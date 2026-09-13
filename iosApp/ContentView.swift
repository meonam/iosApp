import SwiftUI
import Combine

// MARK: - THEME COLORS (100% Matching Android Color.kt)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let appPrimaryPink = Color(hex: "#F40266")           // Hồng rực rỡ đặc trưng
    static let appPrimaryPinkLight = Color(hex: "#FF4081")
    static let appSecondaryDarkBlue = Color(hex: "#002A8F")     // Xanh Đậm SGCOOP
    static let appTopBar = Color(hex: "#002A8F")                // Xanh Đậm TopBar
    static let appBottomBar = Color(hex: "#0A192F")             // Xanh Đậm Đêm BottomBar
    static let appBottomBarSelected = Color(hex: "#F40266")     // Hồng highlight tab
    static let appBottomBarUnselected = Color(hex: "#94A3B8")   // Slate muted
    static let appBackground = Color(hex: "#F8FAFC")            // Nền xám slate nhạt
    static let appCardBorder = Color(hex: "#E2E8F0")            // Viền card
    static let appTextPrimary = Color(hex: "#0F172A")           // Chữ đen đậm
    static let appTextSecondary = Color(hex: "#475569")         // Chữ xám đậm
    static let appTextMuted = Color(hex: "#94A3B8")             // Chữ xám nhạt

    // Status colors
    static let statusNew = Color(hex: "#0288D1")
    static let statusInUse = Color(hex: "#16A34A")
    static let statusRepair = Color(hex: "#EA580C")
    static let statusBroken = Color(hex: "#DC2626")
}

// MARK: - DATA MODELS
struct DeviceItem: Identifiable {
    let id = UUID()
    var code: String
    var name: String
    var category: String
    var serialNumber: String
    var unit: String
    var status: String
    var iconName: String
}

struct SupportTicket: Identifiable {
    let id: String
    var title: String
    var unit: String
    var priority: String
    var status: String
    var slaRemaining: String
    var assignedKtv: String
    var createdAt: String
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let sender: String
    let text: String
    let time: String
    let isMe: Bool
}

// MARK: - MAIN ENTRY VIEW
struct ContentView: View {
    @State private var selectedTab: Int = 0
    @State private var showDrawer: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showGuide: Bool = false
    @State private var showLogoutDialog: Bool = false
    @State private var showAddDeviceSheet: Bool = false
    @State private var showScannerSheet: Bool = false
    @State private var showTicketDetail: SupportTicket? = nil
    @State private var showQuickSupportSheet: Bool = false

    // State dữ liệu người dùng
    @State private var userName: String = "Lê Thị D"
    @State private var userPhone: String = "0908 123 456"
    @State private var userRole: String = "Kỹ thuật viên"
    @State private var userDonVi: String = "113 - Co.opmart Cần Thơ"
    @State private var userDept: String = "Phòng Công nghệ thông tin"
    @State private var userEmail: String = "lethid@sgcoop.com"

    // Dữ liệu mẫu danh sách thiết bị
    @State private var devices: [DeviceItem] = [
        DeviceItem(code: "SG-POS-113-01", name: "Máy POS Bán Hàng Sunmi D2s", category: "POS", serialNumber: "SM20241001", unit: "113 - Co.opmart Cần Thơ", status: "Đang sử dụng", iconName: "computermouse.fill"),
        DeviceItem(code: "SG-SCAN-113-05", name: "Máy quét Barcode Honeywell 1900", category: "Scanner", serialNumber: "HW9982711", unit: "113 - Co.opmart Cần Thơ", status: "Đang sử dụng", iconName: "barcode.viewfinder"),
        DeviceItem(code: "SG-PRN-113-03", name: "Máy in hóa đơn Epson TM-T82III", category: "Printer", serialNumber: "EP20230819", unit: "113 - Co.opmart Cần Thơ", status: "Sửa chữa", iconName: "printer.fill"),
        DeviceItem(code: "SG-PC-113-12", name: "Máy vi tính để bàn Dell OptiPlex 7080", category: "PC", serialNumber: "DL7829104", unit: "113 - Co.opmart Cần Thơ", status: "Mới", iconName: "desktopcomputer"),
        DeviceItem(code: "SG-AP-113-02", name: "Thiết bị phát WiFi Aruba AP-505", category: "Network", serialNumber: "AR449102", unit: "113 - Co.opmart Cần Thơ", status: "Đang sử dụng", iconName: "wifi"),
        DeviceItem(code: "SG-UPS-113-04", name: "Bộ lưu điện APC Smart-UPS 1500VA", category: "UPS", serialNumber: "APC882710", unit: "113 - Co.opmart Cần Thơ", status: "Hỏng", iconName: "bolt.batteryblock.fill")
    ]

