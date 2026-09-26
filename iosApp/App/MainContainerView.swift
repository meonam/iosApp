import SwiftUI

// MARK: - MAIN CONTAINER VIEW (THAY THẾ TOÀN BỘ CONTENTVIEW CŨ)
public struct MainContainerView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var currentDestination: DrawerDestination = .home
    @State private var isDrawerOpen: Bool = false
    @State private var selectedTicketForChat: SupportTicket? = nil

    public init() {}

    public var body: some View {
        Group {
            if !authViewModel.isAuthenticated {
                LoginView(viewModel: authViewModel) {
                    currentDestination = .home
                }
            } else if let user = authViewModel.currentUser {
                ZStack(alignment: .leading) {
                    // MÀN HÌNH CHÍNH THEO DESTINATION
                    destinationView(for: currentDestination, user: user)
                        .disabled(isDrawerOpen)

                    // NỀN MỜ KHI MỞ DRAWER
                    if isDrawerOpen {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isDrawerOpen = false
                                }
                            }
                            .zIndex(1)

                        // DRAWER THANH BÊN
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
                        .zIndex(2)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for dest: DrawerDestination, user: User) -> some View {
        switch dest {
        case .home:
            HomeScreenView(
                viewModel: HomeViewModel(
                    user: user,
                    companyId: authViewModel.currentCompanyId,
                    idToken: authViewModel.currentIdToken
                ),
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
                viewModel: DeviceViewModel(
                    user: user,
                    companyId: authViewModel.currentCompanyId,
                    idToken: authViewModel.currentIdToken
                ),
                onBack: { currentDestination = .home },
                onNavigateToAdd: { /* Mở form thêm mới */ },
                onNavigateToPrint: { /* Mở màn hình in */ }
            )
        case .supportHub:
            SupportHubView(
                viewModel: SupportViewModel(
                    user: user,
                    companyId: authViewModel.currentCompanyId,
                    idToken: authViewModel.currentIdToken
                ),
                onBack: { currentDestination = .home },
                onSelectTicket: { ticket in
                    selectedTicketForChat = ticket
                },
                onOpenRatingReport: { /* Mở báo cáo SLA */ }
            )
            .sheet(item: $selectedTicketForChat) { ticket in
                TicketChatDetailView(
                    viewModel: SupportViewModel(
                        user: user,
                        companyId: authViewModel.currentCompanyId,
                        idToken: authViewModel.currentIdToken
                    ),
                    ticket: ticket,
                    onBack: { selectedTicketForChat = nil }
                )
            }
        case .attendance:
            AttendanceCheckInView(
                viewModel: AttendanceViewModel(
                    user: user,
                    companyId: authViewModel.currentCompanyId,
                    idToken: authViewModel.currentIdToken
                ),
                onBack: { currentDestination = .home }
            )
        case .shiftSchedule:
            ShiftScheduleView(
                viewModel: ShiftViewModel(
                    user: user,
                    companyId: authViewModel.currentCompanyId,
                    idToken: authViewModel.currentIdToken
                ),
                onBack: { currentDestination = .home }
            )
        default:
            // Placeholder cho các màn hình đang tiếp tục xây dựng
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
                Image(systemName: "hammer.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text("Màn hình đang được chuyển đổi chuẩn 1:1 theo Android")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
            }
        }
    }
}
