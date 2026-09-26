import SwiftUI

struct InfoView: View {
    @ObservedObject var viewModel: AuthViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        
                        HStack {
                            Text("Thông Tin & Cài Đặt")
                                .font(.headline)
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.appPrimary)
                    }
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // 1. App Info Section
                            VStack(spacing: 12) {
                                Image("Logo") // Assuming "Logo" exists in Assets.xcassets, or use a placeholder
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(16)
                                    .shadow(radius: 2)
                                
                                Text("IT Service & Assets")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appPrimary)
                                
                                HStack {
                                    Text("Phiên bản \(appVersion) (\(appBuild))")
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.appPrimary.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            // 2. Account Info Section
                            InfoSection(title: "Thông tin tài khoản", icon: "person.crop.circle.fill", iconColor: .blue) {
                                InfoRow(title: "Họ và tên", value: viewModel.user.fullName)
                                InfoRow(title: "Email", value: viewModel.user.email)
                                InfoRow(title: "Đơn vị", value: viewModel.user.donVi.isEmpty ? "Chưa cập nhật" : viewModel.user.donVi)
                                InfoRow(title: "Công ty", value: viewModel.user.companyId)
                            }
                            
                            // 3. Developer & Support Section
                            InfoSection(title: "Hỗ trợ & Phát triển", icon: "headphones.circle.fill", iconColor: .green) {
                                InfoRow(title: "Phát triển bởi", value: "Saigon Co.op")
                                InfoButtonRow(title: "Website", icon: "globe", color: .blue) {
                                    openURL(urlString: "https://saigonco-op.com.vn")
                                }
                                InfoButtonRow(title: "Email hỗ trợ", icon: "envelope.fill", color: .orange) {
                                    openURL(urlString: "mailto:support@saigonco-op.com.vn")
                                }
                                InfoButtonRow(title: "Hotline", icon: "phone.fill", color: .green) {
                                    openURL(urlString: "tel://1900555568")
                                }
                            }
                            
                            // 4. Legal Section
                            InfoSection(title: "Pháp lý", icon: "doc.text.fill", iconColor: .gray) {
                                InfoButtonRow(title: "Chính sách bảo mật", icon: "shield.fill", color: .purple) {
                                    openURL(urlString: "https://saigonco-op.com.vn/privacy")
                                }
                                InfoButtonRow(title: "Điều khoản sử dụng", icon: "doc.plaintext.fill", color: .gray) {
                                    openURL(urlString: "https://saigonco-op.com.vn/terms")
                                }
                            }
                            
                            // 5. Actions
                            VStack(spacing: 12) {
                                Button(action: {
                                    shareApp()
                                }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Chia sẻ ứng dụng")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.appPrimary)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.appPrimary, lineWidth: 1)
                                    )
                                }
                                
                                Button(action: {
                                    viewModel.signOut()
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Đăng xuất")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            }
                            
                            Text("© 2026 Saigon Co.op. All rights reserved.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 16)
                                .padding(.bottom, 32)
                        }
                        .padding()
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Helpers
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private func openURL(urlString: String) {
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        let textToShare = "Trải nghiệm ứng dụng IT Service & Assets của Saigon Co.op!"
        let activityVC = UIActivityViewController(activityItems: [textToShare], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            
            // For iPad compatibility
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootVC.present(activityVC, animated: true, completion: nil)
        }
    }
}

// MARK: - Reusable Views

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18))
                Text(title)
                    .font(.headline)
                    .foregroundColor(.appPrimary)
                Spacer()
            }
            .padding()
            .background(Color.white)
            
            Divider()
                .padding(.leading, 40)
            
            VStack(spacing: 0) {
                content
            }
            .background(Color.white)
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        Divider()
            .padding(.leading, 16)
    }
}

struct InfoButtonRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14))
                }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        Divider()
            .padding(.leading, 50)
    }
}
