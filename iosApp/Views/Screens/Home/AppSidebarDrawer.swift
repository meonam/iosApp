import SwiftUI

// MARK: - DRAWER ITEM DEFINITION
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
    case shiftSchedule
    case userManagement
    case approveStaff
    case departmentManagement
    case unitManagement
    case regionManagement
    case systemSettings
    case paywallLicense
    case peripherals

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
        case .shiftSchedule: return "shiftSchedule"
        case .userManagement: return "userManagement"
        case .approveStaff: return "approveStaff"
        case .departmentManagement: return "departmentManagement"
        case .unitManagement: return "unitManagement"
        case .regionManagement: return "regionManagement"
        case .systemSettings: return "systemSettings"
        case .paywallLicense: return "paywallLicense"
        case .peripherals: return "peripherals"
        }
    }
}

// MARK: - APP SIDEBAR DRAWER (ĐỒNG BỘ 1:1 THEO APPSIDEBARDRAWER.KT TRÊN ANDROID)
public struct AppSidebarDrawer: View {
    var user: User
    var pendingStaffCount: Int
    var openTicketsCount: Int = 0
    var onSelect: (DrawerDestination) -> Void
    var onLogout: () -> Void
    var onCloseDrawer: () -> Void

    // Accordion group expand states matching Android
    @State private var isDeviceExpanded: Bool = true
    @State private var isSupportExpanded: Bool = true
    @State private var isAttendanceExpanded: Bool = true
    @State private var isSystemExpanded: Bool = true

    public init(
        user: User,
        pendingStaffCount: Int = 0,
        openTicketsCount: Int = 0,
        onSelect: @escaping (DrawerDestination) -> Void,
        onLogout: @escaping () -> Void,
        onCloseDrawer: @escaping () -> Void = {}
    ) {
        self.user = user
        self.pendingStaffCount = pendingStaffCount
        self.openTicketsCount = openTicketsCount
        self.onSelect = onSelect
        self.onLogout = onLogout
        self.onCloseDrawer = onCloseDrawer
    }

