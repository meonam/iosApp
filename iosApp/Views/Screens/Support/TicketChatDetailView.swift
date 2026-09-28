import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - MÀN HÌNH CHI TIẾT TICKET & CHAT TRỰC TIẾP (ĐỒNG BỘ 1:1 VỚI ADMINSUPPORTCHATSCREEN.KT)
public struct TicketChatDetailView: View {
    @ObservedObject var viewModel: SupportViewModel
    var ticket: SupportTicket
    var onBack: () -> Void

    @State private var inputText: String = ""
    @State private var showCloseTicketAlert: Bool = false
    @State private var showSelfResolvedAlert: Bool = false
    @State private var showTechResolveSheet: Bool = false
    @State private var techResolutionNote: String = ""
    @State private var showReopenSheet: Bool = false
    @State private var reopenReason: String = ""
    @State private var showRatingSheet: Bool = false
    @State private var selectedRating: Int = 5
    @State private var ratingComment: String = ""
    @State private var showLiveTrackingModal: Bool = false
    @State private var showAssignKtvSheet: Bool = false
    @State private var showCallView: Bool = false
    @State private var showRejectReasonSheet: Bool = false
    @State private var rejectReasonText: String = ""

    // SLA countdown timer
    @State private var slaCountdown: String = ""
    @State private var slaTimer: Timer? = nil
    @State private var slaIsOverdue: Bool = false

    // MARK: - File Attachment State (đồng bộ Android AndroidPendingAttachment)
    /// Tối đa 5 tệp, mỗi tệp tối đa 10MB
    @State private var pendingAttachments: [ChatPendingAttachment] = []
    @State private var showImagePicker: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var isUploadingAttachments: Bool = false
    @State private var attachmentAlertMessage: String? = nil

    public init(viewModel: SupportViewModel, ticket: SupportTicket, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.ticket = ticket
        self.onBack = onBack
    }

