import SwiftUI

// MARK: - DRAWER ITEM DEFINITION (ĐỒNG BỘ 1:1 THEO MAINACTIVITY.KT TRÊN ANDROID)
public enum DrawerDestination: Identifiable {
    case home
    case deviceList
    case addDevice
    case printBarcode
    case deviceTypes
    case statistics
    case supportHub
    case supportRating
    case specialistTeams
    case ktvMonitor
    case attendance
    case attendanceReport
    case attendanceHistory
    case shiftSchedule
    case userManagement
    case approveStaff
    case departmentManagement
    case unitManagement
    case regionManagement
    case systemSettings
    case paywallLicense
    case appInfo
    case peripherals
    case staffSupport
    case adminTicketList
    case help
    case lichSu
    case superAdmin

    public var id: String {
        switch self {
        case .home: return "home"
        case .deviceList: return "deviceList"
        case .addDevice: return "addDevice"
        case .printBarcode: return "printBarcode"
        case .deviceTypes: return "deviceTypes"
        case .statistics: return "statistics"
        case .supportHub: return "supportHub"
        case .supportRating: return "supportRating"
        case .specialistTeams: return "specialistTeams"
        case .ktvMonitor: return "ktvMonitor"
        case .attendance: return "attendance"
        case .attendanceReport: return "attendanceReport"
        case .attendanceHistory: return "attendanceHistory"
        case .shiftSchedule: return "shiftSchedule"
        case .userManagement: return "userManagement"
        case .approveStaff: return "approveStaff"
        case .departmentManagement: return "departmentManagement"
        case .unitManagement: return "unitManagement"
        case .regionManagement: return "regionManagement"
        case .systemSettings: return "systemSettings"
        case .paywallLicense: return "paywallLicense"
        case .appInfo: return "appInfo"
        case .peripherals: return "peripherals"
        case .staffSupport: return "staffSupport"
        case .adminTicketList: return "adminTicketList"
        case .help: return "help"
        case .lichSu: return "lichSu"
        case .superAdmin: return "superAdmin"
        }
    }
}

// MARK: - APP SIDEBAR DRAWER (ĐỒNG BỘ 1:1 THEO APPSIDEBARDRAWER.KT TRÊN ANDROID)
public struct AppSidebarDrawer: View {
    var user: User
    var pendingStaffCount: Int
    var openTicketsCount: Int = 0
    var currentDestination: DrawerDestination = .home
    var onSelect: (DrawerDestination) -> Void
    var onLogout: () -> Void
    var onCloseDrawer: () -> Void

    // Trạng thái thu gọn/mở rộng các nhóm accordion (mặc định mở giống Android)
    @State private var isDeviceExpanded: Bool = true
    @State private var isPersonnelExpanded: Bool = true
    @State private var isAttendanceExpanded: Bool = true
    @State private var isSystemExpanded: Bool = false

    public init(
        user: User,
        pendingStaffCount: Int = 0,
        openTicketsCount: Int = 0,
        currentDestination: DrawerDestination = .home,
        onSelect: @escaping (DrawerDestination) -> Void,
        onLogout: @escaping () -> Void,
        onCloseDrawer: @escaping () -> Void = {}
    ) {
        self.user = user
        self.pendingStaffCount = pendingStaffCount
        self.openTicketsCount = openTicketsCount
        self.currentDestination = currentDestination
        self.onSelect = onSelect
        self.onLogout = onLogout
        self.onCloseDrawer = onCloseDrawer
    }

