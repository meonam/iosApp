import SwiftUI

// MARK: - MÀN HÌNH DANH SÁCH PHIẾU HỖ TRỢ TRỰC TUYẾN & XỬ LÝ SỰ CỐ (ĐỒNG BỘ 1:1 VỚI DESKTOP SUPPORT TICKET LIST)
public struct SupportHubView: View {
    @ObservedObject var viewModel: SupportViewModel
    var authViewModel: AuthViewModel?
    var onBack: () -> Void
    var onSelectTicket: (SupportTicket) -> Void
    var onOpenRatingReport: () -> Void

    // Dialog & Sheet States
    @State private var showingCreateTicketSheet: Bool = false
    @State private var showConfirmCleanClosed: Bool = false
    @State private var showGuideAlert: Bool = false
    @State private var showKtvMonitorSheet: Bool = false
    @State private var manuallyExpandedGroups: Set<String> = []
    @State private var manuallyCollapsedGroups: Set<String> = []
    @State private var ticketToDelete: SupportTicket? = nil
    @State private var showDeleteSingleConfirm: Bool = false

    public init(
        viewModel: SupportViewModel,
        authViewModel: AuthViewModel? = nil,
        onBack: @escaping () -> Void,
        onSelectTicket: @escaping (SupportTicket) -> Void,
        onOpenRatingReport: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.authViewModel = authViewModel
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
        // Tự động thu gọn nếu không có ticket đang mở và không phải hôm nay (chuẩn Desktop/Android)
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
                    desktopHeaderAndFilterBar
                    ticketListView
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if let u = authViewModel?.currentUser {
                viewModel.user = u
            }
            if let c = authViewModel?.currentCompanyId, !c.isEmpty {
                viewModel.companyId = c.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            }
            if let t = authViewModel?.currentIdToken, !t.isEmpty {
                viewModel.idToken = t
            }
            viewModel.fetchTickets()
        }
        .refreshable {
            viewModel.fetchTickets()
        }
        // Sheet mở Online KTV Monitor
        .sheet(isPresented: $showKtvMonitorSheet) {
            OnlineKtvMonitorView(supportVM: viewModel, onBack: {
                showKtvMonitorSheet = false
            })
        }
        // Sheet Tạo yêu cầu hỗ trợ mới (Dành cho mọi role)
        .sheet(isPresented: $showingCreateTicketSheet) {
            if let authVM = authViewModel {
                CreateTicketSheetView(
                    supportVM: viewModel,
                    authViewModel: authVM,
                    onSuccess: {
                        showingCreateTicketSheet = false
                        viewModel.fetchTickets()
                    },
                    onCancel: {
                        showingCreateTicketSheet = false
                    }
                )
            }
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
        // Alert xóa 1 ticket
        .alert("Xóa yêu cầu hỗ trợ?", isPresented: $showDeleteSingleConfirm) {
            Button("Hủy", role: .cancel) { ticketToDelete = nil }
            Button("Xóa", role: .destructive) {
                if let t = ticketToDelete {
                    viewModel.hideTicket(id: t.id)
                    ticketToDelete = nil
                }
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa yêu cầu '\(ticketToDelete?.subject ?? "")' khỏi danh sách không?")
        }
        // Alert hướng dẫn
        .alert("Hướng dẫn Quản lý Phiếu Hỗ trợ", isPresented: $showGuideAlert) {
            Button("Đã hiểu", role: .cancel) {}
        } message: {
            Text("• Bộ Lọc 4 Tab: Tất cả, Đang mở, Đã đóng, Đã ẩn.\n• Kênh tiếp nhận: App, Email, Phòng ban.\n• Nhóm theo ngày: Chạm tiêu đề ngày để thu gọn/mở rộng.\n• Chạm vào từng phiếu để mở khung chat 2 chiều, điều phối Kỹ thuật viên và xem hình ảnh đính kèm.")
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

    // MARK: - DESKTOP HEADER & FILTER BAR (HÌNH 2)
    @ViewBuilder
    private var desktopHeaderAndFilterBar: some View {
        VStack(spacing: 8) {
            // Hàng Tiêu Đề Panel: 📋 Hỗ trợ trực tuyến & Xử lý sự cố (N) + Nút Xóa tất cả
            HStack {
                HStack(spacing: 6) {
                    Text("📋")
                        .font(.system(size: 14))
                    Text("Hỗ trợ trực tuyến & Xử lý sự cố (\(viewModel.allCount))")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(Color(hex: "#0B2545"))
                }

                Spacer()

                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin || viewModel.user.isManager {
                    Button(action: {
                        if closedTicketsToCleanCount > 0 {
                            showConfirmCleanClosed = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Xóa tất cả")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#E11D48"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#FFE4E6"))
                        .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Hàng 1: 4 Tabs Trạng thái (Segmented Tabs nền xám bo tròn)
            statusTabsRow

            // Hàng 2: Omni-Channel Filter Chips (Tất cả, App, Email, Phòng ban - bỏ Zalo)
            omniChannelChipsRow

            // Hàng 3: Ô tìm kiếm
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextSecondary)
                TextField("Tìm mã phiếu, tiêu đề, người gửi, đơn vị...", text: $viewModel.searchQuery)
                    .font(.system(size: 13))
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 2)
    }

    // MARK: - 4 STATUS TABS (HÌNH 2)
    private var statusTabsRow: some View {
        HStack(spacing: 4) {
            statusTabButton(title: "Tất cả", count: viewModel.allCount, tag: "ALL")
            statusTabButton(title: "Đang mở", count: viewModel.openCount, tag: "OPEN")
            statusTabButton(title: "Đã đóng", count: viewModel.closedCount, tag: "CLOSED")
            statusTabButton(title: "Đã ẩn", count: viewModel.hiddenCount, tag: "HIDDEN")
        }
        .padding(3)
        .background(Color(hex: "#E2E8F0").opacity(0.65))
        .cornerRadius(10)
        .padding(.horizontal, 12)
    }

    private func statusTabButton(title: String, count: Int, tag: String) -> some View {
        let isSelected = viewModel.filterTab == tag
        let activeBg: Color = {
            switch tag {
            case "OPEN": return Color(hex: "#DCFCE7")
            case "CLOSED": return Color.white
            case "HIDDEN": return Color.white
            default: return Color(hex: "#0B2545")
            }
        }()
        let activeFg: Color = {
            switch tag {
            case "OPEN": return Color(hex: "#16A34A")
            case "CLOSED": return Color(hex: "#1E293B")
            case "HIDDEN": return Color(hex: "#64748B")
            default: return .white
            }
        }()

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.filterTab = tag
            }
        }) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                Text("(\(count))")
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
            }
            .foregroundColor(isSelected ? activeFg : Color(hex: "#64748B"))
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(isSelected ? activeBg : Color.clear)
            .cornerRadius(7)
            .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 1, y: 1)
        }
    }

    // MARK: - OMNI-CHANNEL FILTER CHIPS (HÌNH 2 - BỎ ZALO)
    private var omniChannelChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // Tất cả
                channelChip(
                    title: "Tất cả (\(viewModel.allCount))",
                    icon: nil,
                    tag: "ALL",
                    activeBg: Color(hex: "#0B2545"),
                    activeFg: .white,
                    inactiveBg: Color(hex: "#F1F5F9"),
                    inactiveFg: Color(hex: "#475569")
                )

                // App
                channelChip(
                    title: "App (\(viewModel.appCount))",
                    icon: "iphone",
                    tag: "APP",
                    activeBg: Color(hex: "#0F766E"),
                    activeFg: .white,
                    inactiveBg: Color(hex: "#F0FDFA"),
                    inactiveFg: Color(hex: "#0F766E"),
                    borderColor: Color(hex: "#99F6E4")
                )

                // Email
                channelChip(
                    title: "Email (\(viewModel.emailCount))",
                    icon: "envelope.fill",
                    tag: "EMAIL",
                    activeBg: Color(hex: "#EA4335"),
                    activeFg: .white,
                    inactiveBg: Color(hex: "#FFF1F2"),
                    inactiveFg: Color(hex: "#EA4335"),
                    borderColor: Color(hex: "#FECDD3")
                )

                // Phòng ban
                channelChip(
                    title: "Phòng ban (\(viewModel.deptCount))",
                    icon: "building.2.fill",
                    tag: "DEPARTMENT",
                    activeBg: Color(hex: "#0D9488"),
                    activeFg: .white,
                    inactiveBg: Color(hex: "#F0FDFA"),
                    inactiveFg: Color(hex: "#0D9488"),
                    borderColor: Color(hex: "#99F6E4")
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        }
    }

