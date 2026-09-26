import SwiftUI

struct ResetPasswordView: View {
    @ObservedObject var viewModel: AuthViewModel
    var onBack: () -> Void
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Text("Khôi phục mật khẩu")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                    }
                    .background(Color.appPrimary)
                    
                    VStack(spacing: 20) {
                        Text("Nhập email của bạn để nhận liên kết khôi phục mật khẩu.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                            .padding(.horizontal)
                        
                        if let success = successMessage {
                            Text(success)
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        CustomTextField(icon: "envelope.fill", placeholder: "Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.horizontal, 20)
                        
                        Button(action: sendResetEmail) {
                            HStack {
                                if isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("GỬI YÊU CẦU")
                                        .fontWeight(.bold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appPrimary)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    private func sendResetEmail() {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEmail.isEmpty {
            errorMessage = "Vui lòng nhập email"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(FirebaseConfig.apiKey)")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body: [String: Any] = [
                    "requestType": "PASSWORD_RESET",
                    "email": cleanEmail
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.successMessage = "Đã gửi email khôi phục. Vui lòng kiểm tra hộp thư của bạn."
                    }
                } else {
                    let errMap = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    let errorNode = errMap?["error"] as? [String: Any]
                    let msg = errorNode?["message"] as? String ?? "Lỗi không xác định"
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Gửi thất bại: \(msg)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CustomTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 24, height: 24)
            
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}
