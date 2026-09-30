import SwiftUI

public struct InfoView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    var onLogout: () -> Void
    
    @State private var showingLogoutConfirm = false
    
    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void, onLogout: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
        self.onLogout = onLogout
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        topBar
                    }
                    .background(Color.appTopBarColor)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            userProfileSection
                            appInfoSection
                            actionsSection
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert(isPresented: $showingLogoutConfirm) {
            Alert(
                title: Text("Đăng xuất"),
                message: Text("Bạn có chắc chắn muốn đăng xuất không?"),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    onLogout()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            Spacer()
            Text("Thông tin")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Color.clear.frame(width: 24, height: 24)
        }
        .padding()
    }
    
    private var userProfileSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                Text(getInitials(authViewModel.currentUser?.fullName))
                    .font(.title)
                    .foregroundColor(Color.appPrimary)
                    .bold()
            }
            
            VStack(spacing: 4) {
                Text(authViewModel.currentUser?.fullName ?? "N/A")
                    .font(.title3)
                    .bold()
                    .foregroundColor(Color.appTextPrimary)
                Text(authViewModel.currentUser?.email ?? "N/A")
                    .font(.subheadline)
                    .foregroundColor(Color.appTextSecondary)
                
                Text(authViewModel.currentUser?.role ?? "User")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.appPrimary.opacity(0.1))
                    .foregroundColor(Color.appPrimary)
                    .cornerRadius(12)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .padding(.horizontal)
    }
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THÔNG TIN ỨNG DỤNG")
                .font(.caption)
                .foregroundColor(Color.appTextSecondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            VStack(spacing: 0) {
                infoRow(title: "Tên ứng dụng", value: "IT Service & Assets")
                Divider().padding(.leading, 16)
                infoRow(title: "Phiên bản", value: getAppVersion())
                Divider().padding(.leading, 16)
                infoRow(title: "Mã công ty", value: authViewModel.currentUser?.companyId ?? "SGCOOP")
            }
            .background(Color.appSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                actionRow(icon: "lock", title: "Đổi mật khẩu") {
                    // TBD
                }
                Divider().padding(.leading, 48)
                actionRow(icon: "doc.text", title: "Điều khoản sử dụng") {
                    // TBD
                }
                Divider().padding(.leading, 48)
                actionRow(icon: "shield", title: "Chính sách bảo mật") {
                    // TBD
                }
                Divider().padding(.leading, 48)
                actionRow(icon: "star", title: "Đánh giá ứng dụng") {
                    // TBD
                }
                Divider().padding(.leading, 48)
                Button(action: { showingLogoutConfirm = true }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        Text("Đăng xuất")
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                }
            }
            .background(Color.appSurface)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .padding(.horizontal)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(Color.appTextPrimary)
            Spacer()
            Text(value)
                .foregroundColor(Color.appTextSecondary)
        }
        .padding()
    }
    
    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(Color.appTextSecondary)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.appTextSecondary)
                    .font(.caption)
            }
            .padding()
        }
    }
    
    private func getInitials(_ name: String?) -> String {
        guard let name = name, !name.isEmpty else { return "U" }
        let parts = name.components(separatedBy: " ")
        if parts.count > 1 {
            let first = parts.first?.prefix(1) ?? ""
            let last = parts.last?.prefix(1) ?? ""
            return String(first + last).uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
    
    private func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
