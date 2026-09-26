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

// MARK: - APP SIDEBAR DRAWER (Äá»’NG Bá»˜ 1:1 THEO APPSIDEBARDRAWER.KT TRÃŠN ANDROID)
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
            return "ðŸ‘‘ Quáº£n trá»‹ viÃªn"
        } else if user.isHelpDesk {
            return "ðŸŽ§ HelpDesk"
        } else if user.isTechnician {
            return "ðŸ› ï¸ Ká»¹ thuáº­t viÃªn"
        } else if user.isSpecialist {
            return "ðŸ’» ChuyÃªn viÃªn"
        } else if user.isManager {
            return "ðŸ›ï¸ Quáº£n lÃ½ phÃ²ng"
        } else {
            return "ðŸ‘¤ NhÃ¢n viÃªn"
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // === 1. DRAWER HEADER (2 HÃ€NG: CÃ”NG TY & NGÆ¯á»œI DÃ™NG) ===
                VStack(alignment: .leading, spacing: 10) {
                    // Khoáº£ng Ä‘á»‡m trÃ¡nh Notch tai thá» / Dynamic Island
                    Color.clear.frame(height: max(geometry.safeAreaInsets.top, 24))

                    // HÃ€NG 1: LOGO + TÃŠN á»¨NG Dá»¤NG / CÃ”NG TY + MÃƒ DN + NÃšT ÄÃ“NG (X)
                    HStack(alignment: .center, spacing: 10) {
                        Image("logo_app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 38, height: 38)
                            .cornerRadius(8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dá»‹ch vá»¥ IT & Quáº£n lÃ½ thiáº¿t bá»‹")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)

                            let compCode = user.companyId.isEmpty ? "SGCOOP" : user.companyId
                            Text("MÃ£ DN: \(compCode)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "#93C5FD"))
                        }

                        Spacer()

                        // NÃºt ÄÃ³ng (X)
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

                    // HÃ€NG 2: THáºº Há»’ SÆ  NGÆ¯á»œI DÃ™NG (AVATAR + TÃŠN + EMAIL + VAI TRÃ’)
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

                            // NhÃ£n vai trÃ² mÃ u vÃ ng ná»•i báº­t
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

                // === 2. DANH SÃCH MENU ÄIá»€U HÆ¯á»šNG CUá»˜N (ACCORDIONS) ===
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Má»¥c chÃ­nh: Trang chá»§
                        drawerItemRow(title: "Trang chá»§", icon: "house.fill", color: Color(hex: "#0284C7")) {
                            onSelect(.home)
                        }

                        // Má»¥c chÃ­nh: Há»— trá»£ ká»¹ thuáº­t
                        drawerItemRow(
                            title: "Há»— trá»£ ká»¹ thuáº­t",
                            icon: "headphones",
                            color: Color(hex: "#EC4899"),
                            badge: openTicketsCount > 0 ? "\(openTicketsCount)" : "99+"
                        ) {
                            onSelect(.supportHub)
                        }

                        // --- NHÃ“M 1: QUáº¢N LÃ THIáº¾T Bá»Š ---
                        accordionHeader(title: "QUáº¢N LÃ THIáº¾T Bá»Š", color: Color(hex: "#059669"), isExpanded: $isDeviceExpanded)
                        if isDeviceExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(title: "Danh sÃ¡ch thiáº¿t bá»‹", icon: "desktopcomputer", color: Color(hex: "#10B981")) {
                                    onSelect(.deviceList)
                                }
                                drawerItemRow(title: "ThÃªm thiáº¿t bá»‹ má»›i", icon: "plus.circle.fill", color: Color(hex: "#8B5CF6")) {
                                    onSelect(.addDevice)
                                }
                                drawerItemRow(title: "In tem mÃ£ QR / Barcode", icon: "printer.fill", color: Color(hex: "#0284C7")) {
                                    onSelect(.printBarcode)
                                }
                                drawerItemRow(title: "Quáº£n lÃ½ loáº¡i thiáº¿t bá»‹", icon: "tag.fill", color: Color(hex: "#F59E0B")) {
                                    onSelect(.deviceTypes)
                                }
                                drawerItemRow(title: "Thá»‘ng kÃª & BÃ¡o cÃ¡o tÃ i sáº£n", icon: "chart.pie.fill", color: Color(hex: "#EC4899")) {
                                    onSelect(.statistics)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÃ“M 2: TRUNG TÃ‚M Há»– TRá»¢ (TICKET) ---
                        accordionHeader(title: "TRUNG TÃ‚M Há»– TRá»¢ (TICKET)", color: Color(hex: "#F43F5E"), isExpanded: $isSupportExpanded)
                        if isSupportExpanded {
                            VStack(spacing: 2) {
                                if user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isTechnician {
                                    drawerItemRow(title: "YÃªu cáº§u há»— trá»£ (Ticket)", icon: "headphones", color: Color(hex: "#F43F5E")) {
                                        onSelect(.supportHub)
                                    }
                                    drawerItemRow(title: "BÃ¡o cÃ¡o Ä‘Ã¡nh giÃ¡ SLA KTV", icon: "star.fill", color: Color(hex: "#F59E0B")) {
                                        onSelect(.supportRating)
                                    }
                                    drawerItemRow(title: "Quáº£n lÃ½ Ä‘á»™i chuyÃªn viÃªn", icon: "person.3.fill", color: Color(hex: "#0284C7")) {
                                        onSelect(.specialistTeams)
                                    }
                                    drawerItemRow(title: "GiÃ¡m sÃ¡t KTV trá»±c tuyáº¿n (Map)", icon: "map.fill", color: Color(hex: "#10B981")) {
                                        onSelect(.ktvMonitor)
                                    }
                                } else {
                                    drawerItemRow(title: "YÃªu cáº§u há»— trá»£ (IT Support)", icon: "headphones", color: Color(hex: "#F43F5E")) {
                                        onSelect(.staffSupport)
                                    }
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÃ“M 3: CHáº¤M CÃ”NG & Lá»ŠCH CA ---
                        accordionHeader(title: "CHáº¤M CÃ”NG & Lá»ŠCH CA", color: Color(hex: "#0D9488"), isExpanded: $isAttendanceExpanded)
                        if isAttendanceExpanded {
                            VStack(spacing: 2) {
                                drawerItemRow(title: "Äiá»ƒm danh cháº¥m cÃ´ng", icon: "person.badge.shield.checkmark.fill", color: Color(hex: "#10B981")) {
                                    onSelect(.attendance)
                                }
                                drawerItemRow(title: "BÃ¡o cÃ¡o cÃ´ng & TÄƒng ca", icon: "calendar.badge.clock", color: Color(hex: "#F59E0B")) {
                                    onSelect(.attendanceReport)
                                }
                                drawerItemRow(title: "Nhật ký chấm công", icon: "clock.fill", color: Color(hex: "#10B981")) {
                                    onSelect(.attendanceHistory)
                                }
                                drawerItemRow(title: "Lá»‹ch phÃ¢n ca tuáº§n", icon: "calendar", color: Color(hex: "#8B5CF6")) {
                                    onSelect(.shiftSchedule)
                                }
                            }
                            .padding(.leading, 6)
                        }

                        // --- NHÃ“M 4: QUáº¢N TRá»Š Há»† THá»NG (ADMIN) ---
                        if user.isAdmin || user.isSuperAdmin {
                            accordionHeader(title: "QUáº¢N TRá»Š Há»† THá»NG", color: Color(hex: "#002A8F"), isExpanded: $isSystemExpanded)
                            if isSystemExpanded {
                                VStack(spacing: 2) {
                                    drawerItemRow(title: "Quáº£n lÃ½ tÃ i khoáº£n ngÆ°á»i dÃ¹ng", icon: "person.2.fill", color: Color(hex: "#002A8F")) {
                                        onSelect(.userManagement)
                                    }
                                    drawerItemRow(
                                        title: "Duyá»‡t nhÃ¢n viÃªn má»›i",
                                        icon: "person.badge.plus",
                                        color: Color.appPrimaryPink,
                                        badge: pendingStaffCount > 0 ? "\(pendingStaffCount)" : nil
                                    ) {
                                        onSelect(.approveStaff)
                                    }
                                    drawerItemRow(title: "Quáº£n lÃ½ phÃ²ng ban", icon: "folder.fill", color: Color(hex: "#8B5CF6")) {
                                        onSelect(.departmentManagement)
                                    }
                                    drawerItemRow(title: "Quáº£n lÃ½ Ä‘Æ¡n vá»‹ / Chi nhÃ¡nh", icon: "building.2.fill", color: Color(hex: "#10B981")) {
                                        onSelect(.unitManagement)
                                    }
                                    drawerItemRow(title: "Quáº£n lÃ½ khu vá»±c / Cá»¥m", icon: "map.circle.fill", color: Color(hex: "#0284C7")) {
                                        onSelect(.regionManagement)
                                    }
                                    drawerItemRow(title: "Cáº¥u hÃ¬nh há»‡ thá»‘ng & Báº£n quyá»n", icon: "gearshape.fill", color: Color(hex: "#64748B")) {
                                        onSelect(.systemSettings)
                                    }
                                    drawerItemRow(
                                        title: "Danh sach Ticket (Admin)",
                                        icon: "ticket.fill",
                                        color: Color(hex: "#DC2626"),
                                        badge: openTicketsCount > 0 ? "\(openTicketsCount)" : nil
                                    ) {
                                        onSelect(.adminTicketList)
                                    }
                                    if user.isSuperAdmin {
                                        drawerItemRow(
                                            title: "Super Admin Portal",
                                            icon: "shield.checkered",
                                            color: Color(hex: "#7C3AED")
                                        ) {
                                            onSelect(.superAdmin)
                                        }
                                    }                                }
                                .padding(.leading, 6)
                            }
                        }

                        // --- NHÃ“M 5: NGOáº I VI & CÃ€I Äáº¶T ---
                        drawerItemRow(title: "Ngoáº¡i vi & CÃ i Ä‘áº·t mÃ¡y in / quÃ©t", icon: "printer.dotmatrix.fill", color: Color(hex: "#0284C7")) {
                            onSelect(.peripherals)
                        }
                        drawerItemRow(title: "Nhat ky thiet bi", icon: "clock.arrow.circlepath", color: Color(hex: "#8B5CF6")) {
                            onSelect(.lichSu)
                        }

                        Spacer(minLength: 16)

                        // NÃºt ÄÄƒng xuáº¥t mÃ u Ä‘á»
                        Divider().padding(.vertical, 4)
                        drawerItemRow(title: "Tro giup & FAQ", icon: "questionmark.circle.fill", color: Color(hex: "#0284C7")) {
                            onSelect(.help)
                        }
                        drawerItemRow(title: "ÄÄƒng xuáº¥t", icon: "rectangle.portrait.and.arrow.right", color: Color(hex: "#DC2626")) {
                            onLogout()
                        }

                        // Khoáº£ng Ä‘á»‡m cho Home indicator á»Ÿ cáº¡nh dÆ°á»›i iPhone
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



