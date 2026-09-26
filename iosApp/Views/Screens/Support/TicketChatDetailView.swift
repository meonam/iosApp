import SwiftUI

// MARK: - MÀN HÌNH CHI TIẾT TICKET & CHAT TRỰC TIẾP (ĐỒNG BỘ 1:1 VỚI ANDROID)
// Đồng bộ với: AdminSupportChatScreen.kt
public struct TicketChatDetailView: View {
    @ObservedObject var viewModel: SupportViewModel
    var ticket: SupportTicket
    var onBack: () -> Void

    @State private var inputText: String = ""
    @State private var showCloseTicketAlert: Bool = false
    @State private var closeNote: String = ""
    @State private var showCallView: Bool = false

    // Assign KTV
    @State private var showAssignKtvSheet: Bool = false

    // Rating sheet
    @State private var showRatingSheet: Bool = false
    @State private var selectedRating: Int = 0
    @State private var ratingComment: String = ""

    // SLA countdown
    @State private var slaCountdown: String = ""
    @State private var slaTimer: Timer? = nil
    @State private var slaIsOverdue: Bool = false

    // SLA deadline: URGENT=1h, HIGH=4h, NORMAL=24h — đồng bộ Android
    private var slaDeadlineMs: Int64 {
        switch ticket.priority.uppercased() {
        case "URGENT": return ticket.createdAt + 3_600_000
        case "HIGH":   return ticket.createdAt + 14_400_000
        default:       return ticket.createdAt + 86_400_000
        }
    }

