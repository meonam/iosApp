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
    @Published public var currentCompanyId: String = "saigoncoop"
    @Published public var currentIdToken: String = ""
    @Published public var isAuthenticated: Bool = false

    // State đổi mật khẩu bắt buộc
    @Published public var showForceChangePasswordModal: Bool = false
    @Published public var forceChangePasswordEmail: String = ""

    // State quên mật khẩu
    @Published public var showForgotPasswordDialog: Bool = false
    @Published public var forgotPasswordSuccessMessage: String? = nil

    public init() {
        // Tải session đã lưu từ UserDefaults nếu có
        loadSavedSession()
    }

    public func login() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEmail.isEmpty {
            errorMessage = "Vui lòng nhập Email hoặc Số điện thoại!"
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
                let session = try await AuthService.shared.signIn(email: cleanEmail, password: password)
                let (compId, profile) = await AuthService.shared.resolveUserProfile(email: session.email, idToken: session.idToken)

                self.currentIdToken = session.idToken
                self.currentCompanyId = compId
                self.currentUser = profile ?? User(email: session.email)

                // Kiểm tra xem có bắt buộc đổi mật khẩu lần đầu không
                if profile?.mustChangePassword == true {
                    self.forceChangePasswordEmail = session.email
                    self.showForceChangePasswordModal = true
                } else {
                    self.isAuthenticated = true
                    self.saveSession()
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
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    public func logout() {
        self.isAuthenticated = false
        self.currentUser = nil
        self.currentIdToken = ""
        self.password = ""
        UserDefaults.standard.removeObject(forKey: "saved_auth_email")
        UserDefaults.standard.removeObject(forKey: "saved_auth_company_id")
    }

    private func saveSession() {
        UserDefaults.standard.set(currentUser?.email, forKey: "saved_auth_email")
        UserDefaults.standard.set(currentCompanyId, forKey: "saved_auth_company_id")
    }

    private func loadSavedSession() {
        if let savedEmail = UserDefaults.standard.string(forKey: "saved_auth_email"), !savedEmail.isEmpty {
            self.email = savedEmail
            self.currentCompanyId = UserDefaults.standard.string(forKey: "saved_auth_company_id") ?? "saigoncoop"
        }
    }
}