    // Dữ liệu mẫu ticket sự cố
    @State private var tickets: [SupportTicket] = [
        SupportTicket(id: "TK-2026-001", title: "Máy in bill quầy thu ngân 03 kẹt giấy liên tục", unit: "Co.opmart Cần Thơ", priority: "P1 - Khẩn cấp", status: "OPEN", slaRemaining: "15 phút", assignedKtv: "Lê Thị D", createdAt: "10 phút trước"),
        SupportTicket(id: "TK-2026-002", title: "Máy quét mã vạch không sáng đèn tia đỏ", unit: "Co.opmart Cần Thơ", priority: "P2 - Cao", status: "OPEN", slaRemaining: "45 phút", assignedKtv: "Chưa gán", createdAt: "25 phút trước"),
        SupportTicket(id: "TK-2026-003", title: "Cấu hình địa chỉ IP tĩnh cho máy kiểm kho PDA", unit: "Co.opmart Thốt Nốt", priority: "P3 - Bình thường", status: "IN_PROGRESS", slaRemaining: "2 giờ", assignedKtv: "Nguyễn Văn B", createdAt: "1 giờ trước"),
        SupportTicket(id: "TK-2026-004", title: "Thay nguồn máy tính kế toán tổng hợp", unit: "Co.opmart Bình Thủy", priority: "P3 - Bình thường", status: "RESOLVED", slaRemaining: "Đạt chuẩn SLA", assignedKtv: "Lê Thị D", createdAt: "Hôm qua")
    ]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nội dung chuyển đổi giữa 4 Tab
                Group {
                    switch selectedTab {
                    case 0:
                        HomeScreenView(
                            userName: $userName,
                            userPhone: $userPhone,
                            userRole: userRole,
                            userDonVi: userDonVi,
                            userDept: userDept,
                            userEmail: userEmail,
                            deviceCount: devices.count,
                            openTicketCount: tickets.filter { $0.status == "OPEN" }.count,
                            onOpenDrawer: { showDrawer = true },
                            onOpenGuide: { showGuide = true },
                            onOpenNotifications: { showNotifications = true },
                            onOpenLogout: { showLogoutDialog = true },
                            onNavigateTab: { tabIndex in selectedTab = tabIndex },
                            onScanQr: { showScannerSheet = true },
                            onAddDevice: { showAddDeviceSheet = true }
                        )
                    case 1:
                        DeviceListView(
                            devices: $devices,
                            onOpenDrawer: { showDrawer = true },
                            onAddDevice: { showAddDeviceSheet = true },
                            onScanDevice: { showScannerSheet = true }
                        )
                    case 2:
                        SupportHubView(
                            tickets: $tickets,
                            onOpenDrawer: { showDrawer = true },
                            onSelectTicket: { ticket in showTicketDetail = ticket }
                        )
                    case 3:
                        SettingsView(
                            userName: userName,
                            userEmail: userEmail,
                            userRole: userRole,
                            userDonVi: userDonVi,
                            onOpenDrawer: { showDrawer = true },
                            onLogout: { showLogoutDialog = true }
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Thanh điều hướng đáy (ProBottomBar chuẩn Android)
                ProBottomBarView(selectedTab: $selectedTab)
            }

            // Nút nổi Floating Action Button (Hỗ trợ khẩn cấp)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showQuickSupportSheet = true }) {
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(Color.appSecondaryDarkBlue)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                .overlay(
                                    Image(systemName: "headphones")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                )

                            // Badge đếm ticket chưa đọc/chưa xử lý
                            let openCount = tickets.filter { $0.status == "OPEN" }.count
                            if openCount > 0 {
                                Text("\(openCount)")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.appPrimaryPink))
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 74)
                }
            }

            // Thanh Menu Trượt (Sidebar Drawer)
            if showDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showDrawer = false } }

                HStack {
                    AppSidebarDrawer(
                        userName: userName,
                        userEmail: userEmail,
                        userRole: userRole,
                        userDonVi: userDonVi,
                        onSelectRoute: { route in
                            withAnimation { showDrawer = false }
                            if route == "home" { selectedTab = 0 }
                            else if route == "devices" { selectedTab = 1 }
                            else if route == "support" { selectedTab = 2 }
                            else if route == "settings" { selectedTab = 3 }
                        },
                        onLogout: {
                            showDrawer = false
                            showLogoutDialog = true
                        }
                    )
                    .frame(width: 300)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showScannerSheet) {
            ScannerMockView(onDismiss: { showScannerSheet = false })
        }
        .sheet(isPresented: $showAddDeviceSheet) {
            AddDeviceModalView(devices: $devices, onDismiss: { showAddDeviceSheet = false })
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListView(onDismiss: { showNotifications = false })
        }
        .sheet(isPresented: $showGuide) {
            GuideTourModalView(onDismiss: { showGuide = false })
        }
        .sheet(isPresented: $showQuickSupportSheet) {
            QuickSupportModalView(tickets: $tickets, onDismiss: { showQuickSupportSheet = false })
        }
        .sheet(item: $showTicketDetail) { ticket in
            TicketChatDetailView(ticket: ticket, onDismiss: { showTicketDetail = nil })
        }
        .alert(isPresented: $showLogoutDialog) {
            Alert(
                title: Text("Đăng xuất tài khoản"),
                message: Text("Bạn có chắc chắn muốn đăng xuất khỏi hệ thống Quản lý Thiết bị SGCOOP?"),
                primaryButton: .destructive(Text("Đăng xuất")) {},
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
}

// MARK: - 1. PRO BOTTOM BAR COMPONENT (Android ProBottomBar)
struct ProBottomBarView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            BottomBarTabItem(
                title: "Trang chủ",
                icon: "house.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            BottomBarTabItem(
                title: "Thiết bị",
                icon: "laptopcomputer.and.iphone",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            BottomBarTabItem(
                title: "Hỗ trợ",
                icon: "person.crop.circle.badge.questionmark",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            BottomBarTabItem(
                title: "Cài đặt",
                icon: "gearshape.fill",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .frame(height: 64)
        .background(Color.appBottomBar.ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct BottomBarTabItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.appPrimaryPink.opacity(0.2))
                            .frame(width: 48, height: 26)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 2. HOME SCREEN VIEW
struct HomeScreenView: View {
    @Binding var userName: String
    @Binding var userPhone: String
    let userRole: String
    let userDonVi: String
    let userDept: String
    let userEmail: String
    let deviceCount: Int
    let openTicketCount: Int
    let onOpenDrawer: () -> Void
    let onOpenGuide: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenLogout: () -> Void
    let onNavigateTab: (Int) -> Void
    let onScanQr: () -> Void
    let onAddDevice: () -> Void

    @State private var showEditNameAlert: Bool = false
    @State private var showEditPhoneAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // TopBar Xanh Đậm (#002A8F)
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.appPrimaryPink)
                            .frame(width: 28, height: 28)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }

                    Text("Trang chủ")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Nút Bóng đèn Hướng dẫn (Vàng)
                Button(action: onOpenGuide) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FBBF24"))
                        .frame(width: 34, height: 34)
                }

                // Chuông Thông báo
                Button(action: onOpenNotifications) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)

                        Circle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }

                // Menu 3 chấm
                Menu {
                    Button(action: onOpenGuide) {
                        Label("Trợ giúp & Hướng dẫn", systemImage: "questionmark.circle")
                    }
                    Button(action: { onNavigateTab(3) }) {
                        Label("Cấu hình hệ thống", systemImage: "gearshape")
                    }
                    Divider()
                    Button(role: .destructive, action: onOpenLogout) {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Banner Ticker Thông báo khẩn
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#002A8F"))
                Text("SGCOOP: Nhắc nhở KTV hoàn tất bảo dưỡng POS siêu thị trước 17:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#0F172A"))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#FEF08A"))

            // Nội dung cuộn chính
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. Thẻ Hồ Sơ Người Dùng (UserProfileCard)
                    UserProfileCardView(
                        userName: userName,
                        userRole: userRole,
                        userEmail: userEmail,
                        userPhone: userPhone,
                        userDept: userDept,
                        userDonVi: userDonVi,
                        onEditName: { showEditNameAlert = true },
                        onEditPhone: { showEditPhoneAlert = true }
                    )

                    // 2. Hàng Thống Kê Tổng Quan (DashboardStatsRow)
                    DashboardStatsRowView(
                        deviceCount: deviceCount,
                        openTicketCount: openTicketCount,
                        onDeviceClick: { onNavigateTab(1) },
                        onTicketClick: { onNavigateTab(2) }
                    )

                    // 3. Lưới 8 Thao Tác Nhanh (QuickAccessSection)
                    QuickAccessSectionView(
                        onScanQr: onScanQr,
                        onAddDevice: onAddDevice,
                        onDeviceList: { onNavigateTab(1) },
                        onSupportHub: { onNavigateTab(2) },
                        onSettings: { onNavigateTab(3) }
                    )

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .sheet(isPresented: $showEditNameAlert) {
            EditNameModal(name: $userName, isPresented: $showEditNameAlert)
        }
        .sheet(isPresented: $showEditPhoneAlert) {
            EditPhoneModal(phone: $userPhone, isPresented: $showEditPhoneAlert)
        }
    }
}

