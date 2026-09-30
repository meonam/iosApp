import SwiftUI

// MARK: - MÀN HÌNH HỖ TRỢ KỸ THUẬT DÀNH CHO NHÂN VIÊN (ĐỒNG BỘ 1:1 VỚI STAFFSUPPORTSCREEN.KT TRÊN ANDROID)
public struct StaffSupportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var supportVM: SupportViewModel
    var onBack: () -> Void
    var onTicketClick: ((String, String) -> Void)?

    @State private var filterStatus: String = "ALL" // "ALL", "OPEN", "CLOSED", "HIDDEN"
    @State private var selectedChannel: String = "ALL" // "ALL", "APP", "ZALO", "EMAIL"
    @State private var searchQuery: String = ""
    @State private var collapsedGroups: Set<String> = []
    @State private var showingCreateSheet: Bool = false
    @State private var showConfirmCleanClosed: Bool = false
    @State private var selectedTicketForChat: SupportTicket? = nil
    @State private var selectedTrackingTicket: SupportTicket? = nil
    @State private var deletedTicketIds: Set<String> = {
        let saved = UserDefaults.standard.stringArray(forKey: "support_staff_deleted_ids") ?? []
        return Set(saved)
    }()

    public init(
        authViewModel: AuthViewModel,
        onBack: @escaping () -> Void,
        onTicketClick: ((String, String) -> Void)? = nil
    ) {
        self.authViewModel = authViewModel
        self.onBack = onBack
        self.onTicketClick = onTicketClick

        let user = authViewModel.currentUser ?? User(
            maNhanVien: "",
            email: "",
            role: "STAFF",
            fullName: "",
            companyId: authViewModel.currentCompanyId
        )
        self._supportVM = StateObject(wrappedValue: SupportViewModel(
            user: user,
            companyId: authViewModel.currentCompanyId,
            idToken: authViewModel.currentIdToken
        ))
    }

    public init(
        viewModel: SupportViewModel,
        authViewModel: AuthViewModel,
        onBack: @escaping () -> Void,
        onTicketClick: ((String, String) -> Void)? = nil
    ) {
        self.authViewModel = authViewModel
        self._supportVM = StateObject(wrappedValue: viewModel)
        self.onBack = onBack
        self.onTicketClick = onTicketClick
    }

    private var myScopedTickets: [SupportTicket] {
        let myEmail = (authViewModel.currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myId = (authViewModel.currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return supportVM.tickets.filter { t in
            let cEmail = t.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cId = t.creatorUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return (!myEmail.isEmpty && cEmail == myEmail) || (!myId.isEmpty && cId == myId)
        }
    }

    private func isTicketHidden(_ t: SupportTicket) -> Bool {
        deletedTicketIds.contains(t.id) || t.isRejected
    }

    private var visibleTickets: [SupportTicket] {
        myScopedTickets.filter { ticket in
            let hidden = isTicketHidden(ticket)
            // Filter by hidden
            if filterStatus == "HIDDEN" {
                if !hidden { return false }
            } else {
                if hidden { return false }
                if filterStatus == "OPEN" && !ticket.isOpen { return false }
                if filterStatus == "CLOSED" && !ticket.isClosed { return false }
            }

            // Channel filter
            if selectedChannel != "ALL" {
                let src = ticket.source.uppercased()
                if selectedChannel == "ZALO" && src != "ZALO" { return false }
                if selectedChannel == "EMAIL" && src != "EMAIL" { return false }
                if selectedChannel == "APP" && (src == "ZALO" || src == "EMAIL") { return false }
            }

            // Search query
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let match = ticket.subject.lowercased().contains(q) ||
                            ticket.id.lowercased().contains(q) ||
                            ticket.assetName.lowercased().contains(q) ||
                            ticket.donVi.lowercased().contains(q)
                if !match { return false }
            }

            return true
        }
    }

    private var closedTicketsToClean: [SupportTicket] {
        myScopedTickets.filter { t in
            !deletedTicketIds.contains(t.id) &&
            (t.status.uppercased() == "CLOSED" || t.closedAt > 0)
        }
    }

    // Date grouping
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

        return order.map { ($0, dict[$0] ?? []) }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── 1. TOP BAR ──────────────────────────────────────
                    topBar(safeAreaTop: SafeAreaHelper.top(geometry))

                    // ── 2. CHANNEL FILTER CHIPS ────────────────────────
                    channelFilterChips

                    // ── 3. SEGMENTED TABS: Tất cả | Đang mở | Đã đóng | Đã ẩn ──
                    segmentedTabsBar

                    // ── 4. SEARCH BAR ──────────────────────────────────
                    searchBar

                    // ── 5. TICKETS LIST WITH DATE STICKY HEADERS ───────
                    if supportVM.isLoading && myScopedTickets.isEmpty {
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
            if supportVM.tickets.isEmpty {
                supportVM.fetchTickets()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateTicketSheetView(
                supportVM: supportVM,
                authViewModel: authViewModel,
                onSuccess: {
                    supportVM.fetchTickets()
                    showingCreateSheet = false
                },
                onCancel: {
                    showingCreateSheet = false
                }
            )
        }
        .sheet(item: $selectedTicketForChat) { ticket in
            TicketChatDetailView(
                viewModel: supportVM,
                ticket: ticket,
                onBack: { selectedTicketForChat = nil }
            )
        }
        .sheet(item: $selectedTrackingTicket) { ticket in
            LiveTrackingMapView(
                ticket: ticket,
                viewModel: supportVM,
                onDismiss: { selectedTrackingTicket = nil },
                onSelfResolved: {
                    selectedTrackingTicket = nil
                    supportVM.fetchTickets()
                },
                onTechResolve: {
                    selectedTrackingTicket = nil
                    supportVM.fetchTickets()
                }
            )
        }
        .alert(isPresented: $showConfirmCleanClosed) {
            Alert(
                title: Text("Dọn dẹp các yêu cầu đã đóng?"),
                message: Text("Hệ thống sẽ ẩn \(closedTicketsToClean.count) yêu cầu hỗ trợ ĐÃ ĐÓNG khỏi danh sách. Bạn có thể xem lại hoặc hiện lại bất cứ lúc nào trong tab 'Đã ẩn'."),
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

            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }

                Text("Hỗ trợ Kỹ thuật (\(visibleTickets.count))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Nút Giám sát lộ trình KTV đang di chuyển (Đồng bộ 1:1 Android StaffSupportScreen)
                let movingTicket = myScopedTickets.first(where: { $0.tracking?.status == "EN_ROUTE" })
                if let moving = movingTicket {
                    Button(action: { selectedTrackingTicket = moving }) {
                        Image(systemName: "bicycle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(hex: "#10B981"))
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }

                // Nút Dọn dẹp ticket đã đóng
                if !closedTicketsToClean.isEmpty {
                    Button(action: { showConfirmCleanClosed = true }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 19))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                }

                // Nút Gửi yêu cầu mới (Chỉ hiển thị cho Người dùng/Nhân viên, ẩn đối với Admin/HelpDesk)
                let isHelpDeskOrAdmin = supportVM.user.isAdmin || supportVM.user.isSuperAdmin || supportVM.user.isHelpDesk
                if !isHelpDeskOrAdmin {
                    Button(action: { showingCreateSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Tạo mới")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - CHANNEL FILTER CHIPS
    private var channelFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                channelChip(title: "Tất cả kênh", tag: "ALL")
                channelChip(title: "📱 Ứng dụng", tag: "APP")
                channelChip(title: "💬 Zalo", tag: "ZALO")
                channelChip(title: "✉️ Email", tag: "EMAIL")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func channelChip(title: String, tag: String) -> some View {
        let isSel = selectedChannel == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedChannel = tag
            }
        }) {
            Text(title)
                .font(.system(size: 11, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? Color.white : Color.appSecondaryDarkBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSel ? Color.appPrimaryPink : Color.appSurface)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSel ? Color.clear : Color.appCardBorder, lineWidth: 1))
        }
    }

    // MARK: - SEGMENTED TABS BAR
    private var segmentedTabsBar: some View {
        HStack(spacing: 4) {
            tabButton(title: "Tất cả", count: myScopedTickets.filter { !isTicketHidden($0) }.count, tag: "ALL")
            tabButton(
                title: "Đang mở",
                count: myScopedTickets.filter { !isTicketHidden($0) && $0.isOpen }.count,
                tag: "OPEN",
                activeColor: Color(hex: "#16A34A"),
                activeBg: Color(hex: "#DCFCE7")
            )
            tabButton(
                title: "Đã đóng",
                count: myScopedTickets.filter { !isTicketHidden($0) && $0.isClosed }.count,
                tag: "CLOSED"
            )
            tabButton(
                title: "Đã ẩn",
                count: myScopedTickets.filter { isTicketHidden($0) }.count,
                tag: "HIDDEN",
                activeColor: Color(hex: "#B91C1C"),
                activeBg: Color(hex: "#FEE2E2")
            )
        }
        .padding(4)
        .background(Color.appSurfaceVariant)
        .cornerRadius(12)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func tabButton(
        title: String,
        count: Int,
        tag: String,
        activeColor: Color = Color.appSecondaryDarkBlue,
        activeBg: Color = Color.appSurface
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
            .foregroundColor(isSel ? activeColor : Color.appTextSecondary)
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

            TextField("Tìm theo tiêu đề, thiết bị, đơn vị...", text: $searchQuery)
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
        .background(Color.appSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: - TICKET LIST VIEW
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
                                        if let onTicketClick = onTicketClick {
                                            onTicketClick(ticket.id, ticket.subject)
                                        } else {
                                            selectedTicketForChat = ticket
                                        }
                                    },
                                    onToggleHide: {
                                        toggleHideTicket(ticket.id)
                                    },
                                    onOpenTracking: (ticket.tracking?.status == "EN_ROUTE" || ticket.tracking?.status == "ARRIVED") ? {
                                        selectedTrackingTicket = ticket
                                    } : nil
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

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "ticket.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#CBD5E1"))

            Text("Chưa có yêu cầu hỗ trợ nào")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)

            Text("Nhấn 'Tạo mới' ở góc trên để gửi mô tả sự cố kỹ thuật đến đội ngũ chuyên trách.")
                .font(.system(size: 12))
                .foregroundColor(Color.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }

    private func cleanClosedTickets() {
        let idsToHide = closedTicketsToClean.map { $0.id }
        deletedTicketIds.formUnion(idsToHide)
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_staff_deleted_ids")
        showConfirmCleanClosed = false
    }

    private func toggleHideTicket(_ ticketId: String) {
        if deletedTicketIds.contains(ticketId) {
            deletedTicketIds.remove(ticketId)
        } else {
            deletedTicketIds.insert(ticketId)
        }
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_staff_deleted_ids")
    }
}

// MARK: - SHEET TẠO YÊU CẦU HỖ TRỢ MỚI ĐẦY ĐỦ 1:1 VỚI ANDROID
public struct CreateTicketSheetView: View {
    @ObservedObject var supportVM: SupportViewModel
    var authViewModel: AuthViewModel? = nil
    public var initialAssetId: String = ""
    public var initialAssetName: String = ""
    public var initialCategory: String = "HARDWARE"
    public var onSuccess: () -> Void
    public var onCancel: () -> Void

    public init(
        supportVM: SupportViewModel,
        authViewModel: AuthViewModel? = nil,
        initialAssetId: String = "",
        initialAssetName: String = "",
        initialCategory: String = "HARDWARE",
        onSuccess: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.supportVM = supportVM
        self.authViewModel = authViewModel
        self.initialAssetId = initialAssetId
        self.initialAssetName = initialAssetName
        self.initialCategory = initialCategory
        self.onSuccess = onSuccess
        self.onCancel = onCancel
    }

    @State private var currentStep: Int = 0 // 0: Phân loại & Thiết bị, 1: Chi tiết sự cố
    @State private var ticketScope: String = "UNIT" // "UNIT" or "DEPARTMENT"
    @State private var category: String = "HARDWARE"
    @State private var priority: String = "NORMAL"
    @State private var assetId: String = ""
    @State private var assetName: String = ""
    @State private var phone: String = ""
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var donVi: String = ""
    @State private var isSubmitting: Bool = false

    // Đính kèm hình ảnh & tệp tài liệu (đồng bộ 100% Android)
    @State private var pendingImages: [UIImage] = []
    @State private var pendingDocs: [ChatPendingAttachment] = []
    @State private var showImagePicker: Bool = false
    @State private var showDocPicker: Bool = false

    let categories = [
        ("HARDWARE", "🖥️ Phần cứng / Thiết bị"),
        ("SOFTWARE", "💾 Phần mềm / Ứng dụng"),
        ("NETWORK", "🌐 Mạng / Internet"),
        ("PRINTER", "🖨️ Máy in / POS"),
        ("ACCOUNT", "👤 Tài khoản / Đăng nhập"),
        ("OTHER", "➕ Vấn đề khác")
    ]

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segment Step Header
                HStack(spacing: 8) {
                    stepHeaderPill(title: "1. Thiết bị & Phân loại", step: 0)
                    stepHeaderPill(title: "2. Chi tiết sự cố", step: 1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(hex: "#F1F5F9"))

                if currentStep == 0 {
                    step0View
                } else {
                    step1View
                }
            }
            .navigationTitle("Gửi yêu cầu hỗ trợ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy", action: onCancel),
                trailing: Group {
                    if currentStep == 0 {
                        Button("Tiếp tục") {
                            withAnimation { currentStep = 1 }
                        }
                        .font(.system(size: 14, weight: .bold))
                    } else {
                        Button("Gửi yêu cầu") {
                            submitTicket()
                        }
                        .font(.system(size: 14, weight: .bold))
                        .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  isSubmitting)
                    }
                }
            )
            .sheet(isPresented: $showImagePicker) {
                ChatImagePicker(maxSelection: max(1, 5 - pendingImages.count)) { images in
                    for img in images {
                        if pendingImages.count < 5 {
                            pendingImages.append(img)
                        }
                    }
                }
            }
            .sheet(isPresented: $showDocPicker) {
                ChatDocumentPicker { urls in
                    Task {
                        for url in urls {
                            if url.startAccessingSecurityScopedResource() {
                                defer { url.stopAccessingSecurityScopedResource() }
                                if let data = try? Data(contentsOf: url) {
                                    let fileName = url.lastPathComponent
                                    let attachment = ChatPendingAttachment(
                                        data: data,
                                        fileName: fileName,
                                        fileSize: Int64(data.count),
                                        type: "file"
                                    )
                                    if pendingDocs.count < 5 && !pendingDocs.contains(where: { $0.fileName == attachment.fileName }) {
                                        pendingDocs.append(attachment)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Đang gửi yêu cầu...").tint(.white).foregroundColor(.white)
                }
            }
        }
        .onAppear {
            let u = authViewModel?.currentUser ?? supportVM.user
            phone = u.phone
            donVi = u.donVi
            if !initialAssetId.isEmpty {
                assetId = initialAssetId
            }
            if !initialAssetName.isEmpty {
                assetName = initialAssetName
            }
            if !initialCategory.isEmpty {
                category = initialCategory
            }
        }
    }

    private func stepHeaderPill(title: String, step: Int) -> some View {
        let isSel = currentStep == step
        return Button(action: {
            withAnimation { currentStep = step }
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? Color.white : Color.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 32)
                .background(isSel ? Color.appPrimaryPink : Color.white)
                .cornerRadius(8)
        }
    }

    // MARK: - STEP 0 VIEW
    private var step0View: some View {
        Form {
            Section(header: Text("Phạm vi hỗ trợ")) {
                Picker("Phạm vi", selection: $ticketScope) {
                    Text("Đơn vị (Chi nhánh)").tag("UNIT")
                    Text("Phòng ban nội bộ").tag("DEPARTMENT")
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section(header: Text("Phân loại sự cố")) {
                Picker("Danh mục", selection: $category) {
                    ForEach(categories, id: \.0) { cat in
                        Text(cat.1).tag(cat.0)
                    }
                }

                Picker("Mức độ khẩn cấp", selection: $priority) {
                    Text("🟢 Bình thường (24h)").tag("NORMAL")
                    Text("🟡 Cần gấp (4h)").tag("HIGH")
                    Text("🔴 Khẩn cấp (<1h)").tag("URGENT")
                }
            }

            Section(header: Text("Thông tin thiết bị (nếu có)")) {
                TextField("Mã thiết bị (Asset ID)", text: $assetId)
                    .font(.system(size: 13.5))

                TextField("Tên thiết bị (Model / Tên gọi)", text: $assetName)
                    .font(.system(size: 13.5))
            }

            Section(header: Text("Thông tin liên hệ")) {
                TextField("Số điện thoại liên hệ", text: $phone)
                    .keyboardType(.phonePad)
                    .font(.system(size: 13.5))

                TextField("Đơn vị / Chi nhánh", text: $donVi)
                    .font(.system(size: 13.5))
            }
        }
    }

    // MARK: - STEP 1 VIEW
    private var step1View: some View {
        Form {
            Section(header: Text("Tiêu đề sự cố *")) {
                TextField("Ví dụ: Máy in bill không nhận lệnh, mất mạng POS...", text: $subject)
                    .font(.system(size: 14))
            }

            Section(header: Text("Mô tả chi tiết *")) {
                TextEditor(text: $message)
                    .frame(minHeight: 100)
                    .font(.system(size: 13.5))
            }

            // ẢNH CHỤP HIỆN TRƯỜNG (ĐỒNG BỘ ANDROID)
            Section(header: Text("Ảnh chụp hiện trường / màn hình lỗi (tối đa 5 ảnh)")) {
                if !pendingImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, img in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button(action: {
                                        pendingImages.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .background(Color.white.clipShape(Circle()))
                                    }
                                    .padding(2)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if pendingImages.count < 5 {
                    Button(action: { showImagePicker = true }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Thêm ảnh chụp sự cố (\(pendingImages.count)/5)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color.appPrimaryPink)
                    }
                }
            }

            // TỆP TÀI LIỆU ĐÍNH KÈM (ĐỒNG BỘ ANDROID)
            Section(header: Text("Tệp tài liệu đính kèm (Log, Word, Excel, PDF...)")) {
                if !pendingDocs.isEmpty {
                    ForEach(Array(pendingDocs.enumerated()), id: \.offset) { index, doc in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.fileName)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .lineLimit(1)
                                Text("\(max(1, doc.fileSize / 1024)) KB")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: {
                                pendingDocs.remove(at: index)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                if pendingDocs.count < 5 {
                    Button(action: { showDocPicker = true }) {
                        HStack {
                            Image(systemName: "paperclip")
                            Text("Đính kèm tệp tài liệu (\(pendingDocs.count)/5)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                }
            }

            Section(footer: Text("Yêu cầu sẽ được tự động điều phối tới bộ phận kỹ thuật / chuyên viên phụ trách.")) {
                EmptyView()
            }
        }
    }

    private func submitTicket() {
        guard !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isSubmitting = true
        Task {
            // 1. Tải ảnh lên Cloudinary
            var uploadedImageUrls: [String] = []
            for img in pendingImages {
                if let data = img.jpegData(compressionQuality: 0.8),
                   let url = await CloudinaryService.uploadImageData(data, folder: "support_tickets") {
                    uploadedImageUrls.append(url)
                }
            }

            // 2. Tải tệp tài liệu lên Cloudinary
            var uploadedAttachments: [AttachmentItem] = []
            for doc in pendingDocs {
                if let url = await CloudinaryService.uploadRawData(doc.data, folder: "support_tickets", fileName: doc.fileName) {
                    let ext = (doc.fileName as NSString).pathExtension.lowercased()
                    let typeStr = ["pdf", "doc", "docx", "xls", "xlsx", "txt", "zip", "rar"].contains(ext) ? ext : "file"
                    let item = AttachmentItem(
                        id: UUID().uuidString,
                        name: doc.fileName,
                        url: url,
                        size: doc.fileSize,
                        type: typeStr,
                        uploadedAt: Int64(Date().timeIntervalSince1970 * 1000)
                    )
                    uploadedAttachments.append(item)
                }
            }

            // 3. Tạo ticket trên Firestore
            supportVM.createTicket(
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                priority: priority,
                assetId: assetId.trimmingCharacters(in: .whitespacesAndNewlines),
                assetName: assetName.trimmingCharacters(in: .whitespacesAndNewlines),
                phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
                images: uploadedImageUrls,
                donVi: donVi.trimmingCharacters(in: .whitespacesAndNewlines),
                gpsLat: 0.0,
                gpsLng: 0.0,
                scope: ticketScope,
                attachments: uploadedAttachments
            ) { success in
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    if success {
                        self.onSuccess()
                    }
                }
            }
        }
    }
}
