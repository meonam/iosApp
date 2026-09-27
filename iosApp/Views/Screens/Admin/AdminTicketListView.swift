import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ TICKET DÀNH CHO ADMIN / HELPDESK (ĐỒNG BỘ 1:1 VỚI ADMINTICKETLISTSCREEN.KT)
public struct AdminTicketListView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void
    var onTicketClick: (String, String) -> Void
    var onOpenRatingReport: () -> Void

    @State private var filterStatus: String = "ALL" // "ALL", "OPEN", "CLOSED", "HIDDEN"
    @State private var searchQuery: String = ""
    @State private var collapsedGroups: Set<String> = []
    @State private var showConfirmCleanClosed: Bool = false
    @State private var deletedTicketIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "support_deleted_ticket_ids") ?? []
        return Set(saved)
    }()

    public init(
        viewModel: SupportViewModel,
        onBack: @escaping () -> Void,
        onTicketClick: @escaping (String, String) -> Void,
        onOpenRatingReport: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onTicketClick = onTicketClick
        self.onOpenRatingReport = onOpenRatingReport
    }

    private var visibleTickets: [SupportTicket] {
        viewModel.tickets.filter { ticket in
            // Filter by hidden
            if filterStatus == "HIDDEN" {
                if !deletedTicketIds.contains(ticket.id) { return false }
            } else {
                if deletedTicketIds.contains(ticket.id) { return false }
                let isClosed = ticket.status.uppercased() == "CLOSED" || ticket.closedAt > 0
                if filterStatus == "OPEN" && isClosed { return false }
                if filterStatus == "CLOSED" && !isClosed { return false }
            }

            // Search filter
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let match = ticket.subject.lowercased().contains(q) ||
                            ticket.creatorName.lowercased().contains(q) ||
                            ticket.creatorEmail.lowercased().contains(q) ||
                            ticket.id.lowercased().contains(q) ||
                            ticket.donVi.lowercased().contains(q) ||
                            ticket.assetName.lowercased().contains(q)
                if !match { return false }
            }

            return true
        }
    }

    private var closedTicketsToClean: [SupportTicket] {
        viewModel.tickets.filter { t in
            !deletedTicketIds.contains(t.id) &&
            (t.status.uppercased() == "CLOSED" || t.closedAt > 0)
        }
    }

    // Grouping by Date: "Hôm nay", "Hôm qua", "dd/MM/yyyy"
    private var groupedTickets: [(String, [SupportTicket])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"

        var dict: [String: [SupportTicket]] = [:]
        var order: [String] = []

        for ticket in visibleTickets {
            let tDate = Date(timeIntervalSince1970: TimeInterval(ticket.createdAt) / 1000)
            let start = calendar.startOfDay(for: tDate)

            let groupKey: String
            if start == today {
                groupKey = "Hôm nay"
            } else if start == yesterday {
                groupKey = "Hôm qua"
            } else {
                groupKey = formatter.string(from: tDate)
            }

            if dict[groupKey] == nil {
                dict[groupKey] = []
                order.append(groupKey)
            }
            dict[groupKey]?.append(ticket)
        }

        return order.map { key in
            (key, dict[key] ?? [])
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── 1. TOP BAR ──────────────────────────────────────
                    topBar(safeAreaTop: geometry.safeAreaInsets.top)

                    // ── 2. SEGMENTED TABS: Tất cả | Đang mở | Đã đóng | Đã ẩn ──
                    segmentedTabsBar

                    // ── 3. SEARCH BAR ──────────────────────────────────
                    searchBar

                    // ── 4. TICKET LIST VỚI DATE STICKY HEADERS ─────────
                    if viewModel.isLoading && viewModel.tickets.isEmpty {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Spacer()
                    } else if visibleTickets.isEmpty {
                        emptyStateView
                    } else {
                        ticketListView
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.tickets.isEmpty {
                viewModel.fetchTickets()
            }
        }
        .alert(isPresented: $showConfirmCleanClosed) {
            Alert(
                title: Text("Dọn dẹp các yêu cầu đã đóng?"),
                message: Text("Hệ thống sẽ ẩn \(closedTicketsToClean.count) yêu cầu hỗ trợ ĐÃ ĐÓNG khỏi màn hình. Bạn có thể xem lại hoặc hiện lại bất cứ lúc nào trong tab 'Đã ẩn'."),
                primaryButton: .destructive(Text("Dọn dẹp ngay (\(closedTicketsToClean.count))")) {
                    cleanClosedTickets()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - TOP BAR
    private func topBar(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Quản lý Yêu cầu (\(visibleTickets.count))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Nút Báo cáo Đánh giá
                Button(action: onOpenRatingReport) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }

                // Nút Dọn dẹp ticket đã đóng
                if !closedTicketsToClean.isEmpty {
                    Button(action: { showConfirmCleanClosed = true }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 19))
                            .foregroundColor(.white)
                    }
                }

                // Nút Refresh
                Button(action: { viewModel.fetchTickets() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - SEGMENTED TABS BAR
    private var segmentedTabsBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Tất cả", count: viewModel.tickets.filter { !deletedTicketIds.contains($0.id) }.count, tag: "ALL")
            tabButton(
                title: "Đang mở",
                count: viewModel.tickets.filter { !deletedTicketIds.contains($0.id) && $0.isOpen }.count,
                tag: "OPEN",
                activeColor: Color(hex: "#16A34A"),
                activeBg: Color(hex: "#DCFCE7")
            )
            tabButton(
                title: "Đã đóng",
                count: viewModel.tickets.filter { !deletedTicketIds.contains($0.id) && !$0.isOpen }.count,
                tag: "CLOSED"
            )
            tabButton(
                title: "Đã ẩn",
                count: deletedTicketIds.count,
                tag: "HIDDEN",
                activeColor: Color(hex: "#B91C1C"),
                activeBg: Color(hex: "#FEE2E2")
            )
        }
        .padding(4)
        .background(Color(hex: "#F1F5F9"))
        .cornerRadius(12)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func tabButton(
        title: String,
        count: Int,
        tag: String,
        activeColor: Color = Color.appSecondaryDarkBlue,
        activeBg: Color = Color.white
    ) -> some View {
        let isSel = filterStatus == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                filterStatus = tag
            }
        }) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11.5, weight: isSel ? .bold : .medium))
                if count > 0 {
                    Text("(\(count))")
                        .font(.system(size: 10, weight: isSel ? .bold : .regular))
                }
            }
            .foregroundColor(isSel ? activeColor : Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(isSel ? activeBg : Color.clear)
            .cornerRadius(8)
            .shadow(color: isSel ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
        }
    }

    // MARK: - SEARCH BAR
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.gray)
                .font(.system(size: 14))

            TextField("Tìm theo tiêu đề, người tạo, đơn vị, mã...", text: $searchQuery)
                .font(.system(size: 13))

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - TICKET LIST WITH DATE STICKY HEADERS
    private var ticketListView: some View {
        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedTickets, id: \.0) { dateGroup, ticketsInGroup in
                    Section(
                        header: dateHeaderView(dateGroup: dateGroup, count: ticketsInGroup.count)
                    ) {
                        if !collapsedGroups.contains(dateGroup) {
                            ForEach(ticketsInGroup) { ticket in
                                TicketItemView(
                                    ticket: ticket,
                                    isHidden: filterStatus == "HIDDEN",
                                    onClick: {
                                        onTicketClick(ticket.id, ticket.subject)
                                    },
                                    onToggleHide: {
                                        toggleHideTicket(ticket.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - STICKY DATE HEADER
    private func dateHeaderView(dateGroup: String, count: Int) -> some View {
        let isCollapsed = collapsedGroups.contains(dateGroup)
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isCollapsed {
                    collapsedGroups.remove(dateGroup)
                } else {
                    collapsedGroups.insert(dateGroup)
                }
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.gray)

                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)

                Text("\(dateGroup) (\(count))")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Color.gray)

                Rectangle()
                    .fill(Color(hex: "#E2E8F0"))
                    .frame(height: 1)
            }
            .padding(.vertical, 6)
            .background(Color.appBackground.opacity(0.95))
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - EMPTY STATE VIEW
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#CBD5E1"))

            Text("Không có yêu cầu nào")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)

            Text("Hiện tại không có yêu cầu nào trong danh sách này.")
                .font(.system(size: 12))
                .foregroundColor(Color.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    // MARK: - HELPERS: CLEAN CLOSED & TOGGLE HIDE
    private func cleanClosedTickets() {
        let idsToHide = closedTicketsToClean.map { $0.id }
        deletedTicketIds.formUnion(idsToHide)
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_deleted_ticket_ids")
        showConfirmCleanClosed = false
    }

    private func toggleHideTicket(_ ticketId: String) {
        if deletedTicketIds.contains(ticketId) {
            deletedTicketIds.remove(ticketId)
        } else {
            deletedTicketIds.insert(ticketId)
        }
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_deleted_ticket_ids")
    }
}
