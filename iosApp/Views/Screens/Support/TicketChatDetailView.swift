import SwiftUI

// MARK: - MÀN HÌNH CHI TIẾT TICKET & CHAT TRỰC TIẾP (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct TicketChatDetailView: View {
    @ObservedObject var viewModel: SupportViewModel
    var ticket: SupportTicket
    var onBack: () -> Void

    @State private var inputText: String = ""
    @State private var showCloseTicketAlert: Bool = false
    @State private var closeNote: String = ""

    public init(viewModel: SupportViewModel, ticket: SupportTicket, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.ticket = ticket
        self.onBack = onBack
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. TOP BAR
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(ticket.subject.isEmpty ? "Chi tiết sự cố" : ticket.subject)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("#\(ticket.id.prefix(8).uppercased()) • \(ticket.creatorName)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Nút Đóng / Hoàn tất ticket
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
                .padding(.vertical, 12)
                .background(Color.appTopBarColor)

                // 2. THÔNG TIN SỰ CỐ TÓM TẮT & NÚT TIẾP NHẬN
                VStack(spacing: 8) {
                    HStack {
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
                }
                .padding(12)
                .background(Color.white)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .bottom)

                // 3. DANH SÁCH TIN NHẮN CHAT
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

                // 4. KHUNG NHẬP TIN NHẮN (CHAT INPUT BAR)
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
        .onAppear {
            viewModel.fetchMessages(for: ticket.id)
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
    }

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