    private var roleDisplayBadge: String {
        if user.isAdmin || user.isSuperAdmin {
            return "👑 Quản trị viên"
        } else if user.isHelpDesk {
            return "🎧 HelpDesk"
        } else if user.isTechnician {
            return "🛠️ Kỹ thuật viên"
        } else if user.isSpecialist {
            return "💻 Chuyên viên"
        } else if user.isManager {
            return "🏛️ Quản lý phòng"
        } else {
            return "👤 Nhân viên"
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // === 1. DRAWER HEADER (2 HÀNG: CÔNG TY & NGƯỜI DÙNG) ===
                VStack(alignment: .leading, spacing: 10) {
                    // Khoảng đệm tránh Notch tai thỏ / Dynamic Island
                    Color.clear.frame(height: max(geometry.safeAreaInsets.top, 24))

                    // HÀNG 1: LOGO + TÊN ỨNG DỤNG / CÔNG TY + MÃ DN + NÚT ĐÓNG (X)
                    HStack(alignment: .center, spacing: 10) {
                        Image("logo_app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dịch vụ IT & Quản lý thiết bị")
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
                                .font(.system(size: 13, weight: .bold))
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

                            Image("logo_app")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(!user.fullName.isEmpty ? user.fullName : "admin")
                                .font(.system(size: 14, weight: .bold))
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
                .padding(.bottom, 12)
                .background(Color.appSecondaryDarkBlue)

                // === 2. DANH SÁCH MENU ĐIỀU HƯỚNG CUỘN (ACCORDIONS) ===
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Mục chính: Trang chủ
                        drawerItemRow(title: "Trang chủ", icon: "house.fill", color: Color(hex: "#0284C7")) {
                            onSelect(.home)
                        }

                        // Mục chính: Hỗ trợ kỹ thuật
                        drawerItemRow(
                            title: "Hỗ trợ kỹ thuật",
                            icon: "headphones",
                            color: Color(hex: "#EC4899"),
                            badge: openTicketsCount > 0 ? "\(openTicketsCount)" : "99+"
                        ) {
                            onSelect(.supportHub)
                        }

                        // --- NHÓM 1: QUẢN LÝ THIẾT BỊ ---
                        accordionHeader(title: "QUẢN LÝ THIẾT BỊ", color: Color(hex: "#059669"), isExpanded: $isDeviceExpanded)
                        if isDeviceExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(title: "Danh sách thiết bị", icon: "desktopcomputer", color: Color(hex: "#10B981")) {
                                    onSelect(.deviceList)
                                }
                                drawerItemRow(title: "Thêm thiết bị mới", icon: "plus.circle.fill", color: Color(hex: "#8B5CF6")) {
                                    onSelect(.addDevice)
                                }
                                drawerItemRow(title: "In tem mã QR / Barcode", icon: "printer.fill", color: Color(hex: "#0284C7")) {
                                    onSelect(.printBarcode)
                                }
                                drawerItemRow(title: "Quản lý loại thiết bị", icon: "tag.fill", color: Color(hex: "#F59E0B")) {
                                    onSelect(.deviceTypes)
                                }
                                drawerItemRow(title: "Thống kê & Báo cáo tài sản", icon: "chart.pie.fill", color: Color(hex: "#EC4899")) {
                                    onSelect(.statistics)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÓM 2: TRUNG TÂM HỖ TRỢ (TICKET) ---
                        accordionHeader(title: "TRUNG TÂM HỖ TRỢ (TICKET)", color: Color(hex: "#F43F5E"), isExpanded: $isSupportExpanded)
                        if isSupportExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(title: "Yêu cầu hỗ trợ (Ticket)", icon: "headphones", color: Color(hex: "#F43F5E")) {
                                    onSelect(.supportHub)
                                }
                                drawerItemRow(title: "Báo cáo đánh giá SLA KTV", icon: "star.fill", color: Color(hex: "#F59E0B")) {
                                    onSelect(.supportRating)
                                }
                                drawerItemRow(title: "Quản lý đội chuyên viên", icon: "person.3.fill", color: Color(hex: "#0284C7")) {
                                    onSelect(.specialistTeams)
                                }
                                drawerItemRow(title: "Giám sát KTV trực tuyến (Map)", icon: "map.fill", color: Color(hex: "#10B981")) {
                                    onSelect(.ktvMonitor)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÓM 3: CHẤM CÔNG & LỊCH CA ---
                        accordionHeader(title: "CHẤM CÔNG & LỊCH CA", color: Color(hex: "#0D9488"), isExpanded: $isAttendanceExpanded)
                        if isAttendanceExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(title: "Điểm danh chấm công", icon: "person.badge.shield.checkmark.fill", color: Color(hex: "#10B981")) {
                                    onSelect(.attendance)
                                }
                                drawerItemRow(title: "Báo cáo công & Tăng ca", icon: "calendar.badge.clock", color: Color(hex: "#F59E0B")) {
                                    onSelect(.attendanceReport)
                                }
                                drawerItemRow(title: "Lịch phân ca tuần", icon: "calendar", color: Color(hex: "#8B5CF6")) {
                                    onSelect(.shiftSchedule)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÓM 4: QUẢN TRỊ HỆ THỐNG (ADMIN) ---
                        if user.isAdmin || user.isSuperAdmin {
                            accordionHeader(title: "QUẢN TRỊ HỆ THỐNG", color: Color(hex: "#002A8F"), isExpanded: $isSystemExpanded)
                            if isSystemExpanded {
                                VStack(spacing: 2) {
                                    drawerItemRow(title: "Quản lý tài khoản người dùng", icon: "person.2.fill", color: Color(hex: "#002A8F")) {
                                        onSelect(.userManagement)
                                    }
                                    drawerItemRow(
                                        title: "Duyệt nhân viên mới",
                                        icon: "person.badge.plus",
                                        color: Color.appPrimaryPink,
                                        badge: pendingStaffCount > 0 ? "\(pendingStaffCount)" : nil
                                    ) {
                                        onSelect(.approveStaff)
                                    }
                                    drawerItemRow(title: "Quản lý phòng ban", icon: "folder.fill", color: Color(hex: "#8B5CF6")) {
                                        onSelect(.departmentManagement)
                                    }
                                    drawerItemRow(title: "Quản lý đơn vị / Chi nhánh", icon: "building.2.fill", color: Color(hex: "#10B981")) {
                                        onSelect(.unitManagement)
                                    }
                                    drawerItemRow(title: "Quản lý khu vực / Cụm", icon: "map.circle.fill", color: Color(hex: "#0284C7")) {
                                        onSelect(.regionManagement)
                                    }
                                    drawerItemRow(title: "Cấu hình hệ thống & Bản quyền", icon: "gearshape.fill", color: Color(hex: "#64748B")) {
                                        onSelect(.systemSettings)
                                    }
                                }
                                .padding(.leading, 6)
                            }
                        }

                        // --- NHÓM 5: NGOẠI VI & CÀI ĐẶT ---
                        drawerItemRow(title: "Ngoại vi & Cài đặt máy in / quét", icon: "printer.dotmatrix.fill", color: Color(hex: "#0284C7")) {
                            onSelect(.peripherals)
                        }

                        Spacer(minLength: 16)

                        // Nút Đăng xuất màu đỏ
                        Divider().padding(.vertical, 4)
                        drawerItemRow(title: "Đăng xuất", icon: "rectangle.portrait.and.arrow.right", color: Color(hex: "#DC2626")) {
                            onLogout()
                        }

                        // Khoảng đệm cho Home indicator ở cạnh dưới iPhone
                        Color.clear.frame(height: max(geometry.safeAreaInsets.bottom, 20))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: min(geometry.size.width * 0.82, 320))
            .background(Color.white)
            .ignoresSafeArea(edges: .all)
        }
    }

    // MARK: - ACCORDION HEADER
    private func accordionHeader(title: String, color: Color, isExpanded: Binding<Bool>) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.wrappedValue.toggle()
            }
        }) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(color)

                Spacer()

                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    // MARK: - DRAWER ITEM ROW
    private func drawerItemRow(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)

                Spacer()

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Color.appPrimaryPink)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clear)
            .cornerRadius(8)
        }
    }
}
