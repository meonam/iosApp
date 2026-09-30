import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - ENUM ĐIỀU PHỐI SHEET ĐƠN LẺ TRÁNH XUNG ĐỘT TRÊN SWIFTUI
public enum ActiveChatSheet: Identifiable {
    case techResolve
    case rating
    case reopen
    case assignKtv
    case handover
    case liveTracking
    case rejectReason
    case selfResolved
    case imagePicker
    case documentPicker

    public var id: String {
        switch self {
        case .techResolve: return "techResolve"
        case .rating: return "rating"
        case .reopen: return "reopen"
        case .assignKtv: return "assignKtv"
        case .handover: return "handover"
        case .liveTracking: return "liveTracking"
        case .rejectReason: return "rejectReason"
        case .selfResolved: return "selfResolved"
        case .imagePicker: return "imagePicker"
        case .documentPicker: return "documentPicker"
        }
    }
}

// MARK: - MÀN HÌNH CHI TIẾT TICKET & CHAT TRỰC TIẾP (ĐỒNG BỘ 1:1 VỚI ADMINSUPPORTCHATSCREEN.KT)
public struct TicketChatDetailView: View {
    @ObservedObject var viewModel: SupportViewModel
    var ticket: SupportTicket
    var onBack: () -> Void

    @State private var inputText: String = ""
    @State private var showCloseTicketAlert: Bool = false
    @State private var showSelfResolvedAlert: Bool = false
    @State private var activeSheet: ActiveChatSheet? = nil
    @State private var showCallView: Bool = false
    @State private var selfResolvedReason: String = ""
    @State private var selectedPreviewImageUrl: String? = nil
    @State private var techResolutionNote: String = ""
    @State private var reopenReason: String = ""
    @State private var selectedRating: Int = 5
    @State private var ratingComment: String = ""
    @State private var rejectReasonText: String = ""
    @State private var isInternalNote: Bool = false

    // SLA countdown timer
    @State private var slaCountdown: String = ""
    @State private var slaTimer: Timer? = nil
    @State private var slaIsOverdue: Bool = false

    // MARK: - File Attachment State (đồng bộ Android AndroidPendingAttachment)
    /// Tối đa 5 tệp, mỗi tệp tối đa 10MB
    @State private var pendingAttachments: [ChatPendingAttachment] = []
    @State private var isUploadingAttachments: Bool = false
    @State private var attachmentAlertMessage: String? = nil

    public init(viewModel: SupportViewModel, ticket: SupportTicket, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.ticket = ticket
        self.onBack = onBack
    }

    private var currentTicket: SupportTicket {
        viewModel.tickets.first(where: { $0.id == ticket.id }) ?? ticket
    }