    // MARK: - XỬ LÝ PHÂN QUYỀN (ĐỒNG BỘ 1:1 VỚI APPSIDEBARDRAWER.KT)
    private var cleanRole: String {
        user.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSuperAdmin: Bool {
        user.isSuperAdmin
    }

    private var isAdmin: Bool {
        user.isAdmin || isSuperAdmin
    }

    private var isHelpDesk: Bool {
        user.isHelpDesk
    }

    private var isManager: Bool {
        user.isManager || cleanRole == "phongban" || cleanRole == "quanly"
    }

    private var isManagerOrAdmin: Bool {
        isAdmin || isHelpDesk || isManager
    }

    private var isSpecialist: Bool {
        !isManagerOrAdmin && (
            user.isSpecialist ||
            cleanRole.contains("chuyenvien") ||
            cleanRole.contains("specialist") ||
            user.departmentName.localizedCaseInsensitiveContains("NGHIỆP VỤ") ||
            user.departmentName.localizedCaseInsensitiveContains("ỨNG DỤNG")
        )
    }

    private var isIncidentHandler: Bool {
        !isManagerOrAdmin && !isSpecialist && (
            user.isTechnician ||
            user.departmentName.localizedCaseInsensitiveContains("XỬ LÝ") ||
            user.departmentName.localizedCaseInsensitiveContains("SỰ CỐ") ||
            user.departmentName.localizedCaseInsensitiveContains("KỸ THUẬT") ||
            cleanRole.contains("kythuat") ||
            cleanRole.contains("tech") ||
            cleanRole.contains("support")
        )
    }

    // Nhãn vai trò hiển thị (Badge tiếng Việt chuẩn với Emoji)
    private var roleDisplayBadge: String {
        if isSuperAdmin || isAdmin {
            return "👑 Quản trị viên"
        } else if isHelpDesk {
            return "🎧 HelpDesk"
        } else if isSpecialist {
            return "💻 Chuyên viên"
        } else if isIncidentHandler {
            return "🛠️ KTV"
        } else if isManager {
            return "🏛️ Quản lý phòng"
        } else {
            return "👤 Nhân viên"
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // === 1. DRAWER HEADER (2 HÀNG: CÔNG TY & HỒ SƠ NGƯỜI DÙNG) ===
                VStack(alignment: .leading, spacing: 12) {
                    // Khoảng đệm tránh Notch tai thỏ / Dynamic Island
                    Color.clear.frame(height: SafeAreaHelper.top(geometry))

                    // HÀNG 1: LOGO + TÊN ỨNG DỤNG / CÔNG TY + MÃ DN + NÚT ĐÓNG (X)
                    HStack(alignment: .center, spacing: 10) {
                        Image("logo_app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.companyName.isEmpty ? "Dịch vụ IT & Quản lý thiết bị" : user.companyName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            let compCode = user.companyId.isEmpty ? "SGCOOP" : user.companyId
                            Text("Mã DN: \(compCode)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#93C5FD"))
                        }

                        Spacer()

                        // Nút Đóng (X)
                        Button(action: onCloseDrawer) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(7)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }

                    Divider().background(Color.white.opacity(0.18))

                    // HÀNG 2: THẺ HỒ SƠ NGƯỜI DÙNG (AVATAR + TÊN + EMAIL + VAI TRÒ)
                    HStack(alignment: .center, spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimaryPink)
                                .frame(width: 42, height: 42)

                            Text(String(user.fullName.isEmpty ? (user.email.first ?? "U") : (user.fullName.first ?? "U")).uppercased())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(!user.fullName.isEmpty ? user.fullName : user.email.components(separatedBy: "@").first ?? "Người dùng")
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(user.email)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#CBD5E1"))
                                .lineLimit(1)

                            // Nhãn vai trò màu vàng nổi bật
                            Text(roleDisplayBadge)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Color(hex: "#FDE68A"))
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .background(Color.appSecondaryDarkBlue)

                // === 2. DANH SÁCH MENU ĐIỀU HƯỚNG CUỘN (ACCORDIONS) ===
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Mục chính 1: Trang chủ
                        drawerItemRow(
                            title: "Trang chủ",
                            icon: "house.fill",
                            color: Color(hex: "#0284C7"),
                            isSelected: currentDestination == .home
                        ) {
                            onSelect(.home)
                        }

                        // Mục chính 2: Hỗ trợ kỹ thuật
                        drawerItemRow(
                            title: "Hỗ trợ kỹ thuật",
                            icon: "headphones",
                            color: Color(hex: "#EC4899"),
                            badge: openTicketsCount > 0 ? "\(openTicketsCount)" : nil,
                            isSelected: currentDestination == .supportHub || currentDestination == .staffSupport || currentDestination == .adminTicketList
                        ) {
                            onSelect(.supportHub)
                        }

                        // --- NHÓM 1: QUẢN LÝ THIẾT BỊ ---
                        DrawerSectionHeader(
                            title: "QUẢN LÝ THIẾT BỊ",
                            headerColor: Color(hex: "#059669"),
                            isExpanded: $isDeviceExpanded
                        )
                        if isDeviceExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(
                                    title: "Danh sách thiết bị",
                                    icon: "laptopcomputer.and.iphone",
                                    color: Color(hex: "#10B981"),
                                    isSelected: currentDestination == .deviceList
                                ) {
                                    onSelect(.deviceList)
                                }
                                drawerItemRow(
                                    title: "Thêm thiết bị mới",
                                    icon: "plus.circle.fill",
                                    color: Color(hex: "#8B5CF6"),
                                    isSelected: currentDestination == .addDevice
                                ) {
                                    onSelect(.addDevice)
                                }
                                drawerItemRow(
                                    title: "Danh mục loại thiết bị",
                                    icon: "tag.fill",
                                    color: Color(hex: "#0EA5E9"),
                                    isSelected: currentDestination == .deviceTypes
                                ) {
                                    onSelect(.deviceTypes)
                                }
                                drawerItemRow(
                                    title: "In ấn & Tem nhãn QR",
                                    icon: "printer.fill",
                                    color: Color(hex: "#A855F7"),
                                    isSelected: currentDestination == .printBarcode
                                ) {
                                    onSelect(.printBarcode)
                                }
                                drawerItemRow(
                                    title: "Thống kê thiết bị",
                                    icon: "chart.pie.fill",
                                    color: Color(hex: "#14B8A6"),
                                    isSelected: currentDestination == .statistics
                                ) {
                                    onSelect(.statistics)
                                }
                                drawerItemRow(
                                    title: "Nhật ký thiết bị",
                                    icon: "clock.arrow.circlepath",
                                    color: Color(hex: "#8B5CF6"),
                                    isSelected: currentDestination == .lichSu
                                ) {
                                    onSelect(.lichSu)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÓM 2: QUẢN LÝ NHÂN SỰ & TỔ CHỨC (ADMIN & QUẢN LÝ) ---
                        if isManagerOrAdmin {
                            DrawerSectionHeader(
                                title: "QUẢN LÝ NHÂN SỰ & TỔ CHỨC",
                                headerColor: Color(hex: "#6366F1"),
                                isExpanded: $isPersonnelExpanded
                            )
                            if isPersonnelExpanded {
                                VStack(spacing: 2) {
                                    drawerItemRow(
                                        title: "Quản lý người dùng",
                                        icon: "person.2.fill",
                                        color: Color(hex: "#3B82F6"),
                                        isSelected: currentDestination == .userManagement
                                    ) {
                                        onSelect(.userManagement)
                                    }
                                    drawerItemRow(
                                        title: "Duyệt nhân viên mới",
                                        icon: "checkmark.shield.fill",
                                        color: Color(hex: "#10B981"),
                                        badge: pendingStaffCount > 0 ? "\(pendingStaffCount)" : nil,
                                        isSelected: currentDestination == .approveStaff
                                    ) {
                                        onSelect(.approveStaff)
                                    }
                                    drawerItemRow(
                                        title: "Quản lý phòng ban",
                                        icon: "building.2.fill",
                                        color: Color(hex: "#818CF8"),
                                        isSelected: currentDestination == .departmentManagement
                                    ) {
                                        onSelect(.departmentManagement)
                                    }
                                    drawerItemRow(
                                        title: "Quản lý đơn vị",
                                        icon: "building.columns.fill",
                                        color: Color(hex: "#6366F1"),
                                        isSelected: currentDestination == .unitManagement
                                    ) {
                                        onSelect(.unitManagement)
                                    }
                                    if isAdmin || isHelpDesk {
                                        drawerItemRow(
                                            title: "Quản lý khu vực",
                                            icon: "map.circle.fill",
                                            color: Color(hex: "#F59E0B"),
                                            isSelected: currentDestination == .regionManagement
                                        ) {
                                            onSelect(.regionManagement)
                                        }
                                        drawerItemRow(
                                            title: "Quản lý tổ nghiệp vụ",
                                            icon: "person.3.fill",
                                            color: Color(hex: "#8B5CF6"),
                                            isSelected: currentDestination == .specialistTeams
                                        ) {
                                            onSelect(.specialistTeams)
                                        }
                                    }
                                }
                                .padding(.leading, 6)
                            }
                        }

                        // --- NHÓM 3: CHẤM CÔNG & ĐIỀU PHỐI (KTV, SỰ CỐ, CHUYÊN VIÊN, QUẢN LÝ) ---
                        if isManagerOrAdmin || isIncidentHandler || isSpecialist {
                            DrawerSectionHeader(
                                title: "CHẤM CÔNG & ĐIỀU PHỐI",
                                headerColor: Color(hex: "#F97316"),
                                isExpanded: $isAttendanceExpanded
                            )
                            if isAttendanceExpanded {
                                VStack(spacing: 2) {
                                    drawerItemRow(
                                        title: "Điểm danh Chấm công GPS",
                                        icon: "clock.fill",
                                        color: Color(hex: "#06B6D4"),
                                        isSelected: currentDestination == .attendance
                                    ) {
                                        onSelect(.attendance)
                                    }
                                    let reportTitle = ((isIncidentHandler || isSpecialist) && !isManagerOrAdmin) ? "Báo cáo chấm công của tôi" : "Báo cáo công & OSRM"
                                    drawerItemRow(
                                        title: reportTitle,
                                        icon: "calendar.badge.clock",
                                        color: Color(hex: "#FB923C"),
                                        isSelected: currentDestination == .attendanceReport
                                    ) {
                                        onSelect(.attendanceReport)
                                    }
                                    drawerItemRow(
                                        title: "Nhật ký chấm công",
                                        icon: "clock.arrow.circlepath",
                                        color: Color(hex: "#10B981"),
                                        isSelected: currentDestination == .attendanceHistory
                                    ) {
                                        onSelect(.attendanceHistory)
                                    }
                                    drawerItemRow(
                                        title: "Lịch trực & Phân ca",
                                        icon: "calendar",
                                        color: Color(hex: "#8B5CF6"),
                                        isSelected: currentDestination == .shiftSchedule
                                    ) {
                                        onSelect(.shiftSchedule)
                                    }
                                    if isManagerOrAdmin || isIncidentHandler {
                                        drawerItemRow(
                                            title: "Theo dõi KTV Online (Bản đồ)",
                                            icon: "map.fill",
                                            color: Color(hex: "#10B981"),
                                            isSelected: currentDestination == .ktvMonitor
                                        ) {
                                            onSelect(.ktvMonitor)
                                        }
                                    }
                                    if isAdmin || isHelpDesk {
                                        drawerItemRow(
                                            title: "Báo cáo đánh giá SLA KTV",
                                            icon: "star.fill",
                                            color: Color(hex: "#F59E0B"),
                                            isSelected: currentDestination == .supportRating
                                        ) {
                                            onSelect(.supportRating)
                                        }
                                    }
                                }
                                .padding(.leading, 6)
                            }
                        }

                        // --- NHÓM 4: HỆ THỐNG & BẢN QUYỀN ---
                        DrawerSectionHeader(
                            title: "HỆ THỐNG & BẢN QUYỀN",
                            headerColor: Color(hex: "#64748B"),
                            isExpanded: $isSystemExpanded
                        )
                        if isSystemExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(
                                    title: "Cài đặt máy in / máy quét",
                                    icon: "printer.dotmatrix.fill",
                                    color: Color(hex: "#64748B"),
                                    isSelected: currentDestination == .peripherals
                                ) {
                                    onSelect(.peripherals)
                                }
                                if isAdmin {
                                    drawerItemRow(
                                        title: "Cấu hình hệ thống",
                                        icon: "gearshape.fill",
                                        color: Color(hex: "#475569"),
                                        isSelected: currentDestination == .systemSettings
                                    ) {
                                        onSelect(.systemSettings)
                                    }
                                }
                                if isSuperAdmin {
                                    drawerItemRow(
                                        title: "Quản trị Nền tảng (Super Admin)",
                                        icon: "shield.checkered",
                                        color: Color(hex: "#4338CA"),
                                        isSelected: currentDestination == .superAdmin
                                    ) {
                                        onSelect(.superAdmin)
                                    }
                                }
                                drawerItemRow(
                                    title: "Gói cước & Bản quyền",
                                    icon: "crown.fill",
                                    color: Color(hex: "#F59E0B"),
                                    isSelected: currentDestination == .paywallLicense
                                ) {
                                    onSelect(.paywallLicense)
                                }
                                drawerItemRow(
                                    title: "Cẩm nang trợ giúp",
                                    icon: "questionmark.circle.fill",
                                    color: Color(hex: "#FBBF24"),
                                    isSelected: currentDestination == .help
                                ) {
                                    onSelect(.help)
                                }
                                drawerItemRow(
                                    title: "Thông tin ứng dụng",
                                    icon: "info.circle.fill",
                                    color: Color(hex: "#64748B"),
                                    isSelected: currentDestination == .appInfo
                                ) {
                                    onSelect(.appInfo)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        Spacer(minLength: 16)

                        // Khoảng đệm cho Home indicator
                        Color.clear.frame(height: max(geometry.safeAreaInsets.bottom, 20))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }

                // === 3. FOOTER: ĐĂNG XUẤT & PHIÊN BẢN (ĐỒNG BỘ 1:1 ANDROID) ===
                Divider().background(Color.gray.opacity(0.2))
                HStack {
                    Button(action: onLogout) {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .bold))
                            Text("Đăng xuất")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#DC2626"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.dynamic(light: "#FEF2F2", dark: "#450A0A"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.dynamic(light: "#FCA5A5", dark: "#991B1B"), lineWidth: 1))
                    }

                    Spacer()

                    Text("v1.2.0")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom - 4, 4))
                .background(Color.appSurface)
            }
            .frame(width: min(geometry.size.width * 0.82, 320))
            .background(Color.appBackground)
            .ignoresSafeArea(edges: .all)
        }
    }

    // MARK: - DRAWER SECTION HEADER (ACCORDION)
    private struct DrawerSectionHeader: View {
        let title: String
        let headerColor: Color
        @Binding var isExpanded: Bool

        var body: some View {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(headerColor)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(headerColor)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
        }
    }

    // MARK: - DRAWER ITEM ROW (ĐỒNG BỘ 1:1 DRAWERITEM TRÊN ANDROID)
    private func drawerItemRow(
        title: String,
        icon: String,
        color: Color,
        badge: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: isSelected ? .bold : .medium))
                    .foregroundColor(color)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color(hex: "#0F172A") : Color(hex: "#334155"))
                    .lineLimit(1)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appPrimaryPink)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .background(isSelected ? color.opacity(0.10) : Color.clear)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color.opacity(0.25) : Color.clear, lineWidth: 1)
            )
        }
    }
}
