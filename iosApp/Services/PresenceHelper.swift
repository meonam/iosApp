import Foundation
import UIKit

// MARK: - PRESENCE HELPER (ĐỒNG BỘ 1:1 THEO PRESENCEHELPER.KT CỦA ANDROID)
// Cập nhật trạng thái isOnline và lastActiveAt của người dùng lên Firestore
// Để các nền tảng khác (Web/Desktop/Android) thấy ngay trạng thái Online/Offline trong Form điều phối
public class PresenceHelper {
    public static let shared = PresenceHelper()

    private var heartbeatTimer: Timer?
    private var currentCompanyId: String = ""
    private var currentEmail: String = ""
    private var currentIdToken: String = ""

    private init() {}

    // Bắt đầu nhịp tim hoạt động (mỗi 45s đồng bộ Android)
    public func startHeartbeat(companyId: String, email: String, idToken: String = "") {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCompId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanEmail.isEmpty, !cleanCompId.isEmpty else { return }

        self.currentCompanyId = cleanCompId
        self.currentEmail = cleanEmail
        self.currentIdToken = idToken

        // Báo online ngay lập tức khi đăng nhập hoặc mở app
        setPresence(companyId: cleanCompId, email: cleanEmail, isOnline: true, idToken: idToken)

        // Hủy timer cũ nếu có
        stopHeartbeat()

        // Tạo timer chạy lặp lại mỗi 45 giây trên Main thread
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.setPresence(companyId: self.currentCompanyId, email: self.currentEmail, isOnline: true, idToken: self.currentIdToken)
            }
        }
    }

    public func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    // Cập nhật Firestore document: companies/{companyId}/users/{email}
    // Ghi 2 trường chuẩn: lastActiveAt (ms timestamp) & isOnline (Bool)
    public func setPresence(companyId: String, email: String, isOnline: Bool, idToken: String = "") {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCompId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanEmail.isEmpty, !cleanCompId.isEmpty else { return }

        let encodedEmail = cleanEmail.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanEmail
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanCompId)/users/\(encodedEmail)?updateMask.fieldPaths=lastActiveAt&updateMask.fieldPaths=isOnline"

        guard let url = URL(string: urlStr) else { return }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let bodyObj: [String: Any] = [
            "fields": [
                "lastActiveAt": ["integerValue": "\(nowMs)"],
                "isOnline": ["booleanValue": isOnline]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyObj) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        let tokenToUse = !idToken.isEmpty ? idToken : self.currentIdToken
        if !tokenToUse.isEmpty {
            request.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("[PresenceHelper] Error setting presence (\(isOnline)) for \(cleanEmail): \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 200 && http.statusCode < 300 {
                print("[PresenceHelper] Successfully updated presence for \(cleanEmail) in \(cleanCompId) -> isOnline=\(isOnline)")
            }
        }.resume()
    }
}