    private var myEmail: String {
        viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isCreator: Bool {
        let cEmail = currentTicket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cUser = currentTicket.creatorUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myId = viewModel.user.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (!myEmail.isEmpty && cEmail == myEmail) || (!myId.isEmpty && cUser == myId)
    }

    private var isAssignedTech: Bool {
        if isCreator { return false }
        return currentTicket.isUserAssigned(email: myEmail)
    }

    private var isAdminOrHelpDesk: Bool {
        viewModel.user.isAdmin || viewModel.user.isHelpDesk
    }

    private var isClosed: Bool {
        currentTicket.status.uppercased() == "CLOSED" || currentTicket.closedAt > 0
    }

    private var isReopenedActive: Bool {
        !isClosed && (currentTicket.reopenCount > 0 || currentTicket.reopenedAt > 0) &&
        currentTicket.status.uppercased() != "RESOLVED" &&
        !(currentTicket.reopenedAt > 0 && currentTicket.resolvedAt > currentTicket.reopenedAt)
    }

    private var isResolved: Bool {
        !isClosed && !isReopenedActive && (
            currentTicket.status.uppercased() == "RESOLVED" ||
            (currentTicket.reopenCount == 0 && currentTicket.reopenedAt <= 0 && currentTicket.resolvedAt > 0) ||
            (currentTicket.reopenedAt > 0 && currentTicket.resolvedAt > currentTicket.reopenedAt)
        )
    }

    private var isOpen: Bool {
        !isClosed
    }

    private var isTicketDone: Bool {
        isClosed || isResolved || currentTicket.resolvedAt > 0
    }

    private var canReopen: Bool {
        viewModel.isTicketReopenEnabled && isClosed && ticket.reopenCount < 2 && (ticket.isWithinQualityTrackingWindow || isAdminOrHelpDesk) && (isCreator || isAdminOrHelpDesk)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── 1. TOP BAR ──────────────────────────────────────
                    topBar(safeAreaTop: max(0, geometry.safeAreaInsets.top))

                    // ── 2. TICKET SUMMARY CARD (ĐỒNG BỘ 1:1 VỚI ANDROID) ─
                    ticketSummaryCard

                    // ── 3. SLA COUNTDOWN BAR (Đồng bộ 1:1 với Android: Chỉ đếm ngược khi ticket CHƯA giải quyết và có áp dụng SLA) ───
                    if !isTicketDone && currentTicket.slaTargetMinutes > 0 {
                        slaCountdownBar
                    }

                    // ── 4. DYNAMIC CONTEXTUAL ACTION BANNERS ────────────
                    contextualActionBanners

                    // ── 5. CHAT MESSAGES LIST ───────────────────────────
                    messagesListView

                    // ── 6. INPUT BAR (hoặc banner Đã đóng / Đã từ chối) ──────────────
                    if ticket.isRejected {
                        ticketRejectedBar
                    } else if isOpen {
                        chatInputBar
                    } else {
                        closedTicketFooter
                    }
                }

                // Full-screen Image Preview Overlay (nếu đang bấm xem ảnh)
                if let previewUrl = selectedPreviewImageUrl {
                    fullscreenImageOverlay(previewUrl)
                }

                // Overlay Cuộc gọi đến khi đang ở màn hình Ticket
                if let incomingCall = IncomingCallManager.shared.activeIncomingCall {
                    IncomingCallBannerView(
                        call: incomingCall,
                        onAccept: {
                            IncomingCallManager.shared.acceptCall()
                            showCallView = true
                        },
                        onReject: {
                            IncomingCallManager.shared.rejectCall()
                        }
                    )
                    .zIndex(99)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            VoiceNotificationHelper.shared.stopAlert(ticketId: ticket.id)
            viewModel.fetchMessages(for: ticket.id)
            startSlaTimer()
        }
        .onDisappear {
            slaTimer?.invalidate()
            slaTimer = nil
        }
        // ĐIỀU PHỐI SHEET ĐƠN LẺ CHÍNH THỨC TRÊN SWIFTUI (TRÁNH XUNG ĐỘT)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .techResolve:
                techResolveSheetView
            case .rating:
                ratingSheetView
            case .reopen:
                reopenSheetView
            case .assignKtv:
                DispatchTicketSheet(ticket: currentTicket, viewModel: viewModel, onDismiss: {
                    activeSheet = nil
                })
            case .handover:
                HandoverTicketSheetView(ticket: currentTicket, viewModel: viewModel)
            case .liveTracking:
                LiveTrackingMapView(
                    ticket: currentTicket,
                    viewModel: viewModel,
                    onDismiss: { activeSheet = nil },
                    onSelfResolved: { activeSheet = .selfResolved },
                    onTechResolve: { activeSheet = .techResolve }
                )
            case .rejectReason:
                rejectTicketSheetView
            case .selfResolved:
                selfResolvedSheetView
            case .imagePicker:
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
            case .documentPicker:
                ChatDocumentPicker { urls in
                    Task {
                        for url in urls {
                            await addAttachmentFromUrl(url)
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCallView) {
            CallView()
        }
        .alert(isPresented: $showCloseTicketAlert) {
            Alert(
                title: Text("Nghiệm thu & Đóng yêu cầu"),
                message: Text("Kỹ thuật viên đã xử lý xong. Xác nhận nghiệm thu và hoàn tất đóng phiếu hỗ trợ này?"),
                primaryButton: .default(Text("Nghiệm thu & Đóng")) {
                    viewModel.closeTicket(ticketId: ticket.id, rating: 5, feedback: "Admin/HelpDesk nghiệm thu & đóng phiếu") { _ in }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .onReceive(WebRtcCallManager.shared.$isCallPresented) { presented in
            showCallView = presented
        }
    }

    // MARK: - TOP BAR (ĐỒNG BỘ 1:1 VỚI ANDROID Image 2)
    private func topBar(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 6) {
                // Nút quay lại
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }

                // 1. Nút Bản đồ lộ trình KTV (Live Tracking Map)
                Button(action: { activeSheet = .liveTracking }) {
                    Image(systemName: "bicycle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                        .contentShape(Rectangle())
                }

                // 2. Nút Gọi thoại trực tiếp giữa Người tạo <-> KTV (P2P In-App)
                let callTargetEmail = isCreator ? ticket.assignedToEmail : ticket.creatorEmail
                let callTargetName = isCreator
                    ? (ticket.assignedToName.isEmpty ? "Kỹ thuật viên" : ticket.assignedToName)
                    : (ticket.creatorName.isEmpty ? "Người gửi yêu cầu" : ticket.creatorName)

                if !callTargetEmail.isEmpty && !isClosed {
                    Button(action: {
                        WebRtcCallManager.shared.companyId = viewModel.companyId
                        WebRtcCallManager.shared.idToken = viewModel.idToken
                        WebRtcCallManager.shared.startCall(
                            targetEmail: callTargetEmail,
                            targetName: callTargetName,
                            callerName: viewModel.user.fullName,
                            callerEmail: viewModel.user.email,
                            callerRole: viewModel.user.role
                        )
                        showCallView = true
                    }) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "#38BDF8"))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                }

                // 3. Nút Gọi thoại Hàng đợi Trực ban HelpDesk
                if !isClosed {
                    Button(action: {
                        WebRtcCallManager.shared.companyId = viewModel.companyId
                        WebRtcCallManager.shared.idToken = viewModel.idToken
                        WebRtcCallManager.shared.startSmartQueueCall(
                            companyId: viewModel.companyId,
                            callerEmail: viewModel.user.email,
                            callerName: viewModel.user.fullName,
                            callerRole: viewModel.user.role,
                            ticketId: ticket.id
                        )
                        showCallView = true
                    }) {
                        Image(systemName: "headphones")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "#FBBF24"))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                }

                // 4. Nút Bàn giao ca / Chuyển ticket (dành cho KTV được phân công)
                if isAssignedTech && !isClosed && !isResolved {
                    Button(action: {
                        viewModel.fetchKtvTechnicians()
                        activeSheet = .handover
                    }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color(hex: "#6366F1"))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }
                }

                Spacer(minLength: 4)

                // 5. Nút Điều phối KTV (Admin/HelpDesk) - Badge Pill chuẩn Android Image 2
                if isOpen && isAdminOrHelpDesk {
                    Button(action: {
                        viewModel.fetchKtvTechnicians()
                        activeSheet = .assignKtv
                    }) {
                        let isAssigned = !ticket.assignedToEmail.isEmpty || !ticket.assignedToName.isEmpty || !ticket.assignedCluster.isEmpty
                        let techDisplay = !ticket.assignedToName.isEmpty ? ticket.assignedToName : (!ticket.assignedToEmail.isEmpty ? ticket.assignedToEmail.components(separatedBy: "@").first ?? "" : "Điều phối")

                        HStack(spacing: 3) {
                            Image(systemName: isAssigned ? "checkmark.circle.fill" : "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(isAssigned ? Color(hex: "#86EFAC") : Color(hex: "#FCA5A5"))
                            Text(isAssigned ? "✓ \(techDisplay)" : "⚡ Điều phối (*)")
                                .font(.system(size: 11, weight: .bold))
                                .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(isAssigned ? Color(hex: "#10B981").opacity(0.3) : Color(hex: "#EF4444").opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isAssigned ? Color(hex: "#86EFAC") : Color(hex: "#FCA5A5"), lineWidth: 1)
                        )
                        .cornerRadius(8)
                        .contentShape(Rectangle())
                    }
                }

                // 6. Nút Đóng / Nghiệm thu / Từ chối (Chuẩn Android icon 30pt có gắn Alert)
                if isOpen && isAdminOrHelpDesk {
                    // Nút Từ chối / Đóng yêu cầu (X)
                    Button(action: {
                        rejectReasonText = ""
                        activeSheet = .rejectReason
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(hex: "#FCA5A5"))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                            .contentShape(Rectangle())
                    }

                    // Nút Nghiệm thu (✓) khi KTV đã xử lý xong hoặc đóng phiếu
                    if isResolved {
                        Button(action: { showCloseTicketAlert = true }) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "#86EFAC"))
                                .frame(width: 30, height: 30)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .contentShape(Rectangle())
                        }
                    }
                }