// MARK: - 3. USER PROFILE CARD COMPONENT
struct UserProfileCardView: View {
    let userName: String
    let userRole: String
    let userEmail: String
    let userPhone: String
    let userDept: String
    let userDonVi: String
    let onEditName: () -> Void
    let onEditPhone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                // Avatar tròn có chữ viết tắt
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appSecondaryDarkBlue, Color.appPrimaryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text(getInitials(name: userName))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(userName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)

                        Button(action: onEditName) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.appPrimaryPink)
                        }

                        Spacer()

                        // Role Badge
                        Text(userRole)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appSecondaryDarkBlue.opacity(0.12))
                            .cornerRadius(6)
                    }

                    Text(userEmail)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appPrimaryPink)

                        Text(userPhone.isEmpty ? "Chưa có SĐT" : userPhone)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(userPhone.isEmpty ? Color.appTextMuted : Color.appTextPrimary)

                        Button(action: onEditPhone) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                }
            }

            Divider().background(Color.appCardBorder)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🏛️")
                        .font(.system(size: 13))
                    Text(userDept)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("🏬")
                        .font(.system(size: 13))
                    Text(userDonVi)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func getInitials(name: String) -> String {
        let parts = name.split(separator: " ")
        if let last = parts.last, let firstChar = last.first {
            return String(firstChar)
        }
        return "D"
    }
}

