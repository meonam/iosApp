import SwiftUI

struct StaffTicket: Identifiable {
    let id: String
    var title: String
    var description: String
    var status: String
    var priority: String
    var category: String
    var creatorId: String
    var createdAt: Int64
}

public struct StaffSupportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    
    @State private var tickets: [StaffTicket] = []
    @State private var isLoading = false
    @State private var showingCreateSheet = false
    @State private var selectedStatus: String = "ALL"
    let statuses = ["ALL", "OPEN", "IN_PROGRESS", "CLOSED"]
    
    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appPrimary)
                    
                    statusPicker
                        .padding()
                    
                    if isLoading && tickets.isEmpty {
                        Spacer()
                        ProgressView("Đang tải...")
                        Spacer()
                    } else if filteredTickets.isEmpty {
                        Spacer()
                        Text("Không có yêu cầu hỗ trợ nào.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredTickets) { ticket in
                                ticketRow(ticket)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
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
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            Spacer()
            Text("Hỗ trợ (Staff)")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { showingCreateSheet = true }) {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    private var statusPicker: some View {
        Picker("Trạng thái", selection: $selectedStatus) {
            ForEach(statuses, id: \.self) { status in
                Text(status == "ALL" ? "Tất cả" : (status == "OPEN" ? "Mở" : (status == "IN_PROGRESS" ? "Đang xử lý" : "Đã đóng"))).tag(status)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var filteredTickets: [StaffTicket] {
        if selectedStatus == "ALL" { return tickets }
        return tickets.filter { $0.status == selectedStatus }
    }
    
    private func ticketRow(_ ticket: StaffTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.title)
                    .font(.headline)
                Spacer()
                Text(ticket.status)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(ticket.status).opacity(0.2))
                    .foregroundColor(statusColor(ticket.status))
                    .cornerRadius(8)
            }
            Text(ticket.description)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            HStack {
                Text(ticket.priority)
                    .font(.caption2)
                    .padding(4)
                    .background(priorityColor(ticket.priority).opacity(0.2))
                    .foregroundColor(priorityColor(ticket.priority))
                    .cornerRadius(4)
                Spacer()
                Text(formatDate(ticket.createdAt))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
    
    private func fetchTickets() {
        Task { await fetchTicketsAsync() }
    }
    
    private func fetchTicketsAsync() async {
        let companyId = authViewModel.currentUser?.companyId ?? ""
        let token = authViewModel.currentIdToken ?? ""
        let userId = authViewModel.currentUser?.id ?? ""
        guard !companyId.isEmpty, !token.isEmpty, !userId.isEmpty else { return }
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        DispatchQueue.main.async { isLoading = true }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {
                    var loadedTickets: [StaffTicket] = []
                    for doc in docs {
                        if let fields = doc["fields"] as? [String: Any] {
                            let cId = FirestoreHelper.getString(fields["creatorId"] as? [String: Any])
                            if cId == userId {
                                let docName = doc["name"] as? String ?? ""
                                let docId = docName.components(separatedBy: "/").last ?? ""
                                let ticket = StaffTicket(
                                    id: docId,
                                    title: FirestoreHelper.getString(fields["title"] as? [String: Any]),
                                    description: FirestoreHelper.getString(fields["description"] as? [String: Any]),
                                    status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                                    priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                                    category: FirestoreHelper.getString(fields["category"] as? [String: Any]),
                                    creatorId: cId,
                                    createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any])
                                )
                                loadedTickets.append(ticket)
                            }
                        }
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
    
    private func statusColor(_ status: String) -> Color {
        switch status {
        case "OPEN": return .blue
        case "IN_PROGRESS": return .orange
        case "CLOSED": return .gray
        default: return .black
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority {
        case "URGENT": return .red
        case "HIGH": return .orange
        case "NORMAL": return .green
        default: return .gray
        }
    }
    
    private func formatDate(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f.string(from: date)
    }
}

struct CreateTicketView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onSuccess: () -> Void
    var onCancel: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var priority = "NORMAL"
    @State private var category = "IT"
    @State private var isSubmitting = false
    
    let priorities = ["NORMAL", "HIGH", "URGENT"]
    let categories = ["IT", "HR", "ADMIN", "OTHER"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin chung")) {
                    TextField("Tiêu đề", text: $title)
                    Picker("Danh mục", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Mức độ", selection: $priority) {
                        ForEach(priorities, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section(header: Text("Mô tả chi tiết")) {
                    TextEditor(text: $description)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Tạo yêu cầu mới")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy", action: onCancel),
                trailing: Button("Lưu") {
                    submitTicket()
                }
                .disabled(title.isEmpty || description.isEmpty || isSubmitting)
            )
            .overlay {
                if isSubmitting {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView().tint(.white)
                }
            }
        }
    }
    
    private func submitTicket() {
        let companyId = authViewModel.currentUser?.companyId ?? ""
        let token = authViewModel.currentIdToken ?? ""
        let userId = authViewModel.currentUser?.id ?? ""
        let userName = authViewModel.currentUser?.fullName ?? ""
        
        guard !companyId.isEmpty, !token.isEmpty else { return }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets"
        guard let url = URL(string: urlStr) else { return }
        
        isSubmitting = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "title": ["stringValue": title],
                "description": ["stringValue": description],
                "status": ["stringValue": "OPEN"],
                "priority": ["stringValue": priority],
                "category": ["stringValue": category],
                "creatorId": ["stringValue": userId],
                "creatorName": ["stringValue": userName],
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
