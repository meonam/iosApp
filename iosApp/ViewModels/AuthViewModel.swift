import SwiftUI

// MARK: - AUTH VIEW MODEL (ĐỒNG BỘ 1:1 VỚI LOGINVIEWMODEL.KT TRÊN ANDROID)
@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var email: String = ""
    @Published public var password: String = ""
    @Published public var isPasswordVisible: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    // State đăng nhập & session
    @Published public var currentUser: User? = nil
    @Published public var currentCompanyId: String = "SGCOOP"
    @Published public var currentIdToken: String = ""
    @Published public var currentRefreshToken: String = ""
    @Published public var isAuthenticated: Bool = false

    // State đổi mật khẩu bắt buộc
    @Published public var showForceChangePasswordModal: Bool = false
    @Published public var forceChangePasswordEmail: String = ""

    // State quên mật khẩu
    @Published public var showForgotPasswordDialog: Bool = false
    @Published public var forgotPasswordSuccessMessage: String? = nil

    // State ghi nhớ mật khẩu
    @Published public var rememberPassword: Bool = true

    private func normalizeCompanyId(_ compId: String) -> String {
        let clean = compId.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty || clean.uppercased() == "SAIGONCOOP" || clean.uppercased() == "SAIGON CO-OP" || clean.uppercased() == "SAIGON_COOP" {
            return "SGCOOP"
        }
        return clean
    }

    public init() {
        // Tải session đã lưu từ UserDefaults nếu có
        loadSavedSession()
    }

    public func login() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEmail.isEmpty {
            errorMessage = "Vui lòng nhập Email, SĐT hoặc Mã nhân viên!"
            return
        }
        if password.isEmpty {
            errorMessage = "Vui lòng nhập mật khẩu!"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let session = try await AuthService.shared.signIn(account: cleanEmail, password: password)
                let (compId, profile) = await AuthService.shared.resolveUserProfile(email: session.email, idToken: session.idToken)

                let status = profile?.status.uppercased() ?? "ACTIVE"
                if status == "DISABLED" || status == "LOCKED" {
                    self.isLoading = false
                    self.errorMessage = "Tài khoản của bạn đã bị vô hiệu hóa bởi Quản trị viên."
                    return
                }

                self.currentIdToken = session.idToken
                self.currentRefreshToken = session.refreshToken
                self.currentCompanyId = self.normalizeCompanyId(compId)
                self.currentUser = profile ?? User(email: session.email)

                // Kiểm tra xem có bắt buộc đổi mật khẩu lần đầu không
                if profile?.mustChangePassword == true {
                    self.forceChangePasswordEmail = session.email
                    self.showForceChangePasswordModal = true
                } else {
                    self.isAuthenticated = true
                    self.saveSession()
                    PresenceHelper.shared.startHeartbeat(
                        companyId: self.currentCompanyId,
                        email: self.currentUser?.email ?? session.email,
                        idToken: self.currentIdToken
                    )
                }
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func submitForgotPassword(for targetEmail: String) {
        let clean = targetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isLoading = true
        Task {
            do {
                try await AuthService.shared.sendPasswordReset(email: clean)
                self.forgotPasswordSuccessMessage = "Đã gửi email khôi phục mật khẩu tới \(clean). Vui lòng kiểm tra hộp thư!"
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func submitForceChangePassword(newPass: String) {
        isLoading = true
        Task {
            do {
                try await AuthService.shared.updatePassword(idToken: currentIdToken, newPassword: newPass)
                self.showForceChangePasswordModal = false
                self.isAuthenticated = true
                self.saveSession()
                PresenceHelper.shared.startHeartbeat(
                    companyId: self.currentCompanyId,
                    email: self.currentUser?.email ?? self.forceChangePasswordEmail,
                    idToken: self.currentIdToken
                )
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func logout() {
        if let u = currentUser {
            PresenceHelper.shared.setPresence(
                companyId: currentCompanyId,
                email: u.email,
                isOnline: false,
                idToken: currentIdToken
            )
        }
        PresenceHelper.shared.stopHeartbeat()

        self.isAuthenticated = false
        self.currentUser = nil
        self.currentIdToken = ""
        self.currentRefreshToken = ""
        if !rememberPassword {
            self.password = ""
            UserDefaults.standard.removeObject(forKey: "saved_auth_password")
        } else {
            if let savedPass = UserDefaults.standard.string(forKey: "saved_auth_password") {
                self.password = savedPass
            }
        }
        UserDefaults.standard.removeObject(forKey: "saved_auth_token")
        UserDefaults.standard.removeObject(forKey: "saved_auth_refresh_token")
        UserDefaults.standard.removeObject(forKey: "saved_auth_user_data")
    }

    private func saveSession() {
        UserDefaults.standard.set(rememberPassword, forKey: "saved_remember_password")
        UserDefaults.standard.set(currentUser?.email, forKey: "saved_auth_email")
        UserDefaults.standard.set(currentCompanyId, forKey: "saved_auth_company_id")
        UserDefaults.standard.set(currentIdToken, forKey: "saved_auth_token")
        UserDefaults.standard.set(currentRefreshToken, forKey: "saved_auth_refresh_token")
        if rememberPassword {
            UserDefaults.standard.set(password, forKey: "saved_auth_password")
        } else {
            UserDefaults.standard.removeObject(forKey: "saved_auth_password")
        }
        if let u = currentUser, let data = try? JSONEncoder().encode(u) {
            UserDefaults.standard.set(data, forKey: "saved_auth_user_data")
        }
    }

    private func loadSavedSession() {
        let isRemember = UserDefaults.standard.object(forKey: "saved_remember_password") as? Bool ?? true
        self.rememberPassword = isRemember

        if let savedEmail = UserDefaults.standard.string(forKey: "saved_auth_email"), !savedEmail.isEmpty {
            self.email = savedEmail
            let savedComp = UserDefaults.standard.string(forKey: "saved_auth_company_id") ?? "SGCOOP"
            self.currentCompanyId = normalizeCompanyId(savedComp)
            self.currentIdToken = UserDefaults.standard.string(forKey: "saved_auth_token") ?? ""
            self.currentRefreshToken = UserDefaults.standard.string(forKey: "saved_auth_refresh_token") ?? ""

            if isRemember {
                if let savedPass = UserDefaults.standard.string(forKey: "saved_auth_password"), !savedPass.isEmpty {
                    self.password = savedPass
                }
            }
            
            if let data = UserDefaults.standard.data(forKey: "saved_auth_user_data"),
               let savedUser = try? JSONDecoder().decode(User.self, from: data) {
                self.currentUser = savedUser
                self.isAuthenticated = true
                PresenceHelper.shared.startHeartbeat(
                    companyId: self.currentCompanyId,
                    email: savedUser.email,
                    idToken: self.currentIdToken
                )
            }

            // Tự động làm mới ID Token nếu có Refresh Token hợp lệ
            if !currentRefreshToken.isEmpty && !currentRefreshToken.starts(with: "refresh_") {
                Task {
                    if let refreshed = await AuthService.shared.refreshToken(refreshToken: self.currentRefreshToken) {
                        await MainActor.run {
                            self.currentIdToken = refreshed.idToken
                            self.currentRefreshToken = refreshed.newRefreshToken
                            self.saveSession()
                            PresenceHelper.shared.startHeartbeat(
                                companyId: self.currentCompanyId,
                                email: self.currentUser?.email ?? savedEmail,
                                idToken: refreshed.idToken
                            )
                        }
                    }
                }
            }

            // Luôn đồng bộ lại thông tin profile mới nhất từ Firestore để cập nhật phòng ban/đơn vị
            Task {
                let (compId, freshUser) = await AuthService.shared.resolveUserProfile(email: savedEmail, idToken: self.currentIdToken)
                if let u = freshUser {
                    await MainActor.run {
                        self.currentUser = u
                        if !compId.isEmpty { self.currentCompanyId = self.normalizeCompanyId(compId) }
                        self.saveSession()
                    }
                }
            }
        }
    }
}
