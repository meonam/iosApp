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
                                    proBottomBar(bottomInset: geometry.safeAreaInsets.bottom)
                                }
                            }
                            .disabled(isDrawerOpen)

                            // 2. NÚT NỔI HỖ TRỢ KỸ THUẬT (FAB - GREEN SUPPORT BUTTON WITH BADGE 99+)
                            if isMainTab && currentDestination != .supportHub && currentDestination != .staffSupport {
                                floatingSupportButton
                                    .padding(.trailing, 16)
                                    .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom + 58 : 68)
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
                                openTicketsCount: 0,
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
                    }
                }
            }
        }
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

            let isSupportSelected = currentDestination == .supportHub || currentDestination == .staffSupport
            bottomNavItem(
                title: "Hỗ trợ",
                icon: "headphones",
                badgeText: "99+",
                isSelected: isSupportSelected
            ) {
                if let u = authViewModel.currentUser {
                    if u.isAdmin || u.isSuperAdmin || u.isHelpDesk || u.isTechnician {
                        currentDestination = .supportHub
                    } else {
                        currentDestination = .staffSupport
                    }
                }
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
        .padding(.bottom, max(bottomInset - 4, 8))
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
            if let u = authViewModel.currentUser {
                if u.isAdmin || u.isSuperAdmin || u.isHelpDesk || u.isTechnician {
                    currentDestination = .supportHub
                } else {
                    currentDestination = .staffSupport
                }
            }
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

                Text("99+")
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

    // MARK: - ROUTER ĐIỀU HƯỚNG MÀN HÌNH (TOÀN BỘ CHỨC NĂNG 1:1 THEO ANDROID)
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
                viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
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
                    viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }

        case .supportRating:
            SupportRatingReportView(
                viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .supportHub }
            )

        case .specialistTeams:
            SpecialistTeamManagerView(
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
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
                onBack: { currentDestination = .home }
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
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .approveStaff:
            ApproveStaffView(
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .departmentManagement:
            DepartmentManagerView(
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .unitManagement, .regionManagement:
            UnitRegionManagerView(
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home }
            )

        case .systemSettings:
            SystemSettingsView(
                viewModel: AdminViewModel(user: user, companyId: compId, idToken: token),
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
            AdminTicketListView(
                viewModel: SupportViewModel(user: user, companyId: compId, idToken: token),
                onBack: { currentDestination = .home },
                onTicketClick: { ticketId, subject in
                    currentDestination = .supportHub
                }
            )

        case .help:
            HelpView(authViewModel: authViewModel, onBack: { currentDestination = .home })

        case .lichSu:
            LichSuView(authViewModel: authViewModel, thietBiId: "", onBack: { currentDestination = .home })

        case .superAdmin:
            SuperAdminPortalView(authViewModel: authViewModel, onBack: { currentDestination = .home })
        }
    }
}

