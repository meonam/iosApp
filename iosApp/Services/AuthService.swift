import Foundation

// MARK: - AUTH RESULT
public struct AuthSession {
    public var idToken: String
    public var refreshToken: String
    public var localId: String
    public var email: String
    public var user: User?
}

// MARK: - AUTH SERVICE (XỬ LÝ ĐĂNG NHẬP, ĐỔI MẬT KHẨU, PHÂN QUYỀN)
public class AuthService {
    public static let shared = AuthService()

    private init() {}

    // 1. Đăng nhập bằng Email & Password qua Firebase REST API
    public func signIn(email: String, password: String) async throws -> AuthSession {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: FirebaseConfig.authSignInUrl) else {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL không hợp lệ"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "email": cleanEmail,
            "password": password,
            "returnSecureToken": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Lỗi kết nối máy chủ"])
        }

        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        if httpResponse.statusCode != 200 {
            let errorObj = json["error"] as? [String: Any]
            let message = errorObj?["message"] as? String ?? "Đăng nhập thất bại"
            if message.contains("INVALID_LOGIN_CREDENTIALS") || message.contains("INVALID_PASSWORD") || message.contains("EMAIL_NOT_FOUND") {
                throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Email hoặc mật khẩu không chính xác!"])
            }
            throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        guard let idToken = json["idToken"] as? String,
              let refreshToken = json["refreshToken"] as? String,
              let localId = json["localId"] as? String else {
            throw NSError(domain: "AuthService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Dữ liệu phiên không hợp lệ"])
        }

        return AuthSession(
            idToken: idToken,
            refreshToken: refreshToken,
            localId: localId,
            email: cleanEmail,
            user: nil
        )
    }

    // 2. Tra cứu Hồ sơ User & Nhận diện Công ty (UserCompanyResolver)
    public func resolveUserProfile(email: String, idToken: String) async -> (companyId: String, user: User?) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Thử tìm trong root collection users trước
        let rootUserUrl = "\(FirebaseConfig.firestoreBaseUrl)/users/\(cleanEmail)"
        if let user = await fetchUserDoc(urlStr: rootUserUrl, idToken: idToken) {
            let compId = !user.companyId.isEmpty ? user.companyId : "saigoncoop"
            return (compId, user)
        }

        // Nếu không có, tìm trong company mặc định (saigoncoop)
        let defaultCompId = "saigoncoop"
        let compUserUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(defaultCompId)/users/\(cleanEmail)"
        if let user = await fetchUserDoc(urlStr: compUserUrl, idToken: idToken) {
            return (defaultCompId, user)
        }

        return (defaultCompId, nil)
    }

    private func fetchUserDoc(urlStr: String, idToken: String) async -> User? {
        guard let url = URL(string: urlStr) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            return nil
        }

        return User(
            maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
            email: FirestoreHelper.getString(fields["email"] as? [String: Any]),
            role: FirestoreHelper.getString(fields["role"] as? [String: Any]),
            fullName: FirestoreHelper.getString(fields["fullName"] as? [String: Any]),
            phone: FirestoreHelper.getString(fields["phone"] as? [String: Any]),
            donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
            companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
            departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
            status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
            avatarUrl: FirestoreHelper.getString(fields["avatarUrl"] as? [String: Any]),
            createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
            mustChangePassword: FirestoreHelper.getBool(fields["mustChangePassword"] as? [String: Any]),
            maKhuVuc: FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any]),
            toNghiepVu: FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any]),
            lastActiveAt: FirestoreHelper.getInt64(fields["lastActiveAt"] as? [String: Any]),
            isOnline: FirestoreHelper.getBool(fields["isOnline"] as? [String: Any]),
            permissions: FirestoreHelper.getStringArray(fields["permissions"] as? [String: Any])
        )
    }

    // 3. Quên mật khẩu (Gửi email reset)
    public func sendPasswordReset(email: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: FirebaseConfig.authSendOobUrl) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "requestType": "PASSWORD_RESET",
            "email": cleanEmail
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let errorObj = json["error"] as? [String: Any]
            let message = errorObj?["message"] as? String ?? "Không thể gửi email đặt lại mật khẩu"
            throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    // 4. Buộc đổi mật khẩu tạm sang mật khẩu mới
    public func updatePassword(idToken: String, newPassword: String) async throws {
        guard let url = URL(string: FirebaseConfig.authUpdateUrl) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "idToken": idToken,
            "password": newPassword,
            "returnSecureToken": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let errorObj = json["error"] as? [String: Any]
            let message = errorObj?["message"] as? String ?? "Không thể đổi mật khẩu"
            throw NSError(domain: "AuthService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
}
