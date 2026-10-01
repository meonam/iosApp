import SwiftUI
import UIKit

// MARK: - MÀN HÌNH TRANG CHỦ (ĐỒNG BỘ 1:1 THEO HOMESCREEN.KT TRÊN ANDROID)
public struct HomeScreenView: View {
    @ObservedObject var viewModel: HomeViewModel
    var onOpenDrawer: () -> Void
    var onNavigate: (DrawerDestination) -> Void
    var onLogout: () -> Void

    // Dialog & Modal States
    @State private var editNameInput: String = ""
    @State private var isSavingName: Bool = false
    @State private var nameError: String? = nil

    @State private var editPhoneInput: String = ""
    @State private var isSavingPhone: Bool = false
    @State private var phoneError: String? = nil

    @State private var showAboutDialog: Bool = false
    @State private var showLogoutConfirmDialog: Bool = false
    @State private var accessRestrictedMessage: String? = nil

    // Image Picker for Avatar
    @State private var selectedAvatarImage: UIImage? = nil

    // Single Active Sheet Manager (giải quyết triệt để lỗi nuốt sheet trong SwiftUI)
    enum HomeActiveSheet: Identifiable {
        case imagePicker
        case editName
        case editPhone
        case guide
        case notifications
        case changePassword
        case qrScanner
        case detail(deviceId: String)
        case addDevice(initialId: String)
        case printQr
        case statistics

        var id: String {
            switch self {
            case .imagePicker: return "imagePicker"
            case .editName: return "editName"
            case .editPhone: return "editPhone"
            case .guide: return "guide"
            case .notifications: return "notifications"
            case .changePassword: return "changePassword"
            case .qrScanner: return "qrScanner"
            case .detail(let id): return "detail_\(id)"
            case .addDevice(let id): return "addDevice_\(id)"
            case .printQr: return "printQr"
            case .statistics: return "statistics"
            }
        }
    }

