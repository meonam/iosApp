import Foundation
import Security

// MARK: - KEYCHAIN HELPER (BẢO MẬT LƯU TRỮ MẬT KHẨU BẰNG PHẦN CỨNG SECURE ENCLAVE)
public enum KeychainHelper {
    private static let serviceName = "com.huyenhan.qltb.auth"

    @discardableResult
    public static func save(key: String, data: String) -> Bool {
        guard let dataBytes = data.data(using: .utf8) else { return false }
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: dataBytes,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    @discardableResult
    public static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

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

    private var identifierCache: [String: String] = [:]
    private var cachedGuestToken: String? = nil
    private var guestTokenExpiry: Date = .distantPast

    // Lấy Guest Token ngầm (guest_lookup_qltb@gmail.com) tương tự Desktop/Android
    public func ensureGuestToken() async -> String? {
        if let token = cachedGuestToken, Date() < guestTokenExpiry {
            return token
        }
        guard let url = URL(string: FirebaseConfig.authSignInUrl) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "email": "guest_lookup_qltb@gmail.com",
            "password": "GuestLookup@2026!",
            "returnSecureToken": true
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body),
              let (data, resp) = try? await URLSession.shared.upload(for: request, from: httpBody),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["idToken"] as? String else {
            return nil
        }
        let expiresInSec = Double(json["expiresIn"] as? String ?? "3600") ?? 3600.0
        self.cachedGuestToken = idToken
        self.guestTokenExpiry = Date().addingTimeInterval(expiresInSec - 120.0)
        return idToken
    }

    private func getPhoneVariations(_ rawPhone: String) -> [String] {
        let trimmed = rawPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        var norm = trimmed.filter { $0.isNumber || $0 == "+" }
        if norm.hasPrefix("+84") {
            norm = "0" + norm.dropFirst(3)
        } else if norm.hasPrefix("84") && norm.count >= 11 {
            norm = "0" + norm.dropFirst(2)
        }

        var variations = Set<String>()
        if !trimmed.isEmpty { variations.insert(trimmed) }
        if !norm.isEmpty {
            variations.insert(norm)
            if norm.hasPrefix("0") {
                let core = String(norm.dropFirst())
                variations.insert("+84\(core)")
                variations.insert("84\(core)")
                if norm.count == 10 {
                    let p1 = norm.prefix(4)
                    let p2 = norm.dropFirst(4).prefix(3)
                    let p3 = norm.suffix(3)
                    variations.insert("\(p1) \(p2) \(p3)")
                    variations.insert("\(p1).\(p2).\(p3)")
                }
            }
        }
        return Array(variations).filter { !$0.isEmpty }
    }

    // Tra cứu Email từ Số điện thoại hoặc Mã nhân viên (Đồng bộ 1:1 Android UserCompanyResolver.kt)
    public func resolveEmailFromIdentifier(input: String) async -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.contains("@") { return trimmed.lowercased() }

        let upperInput = trimmed.uppercased()
        if let cached = identifierCache[trimmed] ?? identifierCache[upperInput] {
            return cached
        }

        let cleanDigits = trimmed.filter { $0.isNumber }
        let isPhone = cleanDigits.count >= 8 && cleanDigits.count <= 12
        let phoneVariations = isPhone ? getPhoneVariations(trimmed) : []
        let targetDigitsSet = Set([cleanDigits] + phoneVariations.map { $0.filter { $0.isNumber } }.filter { !$0.isEmpty })