// MARK: - 4. DASHBOARD STATS ROW (3 Thẻ thống kê)
struct DashboardStatsRowView: View {
    let deviceCount: Int
    let openTicketCount: Int
    let onDeviceClick: () -> Void
    let onTicketClick: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Thẻ Thiết Bị
            Button(action: onDeviceClick) {
                StatsCardItem(
                    title: "Thiết bị",
                    count: "\(deviceCount)",
                    subtitle: "Tổng quản lý",
                    icon: "laptopcomputer",
                    accentColor: Color(hex: "#2563EB"),
                    bgColor: Color(hex: "#EFF6FF")
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Thẻ Sự Cố Mở
            Button(action: onTicketClick) {
                StatsCardItem(
                    title: "Sự cố mở",
                    count: "\(openTicketCount)",
                    subtitle: openTicketCount > 0 ? "Cần xử lý ngay" : "Đang ổn định",
                    icon: openTicketCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                    accentColor: openTicketCount > 0 ? Color(hex: "#DC2626") : Color(hex: "#16A34A"),
                    bgColor: openTicketCount > 0 ? Color(hex: "#FEF2F2") : Color(hex: "#F0FDF4")
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Thẻ Điểm Danh GPS
            Button(action: {}) {
                StatsCardItem(
                    title: "Điểm danh",
                    count: "GPS",
                    subtitle: "Vào / Ra ca",
                    icon: "clock.badge.checkmark.fill",
                    accentColor: Color(hex: "#0D9488"),
                    bgColor: Color(hex: "#F0FDFA")
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct StatsCardItem: View {
    let title: String
    let count: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let bgColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bgColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Text(count)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 5. QUICK ACCESS SECTION (8 Lối tắt chuẩn)
struct QuickAccessSectionView: View {
    let onScanQr: () -> Void
    let onAddDevice: () -> Void
    let onDeviceList: () -> Void
    let onSupportHub: () -> Void
    let onSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Truy cập nhanh chức năng")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("8 lối tắt chính")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextMuted)
            }

            // Hàng 1: Quét QR | Thêm TB | Thiết bị | Hỗ trợ
            HStack(spacing: 10) {
                QuickCardItem(title: "Quét QR", icon: "qrcode.viewfinder", color: Color(hex: "#E11D48"), bgColor: Color(hex: "#FFE4E6"), action: onScanQr)
                QuickCardItem(title: "Thêm TB", icon: "plus.app.fill", color: Color(hex: "#2563EB"), bgColor: Color(hex: "#DBEAFE"), action: onAddDevice)
                QuickCardItem(title: "Thiết bị", icon: "laptopcomputer", color: Color(hex: "#0D9488"), bgColor: Color(hex: "#CCFBF1"), action: onDeviceList)
                QuickCardItem(title: "Hỗ trợ", icon: "person.crop.circle.badge.questionmark.fill", color: Color(hex: "#EA580C"), bgColor: Color(hex: "#FFEDD5"), action: onSupportHub)
            }

            // Hàng 2: Chấm công | Phân ca | Thống kê | In tem phiếu
            HStack(spacing: 10) {
                QuickCardItem(title: "Chấm công", icon: "clock.fill", color: Color(hex: "#059669"), bgColor: Color(hex: "#D1FAE5"), action: {})
                QuickCardItem(title: "Phân ca", icon: "calendar.badge.clock", color: Color(hex: "#7C3AED"), bgColor: Color(hex: "#EDE9FE"), action: {})
                QuickCardItem(title: "Thống kê", icon: "chart.bar.fill", color: Color(hex: "#D97706"), bgColor: Color(hex: "#FEF3C7"), action: {})
                QuickCardItem(title: "In tem", icon: "printer.fill", color: Color(hex: "#4F46E5"), bgColor: Color(hex: "#EEF2FF"), action: onSettings)
            }
        }
    }
}

struct QuickCardItem: View {
    let title: String
    let icon: String
    let color: Color
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(bgColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 6. DEVICE LIST VIEW (Tab Thiết Bị)
struct DeviceListView: View {
    @Binding var devices: [DeviceItem]
    let onOpenDrawer: () -> Void
    let onAddDevice: () -> Void
    let onScanDevice: () -> Void

    @State private var searchText: String = ""
    @State private var selectedFilter: String = "Tất cả"
    let filterOptions = ["Tất cả", "Đang sử dụng", "Mới", "Sửa chữa", "Hỏng"]

    var filteredDevices: [DeviceItem] {
        devices.filter { item in
            let matchSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.serialNumber.localizedCaseInsensitiveContains(searchText)

            let matchFilter = selectedFilter == "Tất cả" || item.status == selectedFilter
            return matchSearch && matchFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Danh sách Thiết bị")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onScanDevice) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                Button(action: onAddDevice) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Thanh tìm kiếm
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextMuted)
                TextField("Tìm theo tên, mã máy, Serial Number...", text: $searchText)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chip Lọc Trạng Thái
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterOptions, id: \.self) { opt in
                        Button(action: { selectedFilter = opt }) {
                            Text(opt)
                                .font(.system(size: 12, weight: selectedFilter == opt ? .bold : .medium))
                                .foregroundColor(selectedFilter == opt ? .white : Color.appTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == opt ? Color.appSecondaryDarkBlue : Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.appCardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Danh sách thẻ thiết bị
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredDevices) { item in
                        DeviceCardItemView(device: item)
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
    }
}

struct DeviceCardItemView: View {
    let device: DeviceItem

    var statusColor: Color {
        switch device.status {
        case "Đang sử dụng": return Color.statusInUse
        case "Mới": return Color.statusNew
        case "Sửa chữa": return Color.statusRepair
        case "Hỏng": return Color.statusBroken
        default: return Color.gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: device.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.code)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Spacer()

                    Text(device.status)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)
                }

                Text(device.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("SN: \(device.serialNumber)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextMuted)

                    Text("•")
                        .foregroundColor(Color.appTextMuted)

                    Text(device.unit)
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}

// MARK: - 7. SUPPORT HUB VIEW (Tab Hỗ Trợ)
struct SupportHubView: View {
    @Binding var tickets: [SupportTicket]
    let onOpenDrawer: () -> Void
    let onSelectTicket: (SupportTicket) -> Void

    @State private var selectedStatus: String = "OPEN"

    var filteredTickets: [SupportTicket] {
        if selectedStatus == "ALL" { return tickets }
        return tickets.filter { $0.status == selectedStatus }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Trung tâm Hỗ trợ Kỹ thuật")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Status Tabs
            HStack(spacing: 0) {
                TicketTabButton(title: "Chờ tiếp nhận", count: tickets.filter { $0.status == "OPEN" }.count, isSelected: selectedStatus == "OPEN") {
                    selectedStatus = "OPEN"
                }
                TicketTabButton(title: "Đang xử lý", count: tickets.filter { $0.status == "IN_PROGRESS" }.count, isSelected: selectedStatus == "IN_PROGRESS") {
                    selectedStatus = "IN_PROGRESS"
                }
                TicketTabButton(title: "Đã xong", count: tickets.filter { $0.status == "RESOLVED" }.count, isSelected: selectedStatus == "RESOLVED") {
                    selectedStatus = "RESOLVED"
                }
            }
            .background(Color.white)
            .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)

            // Danh sách ticket
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredTickets) { ticket in
                        Button(action: { onSelectTicket(ticket) }) {
                            TicketCardItemView(ticket: ticket)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
    }
}

struct TicketTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? Color.appPrimaryPink : Color.appTextSecondary)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isSelected ? Color.appPrimaryPink : Color.gray))
                    }
                }
                .padding(.top, 12)

                Rectangle()
                    .fill(isSelected ? Color.appPrimaryPink : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TicketCardItemView: View {
    let ticket: SupportTicket

    var priorityColor: Color {
        if ticket.priority.contains("P1") { return Color(hex: "#DC2626") }
        if ticket.priority.contains("P2") { return Color(hex: "#EA580C") }
        return Color(hex: "#2563EB")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.priority)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.12))
                    .cornerRadius(4)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                    Text(ticket.slaRemaining)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(priorityColor)
            }

            Text(ticket.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
                .lineLimit(2)

            Divider().background(Color.appCardBorder)

            HStack {
                Text("🏬 \(ticket.unit)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)

                Spacer()

                Text("👤 \(ticket.assignedKtv)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}

// MARK: - 8. SETTINGS VIEW (Tab Cài Đặt)
struct SettingsView: View {
    let userName: String
    let userEmail: String
    let userRole: String
    let userDonVi: String
    let onOpenDrawer: () -> Void
    let onLogout: () -> Void

    @State private var enableSound: Bool = true
    @State private var enableVibrate: Bool = true
    @State private var printThermalAuto: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Cài đặt & Ngoại vi")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            ScrollView {
                VStack(spacing: 16) {
                    // Cấu hình máy in & thiết bị ngoại vi
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MÁY IN NHIỆT & MÃ VẠCH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "printer.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text("Máy in nhiệt Bluetooth (ESC/POS)")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Kết nối máy in tem cầm tay 58mm/80mm")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextMuted)
                                }
                                Spacer()
                                Text("Đã ghép đôi")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.statusInUse)
                            }
                            .padding(14)

                            Divider()

                            Toggle(isOn: $printThermalAuto) {
                                HStack {
                                    Image(systemName: "doc.plaintext.fill")
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                        .frame(width: 28)
                                    Text("Tự động in phiếu sau khi sửa chữa")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(14)
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                    }

                    // Bản quyền & Doanh nghiệp
                    VStack(alignment: .leading, spacing: 10) {
                        Text("THÔNG TIN DOANH NGHIỆP & BẢN QUYỀN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
                            SettingsInfoRow(title: "Doanh nghiệp", value: "SAIGON CO.OP")
                            Divider()
                            SettingsInfoRow(title: "Gói bản quyền", value: "Enterprise PRO (Không giới hạn)")
                            Divider()
                            SettingsInfoRow(title: "Thời hạn bản quyền", value: "31/12/2026")
                            Divider()
                            SettingsInfoRow(title: "Phiên bản iOS", value: "v1.0.0 (Build 34773809159)")
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)
                    }

                    // Nút Đăng xuất
                    Button(action: onLogout) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .bold))
                            Text("Đăng xuất tài khoản")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "#DC2626"))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 80)
                }
                .padding(16)
            }
        }
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
        }
    }
}