    private var myEmail: String {
        viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isCreator: Bool {
        ticket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail
    }

    private var isAssignedTech: Bool {
        ticket.assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail ||
        ticket.assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail
    }

    private var isAdminOrHelpDesk: Bool {
        viewModel.user.isAdmin || viewModel.user.isHelpDesk
    }

    private var isClosed: Bool {
        ticket.status.uppercased() == "CLOSED" || ticket.closedAt > 0
    }

    private var isReopenedActive: Bool {
        !isClosed && (ticket.reopenCount > 0 || ticket.reopenedAt > 0) &&
        ticket.status.uppercased() != "RESOLVED" &&
        !(ticket.reopenedAt > 0 && ticket.resolvedAt > ticket.reopenedAt)
    }

    private var isResolved: Bool {
        !isClosed && !isReopenedActive && (
            ticket.status.uppercased() == "RESOLVED" ||
            (ticket.reopenCount == 0 && ticket.reopenedAt <= 0 && ticket.resolvedAt > 0) ||
            (ticket.reopenedAt > 0 && ticket.resolvedAt > ticket.reopenedAt)
        )
    }

    private var isOpen: Bool {
        !isClosed
    }

    private var canReopen: Bool {
        isClosed && ticket.reopenCount < 2 && (ticket.isWithinQualityTrackingWindow || isAdminOrHelpDesk) && (isCreator || isAdminOrHelpDesk || isAssignedTech)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── 1. TOP BAR ──────────────────────────────────────
                    topBar(safeAreaTop: SafeAreaHelper.top(geometry))

                    // ── 2. SLA COUNTDOWN BAR (nếu đang OPEN và có áp dụng SLA) ───────────
                    if isOpen && ticket.slaTargetMinutes > 0 {
                        slaCountdownBar
                    }

                    // ── 3. DYNAMIC CONTEXTUAL ACTION BANNERS ────────────
                    contextualActionBanners

                    // ── 4. CHAT MESSAGES LIST ───────────────────────────
                    messagesListView

                    // ── 5. INPUT BAR (hoặc banner Đã đóng / Đã từ chối) ──────────────
                    if ticket.isRejected {
                        ticketRejectedBar
                    } else if isOpen {
                        chatInputBar
                    } else {
                        closedTicketFooter
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchMessages(for: ticket.id)
            startSlaTimer()
        }
        .onDisappear {
            slaTimer?.invalidate()
            slaTimer = nil
        }
        // Sheet Báo cáo Hoàn tất của KTV
        .sheet(isPresented: $showTechResolveSheet) {
            techResolveSheetView
        }
        // Sheet Đánh giá Nghiệm thu của Người tạo
        .sheet(isPresented: $showRatingSheet) {
            ratingSheetView
        }
        // Sheet Mở lại Phiếu
        .sheet(isPresented: $showReopenSheet) {
            reopenSheetView
        }
        // Sheet Điều phối KTV (DispatchTicketSheet đồng bộ 1:1 Android)
        .sheet(isPresented: $showAssignKtvSheet) {
            DispatchTicketSheet(ticket: ticket, viewModel: viewModel, onDismiss: {
                showAssignKtvSheet = false
            })
        }
        // Sheet Bản đồ lộ trình KTV (LiveTrackingMapView đồng bộ 1:1 Android)
        .sheet(isPresented: $showLiveTrackingModal) {
            LiveTrackingMapView(
                ticket: ticket,
                viewModel: viewModel,
                onDismiss: { showLiveTrackingModal = false },
                onSelfResolved: { showSelfResolvedAlert = true },
                onTechResolve: { showTechResolveSheet = true }
            )
        }
        // Sheet Từ chối phiếu (Admin/HelpDesk)
        .sheet(isPresented: $showRejectReasonSheet) {
            rejectTicketSheetView
        }
        // Alert Tự xử lý xong
        .alert(isPresented: $showSelfResolvedAlert) {
            Alert(
                title: Text("Bạn đã tự xử lý xong sự cố?"),
                message: Text("Xác nhận sự cố đã được bạn tự khắc phục thành công và kết thúc phiếu hỗ trợ này?"),
                primaryButton: .default(Text("Xác nhận đóng")) {
                    viewModel.closeTicket(ticketId: ticket.id, rating: 5, feedback: "Người dùng tự xử lý thành công") { _ in }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        // Alert Đóng phiếu (Admin/Manager)
        .alert(isPresented: $showCloseTicketAlert) {
            Alert(
                title: Text("Kết thúc và đóng yêu cầu"),
                message: Text("Xác nhận hoàn tất và đóng phiếu hỗ trợ này?"),
                primaryButton: .destructive(Text("Đóng phiếu")) {
                    viewModel.closeTicket(ticketId: ticket.id, rating: 5, feedback: "Admin/HelpDesk đóng phiếu") { _ in }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        // Sheet Image Picker cho ảnh từ thư viện (PHPickerViewController iOS 14+)
        .sheet(isPresented: $showImagePicker) {
            ChatImagePicker(maxSelection: max(1, 5 - pendingAttachments.count)) { images in
                for img in images {
                    if let data = img.jpegData(compressionQuality: 0.8) {
                        let fileName = "img_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(4)).jpg"
                        let attachment = ChatPendingAttachment(
                            data: data,
                            fileName: fileName,
                            fileSize: Int64(data.count),
                            type: "image"
                        )
                        if pendingAttachments.count < 5 && !pendingAttachments.contains(where: { $0.fileName == attachment.fileName }) {
                            pendingAttachments.append(attachment)
                        }
                    }
                }
            }
        }
        // Sheet Document Picker cho tệp tài liệu
        .sheet(isPresented: $showDocumentPicker) {
            ChatDocumentPicker { urls in
                Task {
                    for url in urls {
                        await addAttachmentFromUrl(url)
                    }
                }
            }
        }
        // Alert lỗi attachment chuẩn iOS 15
        .alert(isPresented: Binding(
            get: { attachmentAlertMessage != nil },
            set: { if !$0 { attachmentAlertMessage = nil } }
        )) {
            Alert(
                title: Text("Lỗi tệp đính kèm"),
                message: Text(attachmentAlertMessage ?? ""),
                dismissButton: .default(Text("Đóng"))
            )
        }
    }

    // MARK: - TOP BAR
    private func topBar(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 10) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.subject.isEmpty ? "Chi tiết hỗ trợ" : ticket.subject)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    let creatorDisp = ticket.creatorName.isEmpty ? ticket.creatorEmail : ticket.creatorName
                    Text("#\(ticket.id.prefix(8).uppercased()) • \(creatorDisp)")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                // Nút Bản đồ lộ trình KTV (Live Tracking Map)
                Button(action: { showLiveTrackingModal = true }) {
                    Image(systemName: "figure.outdoor.cycle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color(hex: "#002A8F"))
                        .clipShape(Circle())
                }

                // Nút Gọi WebRTC
                if !isCreator && !ticket.creatorEmail.isEmpty {
                    Button(action: {
                        WebRtcCallManager.shared.startCall(
                            targetEmail: ticket.creatorEmail,
                            targetName: ticket.creatorName,
                            callerName: viewModel.user.fullName,
                            callerEmail: viewModel.user.email
                        )
                        showCallView = true
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color(hex: "#10B981"))
                            .clipShape(Circle())
                    }
                }

                // Nút Điều phối KTV (Admin/HelpDesk)
                if isOpen && isAdminOrHelpDesk {
                    Button(action: {
                        viewModel.fetchKtvTechnicians()
                        showAssignKtvSheet = true
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: ticket.assignedToEmail.isEmpty ? "person.badge.plus" : "person.fill.checkmark")
                                .font(.system(size: 10))
                            Text(ticket.assignedToEmail.isEmpty ? "Điều phối" : "Đổi KTV")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                    }
                }

                // Nút Mở lại phiếu (nếu đủ điều kiện)
                if canReopen {
                    Button(action: { showReopenSheet = true }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#FBBF24"))
                    }
                }

                // Nút Từ chối phiếu (Admin/HelpDesk)
                if isOpen && isAdminOrHelpDesk {
                    Button(action: {
                        rejectReasonText = ""
                        showRejectReasonSheet = true
                    }) {
                        Text("Từ chối")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#DC2626"))
                            .cornerRadius(6)
                    }
                }

                // Nút Hoàn tất đóng phiếu (Admin/Manager)
                if isOpen && isAdminOrHelpDesk {
                    Button(action: { showCloseTicketAlert = true }) {
                        Text("Kết thúc")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appSuccess)
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - SLA COUNTDOWN BAR
    private var slaCountdownBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11))
                .foregroundColor(slaIsOverdue ? Color(hex: "#EF4444") : Color(hex: "#16A34A"))

            Text(slaIsOverdue ? "⚠ QUÁ HẠN SLA: \(slaCountdown)" : "SLA còn lại: \(slaCountdown)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(slaIsOverdue ? Color(hex: "#EF4444") : Color(hex: "#16A34A"))

            Spacer()

            // Badge Mức độ ưu tiên
            Text(ticket.priority.uppercased())
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(Color.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(priorityColor(ticket.priority))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(slaIsOverdue ? Color(hex: "#FEE2E2") : Color(hex: "#DCFCE7"))
    }

    // MARK: - CONTEXTUAL ACTION BANNERS
    private var contextualActionBanners: some View {
        VStack(spacing: 6) {
            // ── Banner 0: Phiếu đã bị từ chối ──
            if ticket.isRejected {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundColor(Color(hex: "#DC2626"))
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Yêu cầu đã bị từ chối / Không phù hợp")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#991B1B"))
                        let rz = ticket.invalidReason.isEmpty ? "Không thuộc phạm vi CNTT hoặc yêu cầu không hợp lệ" : ticket.invalidReason
                        Text("Lý do: \(rz)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#B91C1C"))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(hex: "#FEE2E2"))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }

            // ── Banner 1: Live Tracking KTV (cho Người tạo ticket khi KTV đang di chuyển / đã đến) ──
            if isCreator && isOpen && !isResolved, let tr = ticket.tracking, tr.status == "EN_ROUTE" || tr.status == "ARRIVED" {
                Button(action: { showLiveTrackingModal = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: tr.status == "ARRIVED" ? "checkmark.circle.fill" : "bicycle")
                            .font(.system(size: 16))
                            .foregroundColor(tr.status == "ARRIVED" ? Color(hex: "#2563EB") : Color(hex: "#059669"))

                        VStack(alignment: .leading, spacing: 2) {
                            let techName = ticket.assignedToName.isEmpty ? ticket.assignedToEmail : ticket.assignedToName
                            Text(tr.status == "ARRIVED" ? "KTV \(techName) đã đến hiện trường" : "KTV \(techName) đang di chuyển tới")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(tr.status == "ARRIVED" ? Color(hex: "#1E40AF") : Color(hex: "#065F46"))

                            let dist = tr.distanceKm
                            let eta = tr.etaMinutes
                            let sub = dist > 0.05 && eta > 0 ? "Còn khoảng \(String(format: "%.1f", dist)) km (dự kiến ~\(eta) phút) • Bấm xem lộ trình" : "Bấm để xem vị trí trực tiếp trên bản đồ"
                            Text(sub)
                                .font(.system(size: 10.5))
                                .foregroundColor(tr.status == "ARRIVED" ? Color(hex: "#2563EB") : Color(hex: "#047857"))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(tr.status == "ARRIVED" ? Color(hex: "#EFF6FF") : Color(hex: "#ECFDF5"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(tr.status == "ARRIVED" ? Color(hex: "#3B82F6") : Color(hex: "#10B981"), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
            }

            // ── Banner 2: Người tạo tự xử lý xong (cho Người tạo khi OPEN) ──
            if isCreator && isOpen && !isResolved {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bạn đã tự xử lý xong sự cố?")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("Bấm xác nhận để kết thúc yêu cầu và giải phóng KTV.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.gray)
                    }
                    Spacer()
                    Button("Tôi đã tự xử lý") {
                        showSelfResolvedAlert = true
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#E2E8F0")), alignment: .bottom)
            }

            // ── Banner 3: Chọn phương thức xử lý (cho KTV được phân công) ──
            if (isAssignedTech || isAdminOrHelpDesk) && isOpen && !isResolved {
                HStack(spacing: 8) {
                    Text("Phương thức:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Button(action: {
                        viewModel.selectHandlingMethod(ticketId: ticket.id, method: "REMOTE") { _ in }
                    }) {
                        Text("💻 Từ xa")
                            .font(.system(size: 10.5, weight: ticket.handlingMethod == "REMOTE" ? .bold : .medium))
                            .foregroundColor(ticket.handlingMethod == "REMOTE" ? Color.white : Color(hex: "#1D4ED8"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ticket.handlingMethod == "REMOTE" ? Color(hex: "#1D4ED8") : Color(hex: "#EFF6FF"))
                            .cornerRadius(6)
                    }

                    Button(action: {
                        viewModel.selectHandlingMethod(ticketId: ticket.id, method: "ONSITE") { _ in }
                    }) {
                        Text("🛵 Đến nơi")
                            .font(.system(size: 10.5, weight: ticket.handlingMethod == "ONSITE" ? .bold : .medium))
                            .foregroundColor(ticket.handlingMethod == "ONSITE" ? Color.white : Color(hex: "#B45309"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ticket.handlingMethod == "ONSITE" ? Color(hex: "#B45309") : Color(hex: "#FEF3C7"))
                            .cornerRadius(6)
                    }

                    Spacer()

                    // Nút KTV Báo cáo đã xử lý xong
                    Button("🛠️ Báo cáo xong") {
                        showTechResolveSheet = true
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#10B981"))
                    .cornerRadius(6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#E2E8F0")), alignment: .bottom)
            }

            // ── Banner 4: Nghiệm thu & Đánh giá 5 sao (cho Người tạo khi RESOLVED) ──
            if isResolved {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#10B981"))
                        Text("Kỹ thuật viên đã báo cáo hoàn thành sự cố")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#065F46"))
                        Spacer()
                    }

                    if isCreator {
                        HStack {
                            Text("Vui lòng đánh giá để nghiệm thu đóng phiếu:")
                                .font(.system(size: 11))
                                .foregroundColor(Color.gray)
                            Spacer()
                            Button("⭐ Đánh giá & Đóng") {
                                showRatingSheet = true
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#D97706"))
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(10)
                .background(Color(hex: "#ECFDF5"))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }

            // ── Banner 5: Mở lại phiếu nếu còn trong hạn bảo hành chất lượng ──
            if canReopen {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sự cố chưa được giải quyết triệt để?")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("Còn \(ticket.remainingQualityTrackingHours) giờ bảo hành xử lý sự cố.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color.gray)
                    }
                    Spacer()
                    Button("🔄 Mở lại phiếu") {
                        showReopenSheet = true
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "#D97706"))
                    .cornerRadius(6)
                }
                .padding(10)
                .background(Color(hex: "#FFFBEB"))
                .cornerRadius(8)
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - MESSAGES LIST VIEW
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    // Mô tả ban đầu
                    if !ticket.initialMessage.isEmpty {
                        initialMessageCard
                    }

                    // Danh sách tin nhắn trao đổi
                    ForEach(viewModel.messages) { msg in
                        messageBubbleView(msg)
                            .id(msg.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastId = viewModel.messages.last?.id {
                    withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
                }
            }
        }
    }

    private var initialMessageCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("📌 Mô tả sự cố ban đầu:")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text(ticket.initialMessage)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#1E293B"))

                if !ticket.assetName.isEmpty {
                    Text("Thiết bị: \(ticket.assetName) (\(ticket.assetId))")
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "#F1F5F9"))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
            Spacer()
        }
    }

    // MARK: - MESSAGE BUBBLE & SYSTEM EVENT PILL (ĐỒNG NHẤT 1:1 ANDROID, WEB & DESKTOP)
    @ViewBuilder
    private func messageBubbleView(_ msg: SupportMessage) -> some View {
        let isSystem = msg.isSystemMessage ||
            msg.senderEmail.lowercased() == "system" ||
            msg.senderEmail.lowercased().starts(with: "system") ||
            msg.senderEmail.lowercased().contains("system@") ||
            msg.senderName.contains("Hệ thống") ||
            msg.senderName.contains("Hệ Thống") ||
            msg.senderName.contains("🤖") ||
            isSystemSupportMessage(msg.text)

        if isSystem {
            systemEventPillView(
                text: msg.text,
                time: msg.timestamp > 0 ? formatMessageTime(msg.timestamp) : ""
            )
        } else {
            let isMine = msg.senderEmail.lowercased() == myEmail

            HStack {
                if isMine { Spacer() }

                VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                    if !isMine {
                        let senderName = msg.senderName.isEmpty ? msg.senderEmail : msg.senderName
                        Text(senderName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.gray)
                    }

                    Text(msg.text)
                        .font(.system(size: 13.5))
                        .foregroundColor(isMine ? Color.white : Color(hex: "#0F172A"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMine ? Color.appPrimaryPink : Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isMine ? Color.clear : Color(hex: "#E2E8F0"), lineWidth: 1)
                        )

                    if msg.timestamp > 0 {
                        Text(formatMessageTime(msg.timestamp))
                            .font(.system(size: 9.5))
                            .foregroundColor(Color.gray)
                    }

                    // Hiển thị ảnh/file đính kèm (nếu có)
                    if !msg.attachments.isEmpty {
                        ForEach(msg.attachments) { att in
                            if att.type == "image", let imgUrl = URL(string: att.url) {
                                AsyncImage(url: imgUrl) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 200)
                                            .cornerRadius(10)
                                    case .failure:
                                        Label("Không tải được ảnh", systemImage: "photo.badge.exclamationmark")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    default:
                                        ProgressView()
                                            .frame(width: 120, height: 80)
                                    }
                                }
                            } else if let fileUrl = URL(string: att.url) {
                                Link(destination: fileUrl) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.fill")
                                            .foregroundColor(Color.appPrimaryPink)
                                        Text(att.name.isEmpty ? "Tệp đính kèm" : att.name)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#F1F5F9"))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                                }
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            }
                        }
                    }
                }

                if !isMine { Spacer() }
            }
        }
    }

    private func isSystemSupportMessage(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.hasPrefix("🔄") ||
               t.hasPrefix("🛠️") ||
               t.hasPrefix("✅") ||
               t.hasPrefix("💻") ||
               t.hasPrefix("⭐") ||
               t.hasPrefix("👥") ||
               t.hasPrefix("❌") ||
               t.hasPrefix("🛑") ||
               t.hasPrefix("⚠️") ||
               t.hasPrefix("🚫") ||
               t.hasPrefix("💡") ||
               t.hasPrefix("🛵") ||
               t.hasPrefix("📍") ||
               t.hasPrefix("🤖") ||
               t.hasPrefix("✉️") ||
               t.hasPrefix("📢") ||
               t.hasPrefix("🔔") ||
               t.hasPrefix("🚨") ||
               t.hasPrefix("ℹ️") ||
               t.hasPrefix("⚡") ||
               t.hasPrefix("📌") ||
               t.hasPrefix("[Hệ thống]") ||
               t.contains("[Hệ thống") ||
               t.contains("[Điều phối") ||
               t.contains("Điều phối:") ||
               t.contains("tiếp nhận điều phối") ||
               t.contains("Xử lý từ xa") ||
               t.contains("[Đổi phương án]") ||
               t.contains("đến hiện trường") ||
               t.contains("báo cáo đã xử lý xong") ||
               t.contains("đã xử lý xong") ||
               t.contains("báo xong") ||
               t.contains("tự xử lý xong") ||
               t.contains("đánh giá chất lượng") ||
               t.contains("mở lại sự cố")
    }

    private func systemEventColors(for text: String) -> (textColor: Color, bgColor: Color, borderColor: Color) {
        let t = text.lowercased()
        if t.contains("🔄") || t.contains("điều phối") {
            // Đồng nhất 1:1 Web & Desktop (Image 1): Vàng nhạt / Amber
            return (Color(hex: "#B45309"), Color(hex: "#FEFCE8"), Color(hex: "#FEF08A"))
        } else if t.contains("💻") || t.contains("xử lý từ xa") || t.contains("đổi phương án") {
            // Đồng nhất 1:1 Web & Desktop (Image 1): Xanh dương nhạt
            return (Color(hex: "#1D4ED8"), Color(hex: "#EFF6FF"), Color(hex: "#BFDBFE"))
        } else if t.contains("tiếp nhận điều phối") || t.contains("đã tiếp nhận") {
            // Đồng nhất 1:1 Web & Desktop (Image 1): Xanh lá tiếp nhận
            return (Color(hex: "#15803D"), Color(hex: "#F0FDF4"), Color(hex: "#BBF7D0"))
        } else if t.contains("🛠️") || t.contains("xử lý xong") || t.contains("hoàn thành") {
            // Xanh lá hoàn thành
            return (Color(hex: "#16A34A"), Color(hex: "#F0FDF4"), Color(hex: "#DCFCE7"))
        } else if t.contains("👥") || t.contains("điều động thêm") {
            // Tím điều động thêm
            return (Color(hex: "#7C3AED"), Color(hex: "#FAF5FF"), Color(hex: "#DDD6FE"))
        } else if t.contains("❌") || t.contains("rút điều động") || t.contains("🛑") || t.contains("⚠️") || t.contains("🚫") || t.contains("từ chối") {
            // Đỏ cảnh báo / từ chối
            return (Color(hex: "#DC2626"), Color(hex: "#FEF2F2"), Color(hex: "#FEE2E2"))
        } else if t.contains("⭐") || t.contains("💡") || t.contains("đánh giá") {
            // Vàng hổ phách đánh giá
            return (Color(hex: "#D97706"), Color(hex: "#FFFBEB"), Color(hex: "#FEF3C7"))
        } else if t.contains("🛵") || t.contains("📍") || t.contains("hiện trường") || t.contains("di chuyển") {
            // Xanh da trời di chuyển
            return (Color(hex: "#0284C7"), Color(hex: "#F0F9FF"), Color(hex: "#E0F2FE"))
        } else {
            // Xám mặc định
            return (Color(hex: "#64748B"), Color(hex: "#F8FAFC"), Color(hex: "#E2E8F0"))
        }
    }

    private func systemEventPillView(text: String, time: String) -> some View {
        let colors = systemEventColors(for: text)

        return HStack {
            Spacer(minLength: 8)
            HStack(alignment: .center, spacing: 6) {
                Text(text)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(colors.textColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if !time.isEmpty {
                    Text(time)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "#94A3B8"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(colors.bgColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors.borderColor, lineWidth: 1)
            )
            Spacer(minLength: 8)
        }
        .padding(.vertical, 3)
    }

    // MARK: - CHAT INPUT BAR (ĐỦ TÍNH NĂNG ĐÍNH KÈM FILE NHƯ ANDROID)
    private var chatInputBar: some View {
        VStack(spacing: 0) {
            // Hàng xem trước tệp đính kèm đang chờ gửi
            if !pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pendingAttachments) { att in
                            ZStack(alignment: .topTrailing) {
                                // Preview thumbnail / icon tệp
                                if att.type == "image", let uiImg = UIImage(data: att.data) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(hex: "#F1F5F9"))
                                        .frame(width: 64, height: 64)
                                        .overlay(
                                            VStack(spacing: 4) {
                                                Image(systemName: "doc.fill")
                                                    .foregroundColor(Color.appPrimaryPink)
                                                Text(att.fileName.components(separatedBy: ".").last?.uppercased() ?? "FILE")
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(Color(hex: "#64748B"))
                                            }
                                        )
                                }
                                // Nút xóa attachment
                                Button(action: {
                                    pendingAttachments.removeAll { $0.id == att.id }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#64748B"))
                                        .background(Color.white.clipShape(Circle()))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .background(Color(hex: "#F8FAFC"))

                // Thông tin dung lượng
                HStack {
                    Image(systemName: "paperclip")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appPrimaryPink)
                    Text("Tệp chờ gửi (\(pendingAttachments.count)/5 – Tối đa 10MB/tệp)")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: "#64748B"))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Thanh nhập liệu chính
            HStack(spacing: 8) {
                // Nút đính kèm — mở menu ảnh hoặc tài liệu
                Menu {
                    Button(action: { showImagePicker = true }) {
                        Label("Chọn ảnh từ thư viện", systemImage: "photo.on.rectangle")
                    }
                    Button(action: { showDocumentPicker = true }) {
                        Label("Chọn tài liệu", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                        .foregroundColor(pendingAttachments.count >= 5 ? Color.gray : Color.appPrimaryPink)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#F1F5F9"))
                        .clipShape(Circle())
                }
                .disabled(pendingAttachments.count >= 5)

                TextField("Nhập nội dung trao đổi...", text: $inputText)
                    .font(.system(size: 13.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // Nút gửi — xử lý upload attachment rồi gửi text
                Button(action: {
                    Task { await sendMessageWithAttachments() }
                }) {
                    ZStack {
                        if isUploadingAttachments || viewModel.isSendingMessage {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 36, height: 36)
                                .background(Color.appPrimaryPink.opacity(0.7))
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.appPrimaryPink)
                                .clipShape(Circle())
                        }
                    }
                }
                .disabled(
                    (inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pendingAttachments.isEmpty) ||
                    viewModel.isSendingMessage || isUploadingAttachments
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#E2E8F0")), alignment: .top)
    }

    // MARK: - GỬI TIN NHẮN KÈM FILE (ĐỒNG BỘ Android AdminSupportChatScreen.kt sendMessageWithAttachments)
    private func sendMessageWithAttachments() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }

        isUploadingAttachments = !pendingAttachments.isEmpty
        var uploadedUrls: [String] = []

        // Upload từng attachment lên Cloudinary
        for att in pendingAttachments {
            if let url = await CloudinaryService.uploadImageData(att.data, folder: "chat_attachments") {
                uploadedUrls.append(url)
            }
        }

        isUploadingAttachments = false
        inputText = ""
        pendingAttachments = []

        // Gửi tin nhắn kèm danh sách URL ảnh đính kèm
        viewModel.sendMessage(
            ticketId: ticket.id,
            text: text,
            attachmentUrls: uploadedUrls
        )
    }

    // MARK: - THÊM FILE TỪ DOCUMENT PICKER
    private func addAttachmentFromUrl(_ url: URL) async {
        let maxBytes: Int64 = 10 * 1024 * 1024 // 10MB
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else { return }
        guard data.count <= maxBytes else {
            attachmentAlertMessage = "Tệp \(url.lastPathComponent) vượt quá 10MB"
            return
        }

        let ext = url.pathExtension.lowercased()
        let type = ["png", "jpg", "jpeg", "webp", "bmp"].contains(ext) ? "image" : "file"
        let att = ChatPendingAttachment(data: data, fileName: url.lastPathComponent, fileSize: Int64(data.count), type: type)

        if pendingAttachments.count < 5 {
            pendingAttachments.append(att)
        } else {
            attachmentAlertMessage = "Tối đa 5 tệp mỗi lần gửi"
        }
    }

    private var closedTicketFooter: some View {
        HStack {
            Image(systemName: "lock.fill")
                .foregroundColor(Color.gray)
            Text("Phiếu hỗ trợ này đã hoàn tất và đóng")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.gray)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#F1F5F9"))
    }

    private var ticketRejectedBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.octagon.fill")
                .foregroundColor(Color(hex: "#DC2626"))
            Text("Yêu cầu này đã bị từ chối / không tiếp nhận")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#DC2626"))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#FEE2E2"))
    }

    // MARK: - SHEET: TỪ CHỐI PHIẾU
    private var rejectTicketSheetView: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Lý do từ chối yêu cầu (không phù hợp / ngoài phạm vi):")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                TextEditor(text: $rejectReasonText)
                    .frame(height: 110)
                    .padding(8)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))

                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(hex: "#D97706"))
                    Text("Phiếu sẽ chuyển ngay vào tab 'Đã ẩn'. Hệ thống KHÔNG tự động tính 5★ sau 24h và miễn trừ khỏi KPI.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#92400E"))
                }
                .padding(10)
                .background(Color(hex: "#FEF3C7"))
                .cornerRadius(8)

                Button(action: {
                    let reason = rejectReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yêu cầu không phù hợp" : rejectReasonText
                    viewModel.rejectTicket(ticketId: ticket.id, reason: reason) { _ in }
                    showRejectReasonSheet = false
                }) {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Từ chối & Đóng yêu cầu")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color(hex: "#DC2626"))
                    .cornerRadius(10)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Từ chối phiếu")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Hủy") { showRejectReasonSheet = false })
        }
    }

    // MARK: - SHEET: BÁO CÁO KTV HOÀN THÀNH
    private var techResolveSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Ghi chú xử lý sự cố")) {
                    TextEditor(text: $techResolutionNote)
                        .frame(minHeight: 100)
                        .font(.system(size: 13.5))
                }
                Section(footer: Text("Sau khi báo cáo, hệ thống sẽ thông báo tới người tạo để nghiệm thu và đánh giá dịch vụ.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Báo cáo đã xử lý xong")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showTechResolveSheet = false },
                trailing: Button("Xác nhận") {
                    viewModel.markTicketResolved(ticketId: ticket.id, note: techResolutionNote) { success in
                        if success { showTechResolveSheet = false }
                    }
                }
                .font(.system(size: 14, weight: .bold))
            )
        }
    }

    // MARK: - SHEET: ĐÁNH GIÁ 5 SAO & NGHIỆM THU
    private var ratingSheetView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Đánh giá chất lượng hỗ trợ")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.top, 16)

                // 5 Interactive Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { selectedRating = star }) {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 32))
                                .foregroundColor(star <= selectedRating ? Color(hex: "#F59E0B") : Color(hex: "#CBD5E1"))
                        }
                    }
                }

                TextField("Nhận xét (không bắt buộc)...", text: $ratingComment)
                    .font(.system(size: 13.5))
                    .padding(12)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                    .padding(.horizontal, 20)

                Button(action: {
                    viewModel.rateTicket(ticketId: ticket.id, rating: selectedRating, feedback: ratingComment) { success in
                        if success { showRatingSheet = false }
                    }
                }) {
                    Text("Nghiệm thu & Đóng phiếu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Đóng") { showRatingSheet = false })
        }
    }

    // MARK: - SHEET: MỞ LẠI PHIẾU
    private var reopenSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Lý do mở lại sự cố *")) {
                    TextEditor(text: $reopenReason)
                        .frame(minHeight: 100)
                        .font(.system(size: 13.5))
                }
                Section(footer: Text("Phiếu sẽ được kích hoạt lại ở trạng thái MỞ LẠI và chuyển tới kỹ thuật viên phụ trách tiếp tục hỗ trợ.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Mở lại phiếu hỗ trợ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showReopenSheet = false },
                trailing: Button(action: {
                    if !reopenReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.reopenTicket(ticketId: ticket.id, reason: reopenReason) { success in
                            if success { showReopenSheet = false }
                        }
                    }
                }) {
                    Text("Mở lại")
                        .font(.system(size: 14, weight: .bold))
                }
                .disabled(reopenReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
    }

    // MARK: - HELPERS
    private func priorityColor(_ p: String) -> Color {
        switch p.uppercased() {
        case "URGENT": return Color(hex: "#EF4444")
        case "HIGH":   return Color(hex: "#F59E0B")
        default:       return Color(hex: "#10B981")
        }
    }

    private func formatMessageTime(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    private func startSlaTimer() {
        updateSlaCountdown()
        slaTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateSlaCountdown()
        }
    }

    private func updateSlaCountdown() {
        let limitMinutes = ticket.slaTargetMinutes
        let deadlineMs = ticket.createdAt + Int64(limitMinutes * 60 * 1000)
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let diffMs = deadlineMs - nowMs

        if diffMs <= 0 {
            slaIsOverdue = true
            let overSec = abs(diffMs) / 1000
            let h = overSec / 3600
            let m = (overSec % 3600) / 60
            let s = overSec % 60
            slaCountdown = String(format: "+%02d:%02d:%02d", h, m, s)
        } else {
            slaIsOverdue = false
            let remSec = diffMs / 1000
            let h = remSec / 3600
            let m = (remSec % 3600) / 60
            let s = remSec % 60
            slaCountdown = String(format: "%02d:%02d:%02d", h, m, s)
        }
    }
}
