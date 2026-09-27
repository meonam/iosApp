import SwiftUI

// MARK: - MÀN HÌNH HỖ TRỢ KỸ THUẬT DÀNH CHO NHÂN VIÊN (ĐỒNG BỘ 1:1 VỚI STAFFSUPPORTSCREEN.KT TRÊN ANDROID)
public struct StaffSupportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void

    @State private var tickets: [SupportTicket] = []
    @State private var isLoading = false
    @State private var showingCreateSheet = false
    @State private var selectedStatus: String = "ALL" // "ALL", "OPEN", "CLOSED"
    @State private var selectedTicketForChat: SupportTicket? = nil

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }

    private var openCount: Int {
        tickets.filter { $0.isOpen && $0.closedAt <= 0 }.count
    }

    private var closedCount: Int {
        tickets.filter { !$0.isOpen || $0.closedAt > 0 }.count
    }

    private var filteredTickets: [SupportTicket] {
        if selectedStatus == "ALL" { return tickets }
        if selectedStatus == "OPEN" {
            return tickets.filter { $0.isOpen && $0.closedAt <= 0 }
        }
        return tickets.filter { !$0.isOpen || $0.closedAt > 0 }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .font(.system(size: 17, weight: .bold))
                            }

                            Text("Yêu cầu hỗ trợ của tôi")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { showingCreateSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                    Text("Tạo mới")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // STATUS TABS (Tất cả, Đang mở, Đã đóng)
                    HStack(spacing: 8) {
                        statusTabButton(title: "Tất cả", count: tickets.count, tag: "ALL")
                        statusTabButton(title: "Đang mở", count: openCount, tag: "OPEN", activeColor: Color(hex: "#16A34A"), activeBg: Color(hex: "#DCFCE7"))
                        statusTabButton(title: "Đã đóng", count: closedCount, tag: "CLOSED")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    // TICKETS LIST
                    if isLoading && tickets.isEmpty {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                            .font(.system(size: 14))
                        Spacer()
                    } else if filteredTickets.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color.appTextSecondary.opacity(0.5))
                            Text("Chưa có yêu cầu hỗ trợ nào trong mục này")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredTickets) { ticket in
                                    ticketRow(ticket)
                                        .onTapGesture {
                                            selectedTicketForChat = ticket
                                        }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                        }
                        .refreshable {
                            await fetchTicketsAsync()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            fetchTickets()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateTicketView(authViewModel: authViewModel) {
                fetchTickets()
                showingCreateSheet = false
            } onCancel: {
                showingCreateSheet = false
            }
        }
        .sheet(item: $selectedTicketForChat) { ticket in
            if let user = authViewModel.currentUser {
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
        }
    }

    private func statusTabButton(title: String, count: Int, tag: String, activeColor: Color = Color.appSecondaryDarkBlue, activeBg: Color = Color.white) -> some View {
        let isSelected = selectedStatus == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedStatus = tag
            }
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                Text("(\(count))")
                    .font(.system(size: 11, weight: isSelected ? .bold : .regular))
            }
            .foregroundColor(isSelected ? activeColor : Color.gray)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(isSelected ? activeBg : Color(hex: "#F1F5F9"))
            .cornerRadius(8)
            .shadow(color: isSelected ? Color.black.opacity(0.05) : Color.clear, radius: 2, y: 1)
        }
    }

    private func ticketRow(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.subject.isEmpty ? "Sự cố thiết bị" : ticket.subject)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(2)

                    Text("Mã phiếu: #\(ticket.id.prefix(8).uppercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Spacer()

                priorityBadge(ticket.priority)
            }

            if !ticket.initialMessage.isEmpty {
                Text(ticket.initialMessage)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
            }

            Divider()

            HStack {
                // Trạng thái phiếu
                HStack(spacing: 5) {
                    Circle()
                        .fill(ticket.isOpen ? Color.appWarning : Color.appSuccess)
                        .frame(width: 8, height: 8)

                    Text(ticket.isOpen ? (ticket.isAcknowledged ? "Đang xử lý" : "Chờ tiếp nhận") : "Đã hoàn thành")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ticket.isOpen ? (ticket.isAcknowledged ? Color.appInfo : Color.appWarning) : Color.appSuccess)
                }

                Spacer()

                if ticket.createdAt > 0 {
                    Text(formatDate(ticket.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextSecondary.opacity(0.6))
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
    }

    private func priorityBadge(_ priority: String) -> some View {
        let p = priority.uppercased()
        let color: Color
        let label: String
        switch p {
        case "URGENT":
            color = .appDanger
            label = "Khẩn cấp"
        case "HIGH":
            color = .appWarning
            label = "Ưu tiên cao"
        default:
            color = .appInfo
            label = "Bình thường"
        }

        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func formatDate(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }

    private func fetchTickets() {
        Task { await fetchTicketsAsync() }
    }

    // MARK: - QUERY TICKETS VIA RUNQUERY (ĐỒNG BỘ CHUẨN ANDROID)
    private func fetchTicketsAsync() async {
        let companyId = authViewModel.currentUser?.companyId ?? authViewModel.currentCompanyId
        let token = authViewModel.currentIdToken
        let userEmail = (authViewModel.currentUser?.email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let userId = (authViewModel.currentUser?.id ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !companyId.isEmpty, !token.isEmpty, (!userEmail.isEmpty || !userId.isEmpty) else { return }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId):runQuery"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let queryPayload: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "support_tickets"]],
                "orderBy": [
                    ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
                ],
                "limit": 200
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else { return }
        request.httpBody = bodyData

        DispatchQueue.main.async { isLoading = true }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    var loadedTickets: [SupportTicket] = []

                    for item in results {
                        guard let doc = item["document"] as? [String: Any],
                              let fields = doc["fields"] as? [String: Any],
                              let name = doc["name"] as? String else { continue }

                        let cEmail = FirestoreHelper.getString(fields["creatorEmail"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let cId = FirestoreHelper.getString(fields["creatorUserId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let altCId = FirestoreHelper.getString(fields["creatorId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                        // Kiểm tra quyền sở hữu vé của nhân viên
                        let isMine = (!userEmail.isEmpty && cEmail == userEmail) ||
                                     (!userId.isEmpty && (cId == userId || altCId == userId))
                        if !isMine { continue }

                        let docId = name.components(separatedBy: "/").last ?? ""
                        let subject = FirestoreHelper.getString(fields["subject"] as? [String: Any]).isEmpty
                            ? FirestoreHelper.getString(fields["title"] as? [String: Any])
                            : FirestoreHelper.getString(fields["subject"] as? [String: Any])
                        let initialMessage = FirestoreHelper.getString(fields["initialMessage"] as? [String: Any]).isEmpty
                            ? FirestoreHelper.getString(fields["description"] as? [String: Any])
                            : FirestoreHelper.getString(fields["initialMessage"] as? [String: Any])

                        let ticket = SupportTicket(
                            id: docId,
                            creatorEmail: cEmail,
                            creatorName: FirestoreHelper.getString(fields["creatorName"] as? [String: Any]),
                            creatorPhone: FirestoreHelper.getString(fields["creatorPhone"] as? [String: Any]),
                            creatorUserId: cId,
                            subject: subject,
                            status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                            category: FirestoreHelper.getString(fields["category"] as? [String: Any]),
                            priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                            assetId: FirestoreHelper.getString(fields["assetId"] as? [String: Any]),
                            assetName: FirestoreHelper.getString(fields["assetName"] as? [String: Any]),
                            createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                            lastMessage: FirestoreHelper.getString(fields["lastMessage"] as? [String: Any]),
                            lastMessageAt: FirestoreHelper.getInt64(fields["lastMessageAt"] as? [String: Any]),
                            companyId: companyId,
                            donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                            initialMessage: initialMessage,
                            assignedToName: FirestoreHelper.getString(fields["assignedToName"] as? [String: Any]),
                            isAcknowledged: FirestoreHelper.getBool(fields["isAcknowledged"] as? [String: Any]),
                            closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any])
                        )
                        loadedTickets.append(ticket)
                    }

                    DispatchQueue.main.async {
                        self.tickets = loadedTickets.sorted { $0.createdAt > $1.createdAt }
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.tickets = []
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        } catch {
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
}

// MARK: - FORM TẠO YÊU CẦU HỖ TRỢ MỚI (ĐỒNG BỘ 1:1 FIRESTORE VỚI ANDROID)
struct CreateTicketView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @State private var subject = ""
    @State private var initialMessage = ""
    @State private var priority = "NORMAL"
    @State private var category = "HARDWARE"
    @State private var isSubmitting = false

    let priorities = ["NORMAL", "HIGH", "URGENT"]
    let categories = [
        ("HARDWARE", "Phần cứng / Máy móc"),
        ("SOFTWARE", "Phần mềm / Ứng dụng"),
        ("NETWORK", "Mạng / Đường truyền"),
        ("OTHER", "Vấn đề khác")
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Nội dung sự cố")) {
                    TextField("Tiêu đề sự cố / Thiết bị (bắt buộc)", text: $subject)
                        .font(.system(size: 14.5))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mô tả chi tiết sự cố:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        TextEditor(text: $initialMessage)
                            .frame(minHeight: 100)
                            .font(.system(size: 14))
                    }
                }

                Section(header: Text("Phân loại & Mức độ ưu tiên")) {
                    Picker("Danh mục", selection: $category) {
                        ForEach(categories, id: \.0) { cat in
                            Text(cat.1).tag(cat.0)
                        }
                    }

                    Picker("Mức độ", selection: $priority) {
                        Text("Bình thường").tag("NORMAL")
                        Text("Ưu tiên cao").tag("HIGH")
                        Text("Khẩn cấp").tag("URGENT")
                    }
                }

                Section(footer: Text("Yêu cầu sẽ được chuyển tới bộ phận kỹ thuật để tiếp nhận và hỗ trợ kịp thời.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Tạo yêu cầu hỗ trợ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy", action: onCancel),
                trailing: Button("Gửi yêu cầu") {
                    submitTicket()
                }
                .font(.system(size: 15, weight: .bold))
                .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          initialMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          isSubmitting)
            )
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Đang gửi yêu cầu...").tint(.white).foregroundColor(.white)
                }
            }
        }
    }

    private func submitTicket() {
        let user = authViewModel.currentUser
        let companyId = user?.companyId ?? authViewModel.currentCompanyId
        let token = authViewModel.currentIdToken

        guard !companyId.isEmpty, !token.isEmpty else { return }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets"
        guard let url = URL(string: urlStr) else { return }

        isSubmitting = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDesc = initialMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = user?.email ?? ""
        let fullName = (user?.fullName.isEmpty ?? true) ? email : (user?.fullName ?? "")

        let body: [String: Any] = [
            "fields": [
                "subject": ["stringValue": cleanSubject],
                "title": ["stringValue": cleanSubject],
                "initialMessage": ["stringValue": cleanDesc],
                "description": ["stringValue": cleanDesc],
                "status": ["stringValue": "OPEN"],
                "priority": ["stringValue": priority],
                "category": ["stringValue": category],
                "creatorEmail": ["stringValue": email],
                "creatorUserId": ["stringValue": user?.id ?? ""],
                "creatorId": ["stringValue": user?.id ?? ""],
                "creatorName": ["stringValue": fullName],
                "donVi": ["stringValue": user?.donVi ?? ""],
                "departmentId": ["stringValue": user?.departmentId ?? ""],
                "companyId": ["stringValue": companyId],
                "createdAt": ["integerValue": "\(now)"],
                "updatedAt": ["integerValue": "\(now)"]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                        self.onSuccess()
                    }
                }
            } catch {
                DispatchQueue.main.async { self.isSubmitting = false }
            }
        }
    }
}
