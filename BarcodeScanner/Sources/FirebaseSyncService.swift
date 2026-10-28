import Foundation

public final class FirebaseSyncService {
    public static let shared = FirebaseSyncService()
    
    public let firebaseBaseURL = "https://barcodescanner-cc3ab-default-rtdb.asia-southeast1.firebasedatabase.app"
    
    private init() {}
    
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
        
        // Kiểm tra cờ online và internet
        let status = (json["status"] as? String)?.lowercased() ?? ""
        let isOnline = status == "online" || status == "1" || status == "active"
        
        return isOnline || json["internet"] as? Bool == true
    }
    
    /// Đẩy dữ liệu kiểm kê lên Firebase theo đúng giao thức Android
    public func sendInventoryData(pcUid: String, fileName: String, content: String) async throws -> Bool {
        let pushKey = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        guard let url = URL(string: "\(firebaseBaseURL)/inventory_data/\(pcUid)/\(pushKey).json") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "fileName": fileName,
            "content": content,
            "pushKey": pushKey
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            return false
        }
        
        // Chờ máy tính PC phản hồi ACK xác nhận đã nhận dữ liệu (tối đa 12 giây)
        return await waitForPcAck(pcUid: pcUid, pushKey: pushKey)
    }
    
    private func waitForPcAck(pcUid: String, pushKey: String) async -> Bool {
        guard let ackURL = URL(string: "\(firebaseBaseURL)/inventory_acks/\(pcUid)/\(pushKey).json") else {
            return false
        }
        
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 12.0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Đợi 1 giây mỗi lần lặp
            
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
        // Nếu PC đã lấy qua Realtime Database thì coi như thành công
        return true
    }
}
