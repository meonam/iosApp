import SwiftUI

// MARK: - MÀN HÌNH ĐĂNG NHẬP (ĐỒNG BỘ 1:1 VỚI LOGINSCREEN.KT CỦA ANDROID)
public struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    var onLoginSuccess: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    @State private var showHelpSheet: Bool = false
    @State private var forgotEmailInput: String = ""
    @State private var showResetPasswordSheet: Bool = false

    private enum FocusField: Hashable {
        case email
        case password
    }
    @FocusState private var focusedField: FocusField?

    public init(viewModel: AuthViewModel, onLoginSuccess: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onLoginSuccess = onLoginSuccess
    }

    public var body: some View {
        ZStack {
            // 1. Hình nền IT Support Workflow chuẩn 1:1 Android (Tràn viền màn hình)
            GeometryReader { bgGeo in
                Image("bg_login_workflow")
                    .resizable()
                    .scaledToFill()
                    .frame(width: bgGeo.size.width, height: bgGeo.size.height)
                    .clipped()

                // Lớp phủ Gradient tối tinh tế chuẩn Android (0x440F172A -> 0x771E293B)
                LinearGradient(
                    colors: [
                        Color(hex: "#0F172A").opacity(0.35),
                        Color(hex: "#1E293B").opacity(0.60)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea()

            // 2. Nội dung tự động đẩy lên khi mở bàn phím
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            if focusedField == nil {
                                Spacer(minLength: 24)
                            } else {
                                Color.clear.frame(height: 12)
                            }

                            // Card Đăng Nhập
                            VStack(spacing: focusedField != nil ? 14 : 20) {
                                // Logo App (Thu gọn mượt mà khi mở bàn phím để tiết kiệm diện tích)
                                Image("logo_app")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: focusedField != nil ? 52 : 90, height: focusedField != nil ? 52 : 90)
                                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                                    .animation(.easeInOut(duration: 0.25), value: focusedField)

                                // Tiêu đề & Phiên bản chuẩn 1:1 theo Android
                                VStack(spacing: focusedField != nil ? 3 : 6) {
                                    Text("IT Service & Assets")
                                        .font(.system(size: focusedField != nil ? 20 : 24, weight: .bold))
                                        .foregroundColor(Color.appPrimaryPink)

                                    Text("Dịch vụ IT & Quản lý thiết bị")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color.appTextSecondary)

                                    Text("Phiên bản v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.2") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "132"))")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color.appTextSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 3)
                                        .background(colorScheme == .dark ? Color(hex: "#0F172A").opacity(0.6) : Color.appCardBorder.opacity(0.5))
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1)
                                        )
                                }

                                // Ô nhập Email / SĐT / Mã nhân viên
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Email, SĐT hoặc Mã NV")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.appTextSecondary)

                                    HStack(spacing: 10) {
                                        Image(systemName: iconForEmailInput(viewModel.email))
                                            .foregroundColor(Color.appPrimaryPink)
                                            .frame(width: 20)

                                        ZStack(alignment: .leading) {
                                            if viewModel.email.isEmpty {
                                                Text("Nhập email, SĐT hoặc mã NV")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#94A3B8"))
                                            }
                                            TextField("", text: $viewModel.email)
                                                .font(.system(size: 14))
                                                .foregroundColor(Color.appTextPrimary)
                                                .accentColor(Color.appPrimaryPink)
                                                .autocapitalization(.none)
                                                .disableAutocorrection(true)
                                                .keyboardType(.emailAddress)
                                                .textContentType(.username)
                                                .focused($focusedField, equals: .email)
                                                .submitLabel(.next)
                                                .onSubmit { focusedField = .password }
                                        }
                                    }
                                    .padding(12)
                                    .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color.white)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1))
                                }

                                // Ô nhập Mật khẩu
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Mật khẩu")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.appTextSecondary)

                                    HStack(spacing: 10) {
                                        Image(systemName: "lock.fill")
                                            .foregroundColor(Color.appPrimaryPink)
                                            .frame(width: 20)

                                        ZStack(alignment: .leading) {
                                            if viewModel.password.isEmpty {
                                                Text("Nhập mật khẩu")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color(hex: "#94A3B8"))
                                            }
                                            if viewModel.isPasswordVisible {
                                                TextField("", text: $viewModel.password)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color.appTextPrimary)
                                                    .accentColor(Color.appPrimaryPink)
                                                    .autocapitalization(.none)
                                                    .disableAutocorrection(true)
                                                    .textContentType(.password)
                                                    .focused($focusedField, equals: .password)
                                                    .submitLabel(.go)
                                                    .onSubmit {
                                                        focusedField = nil
                                                        hideKeyboard()
                                                        viewModel.login()
                                                    }
                                            } else {
                                                SecureField("", text: $viewModel.password)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(Color.appTextPrimary)
                                                    .accentColor(Color.appPrimaryPink)
                                                    .textContentType(.password)
                                                    .focused($focusedField, equals: .password)
                                                    .submitLabel(.go)
                                                    .onSubmit {
                                                        focusedField = nil
                                                        hideKeyboard()
                                                        viewModel.login()
                                                    }
                                            }
                                        }

                                        Button(action: { viewModel.isPasswordVisible.toggle() }) {
                                            Image(systemName: viewModel.isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(Color(hex: "#94A3B8"))
                                        }
                                    }
                                    .padding(12)
                                    .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color.white)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1))
                                }
                                .id("passwordSection")

                                // Hàng Ghi nhớ mật khẩu & Quên mật khẩu (Chuẩn 1:1 Android)
                                HStack {
                                    Button(action: {
                                        viewModel.rememberPassword.toggle()
                                        if !viewModel.rememberPassword {
                                            UserDefaults.standard.set(false, forKey: "saved_remember_password")
                                            KeychainHelper.delete(key: "saved_auth_password")
                                            UserDefaults.standard.removeObject(forKey: "saved_auth_password")
                                        } else {
                                            UserDefaults.standard.set(true, forKey: "saved_remember_password")
                                        }
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: viewModel.rememberPassword ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 17))
                                                .foregroundColor(viewModel.rememberPassword ? Color.appPrimaryPink : Color.appTextSecondary)
                                            Text("Ghi nhớ mật khẩu")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(viewModel.rememberPassword ? Color.appTextPrimary : Color.appTextSecondary)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    Spacer()

                                    Button(action: {
                                        forgotEmailInput = viewModel.email
                                        viewModel.showForgotPasswordDialog = true
                                    }) {
                                        Text("Quên mật khẩu?")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.appPrimaryPink)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.top, 2)

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
                                    focusedField = nil
                                    hideKeyboard()
                                    viewModel.login()
                                }) {
                                    HStack(spacing: 8) {
                                        if viewModel.isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        } else {
                                            Image(systemName: "arrow.right.to.line")
                                                .font(.system(size: 16, weight: .bold))
                                            Text("Đăng nhập")
                                                .font(.system(size: 15, weight: .bold))
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.appPrimaryPink)
                                    .cornerRadius(12)
                                    .shadow(color: Color.appPrimaryPink.opacity(0.35), radius: 8, x: 0, y: 4)
                                }
                                .disabled(viewModel.isLoading)
                                .id("loginButton")

                                // Nút Trợ giúp & Hướng dẫn sử dụng
                                Button(action: { showHelpSheet = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "questionmark.circle")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text("Trợ giúp & Hướng dẫn sử dụng")
                                            .font(.system(size: 13, weight: .bold))
                                    }
                                    .foregroundColor(Color.appPrimaryPink)
                                }
                                .padding(.top, 4)
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, focusedField != nil ? 18 : 28)
                            .frame(maxWidth: min(geometry.size.width - 32, 420))
                            .background(
                                colorScheme == .dark
                                    ? Color(hex: "#1E2430").opacity(0.96)
                                    : Color.white.opacity(0.96)
                            )
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(colorScheme == .dark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.15), radius: 18, x: 0, y: 8)
                            .padding(.horizontal, 14)
                            .id("loginCard")

                            Spacer(minLength: focusedField != nil ? 12 : 24)
                        }
                        .frame(minHeight: geometry.size.height)
                        .frame(width: geometry.size.width)
                    }
                    .onChange(of: focusedField) { newField in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                if newField == .password {
                                    proxy.scrollTo("passwordSection", anchor: .bottom)
                                } else if newField == .email {
                                    proxy.scrollTo("loginCard", anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
            hideKeyboard()
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
        .sheet(isPresented: $showResetPasswordSheet) {
            ResetPasswordView(viewModel: viewModel, onBack: { showResetPasswordSheet = false })
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
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hướng dẫn sử dụng hệ thống IT Service & Assets")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)

                        Group {
                            Text("1. Đăng nhập hệ thống:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("Sử dụng email hoặc số điện thoại đã được Ban Quản Trị Saigon Co.op cấp tài khoản để đăng nhập.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)

                            Text("2. Quản lý thiết bị:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("Tra cứu thông tin, vị trí, trạng thái sử dụng của thiết bị hoặc quét mã QR/Barcode trên tem dán.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)

                            Text("3. Trung tâm hỗ trợ (Ticket):")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("Gửi yêu cầu hỗ trợ sự cố thiết bị phần cứng, phần mềm tới bộ phận Kỹ thuật viên / Helpdesk để được xử lý kịp thời.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Trợ giúp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - SHEET QUÊN MẬT KHẨU
public struct ForgotPasswordSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
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
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Đặt lại mật khẩu")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Nhập email tài khoản của bạn để nhận liên kết khôi phục mật khẩu.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color.appPrimaryPink)
                            .frame(width: 20)
                        TextField("Email tài khoản", text: $email)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .accentColor(Color.appPrimaryPink)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1))

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
                            .frame(height: 46)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Quên mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - SHEET BẮT BUỘC ĐỔI MẬT KHẨU TẠM
public struct ForceChangePasswordSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    var email: String
    var onSubmit: (String) -> Void

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var errorMessage: String? = nil

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Đổi mật khẩu lần đầu")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Tài khoản của bạn đang sử dụng mật khẩu tạm do Quản trị viên cấp. Vui lòng đặt mật khẩu mới để tiếp tục.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color.appPrimaryPink)
                            .frame(width: 20)
                        SecureField("Mật khẩu mới", text: $newPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .accentColor(Color.appPrimaryPink)
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1))

                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(Color.appPrimaryPink)
                            .frame(width: 20)
                        SecureField("Xác nhận mật khẩu mới", text: $confirmPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .accentColor(Color.appPrimaryPink)
                    }
                    .padding(12)
                    .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(colorScheme == .dark ? Color(hex: "#334155") : Color.appCardBorder, lineWidth: 1))

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
                            .frame(height: 46)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Đổi mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