// MARK: - 9. APP SIDEBAR DRAWER (Menu Trượt)
struct AppSidebarDrawer: View {
    let userName: String
    let userEmail: String
    let userRole: String
    let userDonVi: String
    let onSelectRoute: (String) -> Void
    let onLogout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Drawer
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 54, height: 54)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Text(userName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(userEmail)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                Text("🏬 \(userDonVi)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSecondaryDarkBlue)

            // Danh sách mục menu
            ScrollView {
                VStack(spacing: 4) {
                    DrawerItem(title: "Trang chủ", icon: "house.fill", action: { onSelectRoute("home") })
                    DrawerItem(title: "Quản lý thiết bị", icon: "laptopcomputer", action: { onSelectRoute("devices") })
                    DrawerItem(title: "Trung tâm Hỗ trợ Kỹ thuật", icon: "headphones", action: { onSelectRoute("support") })
                    DrawerItem(title: "Cấu hình & Ngoại vi", icon: "gearshape.fill", action: { onSelectRoute("settings") })
                    Divider().padding(.vertical, 8)
                    DrawerItem(title: "Đăng xuất", icon: "rectangle.portrait.and.arrow.right", isDestructive: true, action: onLogout)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
    }
}

struct DrawerItem: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? Color(hex: "#DC2626") : Color.appSecondaryDarkBlue)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? Color(hex: "#DC2626") : Color.appTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - 10. MODALS & SHEETS
struct ScannerMockView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Hướng camera về phía mã vạch / QR thiết bị")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.appPrimaryPink, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        Rectangle()
                            .fill(Color.appPrimaryPink.opacity(0.8))
                            .frame(width: 230, height: 2)
                    }

                    Text("Hỗ trợ chuẩn: QR Code, Code128, EAN-13, Code39")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Spacer()
                }
            }
            .navigationTitle("Quét Barcode / QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct AddDeviceModalView: View {
    @Binding var devices: [DeviceItem]
    let onDismiss: () -> Void

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var serialNumber: String = ""
    @State private var category: String = "POS"
    @State private var unit: String = "113 - Co.opmart Cần Thơ"
    @State private var status: String = "Mới"

    let categories = ["POS", "Scanner", "Printer", "PC", "Network", "UPS"]
    let statuses = ["Mới", "Đang sử dụng", "Sửa chữa", "Hỏng"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN ĐỊNH DANH")) {
                    TextField("Mã thiết bị (VD: SG-POS-113-09)", text: $code)
                    TextField("Tên thiết bị", text: $name)
                    TextField("Số Serial Number", text: $serialNumber)
                }

                Section(header: Text("PHÂN LOẠI & ĐƠN VỊ")) {
                    Picker("Danh mục", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Tình trạng", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    TextField("Đơn vị sử dụng", text: $unit)
                }
            }
            .navigationTitle("Thêm Thiết Bị Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !code.isEmpty && !name.isEmpty {
                            let newItem = DeviceItem(
                                code: code,
                                name: name,
                                category: category,
                                serialNumber: serialNumber.isEmpty ? "SN-\(Int.random(in: 100000...999999))" : serialNumber,
                                unit: unit,
                                status: status,
                                iconName: category == "POS" ? "computermouse.fill" : (category == "Scanner" ? "barcode.viewfinder" : "desktopcomputer")
                            )
                            devices.insert(newItem, at: 0)
                            onDismiss()
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

struct NotificationListView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔔 KTV hoàn tất bảo dưỡng POS")
                        .font(.system(size: 14, weight: .bold))
                    Text("Đã cập nhật tình trạng 4 máy POS tại Co.opmart Cần Thơ hoạt động ổn định.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Text("10 phút trước")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextMuted)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Cảnh báo SLA Sự cố P1")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#DC2626"))
                    Text("Sự cố quầy thu ngân 03 sắp hết hạn SLA (còn 15 phút). KTV vui lòng kiểm tra.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Text("25 phút trước")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextMuted)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Thông Báo Hệ Thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                }
            }
        }
    }
}

