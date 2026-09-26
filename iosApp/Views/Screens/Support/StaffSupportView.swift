import SwiftUI

// MARK: - MÀN HÌNH YÊU CẦU HỖ TRỢ CHO NHÂN VIÊN (ĐỒNG BỘ THEO STAFFSUPPORTSCREEN.KT TRÊN ANDROID)
public struct StaffSupportView: View {
    @ObservedObject var viewModel: AuthViewModel
    @ObservedObject var supportVM: SupportViewModel
    var onBack: () -> Void
    var onSelectTicket: (SupportTicket) -> Void
    var onOpenRatingReport: () -> Void

    @State private var currentTab: Int = 0 // 0: Ticket của tôi, 1: Tạo mới

    // Form fields for create
    @State private var subject: String = ""
    @State private var description: String = ""
    @State private var priority: String = "NORMAL"
    @State private var deviceId: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccessAlert: Bool = false

    public init(
        viewModel: AuthViewModel,
        supportVM: SupportViewModel,
        onBack: @escaping () -> Void,
        onSelectTicket: @escaping (SupportTicket) -> Void,
        onOpenRatingReport: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.supportVM = supportVM
        self.onBack = onBack
        self.onSelectTicket = onSelectTicket
        self.onOpenRatingReport = onOpenRatingReport
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Hỗ trợ CNTT")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. TABS
                    HStack(spacing: 0) {
                        tabButton(title: "Yêu cầu của tôi", index: 0)
                        tabButton(title: "Tạo yêu cầu mới", index: 1)
                    }
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 3)
                    .zIndex(1)

                    // 3. CONTENT
                    if currentTab == 0 {
                        myTicketsTab
                    } else {
                        createTicketTab
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if supportVM.myTickets.isEmpty {
                Task {
                    await supportVM.fetchMyTickets()
                }
            }
        }
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("Thành công"),
                message: Text("Đã gửi yêu cầu hỗ trợ thành công. Kỹ thuật viên sẽ liên hệ với bạn trong thời gian sớm nhất."),
                dismissButton: .default(Text("OK")) {
                    currentTab = 0
                    Task {
                        await supportVM.fetchMyTickets()
                    }
                }
            )
        }
    }

    // MARK: - MY TICKETS TAB
    private var myTicketsTab: some View {
        VStack {
            if supportVM.isLoading {
                Spacer()
                ProgressView("Đang tải dữ liệu...")
                Spacer()
            } else if supportVM.myTickets.isEmpty {
                Spacer()
                Image(systemName: "tray.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.appTextSecondary.opacity(0.5))
                Text("Bạn chưa có yêu cầu hỗ trợ nào")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                    .padding(.top, 8)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(supportVM.myTickets) { ticket in
                            Button(action: { onSelectTicket(ticket) }) {
                                ticketCard(ticket)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func ticketCard(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.subject.isEmpty ? "Sự cố thiết bị" : ticket.subject)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                        .lineLimit(2)
                    Text("Mã phiếu: #\(ticket.id.prefix(8).uppercased())")
                        .font(.system(size: 12))
                        .foregroundColor(.appTextSecondary)
                }
                Spacer()
                priorityBadge(ticket.priority)
            }

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ticket.isOpen ? Color.appWarning : Color.appSuccess)
                        .frame(width: 8, height: 8)
                    Text(ticket.isOpen ? "Đang xử lý" : "Đã hoàn tất")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ticket.isOpen ? Color.appWarning : Color.appSuccess)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.appTextSecondary)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func priorityBadge(_ priority: String) -> some View {
        let isUrgent = priority.uppercased() == "URGENT"
        let isHigh = priority.uppercased() == "HIGH"
        let color = isUrgent ? Color.appDanger : (isHigh ? Color.appWarning : Color.appInfo)
        let text = isUrgent ? "Khẩn cấp" : (isHigh ? "Ưu tiên cao" : "Thường")

        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - CREATE TICKET TAB
    private var createTicketTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Mô tả sự cố bạn đang gặp phải để bộ phận IT hỗ trợ kịp thời.")
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tiêu đề sự cố *")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    TextField("VD: Máy tính không lên nguồn", text: $subject)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mô tả chi tiết *")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    TextEditor(text: $description)
                        .font(.system(size: 14))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Độ ưu tiên")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    Picker("Độ ưu tiên", selection: $priority) {
                        Text("Bình thường").tag("NORMAL")
                        Text("Ưu tiên cao").tag("HIGH")
                        Text("Khẩn cấp").tag("URGENT")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mã thiết bị liên quan (Tùy chọn)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                    TextField("Nhập mã thiết bị nếu có", text: $deviceId)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }

                Spacer().frame(height: 16)

                Button(action: submitTicket) {
                    HStack {
                        if isSubmitting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Gửi yêu cầu")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(subject.isEmpty || description.isEmpty || isSubmitting ? Color.gray : Color.appPrimaryPink)
                    .cornerRadius(10)
                }
                .disabled(subject.isEmpty || description.isEmpty || isSubmitting)
            }
            .padding(16)
        }
    }

    private func submitTicket() {
        guard !subject.isEmpty && !description.isEmpty else { return }
        isSubmitting = true
        Task {
            let result = await supportVM.createTicket(
                subject: subject,
                description: description,
                priority: priority,
                deviceId: deviceId.isEmpty ? nil : deviceId
            )
            await MainActor.run {
                isSubmitting = false
                if result != nil {
                    // Reset form
                    subject = ""
                    description = ""
                    priority = "NORMAL"
                    deviceId = ""
                    showSuccessAlert = true
                }
            }
        }
    }

    // MARK: - TAB BUTTON
    private func tabButton(title: String, index: Int) -> some View {
        let isSelected = currentTab == index
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentTab = index
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .appPrimaryPink : .appTextSecondary)
                    .padding(.top, 12)
                
                Rectangle()
                    .fill(isSelected ? Color.appPrimaryPink : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
