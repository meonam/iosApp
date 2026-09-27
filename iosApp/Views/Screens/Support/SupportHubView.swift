import SwiftUI

// MARK: - MÀN HÌNH DANH SÁCH PHIẾU HỖ TRỢ (ĐỒNG BỘ 1:1 VỚI ADMINTICKETLISTSCREEN.KT TRÊN ANDROID)
public struct SupportHubView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void
    var onSelectTicket: (SupportTicket) -> Void
    var onOpenRatingReport: () -> Void

    // Dialog & Sheet States
    @State private var showConfirmCleanClosed: Bool = false
    @State private var showGuideAlert: Bool = false
    @State private var showKtvMonitorSheet: Bool = false
    @State private var manuallyExpandedGroups: Set<String> = []
    @State private var manuallyCollapsedGroups: Set<String> = []

    public init(
        viewModel: SupportViewModel,
        onBack: @escaping () -> Void,
        onSelectTicket: @escaping (SupportTicket) -> Void,
        onOpenRatingReport: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onSelectTicket = onSelectTicket
        self.onOpenRatingReport = onOpenRatingReport
    }

    // Số vé đã đóng chưa bị ẩn (để dọn dẹp)
    private var closedTicketsToCleanCount: Int {
        viewModel.scopedTickets.filter {
            !viewModel.deletedTicketIds.contains($0.id) && (!$0.isOpen || $0.closedAt > 0)
        }.count
    }

    // MARK: - DATE GROUPING HELPER
    private func dateGroupKey(for timestamp: Int64) -> String {
        guard timestamp > 0 else { return "Khác" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hôm nay"
        } else if calendar.isDateInYesterday(date) {
            return "Hôm qua"
        } else {
            let df = DateFormatter()
            df.dateFormat = "dd/MM/yyyy"
            return df.string(from: date)
        }
    }

    private var groupedTickets: [(key: String, tickets: [SupportTicket])] {
        let filtered = viewModel.filteredTickets
        let groups = Dictionary(grouping: filtered) { t in
            dateGroupKey(for: t.createdAt)
        }

        // Sắp xếp nhóm: Hôm nay -> Hôm qua -> dd/MM/yyyy mới nhất
        let sortedKeys = groups.keys.sorted { k1, k2 in
            if k1 == "Hôm nay" { return true }
            if k2 == "Hôm nay" { return false }
            if k1 == "Hôm qua" { return true }
            if k2 == "Hôm qua" { return false }
            return k1 > k2
        }

        return sortedKeys.map { ($0, groups[$0] ?? []) }
    }

    private func isGroupCollapsed(key: String, openCountInGroup: Int) -> Bool {
        if manuallyExpandedGroups.contains(key) { return false }
        if manuallyCollapsedGroups.contains(key) { return true }
        // Tự động thu gọn nếu không có ticket đang mở và không phải hôm nay (chuẩn Android)
        return openCountInGroup == 0 && key != "Hôm nay"
    }

    private func toggleGroupCollapse(key: String, openCountInGroup: Int) {
        let currentlyCollapsed = isGroupCollapsed(key: key, openCountInGroup: openCountInGroup)
        if currentlyCollapsed {
            manuallyExpandedGroups.insert(key)
            manuallyCollapsedGroups.remove(key)
        } else {
            manuallyCollapsedGroups.insert(key)
            manuallyExpandedGroups.remove(key)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBarView(safeAreaTop: SafeAreaHelper.top(geometry))
                    searchAndFilterBar
                    ticketListView
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.rawTickets.isEmpty {
                viewModel.fetchTickets()
            }
        }
        // Sheet mở Online KTV Monitor
        .sheet(isPresented: $showKtvMonitorSheet) {
            OnlineKtvMonitorView(supportVM: viewModel, onBack: {
                showKtvMonitorSheet = false
            })
        }
        // Alert xác nhận dọn dẹp các yêu cầu đã đóng
        .alert(isPresented: $showConfirmCleanClosed) {
            Alert(
                title: Text("Dọn dẹp các yêu cầu đã đóng?"),
                message: Text("Hệ thống sẽ ẩn \(closedTicketsToCleanCount) yêu cầu hỗ trợ ĐÃ ĐÓNG khỏi danh sách để màn hình luôn gọn gàng.\n\n• Các yêu cầu đang mở (OPEN) được giữ nguyên để theo dõi tiếp.\n• Dữ liệu đánh giá, lịch sử sự cố vẫn được lưu trữ đầy đủ 100% trên hệ thống cho các báo cáo.\n• Bạn có thể xem lại hoặc hiện lại bất cứ lúc nào tại tab 'Đã ẩn'."),
                primaryButton: .destructive(Text("Dọn dẹp")) {
                    withAnimation {
                        viewModel.cleanClosedTickets()
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        // Alert hướng dẫn
        .alert("Hướng dẫn Quản lý Phiếu Hỗ trợ", isPresented: $showGuideAlert) {
            Button("Đã hiểu", role: .cancel) {}
        } message: {
            Text("• Bộ Lọc 4 Tab: Tất cả, Đang mở (xanh lá), Đã đóng, Đã ẩn (đỏ).\n• Nhóm theo ngày: Chạm tiêu đề ngày để thu gọn/mở rộng.\n• Chạm vào từng phiếu để mở khung chat 2 chiều, điều phối Kỹ thuật viên và xem hình ảnh đính kèm.\n• Nút Dọn dẹp trên thanh tiêu đề giúp ẩn hàng loạt các phiếu đã đóng.")
        }
    }

    private var emptyStateText: String {
        switch viewModel.filterTab {
        case "OPEN": return "Không có sự cố nào đang chờ xử lý"
        case "CLOSED": return "Chưa có sự cố nào được đóng"
        case "HIDDEN": return "Danh sách phiếu ẩn trống"
        default: return "Không tìm thấy yêu cầu hỗ trợ phù hợp"
        }
    }

    // MARK: - 4 FILTER TABS
    private var filterTabsView: some View {
        HStack(spacing: 4) {
            // Tab: Tất cả
            tabButton(
                title: "Tất cả",
                count: viewModel.allCount,
                tag: "ALL",
                activeBg: Color.white,
                activeFg: Color.appSecondaryDarkBlue
            )

            // Tab: Đang mở (màu xanh lá chuẩn Android)
            tabButton(
                title: "Đang mở",
                count: viewModel.openCount,
                tag: "OPEN",
                activeBg: Color(hex: "#DCFCE7"),
                activeFg: Color(hex: "#16A34A")
            )

            // Tab: Đã đóng
            tabButton(
                title: "Đã đóng",
                count: viewModel.closedCount,
                tag: "CLOSED",
                activeBg: Color.white,
                activeFg: Color.appSecondaryDarkBlue
            )

            // Tab: Đã ẩn (màu đỏ chuẩn Android)
            tabButton(
                title: "Đã ẩn",
                count: viewModel.hiddenCount,
                tag: "HIDDEN",
                activeBg: Color(hex: "#FEE2E2"),
                activeFg: Color(hex: "#B91C1C")
            )
        }
        .padding(4)
        .background(Color(hex: "#F1F5F9"))
        .cornerRadius(12)
    }

    private func tabButton(title: String, count: Int, tag: String, activeBg: Color, activeFg: Color) -> some View {
        let isSelected = viewModel.filterTab == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.filterTab = tag
            }
        }) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                Text("(\(count))")
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
            }
            .foregroundColor(isSelected ? activeFg : Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(isSelected ? activeBg : Color.clear)
            .cornerRadius(8)
            .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
        }
    }

    // MARK: - GROUP HEADER
    private func groupHeader(title: String, totalCount: Int, openCount: Int, isCollapsed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(openCount > 0 ? Color(hex: "#D97706") : Color.gray)
                .frame(width: 14)

            Image(systemName: "calendar")
                .font(.system(size: 12))
                .foregroundColor(openCount > 0 ? Color(hex: "#D97706") : Color.gray)

            Text("\(title) (\(totalCount))")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(openCount > 0 ? Color.appTextPrimary : Color.gray)

            Spacer()

            if openCount > 0 {
                Text("\(openCount) đang mở")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "#B45309"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#FEF3C7"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
            } else {
                Text("✓ Đã xong")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#64748B"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#F1F5F9"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.96))
        .cornerRadius(8)
    }

    // MARK: - SUBVIEWS
    @ViewBuilder
    private func topBarView(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Trung tâm hỗ trợ")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Nút 1: Hướng dẫn
                Button(action: { showGuideAlert = true }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }

                // Nút 2: Giám sát lộ trình KTV
                Button(action: { showKtvMonitorSheet = true }) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(viewModel.rawTickets.contains { $0.isOpen } ? Color(hex: "#10B981") : .white)
                }

                // Nút 3: Dọn dẹp các yêu cầu đã đóng
                Button(action: {
                    if closedTicketsToCleanCount > 0 {
                        showConfirmCleanClosed = true
                    }
                }) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }

                // Nút 4: Báo cáo SLA / Đánh giá
                Button(action: onOpenRatingReport) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                // Nút 5: Làm mới
                Button(action: { viewModel.fetchTickets() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color.appTopBarColor)
    }

    @ViewBuilder
    private var searchAndFilterBar: some View {
        VStack(spacing: 10) {
            filterTabsView

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextSecondary)
                TextField("Tìm mã phiếu, tiêu đề, người gửi, đơn vị...", text: $viewModel.searchQuery)
                    .font(.system(size: 13.5))
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var ticketListView: some View {
        if viewModel.isLoading && viewModel.rawTickets.isEmpty {
            Spacer()
            ProgressView("Đang tải dữ liệu...")
                .font(.system(size: 14))
            Spacer()
        } else if viewModel.filteredTickets.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "tray.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.appTextSecondary.opacity(0.6))
                Text(emptyStateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedTickets, id: \.key) { group in
                        let openInGroup = group.tickets.filter { $0.isOpen && $0.closedAt <= 0 }.count
                        let isCollapsed = isGroupCollapsed(key: group.key, openCountInGroup: openInGroup)

                        Section(
                            header: groupHeader(
                                title: group.key,
                                totalCount: group.tickets.count,
                                openCount: openInGroup,
                                isCollapsed: isCollapsed
                            )
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    toggleGroupCollapse(key: group.key, openCountInGroup: openInGroup)
                                }
                            }
                        ) {
                            if !isCollapsed {
                                ForEach(group.tickets) { ticket in
                                    TicketItemView(
                                        ticket: ticket,
                                        isHidden: viewModel.filterTab == "HIDDEN",
                                        onClick: {
                                            onSelectTicket(ticket)
                                        },
                                        onToggleHide: {
                                            viewModel.toggleHideTicket(ticket.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .refreshable {
                viewModel.fetchTickets()
            }
        }
    }
}