struct GuideTourModalView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TourSectionItem(number: "1", title: "Hồ Sơ & Đơn Vị Trực Thuộc 👤", desc: "Hiển thị thông tin cá nhân, chức danh, phòng ban và chi nhánh Co.opmart bạn đang trực thuộc. Có thể bấm đổi họ tên và SĐT bất cứ lúc nào.")
                    TourSectionItem(number: "2", title: "Trung Tâm Thao Tác Nhanh ⚡", desc: "8 lối tắt chính: Quét QR, Thêm mới thiết bị, Quản lý danh sách, Xem Ticket hỗ trợ, Chấm công GPS và In tem phiếu qua máy in Bluetooth.")
                    TourSectionItem(number: "3", title: "Điều Phối & Hỗ Trợ Kỹ Thuật 🎧", desc: "Nút nổi hỗ trợ khẩn cấp luôn sẵn sàng ở góc dưới phải để tạo yêu cầu trợ giúp và chat trực tiếp với HelpDesk SGCOOP.")
                }
                .padding(20)
            }
            .navigationTitle("Cẩm Nang Ứng Dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đã hiểu", action: onDismiss)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

struct TourSectionItem: View {
    let number: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.appSecondaryDarkBlue).frame(width: 32, height: 32)
                Text(number).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }
}

