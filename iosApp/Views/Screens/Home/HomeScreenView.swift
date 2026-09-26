import SwiftUI

// MARK: - MÀN HÌNH TRANG CHỦ (ĐỒNG BỘ 1:1 VỚI HOMESCREEN.KT TRÊN ANDROID)
public struct HomeScreenView: View {
    @ObservedObject var viewModel: HomeViewModel
    var onOpenDrawer: () -> Void
    var onNavigate: (DrawerDestination) -> Void
    var onLogout: () -> Void

    public init(
        viewModel: HomeViewModel,
        onOpenDrawer: @escaping () -> Void,
        onNavigate: @escaping (DrawerDestination) -> Void,
        onLogout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onOpenDrawer = onOpenDrawer
        self.onNavigate = onNavigate
        self.onLogout = onLogout
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. TOP BAR CHUẨN ANDROID
                HStack(spacing: 12) {
                    Button(action: onOpenDrawer) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 8) {
                        Image("logo_app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)

                        Text("Saigon Co.op")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Chuông thông báo
                    Button(action: {}) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }

                    // Nút Đăng xuất nhanh
                    Button(action: onLogout) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.appTopBarColor)

                // 2. NỘI DUNG CUỘN
                ScrollView {
                    VStack(spacing: 14) {
                        // Card Thông tin cá nhân
                        userProfileCard

                        // Dashboard Thống kê (Thiết bị & Ticket)
                        dashboardStatsRow

                        // Lối tắt truy cập nhanh (Quick Access)
                        quickAccessSection

                        Spacer(minLength: 20)
                    }
                    .padding(14)
                }
            }
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
        .sheet(isPresented: $viewModel.showChangePasswordModal) {
            ChangePasswordModal(
                email: viewModel.user.email,
                idToken: viewModel.idToken,
                onDismiss: { viewModel.showChangePasswordModal = false }
            )
        }
    }

    // MARK: - CARD HỒ SƠ NGƯỜI DÙNG
    private var userProfileCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 54, height: 54)
                    .foregroundColor(Color.appSecondaryDarkBlue)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(!viewModel.user.fullName.isEmpty ? viewModel.user.fullName : "Người dùng")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        Text(viewModel.user.role.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(6)
                    }

                    Text("MNV: \(viewModel.user.mnvDisplay) • \(viewModel.user.email)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    if !viewModel.user.donVi.isEmpty {
                        Text("Đơn vị: \(viewModel.user.donVi)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { viewModel.showChangePasswordModal = true }) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .padding(8)
                        .background(Color.appCardBorder.opacity(0.4))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - HÀNG THỐNG KÊ (DASHBOARD STATS)
    private var dashboardStatsRow: some View {
        HStack(spacing: 12) {
            // Thẻ Thiết bị
            Button(action: { onNavigate(.deviceList) }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    Text("\(viewModel.totalDevicesCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Text("Tổng thiết bị")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
            }

            // Thẻ Hỗ trợ Kỹ thuật
            Button(action: { onNavigate(.supportHub) }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "headphones")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appPrimaryPink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    Text("\(viewModel.openTicketsCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)

                    Text("Yêu cầu hỗ trợ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - LỐI TẮT TRUY CẬP NHANH (QUICK ACCESS)
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lối tắt truy cập nhanh")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickActionItem(title: "In tem QR", icon: "printer.fill", color: .appInfo) {
                    onNavigate(.printBarcode)
                }

                quickActionItem(title: "Chấm công", icon: "person.badge.shield.checkmark.fill", color: .appSuccess) {
                    onNavigate(.attendance)
                }

                quickActionItem(title: "Lịch ca", icon: "calendar", color: .appSecondaryDarkBlue) {
                    onNavigate(.shiftSchedule)
                }

                quickActionItem(title: "Báo cáo SLA", icon: "star.fill", color: .statusRepair) {
                    onNavigate(.supportRating)
                }

                quickActionItem(title: "KTV Online", icon: "map.fill", color: .statusInUse) {
                    onNavigate(.ktvMonitor)
                }

                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                    quickActionItem(title: "Duyệt NV", icon: "person.badge.plus", color: .appPrimaryPink, badge: viewModel.pendingStaffCount > 0 ? "\(viewModel.pendingStaffCount)" : nil) {
                        onNavigate(.approveStaff)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func quickActionItem(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 46, height: 46)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                        .frame(width: 46, height: 46)

                    if let b = badge {
                        Text(b)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.appPrimaryPink)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - MODAL ĐỔI MẬT KHẨU CÁ NHÂN
public struct ChangePasswordModal: View {
    var email: String
    var idToken: String
    var onDismiss: () -> Void

    @State private var newPass: String = ""
    @State private var confirmPass: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Đổi mật khẩu tài khoản")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                SecureField("Mật khẩu mới", text: $newPass)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                SecureField("Xác nhận mật khẩu", text: $confirmPass)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                if let err = errorMessage {
                    Text(err).font(.system(size: 12)).foregroundColor(.red)
                }

                if let succ = successMessage {
                    Text(succ).font(.system(size: 12)).foregroundColor(.green)
                }

                Button(action: {
                    if newPass.count < 6 {
                        errorMessage = "Mật khẩu phải từ 6 ký tự trở lên!"
                        return
                    }
                    if newPass != confirmPass {
                        errorMessage = "Mật khẩu không khớp!"
                        return
                    }
                    isLoading = true
                    Task {
                        do {
                            try await AuthService.shared.updatePassword(idToken: idToken, newPassword: newPass)
                            self.successMessage = "Đổi mật khẩu thành công!"
                            self.isLoading = false
                        } catch {
                            self.isLoading = false
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text("Lưu mật khẩu mới")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng", action: onDismiss)
                }
            }
        }
    }
}