    public init(viewModel: SupportViewModel, ticket: SupportTicket, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.ticket = ticket
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ─── 1. TOP BAR TRÀN TAI THỎ ───────────────────────────
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 10) {
                            // Nút back
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            // Tiêu đề ticket
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ticket.subject.isEmpty ? "Chi tiết sự cố" : ticket.subject)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text("#\(ticket.id.prefix(8).uppercased()) • \(ticket.creatorName)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // ── Chip Phân công KTV (Admin/HelpDesk) ──────
                            if viewModel.user.email.lowercased() != ticket.creatorEmail.lowercased() {
                                Button(action: {
                                    WebRtcCallManager.shared.startCall(targetEmail: ticket.creatorEmail, targetName: ticket.creatorName, callerName: viewModel.user.fullName, callerEmail: viewModel.user.email)
                                    showCallView = true
                                }) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(.green)
                                        .padding(6)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                            }
                            if ticket.isOpen && (viewModel.user.isAdmin || viewModel.user.isHelpDesk) {
                                Button(action: {
                                    viewModel.fetchKtvTechnicians()
                                    showAssignKtvSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: ticket.assignedToEmail.isEmpty
                                              ? "person.badge.plus"
                                              : "person.fill.checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(ticket.assignedToEmail.isEmpty
                                             ? "Phân công"
                                             : (ticket.assignedToName.isEmpty ? "KTV" : ticket.assignedToName))
                                            .font(.system(size: 11, weight: .bold))
                                            .lineLimit(1)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(ticket.assignedToEmail.isEmpty
                                                ? Color.red.opacity(0.85)
                                                : Color.green.opacity(0.85))
                                    .cornerRadius(8)
                                }
                                .frame(maxWidth: 110)
                            }

                            // ── Nút Rating (người tạo, ticket đã đóng, chưa đánh giá) ──
                            let isCreator = viewModel.user.email.lowercased() == ticket.creatorEmail.lowercased()
                            if isCreator && !ticket.isOpen && ticket.rating == 0 {
                                Button(action: { showRatingSheet = true }) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 15))
                                        .foregroundColor(.yellow)
                                }
                            }

                            // ── Nút Hoàn tất (Admin/HelpDesk/Tech) ─────────
                            if ticket.isOpen && (viewModel.user.isAdmin || viewModel.user.isHelpDesk || viewModel.user.isTechnician) {
                                Button(action: { showCloseTicketAlert = true }) {
                                    Text("Hoàn tất")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.appSuccess)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // ─── 2. THÔNG TIN SỰ CỐ TÓM TẮT ────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Thiết bị: \(ticket.assetName.isEmpty ? "Thiết bị chung" : ticket.assetName)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.appTextPrimary)
                                Text("Đơn vị: \(ticket.donVi.isEmpty ? "Chưa rõ" : ticket.donVi)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            Spacer()

                            // Nút KTV Tiếp nhận sự cố
                            if ticket.isOpen && !ticket.isAcknowledged && (viewModel.user.isTechnician || viewModel.user.isAdmin || viewModel.user.isHelpDesk) {
                                Button(action: {
                                    viewModel.acknowledgeTicket(ticketId: ticket.id)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.shield.fill")
                                        Text("Tiếp nhận")
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.appPrimaryPink)
                                    .cornerRadius(8)
                                }
                            }
                        }

                        // ── Badge trạng thái + đánh giá ─────────────────────
                        HStack(spacing: 6) {
                            if !ticket.isOpen {
                                Text("CLOSED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.gray)
                                    .cornerRadius(10)
                            } else {
                                Text("OPEN")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }

                            if ticket.rating > 0 {
                                Text("⭐ \(ticket.rating)/5")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#D97706"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#FEF3C7"))
                                    .cornerRadius(10)
                            }

                            Spacer()
                        }

                        // ── SLA countdown (chỉ hiện khi OPEN) ───────────────
                        if ticket.isOpen {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(slaIsOverdue ? .red : Color.appTextSecondary)
                                Text(slaIsOverdue
                                     ? "⚠ QUÁ HẠN SLA: \(slaCountdown)"
                                     : "SLA còn: \(slaCountdown)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(slaIsOverdue ? .red : Color.appTextSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .bottom)

                    // ─── 3. DANH SÁCH TIN NHẮN CHAT ─────────────────────────
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Tin nhắn mô tả ban đầu của người tạo
                                if !ticket.initialMessage.isEmpty {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Yêu cầu ban đầu:")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(Color.appSecondaryDarkBlue)
                                            Text(ticket.initialMessage)
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appTextPrimary)
                                        }
                                        .padding(12)
                                        .background(Color.appSecondaryDarkBlue.opacity(0.08))
                                        .cornerRadius(12)
                                        Spacer()
                                    }
                                }

                                // Các tin nhắn trao đổi
                                ForEach(viewModel.messages) { msg in
                                    messageBubble(msg)
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

                    // ─── 4. KHUNG NHẬP TIN NHẮN ─────────────────────────────
                    if ticket.isOpen {
                        HStack(spacing: 8) {
                            TextField("Nhập tin nhắn trao đổi...", text: $inputText)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))

                            Button(action: {
                                let text = inputText
                                inputText = ""
                                viewModel.sendMessage(ticketId: ticket.id, text: text)
                            }) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.appPrimaryPink)
                                    .clipShape(Circle())
                            }
                            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSendingMessage)
                        }
                        .padding(10)
                        .background(Color.white)
                        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .top)
                    } else {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Color.appTextSecondary)
                            Text("Phiếu hỗ trợ này đã được hoàn tất và đóng")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
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
        .alert(isPresented: $showCloseTicketAlert) {
            Alert(
                title: Text("Hoàn tất sự cố"),
                message: Text("Xác nhận hoàn tất và đóng phiếu hỗ trợ này?"),
                primaryButton: .default(Text("Đóng phiếu")) {
                    viewModel.closeTicket(ticketId: ticket.id, note: "Đã xử lý xong bởi KTV")
                    onBack()
                },
                secondaryButton: .cancel()
            )
        }
        // ─── Sheet: Chọn KTV phân công ───────────────────────────────────
        .fullScreenCover(isPresented: $showCallView) {
            CallView()
        }
        .sheet(isPresented: $showAssignKtvSheet) {
            NavigationView {
                Group {
                    if viewModel.isLoadingKtvs {
                        ProgressView("Đang tải danh sách KTV...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.ktvTechnicians.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "person.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Không có KTV nào đang hoạt động")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(viewModel.ktvTechnicians, id: \.email) { ktv in
                            Button(action: {
                                viewModel.assignKtv(
                                    ticketId: ticket.id,
                                    ktvEmail: ktv.email,
                                    ktvName: ktv.name
                                )
                                showAssignKtvSheet = false
                            }) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(ktv.isOnline ? Color.green : Color.gray)
                                        .frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ktv.name.isEmpty ? ktv.email : ktv.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(ktv.email)
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                        if ktv.isOnline {
                                            Text("● Đang online")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                    if ktv.email.lowercased() == ticket.assignedToEmail.lowercased() {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .navigationTitle("Phân công KTV")
                .navigationBarItems(trailing: Button("Đóng") { showAssignKtvSheet = false })
            }
        }
        // ─── Sheet: Đánh giá dịch vụ (5 sao) ────────────────────────────
        .sheet(isPresented: $showRatingSheet) {
            VStack(spacing: 24) {
                Text("Đánh giá dịch vụ")
                    .font(.title2.bold())
                    .padding(.top, 24)

                Text("Sự cố: \(ticket.subject.isEmpty ? "#\(ticket.id.prefix(8).uppercased())" : ticket.subject)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // 5 sao
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= selectedRating ? "star.fill" : "star")
                            .font(.system(size: 38))
                            .foregroundColor(star <= selectedRating ? .yellow : .gray)
                            .onTapGesture { selectedRating = star }
                    }
                }

                if selectedRating > 0 {
                    Text(["", "Rất tệ", "Tệ", "Bình thường", "Tốt", "Xuất sắc"][selectedRating])
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(selectedRating >= 4 ? .green : selectedRating == 3 ? .orange : .red)
                }

                TextField("Nhận xét (tùy chọn)...", text: $ratingComment)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button(action: {
                    if selectedRating > 0 {
                        viewModel.rateTicket(
                            ticketId: ticket.id,
                            rating: selectedRating,
                            comment: ratingComment
                        )
                        showRatingSheet = false
                    }
                }) {
                    Text("Gửi đánh giá")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedRating > 0 ? Color.appPrimaryPink : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(selectedRating == 0)
                .padding(.horizontal)

                Button("Hủy") { showRatingSheet = false }
                    .foregroundColor(.gray)
                    .padding(.bottom, 24)
            }
            .padding()
        }
    }

    // ─── SLA Timer ────────────────────────────────────────────────────────
    private func startSlaTimer() {
        let update = {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let remaining = slaDeadlineMs - now
            slaIsOverdue = remaining < 0
            let absMs = abs(remaining) / 1000
            let h = absMs / 3600
            let m = (absMs % 3600) / 60
            let s = absMs % 60
            slaCountdown = String(format: "%dh%02dm%02ds", h, m, s)
        }
        update()
        slaTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in update() }
        }
    }

    // ─── Message Bubble ───────────────────────────────────────────────────
    private func messageBubble(_ msg: SupportMessage) -> some View {
        let isMe = msg.senderEmail.lowercased() == viewModel.user.email.lowercased()

        return HStack {
            if isMe { Spacer(minLength: 40) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                if !isMe {
                    Text(msg.senderName.isEmpty ? msg.senderEmail : msg.senderName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                }

                Text(msg.message)
                    .font(.system(size: 13))
                    .foregroundColor(isMe ? .white : Color.appTextPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMe ? Color.appSecondaryDarkBlue : Color.white)
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isMe ? Color.clear : Color.appCardBorder, lineWidth: 1)
                    )
            }

            if !isMe { Spacer(minLength: 40) }
        }
    }
}

