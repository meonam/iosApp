import SwiftUI

// MARK: - SUPPORT VIEW MODEL (ĐỒNG BỘ 1:1 VỚI ADMINSUPPORTVIEWMODEL.KT TRÊN ANDROID)
@MainActor
public class SupportViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var rawTickets: [SupportTicket] = []
    public var tickets: [SupportTicket] {
        get { rawTickets }
        set { rawTickets = newValue }
    }
    @Published public var filterStatus: String = "ALL" // "ALL", "OPEN", "CLOSED", "HIDDEN"
    public var filterTab: String {
        get { filterStatus }
        set { filterStatus = newValue }
    }
    @Published public var filterSource: String = "ALL" // "ALL", "APP", "ZALO", "EMAIL", "DEPARTMENT"
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
    @Published public var recentFeedbacks: [SupportTicket] = []
    @Published public var starCounts: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
    @Published public var averageRating: Double = 0.0
    @Published public var satisfactionRate: Double = 0.0
    @Published public var dissatisfactionRate: Double = 0.0
    @Published public var totalRatedTickets: Int = 0
    @Published public var isLoadingStats: Bool = false

    @Published public var deletedTicketIds: Set<String> = []

    public struct KtvStat: Identifiable {
        public var id: String { email }
        public var email: String
        public var name: String
        public var departmentName: String
        public var totalTickets: Int
        public var closedTickets: Int
        public var totalRatings: Int
        public var avgRating: Double
        public var avgResolutionHours: Double
        public var slaComplianceRate: Double

        public init(
            email: String,
            name: String,
            departmentName: String = "",
            totalTickets: Int,
            closedTickets: Int,
            totalRatings: Int = 0,
            avgRating: Double,
            avgResolutionHours: Double,
            slaComplianceRate: Double
        ) {
            self.email = email
            self.name = name
            self.departmentName = departmentName
            self.totalTickets = totalTickets
            self.closedTickets = closedTickets
            self.totalRatings = totalRatings
            self.avgRating = avgRating
            self.avgResolutionHours = avgResolutionHours
            self.slaComplianceRate = slaComplianceRate
        }
    }

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.idToken = idToken
        let saved = UserDefaults.standard.stringArray(forKey: "support_prefs_deleted_ids") ?? []
        self.deletedTicketIds = Set(saved)
    }

    // MARK: - HIDE / CLEAN CLOSED TICKETS
    public func hideTicket(id: String) {
        deletedTicketIds.insert(id)
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_prefs_deleted_ids")
    }

    public func unhideTicket(id: String) {
        deletedTicketIds.remove(id)
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_prefs_deleted_ids")
    }

    public func toggleHideTicket(_ id: String) {
        if deletedTicketIds.contains(id) {
            unhideTicket(id: id)
        } else {
            hideTicket(id: id)
        }
    }

    public func cleanClosedTickets() {
        let closedIds = scopedTickets.filter { $0.isClosed }.map { $0.id }
        for id in closedIds {
            deletedTicketIds.insert(id)
        }
        UserDefaults.standard.set(Array(deletedTicketIds), forKey: "support_prefs_deleted_ids")
    }

    // MARK: - SCOPED TICKETS FILTERING (ĐỒNG BỘ 1:1 VỚI isTicketVisible TRONG ADMINSUPPORTVIEWMODEL.KT)
    public var scopedTickets: [SupportTicket] {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanDeptId = user.departmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanDonVi = user.donVi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Admin, SuperAdmin, HelpDesk: toàn quyền thấy hết để điều phối
        if user.isAdmin || user.isSuperAdmin || user.isHelpDesk {
            return rawTickets
        }

        return rawTickets.filter { ticket in
            let tCreator = ticket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tCreatorUserId = ticket.creatorUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tDonVi = ticket.donVi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // 2. Người tạo Ticket luôn thấy
            if tCreator == cleanEmail || tCreatorUserId == cleanEmail {
                return true
            }

            // 2b. Người thuộc đơn vị thấy
            if !cleanDonVi.isEmpty && (tDonVi == cleanDonVi || tDonVi.contains(cleanDonVi) || cleanDonVi.contains(tDonVi)) {
                return true
            }

            // 3. KTV hoặc Specialist được phân công
            if ticket.isUserAssigned(email: cleanEmail) {
                return true
            }

            // 4. Ticket phòng ban điều phối
            let tAssignedDept = ticket.assignedDepartmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tAssignedDeptName = ticket.assignedDepartmentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !tAssignedDept.isEmpty || !tAssignedDeptName.isEmpty {
                let matchDept = (!cleanDeptId.isEmpty && (tAssignedDept == cleanDeptId || tAssignedDeptName == cleanDeptId)) ||
                                (!cleanDonVi.isEmpty && (tAssignedDept == cleanDonVi || tAssignedDeptName == cleanDonVi))
                if matchDept {
                    if user.isManager { return true }
                    if ticket.assignedToEmail.isEmpty && ticket.assignedTo.isEmpty { return true }
                }
            }

            // 5. Chuyên viên tổ nghiệp vụ
            if user.isSpecialist && !ticket.toNghiepVu.isEmpty {
                if ticket.isSpecialistAssigned && ticket.assignedToEmail.isEmpty {
                    return true
                }
            }

            return false
        }
    }

    // MARK: - TAB COUNTS
    public var allCount: Int {
        scopedTickets.filter { !deletedTicketIds.contains($0.id) }.count
    }

    public var openCount: Int {
        scopedTickets.filter { !deletedTicketIds.contains($0.id) && $0.isOpen }.count
    }

    public var closedCount: Int {
        scopedTickets.filter { !deletedTicketIds.contains($0.id) && $0.isClosed }.count
    }

    public var hiddenCount: Int {
        scopedTickets.filter { deletedTicketIds.contains($0.id) }.count
    }

    public func isDeptTicket(_ t: SupportTicket) -> Bool {
        t.scope.uppercased() == "DEPARTMENT" ||
        t.source.uppercased() == "DEPARTMENT" ||
        t.isSpecialistAssigned ||
        t.assignedRole.uppercased() == "SPECIALIST" ||
        t.assignedDepartmentId.uppercased().hasPrefix("TO_") ||
        t.assignedDepartmentName.localizedCaseInsensitiveContains("ứng dụng") ||
        t.assignedDepartmentName.localizedCaseInsensitiveContains("nghiệp vụ") ||
        t.departmentId.localizedCaseInsensitiveContains("phòng ban") ||
        t.subject.localizedCaseInsensitiveContains("phòng ban")
    }

    public var appCount: Int {
        scopedTickets.filter { t in
            !deletedTicketIds.contains(t.id) &&
            (t.source.isEmpty || t.source.uppercased() == "APP") &&
            !isDeptTicket(t)
        }.count
    }

    public var emailCount: Int {
        scopedTickets.filter { t in
            !deletedTicketIds.contains(t.id) &&
            (t.source.uppercased() == "EMAIL" || t.externalSenderId.contains("@")) &&
            !isDeptTicket(t)
        }.count
    }

    public var deptCount: Int {
        scopedTickets.filter { t in
            !deletedTicketIds.contains(t.id) &&
            isDeptTicket(t)
        }.count
    }

    // MARK: - FILTERED TICKETS BY STATUS, CHANNEL & SEARCH
    public var filteredTickets: [SupportTicket] {
        let baseList = scopedTickets
        let isDeptFilter: (SupportTicket) -> Bool = { t in
            t.scope.uppercased() == "DEPARTMENT" ||
            t.source.uppercased() == "DEPARTMENT" ||
            t.isSpecialistAssigned ||
            t.assignedRole.uppercased() == "SPECIALIST" ||
            t.assignedDepartmentId.uppercased().hasPrefix("TO_") ||
            t.assignedDepartmentName.localizedCaseInsensitiveContains("ứng dụng") ||
            t.assignedDepartmentName.localizedCaseInsensitiveContains("nghiệp vụ")
        }

        let statusFiltered = baseList.filter { t in
            if filterStatus == "HIDDEN" {
                return deletedTicketIds.contains(t.id)
            } else {
                if deletedTicketIds.contains(t.id) { return false }
                switch filterStatus {
                case "OPEN": return t.isOpen
                case "CLOSED": return t.isClosed
                default: return true // "ALL"
                }
            }
        }

        let channelFiltered = statusFiltered.filter { t in
            switch filterSource {
            case "APP": return (t.source.isEmpty || t.source.uppercased() == "APP") && !isDeptFilter(t)
            case "ZALO": return t.source.uppercased() == "ZALO" && !isDeptFilter(t)
            case "EMAIL": return t.source.uppercased() == "EMAIL" && !isDeptFilter(t)
            case "DEPARTMENT": return isDeptFilter(t)
            default: return true // "ALL"
            }
        }

        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return channelFiltered
        }

        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return channelFiltered.filter { t in
            t.subject.lowercased().contains(q) ||
            t.id.lowercased().contains(q) ||
            t.creatorName.lowercased().contains(q) ||
            t.creatorEmail.lowercased().contains(q) ||
            t.donVi.lowercased().contains(q) ||
            t.assignedToName.lowercased().contains(q) ||
            t.assetName.lowercased().contains(q)
        }
    }

    // MARK: - DATE GROUPING HELPER (ĐỒNG BỘ GROUPED BY "Hôm nay", "Hôm qua", "dd/MM/yyyy")
    public func groupedTicketsByDate() -> [(dateGroup: String, tickets: [SupportTicket])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        let grouped = Dictionary(grouping: filteredTickets) { ticket -> String in
            let tDate = Date(timeIntervalSince1970: Double(ticket.createdAt) / 1000.0)
            let startOfTDate = cal.startOfDay(for: tDate)

            if startOfTDate == today {
                return "Hôm nay"
            } else if startOfTDate == yesterday {
                return "Hôm qua"
            } else {
                return dateFormatter.string(from: tDate)
            }
        }

        // Sort keys: "Hôm nay" first, "Hôm qua" second, then by date descending
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Hôm nay" { return true }
            if k2 == "Hôm nay" { return false }
            if k1 == "Hôm qua" { return true }
            if k2 == "Hôm qua" { return false }
            return k1 > k2
        }

        return sortedKeys.map { key in
            let sortedInGroup = (grouped[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            return (dateGroup: key, tickets: sortedInGroup)
        }
    }

    // MARK: - FETCH ALL TICKETS (FIRESTORE RUN QUERY)
    public func fetchTickets() {
        guard !companyId.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId):runQuery"
            guard let url = URL(string: urlStr) else {
                self.isLoading = false
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let queryPayload: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "support_tickets"]],
                    "orderBy": [
                        ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
                    ],
                    "limit": 500
                ]
            ]

            guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else {
                self.isLoading = false
                return
            }
            request.httpBody = bodyData

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                self.isLoading = false
                self.errorMessage = "Không thể tải danh sách phiếu hỗ trợ"
                return
            }

            let parsed: [SupportTicket] = results.compactMap { item in
                guard let doc = item["document"] as? [String: Any],
                      let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""

                let ack = FirestoreHelper.getBool(fields["isAcknowledged"] as? [String: Any])
                let ackAt = FirestoreHelper.getInt64(fields["acknowledgedAt"] as? [String: Any])
                let ackBy = FirestoreHelper.getString(fields["acknowledgedBy"] as? [String: Any])
                let ackByName = FirestoreHelper.getString(fields["acknowledgedByName"] as? [String: Any])

                // Parse attachments if any
                var attachmentsList: [AttachmentItem] = []
                if let attArray = (fields["attachments"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let values = attArray["values"] as? [[String: Any]] {
                    for v in values {
                        if let mMap = v["mapValue"] as? [String: Any], let mFields = mMap["fields"] as? [String: Any] {
                            let aId = FirestoreHelper.getString(mFields["id"] as? [String: Any])
                            let aName = FirestoreHelper.getString(mFields["name"] as? [String: Any])
                            let aUrl = FirestoreHelper.getString(mFields["url"] as? [String: Any])
                            let aSize = FirestoreHelper.getInt64(mFields["size"] as? [String: Any])
                            let aType = FirestoreHelper.getString(mFields["type"] as? [String: Any])
                            attachmentsList.append(AttachmentItem(id: aId, name: aName, url: aUrl, size: aSize, type: aType))
                        }
                    }
                }

                return SupportTicket(
                    id: id,
                    creatorEmail: FirestoreHelper.getString(fields["creatorEmail"] as? [String: Any]),
                    creatorName: FirestoreHelper.getString(fields["creatorName"] as? [String: Any]),
                    creatorPhone: FirestoreHelper.getString(fields["creatorPhone"] as? [String: Any]),
                    creatorUserId: FirestoreHelper.getString(fields["creatorUserId"] as? [String: Any]),
                    creatorLat: FirestoreHelper.getDouble(fields["creatorLat"] as? [String: Any]),
                    creatorLng: FirestoreHelper.getDouble(fields["creatorLng"] as? [String: Any]),
                    creatorAddress: FirestoreHelper.getString(fields["creatorAddress"] as? [String: Any]),
                    subject: FirestoreHelper.getString(fields["subject"] as? [String: Any]),
                    status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                    category: FirestoreHelper.getString(fields["category"] as? [String: Any]),
                    priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                    assetId: FirestoreHelper.getString(fields["assetId"] as? [String: Any]),
                    assetName: FirestoreHelper.getString(fields["assetName"] as? [String: Any]),
                    images: FirestoreHelper.getStringArray(fields["images"] as? [String: Any]),
                    attachments: attachmentsList,
                    createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                    lastMessage: FirestoreHelper.getString(fields["lastMessage"] as? [String: Any]),
                    lastMessageAt: FirestoreHelper.getInt64(fields["lastMessageAt"] as? [String: Any]),
                    companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
                    departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                    donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                    initialMessage: FirestoreHelper.getString(fields["initialMessage"] as? [String: Any]),
                    rating: FirestoreHelper.getInt(fields["rating"] as? [String: Any]),
                    feedback: FirestoreHelper.getString(fields["feedback"] as? [String: Any]),
                    feedbackAt: FirestoreHelper.getInt64(fields["feedbackAt"] as? [String: Any]),
                    parentTicketId: FirestoreHelper.getString(fields["parentTicketId"] as? [String: Any]),
                    assignedTo: FirestoreHelper.getString(fields["assignedTo"] as? [String: Any]),
                    assignedDepartmentId: FirestoreHelper.getString(fields["assignedDepartmentId"] as? [String: Any]),
                    assignedDepartmentName: FirestoreHelper.getString(fields["assignedDepartmentName"] as? [String: Any]),
                    assignedToEmail: FirestoreHelper.getString(fields["assignedToEmail"] as? [String: Any]),
                    assignedToName: FirestoreHelper.getString(fields["assignedToName"] as? [String: Any]),
                    assignedCluster: FirestoreHelper.getString(fields["assignedCluster"] as? [String: Any]),
                    assignedRegion: FirestoreHelper.getString(fields["assignedRegion"] as? [String: Any]),
                    assignedByEmail: FirestoreHelper.getString(fields["assignedByEmail"] as? [String: Any]),
                    assignedAt: FirestoreHelper.getInt64(fields["assignedAt"] as? [String: Any]),
                    dispatchNote: FirestoreHelper.getString(fields["dispatchNote"] as? [String: Any]),
                    handlingMethod: FirestoreHelper.getString(fields["handlingMethod"] as? [String: Any]),
                    handlingMethodUpdatedAt: FirestoreHelper.getInt64(fields["handlingMethodUpdatedAt"] as? [String: Any]),
                    isAcknowledged: ack,
                    acknowledgedAt: ackAt,
                    acknowledgedBy: ackBy,
                    acknowledgedByName: ackByName,
                    resolvedAt: FirestoreHelper.getInt64(fields["resolvedAt"] as? [String: Any]),
                    resolvedBy: FirestoreHelper.getString(fields["resolvedBy"] as? [String: Any]),
                    resolvedByName: FirestoreHelper.getString(fields["resolvedByName"] as? [String: Any]),
                    resolutionNote: FirestoreHelper.getString(fields["resolutionNote"] as? [String: Any]),
                    closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any]),
                    closedByEmail: FirestoreHelper.getString(fields["closedByEmail"] as? [String: Any]),
                    closedByName: FirestoreHelper.getString(fields["closedByName"] as? [String: Any]),
                    ratingResponse: FirestoreHelper.getInt(fields["ratingResponse"] as? [String: Any]),
                    ratingResolve: FirestoreHelper.getInt(fields["ratingResolve"] as? [String: Any]),
                    ratingAttitude: FirestoreHelper.getInt(fields["ratingAttitude"] as? [String: Any]),
                    ratingQuality: FirestoreHelper.getInt(fields["ratingQuality"] as? [String: Any]),
                    isAutoRated: FirestoreHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                    reopenCount: FirestoreHelper.getInt(fields["reopenCount"] as? [String: Any]),
                    isQualityPassed: FirestoreHelper.getBool(fields["isQualityPassed"] as? [String: Any]),
                    source: FirestoreHelper.getString(fields["source"] as? [String: Any]),
                    isInvalid: FirestoreHelper.getBool(fields["isInvalid"] as? [String: Any]),
                    invalidReason: FirestoreHelper.getString(fields["invalidReason"] as? [String: Any]),
                    previousRating: FirestoreHelper.getInt(fields["previousRating"] as? [String: Any]),
                    previousFeedback: FirestoreHelper.getString(fields["previousFeedback"] as? [String: Any]),
                    isObjectiveExclusion: FirestoreHelper.getBool(fields["isObjectiveExclusion"] as? [String: Any]),
                    objectiveExclusionReason: FirestoreHelper.getString(fields["objectiveExclusionReason"] as? [String: Any]),
                    reopenedAt: FirestoreHelper.getInt64(fields["reopenedAt"] as? [String: Any]),
                    reopenedByEmail: FirestoreHelper.getString(fields["reopenedByEmail"] as? [String: Any]),
                    reopenedByName: FirestoreHelper.getString(fields["reopenedByName"] as? [String: Any]),
                    reopenReason: FirestoreHelper.getString(fields["reopenReason"] as? [String: Any]),
                    assignedApplication: FirestoreHelper.getString(fields["assignedApplication"] as? [String: Any]),
                    assignedRole: FirestoreHelper.getString(fields["assignedRole"] as? [String: Any]),
                    scope: FirestoreHelper.getString(fields["scope"] as? [String: Any]),
                    toNghiepVu: FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any])
                )
            }

            self.rawTickets = parsed.sorted { $0.lastMessageAt.coerceAtLeast($0.createdAt) > $1.lastMessageAt.coerceAtLeast($1.createdAt) }
            self.isLoading = false
        }
    }

    // MARK: - CREATE TICKET
    public func createTicket(
        subject: String,
        initialMessage: String,
        category: String = "HARDWARE",
        priority: String = "NORMAL",
        assetId: String = "",
        assetName: String = "",
        images: [String] = [],
        attachments: [AttachmentItem] = []
    ) async -> String? {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var fields: [String: Any] = [
            "subject": ["stringValue": subject],
            "initialMessage": ["stringValue": initialMessage],
            "lastMessage": ["stringValue": initialMessage],
            "category": ["stringValue": category],
            "priority": ["stringValue": priority],
            "status": ["stringValue": "OPEN"],
            "creatorEmail": ["stringValue": user.email],
            "creatorName": ["stringValue": !user.fullName.isEmpty ? user.fullName : user.email],
            "creatorPhone": ["stringValue": user.phone],
            "donVi": ["stringValue": user.donVi],
            "departmentId": ["stringValue": user.departmentId],
            "companyId": ["stringValue": companyId],
            "createdAt": ["integerValue": String(now)],
            "lastMessageAt": ["integerValue": String(now)],
            "source": ["stringValue": "APP"]
        ]
        if !assetId.isEmpty { fields["assetId"] = ["stringValue": assetId] }
        if !assetName.isEmpty { fields["assetName"] = ["stringValue": assetName] }
        if !images.isEmpty {
            fields["images"] = ["arrayValue": ["values": images.map { ["stringValue": $0] }]]
        }

        let body: [String: Any] = ["fields": fields]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else { return nil }

        let id = name.components(separatedBy: "/").last ?? ""

        // Also add the first message into messages subcollection
        sendMessage(ticketId: id, text: initialMessage)
        fetchTickets()
        return id
    }

    public func createTicket(
        subject: String,
        message: String = "",
        initialMessage: String = "",
        category: String = "HARDWARE",
        priority: String = "NORMAL",
        assetId: String = "",
        assetName: String = "",
        phone: String = "",
        images: [String] = [],
        donVi: String = "",
        gpsLat: Double = 0.0,
        gpsLng: Double = 0.0,
        scope: String = "GENERAL",
        attachments: [AttachmentItem] = [],
        completion: ((Bool) -> Void)? = nil
    ) {
        let msg = !message.isEmpty ? message : initialMessage
        Task {
            let res = await createTicket(
                subject: subject,
                initialMessage: msg,
                category: category,
                priority: priority,
                assetId: assetId,
                assetName: assetName,
                images: images,
                attachments: attachments
            )
            DispatchQueue.main.async {
                completion?(res != nil)
            }
        }
    }

    // MARK: - CHAT MESSAGES
    public func fetchMessages(for ticketId: String) {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)/messages?pageSize=100"
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

    public func sendMessage(ticketId: String, text: String, isInternal: Bool = false) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        isSendingMessage = true
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)/messages"
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
                    "timestamp": ["integerValue": String(now)],
                    "isAdminReply": ["booleanValue": user.isAdmin || user.isHelpDesk || user.isTechnician],
                    "donVi": ["stringValue": user.donVi],
                    "departmentId": ["stringValue": user.departmentId],
                    "isInternal": ["booleanValue": isInternal]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            // Update ticket lastMessage & lastMessageAt
            let patchUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            if let patchUrl = URL(string: patchUrlStr) {
                var pReq = URLRequest(url: patchUrl)
                pReq.httpMethod = "PATCH"
                pReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                pReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let pBody: [String: Any] = [
                    "fields": [
                        "lastMessage": ["stringValue": cleanText],
                        "lastMessageAt": ["integerValue": String(now)]
                    ]
                ]
                pReq.httpBody = try? JSONSerialization.data(withJSONObject: pBody)
                _ = try? await URLSession.shared.data(for: pReq)
            }

            self.isSendingMessage = false
            self.fetchMessages(for: ticketId)
        }
    }

    // MARK: - KTV TIẾP NHẬN / PHƯƠNG ÁN XỬ LÝ
    public func acknowledgeTicket(ticketId: String) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=isAcknowledged&updateMask.fieldPaths=acknowledgedAt&updateMask.fieldPaths=acknowledgedBy&updateMask.fieldPaths=acknowledgedByName"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "isAcknowledged": ["booleanValue": true],
                    "acknowledgedAt": ["integerValue": String(now)],
                    "acknowledgedBy": ["stringValue": user.email],
                    "acknowledgedByName": ["stringValue": user.fullName]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
            self.fetchTickets()
        }
    }

    public func selectHandlingMethod(ticketId: String, method: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=handlingMethod&updateMask.fieldPaths=handlingMethodUpdatedAt&updateMask.fieldPaths=isAcknowledged&updateMask.fieldPaths=acknowledgedAt&updateMask.fieldPaths=acknowledgedBy&updateMask.fieldPaths=acknowledgedByName"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "handlingMethod": ["stringValue": method],
                    "handlingMethodUpdatedAt": ["integerValue": String(now)],
                    "isAcknowledged": ["booleanValue": true],
                    "acknowledgedAt": ["integerValue": String(now)],
                    "acknowledgedBy": ["stringValue": user.email],
                    "acknowledgedByName": ["stringValue": user.fullName]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let msg = method == "REMOTE"
                ? "💻 KTV \(user.fullName) đã tiếp nhận và chọn phương án Xử lý từ xa (UltraViewer / ĐT)"
                : "🛵 KTV \(user.fullName) đã tiếp nhận và đang di chuyển tới đơn vị"
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - KTV BÁO CÁO HOÀN THÀNH XỬ LÝ (markTicketResolved)
    public func markTicketResolved(ticketId: String, note: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=resolvedBy&updateMask.fieldPaths=resolvedByName&updateMask.fieldPaths=resolutionNote"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "status": ["stringValue": "RESOLVED"],
                    "resolvedAt": ["integerValue": String(now)],
                    "resolvedBy": ["stringValue": user.email],
                    "resolvedByName": ["stringValue": user.fullName],
                    "resolutionNote": ["stringValue": note]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let msg = "🛠️ KTV \(user.fullName) báo cáo ĐÃ XỬ LÝ XONG: \(note). Mời bạn nghiệm thu & đánh giá chất lượng."
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - ĐÓNG TICKET
    public func closeTicket(ticketId: String, note: String = "", rating: Int? = nil, feedback: String = "", completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            var mask = "updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=closedByName"
            if !note.isEmpty { mask += "&updateMask.fieldPaths=resolutionNote" }
            if let _ = rating {
                mask += "&updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt"
            }
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var f: [String: Any] = [
                "status": ["stringValue": "CLOSED"],
                "closedAt": ["integerValue": String(now)],
                "closedByEmail": ["stringValue": user.email],
                "closedByName": ["stringValue": user.fullName]
            ]
            if !note.isEmpty { f["resolutionNote"] = ["stringValue": note] }
            if let r = rating {
                f["rating"] = ["integerValue": String(r)]
                f["feedback"] = ["stringValue": feedback]
                f["feedbackAt"] = ["integerValue": String(now)]
            }

            let body: [String: Any] = ["fields": f]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let closeMsg = !note.isEmpty ? "🔒 Yêu cầu hỗ trợ đã được đóng bởi \(user.fullName): \(note)" : "🔒 Yêu cầu hỗ trợ đã được đóng bởi \(user.fullName)."
            sendMessage(ticketId: ticketId, text: closeMsg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - REOPEN TICKET (MỞ LẠI SỰ CỐ)
    public func reopenTicket(ticketId: String, reason: String, completion: ((Bool) -> Void)? = nil) {
        guard let ticket = rawTickets.first(where: { $0.id == ticketId }) else { completion?(false); return }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=reopenCount&updateMask.fieldPaths=reopenedAt&updateMask.fieldPaths=reopenedByEmail&updateMask.fieldPaths=reopenedByName&updateMask.fieldPaths=reopenReason&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=previousRating&updateMask.fieldPaths=previousFeedback"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "status": ["stringValue": "OPEN"],
                    "reopenCount": ["integerValue": String(ticket.reopenCount + 1)],
                    "reopenedAt": ["integerValue": String(now)],
                    "reopenedByEmail": ["stringValue": user.email],
                    "reopenedByName": ["stringValue": user.fullName],
                    "reopenReason": ["stringValue": reason],
                    "closedAt": ["integerValue": "0"],
                    "resolvedAt": ["integerValue": "0"],
                    "previousRating": ["integerValue": String(ticket.rating)],
                    "previousFeedback": ["stringValue": ticket.feedback]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let msg = "🔄 \(user.fullName) đã MỞ LẠI yêu cầu hỗ trợ (Lần \(ticket.reopenCount + 1)): \(reason)"
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - ĐÁNH GIÁ CHẤT LƯỢNG (RATE TICKET)
    public func rateTicket(ticketId: String, rating: Int, feedback: String = "", completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let fields = "updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt&updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=closedByName"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(fields)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "rating": ["integerValue": String(rating)],
                    "feedback": ["stringValue": feedback],
                    "feedbackAt": ["integerValue": String(now)],
                    "status": ["stringValue": "CLOSED"],
                    "closedAt": ["integerValue": String(now)],
                    "closedByEmail": ["stringValue": user.email],
                    "closedByName": ["stringValue": user.fullName]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let stars = String(repeating: "⭐", count: rating)
            let commentPart = feedback.isEmpty ? "" : " • Nhận xét: \"\(feedback)\""
            let msg = "🎉 Người dùng đã nghiệm thu và đánh giá: \(stars) (\(rating)/5 sao)\(commentPart)"
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - ĐIỀU PHỐI / PHÂN CÔNG KTV
    public func assignKtv(ticketId: String, ktvEmail: String, ktvName: String, cluster: String = "", note: String = "", completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            var mask = "updateMask.fieldPaths=assignedToEmail&updateMask.fieldPaths=assignedToName&updateMask.fieldPaths=assignedAt&updateMask.fieldPaths=assignedByEmail"
            if !cluster.isEmpty { mask += "&updateMask.fieldPaths=assignedCluster" }
            if !note.isEmpty { mask += "&updateMask.fieldPaths=dispatchNote" }

            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var f: [String: Any] = [
                "assignedToEmail": ["stringValue": ktvEmail],
                "assignedToName": ["stringValue": ktvName],
                "assignedAt": ["integerValue": String(now)],
                "assignedByEmail": ["stringValue": user.email]
            ]
            if !cluster.isEmpty { f["assignedCluster"] = ["stringValue": cluster] }
            if !note.isEmpty { f["dispatchNote"] = ["stringValue": note] }

            let body: [String: Any] = ["fields": f]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)

            let clusterMsg = cluster.isEmpty ? "" : " (Cụm: \(cluster))"
            let noteMsg = note.isEmpty ? "" : " - Ghi chú: \(note)"
            let msg = "📌 Ticket đã được điều phối cho KTV \(ktvName)\(clusterMsg)\(noteMsg)"
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - KTV ONLINE MONITOR (OnlineKtvMonitorScreen.kt)
    public func fetchKtvTechnicians() {
        isLoadingKtvs = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/users?pageSize=200"
            guard let url = URL(string: urlStr) else {
                self.isLoadingKtvs = false
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let docs = json["documents"] as? [[String: Any]] else {
                self.isLoadingKtvs = false
                return
            }

            let ktvRoles: Set<String> = ["KTV", "TECHNICIAN", "KYTHUAT", "HELPDESK", "HELP_DESK", "CHUYENVIEN", "SPECIALIST"]
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

            result.sort { $0.isOnline && !$1.isOnline }
            self.ktvTechnicians = result
            self.isLoadingKtvs = false
        }
    }

    // MARK: - RATING REPORT KPIs (SupportRatingReportScreen.kt)
    public func fetchKtvStats() async {
        isLoadingStats = true
        guard let all = await fetchAllTicketsFromFirestore() else {
            self.isLoadingStats = false
            return
        }

        var ticketsByKtv: [String: [SupportTicket]] = [:]
        var stars: [Int: Int] = [1: 0, 2: 0, 3: 0, 4: 0, 5: 0]
        var totalRatingSum = 0
        var totalRatedCount = 0
        var satisfiedCount = 0
        var dissatisfiedCount = 0

        var feedbacks: [SupportTicket] = []

        for t in all {
            let rating = t.effectiveRating
            if rating > 0 {
                stars[rating, default: 0] += 1
                totalRatingSum += rating
                totalRatedCount += 1
                if rating >= 4 { satisfiedCount += 1 }
                if rating <= 2 { dissatisfiedCount += 1 }

                if !t.feedback.isEmpty {
                    feedbacks.append(t)
                }
            }

            if !t.assignedToEmail.isEmpty {
                ticketsByKtv[t.assignedToEmail, default: []].append(t)
            }
        }

        var stats: [KtvStat] = []
        for (email, tickets) in ticketsByKtv {
            let total = tickets.count
            let closed = tickets.filter { $0.isClosed }.count
            var name = tickets.first?.assignedToName ?? ""
            if name.isEmpty { name = email }
            let deptName = tickets.first?.assignedDepartmentName ?? ""

            var totalRating = 0.0
            var ratedCount = 0
            var totalHours = 0.0
            var resolvedCount = 0
            var withinSlaCount = 0

            for t in tickets {
                let r = t.effectiveRating
                if r > 0 {
                    totalRating += Double(r)
                    ratedCount += 1
                }
                if t.closedAt > t.createdAt && t.createdAt > 0 {
                    let hours = Double(t.closedAt - t.createdAt) / (1000.0 * 3600.0)
                    totalHours += hours
                    resolvedCount += 1
                    let limitHours = Double(t.getSlaTargetMinutes()) / 60.0
                    if hours <= limitHours { withinSlaCount += 1 }
                }
            }

            let avgRating = ratedCount > 0 ? totalRating / Double(ratedCount) : 0.0
            let avgRes = resolvedCount > 0 ? totalHours / Double(resolvedCount) : 0.0
            let slaRate = total > 0 ? (Double(withinSlaCount) / Double(total)) * 100.0 : 0.0

            stats.append(KtvStat(
                email: email,
                name: name,
                departmentName: deptName,
                totalTickets: total,
                closedTickets: closed,
                totalRatings: ratedCount,
                avgRating: avgRating,
                avgResolutionHours: avgRes,
                slaComplianceRate: slaRate
            ))
        }

        self.ktvStats = stats.sorted { $0.avgRating > $1.avgRating }
        self.starCounts = stars
        self.totalRatedTickets = totalRatedCount
        self.averageRating = totalRatedCount > 0 ? Double(totalRatingSum) / Double(totalRatedCount) : 0.0
        self.satisfactionRate = totalRatedCount > 0 ? (Double(satisfiedCount) / Double(totalRatedCount)) * 100.0 : 0.0
        self.dissatisfactionRate = totalRatedCount > 0 ? (Double(dissatisfiedCount) / Double(totalRatedCount)) * 100.0 : 0.0
        self.recentFeedbacks = feedbacks.sorted { $0.feedbackAt > $1.feedbackAt }
        self.isLoadingStats = false
    }

    private func fetchAllTicketsFromFirestore() async -> [SupportTicket]? {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId):runQuery"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let queryPayload: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "support_tickets"]],
                "orderBy": [
                    ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
                ],
                "limit": 500
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else { return nil }
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return nil
        }

        return results.compactMap { item in
            guard let doc = item["document"] as? [String: Any],
                  let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let id = name.components(separatedBy: "/").last ?? ""

            return SupportTicket(
                id: id,
                creatorEmail: FirestoreHelper.getString(fields["creatorEmail"] as? [String: Any]),
                creatorName: FirestoreHelper.getString(fields["creatorName"] as? [String: Any]),
                subject: FirestoreHelper.getString(fields["subject"] as? [String: Any]),
                status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                rating: FirestoreHelper.getInt(fields["rating"] as? [String: Any]),
                feedback: FirestoreHelper.getString(fields["feedback"] as? [String: Any]),
                feedbackAt: FirestoreHelper.getInt64(fields["feedbackAt"] as? [String: Any]),
                assignedDepartmentName: FirestoreHelper.getString(fields["assignedDepartmentName"] as? [String: Any]),
                assignedToEmail: FirestoreHelper.getString(fields["assignedToEmail"] as? [String: Any]),
                assignedToName: FirestoreHelper.getString(fields["assignedToName"] as? [String: Any]),
                closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any]),
                isAutoRated: FirestoreHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                isInvalid: FirestoreHelper.getBool(fields["isInvalid"] as? [String: Any])
            )
        }
    }
}

// MARK: - EXTENSION HELPER
extension Int64 {
    func coerceAtLeast(_ other: Int64) -> Int64 {
        return self > other ? self : other
    }
}