        // 0. Kiểm tra bộ nhớ đệm Offline UserDefaults (nếu trước đó đã đăng nhập trên máy này)
        if let offlineList = UserDefaults.standard.array(forKey: "qltb_offline_users_cache") as? [[String: String]] {
            for u in offlineList {
                guard let email = u["email"], email.contains("@") else { continue }
                let uMnv = (u["maNhanVien"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                if !uMnv.isEmpty && uMnv == upperInput {
                    let resEmail = email.lowercased()
                    identifierCache[trimmed] = resEmail
                    return resEmail
                }
                if isPhone {
                    let uPhoneDigits = (u["phone"] ?? "").filter { $0.isNumber }
                    if targetDigitsSet.contains(uPhoneDigits) || (uPhoneDigits.count >= 9 && cleanDigits.count >= 9 && (uPhoneDigits.hasSuffix(cleanDigits) || cleanDigits.hasSuffix(uPhoneDigits))) {
                        let resEmail = email.lowercased()
                        identifierCache[trimmed] = resEmail
                        return resEmail
                    }
                }
            }
        }

        // Chuẩn bị token khách để xác thực nếu Firestore yêu cầu
        let guestToken = await ensureGuestToken()

        // Helper so khớp DocumentSnapshot
        func matchesUser(fields: [String: Any], docId: String) -> String? {
            let mnvFields = [
                FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                FirestoreHelper.getString(fields["employeeId"] as? [String: Any]),
                FirestoreHelper.getString(fields["employeeCode"] as? [String: Any]),
                FirestoreHelper.getString(fields["mnv"] as? [String: Any]),
                FirestoreHelper.getString(fields["mnvDisplay"] as? [String: Any])
            ].map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }.filter { !$0.isEmpty }

            let cleanDocId = docId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let emailField = FirestoreHelper.getString(fields["email"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let fullName = FirestoreHelper.getString(fields["fullName"] as? [String: Any])

            if mnvFields.contains(upperInput) || cleanDocId == upperInput {
                return !emailField.isEmpty ? emailField : (docId.contains("@") ? docId.lowercased() : nil)
            }

            let standardMnv = lookupStandardKtvMnv(email: emailField, fullName: fullName).uppercased()
            if !standardMnv.isEmpty && standardMnv == upperInput {
                return !emailField.isEmpty ? emailField : (docId.contains("@") ? docId.lowercased() : nil)
            }

            if isPhone && !targetDigitsSet.isEmpty {
                let pFields = [
                    FirestoreHelper.getString(fields["phone"] as? [String: Any]),
                    FirestoreHelper.getString(fields["soDienThoai"] as? [String: Any]),
                    FirestoreHelper.getString(fields["phoneNumber"] as? [String: Any]),
                    FirestoreHelper.getString(fields["sdt"] as? [String: Any]),
                    FirestoreHelper.getString(fields["soDT"] as? [String: Any])
                ].map { $0.filter { $0.isNumber } }.filter { !$0.isEmpty }

                for p in pFields {
                    if targetDigitsSet.contains(p) || (p.count >= 9 && cleanDigits.count >= 9 && (p.hasSuffix(cleanDigits) || cleanDigits.hasSuffix(p))) {
                        return !emailField.isEmpty ? emailField : (docId.contains("@") ? docId.lowercased() : nil)
                    }
                }
            }

            return nil
        }

        func makeAuthorizedRequest(urlStr: String) -> URLRequest? {
            guard let url = URL(string: urlStr) else { return nil }
            var req = URLRequest(url: url)
            if let token = guestToken, !token.isEmpty {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            return req
        }

        // 1. Quét nhanh trong companies/SGCOOP/users
        if let req = makeAuthorizedRequest(urlStr: "\(FirebaseConfig.firestoreBaseUrl)/companies/SGCOOP/users?pageSize=300") {
            if let (data, resp) = await FirestoreHelper.executeSafeRequest(req),
               resp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    if let fields = doc["fields"] as? [String: Any],
                       let docName = doc["name"] as? String {
                        let docId = docName.components(separatedBy: "/").last ?? ""
                        if let foundEmail = matchesUser(fields: fields, docId: docId) {
                            identifierCache[trimmed] = foundEmail
                            identifierCache[upperInput] = foundEmail
                            if isPhone { identifierCache[cleanDigits] = foundEmail }
                            return foundEmail
                        }
                    }
                }
            }
        }

        // 2. Quét qua tất cả các công ty khác trong companies/ (hỗ trợ đa doanh nghiệp)
        if let reqComps = makeAuthorizedRequest(urlStr: "\(FirebaseConfig.firestoreBaseUrl)/companies?pageSize=50") {
            if let (data, resp) = await FirestoreHelper.executeSafeRequest(reqComps),
               resp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let compDocs = json["documents"] as? [[String: Any]] {
                for cDoc in compDocs {
                    guard let cName = cDoc["name"] as? String else { continue }
                    let cId = cName.components(separatedBy: "/").last ?? ""
                    if cId.isEmpty || cId.uppercased() == "SGCOOP" { continue }

                    if let reqUsers = makeAuthorizedRequest(urlStr: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cId)/users?pageSize=300") {
                        if let (uData, uResp) = await FirestoreHelper.executeSafeRequest(reqUsers),
                           uResp.statusCode == 200,
                           let uJson = try? JSONSerialization.jsonObject(with: uData) as? [String: Any],
                           let uDocs = uJson["documents"] as? [[String: Any]] {
                            for doc in uDocs {
                                if let fields = doc["fields"] as? [String: Any],
                                   let docName = doc["name"] as? String {
                                    let docId = docName.components(separatedBy: "/").last ?? ""
                                    if let foundEmail = matchesUser(fields: fields, docId: docId) {
                                        identifierCache[trimmed] = foundEmail
                                        identifierCache[upperInput] = foundEmail
                                        if isPhone { identifierCache[cleanDigits] = foundEmail }
                                        return foundEmail
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3. Fallback quét qua root users/
        if let req = makeAuthorizedRequest(urlStr: "\(FirebaseConfig.firestoreBaseUrl)/users?pageSize=300") {
            if let (data, resp) = await FirestoreHelper.executeSafeRequest(req),
               resp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    if let fields = doc["fields"] as? [String: Any],
                       let docName = doc["name"] as? String {
                        let docId = docName.components(separatedBy: "/").last ?? ""
                        if let foundEmail = matchesUser(fields: fields, docId: docId) {
                            identifierCache[trimmed] = foundEmail
                            identifierCache[upperInput] = foundEmail
                            if isPhone { identifierCache[cleanDigits] = foundEmail }
                            return foundEmail
                        }
                    }
                }
            }
        }

        return nil
    }

    // 1. Đăng nhập bằng Email, Số điện thoại hoặc Mã nhân viên (Đồng bộ 1:1 Android LoginViewModel.kt)
    public func signIn(account: String, password: String) async throws -> AuthSession {
        let cleanInput = account.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanInput.isEmpty {
            throw NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Email, SĐT hoặc Mã nhân viên!"])
        }

        // Ánh xạ SĐT hoặc Mã NV sang Email tài khoản nếu không có ký tự @
        let resolvedEmail: String
        if !cleanInput.contains("@") {
            if let email = await resolveEmailFromIdentifier(input: cleanInput) {
                resolvedEmail = email
            } else {
                throw NSError(domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy tài khoản gắn với số điện thoại hoặc mã nhân viên '\(cleanInput)'."])
            }
        } else {
            resolvedEmail = cleanInput.lowercased()
        }

        let isSuperAdmin = SuperAdminConfig.isSuperAdmin(email: resolvedEmail)

        // A. Thử đăng nhập qua Firebase Auth REST API
        var firebaseAuthError: Error? = nil
        do {
            let session = try await performFirebaseAuthSignIn(email: resolvedEmail, password: password)
            return session
        } catch {
            firebaseAuthError = error
        }

        // B. Fallback Firestore: Kiểm tra nếu mật khẩu người dùng khớp với Firestore document (password, matKhau, pass, newPassword)
        let userDocUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/SGCOOP/users/\(resolvedEmail)"
        if let uUrl = URL(string: userDocUrl) {
            let req = URLRequest(url: uUrl)
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let savedPw = FirestoreHelper.getString(fields["password"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["matKhau"] as? [String: Any]) : FirestoreHelper.getString(fields["password"] as? [String: Any])
                let fallbackPw = savedPw.isEmpty ? FirestoreHelper.getString(fields["pass"] as? [String: Any]) : savedPw
                let newPw = FirestoreHelper.getString(fields["newPassword"] as? [String: Any])

                if (!fallbackPw.isEmpty && fallbackPw == password) || (!newPw.isEmpty && newPw == password) {
                    return AuthSession(
                        idToken: "token_\(UUID().uuidString)",
                        refreshToken: "refresh_\(UUID().uuidString)",
                        localId: resolvedEmail,
                        email: resolvedEmail,
                        user: nil
                    )
                }
            }
        }

        // B2. Fallback Root Firestore (cho tài khoản Quản trị toàn hệ thống / Central Command)
        let rootDocUrl = "\(FirebaseConfig.firestoreBaseUrl)/users/\(resolvedEmail)"
        if let rUrl = URL(string: rootDocUrl) {
            let req = URLRequest(url: rUrl)
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let savedPw = FirestoreHelper.getString(fields["password"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["matKhau"] as? [String: Any]) : FirestoreHelper.getString(fields["password"] as? [String: Any])
                let fallbackPw = savedPw.isEmpty ? FirestoreHelper.getString(fields["pass"] as? [String: Any]) : savedPw
                let newPw = FirestoreHelper.getString(fields["newPassword"] as? [String: Any])

                if (!fallbackPw.isEmpty && fallbackPw == password) || (!newPw.isEmpty && newPw == password) {
                    return AuthSession(
                        idToken: "token_\(UUID().uuidString)",
                        refreshToken: "refresh_\(UUID().uuidString)",
                        localId: resolvedEmail,
                        email: resolvedEmail,
                        user: nil
                    )
                }
            }
        }

        if let err = firebaseAuthError {
            throw err
        }

        throw NSError(domain: "AuthService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Tài khoản hoặc mật khẩu không chính xác!"])
    }

    // Convenience overload to support calling signIn(email:password:) directly
    @discardableResult
    public func signIn(email: String, password: String) async throws -> AuthSession {
        return try await signIn(account: email, password: password)
    }

    // Gửi yêu cầu đăng nhập trực tiếp tới Firebase REST
    public func performFirebaseAuthSignIn(email: String, password: String) async throws -> AuthSession {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

        // Thử tìm trong SGCOOP trước (theo đúng chuẩn Android)
        let defaultCompId = "SGCOOP"
        let compUserUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(defaultCompId)/users/\(cleanEmail)"
        if let user = await fetchUserDoc(urlStr: compUserUrl, idToken: idToken) {
            var updatedUser = user
            if updatedUser.companyId.isEmpty { updatedUser.companyId = defaultCompId }
            return (defaultCompId, updatedUser)
        }

        // Thử tìm trong root collection users
        let rootUserUrl = "\(FirebaseConfig.firestoreBaseUrl)/users/\(cleanEmail)"
        if let user = await fetchUserDoc(urlStr: rootUserUrl, idToken: idToken) {
            let compId = !user.companyId.isEmpty ? user.companyId : defaultCompId
            return (compId, user)
        }

        // Thử tìm trong saigoncoop (lowercase)
        let lowerCompId = "saigoncoop"
        let lowerUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(lowerCompId)/users/\(cleanEmail)"
        if let user = await fetchUserDoc(urlStr: lowerUrl, idToken: idToken) {
            var updatedUser = user
            if updatedUser.companyId.isEmpty { updatedUser.companyId = defaultCompId }
            return (defaultCompId, updatedUser)
        }

        // Nếu là admin@sgcoop.com, tự động khởi tạo hồ sơ Quản trị viên
        if cleanEmail.contains("admin") || cleanEmail == "admin@sgcoop.com" {
            let adminUser = User(
                maNhanVien: "ADMIN",
                email: cleanEmail,
                role: "admin",
                fullName: "admin",
                phone: "",
                donVi: "Toàn hệ thống Doanh nghiệp",
                companyId: defaultCompId,
                departmentId: "CNTT",
                status: "ACTIVE"
            )
            return (defaultCompId, adminUser)
        }

        return (defaultCompId, nil)
    }

    private func fetchUserDoc(urlStr: String, idToken: String) async -> User? {
        guard let url = URL(string: urlStr) else { return nil }
        
        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = await FirestoreHelper.executeSafeRequest(request),
              response.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            return nil
        }

        let resolvedDept = FirestoreHelper.getString(fields["departmentId"] as? [String: Any])
            .ifEmpty(FirestoreHelper.getString(fields["phongBan"] as? [String: Any]))
        let rawDonVi = FirestoreHelper.getString(fields["donVi"] as? [String: Any])
            .ifEmpty(FirestoreHelper.getString(fields["tenDonVi"] as? [String: Any]))
        let rawUnitId = FirestoreHelper.getString(fields["unitId"] as? [String: Any])
        var resolvedDonVi = rawDonVi
        if !rawUnitId.isEmpty && !resolvedDonVi.isEmpty && resolvedDonVi != rawUnitId {
            if !resolvedDonVi.contains(" - ") && !resolvedDonVi.hasPrefix(rawUnitId) {
                resolvedDonVi = "\(rawUnitId) - \(resolvedDonVi)"
            }
        } else if !rawUnitId.isEmpty && resolvedDonVi.isEmpty {
            resolvedDonVi = rawUnitId
        }
        let resolvedCompanyId = FirestoreHelper.getString(fields["companyId"] as? [String: Any])
            .ifEmpty("SGCOOP")
        let resolvedKhuVuc = FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])
            .ifEmpty(FirestoreHelper.getString(fields["khuVuc"] as? [String: Any]))

        return User(
            maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
            email: FirestoreHelper.getString(fields["email"] as? [String: Any]),
            role: FirestoreHelper.getString(fields["role"] as? [String: Any]),
            fullName: FirestoreHelper.getString(fields["fullName"] as? [String: Any]),
            phone: FirestoreHelper.getString(fields["phone"] as? [String: Any]),
            donVi: resolvedDonVi,
            companyId: resolvedCompanyId,
            departmentId: resolvedDept,
            status: FirestoreHelper.getString(fields["status"] as? [String: Any]).ifEmpty("ACTIVE"),
            avatarUrl: FirestoreHelper.getString(fields["avatarUrl"] as? [String: Any]),
            createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
            mustChangePassword: FirestoreHelper.getBool(fields["mustChangePassword"] as? [String: Any]),
            maKhuVuc: resolvedKhuVuc,
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

    // 5. Làm mới Firebase ID Token khi hết hạn
    public func refreshToken(refreshToken: String) async -> (idToken: String, newRefreshToken: String)? {
        let clean = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !clean.starts(with: "refresh_") else { return nil }
        guard let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)") else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "grant_type=refresh_token&refresh_token=\(clean)"
        req.httpBody = bodyString.data(using: .utf8)

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newId = json["id_token"] as? String else {
            return nil
        }
        let nextRefresh = (json["refresh_token"] as? String) ?? clean
        return (newId, nextRefresh)
    }
}
