import SwiftUI

// MARK: - SUPPORT VIEW MODEL (ĐỒNG BỘ 1:1 VỚI ADMINSUPPORTVIEWMODEL.KT TRÊN ANDROID)
@MainActor
public class SupportViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var rawTickets: [SupportTicket] = []
    @Published public var filterTab: String = "OPEN" // "OPEN", "CLOSED", "ALL"
    @Published public var searchQuery: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    // Chat realtime
    @Published public var currentTicket: SupportTicket? = nil
    @Published public var messages: [SupportMessage] = []
    @Published public var isSendingMessage: Bool = false

    // KTV Online Monitor (đồng bộ OnlineKtvMonitorScreen.kt)
    @Published public var ktvTechnicians: [KtvOnlineLocation] = []
    @Published public var isLoadingKtvs: Bool = false

    // MARK: - Rating Report KPIs
    @Published public var ktvStats: [KtvStat] = []
    @Published public var isLoadingStats: Bool = false

    public struct KtvStat: Identifiable {
        public var id: String { email }
        public var email: String
        public var name: String
        public var totalTickets: Int
        public var closedTickets: Int
        public var avgRating: Double
        public var avgResolutionHours: Double
        public var slaComplianceRate: Double
        
        public init(email: String, name: String, totalTickets: Int, closedTickets: Int, avgRating: Double, avgResolutionHours: Double, slaComplianceRate: Double) {
            self.email = email
            self.name = name
            self.totalTickets = totalTickets
            self.closedTickets = closedTickets
            self.avgRating = avgRating
            self.avgResolutionHours = avgResolutionHours
            self.slaComplianceRate = slaComplianceRate
        }
    }

    public func fetchKtvStats() async {
        await MainActor.run { isLoadingStats = true }
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets?pageSize=200"
        guard let url = URL(string: urlStr) else {
            await MainActor.run { isLoadingStats = false }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            await MainActor.run { isLoadingStats = false }
            return
        }

        var ticketsByKtv: [String: [SupportTicket]] = [:]
        
        for doc in documents {
            guard let fields = doc["fields"] as? [String: Any] else { continue }
            let status = FirestoreHelper.getString(fields["status"] as? [String: Any])
            guard status.uppercased() == "CLOSED" else { continue }
            
            let assignedEmail = FirestoreHelper.getString(fields["assignedToEmail"] as? [String: Any])
            guard !assignedEmail.isEmpty else { continue }
            
            let name = doc["name"] as? String ?? ""
            let id = name.components(separatedBy: "/").last ?? ""
            
            let t = SupportTicket(
                id: id,
                priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                rating: FirestoreHelper.getInt(fields["rating"] as? [String: Any]),
                assignedToEmail: assignedEmail,
                assignedToName: FirestoreHelper.getString(fields["assignedToName"] as? [String: Any]),
                closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any]),
                isAutoRated: FirestoreHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                isInvalid: FirestoreHelper.getBool(fields["isInvalid"] as? [String: Any])
            )
            
            ticketsByKtv[assignedEmail, default: []].append(t)
        }
        
        var stats: [KtvStat] = []
        for (email, tickets) in ticketsByKtv {
            let total = tickets.count
            let closed = tickets.count
            var name = tickets.first?.assignedToName ?? ""
            if name.isEmpty { name = email }
            
            var totalRating = 0.0
            var ratedCount = 0
            
            var totalHours = 0.0
            var resolvedCount = 0
            var withinSlaCount = 0
            
            for t in tickets {
                let rating = t.effectiveRating
                if rating > 0 {
                    totalRating += Double(rating)
                    ratedCount += 1
                }
                
                if t.closedAt > t.createdAt && t.createdAt > 0 {
                    let hours = Double(t.closedAt - t.createdAt) / (1000.0 * 60.0 * 60.0)
                    totalHours += hours
                    resolvedCount += 1
                    
                    let priority = t.priority.uppercased()
                    let slaLimit = (priority == "URGENT") ? 1.0 : (priority == "HIGH" ? 4.0 : 24.0)
                    if hours <= slaLimit {
                        withinSlaCount += 1
                    }
                }
            }
            
            let avgRating = ratedCount > 0 ? totalRating / Double(ratedCount) : 0.0
            let avgRes = resolvedCount > 0 ? totalHours / Double(resolvedCount) : 0.0
            let slaRate = total > 0 ? (Double(withinSlaCount) / Double(total)) * 100.0 : 0.0
            
            stats.append(KtvStat(email: email, name: name, totalTickets: total, closedTickets: closed, avgRating: avgRating, avgResolutionHours: avgRes, slaComplianceRate: slaRate))
        }
        
        let finalStats = stats.sorted { $0.avgRating > $1.avgRating }
        await MainActor.run {
            self.ktvStats = finalStats
            self.isLoadingStats = false
        }
    }

    @Published var myTickets: [SupportTicket] = []
    
    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
    }

    public var filteredTickets: [SupportTicket] {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isFull = user.isAdmin || user.isSuperAdmin || user.isHelpDesk

        // 1. Phân quyền xem ticket
        let baseList: [SupportTicket]
        if isFull {
            baseList = rawTickets
        } else if user.isTechnician || user.isSpecialist {
            // KTV xem ticket giao cho mình
            baseList = rawTickets.filter { t in
                t.isUserAssigned(email: cleanEmail) || t.creatorEmail.lowercased() == cleanEmail
            }
        } else {
            // Nhân viên thường chỉ xem ticket do mình tạo
            baseList = rawTickets.filter { t in
                t.creatorEmail.lowercased() == cleanEmail || t.creatorUserId.lowercased() == cleanEmail
            }
        }

        // 2. Lọc theo Tab trạng thái & Search
        return baseList.filter { t in
            let matchTab: Bool
            switch filterTab {
            case "OPEN": matchTab = t.isOpen
            case "CLOSED": matchTab = !t.isOpen
            default: matchTab = true
            }

            let matchSearch = searchQuery.isEmpty ||
                t.subject.localizedCaseInsensitiveContains(searchQuery) ||
                t.id.localizedCaseInsensitiveContains(searchQuery) ||
                t.creatorName.localizedCaseInsensitiveContains(searchQuery) ||
                t.donVi.localizedCaseInsensitiveContains(searchQuery)

            return matchTab && matchSearch
        }
    }

    public var openCount: Int {
        rawTickets.filter { $0.isOpen }.count
    }

    public var closedCount: Int {
        rawTickets.filter { !$0.isOpen }.count
    }

    // Staff ticket creation
    public func createTicket(subject: String, description: String, priority: String, deviceId: String?) async -> String? {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var fields: [String: Any] = [
            "subject": ["stringValue": subject],
            "initialMessage": ["stringValue": description],
            "priority": ["stringValue": priority],
            "status": ["stringValue": "OPEN"],
            "creatorEmail": ["stringValue": user.email],
            "creatorName": ["stringValue": user.fullName.isEmpty ? user.email : user.fullName],
            "createdAt": ["integerValue": String(now)],
            "companyId": ["stringValue": companyId]
        ]
        if let deviceId = deviceId, !deviceId.isEmpty {
            fields["assetId"] = ["stringValue": deviceId]
        }

        let body: [String: Any] = ["fields": fields]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else { return nil }

        let id = name.components(separatedBy: "/").last ?? ""
        return id
    }

    // Staff xem ticket của mình
    public func fetchMyTickets() async {
        await MainActor.run { isLoading = true }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets?pageSize=100" // Should filter via structuredQuery, but for now fetch and filter
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            await MainActor.run { self.isLoading = false }
            return
        }

        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let list: [SupportTicket] = documents.compactMap { doc in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let creatorEmail = FirestoreHelper.getString(fields["creatorEmail"] as? [String: Any]).lowercased()
            if creatorEmail != cleanEmail { return nil }
            
            let id = name.components(separatedBy: "/").last ?? ""
            return SupportTicket(
                id: id,
                creatorEmail: creatorEmail,
                creatorName: FirestoreHelper.getString(fields["creatorName"] as? [String: Any]),
                subject: FirestoreHelper.getString(fields["subject"] as? [String: Any]),
                status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any])
            )
        }

        await MainActor.run {
            self.myTickets = list.sorted { $0.createdAt > $1.createdAt }
            self.isLoading = false
        }
    }

    // Tải danh sách tickets từ Firestore
    public func fetchTickets() {
        isLoading = true
        errorMessage = nil
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets?pageSize=100"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let documents = json["documents"] as? [[String: Any]] else {
                self.isLoading = false
                self.errorMessage = "Không thể tải danh sách yêu cầu hỗ trợ"
                return
            }

            let list: [SupportTicket] = documents.compactMap { doc in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""

                return SupportTicket(
                    id: id,
                    creatorEmail: FirestoreHelper.getString(fields["creatorEmail"] as? [String: Any]),
                    creatorName: FirestoreHelper.getString(fields["creatorName"] as? [String: Any]),
                    creatorPhone: FirestoreHelper.getString(fields["creatorPhone"] as? [String: Any]),
                    creatorUserId: FirestoreHelper.getString(fields["creatorUserId"] as? [String: Any]),
                    subject: FirestoreHelper.getString(fields["subject"] as? [String: Any]),
                    status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                    category: FirestoreHelper.getString(fields["category"] as? [String: Any]),
                    priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                    assetId: FirestoreHelper.getString(fields["assetId"] as? [String: Any]),
                    assetName: FirestoreHelper.getString(fields["assetName"] as? [String: Any]),
                    images: FirestoreHelper.getStringArray(fields["images"] as? [String: Any]),
                    createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                    lastMessage: FirestoreHelper.getString(fields["lastMessage"] as? [String: Any]),
                    lastMessageAt: FirestoreHelper.getInt64(fields["lastMessageAt"] as? [String: Any]),
                    companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
                    departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                    donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                    initialMessage: FirestoreHelper.getString(fields["initialMessage"] as? [String: Any]),
                    rating: FirestoreHelper.getInt(fields["rating"] as? [String: Any]),
                    feedback: FirestoreHelper.getString(fields["feedback"] as? [String: Any]),
                    assignedTo: FirestoreHelper.getString(fields["assignedTo"] as? [String: Any]),
                    assignedToEmail: FirestoreHelper.getString(fields["assignedToEmail"] as? [String: Any]),
                    assignedToName: FirestoreHelper.getString(fields["assignedToName"] as? [String: Any]),
                    isAcknowledged: FirestoreHelper.getBool(fields["isAcknowledged"] as? [String: Any]),
                    resolvedAt: FirestoreHelper.getInt64(fields["resolvedAt"] as? [String: Any]),
                    closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any])
                )
            }

            self.rawTickets = list.sorted { $0.createdAt > $1.createdAt }
            self.isLoading = false
        }
    }

    // Tải tin nhắn chat của Ticket
    public func fetchMessages(for ticketId: String) {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)/messages?pageSize=100"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let documents = json["documents"] as? [[String: Any]] else {
                return
            }

            let msgs: [SupportMessage] = documents.compactMap { doc in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""
                return SupportMessage(
                    id: id,
                    senderEmail: FirestoreHelper.getString(fields["senderEmail"] as? [String: Any]),
                    senderName: FirestoreHelper.getString(fields["senderName"] as? [String: Any]),
                    message: FirestoreHelper.getString(fields["message"] as? [String: Any]),
                    timestamp: FirestoreHelper.getInt64(fields["timestamp"] as? [String: Any]),
                    isAdminReply: FirestoreHelper.getBool(fields["isAdminReply"] as? [String: Any]),
                    donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                    departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                    isSystemMessage: FirestoreHelper.getBool(fields["isSystemMessage"] as? [String: Any]),
                    isInternal: FirestoreHelper.getBool(fields["isInternal"] as? [String: Any])
                )
            }

            self.messages = msgs.sorted { $0.timestamp < $1.timestamp }
        }
    }

    // Gửi tin nhắn mới
    public func sendMessage(ticketId: String, text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        isSendingMessage = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)/messages"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "senderEmail": ["stringValue": user.email],
                    "senderName": ["stringValue": !user.fullName.isEmpty ? user.fullName : user.email],
                    "message": ["stringValue": cleanText],
                    "timestamp": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))],
                    "isAdminReply": ["booleanValue": user.isAdmin || user.isHelpDesk || user.isTechnician],
                    "donVi": ["stringValue": user.donVi],
                    "departmentId": ["stringValue": user.departmentId]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
            self.isSendingMessage = false
            self.fetchMessages(for: ticketId)
        }
    }

    // KTV Tiếp nhận Ticket
    public func acknowledgeTicket(ticketId: String) {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)?updateMask.fieldPaths=isAcknowledged&updateMask.fieldPaths=acknowledgedAt&updateMask.fieldPaths=acknowledgedBy"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "isAcknowledged": ["booleanValue": true],
                    "acknowledgedAt": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))],
                    "acknowledgedBy": ["stringValue": user.email]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchTickets()
        }
    }

    // Hoàn tất / Đóng Ticket
    public func closeTicket(ticketId: String, note: String = "") {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=resolutionNote"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "status": ["stringValue": "CLOSED"],
                    "closedAt": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))],
                    "closedByEmail": ["stringValue": user.email],
                    "resolutionNote": ["stringValue": note]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchTickets()
        }
    }

    // MARK: - PHÂN CÔNG KTV — Đồng bộ AdminSupportChatScreen.kt dispatchKtv
    public func assignKtv(ticketId: String, ktvEmail: String, ktvName: String) {
        Task {
            let fields = "updateMask.fieldPaths=assignedToEmail&updateMask.fieldPaths=assignedToName&updateMask.fieldPaths=assignedAt&updateMask.fieldPaths=assignedByEmail"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)?\(fields)"
            guard let url = URL(string: urlStr) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["fields": [
                "assignedToEmail": ["stringValue": ktvEmail],
                "assignedToName": ["stringValue": ktvName],
                "assignedAt": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))],
                "assignedByEmail": ["stringValue": user.email]
            ]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchTickets()
        }
    }

    // MARK: - ĐÁNH GIÁ TICKET — Đồng bộ AdminSupportChatScreen.kt rateTicket
    public func rateTicket(ticketId: String, rating: Int, comment: String = "") {
        Task {
            let fields = "updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets/\(ticketId)?\(fields)"
            guard let url = URL(string: urlStr) else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["fields": [
                "rating": ["integerValue": String(rating)],
                "feedback": ["stringValue": comment],
                "feedbackAt": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))]
            ]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchTickets()
        }
    }

    // MARK: - KTV MONITOR — Đồng bộ OnlineKtvMonitorScreen.kt
    // Lấy danh sách KTV từ collection companies/{companyId}/users, lọc theo role
    public func fetchKtvTechnicians() {
        isLoadingKtvs = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/users?pageSize=200"
            guard let url = URL(string: urlStr) else {
                await MainActor.run { self.isLoadingKtvs = false }
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let docs = json["documents"] as? [[String: Any]] else {
                await MainActor.run { self.isLoadingKtvs = false }
                return
            }

            let ktvRoles: Set<String> = ["KTV", "TECHNICIAN", "KYTHUAT", "HELPDESK", "HELP_DESK"]
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let onlineWindowMs: Int64 = 15 * 60 * 1000 // 15 phút

            var result: [KtvOnlineLocation] = []
            for doc in docs {
                guard let fields = doc["fields"] as? [String: Any] else { continue }
                let role = FirestoreHelper.getString(fields["role"] as? [String: Any]).uppercased()
                guard ktvRoles.contains(role) else { continue }

                let rawOnline = (fields["isOnline"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let lastActiveAt = FirestoreHelper.getInt64(fields["lastActiveAt"] as? [String: Any])
                let isOnline = rawOnline && (lastActiveAt > 0) && ((nowMs - lastActiveAt) < onlineWindowMs)

                let name = FirestoreHelper.getString(fields["fullName"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["name"] as? [String: Any])
                    : FirestoreHelper.getString(fields["fullName"] as? [String: Any])
                let email = FirestoreHelper.getString(fields["email"] as? [String: Any])
                let phone = FirestoreHelper.getString(fields["phone"] as? [String: Any])
                let maNhanVien = FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["employeeId"] as? [String: Any])
                    : FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any])
                let maKhuVuc = FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])
                let unitName = FirestoreHelper.getString(fields["donVi"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["departmentId"] as? [String: Any])
                    : FirestoreHelper.getString(fields["donVi"] as? [String: Any])

                // Tính lastSeen string
                var lastSeen = "Không rõ"
                if lastActiveAt > 0 {
                    let diffSeconds = (nowMs - lastActiveAt) / 1000
                    if diffSeconds < 60 { lastSeen = "Vừa xong" }
                    else if diffSeconds < 3600 { lastSeen = "\(diffSeconds / 60) phút trước" }
                    else { lastSeen = "\(diffSeconds / 3600) giờ trước" }
                }

                let latitude = FirestoreHelper.getDouble(fields["latitude"] as? [String: Any])
                let longitude = FirestoreHelper.getDouble(fields["longitude"] as? [String: Any])

                result.append(KtvOnlineLocation(
                    name: name.isEmpty ? email : name,
                    email: email,
                    maNhanVien: maNhanVien,
                    phone: phone,
                    maKhuVuc: maKhuVuc,
                    unitName: unitName.isEmpty ? role : unitName,
                    isOnline: isOnline,
                    lastSeen: lastSeen,
                    lastActiveAt: lastActiveAt,
                    latitude: latitude,
                    longitude: longitude
                ))
            }

            // Sắp xếp: trực tuyến trước, ngoại tuyến sau
            result.sort { $0.isOnline && !$1.isOnline }

            await MainActor.run {
                self.ktvTechnicians = result
                self.isLoadingKtvs = false
            }
        }
    }
}