                // 7. Nút Mở lại phiếu (nếu đủ điều kiện)
                if canReopen {
                    Button(action: { activeSheet = .reopen }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#FBBF24"))
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - TICKET SUMMARY CARD (ĐỒNG BỘ 1:1 VỚI ANDROID AdminSupportChatScreen.kt:736-879)
    private var ticketSummaryCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Hàng 1: #TK-TICKET_1 • NANG CAP APP SOAN HANG
            HStack(spacing: 6) {
                let tCode = ticket.id.prefix(8).uppercased()
                Text("#TK-\(tCode) • \(ticket.subject.isEmpty ? "Chi tiết hỗ trợ" : ticket.subject)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Badge Trạng thái
                if isClosed {
                    Text("ĐÃ ĐÓNG")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(hex: "#64748B"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#F1F5F9"))
                        .cornerRadius(4)
                }

                // Điểm đánh giá sao nếu có
                if ticket.rating > 0 {
                    Text("⭐ \(ticket.rating)/5")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FEF3C7"))
                        .cornerRadius(4)
                }

                // Miễn trừ KPI nếu có
                if ticket.isObjectiveExclusion {
                    Text("🛡️ Miễn trừ KPI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#166534"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#DCFCE7"))
                        .cornerRadius(4)
                }
            }

            // Hàng 2: Submeta: 📱 App • 🏬 Co.opmart Phú Lâm • 👤 Co.opmart Phú Lâm • ➡️ IT Tập...
            HStack(spacing: 5) {
                let channelText: String = {
                    switch ticket.source.uppercased() {
                    case "ZALO": return "💬 Zalo"
                    case "EMAIL": return "✉️ Email"
                    default: return "📱 App"
                    }
                }()
                Text(channelText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)

                if !ticket.donVi.isEmpty {
                    Text("•")
                        .foregroundColor(Color.appTextMuted)
                        .font(.system(size: 10))
                    Text("🏬 \(ticket.donVi)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                let creatorDisp = ticket.creatorName.isEmpty ? (ticket.creatorEmail.components(separatedBy: "@").first ?? ticket.creatorEmail) : ticket.creatorName
                if !creatorDisp.isEmpty {
                    Text("•")
                        .foregroundColor(Color.appTextMuted)
                        .font(.system(size: 10))
                    Text("👤 \(creatorDisp)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                if !ticket.assignedDepartmentName.isEmpty {
                    Text("•")
                        .foregroundColor(Color.appTextMuted)
                        .font(.system(size: 10))
                    Text("➡️ \(ticket.assignedDepartmentName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.appSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.appCardBorder),
            alignment: .bottom
        )
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
                Button(action: { activeSheet = .liveTracking }) {
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

            // ── Banner 2: Thẻ "Tôi đã tự xử lý xong" (cho User tạo phiếu, ẩn với Admin/KTV/HelpDesk) ──
            if isCreator && isOpen && !isResolved && !isAdminOrHelpDesk && !isAssignedTech {
                Button(action: { activeSheet = .selfResolved }) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "#D97706"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("💡 Bạn đã tự xử lý xong sự cố?")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#92400E"))
                            Text("Bấm để đóng yêu cầu & dừng chuyến đi KTV")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(hex: "#B45309"))
                        }

                        Spacer()

                        Text("Đóng phiếu")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#D97706"))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#FFFBEB"))
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
                    .padding(.horizontal, 12)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // ── Banner 3: Chọn phương thức xử lý (CHỈ cho KTV được phân công, ẩn với HelpDesk & Admin) ──
            if isAssignedTech && !isAdminOrHelpDesk && isOpen && !isResolved {
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
                        activeSheet = .techResolve
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
                .background(Color.appSurface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .bottom)
            }

            // ── Banner 4: Nghiệm thu & Đánh giá 5 sao (cho Người tạo khi RESOLVED) ──
            if isResolved {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#10B981"))
                        Text(currentTicket.isSpecialistAssigned ? "Chuyên viên đã báo cáo hoàn thành sự cố" : "Kỹ thuật viên đã báo cáo hoàn thành sự cố")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#065F46"))
                        Spacer()

                        // Badge cố định thời hạn SLA đã hoàn tất (Đồng hồ SLA đã dừng khi KTV báo xong)
                        if currentTicket.slaTargetMinutes > 0 && currentTicket.resolvedAt > 0 {
                            let deadlineMs = currentTicket.createdAt + Int64(currentTicket.slaTargetMinutes * 60 * 1000)
                            let isWithinSla = currentTicket.resolvedAt <= deadlineMs
                            Text(isWithinSla ? "⏱️ Đạt chuẩn SLA" : "⚠️ Quá hạn SLA")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(isWithinSla ? Color(hex: "#166534") : Color(hex: "#DC2626"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(isWithinSla ? Color(hex: "#DCFCE7") : Color(hex: "#FEE2E2"))
                                .cornerRadius(4)
                        }
                    }

                    if isCreator {
                        HStack {
                            Text("Vui lòng đánh giá để nghiệm thu đóng phiếu:")
                                .font(.system(size: 11))
                                .foregroundColor(Color.gray)
                            Spacer()
                            Button("⭐ Đánh giá & Đóng") {
                                activeSheet = .rating
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
                        activeSheet = .reopen
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
                    // Mô tả ban đầu (kèm hình ảnh, tệp đính kèm, thông tin thiết bị)
                    if !currentTicket.initialMessage.isEmpty || !currentTicket.images.isEmpty || !currentTicket.attachments.isEmpty {
                        initialMessageCard
                    }

                    // Danh sách tin nhắn trao đổi
                    ForEach(viewModel.messages) { msg in
                        messageBubbleView(msg)
                            .id(msg.id)
                    }

                    // Thẻ Đánh giá chất lượng hỗ trợ (đồng bộ 1:1 Android khi đã xử lý xong hoặc đã đóng)
                    if isResolved || isClosed {
                        supportRatingSectionView
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
        VStack(alignment: .leading, spacing: 6) {
            // Category & Priority & Time (đồng bộ thẻ thông tin Android)
            HStack {
                HStack(spacing: 4) {
                    let catText = categoryBadgeText(currentTicket.category)
                    Text(catText)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(hex: "#0369A1"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#E0F2FE"))
                        .cornerRadius(4)

                    let (pText, pBg, pCol) = priorityBadgeInfo(currentTicket.priority)
                    Text(pText)
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(pCol)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(pBg)
                        .cornerRadius(4)
                }

                Spacer()

                if currentTicket.createdAt > 0 {
                    Text(formatDate(currentTicket.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(Color.gray)
                }
            }

            // Thiết bị liên quan
            let assetLabel = currentTicket.assetName.isEmpty ? currentTicket.assetId : currentTicket.assetName
            if !assetLabel.isEmpty {
                HStack(spacing: 4) {
                    Text("💻 Thiết bị: \(assetLabel) \(currentTicket.assetId.isEmpty ? "" : "(\(currentTicket.assetId))")")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#334155"))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(hex: "#F1F5F9"))
                .cornerRadius(4)
            }

            // Đơn vị yêu cầu
            if !currentTicket.donVi.isEmpty {
                Text("🏬 Đơn vị: \(currentTicket.donVi)")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: "#475569"))
            }

            // Số điện thoại liên hệ
            if !currentTicket.creatorPhone.isEmpty {
                Text("📞 SĐT người tạo: \(currentTicket.creatorPhone)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }

            // App User đã đăng ký
            if !currentTicket.creatorUserId.isEmpty {
                Text("👤 App User: \(currentTicket.creatorUserId)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#15803D"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#DCFCE7"))
                    .cornerRadius(4)
            }

            // Nội dung mô tả sự cố
            if !currentTicket.initialMessage.isEmpty {
                Text("📝 Vấn đề: \(currentTicket.initialMessage)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#1E293B"))
            }

            // Hình ảnh chụp hiện trường ban đầu
            if !currentTicket.images.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📷 Ảnh sự cố ban đầu:")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: "#475569"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currentTicket.images, id: \.self) { imgUrl in
                                Button(action: {
                                    selectedPreviewImageUrl = imgUrl
                                }) {
                                    if let url = URL(string: imgUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty:
                                                Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 72, height: 72)
                                            case .success(let image):
                                                image.resizable().scaledToFill().frame(width: 72, height: 72).clipped()
                                            case .failure:
                                                Image(systemName: "photo").frame(width: 72, height: 72).background(Color.gray.opacity(0.1))
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            // Tệp tài liệu đính kèm ban đầu
            if !currentTicket.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📎 Tệp đính kèm:")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: "#475569"))

                    ForEach(currentTicket.attachments) { att in
                        Button(action: {
                            if let url = URL(string: att.url) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: documentIconName(att.type))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .font(.system(size: 13))
                                Text(att.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color(hex: "#1E293B"))
                                    .lineLimit(1)
                                Spacer()
                                if att.size > 0 {
                                    Text("\(max(1, att.size / 1024)) KB")
                                        .font(.system(size: 9.5))
                                        .foregroundColor(Color.gray)
                                }
                                Image(systemName: "arrow.down.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.appSurfaceVariant)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }
                }
                .padding(.top, 2)
            }

            // PHÂN LOẠI NHANH: Dành cho HelpDesk / Admin hoặc Ticket gửi từ Email (ĐỒNG BỘ 1:1 ANDROID Image 2)
            if (currentTicket.source.uppercased() == "EMAIL" || isAdminOrHelpDesk) && isOpen {
                Divider()
                    .background(Color.appCardBorder)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("⚡ Phân loại sự cố nhanh:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#0369A1"))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            let cats: [(key: String, label: String)] = [
                                ("HARDWARE", "🖥️ Phần cứng"),
                                ("SOFTWARE", "💾 Phần mềm"),
                                ("NETWORK", "🌐 Mạng/Internet"),
                                ("PRINTER", "🖨️ Máy in"),
                                ("ACCOUNT", "👤 Tài khoản"),
                                ("OTHER", "➕ Khác")
                            ]
                            ForEach(cats, id: \.key) { c in
                                let isCur = currentTicket.category.uppercased() == c.key
                                Button(action: {
                                    if !isCur {
                                        viewModel.updateTicketCategory(ticketId: currentTicket.id, newCategory: c.key)
                                    }
                                }) {
                                    Text(c.label)
                                        .font(.system(size: 10.5, weight: isCur ? .bold : .medium))
                                        .foregroundColor(isCur ? Color.white : Color.appTextPrimary)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 4.5)
                                        .background(isCur ? Color(hex: "#0284C7") : Color.appSurfaceVariant)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(isCur ? Color(hex: "#0369A1") : Color.appCardBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
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
                        .foregroundColor(isMine ? Color.white : Color.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isMine ? Color.appPrimaryPink : Color.appSurface)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isMine ? Color.clear : Color.appCardBorder, lineWidth: 1)
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
                .background(Color.appSurfaceVariant)

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
                    Button(action: { activeSheet = .imagePicker }) {
                        Label("Chọn ảnh từ thư viện", systemImage: "photo.on.rectangle")
                    }
                    Button(action: { activeSheet = .documentPicker }) {
                        Label("Chọn tài liệu", systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18))
                        .foregroundColor(pendingAttachments.count >= 5 ? Color.gray : Color.appPrimaryPink)
                        .frame(width: 36, height: 36)
                        .background(Color.appSurfaceVariant)
                        .clipShape(Circle())
                }
                .disabled(pendingAttachments.count >= 5)

                TextField("Nhập nội dung...", text: $inputText)
                    .font(.system(size: 13.5))
                    .foregroundColor(Color.appTextPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))

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
            .padding(.top, 8)
            .padding(.bottom, (isAdminOrHelpDesk || isAssignedTech) ? 4 : 8)

            // Checkbox Ghi chú nội bộ (ĐỒNG BỘ 1:1 VỚI ANDROID Image 2)
            if isAdminOrHelpDesk || isAssignedTech {
                HStack(spacing: 6) {
                    Button(action: { isInternalNote.toggle() }) {
                        Image(systemName: isInternalNote ? "checkmark.square.fill" : "square")
                            .foregroundColor(isInternalNote ? Color(hex: "#EAB308") : Color.appTextMuted)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text("Ghi chú nội bộ (Chat mật KTV / Chuyên viên & Helpdesk/Admin)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#B45309"))

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }
        }
        .background(Color.appSurface)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .top)
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
        let sendInternal = isInternalNote
        inputText = ""
        isInternalNote = false
        pendingAttachments = []

        // Gửi tin nhắn kèm danh sách URL ảnh đính kèm
        viewModel.sendMessage(
            ticketId: ticket.id,
            text: text,
            isInternal: sendInternal,
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

    private func formatTimestamp(_ ms: Int64, format: String = "dd/MM HH:mm") -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: Double(ms) / 1000.0)
        let df = DateFormatter()
        df.locale = Locale(identifier: "vi_VN")
        df.dateFormat = format
        return df.string(from: date)
    }

    private var closedTicketFooter: some View {
        let effectiveRating = currentTicket.effectiveRating
        let hasRating = effectiveRating > 0

        return VStack(spacing: 0) {
            if hasRating {
                // Đã đánh giá hoặc tự động 5 sao sau 24h → hiển thị Card đánh giá cố định ở cuối màn hình với icon ổ khoá
                let isHighRating = effectiveRating >= 3
                let containerBg = isHighRating ? Color(hex: "#F0FDF4") : Color(hex: "#FEF2F2")
                let containerBorder = isHighRating ? Color(hex: "#BBF7D0") : Color(hex: "#FECACA")
                let themeColor = isHighRating ? Color(hex: "#15803D") : Color(hex: "#B91C1C")

                VStack(alignment: .leading, spacing: 8) {
                    // Header sao & thời gian
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(themeColor)

                            // 5 sao
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= effectiveRating ? "star.fill" : "star")
                                        .font(.system(size: 14))
                                        .foregroundColor(star <= effectiveRating ? Color(hex: "#F59E0B") : Color(hex: "#CBD5E1"))
                                }
                            }

                            Text("\(effectiveRating)/5 ⭐")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(themeColor)
                        }

                        Spacer()

                        // Thời gian đánh giá hoặc hoàn tất
                        let displayTime = currentTicket.feedbackAt > 0 ? currentTicket.feedbackAt : (currentTicket.closedAt > 0 ? currentTicket.closedAt : currentTicket.lastMessageAt)
                        if displayTime > 0 {
                            Text(formatTimestamp(displayTime))
                                .font(.system(size: 11))
                                .foregroundColor(Color.gray)
                        }
                    }

                    // Nhận xét (Feedback)
                    let effectiveFb = currentTicket.effectiveFeedback
                    if !effectiveFb.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Text("💬 Nhận xét: \"\(effectiveFb)\"")
                                .font(.system(size: 11.5, weight: .medium))
                                .italic()
                                .foregroundColor(Color(hex: "#1E293B"))
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.85))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                                )
                        }
                    }

                    // Phụ chú khóa
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(Color.gray.opacity(0.7))
                        Text("🔒 Đánh giá đã được ghi nhận vào hồ sơ KPI và tự động khóa.")
                            .font(.system(size: 10))
                            .foregroundColor(Color.gray.opacity(0.85))
                    }
                }
                .padding(12)
                .background(containerBg)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(containerBorder, lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            } else {
                // Phiếu đã đóng nhưng chưa đánh giá
                if isCreator {
                    // Người tạo yêu cầu: hiển thị nút đánh giá
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(Color(hex: "#F59E0B"))
                                .font(.system(size: 16))
                            Text("Yêu cầu đã được đóng. Mời bạn đánh giá dịch vụ hỗ trợ:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#1E293B"))
                        }

                        Button(action: {
                            activeSheet = .rating
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                Text("Đánh giá ngay (⭐ 1-5 sao)")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#10B981"))
                            .cornerRadius(8)
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#F8FAFC"))
                    .overlay(
                        Rectangle().frame(height: 1).foregroundColor(Color(hex: "#E2E8F0")),
                        alignment: .top
                    )
                } else {
                    // KTV / người khác xem: hiển thị chờ đánh giá
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color.gray)
                        Text("Phiếu đã đóng. Đang chờ người dùng đánh giá chất lượng dịch vụ.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.gray)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#F1F5F9"))
                }
            }
        }
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
                    activeSheet = nil
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
            .navigationBarItems(leading: Button("Hủy") { activeSheet = nil })
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
                leading: Button("Hủy") { activeSheet = nil },
                trailing: Button("Xác nhận") {
                    viewModel.markTicketResolved(ticketId: ticket.id, note: techResolutionNote) { success in
                        if success { activeSheet = nil }
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
                        if success { activeSheet = nil }
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
            .navigationBarItems(leading: Button("Đóng") { activeSheet = nil })
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
                leading: Button("Hủy") { activeSheet = nil },
                trailing: Button(action: {
                    if !reopenReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.reopenTicket(ticketId: ticket.id, reason: reopenReason) { success in
                            if success { activeSheet = nil }
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
        if isTicketDone {
            slaTimer?.invalidate()
            slaTimer = nil
            return
        }
        updateSlaCountdown()
        slaTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isTicketDone {
                slaTimer?.invalidate()
                slaTimer = nil
                return
            }
            updateSlaCountdown()
        }
    }

    private func updateSlaCountdown() {
        if isTicketDone {
            slaTimer?.invalidate()
            slaTimer = nil
            return
        }
        let limitMinutes = currentTicket.slaTargetMinutes
        let deadlineMs = currentTicket.createdAt + Int64(limitMinutes * 60 * 1000)
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

    // MARK: - RATING SECTION VIEW (ĐỒNG BỘ 100% ANDROID AdminSupportChatScreen.kt lines 1740-1847)
    @ViewBuilder
    private var supportRatingSectionView: some View {
        let ticketRating = currentTicket.rating
        if ticketRating > 0 {
            // Đã đánh giá / Tự động 5 sao sau 24h -> Hiển thị Card đánh giá cố định có ổ khóa
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(ticketRating >= 3 ? Color(hex: "#15803D") : Color(hex: "#B91C1C"))

                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= ticketRating ? "star.fill" : "star")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                        }

                        Text("\(ticketRating)/5 ⭐")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ticketRating >= 3 ? Color(hex: "#15803D") : Color(hex: "#B91C1C"))
                    }

                    Spacer()

                    let displayTime = currentTicket.feedbackAt > 0 ? currentTicket.feedbackAt : (currentTicket.closedAt > 0 ? currentTicket.closedAt : currentTicket.lastMessageAt)
                    if displayTime > 0 {
                        Text(formatMessageTime(displayTime))
                            .font(.system(size: 10))
                            .foregroundColor(Color.gray)
                    }
                }

                let effectiveFb = currentTicket.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
                if !effectiveFb.isEmpty {
                    Text("💬 Nhận xét: \"\(effectiveFb)\"")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(Color(hex: "#1E293B"))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.85))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }

                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.gray.opacity(0.6))
                    Text("Đánh giá chất lượng đã được lưu vào hệ thống KPI.")
                        .font(.system(size: 10))
                        .foregroundColor(Color.gray)
                }

                if isAdminOrHelpDesk && !isClosed {
                    Button(action: { showCloseTicketAlert = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Nghiệm thu & Đóng phiếu")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(Color(hex: "#16A34A"))
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(ticketRating >= 3 ? Color(hex: "#F0FDF4") : Color(hex: "#FEF2F2"))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ticketRating >= 3 ? Color(hex: "#BBF7D0") : Color(hex: "#FECACA"), lineWidth: 1))
        } else if isCreator {
            // Người tạo xem phiếu khi KTV đã xử lý xong và chưa đánh giá -> Hiển thị form đánh giá nhanh
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "star.bubble.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .font(.system(size: 16))
                    Text("Đánh giá chất lượng hỗ trợ")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Text("Kỹ thuật viên đã xử lý xong sự cố. Xin mời bạn đánh giá chất lượng dịch vụ:")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.gray)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { selectedRating = star }) {
                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                .font(.system(size: 26))
                                .foregroundColor(star <= selectedRating ? Color(hex: "#F59E0B") : Color(hex: "#CBD5E1"))
                        }
                    }
                }

                TextField("Nhận xét thêm (không bắt buộc)...", text: $ratingComment)
                    .font(.system(size: 12.5))
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))

                Button(action: {
                    viewModel.rateTicket(ticketId: ticket.id, rating: selectedRating, feedback: ratingComment) { _ in }
                }) {
                    Text("✅ Gửi đánh giá & Nghiệm thu")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(hex: "#10B981"))
                        .cornerRadius(8)
                }
            }
            .padding(12)
            .background(Color(hex: "#FFFBEB"))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
        } else {
            // KTV / Quản trị viên xem khi chưa có đánh giá
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(Color.gray)
                Text("⏳ Chờ người dùng đánh giá chất lượng (Tự động ghi nhận 5★ sau 24h)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color(hex: "#F8FAFC"))
            .cornerRadius(8)
        }
    }

    // MARK: - SHEET: XÁC NHẬN TỰ XỬ LÝ (ĐỒNG BỘ 1:1 ANDROID SelfResolvedConfirmDialog)
    private var selfResolvedSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Xác nhận sự cố")) {
                    Text("Sự cố của bạn đã hoạt động bình thường? Thao tác này sẽ đóng yêu cầu hỗ trợ và dừng chuyến đi của Kỹ thuật viên an toàn.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#334155"))
                }

                Section(header: Text("Chọn lý do để lưu nhật ký báo cáo *")) {
                    let reasons = [
                        "Đã cắm lại dây nguồn / dây mạng / cáp kết nối",
                        "Đã khởi động lại máy / thiết bị và chạy tốt",
                        "Đồng nghiệp xung quanh đã hỗ trợ xong",
                        "Sự cố tự hết / Không cần hỗ trợ nữa"
                    ]
                    ForEach(reasons, id: \.self) { r in
                        Button(action: {
                            selfResolvedReason = r
                        }) {
                            HStack {
                                Image(systemName: selfResolvedReason == r ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(selfResolvedReason == r ? Color(hex: "#10B981") : Color.gray)
                                Text(r)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: "#1E293B"))
                                Spacer()
                            }
                        }
                    }

                    TextField("Lý do khác (tùy chọn)...", text: $selfResolvedReason)
                        .font(.system(size: 13))
                }

                Section(footer: Text("Hệ thống sẽ cập nhật trạng thái phiếu là ĐÃ ĐÓNG và hủy lệnh di chuyển của KTV.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Tự khắc phục sự cố")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { activeSheet = nil },
                trailing: Button("Xác nhận Đóng") {
                    let reasonToSubmit = selfResolvedReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Đã cắm lại dây nguồn / dây mạng / cáp kết nối"
                        : selfResolvedReason
                    viewModel.selfResolveTicket(ticketId: ticket.id, reason: reasonToSubmit) { success in
                        if success {
                            activeSheet = nil
                            if currentTicket.rating == 0 {
                                activeSheet = .rating
                            }
                        }
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(hex: "#10B981"))
            )
        }
    }

    // MARK: - FULLSCREEN IMAGE OVERLAY
    @ViewBuilder
    private func fullscreenImageOverlay(_ imgUrl: String) -> some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { selectedPreviewImageUrl = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(16)
                    }
                }

                Spacer()

                if let url = URL(string: imgUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().tint(.white)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding()
                        case .failure:
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                Text("Không thể tải hình ảnh")
                                    .foregroundColor(.white)
                                    .font(.system(size: 13))
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                Spacer()
            }
        }
    }

    private func categoryBadgeText(_ cat: String) -> String {
        switch cat.uppercased() {
        case "HARDWARE": return "🖥️ Phần cứng"
        case "SOFTWARE": return "💾 Phần mềm"
        case "NETWORK": return "🌐 Mạng/Internet"
        case "PRINTER": return "🖨️ Máy in"
        case "ACCOUNT": return "👤 Tài khoản"
        case "OTHER": return "➕ Khác"
        default: return "➕ \(cat.isEmpty ? "Khác" : cat)"
        }
    }

    private func priorityBadgeInfo(_ p: String) -> (String, Color, Color) {
        switch p.uppercased() {
        case "URGENT", "CRITICAL": return ("🔴 Gấp (<1h)", Color(hex: "#FEE2E2"), Color(hex: "#DC2626"))
        case "HIGH": return ("🟡 Cần gấp (4h)", Color(hex: "#FEF3C7"), Color(hex: "#D97706"))
        default: return ("🟢 Thường (24h)", Color(hex: "#DCFCE7"), Color(hex: "#16A34A"))
        }
    }

    private func formatDate(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let d = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: d)
    }

    private func documentIconName(_ type: String) -> String {
        let t = type.lowercased()
        if t.contains("pdf") { return "doc.text.fill" }
        if t.contains("doc") || t.contains("word") { return "doc.fill" }
        if t.contains("xls") || t.contains("sheet") || t.contains("excel") { return "tablecells.fill" }
        if t.contains("zip") || t.contains("rar") { return "archivebox.fill" }
        return "doc.fill"
    }
}
