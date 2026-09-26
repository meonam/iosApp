import SwiftUI

// MARK: - MÀN HÌNH ĐĂNG NHẬP (ĐỒNG BỘ 1:1 VỚI LOGINSCREEN.KT CỦA ANDROID)
public struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    var onLoginSuccess: () -> Void

    @State private var showHelpSheet: Bool = false
    @State private var forgotEmailInput: String = ""

    public init(viewModel: AuthViewModel, onLoginSuccess: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onLoginSuccess = onLoginSuccess
    }

    public var body: some View {
        ZStack {
            // 1. Nền giao diện gradient nhẹ nhàng
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    // 2. Card Đăng Nhập
                    VStack(spacing: 20) {
                        // Logo App
                        Image("logo_app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 90, height: 90)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                        // Tiêu đề & Phiên bản
                        VStack(spacing: 6) {
                            Text("QLTB")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Text("Hệ thống quản trị thiết bị & tài sản")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)

                            Text("Phiên bản v1.0.0 (Build 1)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Color.appCardBorder.opacity(0.5))
                                .cornerRadius(10)
                        }

                        // Ô nhập Email / Số điện thoại
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email hoặc số điện thoại")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)

                            HStack(spacing: 10) {
                                Image(systemName: iconForEmailInput(viewModel.email))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 20)

                                TextField("Nhập email hoặc SĐT", text: $viewModel.email)
                                    .font(.system(size: 14))
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Ô nhập Mật khẩu
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Mật khẩu")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appTextSecondary)
                                Spacer()
                                Button(action: {
                                    forgotEmailInput = viewModel.email
                                    viewModel.showForgotPasswordDialog = true
                                }) {
                                    Text("Quên mật khẩu?")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.appPrimaryPink)
                                }
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 20)

                                if viewModel.isPasswordVisible {
                                    TextField("Nhập mật khẩu", text: $viewModel.password)
                                        .font(.system(size: 14))
                                } else {
                                    SecureField("Nhập mật khẩu", text: $viewModel.password)
                                        .font(.system(size: 14))
                                }

                                Button(action: { viewModel.isPasswordVisible.toggle() }) {
                                    Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Thông báo lỗi nếu có
                        if let errorMsg = viewModel.errorMessage, !errorMsg.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(errorMsg)
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }

                        // Nút Đăng Nhập
                        Button(action: {
                            hideKeyboard()
                            viewModel.login()
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 16))
                                    Text("ĐĂNG NHẬP")
                                        .font(.system(size: 15, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                LinearGradient(
                                    colors: [Color.appPrimaryPink, Color(hex: "#C2185B")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.appPrimaryPink.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading)

                        // Nút Trợ giúp & Hướng dẫn sử dụng
                        Button(action: { showHelpSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                Text("Trợ giúp & Hướng dẫn sử dụng")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
            }
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpInstructionSheet(isPresented: $showHelpSheet)
        }
        .sheet(isPresented: $viewModel.showForgotPasswordDialog) {
            ForgotPasswordSheet(
                initialEmail: forgotEmailInput,
                onSubmit: { email in
                    viewModel.submitForgotPassword(for: email)
                },
                successMessage: viewModel.forgotPasswordSuccessMessage
            )
        }
        .sheet(isPresented: $viewModel.showForceChangePasswordModal) {
            ForceChangePasswordSheet(
                email: viewModel.forceChangePasswordEmail,
                onSubmit: { newPass in
                    viewModel.submitForceChangePassword(newPass: newPass)
                }
            )
        }
        .onChange(of: viewModel.isAuthenticated) { authenticated in
            if authenticated {
                onLoginSuccess()
            }
        }
    }

    private func iconForEmailInput(_ text: String) -> String {
        if text.contains("@") { return "envelope.fill" }
        let digitsOnly = text.filter { $0.isNumber }
        if !digitsOnly.isEmpty && digitsOnly.count >= 8 { return "phone.fill" }
        if !text.isEmpty { return "person.fill" }
        return "person.crop.circle"
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - SHEET TRỢ GIÚP & HƯỚNG DẪN
public struct HelpInstructionSheet: View {
    @Binding var isPresented: Bool

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Hướng dẫn sử dụng hệ thống QLTB")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Text("1. Đăng nhập hệ thống:")
                        .font(.system(size: 14, weight: .bold))
                    Text("Sử dụng email hoặc số điện thoại đã được Ban Quản Trị Saigon Co.op cấp tài khoản để đăng nhập.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)

                    Text("2. Quản lý thiết bị:")
                        .font(.system(size: 14, weight: .bold))
                    Text("Tra cứu thông tin, vị trí, trạng thái sử dụng của thiết bị hoặc quét mã QR/Barcode trên tem dán.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)

                    Text("3. Trung tâm hỗ trợ (Ticket):")
                        .font(.system(size: 14, weight: .bold))
                    Text("Gửi yêu cầu hỗ trợ sự cố thiết bị phần cứng, phần mềm tới bộ phận Kỹ thuật viên / Helpdesk để được xử lý kịp thời.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)

                    Spacer(minLength: 30)
                }
                .padding(20)
            }
            .navigationTitle("Trợ giúp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - SHEET QUÊN MẬT KHẨU
public struct ForgotPasswordSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @State var email: String
    var onSubmit: (String) -> Void
    var successMessage: String?

    public init(initialEmail: String, onSubmit: @escaping (String) -> Void, successMessage: String? = nil) {
        _email = State(initialValue: initialEmail)
        self.onSubmit = onSubmit
        self.successMessage = successMessage
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Đặt lại mật khẩu")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Nhập email tài khoản của bạn để nhận liên kết khôi phục mật khẩu.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)

                TextField("Email tài khoản", text: $email)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .autocapitalization(.none)

                if let success = successMessage {
                    Text(success)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appSuccess)
                }

                Button(action: { onSubmit(email) }) {
                    Text("Gửi yêu cầu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Quên mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

// MARK: - SHEET BẮT BUỘC ĐỔI MẬT KHẨU TẠM
public struct ForceChangePasswordSheet: View {
    var email: String
    var onSubmit: (String) -> Void

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Đổi mật khẩu lần đầu")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Tài khoản của bạn đang sử dụng mật khẩu tạm do Quản trị viên cấp. Vui lòng đặt mật khẩu mới để tiếp tục.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)

                SecureField("Mật khẩu mới", text: $newPassword)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                SecureField("Xác nhận mật khẩu mới", text: $confirmPassword)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }

                Button(action: {
                    if newPassword.count < 6 {
                        errorMessage = "Mật khẩu phải có ít nhất 6 ký tự!"
                        return
                    }
                    if newPassword != confirmPassword {
                        errorMessage = "Mật khẩu xác nhận không khớp!"
                        return
                    }
                    onSubmit(newPassword)
                }) {
                    Text("Cập nhật mật khẩu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(10)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Đổi mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