    @State private var activeSheet: HomeActiveSheet? = nil

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
                    // 1. TOP BAR CHUẨN ANDROID (#002A8F) KÈM STATUS BAR INSETS
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 4) {
                            // Nút Hamburger mở Drawer
                            Button(action: onOpenDrawer) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }

                            // Logo & Tiêu đề "Trang chủ"
                            HStack(spacing: 8) {
                                Image("logo_app")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(6)

                                Text("Trang chủ")
                                    .font(.system(size: 18, weight: .heavy))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Nút 1: Bóng đèn Hướng dẫn (Màu vàng #FBBF24, 20dp)
                            Button(action: { activeSheet = .guide }) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "#FBBF24"))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }

                            // Nút 2: Chuông thông báo (Kèm Badge số lượng màu hồng #F40266)
                            Button(action: { activeSheet = .notifications }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: "bell.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)

                                    if viewModel.unreadNotificationCount > 0 {
                                        Text(viewModel.unreadNotificationCount > 99 ? "99+" : "\(viewModel.unreadNotificationCount)")
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.appPrimaryPink)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -6)
                                    }
                                }
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                            }

                            // Nút 3: Menu mở rộng 3 chấm (Overflow Menu)
                            Menu {
                                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                                    Button(action: { onNavigate(.systemSettings) }) {
                                        Label("Cấu hình hệ thống", systemImage: "gearshape.fill")
                                    }
                                }

                                Button(action: { activeSheet = .changePassword }) {
                                    Label("Đổi mật khẩu tài khoản", systemImage: "lock.fill")
                                }

                                Button(action: { onNavigate(.help) }) {
                                    Label("Trợ giúp & Hướng dẫn", systemImage: "questionmark.circle.fill")
                                }

                                Button(action: { onNavigate(.appInfo) }) {
                                    Label("Thông tin ứng dụng", systemImage: "info.circle.fill")
                                }

                                Divider()

                                Button(role: .destructive, action: { showLogoutConfirmDialog = true }) {
                                    Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .rotationEffect(.degrees(90))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)

                        // Dòng chữ chạy thông báo doanh nghiệp gắn liền ngay dưới TopBar (chỉ hiển thị khi Admin bật)
                        if viewModel.isCompanyBannerActive && !viewModel.companyBannerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            CompanyBannerTickerView(
                                text: viewModel.companyBannerText,
                                type: CompanyBannerTickerView.BannerType(rawValue: viewModel.companyBannerType) ?? .info,
                                isActive: viewModel.isCompanyBannerActive
                            )
                        }
                    }
                    .background(Color.appTopBarColor)

                    // 2. NỘI DUNG CUỘN (SCROLLABLE CONTENT)
                    ScrollView {
                        VStack(spacing: 16) {
                            // Thẻ Hồ sơ Người dùng (User Profile Card)
                            userProfileCard

                            // 3 Thẻ thống kê ngang (Thiết bị | Sự cố mở | Điểm danh)
                            dashboardStatsRow

                            // Trung tâm thao tác nhanh (8 lối tắt chính)
                            quickAccessSection

                            Spacer(minLength: 80)
                        }
                        .padding(16)
                    }
                }

                // Modal thông báo "Truy cập bị giới hạn" (chuẩn Android)
                if let restrictedMsg = accessRestrictedMessage {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    accessRestrictedDialog(message: restrictedMsg)
                        .padding(.horizontal, 28)
                        .zIndex(50)
                }
            }
        }
        .onAppear {
            viewModel.loadDashboardData()
        }
        // Sheet Thông tin ứng dụng
        .alert("Thông tin ứng dụng", isPresented: $showAboutDialog) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("IT Service & Assets\nPhiên bản: v1.2.0 (Build 120)\nSaigon Co.op - Bản quyền thuộc Trung tâm CNTT")
        }
        // Alert Xác nhận đăng xuất
        .alert("Đăng xuất", isPresented: $showLogoutConfirmDialog) {
            Button("Hủy", role: .cancel) {}
            Button("Đăng xuất", role: .destructive) {
                onLogout()
            }
        } message: {
            Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này?")
        }
        // SINGLE SHEET PRESENTER - Đảm bảo 100% modal/sheet hoạt động mượt mà không bị nuốt
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .imagePicker:
                ImagePickerView(selectedImage: $selectedAvatarImage) { image in
                    Task {
                        try? await viewModel.uploadAvatarImage(image)
                    }
                }
            case .editName:
                editNameSheetView
            case .editPhone:
                editPhoneSheetView
            case .guide:
                guideModalView
            case .notifications:
                SystemNotificationsView(
                    companyId: viewModel.companyId,
                    idToken: viewModel.idToken,
                    userEmail: viewModel.user.email,
                    userRole: viewModel.user.role,
                    userDept: viewModel.user.departmentId.isEmpty ? viewModel.user.donVi : viewModel.user.departmentId,
                    userFullName: viewModel.user.fullName,
                    isAdmin: viewModel.user.isAdmin,
                    isHelpDesk: viewModel.user.isHelpDesk,
                    isManager: viewModel.user.isManager,
                    companyBannerText: viewModel.companyBannerText,
                    companyBannerType: viewModel.companyBannerType,
                    isCompanyBannerActive: viewModel.isCompanyBannerActive,
                    onBannerUpdated: { text, type, active in
                        viewModel.companyBannerText = text
                        viewModel.companyBannerType = type
                        viewModel.isCompanyBannerActive = active
                    },
                    onBack: {
                        activeSheet = nil
                        Task { await viewModel.fetchUnreadNotifications() }
                    }
                )
            case .changePassword:
                ChangePasswordModalView(
                    viewModel: viewModel,
                    onDismiss: { activeSheet = nil }
                )
            case .qrScanner:
                QRScannerView(
                    viewModel: DeviceViewModel(
                        user: viewModel.user,
                        companyId: viewModel.companyId,
                        idToken: viewModel.idToken
                    ),
                    onScanResult: { _ in },
                    onDismiss: { activeSheet = nil },
                    onNavigateToDetail: { devId in
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .detail(deviceId: devId)
                        }
                    },
                    onNavigateToAdd: { newCode in
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .addDevice(initialId: newCode)
                        }
                    }
                )
            case .detail(let devId):
                DeviceDetailView(
                    viewModel: DeviceViewModel(
                        user: viewModel.user,
                        companyId: viewModel.companyId,
                        idToken: viewModel.idToken
                    ),
                    deviceId: devId,
                    onBack: { activeSheet = nil }
                )
            case .addDevice(let initId):
                AddDeviceView(
                    viewModel: DeviceViewModel(
                        user: viewModel.user,
                        companyId: viewModel.companyId,
                        idToken: viewModel.idToken
                    ),
                    initialDeviceId: initId,
                    onBack: { activeSheet = nil },
                    onSuccess: { _ in
                        activeSheet = nil
                        viewModel.loadDashboardData()
                    }
                )
            case .printQr:
                PrintQrLabelView(
                    viewModel: DeviceViewModel(
                        user: viewModel.user,
                        companyId: viewModel.companyId,
                        idToken: viewModel.idToken
                    ),
                    onBack: { activeSheet = nil }
                )
            case .statistics:
                AssetStatisticsView(
                    viewModel: viewModel,
                    onBack: { activeSheet = nil },
                    onNavigateToPrint: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            activeSheet = .printQr
                        }
                    }
                )
            }
        }
    }

    // MARK: - 1. THẺ HỒ SƠ NGƯỜI DÙNG (PROFILE CARD)
    private var userProfileCard: some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar tròn 64dp với viền hồng, camera badge và hiển thị ảnh Cloudinary
            Button(action: { activeSheet = .imagePicker }) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .stroke(Color.appPrimaryPink.opacity(0.4), lineWidth: 2)
                            .frame(width: 64, height: 64)

                        if !viewModel.user.avatarUrl.isEmpty, let url = URL(string: viewModel.user.avatarUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                case .failure, .empty:
                                    Image("logo_app")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 56, height: 56)
                                        .clipShape(Circle())
                                @unknown default:
                                    ProgressView().frame(width: 56, height: 56)
                                }
                            }
                        } else {
                            Image("logo_app")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        }

                        if viewModel.isUploadingAvatar {
                            Circle().fill(Color.black.opacity(0.45)).frame(width: 56, height: 56)
                            ProgressView().colorInvert()
                        }
                    }

                    // Camera icon badge
                    ZStack {
                        Circle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))

                        Image(systemName: "camera.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                    }
                    .offset(x: 2, y: 2)
                }
            }

            // Thông tin cá nhân theo Bố cục Phân tầng (Tiered Hierarchy)
            VStack(alignment: .leading, spacing: 4) {
                // Tầng 1: Huy hiệu vai trò (Role Badge)
                roleBadgeView

                // Tầng 2: Họ và tên người dùng (Chiếm trọn bề ngang, tối đa 2 dòng không bao giờ mất chữ) + Bút chì đổi tên
                HStack(alignment: .center, spacing: 4) {
                    let displayName = !viewModel.user.fullName.isEmpty ? viewModel.user.fullName : (viewModel.user.email.components(separatedBy: "@").first ?? "Người dùng")
                    Text(displayName)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(Color.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: {
                        editNameInput = displayName
                        nameError = nil
                        activeSheet = .editName
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }

                    Spacer(minLength: 0)
                }

                // Tầng 3: Email
                Text(viewModel.user.email)
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.secondary)
                    .lineLimit(1)

                // Tầng 4: SĐT + Bút chì & Nút Đổi mật khẩu
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appPrimaryPink)

                        Text(!viewModel.user.phone.isEmpty ? viewModel.user.phone : "Chưa có SĐT")
                            .font(.system(size: 11))
                            .foregroundColor(!viewModel.user.phone.isEmpty ? Color.primary : Color.secondary)

                        Button(action: {
                            editPhoneInput = viewModel.user.phone
                            phoneError = nil
                            activeSheet = .editPhone
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                                .frame(width: 22, height: 22)
                                .contentShape(Rectangle())
                        }
                    }

                    Spacer()

                    // Nút Đổi mật khẩu Pill (Theme adaptive)
                    Button(action: { activeSheet = .changePassword }) {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(Color.appPrimaryPink)
                            Text("Đổi mật khẩu")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.appPrimaryPink.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appPrimaryPink.opacity(0.3), lineWidth: 1))
                    }
                }

                // Tầng 5: Đơn vị sở hữu & Phòng ban (cho phép 2 dòng)
                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                    Text("🏢 \(viewModel.user.donVi.isEmpty ? "Toàn hệ thống Doanh nghiệp" : viewModel.user.donVi)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.secondary)
                        .lineLimit(2)
                } else {
                    let deptStr = !viewModel.user.departmentId.isEmpty ? "🏛️ Phòng: \(viewModel.user.departmentId)\n" : ""
                    let donViStr = "🏬 Đơn vị: \(viewModel.user.donVi.isEmpty ? "Chưa gán" : viewModel.user.donVi)"
                    Text(deptStr + donViStr)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 2)
    }

    // Role badge pill chuẩn xác 1:1 theo HomeScreen.kt
    private var roleBadgeView: some View {
        let (title, bg, textCol) = { () -> (String, Color, Color) in
            if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                return ("👑 Quản trị viên (Admin)", Color.appPrimaryPink.opacity(0.15), Color.appPrimaryPink)
            } else if viewModel.user.isHelpDesk {
                return ("🎧 Phòng Helpdesk", Color(hex: "#0284C7").opacity(0.15), Color(hex: "#0284C7"))
            } else if viewModel.user.isSpecialist {
                return ("⚡ Chuyên viên", Color(hex: "#7E22CE").opacity(0.15), Color(hex: "#7E22CE"))
            } else if viewModel.user.isTechnician {
                return ("🔧 Kỹ thuật viên", Color(hex: "#16A34A").opacity(0.15), Color(hex: "#16A34A"))
            } else if viewModel.user.isManager {
                return ("👔 Quản lý phòng ban", Color(hex: "#2563EB").opacity(0.15), Color(hex: "#2563EB"))
            } else {
                return ("👤 Nhân viên", Color.gray.opacity(0.15), Color.secondary)
            }
        }()

        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(textCol)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(bg)
            .cornerRadius(6)
    }

    // MARK: - 2. DASHBOARD STATS (3 THẺ NGANG)
    private var dashboardStatsRow: some View {
        HStack(spacing: 8) {
            // Thẻ 1: Tổng thiết bị (Màu xanh dương)
            statsCardItem(
                title: "Thiết bị",
                count: "\(viewModel.totalDevicesCount)",
                subtitle: viewModel.user.isStaff ? "Của tôi" : "Tổng quản lý",
                icon: "laptopcomputer.and.iphone",
                accentColor: Color(hex: "#2563EB"),
                bgColor: Color(hex: "#EFF6FF")
            ) {
                onNavigate(.deviceList)
            }

            // Thẻ 2: Sự cố kỹ thuật OPEN
            let openCount = viewModel.openTicketsCount
            let isAdmOrHd = viewModel.user.isAdmin || viewModel.user.isSuperAdmin || viewModel.user.isHelpDesk
            let isTech = viewModel.user.isTechnician

            let ticketColor = openCount > 0 ? Color(hex: "#DC2626") : Color(hex: "#16A34A")
            let ticketBg = openCount > 0 ? Color(hex: "#FEF2F2") : Color(hex: "#F0FDF4")
            let ticketIcon = openCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            let ticketSubtitle: String = {
                if isAdmOrHd {
                    return openCount > 0 ? "Tổng cần xử lý" : "Đang ổn định"
                } else if isTech {
                    return openCount > 0 ? "Ca của tôi" : "Đã hoàn thành"
                } else {
                    return openCount > 0 ? "Yêu cầu của tôi" : "Không có sự cố"
                }
            }()

            statsCardItem(
                title: "Sự cố mở",
                count: "\(openCount)",
                subtitle: ticketSubtitle,
                icon: ticketIcon,
                accentColor: ticketColor,
                bgColor: ticketBg
            ) {
                onNavigate(.supportHub)
            }

            // Thẻ 3: Điểm danh GPS
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
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(accentColor)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color.appSurface)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - 3. TRUY CẬP NHANH CHỨC NĂNG (8 LỐI TẮT CHÍNH)
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
                    activeSheet = .qrScanner
                }

                quickAccessCard(
                    icon: "plus.app.fill",
                    label: "Thêm TB",
                    iconColor: Color(hex: "#2563EB"),
                    bgColor: Color(hex: "#DBEAFE")
                ) {
                    activeSheet = .addDevice(initialId: "")
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

            // Hàng 2: Chấm công | Phân ca | Thống kê | Duyệt NV / In tem QR
            HStack(spacing: 8) {
                // Chấm công (KTV, Chuyên viên, Quản lý, Admin được truy cập)
                quickAccessCard(
                    icon: "chart.bar.xaxis",
                    label: "Chấm công",
                    iconColor: Color(hex: "#059669"),
                    bgColor: Color(hex: "#D1FAE5")
                ) {
                    if viewModel.user.isStaff && !viewModel.user.isTechnician && !viewModel.user.isSpecialist {
                        accessRestrictedMessage = "Báo cáo Chấm công & Công tác phí chỉ dành cho Kỹ thuật viên, Chuyên viên và Cấp quản lý.\nBạn không có quyền truy cập trang này."
                    } else {
                        onNavigate(.attendanceReport)
                    }
                }

                // Phân ca (KTV, Chuyên viên, Quản lý, Admin được truy cập)
                quickAccessCard(
                    icon: "calendar",
                    label: "Phân ca",
                    iconColor: Color(hex: "#7C3AED"),
                    bgColor: Color(hex: "#EDE9FE")
                ) {
                    if viewModel.user.isStaff && !viewModel.user.isTechnician && !viewModel.user.isSpecialist {
                        accessRestrictedMessage = "Lịch trực và Phân ca kỹ thuật chỉ dành cho Kỹ thuật viên, Chuyên viên và Cấp quản lý.\nBạn không có quyền truy cập trang này."
                    } else {
                        onNavigate(.shiftSchedule)
                    }
                }

                // Thống kê
                quickAccessCard(
                    icon: "chart.pie.fill",
                    label: "Thống kê",
                    iconColor: Color(hex: "#D97706"),
                    bgColor: Color(hex: "#FEF3C7")
                ) {
                    activeSheet = .statistics
                }

                // Thẻ thứ 4: Nếu có nhân viên chờ duyệt -> Hiện Duyệt NV; ngược lại hiện In tem QR
                let isMgrOrAdm = viewModel.user.isAdmin || viewModel.user.isSuperAdmin || viewModel.user.isHelpDesk || viewModel.user.isManager
                if isMgrOrAdm && viewModel.pendingStaffCount > 0 {
                    quickAccessCard(
                        icon: "person.badge.shield.checkmark.fill",
                        label: "Duyệt NV",
                        iconColor: Color(hex: "#DB2777"),
                        bgColor: Color(hex: "#FCE7F3"),
                        badgeCount: viewModel.pendingStaffCount
                    ) {
                        onNavigate(.approveStaff)
                    }
                } else {
                    quickAccessCard(
                        icon: "printer.fill",
                        label: "In tem QR",
                        iconColor: Color(hex: "#4F46E5"),
                        bgColor: Color(hex: "#E0E7FF")
                    ) {
                        activeSheet = .printQr
                    }
                }
            }
        }
    }

    private func quickAccessCard(
        icon: String,
        label: String,
        iconColor: Color,
        bgColor: Color,
        badgeCount: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(bgColor)
                            .frame(width: 42, height: 42)

                        Image(systemName: icon)
                            .font(.system(size: 19))
                            .foregroundColor(iconColor)
                    }

                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.appPrimaryPink)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -2)
                    }
                }

                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.appSurface)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 1)
        }
    }

    // MARK: - 4. MODAL HỘP THOẠI "TRUY CẬP BỊ GIỚI HẠN" (CHUẨN ANDROID)
    private func accessRestrictedDialog(message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFE4E6"))
                    .frame(width: 56, height: 56)

                Image(systemName: "shield.slash.fill")
                    .font(.system(size: 26))
                    .foregroundColor(Color(hex: "#E11D48"))
            }

            Text("Truy cập bị giới hạn")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.appTextPrimary)

            Text(message)
                .font(.system(size: 13.5))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button(action: { accessRestrictedMessage = nil }) {
                Text("Đóng")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.appDarkButtonBackground)
                    .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 12)
    }

    // MARK: - 5. SHEET ĐỔI TÊN HIỂN THỊ
    private var editNameSheetView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nhập họ và tên hiển thị mới của bạn:")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)

                if let err = nameError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(Color.red)
                }

                TextField("Họ và tên *", text: $editNameInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))

                Spacer()

                Button(action: {
                    let clean = editNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else {
                        nameError = "Vui lòng nhập họ và tên!"
                        return
                    }
                    isSavingName = true
                    Task {
                        do {
                            try await viewModel.updateUserName(newName: clean)
                            isSavingName = false
                            activeSheet = nil
                        } catch {
                            isSavingName = false
                            nameError = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        if isSavingName {
                            ProgressView().colorInvert()
                        } else {
                            Text("Lưu thay đổi")
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(10)
                }
                .disabled(isSavingName || editNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .navigationTitle("Đổi tên hiển thị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { activeSheet = nil }
                }
            }
        }
    }

    // MARK: - 6. SHEET ĐỔI SỐ ĐIỆN THOẠI (KIỂM TRA DUY NHẤT)
    private var editPhoneSheetView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nhập số điện thoại mới của bạn (mỗi tài khoản gắn với 1 số điện thoại duy nhất):")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)

                if let err = phoneError {
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
                }

                TextField("Số điện thoại (VD: 0912345678)", text: $editPhoneInput)
                    .keyboardType(.phonePad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))

                Spacer()

                Button(action: {
                    isSavingPhone = true
                    phoneError = nil
                    Task {
                        do {
                            try await viewModel.updateUserPhone(newPhone: editPhoneInput)
                            isSavingPhone = false
                            activeSheet = nil
                        } catch {
                            isSavingPhone = false
                            phoneError = error.localizedDescription
                        }
                    }
                }) {
                    HStack {
                        if isSavingPhone {
                            ProgressView().colorInvert()
                        } else {
                            Text("Lưu thay đổi")
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(10)
                }
                .disabled(isSavingPhone)
            }
            .padding(20)
            .navigationTitle("Đổi số điện thoại")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { activeSheet = nil }
                }
            }
        }
    }

    // MARK: - 7. SHEET HƯỚNG DẪN SỬ DỤNG
    private var guideModalView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    guideSection(
                        icon: "person.crop.circle.badge.checkmark",
                        title: "1. Hồ Sơ & Đơn Vị Của Bạn 👤",
                        desc: "Hiển thị thông tin cá nhân, phòng ban, đơn vị trực thuộc và vai trò quyền hạn được cấp. Nhấn vào ảnh để đổi avatar, nhấn bút chì để cập nhật họ tên hoặc số điện thoại."
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
                    Button("Đóng") { activeSheet = nil }
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
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

// MARK: - IMAGE PICKER VIEW CONTROLLER REPRESENTABLE
struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var onSelected: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - MODAL ĐỔI MẬT KHẨU TÀI KHOẢN (CHUẨN 1:1 THEO ANDROID HOMESCREEN.KT)
public struct ChangePasswordModalView: View {
    @ObservedObject var viewModel: HomeViewModel
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
                        .background(Color.appSurface)
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
                        .background(Color.appSurface)
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
                        .background(Color.appSurface)
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
        isLoading = true
        errorMessage = nil
        successMessage = nil

        Task {
            do {
                try await viewModel.executeChangePassword(oldPass: oldPass, newPass: newPass, confirmPass: confirmPass)
                self.isLoading = false
                self.successMessage = "✅ Đổi mật khẩu tài khoản thành công! Mật khẩu cũ đã bị vô hiệu hóa."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onDismiss()
                }
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
