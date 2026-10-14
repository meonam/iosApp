import Foundation

// MARK: - TRUNG TÂM CẤU HÌNH MÁY CHỦ QLTB (POSTGRESQL + NODE.JS + WEBRTC)
// QUY TẮC BẮT BUỘC: 100% kết nối qua URLSession REST API của máy chủ Backend PostgreSQL.
// TUYỆT ĐỐI KHÔNG dùng Firebase SDK hay Google Cloud Firestore SDK.
// Khi chuyển sang máy chủ mới, chỉ cần đổi duy nhất hằng số `serverHost` bên dưới (hoặc chạy switch_server.bat).
public struct ServerConfig {
    public static let serverHost = "103.179.172.229"
    public static let projectId = "qltb-81f4c"
    public static let apiKey = "AIzaSyAehFfYkaZZnaOw3zXQNxokB21D2XcUG6A"

    // MÁY CHỦ BẢN QUYỀN TRUNG TÂM (MASTER LICENSE CLOUD) CỦA TÁC GIẢ
    // Quản lý `license_keys`, `license_codes`, SuperAdmin tạo key và xác thực bản quyền toàn cầu.
    // Tách biệt hoàn toàn khỏi máy chủ nghiệp vụ của công ty khách hàng.
    public static let masterLicenseHost = "103.179.172.229"
    public static let masterLicenseBaseUrl = "https://103.179.172.229.sslip.io/v1/projects/\(projectId)/databases/(default)/documents"

    // ĐÃ CHUYỂN HOÀN TOÀN SANG MÁY CHỦ QLTB ENTERPRISE (POSTGRESQL + EXPRESS)
    public static let serverBaseUrl = "https://103.179.172.229.sslip.io"
    public static let firestoreBaseUrl = "\(serverBaseUrl)/v1/projects/\(projectId)/databases/(default)/documents"
    public static let authSignInUrl = "\(serverBaseUrl)/v1/accounts:signInWithPassword?key=\(apiKey)"
    public static let authSignUpUrl = "\(serverBaseUrl)/v1/accounts:signUp?key=\(apiKey)"
    public static let authSendOobUrl = "\(serverBaseUrl)/v1/accounts:sendOobCode?key=\(apiKey)"
    public static let authUpdateUrl = "\(serverBaseUrl)/v1/accounts:update?key=\(apiKey)"
    public static let storageBucket = "qltb-81f4c.firebasestorage.app"
    
    // WebRTC Signaling & CoTurn STUN/TURN
    public static let stunServer = "stun:\(serverHost):3478"
    public static let turnServer = "turn:\(serverHost):3478"
    public static let turnUsername = "qltbuser"
    public static let turnPassword = "QltbTurn2026!"
    public static let wsSignalingUrl = "ws://\(serverHost)/ws"

    // Định tuyến thông minh theo collection: dữ liệu bản quyền đi tới Master License Cloud
    public static func resolveFirestoreUrl(for path: String) -> String {
        let clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean == "license_keys" || clean.hasPrefix("license_keys/") ||
           clean == "license_codes" || clean.hasPrefix("license_codes/") {
            return "\(masterLicenseBaseUrl)/\(clean)"
        }
        return "\(firestoreBaseUrl)/\(clean)"
    }
}

// Alias tương thích ngược giúp toàn bộ các View hiện hữu hoạt động ổn định 100%
public typealias FirebaseConfig = ServerConfig
