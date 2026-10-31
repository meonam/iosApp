import Foundation
import UIKit
import AudioToolbox

extension Notification.Name {
    public static let inventoryDidClearRemotely = Notification.Name("inventoryDidClearRemotely")
}

public final class FirebaseSyncService {
    public static let shared = FirebaseSyncService()
    
    public let firebaseBaseURL = "https://barcodescanner-cc3ab-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    private var clearMonitorTask: Task<Void, Never>? = nil
    private var monitoredPcUid: String = ""
    
    private init() {}
    
    // MARK: - Kiểm tra kết nối PC
    
    /// Kiểm tra trạng thái máy tính (PC) đã sẵn sàng nhận qua Internet chưa
    public func checkPcConnection(pcUid: String) async throws -> Bool {
        guard let url = URL(string: "\(firebaseBaseURL)/devices/pc/\(pcUid).json") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return false
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        
        // 1. Kiểm tra trạng thái status ("online", true, "1", "active")
        let rawStatus = json["status"]
        var isOnline = false
        if let s = rawStatus as? String {
            isOnline = s.lowercased() == "online" || s == "1" || s.lowercased() == "active"
        } else if let b = rawStatus as? Bool {
            isOnline = b
        } else if let n = rawStatus as? NSNumber {
            isOnline = n.intValue == 1
        }
        
        // 2. Kiểm tra cờ tích nhận Internet trên PC (internet / isInternet / is_internet)
        var isInternetEnabled = true
        let rawInternet = json["internet"] ?? json["isInternet"] ?? json["is_internet"]
        if let b = rawInternet as? Bool {
            isInternetEnabled = b
        } else if let s = rawInternet as? String {
            isInternetEnabled = s.lowercased() == "true" || s == "1"
        } else if let n = rawInternet as? NSNumber {
            isInternetEnabled = n.intValue == 1
        }
        
        return isOnline && isInternetEnabled
    }
    
    // MARK: - Gửi dữ liệu kiểm kê lên Firebase RTDB
    
    /// Đẩy dữ liệu kiểm kê lên Firebase theo đúng chuẩn định dạng Android và PC Tool
    public func sendInventoryData(pcUid: String, fileName: String, content: String, employeeId: String = "001") async throws -> Bool {
        let pushKey = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        guard let url = URL(string: "\(firebaseBaseURL)/inventory_data/\(pcUid)/\(pushKey).json") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let iosId = UIDevice.current.identifierForVendor?.uuidString ?? "iOSDevice"
        
        // Đầy đủ các trường tương tự Android WifiFragment.kt và model InventoryData trên PC GETDATA.cs
        let payload: [String: Any] = [
            "fileName": fileName,
            "content": content,
            "timestamp": nowMs,
            "deviceId": pcUid,
            "uid": pushKey,
            "pushKey": pushKey,
            "employeeId": employeeId,
            "androidId": iosId,
            "iosId": iosId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return false
        }
        
        // Khởi động lắng nghe lệnh xoá từ PC ngay sau khi gửi thành công
        startRemoteClearMonitoring(pcUid: pcUid)
        
        // Chờ máy tính PC phản hồi ACK xác nhận đã nhận dữ liệu (tối đa 12 giây)
        return await waitForPcAck(pcUid: pcUid, pushKey: pushKey)
    }
    
    // MARK: - Chờ ACK từ máy tính PC
    
    private func waitForPcAck(pcUid: String, pushKey: String) async -> Bool {
        guard let ackURL = URL(string: "\(firebaseBaseURL)/inventory_acks/\(pcUid)/\(pushKey).json") else {
            return false
        }
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 12.0 {
            try? await Task.sleep(nanoseconds: 600_000_000) // Đợi 600ms mỗi lần kiểm tra (tương tự delay(600) trên Android)
            
            if let (data, _) = try? await URLSession.shared.data(from: ackURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String, status == "CONFIRMED" {
                
                // Xoá ACK sau khi nhận
                var deleteReq = URLRequest(url: ackURL)
                deleteReq.httpMethod = "DELETE"
                _ = try? await URLSession.shared.data(for: deleteReq)
                return true
            }
        }
        // Nếu hết 12 giây vẫn coi là đã đẩy lên hàng đợi Firebase thành công
        return true
    }
    
    // MARK: - Lắng nghe lệnh xóa từ PC (Remote Clear)
    
    public func startRemoteClearMonitoring(pcUid: String) {
        let clean = pcUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if clearMonitorTask != nil && monitoredPcUid == clean { return }
        
        clearMonitorTask?.cancel()
        monitoredPcUid = clean
        
        clearMonitorTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                await self.checkAndPerformRemoteClear(pcUid: clean)
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Kiểm tra mỗi 3 giây
            }
        }
    }
    
    public func stopRemoteClearMonitoring() {
        clearMonitorTask?.cancel()
        clearMonitorTask = nil
    }
    
    private func checkAndPerformRemoteClear(pcUid: String) async {
        // Kiểm tra đồng thời 2 node: inventory_device_clear và device_commands giống Android LauncherActivity
        let endpoints = [
            "\(firebaseBaseURL)/inventory_device_clear/\(pcUid).json",
            "\(firebaseBaseURL)/device_commands/\(pcUid).json"
        ]
        
        for ep in endpoints {
            guard let url = URL(string: ep) else { continue }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            
            let action = (json["action"] as? String) ?? ""
            let command = (json["command"] as? String) ?? ""
            
            if action == "CLEAR_DATA" || command == "CLEAR" {
                let targetEmpId = ((json["targetEmployeeId"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let targetFileName = ((json["targetFileName"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                
                let rawIdScan = (UserDefaults.standard.string(forKey: "id_scan") ?? "001").trimmingCharacters(in: .whitespacesAndNewlines)
                let myScanId: String
                if let intVal = Int(rawIdScan) {
                    myScanId = String(format: "%03d", intVal)
                } else {
                    myScanId = rawIdScan.isEmpty ? "001" : rawIdScan
                }
                
                let formattedTargetEmpId: String
                if let intVal = Int(targetEmpId) {
                    formattedTargetEmpId = String(format: "%03d", intVal)
                } else {
                    formattedTargetEmpId = targetEmpId
                }
                
                let isForMe: Bool
                if !targetEmpId.isEmpty {
                    isForMe = (formattedTargetEmpId == myScanId) || targetFileName.hasPrefix(myScanId)
                } else if !targetFileName.isEmpty {
                    isForMe = targetFileName.hasPrefix(myScanId)
                } else {
                    isForMe = true
                }
                
                if isForMe {
                    // 1. Xoá node trên Firebase
                    var delReq = URLRequest(url: url)
                    delReq.httpMethod = "DELETE"
                    _ = try? await URLSession.shared.data(for: delReq)
                    
                    // 2. Xoá CSDL cục bộ và thông báo cho UI
                    await MainActor.run {
                        _ = DatabaseHelper.shared.clearAll()
                        AudioServicesPlaySystemSound(1057) // Beep
                        NotificationCenter.default.post(name: .inventoryDidClearRemotely, object: nil)
                    }
                    break
                } else {
                    // Lệnh xóa nhắm tới máy khác, bỏ qua
                    continue
                }
            }
        }
    }
}