struct QuickSupportModalView: View {
    @Binding var tickets: [SupportTicket]
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var priority: String = "P1 - Khẩn cấp"
    @State private var unit: String = "113 - Co.opmart Cần Thơ"

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YÊU CẦU TRỢ GIÚP KHẨN CẤP")) {
                    TextField("Mô tả sự cố (VD: POS không in bill)", text: $title)
                    Picker("Mức độ ưu tiên", selection: $priority) {
                        Text("P1 - Khẩn cấp (SLA 30p)").tag("P1 - Khẩn cấp")
                        Text("P2 - Cao (SLA 2h)").tag("P2 - Cao")
                        Text("P3 - Bình thường (SLA 8h)").tag("P3 - Bình thường")
                    }
                    TextField("Địa điểm / Quầy xảy ra sự cố", text: $unit)
                }
            }
            .navigationTitle("Tạo Yêu Cầu Hỗ Trợ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gửi Ticket") {
                        if !title.isEmpty {
                            let newTicket = SupportTicket(
                                id: "TK-2026-\(Int.random(in: 100...999))",
                                title: title,
                                unit: unit,
                                priority: priority,
                                status: "OPEN",
                                slaRemaining: "30 phút",
                                assignedKtv: "Chưa gán",
                                createdAt: "Vừa xong"
                            )
                            tickets.insert(newTicket, at: 0)
                            onDismiss()
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

struct TicketChatDetailView: View {
    let ticket: SupportTicket
    let onDismiss: () -> Void

    @State private var messageInput: String = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(sender: "Thu ngân Co.opmart", text: "Máy in bill quầy 03 không nhận lệnh in, đèn báo đỏ liên tục.", time: "10:15", isMe: false),
        ChatMessage(sender: "HelpDesk SGCOOP", text: "Đã tiếp nhận yêu cầu! Đang điều phối KTV Lê Thị D đến kiểm tra.", time: "10:17", isMe: false),
        ChatMessage(sender: "Lê Thị D (KTV)", text: "Tôi đang di chuyển đến quầy 03, dự kiến 5 phút nữa có mặt.", time: "10:20", isMe: true)
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Ticket Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ticket.id)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                        Spacer()
                        Text(ticket.priority)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#DC2626"))
                    }
                    Text(ticket.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
                .padding(14)
                .background(Color.white)
                .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)

                // Chat message bubbles
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.isMe { Spacer() }

                                VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 3) {
                                    Text(msg.sender)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color.appTextSecondary)

                                    Text(msg.text)
                                        .font(.system(size: 14))
                                        .foregroundColor(msg.isMe ? .white : Color.appTextPrimary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(msg.isMe ? Color.appSecondaryDarkBlue : Color.white)
                                        .cornerRadius(16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.appCardBorder, lineWidth: msg.isMe ? 0 : 1)
                                        )

                                    Text(msg.time)
                                        .font(.system(size: 9))
                                        .foregroundColor(Color.appTextMuted)
                                }

                                if !msg.isMe { Spacer() }
                            }
                        }
                    }
                    .padding(16)
                }

                // Input bar
                HStack(spacing: 10) {
                    TextField("Nhập nội dung trao đổi...", text: $messageInput)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))

                    Button(action: {
                        if !messageInput.isEmpty {
                            messages.append(ChatMessage(sender: "Tôi (KTV)", text: messageInput, time: "Bây giờ", isMe: true))
                            messageInput = ""
                        }
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.appPrimaryPink)
                            .clipShape(Circle())
                    }
                }
                .padding(12)
                .background(Color.white)
            }
            .navigationTitle("Trao Đổi Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                }
            }
        }
    }
}

struct EditNameModal: View {
    @Binding var name: String
    @Binding var isPresented: Bool
    @State private var input: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("HỌ VÀ TÊN HIỂN THỊ")) {
                    TextField("Nhập họ và tên mới", text: $input)
                }
            }
            .navigationTitle("Đổi Họ Tên")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { input = name }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !input.trimmingCharacters(in: .whitespaces).isEmpty {
                            name = input.trimmingCharacters(in: .whitespaces)
                            isPresented = false
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

struct EditPhoneModal: View {
    @Binding var phone: String
    @Binding var isPresented: Bool
    @State private var input: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SỐ ĐIỆN THOẠI CỦA BẠN")) {
                    TextField("Nhập số điện thoại (VD: 0908123456)", text: $input)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Đổi Số Điện Thoại")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { input = phone }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        phone = input.trimmingCharacters(in: .whitespaces)
                        isPresented = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
