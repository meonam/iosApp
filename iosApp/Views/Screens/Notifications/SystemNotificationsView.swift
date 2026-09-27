import SwiftUI

public struct SystemNotificationsView: View {
    var companyId: String
    var idToken: String
    var userEmail: String
    var onBack: () -> Void

    @State private var notifications: [SysNotification] = []
    @State private var isLoading: Bool = true
    @State private var selectedFilter: NotifFilter = .all

    enum NotifFilter: String, CaseIterable {
        case all = "Tất cả"
        case ticket = "Ticket"
        case attendance = "Chấm công"
        case device = "Thiết bị"
        case system = "Hệ thống"
        
        var matchType: String {
            switch self {
            case .all: return ""
            case .ticket: return "TICKET"
            case .attendance: return "ATTENDANCE"
            case .device: return "DEVICE"
            case .system: return "SYSTEM"
            }
        }
    }

    struct SysNotification: Identifiable {
        let id: String
        let title: String
        let body: String
        let type: String
        var isRead: Bool
        let createdAt: Int64
        let userId: String
    }

    public init(companyId: String = "", idToken: String = "", userEmail: String = "", onBack: @escaping () -> Void = {}) {
        self.companyId = companyId
        self.idToken = idToken
        self.userEmail = userEmail
        self.onBack = onBack
    }

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void = {}) {
        self.companyId = authViewModel.currentUser?.companyId ?? ""
        self.idToken = authViewModel.currentIdToken
        self.userEmail = authViewModel.currentUser?.email ?? ""
        self.onBack = onBack
    }

    public init(onBack: @escaping () -> Void = {}) {
        self.companyId = ""
        self.idToken = ""
        self.userEmail = ""
        self.onBack = onBack
    }

    private var filteredNotifs: [SysNotification] {
        if selectedFilter == .all { return notifications }
        return notifications.filter { $0.type.uppercased() == selectedFilter.matchType }
    }

    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    private var groupedNotifs: [(String, [SysNotification])] {
        let calendar = Calendar.current
        var groups: [String: [SysNotification]] = [:]
        
        for notif in filteredNotifs {
            let date = Date(timeIntervalSince1970: TimeInterval(notif.createdAt) / 1000.0)
            let key: String
            if calendar.isDateInToday(date) {
                key = "Hôm nay"
            } else if calendar.isDateInYesterday(date) {
                key = "Hôm qua"
            } else {
                let diff = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
                if diff <= 7 {
                    key = "Tuần này"
                } else {
                    key = "Cũ hơn"
                }
            }
            groups[key, default: []].append(notif)
        }
        
        let order = ["Hôm nay", "Hôm qua", "Tuần này", "Cũ hơn"]
        return order.compactMap { key in
            if let list = groups[key] {
                return (key, list.sorted(by: { $0.createdAt > $1.createdAt }))
            }
            return nil
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            Text("Thông báo hệ thống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            if unreadCount > 0 {
                                Text("\(unreadCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.appPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                            Spacer()
                            
                            Menu {
                                Button(action: markAllAsRead) {
                                    Label("Đánh dấu đã đọc tất cả", systemImage: "checkmark.circle.fill")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .background(Color.appPrimary)

                    // Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(NotifFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.appPrimary : Color.white)
                                    .foregroundColor(selectedFilter == filter ? .white : .appTextPrimary)
                                    .cornerRadius(20)
                                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appPrimary.opacity(0.3), lineWidth: 1))
                                    .onTapGesture {
                                        withAnimation { selectedFilter = filter }
                                    }
                            }
                        }
                        .padding(14)
                    }
                    .background(Color.appBackground)

                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải thông báo...")
                        Spacer()
                    } else if filteredNotifs.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Không có thông báo nào")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(groupedNotifs, id: \.0) { group in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(group.0)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 16)
                                        
                                        ForEach(group.1) { notif in
                                            notifCard(notif)
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .refreshable {
                            await fetchNotifications()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                Task {
                    await fetchNotifications()
                }
            }
        }
    }

    private func notifCard(_ notif: SysNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor(type: notif.type).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName(type: notif.type))
                    .font(.system(size: 20))
                    .foregroundColor(iconColor(type: notif.type))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notif.title)
                        .font(.system(size: 15, weight: notif.isRead ? .regular : .bold))
                        .foregroundColor(notif.isRead ? .appTextPrimary : .black)
                    Spacer()
                    if !notif.isRead {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                    }
                }
                Text(notif.body)
                    .font(.system(size: 13))
                    .foregroundColor(.appTextSecondary)
                    .lineLimit(2)
                
                HStack {
                    Text(formatTime(notif.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                    Button(action: { deleteNotification(notif.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .onTapGesture {
            if !notif.isRead {
                markAsRead(notif.id)
            }
        }
    }

    private func iconName(type: String) -> String {
        switch type.uppercased() {
        case "TICKET": return "ticket"
        case "ATTENDANCE": return "calendar.badge.clock"
        case "DEVICE": return "desktopcomputer"
        case "SYSTEM": return "gearshape.fill"
        default: return "bell.fill"
        }
    }

    private func iconColor(type: String) -> Color {
        switch type.uppercased() {
        case "TICKET": return .blue
        case "ATTENDANCE": return .green
        case "DEVICE": return .purple
        case "SYSTEM": return .orange
        default: return .appPrimary
        }
    }
    
    private func formatTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let df = DateFormatter()
        df.dateFormat = "HH:mm dd/MM/yyyy"
        return df.string(from: date)
    }

    private func fetchNotifications() async {
        await MainActor.run { isLoading = true }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/notifications"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = json["documents"] as? [[String: Any]] {
                    
                    var loaded: [SysNotification] = []
                    let myUserId = userEmail
                    
                    for doc in documents {
                        guard let fields = doc["fields"] as? [String: Any] else { continue }
                        let nType = FirestoreHelper.getString(fields["type"] as? [String: Any])
                        let uId = FirestoreHelper.getString(fields["userId"] as? [String: Any])
                        
                        // Filter: userId == currentUserId OR isGlobal (userId == "")
                        if uId.isEmpty || uId.lowercased() == myUserId.lowercased() {
                            let docName = doc["name"] as? String ?? ""
                            let id = docName.components(separatedBy: "/").last ?? ""
                            loaded.append(SysNotification(
                                id: id,
                                title: FirestoreHelper.getString(fields["title"] as? [String: Any]),
                                body: FirestoreHelper.getString(fields["body"] as? [String: Any]),
                                type: nType.isEmpty ? "SYSTEM" : nType,
                                isRead: FirestoreHelper.getBool(fields["isRead"] as? [String: Any]),
                                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                                userId: uId
                            ))
                        }
                    }
                    loaded.sort { $0.createdAt > $1.createdAt }
                    await MainActor.run {
                        self.notifications = loaded
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func markAsRead(_ id: String) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
        }
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/notifications/\(id)?updateMask.fieldPaths=isRead"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "isRead": ["booleanValue": true]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        Task {
            let _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func markAllAsRead() {
        let unreadIds = notifications.filter { !$0.isRead }.map { $0.id }
        for id in unreadIds {
            markAsRead(id)
        }
    }

    private func deleteNotification(_ id: String) {
        notifications.removeAll { $0.id == id }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/notifications/\(id)"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        
        Task {
            let _ = try? await URLSession.shared.data(for: request)
        }
    }
}
