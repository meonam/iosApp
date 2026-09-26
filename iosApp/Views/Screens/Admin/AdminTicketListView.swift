import SwiftUI

public struct AdminTicketListView: View {
    @StateObject var viewModel: SupportViewModel
    var onBack: () -> Void
    var onTicketClick: (String, String) -> Void

    @State private var filterStatus: String = "ALL" // ALL, OPEN, PENDING, ASSIGNED, CLOSED
    @State private var filterPriority: String = "ALL" // ALL, URGENT, HIGH, NORMAL
    @State private var searchQuery: String = ""
    @State private var sortOption: String = "newest" // newest, oldest, priority, sla

    public init(viewModel: SupportViewModel, onBack: @escaping () -> Void, onTicketClick: @escaping (String, String) -> Void) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onBack = onBack
        self.onTicketClick = onTicketClick
    }

    private var filteredAndSortedTickets: [SupportTicket] {
        // 1. Filter
        var list = viewModel.rawTickets.filter { t in
            // Status
            var matchStatus = true
            switch filterStatus {
            case "OPEN": matchStatus = t.isOpen
            case "CLOSED": matchStatus = !t.isOpen
            case "PENDING": matchStatus = t.isOpen && t.assignedToEmail.isEmpty
            case "ASSIGNED": matchStatus = t.isOpen && !t.assignedToEmail.isEmpty
            default: matchStatus = true
            }

            // Priority
            var matchPriority = true
            if filterPriority != "ALL" {
                matchPriority = t.priority.uppercased() == filterPriority
            }

            // Search
            var matchSearch = true
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                matchSearch = t.subject.lowercased().contains(q) ||
                              t.creatorName.lowercased().contains(q) ||
                              t.creatorEmail.lowercased().contains(q) ||
                              t.id.lowercased().contains(q)
            }

            return matchStatus && matchPriority && matchSearch
        }

        // 2. Sort
        list.sort { a, b in
            switch sortOption {
            case "oldest":
                return a.createdAt < b.createdAt
            case "priority":
                return priorityWeight(a.priority) > priorityWeight(b.priority)
            case "sla":
                return getDeadline(a) < getDeadline(b)
            case "newest":
                fallthrough
            default:
                return a.createdAt > b.createdAt
            }
        }

        return list
    }

    private func priorityWeight(_ p: String) -> Int {
        switch p.uppercased() {
        case "URGENT": return 3
        case "HIGH": return 2
        default: return 1
        }
    }

    private func getDeadline(_ t: SupportTicket) -> Int64 {
        let limitHours: Int64 = t.priority.uppercased() == "URGENT" ? 1 : (t.priority.uppercased() == "HIGH" ? 4 : 24)
        return t.createdAt + (limitHours * 3600 * 1000)
    }

    private func isOverdue(_ t: SupportTicket) -> Bool {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        return t.isOpen && now > getDeadline(t)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    topBar(geometry: geometry)

                    // STATS BAR
                    statsBar

                    // SEARCH & FILTERS
                    searchAndFilters

                    // LIST
                    ticketList
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.rawTickets.isEmpty {
                viewModel.fetchTickets()
            }
        }
    }

    private func topBar(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: geometry.safeAreaInsets.top)
            
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Quản lý Yêu cầu (\(viewModel.rawTickets.count))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { viewModel.fetchTickets() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appPrimary)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 10) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Tìm theo tiêu đề, người tạo...", text: $searchQuery)
                    .font(.system(size: 14))
                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            
            // Status Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Tất cả", value: "ALL", current: $filterStatus)
                    filterChip(title: "Đang mở", value: "OPEN", current: $filterStatus)
                    filterChip(title: "Chờ phân công", value: "PENDING", current: $filterStatus)
                    filterChip(title: "Đã phân công", value: "ASSIGNED", current: $filterStatus)
                    filterChip(title: "Đã đóng", value: "CLOSED", current: $filterStatus)
                }
            }

            // Priority & Sort
            HStack {
                Picker("Độ ưu tiên", selection: $filterPriority) {
                    Text("Mọi ưu tiên").tag("ALL")
                    Text("Khẩn cấp").tag("URGENT")
                    Text("Cao").tag("HIGH")
                    Text("Bình thường").tag("NORMAL")
                }
                .pickerStyle(MenuPickerStyle())
                .font(.system(size: 13))
                .padding(6)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                Spacer()

                Picker("Sắp xếp", selection: $sortOption) {
                    Text("Mới nhất").tag("newest")
                    Text("Cũ nhất").tag("oldest")
                    Text("Độ ưu tiên").tag("priority")
                    Text("Hạn xử lý (SLA)").tag("sla")
                }
                .pickerStyle(MenuPickerStyle())
                .font(.system(size: 13))
                .padding(6)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var ticketList: some View {
        Group {
            if viewModel.isLoading && viewModel.rawTickets.isEmpty {
                Spacer()
                ProgressView("Đang tải dữ liệu...")
                Spacer()
            } else if filteredAndSortedTickets.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Không tìm thấy yêu cầu nào.")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAndSortedTickets) { ticket in
                            ticketCard(ticket)
                                .onTapGesture {
                                    onTicketClick(ticket.id, ticket.subject)
                                }
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var statsBar: some View {
        let total = viewModel.rawTickets.count
        let open = viewModel.rawTickets.filter { $0.isOpen }.count
        let overdue = viewModel.rawTickets.filter { isOverdue($0) }.count

        return HStack(spacing: 0) {
            statItem(title: "Tổng", value: "\(total)", color: .primary)
            Divider().frame(height: 30)
            statItem(title: "Đang xử lý", value: "\(open)", color: .blue)
            Divider().frame(height: 30)
            statItem(title: "Quá hạn SLA", value: "\(overdue)", color: .red)
        }
        .padding(.vertical, 8)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func filterChip(title: String, value: String, current: Binding<String>) -> some View {
        let isSel = current.wrappedValue == value
        return Button(action: { current.wrappedValue = value }) {
            Text(title)
                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSel ? Color.appPrimary : Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }

    private func ticketCard(_ t: SupportTicket) -> some View {
        let overdue = isOverdue(t)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                // Priority Indicator
                Circle()
                    .fill(t.priority.uppercased() == "URGENT" ? Color.red : (t.priority.uppercased() == "HIGH" ? Color.orange : Color.green))
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(t.subject)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(2)
                    
                    Text("Người tạo: \(t.creatorName.isEmpty ? t.creatorEmail : t.creatorName)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Status Badge
                Text(t.isOpen ? (t.assignedToEmail.isEmpty ? "CHỜ PHÂN CÔNG" : "ĐANG XỬ LÝ") : "ĐÃ ĐÓNG")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(t.isOpen ? (t.assignedToEmail.isEmpty ? Color.orange : Color.blue) : Color.gray)
                    .cornerRadius(4)
            }

            Divider()

            HStack {
                // Time
                let dateStr = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(t.createdAt) / 1000.0))
                Label(dateStr, systemImage: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer()

                // Assignee
                if !t.assignedToEmail.isEmpty {
                    Label(t.assignedToName.isEmpty ? t.assignedToEmail : t.assignedToName, systemImage: "person.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.appPrimary)
                        .lineLimit(1)
                }
            }

            if overdue {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("Quá hạn SLA")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.red)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(overdue ? Color.red : Color.gray.opacity(0.2), lineWidth: overdue ? 1 : 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy HH:mm"
        return df
    }
}
