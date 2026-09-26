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
}
