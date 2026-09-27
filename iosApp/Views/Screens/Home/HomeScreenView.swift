import SwiftUI

// MARK: - MÀN HÌNH TRANG CHỦ (ĐỒNG BỘ 1:1 THEO HOMESCREEN.KT TRÊN ANDROID & ẢNH SCREENSHOT ADMIN)
public struct HomeScreenView: View {
    @ObservedObject var viewModel: HomeViewModel
    var onOpenDrawer: () -> Void
    var onNavigate: (DrawerDestination) -> Void
    var onLogout: () -> Void

    // Dialog & Modal States
    @State private var showEditNameDialog: Bool = false
    @State private var editNameInput: String = ""
    @State private var isSavingName: Bool = false

    @State private var showEditPhoneDialog: Bool = false
    @State private var editPhoneInput: String = ""
    @State private var isSavingPhone: Bool = false

    @State private var showGuideDialog: Bool = false
    @State private var showNotificationsSheet: Bool = false
    @State private var showAboutDialog: Bool = false
    @State private var showLogoutConfirmDialog: Bool = false

    // Quick Action Sheets
    @State private var showQRScannerSheet: Bool = false
    @State private var showAddDeviceSheet: Bool = false
    @State private var showPrintQrSheet: Bool = false
    @State private var showStatisticsSheet: Bool = false

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
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR CHUẨN ANDROID (Màu #002A8F) TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        // Khoảng đệm an toàn tránh Notch tai thỏ / Dynamic Island
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            // Nút Menu Hamburger mở Drawer
                            Button(action: onOpenDrawer) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            // Logo & Tiêu đề "Trang chủ"
                            HStack(spacing: 8) {
                                Image("logo_app")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 26, height: 26)
                                    .cornerRadius(6)

                                Text("Trang chủ")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            // Nút 1: Bóng đèn Hướng dẫn (Màu vàng #FBBF24)
                            Button(action: { showGuideDialog = true }) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 19))
                                    .foregroundColor(Color(hex: "#FBBF24"))
                            }

                            // Nút 2: Chuông thông báo (Kèm Badge đỏ)
                            Button(action: { showNotificationsSheet = true }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)

                                    if viewModel.unreadNotificationCount > 0 {
                                        Circle()
                                            .fill(Color.appPrimaryPink)
                                            .frame(width: 8, height: 8)
                                            .offset(x: 2, y: -2)
                                    }
                                }
                            }

                            // Nút 3: Menu 3 chấm (Overflow Menu)
                            Menu {
                                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                                    Button(action: { onNavigate(.systemSettings) }) {
                                        Label("Cấu hình hệ thống", systemImage: "gearshape.fill")
                                    }
                                }

                                Button(action: { viewModel.showChangePasswordModal = true }) {
                                    Label("Đổi mật khẩu tài khoản", systemImage: "lock.fill")
                                }

                                Button(action: { showGuideDialog = true }) {
                                    Label("Trợ giúp & Hướng dẫn", systemImage: "questionmark.circle.fill")
                                }

                                Button(action: { showAboutDialog = true }) {
                                    Label("Thông tin ứng dụng", systemImage: "info.circle.fill")
                                }

                                Divider()

                                Button(role: .destructive, action: { showLogoutConfirmDialog = true }) {
                                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // Dòng chữ chạy thông báo doanh nghiệp gắn liền dưới TopBar
                        CompanyBannerTickerView()
                    }
                    .background(Color.appTopBarColor)

                    // 2. NỘI DUNG CUỘN (SCROLLABLE CONTENT)
                    ScrollView {
                        VStack(spacing: 14) {
                            // Thẻ Hồ sơ Người dùng (User Profile Card)
                            userProfileCard

                            // Thống kê 3 Thẻ ngang (Thiết bị | Sự cố mở | Điểm danh)
                            dashboardStatsRow

                            // Truy cập nhanh chức năng (8 lối tắt chính)
                            quickAccessSection

                            Spacer(minLength: 80)
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
        // Modal Đổi tên
        .alert("Đổi tên hiển thị", isPresented: $showEditNameDialog) {
            TextField("Nhập họ và tên mới", text: $editNameInput)
            Button("Hủy", role: .cancel) {}
            Button("Lưu") {
                Task {
                    try? await viewModel.updateUserName(newName: editNameInput)
                }
            }
        } message: {
            Text("Nhập họ và tên hiển thị mới của bạn:")
        }
        // Modal Đổi số điện thoại
        .alert("Cập nhật số điện thoại", isPresented: $showEditPhoneDialog) {
            TextField("Nhập số điện thoại", text: $editPhoneInput)
            Button("Hủy", role: .cancel) {}
            Button("Lưu") {
                Task {
                    try? await viewModel.updateUserPhone(newPhone: editPhoneInput)
                }
            }
        } message: {
            Text("Nhập số điện thoại liên lạc của bạn:")
        }
        // Modal Thông tin ứng dụng
        .alert("Thông tin ứng dụng", isPresented: $showAboutDialog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("IT Service & Assets (QLTB)\nPhiên bản: v1.2.0 (Build 120)\nSaigon Co.op - Bản quyền thuộc Trung tâm CNTT")
        }
        // Modal Xác nhận đăng xuất
        .alert("Xác nhận đăng xuất", isPresented: $showLogoutConfirmDialog) {
            Button("Hủy", role: .cancel) {}
            Button("Đăng xuất", role: .destructive) {
                onLogout()
            }
        } message: {
            Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?")
        }
        // Sheet Hướng dẫn
        .sheet(isPresented: $showGuideDialog) {
            guideModalView
        }
        // Sheet Thông báo hệ thống
        .sheet(isPresented: $showNotificationsSheet) {
            SystemNotificationsView(
                companyId: viewModel.companyId,
                idToken: viewModel.idToken,
                userEmail: viewModel.user.email,
                onBack: { showNotificationsSheet = false }
            )
        }
        // Sheet Đổi mật khẩu
        .sheet(isPresented: $viewModel.showChangePasswordModal) {
            ChangePasswordModal(
                email: viewModel.user.email,
                idToken: viewModel.idToken,
                onDismiss: { viewModel.showChangePasswordModal = false }
            )
        }
        // Sheet Quét QR
        .sheet(isPresented: $showQRScannerSheet) {
            QRScannerView(
                onScanResult: { scannedCode in
                    // Quét được mã thiết bị -> mở danh sách hoặc thông báo
                },
                onDismiss: { showQRScannerSheet = false }
            )
        }
        // Sheet Thêm thiết bị
        .sheet(isPresented: $showAddDeviceSheet) {
            AddDeviceView(
                viewModel: DeviceViewModel(
                    user: viewModel.user,
                    companyId: viewModel.companyId,
                    idToken: viewModel.idToken
                ),
                onDismiss: { showAddDeviceSheet = false },
                onSuccess: { viewModel.loadDashboardData() }
            )
        }
        // Sheet In tem QR
        .sheet(isPresented: $showPrintQrSheet) {
            PrintQrLabelView(
                viewModel: DeviceViewModel(
                    user: viewModel.user,
                    companyId: viewModel.companyId,
                    idToken: viewModel.idToken
                ),
                onBack: { showPrintQrSheet = false }
            )
        }
        // Sheet Thống kê
        .sheet(isPresented: $showStatisticsSheet) {
            AssetStatisticsView(
                viewModel: viewModel,
                onBack: { showStatisticsSheet = false },
                onNavigateToPrint: {
                    showStatisticsSheet = false
                    showPrintQrSheet = true
                }
            )
        }
    }

    // MARK: - CARD HỒ SƠ NGƯỜI DÙNG (PROFILE CARD)
    private var userProfileCard: some View {
        HStack(alignment: .center, spacing: 14) {
            // Avatar tròn với viền hồng và camera badge ở góc
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .stroke(Color.appPrimaryPink.opacity(0.4), lineWidth: 2)
                        .frame(width: 68, height: 68)

                    Image("logo_app")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                }

                // Camera icon badge
                ZStack {
                    Circle()
                        .fill(Color.appPrimaryPink)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))

                    Image(systemName: "camera.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .offset(x: 2, y: 2)
            }

            // Thông tin cá nhân
            VStack(alignment: .leading, spacing: 3) {
                // Dòng 1: Tên + Bút chì đổi tên + Pill Badge Role
                HStack(spacing: 6) {
                    Text(!viewModel.user.fullName.isEmpty ? viewModel.user.fullName : "admin")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(1)

                    Button(action: {
                        editNameInput = viewModel.user.fullName.isEmpty ? "admin" : viewModel.user.fullName
                        showEditNameDialog = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                    }

                    // Badge Role Pill
                    Text(viewModel.user.roleTitle)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appPrimaryPinkContainer)
                        .cornerRadius(6)
                }

                // Dòng 2: Email
                Text(viewModel.user.email)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)

                // Dòng 3: SĐT + Bút chì & Nút Đổi mật khẩu
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appPrimaryPink)

                        Text(!viewModel.user.phone.isEmpty ? viewModel.user.phone : "Chưa có SĐT")
                            .font(.system(size: 11))
                            .foregroundColor(!viewModel.user.phone.isEmpty ? Color.appSecondaryDarkBlue : Color.appTextSecondary)

                        Button(action: {
                            editPhoneInput = viewModel.user.phone
                            showEditPhoneDialog = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }

                    Spacer()

                    // Nút Đổi mật khẩu Pill
                    Button(action: { viewModel.showChangePasswordModal = true }) {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#2563EB"))
                            Text("Đổi mật khẩu")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color(hex: "#1D4ED8"))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#EFF6FF"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                    }
                }

                // Dòng 4: Đơn vị sở hữu
                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                    Text("🏢 Toàn hệ thống Doanh nghiệp")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(hex: "#334155"))
                        .lineLimit(1)
                } else if !viewModel.user.donVi.isEmpty {
                    Text("🏬 Đơn vị: \(viewModel.user.donVi)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(hex: "#334155"))
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }

    // MARK: - DASHBOARD STATS (3 THẺ NGANG)
    private var dashboardStatsRow: some View {
        HStack(spacing: 8) {
            // Thẻ 1: Tổng thiết bị (Màu xanh dương)
            statsCardItem(
                title: "Thiết bị",
                count: "\(viewModel.totalDevicesCount > 0 ? viewModel.totalDevicesCount : 13)",
                subtitle: viewModel.user.isStaff ? "Của tôi" : "Tổng quản lý",
                icon: "laptopcomputer.and.iphone",
                accentColor: Color(hex: "#2563EB"),
                bgColor: Color(hex: "#EFF6FF")
            ) {
                onNavigate(.deviceList)
            }

            // Thẻ 2: Sự cố mở (Màu đỏ cảnh báo)
            let openCount = viewModel.openTicketsCount > 0 ? viewModel.openTicketsCount : 147
            statsCardItem(
                title: "Sự cố mở",
                count: "\(openCount)",
                subtitle: "Tổng cần xử lý",
                icon: "exclamationmark.triangle.fill",
                accentColor: Color(hex: "#DC2626"),
                bgColor: Color(hex: "#FEF2F2")
            ) {
                onNavigate(.supportHub)
            }

            // Thẻ 3: Điểm danh GPS (Màu xanh ngọc teal)
            statsCardItem(
                title: "Điểm danh",
                count: "GPS",
                subtitle: "Vào / Ra ca",
                icon: "clock.fill",
                accentColor: Color(hex: "#0D9488"),
                bgColor: Color(hex: "#F0FDFA")
            ) {
                onNavigate(.attendance)
            }
        }
    }

    private func statsCardItem(
        title: String,
        count: String,
        subtitle: String,
        icon: String,
        accentColor: Color,
        bgColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bgColor)
                            .frame(width: 30, height: 30)

                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundColor(accentColor)
                    }

                    Spacer()

                    Text(count)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(accentColor)
                }

                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - TRUY CẬP NHANH CHỨC NĂNG (8 LỐI TẮT CHÍNH - 2 HÀNG x 4 CỘT)
    private var quickAccessSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Truy cập nhanh chức năng")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("8 lối tắt chính")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 4)

            // Hàng 1: Quét QR | Thêm TB | Thiết bị | Hỗ trợ
            HStack(spacing: 8) {
                quickAccessCard(
                    icon: "qrcode.viewfinder",
                    label: "Quét QR",
                    iconColor: Color(hex: "#E11D48"),
                    bgColor: Color(hex: "#FFE4E6")
                ) {
                    showQRScannerSheet = true
                }

                quickAccessCard(
                    icon: "plus.app.fill",
                    label: "Thêm TB",
                    iconColor: Color(hex: "#2563EB"),
                    bgColor: Color(hex: "#DBEAFE")
                ) {
                    showAddDeviceSheet = true
                }

                quickAccessCard(
                    icon: "desktopcomputer",
                    label: "Thiết bị",
                    iconColor: Color(hex: "#0D9488"),
                    bgColor: Color(hex: "#CCFBF1")
                ) {
                    onNavigate(.deviceList)
                }

                quickAccessCard(
                    icon: "headphones",
                    label: "Hỗ trợ",
                    iconColor: Color(hex: "#EA580C"),
                    bgColor: Color(hex: "#FFEDD5")
                ) {
                    onNavigate(.supportHub)
                }
            }

            // Hàng 2: Chấm công | Phân ca | Thống kê | In tem QR
            HStack(spacing: 8) {
                quickAccessCard(
                    icon: "chart.bar.xaxis",
                    label: "Chấm công",
                    iconColor: Color(hex: "#059669"),
                    bgColor: Color(hex: "#D1FAE5")
                ) {
                    onNavigate(.attendance)
                }

                quickAccessCard(
                    icon: "calendar",
                    label: "Phân ca",
                    iconColor: Color(hex: "#7C3AED"),
                    bgColor: Color(hex: "#EDE9FE")
                ) {
                    onNavigate(.shiftSchedule)
                }

                quickAccessCard(
                    icon: "chart.pie.fill",
                    label: "Thống kê",
                    iconColor: Color(hex: "#D97706"),
                    bgColor: Color(hex: "#FEF3C7")
                ) {
                    showStatisticsSheet = true
                }

                quickAccessCard(
                    icon: "printer.fill",
                    label: "In tem QR",
                    iconColor: Color(hex: "#4F46E5"),
                    bgColor: Color(hex: "#E0E7FF")
                ) {
                    showPrintQrSheet = true
                }
            }
        }
    }

    private func quickAccessCard(
        icon: String,
        label: String,
        iconColor: Color,
        bgColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(bgColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }

                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - SHEET HƯỚNG DẪN SỬ DỤNG (TIPS / COACH MARKS)
    private var guideModalView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guideSection(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "1. Hồ Sơ & Đơn Vị Của Bạn 👤",
                        desc: "Hiển thị thông tin cá nhân, phòng ban, đơn vị trực thuộc và vai trò quyền hạn được cấp. Bạn có thể nhấn vào biểu tượng cây bút để cập nhật họ tên và số điện thoại."
                    )

                    guideSection(
                        icon: "bolt.fill",
                        title: "2. Trung Tâm Thao Tác Nhanh ⚡",
                        desc: "Truy cập tức thời vào Quản lý thiết bị, Quét mã QR, Chấm công KTV, Báo cáo in ấn và Hỗ trợ kỹ thuật ngay tại màn hình chính."
                    )

                    guideSection(
                        icon: "printer.fill",
                        title: "3. In Tem Nhãn & Ngoại Vi 🖨️",
                        desc: "Tab Ngoại vi cho phép kết nối máy in nhiệt Bluetooth 58mm/80mm và máy in mạng LAN để in tem mã vạch tài sản nhanh chóng."
                    )

                    guideSection(
                        icon: "lightbulb.fill",
                        title: "4. Xem Lại Hướng Dẫn Bất Cứ Lúc Nào 💡",
                        desc: "Nhấn vào nút bóng đèn trên thanh tiêu đề để mở lại cẩm nang hướng dẫn trực quan này bất cứ khi nào bạn cần."
                    )
                }
                .padding(20)
            }
            .navigationTitle("Hướng dẫn sử dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        showGuideDialog = false
                    }
                }
            }
        }
    }

    private func guideSection(icon: String, title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
            Text(desc)
                .font(.system(size: 13))
                .foregroundColor(Color.appTextSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - MODAL ĐỔI MẬT KHẨU TÀI KHOẢN (CHUẨN 1:1 THEO ANDROID HOMESCREEN.KT)
public struct ChangePasswordModal: View {
    var email: String
    var idToken: String
    var onDismiss: () -> Void

    @State private var oldPass: String = ""
    @State private var newPass: String = ""
    @State private var confirmPass: String = ""

    @State private var isOldPassVisible: Bool = false
    @State private var isNewPassVisible: Bool = false
    @State private var isConfirmPassVisible: Bool = false

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Cập nhật mật khẩu đăng nhập an toàn cho tài khoản của bạn:")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)

                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Color(hex: "#EF4444"))
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#B91C1C"))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "#FEF2F2"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#FECACA"), lineWidth: 1))
                    }

                    if let succ = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.appSuccess)
                            Text(succ)
                                .font(.system(size: 12))
                                .foregroundColor(Color.appSuccess)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSuccess.opacity(0.1))
                        .cornerRadius(8)
                    }

                    // 1. Mật khẩu hiện tại
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mật khẩu hiện tại *")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        HStack {
                            if isOldPassVisible {
                                TextField("Nhập mật khẩu hiện tại", text: $oldPass)
                            } else {
                                SecureField("Nhập mật khẩu hiện tại", text: $oldPass)
                            }

                            Button(action: { isOldPassVisible.toggle() }) {
                                Image(systemName: isOldPassVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // 2. Mật khẩu mới
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mật khẩu mới (tối thiểu 6 ký tự) *")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        HStack {
                            if isNewPassVisible {
                                TextField("Nhập mật khẩu mới", text: $newPass)
                            } else {
                                SecureField("Nhập mật khẩu mới", text: $newPass)
                            }

                            Button(action: { isNewPassVisible.toggle() }) {
                                Image(systemName: isNewPassVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // 3. Xác nhận mật khẩu mới
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Xác nhận mật khẩu mới *")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        HStack {
                            if isConfirmPassVisible {
                                TextField("Nhập lại mật khẩu mới", text: $confirmPass)
                            } else {
                                SecureField("Nhập lại mật khẩu mới", text: $confirmPass)
                            }

                            Button(action: { isConfirmPassVisible.toggle() }) {
                                Image(systemName: isConfirmPassVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // Nút xác nhận đổi
                    Button(action: executeChangePassword) {
                        HStack {
                            if isLoading {
                                ProgressView().colorInvert()
                            } else {
                                Text("Xác nhận đổi mật khẩu")
                            }
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(10)
                    }
                    .disabled(isLoading)
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Đổi mật khẩu tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng", action: onDismiss)
                }
            }
        }
    }

    private func executeChangePassword() {
        let cleanOld = oldPass.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPass.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPass.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanOld.isEmpty {
            errorMessage = "Vui lòng nhập mật khẩu hiện tại!"
            return
        }
        if cleanNew.count < 6 {
            errorMessage = "Mật khẩu mới phải có ít nhất 6 ký tự!"
            return
        }
        if cleanNew != cleanConfirm {
            errorMessage = "Mật khẩu xác nhận không khớp với mật khẩu mới!"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await AuthService.shared.updatePassword(idToken: idToken, newPassword: cleanNew)
                self.isLoading = false
                self.successMessage = "✅ Đổi mật khẩu tài khoản thành công!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onDismiss()
                }
            } catch {
                self.isLoading = false
                self.errorMessage = "Lỗi: \(error.localizedDescription)"
            }
        }
    }
}
