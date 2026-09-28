import SwiftUI

// MARK: - MAIN CONTAINER VIEW (ĐỒNG BỘ 1:1 THEO MAINACTIVITY.KT TRÊN ANDROID)
public struct MainContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var homeViewModel = HomeViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var supportViewModel = SupportViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var adminViewModel = AdminViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @State private var currentDestination: DrawerDestination = .home
    @State private var isDrawerOpen: Bool = false
    @State private var selectedTicketForChat: SupportTicket? = nil

    // Sheets mở từ khắp nơi
    @State private var showAddDeviceSheet: Bool = false
    @State private var showPrintSheet: Bool = false
    @State private var showRatingReportSheet: Bool = false

    public init() {}

    // Các tab chính hiển thị Bottom Navigation Bar & FAB
    private var isMainTab: Bool {
        switch currentDestination {
        case .home, .deviceList, .supportHub, .staffSupport, .peripherals:
            return true
        default:
            return false
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            Group {
                if !authViewModel.isAuthenticated {
                    LoginView(viewModel: authViewModel) {
                        currentDestination = .home
                    }
                } else if let user = authViewModel.currentUser {
                    let compId = authViewModel.currentCompanyId
                    let token = authViewModel.currentIdToken

                    if user.status == "PENDING" {
                        PendingApprovalView(
                            viewModel: authViewModel,
                            onApproved: { role in
                                authViewModel.currentUser?.status = "APPROVED"
                                authViewModel.currentUser?.role = role
                            },
                            onLogout: {
                                authViewModel.logout()
                            }
                        )
                    } else {
                        ZStack(alignment: .leading) {
                            // MÀN HÌNH CHÍNH THEO DESTINATION + BOTTOM BAR + FAB
                            ZStack(alignment: .bottomTrailing) {
                                VStack(spacing: 0) {
                                    // Nội dung màn hình
                                    destinationView(for: currentDestination, user: user, compId: compId, token: token)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                                // 1. THANH ĐIỀU HƯỚNG DƯỚI (PRO BOTTOM NAVIGATION BAR - 4 TABS)
                                if isMainTab {
                                    proBottomBar(bottomInset: SafeAreaHelper.bottom(geometry))
                                }
                            }
                            .disabled(isDrawerOpen)

                            // 2. NÚT NỔI HỖ TRỢ KỸ THUẬT (FAB - GREEN SUPPORT BUTTON WITH BADGE)
                            if isMainTab && currentDestination != .supportHub && currentDestination != .staffSupport {
                                floatingSupportButton
                                    .padding(.trailing, 16)
                                    .padding(.bottom, SafeAreaHelper.bottom(geometry) + 64)
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
                                user: homeViewModel.user.email.isEmpty ? user : homeViewModel.user,
                                pendingStaffCount: homeViewModel.pendingStaffCount,
                                openTicketsCount: homeViewModel.openTicketsCount,
                                currentDestination: currentDestination,
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
                                },
                                onCloseDrawer: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isDrawerOpen = false
                                    }
                                }
                            )
                            .transition(.move(edge: .leading))
                            .zIndex(30)
                        }
                    }
                    .onAppear {
                        homeViewModel.user = user
                        homeViewModel.companyId = compId
                        homeViewModel.idToken = token
                        homeViewModel.loadDashboardData()

                        supportViewModel.user = user
                        supportViewModel.companyId = compId
                        supportViewModel.idToken = token

                        adminViewModel.currentUser = user
                        adminViewModel.companyId = compId
                        adminViewModel.idToken = token
                        adminViewModel.fetchAllDataIfNeeded()
                    }
                    .onChange(of: authViewModel.currentUser) { newUser in
                        if let u = newUser {
                            let cid = authViewModel.currentCompanyId
                            let tok = authViewModel.currentIdToken

                            homeViewModel.user = u
                            homeViewModel.companyId = cid
                            homeViewModel.idToken = tok
                            homeViewModel.loadDashboardData()

                            supportViewModel.user = u
                            supportViewModel.companyId = cid
                            supportViewModel.idToken = tok

                            adminViewModel.currentUser = u
                            adminViewModel.companyId = cid
                            adminViewModel.idToken = tok
                            adminViewModel.fetchAllDataIfNeeded()
                        }
                    }
                    .onChange(of: scenePhase) { newPhase in
                        if authViewModel.isAuthenticated, let user = authViewModel.currentUser {
                            let isOnline = (newPhase == .active)
                            PresenceHelper.shared.setPresence(
                                companyId: authViewModel.currentCompanyId,
                                email: user.email,
                                isOnline: isOnline,
                                idToken: authViewModel.currentIdToken
                            )
                        }
                    }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - PRO BOTTOM BAR (4 TABS CHUẨN ANDROID VỚI SAFE AREA BOTTOM)
    private func proBottomBar(bottomInset: CGFloat) -> some View {
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

            let isSupportSelected = currentDestination == .supportHub || currentDestination == .staffSupport || currentDestination == .adminTicketList
            let ticketBadge: String? = homeViewModel.openTicketsCount > 0 ? (homeViewModel.openTicketsCount > 99 ? "99+" : "\(homeViewModel.openTicketsCount)") : nil
            bottomNavItem(
                title: "Hỗ trợ",
                icon: "headphones",
                badgeText: ticketBadge,
                isSelected: isSupportSelected
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
        .padding(.top, 8)
        .padding(.bottom, max(bottomInset, 16))
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

    // MARK: - FLOATING ACTION BUTTON (GREEN SUPPORT FAB WITH BADGE)
    private var floatingSupportButton: some View {
        Button(action: {
            currentDestination = .supportHub
        }) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Color.appFabGreen)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.appFabGreen.opacity(0.4), radius: 8, x: 0, y: 4)

                Image(systemName: "headphones")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)

                if homeViewModel.openTicketsCount > 0 {
                    Text(homeViewModel.openTicketsCount > 99 ? "99+" : "\(homeViewModel.openTicketsCount)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#E11D48"))
                        .clipShape(Capsule())
                        .offset(x: 4, y: -2)
                }
            }
        }
    }

    // MARK: - ROUTER ĐIỀU HƯỚNG MÀN HÌNH (TOÀN BỘ CHỨC NĂNG 1:1 THEO ANDROID)
    @ViewBuilder
    private func destinationView(for dest: DrawerDestination, user: User, compId: String, token: String) -> some View {
        switch dest {
        case .home:
            HomeScreenView(
                viewModel: homeViewModel,
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

        case .addDevice:
            AddDeviceView(
                viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                onDismiss: { currentDestination = .deviceList }
            )

        case .printBarcode:
            PrintQrLabelView(
                viewModel: DeviceViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .deviceTypes:
            DeviceTypeManagerView(
                authViewModel: authViewModel,
                onBack: { currentDestination = .home }
            )

        case .statistics:
            AssetStatisticsView(
                viewModel: HomeViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onNavigateToPrint: { currentDestination = .printBarcode }
            )

        case .staffSupport:
            StaffSupportView(
                authViewModel: authViewModel,
                onBack: { currentDestination = .home }
            )

        case .supportHub:
            SupportHubView(
                viewModel: supportViewModel,
                authViewModel: authViewModel,
                onBack: { currentDestination = .home },
                onSelectTicket: { ticket in
                    selectedTicketForChat = ticket
                },
                onOpenRatingReport: {
                    currentDestination = .supportRating
                }
            )
            .sheet(item: $selectedTicketForChat) { ticket in
                TicketChatDetailView(
                    viewModel: supportViewModel,
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }

        case .supportRating:
            SupportRatingReportView(
                viewModel: supportViewModel,
                onBack: { currentDestination = .supportHub }
            )

        case .specialistTeams:
            SpecialistTeamManagerView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .ktvMonitor:
            OnlineKtvMonitorView(
                supportVM: SupportViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .peripherals:
            PeripheralsView(onBack: { currentDestination = .home })

        case .attendanceHistory:
            AttendanceHistoryView(authViewModel: authViewModel, onBack: { currentDestination = .home })

        case .attendance:
            AttendanceCheckInView(
                viewModel: AttendanceViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onNavigateToHistory: { currentDestination = .attendanceHistory },
                onNavigateToReport: { currentDestination = .attendanceReport }
            )

        case .attendanceReport:
            AttendanceReportView(
                authViewModel: authViewModel,
                onBack: { currentDestination = .home }
            )

        case .shiftSchedule:
            ShiftScheduleView(
                viewModel: ShiftViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .userManagement:
            UserManagementView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .approveStaff:
            ApproveStaffView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .departmentManagement:
            DepartmentManagerView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .unitManagement:
            UnitManagerView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .regionManagement:
            RegionManagerView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .systemSettings:
            SystemSettingsView(
                viewModel: adminViewModel,
                onBack: { currentDestination = .home }
            )

        case .appInfo:
            InfoView(
                authViewModel: authViewModel,
                onBack: { currentDestination = .home },
                onLogout: { authViewModel.logout() }
            )

        case .paywallLicense:
            PaywallLicenseView(companyId: compId, token: token, onBack: { currentDestination = .home })

        case .adminTicketList:
            let adminSupportVM = SupportViewModel(user: user, companyId: compId, idToken: token)
            AdminTicketListView(
                viewModel: adminSupportVM,
                onBack: { currentDestination = .home },
                onTicketClick: { ticketId, subject in
                    if let t = adminSupportVM.tickets.first(where: { $0.id == ticketId }) {
                        selectedTicketForChat = t
                    }
                },
                onOpenRatingReport: {
                    currentDestination = .supportRating
                }
            )
            .sheet(item: $selectedTicketForChat) { ticket in
                TicketChatDetailView(
                    viewModel: adminSupportVM,
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }

        case .help:
            HelpView(authViewModel: authViewModel, onBack: { currentDestination = .home })

        case .lichSu:
            LichSuView(authViewModel: authViewModel, thietBiId: "", onBack: { currentDestination = .home })

        case .superAdmin:
            SuperAdminPortalView(authViewModel: authViewModel, onBack: { currentDestination = .home })
        }
    }
}

