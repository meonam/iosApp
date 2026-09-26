import SwiftUI

// MARK: - MAIN CONTAINER VIEW (ĐỒNG BỘ 1:1 THEO MAINACTIVITY.KT TRÊN ANDROID)
public struct MainContainerView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var currentDestination: DrawerDestination = .home
    @State private var isDrawerOpen: Bool = false
    @State private var selectedTicketForChat: SupportTicket? = nil

    // Sheets mở từ khắp nơi
    @State private var showAddDeviceSheet: Bool = false
    @State private var showPrintSheet: Bool = false

    public init() {}

    // Các tab chính hiển thị Bottom Navigation Bar & FAB
    private var isMainTab: Bool {
        switch currentDestination {
        case .home, .deviceList, .supportHub, .peripherals:
            return true
        default:
            return false
        }
    }

    public var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                LoginView(viewModel: authViewModel) {
                    currentDestination = .home
                }
            } else if let user = authViewModel.currentUser {
                let compId = authViewModel.currentCompanyId
                let token = authViewModel.currentIdToken

                ZStack(alignment: .leading) {
                    // MÀN HÌNH CHÍNH THEO DESTINATION + BOTTOM BAR + FAB
                    ZStack(alignment: .bottomTrailing) {
                        VStack(spacing: 0) {
                            // Nội dung màn hình
                            destinationView(for: currentDestination, user: user, compId: compId, token: token)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            // 1. THANH ĐIỀU HƯỚNG DƯỚI (PRO BOTTOM NAVIGATION BAR - 4 TABS)
                            if isMainTab {
                                proBottomBar
                            }
                        }
                        .disabled(isDrawerOpen)

                        // 2. NÚT NỔI HỖ TRỢ KỸ THUẬT (FAB - GREEN SUPPORT BUTTON WITH BADGE 99+)
                        if isMainTab && currentDestination != .supportHub {
                            floatingSupportButton
                                .padding(.trailing, 16)
                                .padding(.bottom, 72)
                                .zIndex(10)
                        }
                    }

                    // 3. NỀN MỜ VÀ THANH BÊN DRAWER TRƯỢT TỪ BÊN TRÁI
                    if isDrawerOpen {
                        Color.black.opacity(0.45)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isDrawerOpen = false
                                }
                            }
                            .zIndex(20)

                        AppSidebarDrawer(
                            user: user,
                            pendingStaffCount: 0,
                            onSelect: { dest in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isDrawerOpen = false
                                    currentDestination = dest
                                }
                            },
                            onLogout: {
                                withAnimation {
                                    isDrawerOpen = false
                                    authViewModel.logout()
                                }
                            }
                        )
                        .transition(.move(edge: .leading))
                        .zIndex(30)
                    }
                }
            }
        }
    }

    // MARK: - PRO BOTTOM BAR (4 TABS CHUẨN ANDROID)
    private var proBottomBar: some View {
        HStack(spacing: 0) {
            bottomNavItem(
                title: "Trang chủ",
                icon: "house.fill",
                isSelected: currentDestination == .home
            ) {
                currentDestination = .home
            }

            bottomNavItem(
                title: "Danh sách TB",
                icon: "laptopcomputer.and.iphone",
                isSelected: currentDestination == .deviceList
            ) {
                currentDestination = .deviceList
            }

            bottomNavItem(
                title: "Hỗ trợ",
                icon: "headphones",
                badgeText: "99+",
                isSelected: currentDestination == .supportHub
            ) {
                currentDestination = .supportHub
            }

            bottomNavItem(
                title: "Ngoại vi",
                icon: "printer.fill",
                isSelected: currentDestination == .peripherals
            ) {
                currentDestination = .peripherals
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(Color.appBottomBarBackground)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -2)
    }

    private func bottomNavItem(
        title: String,
        icon: String,
        badgeText: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
                        .frame(width: 28, height: 28)

                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#E11D48"))
                            .clipShape(Capsule())
                            .offset(x: 10, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - FLOATING ACTION BUTTON (GREEN SUPPORT FAB WITH 99+ BADGE)
    private var floatingSupportButton: some View {
        Button(action: {
            currentDestination = .supportHub
        }) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.appFabGreen)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)

                Image(systemName: "headphones")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)

                // Huy hiệu 99+
                Text("99+")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#E11D48"))
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
    }

    // MARK: - ĐIỀU HƯỚNG VIEW CON THEO DESTINATION
    @ViewBuilder
    private func destinationView(for dest: DrawerDestination, user: User, compId: String, token: String) -> some View {
        switch dest {
        case .home:
            HomeScreenView(
                viewModel: HomeViewModel(user: user, companyId: compId, idToken: token),
                onOpenDrawer: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isDrawerOpen = true
                    }
                },
                onNavigate: { target in
                    currentDestination = target
                },
                onLogout: {
                    authViewModel.logout()
                }
            )
        case .deviceList:
            DeviceListView(
                viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onNavigateToAdd: { showAddDeviceSheet = true },
                onNavigateToPrint: { currentDestination = .printBarcode }
            )
            .sheet(isPresented: $showAddDeviceSheet) {
                AddDeviceView(
                    viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                    onDismiss: { showAddDeviceSheet = false }
                )
            }
        case .supportHub:
            SupportHubView(
                viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onSelectTicket: { ticket in
                    selectedTicketForChat = ticket
                },
                onOpenRatingReport: { /* Mở báo cáo SLA */ }
            )
            .sheet(item: $selectedTicketForChat) { ticket in
                TicketChatDetailView(
                    viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }
        case .peripherals:
            PeripheralsView(onBack: { currentDestination = .home })

        case .attendance:
            AttendanceCheckInView(
                viewModel: AttendanceViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )
        case .shiftSchedule:
            ShiftScheduleView(
                viewModel: ShiftViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )
        case .statistics:
            AssetStatisticsView(
                viewModel: HomeViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onNavigateToPrint: { currentDestination = .printBarcode }
            )
        case .printBarcode:
            PrintQrLabelView(
                viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )
        case .addDevice:
            AddDeviceView(
                viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                onDismiss: { currentDestination = .deviceList }
            )
        case .systemSettings:
            SystemSettingsView(onBack: { currentDestination = .home })

        default:
            VStack(spacing: 16) {
                HStack {
                    Button(action: { currentDestination = .home }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Text("Đang đồng bộ...")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(14)
                .background(Color.appTopBarColor)

                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text("Tính năng đã được cấu hình sẵn sàng")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
            }
        }
    }
}
