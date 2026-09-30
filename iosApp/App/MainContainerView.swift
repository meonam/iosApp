import SwiftUI

// MARK: - MAIN CONTAINER VIEW (ĐỒNG BỘ 1:1 THEO MAINACTIVITY.KT TRÊN ANDROID)
public struct MainContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var homeViewModel = HomeViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var supportViewModel = SupportViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var adminViewModel = AdminViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var deviceViewModel = DeviceViewModel(user: User(), companyId: "SGCOOP", idToken: "")
    @StateObject private var incomingCallManager = IncomingCallManager.shared
    @State private var currentDestination: DrawerDestination = .home
    @State private var isDrawerOpen: Bool = false
    @State private var selectedTicketForChat: SupportTicket? = nil
    @State private var pendingNavTicketId: String? = nil   // Điều hướng từ notification "Tiếp nhận"

    // Sheets mở từ khắp nơi
    @State private var showAddDeviceSheet: Bool = false
    @State private var showPrintSheet: Bool = false
    @State private var showRatingReportSheet: Bool = false

    // FAB Draggable Position (Cho phép người dùng kéo thả di chuyển nút nổi bất cứ đâu)
    @AppStorage("floating_fab_offset_x") private var fabOffsetX: Double = 0.0
    @AppStorage("floating_fab_offset_y") private var fabOffsetY: Double = 0.0
    @State private var dragTranslation: CGSize = .zero
    @State private var isDragging: Bool = false

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
                                incomingCallManager.stopListening()
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
                                floatingSupportButton(geometry: geometry)
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
                                        incomingCallManager.stopListening()
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

                        // 4. OVERLAY CUỘC GỌI ĐẾN (INCOMING CALL POPUP BANNER TOÀN CỤC)
                        if let incomingCall = incomingCallManager.activeIncomingCall {
                            IncomingCallBannerView(
                                call: incomingCall,
                                onAccept: {
                                    incomingCallManager.acceptCall()
                                },
                                onReject: {
                                    incomingCallManager.rejectCall()
                                }
                            )
                        }
                    }
                    .fullScreenCover(isPresented: $incomingCallManager.isCallPresented) {
                        CallView()
                    }
                    .onAppear {
                        incomingCallManager.startListening(user: user, companyId: compId, idToken: token)
                        WebRtcCallManager.shared.companyId = compId
                        WebRtcCallManager.shared.idToken = token

                        homeViewModel.user = user
                        homeViewModel.companyId = compId
                        homeViewModel.idToken = token
                        homeViewModel.loadDashboardData()

                        supportViewModel.user = user
                        supportViewModel.companyId = compId
                        supportViewModel.idToken = token
                        if authViewModel.isAuthenticated {
                            supportViewModel.fetchTickets()
                            supportViewModel.startAutoPolling()
                        }

                        adminViewModel.currentUser = user
                        adminViewModel.companyId = compId
                        adminViewModel.idToken = token
                        adminViewModel.fetchAllDataIfNeeded()

                        deviceViewModel.user = user
                        deviceViewModel.companyId = compId.isEmpty || compId == "DEFAULT" ? "SGCOOP" : compId
                        deviceViewModel.idToken = token
                    }
                    .onChange(of: authViewModel.currentUser) { newUser in
                        if let u = newUser {
                            let cid = authViewModel.currentCompanyId
                            let tok = authViewModel.currentIdToken

                            incomingCallManager.startListening(user: u, companyId: cid, idToken: tok)
                            WebRtcCallManager.shared.companyId = cid
                            WebRtcCallManager.shared.idToken = tok

                            homeViewModel.user = u
                            homeViewModel.companyId = cid
                            homeViewModel.idToken = tok
                            homeViewModel.loadDashboardData()

                            supportViewModel.user = u
                            supportViewModel.companyId = cid
                            supportViewModel.idToken = tok
                            supportViewModel.fetchTickets()
                            supportViewModel.startAutoPolling()

                            adminViewModel.currentUser = u
                            adminViewModel.companyId = cid
                            adminViewModel.idToken = tok
                            adminViewModel.fetchAllDataIfNeeded()

                            deviceViewModel.user = u
                            deviceViewModel.companyId = cid.isEmpty || cid == "DEFAULT" ? "SGCOOP" : cid
                            deviceViewModel.idToken = tok
                        } else {
                            incomingCallManager.stopListening()
                            supportViewModel.stopAutoPolling()
                            BackgroundKeepAliveService.shared.stop()
                        }
                    }
                    .onChange(of: scenePhase) { newPhase in
                        guard authViewModel.isAuthenticated, let user = authViewModel.currentUser else { return }
                        switch newPhase {
                        case .active:
                            // Foreground: cập nhật presence + restart stream
                            PresenceHelper.shared.setPresence(
                                companyId: authViewModel.currentCompanyId,
                                email: user.email,
                                isOnline: true,
                                idToken: authViewModel.currentIdToken
                            )
                            // Khởi động lại polling nhanh 2s và kích hoạt keep-alive
                            BackgroundKeepAliveService.shared.start()
                            supportViewModel.startAutoPolling(interval: 2.0)
                        case .background:
                            // Background: giữ nguyên polling 2s — KeepAlive duy trì tiến trình 24/7
                            // KHÔNG stopAutoPolling() — đây là yêu cầu bắt buộc: app nền vẫn nhận lệnh
                            BackgroundKeepAliveService.shared.start()
                            supportViewModel.keepPollingInBackground()
                        case .inactive:
                            break
                        @unknown default:
                            break
                        }
                    }
                    // MARK: - XỬ LÝ ĐIỀU HƯỚNG TỪ THÔNG BÁO "TIẾP NHẬN" (ĐỒNG BỘ ANDROID MainActivity.handleNotificationIntent)
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("QLTB_NavigateToTicket"))) { note in
                        guard let tid = note.userInfo?["ticketId"] as? String, !tid.isEmpty else { return }
                        // Chuyển về tab Hỗ trợ
                        currentDestination = .staffSupport
                        // Tìm ticket trong cache hiện tại
                        if let found = supportViewModel.tickets.first(where: { $0.id == tid }) {
                            selectedTicketForChat = found
                        } else {
                            // Chưa có trong cache → lưu pending, sau khi fetch xong sẽ mở
                            pendingNavTicketId = tid
                            supportViewModel.fetchTickets()
                        }
                    }
                    // Theo dõi danh sách ticket: nếu đang pending điều hướng từ notification thì mở ngay khi có
                    .onChange(of: supportViewModel.tickets) { newTickets in
                        if let tid = pendingNavTicketId,
                           let found = newTickets.first(where: { $0.id == tid }) {
                            pendingNavTicketId = nil
                            selectedTicketForChat = found
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

    // MARK: - FLOATING ACTION BUTTON (DRAGGABLE GREEN SUPPORT FAB WITH BADGE - DI CHUYỂN BẤT CỨ ĐÂU)
    private func floatingSupportButton(geometry: GeometryProxy) -> some View {
        let currentX = CGFloat(fabOffsetX) + dragTranslation.width
        let currentY = CGFloat(fabOffsetY) + dragTranslation.height

        let fabSize: CGFloat = 56
        let margin: CGFloat = 16
        let topSafe = SafeAreaHelper.top(geometry)
        let bottomSafe = SafeAreaHelper.bottom(geometry)

        // Tính toán giới hạn màn hình để nút không bị kéo ra ngoài
        let minX = -(geometry.size.width - fabSize - margin * 2)
        let maxX: CGFloat = 8
        let minY = -(geometry.size.height - (bottomSafe + 64 + fabSize) - topSafe - margin)
        let maxY = CGFloat(bottomSafe + 40)

        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.appFabGreen)
                .frame(width: fabSize, height: fabSize)
                .shadow(color: Color.appFabGreen.opacity(isDragging ? 0.6 : 0.4), radius: isDragging ? 12 : 8, x: 0, y: isDragging ? 6 : 4)

            Image(systemName: "headphones")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: fabSize, height: fabSize)

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
        .contentShape(Circle())
        .scaleEffect(isDragging ? 1.08 : 1.0)
        .offset(x: currentX, y: currentY)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    let distance = hypot(value.translation.width, value.translation.height)
                    if distance < 7 {
                        // Thao tác Click / Chạm mở Hub hỗ trợ
                        dragTranslation = .zero
                        isDragging = false
                        currentDestination = .supportHub
                    } else {
                        // Thao tác Kéo thả di chuyển nút FAB
                        let finalX = CGFloat(fabOffsetX) + value.translation.width
                        let finalY = CGFloat(fabOffsetY) + value.translation.height
                        dragTranslation = .zero
                        isDragging = false

                        let clampedX = min(max(finalX, minX), maxX)
                        let clampedY = min(max(finalY, minY), maxY)

                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            fabOffsetX = Double(clampedX)
                            fabOffsetY = Double(clampedY)
                        }
                    }
                }
        )
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
                viewModel: deviceViewModel,
                onBack: { currentDestination = .home },
                onNavigateToAdd: { showAddDeviceSheet = true },
                onNavigateToPrint: { currentDestination = .printBarcode }
            )
            .sheet(isPresented: $showAddDeviceSheet) {
                AddDeviceView(
                    viewModel: deviceViewModel,
                    onDismiss: {
                        showAddDeviceSheet = false
                        deviceViewModel.fetchDevices(isRefresh: true)
                    },
                    onSuccess: { _ in
                        showAddDeviceSheet = false
                        deviceViewModel.fetchDevices(isRefresh: true)
                    }
                )
            }

        case .addDevice:
            AddDeviceView(
                viewModel: deviceViewModel,
                onDismiss: { currentDestination = .deviceList },
                onSuccess: { _ in
                    currentDestination = .deviceList
                    deviceViewModel.fetchDevices(isRefresh: true)
                }
            )

        case .printBarcode:
            PrintQrLabelView(
                viewModel: deviceViewModel,
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
                viewModel: supportViewModel,
                authViewModel: authViewModel,
                onBack: { currentDestination = .home }
            )
            .sheet(item: $selectedTicketForChat) { ticket in
                TicketChatDetailView(
                    viewModel: supportViewModel,
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }

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
                supportVM: supportViewModel,
                onBack: { currentDestination = .home }
            )

        case .peripherals:
            PeripheralsView(onBack: { currentDestination = .home })

        case .attendanceHistory:
            AttendanceHistoryView(authViewModel: authViewModel, onBack: { currentDestination = .home })

        case .attendance:
            AttendanceCheckInView(
                user: user,
                companyId: compId,
                idToken: token,
                onBack: { currentDestination = .home },
                onNavigateToHistory: { currentDestination = .attendanceHistory },
                onNavigateToReport: { currentDestination = .attendanceReport }
            )

        case .attendanceReport:
            AttendanceReportView(
                authViewModel: authViewModel,
                onBack: { currentDestination = .home },
                onNavigateToSettings: { currentDestination = .systemSettings }
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