    private func channelChip(
        title: String,
        icon: String?,
        tag: String,
        activeBg: Color,
        activeFg: Color,
        inactiveBg: Color,
        inactiveFg: Color,
        borderColor: Color? = nil
    ) -> some View {
        let isSelected = viewModel.filterSource == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.filterSource = tag
            }
        }) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                }
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .bold : .semibold))
            }
            .foregroundColor(isSelected ? activeFg : inactiveFg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? activeBg : inactiveBg)
            .cornerRadius(16)
            .overlay(
                Group {
                    if let border = borderColor, !isSelected {
                        RoundedRectangle(cornerRadius: 16).stroke(border, lineWidth: 1)
                    }
                }
            )
        }
    }

    // MARK: - GROUP HEADER (HÌNH 2: v 📅 Hôm nay (2) [2 đang mở])
    private func groupHeader(title: String, totalCount: Int, openCount: Int, isCollapsed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(openCount > 0 ? Color(hex: "#D97706") : Color.gray)
                .frame(width: 14)

            Text("📅")
                .font(.system(size: 12))

            Text("\(title) (\(totalCount))")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(openCount > 0 ? Color(hex: "#1E293B") : Color(hex: "#64748B"))

            if openCount > 0 {
                Text("\(openCount) đang mở")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(Color(hex: "#B45309"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#FEF3C7"))
                    .cornerRadius(6)
            } else {
                Text("✓ Đã xong")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color(hex: "#64748B"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#F1F5F9"))
                    .cornerRadius(6)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.95))
        .cornerRadius(8)
    }

    // MARK: - TOP BAR
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

                Text("Hỗ trợ trực tuyến")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // Nút Tạo yêu cầu hỗ trợ mới (Đồng nhất cho mọi người dùng)
                if authViewModel != nil {
                    Button(action: { showingCreateTicketSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

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

                // Nút 3: Báo cáo SLA / Đánh giá
                Button(action: onOpenRatingReport) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }

                // Nút 4: Làm mới
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

    // MARK: - TICKET LIST
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
                LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
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
                                        },
                                        onDelete: (viewModel.user.isAdmin || viewModel.user.isSuperAdmin || viewModel.user.isManager) ? {
                                            ticketToDelete = ticket
                                            showDeleteSingleConfirm = true
                                        } : nil
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
