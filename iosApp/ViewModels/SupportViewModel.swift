import SwiftUI
import UIKit

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

    @Published public var isTicketReopenEnabled: Bool = false
    @Published public var slaConfig: SlaConfig = SlaConfig()
    @Published public var companyUnits: [DonVi] = []

    // Chat realtime
    @Published public var currentTicket: SupportTicket? = nil
    @Published public var messages: [SupportMessage] = []
    @Published public var isSendingMessage: Bool = false

    // KTV Online Monitor (đồng bộ OnlineKtvMonitorScreen.kt)
    @Published public var ktvTechnicians: [KtvOnlineLocation] = []
    @Published public var isLoadingKtvs: Bool = false

    // Staff & Specialist Teams (đồng bộ Android AndroidDispatchDialog)
    @Published public var allStaffList: [User] = []
    @Published public var specialistTeams: [SpecialistTeamInfo] = SpecialistTeamDefaults.TEAMS
    @Published public var isLoadingStaff: Bool = false

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

    public func getActiveTicketCount(email: String) -> Int {
        guard !email.isEmpty else { return 0 }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return rawTickets.filter { t in
            !t.isClosed && !t.isResolved && t.rating == 0 &&
            (t.assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == clean ||
             t.assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == clean)
        }.count
    }

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

    public init(user: User, companyId: String = "", idToken: String = "") {
        self.user = user
        let resolvedComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? user.companyId : companyId
        self.companyId = resolvedComp.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.idToken = idToken
        let saved = UserDefaults.standard.stringArray(forKey: "support_prefs_deleted_ids") ?? []
        self.deletedTicketIds = Set(saved)

        // Lắng nghe tín hiệu background fetch / silent push từ AppDelegate → fetch ngay lập tức
        NotificationCenter.default.addObserver(
            forName: Notification.Name("QLTB_BackgroundFetch"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchTicketsSilent()
        }

        fetchSystemToggleConfig()
        fetchSlaConfig()
        fetchCompanyUnits()
        fetchKtvTechnicians()
    }

    // MARK: - SYSTEM TOGGLE CONFIG (ĐỒNG BỘ CẤU HÌNH ADMIN / REOPEN TICKET)
    public func fetchSystemToggleConfig() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/system_config/system_toggle_config"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty {
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            if let (data, httpResp) = await FirestoreHelper.executeSafeRequest(req), httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let allowReopen = (fields["allowTicketReopen"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                await MainActor.run {
                    self.isTicketReopenEnabled = allowReopen
                }
            } else {
                await MainActor.run {
                    self.isTicketReopenEnabled = false
                }
            }
        }
    }

    // MARK: - SLA CONFIG & AUTO DISPATCH
    public func fetchSlaConfig() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/system_config/sla_config"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty {
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            if let (data, httpResp) = await FirestoreHelper.executeSafeRequest(req), httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                var cfg = SlaConfig()
                let rDef = FirestoreHelper.getInt(fields["responseMinutesDefault"] as? [String: Any])
                if rDef > 0 {
                    cfg.responseMinutesDefault = rDef
                }
                let rUrg = FirestoreHelper.getInt(fields["resolveMinutesUrgent"] as? [String: Any])
                if rUrg > 0 {
                    cfg.resolveMinutesUrgent = rUrg
                }
                let rHigh = FirestoreHelper.getInt(fields["resolveMinutesHigh"] as? [String: Any])
                if rHigh > 0 {
                    cfg.resolveMinutesHigh = rHigh
                }
                let rNorm = FirestoreHelper.getInt(fields["resolveMinutesNormal"] as? [String: Any])
                if rNorm > 0 {
                    cfg.resolveMinutesNormal = rNorm
                }
                let rLow = FirestoreHelper.getInt(fields["resolveMinutesLow"] as? [String: Any])
                if rLow > 0 {
                    cfg.resolveMinutesLow = rLow
                }
                let qUrg = FirestoreHelper.getInt(fields["qualityTrackingHoursUrgent"] as? [String: Any])
                if qUrg > 0 {
                    cfg.qualityTrackingHoursUrgent = qUrg
                }
                let qHigh = FirestoreHelper.getInt(fields["qualityTrackingHoursHigh"] as? [String: Any])
                if qHigh > 0 {
                    cfg.qualityTrackingHoursHigh = qHigh
                }
                let qNorm = FirestoreHelper.getInt(fields["qualityTrackingHoursNormal"] as? [String: Any])
                if qNorm > 0 {
                    cfg.qualityTrackingHoursNormal = qNorm
                }
                let qLow = FirestoreHelper.getInt(fields["qualityTrackingHoursLow"] as? [String: Any])
                if qLow > 0 {
                    cfg.qualityTrackingHoursLow = qLow
                }
                let wMin = FirestoreHelper.getInt(fields["warningBeforeBreachMinutes"] as? [String: Any])
                if wMin > 0 {
                    cfg.warningBeforeBreachMinutes = wMin
                }
                if fields["slaPenaltyPercentDefault"] != nil {
                    let pen = FirestoreHelper.getInt(fields["slaPenaltyPercentDefault"] as? [String: Any])
                    cfg.slaPenaltyPercentDefault = pen
                }
                if let eh = fields["enableHelpdeskSla"] as? [String: Any], let b = eh["booleanValue"] as? Bool {
                    cfg.enableHelpdeskSla = b
                }
                if let autoOff = fields["enableAutoDispatchOffHours"] as? [String: Any], let b = autoOff["booleanValue"] as? Bool {
                    cfg.enableAutoDispatchOffHours = b
                }
                let wdS = FirestoreHelper.getString(fields["helpdeskWeekdayStart"] as? [String: Any])
                if !wdS.isEmpty { cfg.helpdeskWeekdayStart = wdS }
                let wdE = FirestoreHelper.getString(fields["helpdeskWeekdayEnd"] as? [String: Any])
                if !wdE.isEmpty { cfg.helpdeskWeekdayEnd = wdE }
                let satS = FirestoreHelper.getString(fields["helpdeskSaturdayStart"] as? [String: Any])
                if !satS.isEmpty { cfg.helpdeskSaturdayStart = satS }
                let satE = FirestoreHelper.getString(fields["helpdeskSaturdayEnd"] as? [String: Any])
                if !satE.isEmpty { cfg.helpdeskSaturdayEnd = satE }
                let escMin = FirestoreHelper.getInt(fields["escalationTimeoutMinutes"] as? [String: Any])
                if escMin > 0 { cfg.escalationTimeoutMinutes = escMin }
                if let hArr = fields["holidaysList"] as? [String: Any],
                   let vals = hArr["arrayValue"] as? [String: Any],
                   let list = vals["values"] as? [[String: Any]] {
                    let hList: [String] = list.compactMap { $0["stringValue"] as? String }
                    if !hList.isEmpty { cfg.holidaysList = hList }
                }
                await MainActor.run {
                    self.slaConfig = cfg
                }
            }
        }
    }

    public func fetchCompanyUnits() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/units?pageSize=300"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            if let (data, resp) = await FirestoreHelper.executeSafeRequest(req), resp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                let units: [DonVi] = docs.compactMap { doc in
                    guard let fields = doc["fields"] as? [String: Any],
                          let name = doc["name"] as? String else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    let uName = FirestoreHelper.getString(fields["unitName"] as? [String: Any]).isEmpty
                        ? (FirestoreHelper.getString(fields["name"] as? [String: Any]).isEmpty ? id : FirestoreHelper.getString(fields["name"] as? [String: Any]))
                        : FirestoreHelper.getString(fields["unitName"] as? [String: Any])
                    let maKhuVuc = FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])
                    return DonVi(id: id, tenDonVi: uName, maKhuVuc: maKhuVuc, companyId: cleanComp)
                }
                await MainActor.run {
                    self.companyUnits = units
                }
            }
        }
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
        let closedIds = scopedTickets.filter { $0.isClosed || $0.isRejected }.map { $0.id }
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

            // 2b. Chỉ Nhân viên thường thuộc đơn vị mới thấy ticket đơn vị mình
            // KTV, Chuyên viên, Quản trị viên, HelpDesk: KHÔNG áp dụng quy tắc đơn vị này (vì KTV chỉ giải quyết ticket được giao đích danh hoặc cụm/phòng ban)
            let isNormalStaff = !user.isAdmin && !user.isSuperAdmin && !user.isHelpDesk && !user.isTechnician && !user.isSpecialist && !user.isManager
            if isNormalStaff {
                if !cleanDonVi.isEmpty && (tDonVi == cleanDonVi || tDonVi.contains(cleanDonVi) || cleanDonVi.contains(tDonVi)) {
                    return true
                }
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

            // 5. Chuyên viên tổ nghiệp vụ (Specialist): thấy ticket được giao tới tổ nghiệp vụ của mình (chưa chỉ định cá nhân)
            let myToNghiepVu = user.toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if user.isSpecialist && !myToNghiepVu.isEmpty {
                let tToNghiepVu = ticket.toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let noIndividualAssigned = ticket.assignedToEmail.isEmpty && ticket.assignedTo.isEmpty
                if ticket.isSpecialistAssigned && noIndividualAssigned && !tToNghiepVu.isEmpty &&
                    (tToNghiepVu == myToNghiepVu || tToNghiepVu.contains(myToNghiepVu) || myToNghiepVu.contains(tToNghiepVu)) {
                    return true
                }
            } else if user.isSpecialist && ticket.isSpecialistAssigned && ticket.assignedToEmail.isEmpty && ticket.assignedTo.isEmpty {
                // Fallback nếu specialist chưa có toNghiepVu cụ thể
                return true
            }

            return false
        }
    }

    // MARK: - CHECK TICKET HIDDEN (BỊ XÓA HOẶC TỪ CHỐI/KHÔNG PHÙ HỢP)
    public func isTicketHidden(_ t: SupportTicket) -> Bool {
        deletedTicketIds.contains(t.id) || t.isRejected
    }

    // MARK: - TAB COUNTS
    public var allCount: Int {
        scopedTickets.filter { !isTicketHidden($0) }.count
    }

    public var openCount: Int {
        scopedTickets.filter { !isTicketHidden($0) && $0.isOpen }.count
    }

    public var closedCount: Int {
        scopedTickets.filter { !isTicketHidden($0) && $0.isClosed }.count
    }

    public var hiddenCount: Int {
        scopedTickets.filter { isTicketHidden($0) }.count
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
            !isTicketHidden(t) &&
            (t.source.isEmpty || t.source.uppercased() == "APP") &&
            !isDeptTicket(t)
        }.count
    }

    public var emailCount: Int {
        scopedTickets.filter { t in
            !isTicketHidden(t) &&
            (t.source.uppercased() == "EMAIL" || t.externalSenderId.contains("@")) &&
            !isDeptTicket(t)
        }.count
    }

    public var deptCount: Int {
        scopedTickets.filter { t in
            !isTicketHidden(t) &&
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
            let hidden = isTicketHidden(t)
            if filterStatus == "HIDDEN" {
                return hidden
            } else {
                if hidden { return false }
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

    // MARK: - REAL-TIME TICKET AUTO POLLING (ĐỒNG BỘ 1:1 VỚI FIRESTORE REALTIME LISTENER TRÊN ANDROID)
    private var autoPollingTimer: Timer?
    private var pollingDispatchSource: DispatchSourceTimer?
    private var firestoreListenTask: Task<Void, Never>?
    private var isFetchingSilent: Bool = false

    public func startAutoPolling(interval: TimeInterval = 3.0) {
        stopAutoPolling()
        // 1. Kích hoạt Keep-Alive âm thanh chạy nền 24/7 để iOS không bao giờ suspend tiến trình
        BackgroundKeepAliveService.shared.start()

        // 2. Sử dụng DispatchSourceTimer trên background queue để không phụ thuộc vào RunLoop mode
        let queue = DispatchQueue.global(qos: .userInitiated)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.fetchTicketsSilent()
            }
        }
        timer.resume()
        self.pollingDispatchSource = timer

        // 3. Firestore Listen stream (gần realtime như addSnapshotListener Android)
        startFirestoreListen()
    }

    public func stopAutoPolling() {
        pollingDispatchSource?.cancel()
        pollingDispatchSource = nil
        autoPollingTimer?.invalidate()
        autoPollingTimer = nil
        firestoreListenTask?.cancel()
        firestoreListenTask = nil
        bgPollingRenewalTask?.cancel()
        bgPollingRenewalTask = nil
        if bgPollingTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(bgPollingTaskId)
            bgPollingTaskId = .invalid
        }
    }

    // MARK: - FIRESTORE LISTEN STREAM (SERVER-SENT EVENTS — GẦN REALTIME)
    private func startFirestoreListen() {
        firestoreListenTask?.cancel()
        let compId = companyId
        let token = idToken
        guard !compId.isEmpty else { return }

        firestoreListenTask = Task { [weak self] in
            guard let self = self else { return }
            // Firestore REST Listen endpoint: POST :listen với resumeToken
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(compId):listen"
            guard let url = URL(string: urlStr) else { return }

            let listenBody: [String: Any] = [
                "addTarget": [
                    "query": [
                        "parent": "\(FirebaseConfig.firestoreBaseUrl)/companies/\(compId)",
                        "structuredQuery": [
                            "from": [["collectionId": "support_tickets"]],
                            "orderBy": [["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]],
                            "limit": 500
                        ]
                    ],
                    "targetId": 1
                ]
            ]
            guard let bodyData = try? JSONSerialization.data(withJSONObject: listenBody) else { return }

            while !Task.isCancelled {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if !token.isEmpty {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                request.httpBody = bodyData
                request.timeoutInterval = 90  // server-sent stream — timeout lớn

                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        continue
                    }
                    // Đọc từng dòng JSON từ stream
                    var lineBuffer = ""
                    for try await byte in bytes {
                        if Task.isCancelled { break }
                        let ch = Character(UnicodeScalar(byte))
                        if ch == "\n" {
                            let trimmed = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && trimmed != "[" && trimmed != "]" && trimmed != "," {
                                // Khi nhận bất kỳ thay đổi nào từ stream → fetch ngay
                                if trimmed.contains("documentChange") || trimmed.contains("documentDelete") {
                                    await self.executeFetchTickets(showSpinner: false)
                                }
                            }
                            lineBuffer = ""
                        } else {
                            lineBuffer.append(ch)
                        }
                    }
                } catch {
                    if !Task.isCancelled {
                        // Kết nối bị ngắt → đợi 5 giây rồi reconnect
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                    }
                }
            }
        }
    }

    public func fetchTicketsSilent() {
        guard !companyId.isEmpty, !isFetchingSilent else { return }
        isFetchingSilent = true
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "QLTB_SilentFetch") {
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        Task {
            await self.executeFetchTickets(showSpinner: false)
            self.isFetchingSilent = false
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
    }

    // MARK: - GIỮ POLLING HOẠT ĐỘNG KHI APP CHẠY NỀN (KHÔNG LOGOUT)
    private var bgPollingTaskId: UIBackgroundTaskIdentifier = .invalid
    private var bgPollingRenewalTask: Task<Void, Never>?

    public func keepPollingInBackground() {
        // Kết thúc background task cũ nếu có
        if bgPollingTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(bgPollingTaskId)
            bgPollingTaskId = .invalid
        }
        bgPollingRenewalTask?.cancel()

        // 1. Bắt đầu background execution ngắn hạn của iOS hỗ trợ quá trình chuyển trạng thái
        bgPollingTaskId = UIApplication.shared.beginBackgroundTask(withName: "QLTB_KeepPolling") { [weak self] in
            guard let self = self else { return }
            if self.bgPollingTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(self.bgPollingTaskId)
                self.bgPollingTaskId = .invalid
            }
        }

        // 2. Kích hoạt dịch vụ Audio Keep-Alive duy trì chạy nền 24/7
        BackgroundKeepAliveService.shared.start()

        // 3. Đảm bảo timer polling 2s đang chạy
        if pollingDispatchSource == nil && autoPollingTimer == nil {
            startAutoPolling(interval: 2.0)
        } else {
            fetchTicketsSilent()
        }
    }

    // MARK: - FETCH ALL TICKETS (FIRESTORE RUN QUERY & DIRECT FALLBACK)
    public func fetchTickets() {
        guard !companyId.isEmpty else { return }
        Task {
            await self.executeFetchTickets(showSpinner: true)
        }
    }


    private func executeFetchTickets(showSpinner: Bool) async {
        if showSpinner {
            await MainActor.run {
                self.isLoading = true
                self.errorMessage = nil
            }
        }

        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp):runQuery"
        guard let url = URL(string: urlStr) else {
            if showSpinner {
                await MainActor.run { self.isLoading = false }
            }
            return
        }

        let queryLimit = showSpinner ? 500 : 150
        let queryPayload: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "support_tickets"]],
                "orderBy": [
                    ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
                ],
                "limit": queryLimit
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else {
            if showSpinner {
                await MainActor.run { self.isLoading = false }
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        var responseData: Data? = nil
        var isSuccess = false

        if let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
           httpResponse.statusCode == 200 {
            responseData = data
            isSuccess = true
        }

        // Fallback: Nếu runQuery bị lỗi hoặc không có dữ liệu, dùng trực tiếp document listing
        if !isSuccess {
            let listUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/support_tickets?pageSize=300"
            if let listUrl = URL(string: listUrlStr) {
                var listReq = URLRequest(url: listUrl)
                if !idToken.isEmpty {
                    listReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                }
                if let (lData, lHttp) = await FirestoreHelper.executeSafeRequest(listReq),
                   lHttp.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: lData) as? [String: Any],
                       let docs = json["documents"] as? [[String: Any]] {
                        let wrappedDocs = docs.map { ["document": $0] }
                        if let wrappedData = try? JSONSerialization.data(withJSONObject: wrappedDocs) {
                            responseData = wrappedData
                            isSuccess = true
                        }
                    }
                }
            }
        }

        guard isSuccess, let data = responseData,
              let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            await MainActor.run {
                if showSpinner {
                    self.isLoading = false
                    self.errorMessage = "Không thể tải danh sách phiếu hỗ trợ"
                }
            }
            return
        }

            let parsed: [SupportTicket] = results.compactMap { item in
                guard let doc = item["document"] as? [String: Any],
                      let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""

                let ackBool = FirestoreHelper.getBool(fields["isAcknowledged"] as? [String: Any]) || FirestoreHelper.getBool(fields["acknowledged"] as? [String: Any])
                let ackAt = FirestoreHelper.getInt64(fields["acknowledgedAt"] as? [String: Any])
                let ackBy = FirestoreHelper.getString(fields["acknowledgedBy"] as? [String: Any])
                let ackByName = FirestoreHelper.getString(fields["acknowledgedByName"] as? [String: Any])
                let hdAckAt = FirestoreHelper.getInt64(fields["helpdeskAcknowledgedAt"] as? [String: Any])
                let hdAckBy = FirestoreHelper.getString(fields["helpdeskAcknowledgedBy"] as? [String: Any])
                let rawMethod = FirestoreHelper.getString(fields["handlingMethod"] as? [String: Any])
                let rawStatus = FirestoreHelper.getString(fields["status"] as? [String: Any]).uppercased()
                let ack = ackBool || ackAt > 0 || !ackBy.isEmpty || !rawMethod.isEmpty || ["PROCESSING", "IN_PROGRESS", "ASSIGNED", "RESOLVED", "CLOSED"].contains(rawStatus)

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

                // Parse tracking if any
                var parsedTracking: TicketTracking? = nil
                if let tMap = fields["tracking"] as? [String: Any], let tFields = (tMap["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                    var routeCoords: [[Double]] = []
                    if let rArr = (tFields["routeCoordinates"] as? [String: Any])?["arrayValue"] as? [String: Any],
                       let rVals = rArr["values"] as? [[String: Any]] {
                        for v in rVals {
                            if let vm = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                                let lat = FirestoreHelper.getDouble(vm["lat"] as? [String: Any])
                                let lng = FirestoreHelper.getDouble(vm["lng"] as? [String: Any])
                                if lat != 0 && lng != 0 {
                                    routeCoords.append([lat, lng])
                                }
                            }
                        }
                    }
                    parsedTracking = TicketTracking(
                        ticketId: FirestoreHelper.getString(tFields["ticketId"] as? [String: Any]),
                        technicianEmail: FirestoreHelper.getString(tFields["technicianEmail"] as? [String: Any]),
                        technicianName: FirestoreHelper.getString(tFields["technicianName"] as? [String: Any]),
                        technicianPhone: FirestoreHelper.getString(tFields["technicianPhone"] as? [String: Any]),
                        currentLat: FirestoreHelper.getDouble(tFields["currentLat"] as? [String: Any]),
                        currentLng: FirestoreHelper.getDouble(tFields["currentLng"] as? [String: Any]),
                        speedKmh: Float(FirestoreHelper.getDouble(tFields["speedKmh"] as? [String: Any])),
                        heading: Float(FirestoreHelper.getDouble(tFields["heading"] as? [String: Any])),
                        startLat: FirestoreHelper.getDouble(tFields["startLat"] as? [String: Any]),
                        startLng: FirestoreHelper.getDouble(tFields["startLng"] as? [String: Any]),
                        startAddress: FirestoreHelper.getString(tFields["startAddress"] as? [String: Any]),
                        startName: FirestoreHelper.getString(tFields["startName"] as? [String: Any]),
                        destLat: FirestoreHelper.getDouble(tFields["destLat"] as? [String: Any]),
                        destLng: FirestoreHelper.getDouble(tFields["destLng"] as? [String: Any]),
                        destAddress: FirestoreHelper.getString(tFields["destAddress"] as? [String: Any]),
                        destName: FirestoreHelper.getString(tFields["destName"] as? [String: Any]),
                        distanceKm: FirestoreHelper.getDouble(tFields["distanceKm"] as? [String: Any]),
                        traveledDistanceKm: FirestoreHelper.getDouble(tFields["traveledDistanceKm"] as? [String: Any]),
                        etaMinutes: FirestoreHelper.getInt(tFields["etaMinutes"] as? [String: Any]),
                        status: FirestoreHelper.getString(tFields["status"] as? [String: Any]),
                        lastUpdatedAt: FirestoreHelper.getInt64(tFields["lastUpdatedAt"] as? [String: Any]),
                        isGpsLost: FirestoreHelper.getBool(tFields["isGpsLost"] as? [String: Any]),
                        lastGpsLostAt: FirestoreHelper.getInt64(tFields["lastGpsLostAt"] as? [String: Any]),
                        isArrivedVerified: FirestoreHelper.getBool(tFields["isArrivedVerified"] as? [String: Any]),
                        cancelledBy: FirestoreHelper.getString(tFields["cancelledBy"] as? [String: Any]),
                        cancelReason: FirestoreHelper.getString(tFields["cancelReason"] as? [String: Any]),
                        cancelledAt: FirestoreHelper.getInt64(tFields["cancelledAt"] as? [String: Any]),
                        routeCoordinates: routeCoords
                    )
                }

                // Parse coTechnicians if any
                var parsedCoTechs: [CoTechnician] = []
                if let coArr = (fields["coTechnicians"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let coVals = coArr["values"] as? [[String: Any]] {
                    for cv in coVals {
                        if let cm = (cv["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                            let email = FirestoreHelper.getString(cm["email"] as? [String: Any])
                            if !email.isEmpty {
                                parsedCoTechs.append(CoTechnician(
                                    email: email,
                                    name: FirestoreHelper.getString(cm["name"] as? [String: Any]),
                                    phone: FirestoreHelper.getString(cm["phone"] as? [String: Any]),
                                    role: FirestoreHelper.getString(cm["role"] as? [String: Any]),
                                    assignedAt: FirestoreHelper.getInt64(cm["assignedAt"] as? [String: Any]),
                                    assignedBy: FirestoreHelper.getString(cm["assignedBy"] as? [String: Any]),
                                    isAcknowledged: FirestoreHelper.getBool(cm["isAcknowledged"] as? [String: Any]),
                                    acknowledgedAt: FirestoreHelper.getInt64(cm["acknowledgedAt"] as? [String: Any])
                                ))
                            }
                        }
                    }
                }

                // Parse collaboratorTrackings if any
                var parsedCollabs: [String: TicketTracking] = [:]
                if let cMap = (fields["collaboratorTrackings"] as? [String: Any])?["mapValue"] as? [String: Any],
                   let cFields = cMap["fields"] as? [String: Any] {
                    for (k, v) in cFields {
                        if let vm = (v as? [String: Any])?["mapValue"] as? [String: Any],
                           let vFields = vm["fields"] as? [String: Any] {
                            var cRouteCoords: [[Double]] = []
                            if let rArr = (vFields["routeCoordinates"] as? [String: Any])?["arrayValue"] as? [String: Any],
                               let rVals = rArr["values"] as? [[String: Any]] {
                                for rv in rVals {
                                    if let rm = (rv["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                                        let lat = FirestoreHelper.getDouble(rm["lat"] as? [String: Any])
                                        let lng = FirestoreHelper.getDouble(rm["lng"] as? [String: Any])
                                        if lat != 0 && lng != 0 {
                                            cRouteCoords.append([lat, lng])
                                        }
                                    }
                                }
                            }

                            parsedCollabs[k] = TicketTracking(
                                ticketId: FirestoreHelper.getString(vFields["ticketId"] as? [String: Any]),
                                technicianEmail: FirestoreHelper.getString(vFields["technicianEmail"] as? [String: Any]),
                                technicianName: FirestoreHelper.getString(vFields["technicianName"] as? [String: Any]),
                                technicianPhone: FirestoreHelper.getString(vFields["technicianPhone"] as? [String: Any]),
                                currentLat: FirestoreHelper.getDouble(vFields["currentLat"] as? [String: Any]),
                                currentLng: FirestoreHelper.getDouble(vFields["currentLng"] as? [String: Any]),
                                speedKmh: Float(FirestoreHelper.getDouble(vFields["speedKmh"] as? [String: Any])),
                                heading: Float(FirestoreHelper.getDouble(vFields["heading"] as? [String: Any])),
                                startLat: FirestoreHelper.getDouble(vFields["startLat"] as? [String: Any]),
                                startLng: FirestoreHelper.getDouble(vFields["startLng"] as? [String: Any]),
                                startAddress: FirestoreHelper.getString(vFields["startAddress"] as? [String: Any]),
                                startName: FirestoreHelper.getString(vFields["startName"] as? [String: Any]),
                                destLat: FirestoreHelper.getDouble(vFields["destLat"] as? [String: Any]),
                                destLng: FirestoreHelper.getDouble(vFields["destLng"] as? [String: Any]),
                                destAddress: FirestoreHelper.getString(vFields["destAddress"] as? [String: Any]),
                                destName: FirestoreHelper.getString(vFields["destName"] as? [String: Any]),
                                distanceKm: FirestoreHelper.getDouble(vFields["distanceKm"] as? [String: Any]),
                                traveledDistanceKm: FirestoreHelper.getDouble(vFields["traveledDistanceKm"] as? [String: Any]),
                                etaMinutes: FirestoreHelper.getInt(vFields["etaMinutes"] as? [String: Any]),
                                status: FirestoreHelper.getString(vFields["status"] as? [String: Any]),
                                lastUpdatedAt: FirestoreHelper.getInt64(vFields["lastUpdatedAt"] as? [String: Any]),
                                isGpsLost: FirestoreHelper.getBool(vFields["isGpsLost"] as? [String: Any]),
                                lastGpsLostAt: FirestoreHelper.getInt64(vFields["lastGpsLostAt"] as? [String: Any]),
                                isArrivedVerified: FirestoreHelper.getBool(vFields["isArrivedVerified"] as? [String: Any]),
                                cancelledBy: FirestoreHelper.getString(vFields["cancelledBy"] as? [String: Any]),
                                cancelReason: FirestoreHelper.getString(vFields["cancelReason"] as? [String: Any]),
                                cancelledAt: FirestoreHelper.getInt64(vFields["cancelledAt"] as? [String: Any]),
                                routeCoordinates: cRouteCoords
                            )
                        }
                    }
                }

                // Parse handoverHistory if any
                var parsedHandoverHistory: [HandoverRecord] = []
                if let hoArr = (fields["handoverHistory"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let hoVals = hoArr["values"] as? [[String: Any]] {
                    for hv in hoVals {
                        if let hm = (hv["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                            let handoverId = FirestoreHelper.getString(hm["handoverId"] as? [String: Any])
                            let fromEmail = FirestoreHelper.getString(hm["fromEmail"] as? [String: Any])
                            let fromName = FirestoreHelper.getString(hm["fromName"] as? [String: Any])
                            let fromTitle = FirestoreHelper.getString(hm["fromTitle"] as? [String: Any])
                            let toType = FirestoreHelper.getString(hm["toType"] as? [String: Any])
                            let toEmail = FirestoreHelper.getString(hm["toEmail"] as? [String: Any])
                            let toName = FirestoreHelper.getString(hm["toName"] as? [String: Any])
                            let toTitle = FirestoreHelper.getString(hm["toTitle"] as? [String: Any])
                            let toCluster = FirestoreHelper.getString(hm["toCluster"] as? [String: Any])
                            let reason = FirestoreHelper.getString(hm["reason"] as? [String: Any])
                            let timestamp = FirestoreHelper.getInt64(hm["timestamp"] as? [String: Any])

                            parsedHandoverHistory.append(HandoverRecord(
                                handoverId: handoverId.isEmpty ? UUID().uuidString : handoverId,
                                fromEmail: fromEmail,
                                fromName: fromName,
                                fromTitle: fromTitle.isEmpty ? "KTV" : fromTitle,
                                toType: toType,
                                toEmail: toEmail,
                                toName: toName,
                                toTitle: toTitle.isEmpty ? "KTV" : toTitle,
                                toCluster: toCluster,
                                reason: reason,
                                timestamp: timestamp
                            ))
                        }
                    }
                }

                return SupportTicket(
                    id: id,
                    ticketCode: FirestoreHelper.getString(fields["ticketCode"] as? [String: Any]),
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
                    coTechnicians: parsedCoTechs,
                    tracking: parsedTracking,
                    collaboratorTrackings: parsedCollabs,
                    isAcknowledged: ack,
                    acknowledgedAt: ackAt,
                    acknowledgedBy: ackBy,
                    acknowledgedByName: ackByName,
                    helpdeskAcknowledgedAt: hdAckAt,
                    helpdeskAcknowledgedBy: hdAckBy,
                    resolvedAt: FirestoreHelper.getInt64(fields["resolvedAt"] as? [String: Any]),
                    resolvedBy: FirestoreHelper.getString(fields["resolvedBy"] as? [String: Any]),
                    resolvedByName: FirestoreHelper.getString(fields["resolvedByName"] as? [String: Any]),
                    resolutionNote: FirestoreHelper.getString(fields["resolutionNote"] as? [String: Any]),
                    resolvedReason: FirestoreHelper.getString(fields["resolvedReason"] as? [String: Any]),
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
                    handoverHistory: parsedHandoverHistory,
                    assignedApplication: FirestoreHelper.getString(fields["assignedApplication"] as? [String: Any]),
                    assignedRole: FirestoreHelper.getString(fields["assignedRole"] as? [String: Any]),
                    scope: FirestoreHelper.getString(fields["scope"] as? [String: Any]),
                    toNghiepVu: FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any])
                )
            }

            let sortedTickets = parsed.sorted { $0.lastMessageAt.coerceAtLeast($0.createdAt) > $1.lastMessageAt.coerceAtLeast($1.createdAt) }
            await MainActor.run {
                if showSpinner {
                    self.rawTickets = sortedTickets
                } else {
                    var ticketMap = [String: SupportTicket]()
                    for t in self.rawTickets {
                        ticketMap[t.id] = t
                    }
                    for t in sortedTickets {
                        ticketMap[t.id] = t
                    }
                    self.rawTickets = Array(ticketMap.values).sorted {
                        $0.lastMessageAt.coerceAtLeast($0.createdAt) > $1.lastMessageAt.coerceAtLeast($1.createdAt)
                    }
                }
                if showSpinner {
                    self.isLoading = false
                }
                VoiceNotificationHelper.shared.processTicketUpdates(tickets: self.rawTickets, currentUser: self.user)
                VoiceNotificationHelper.shared.syncAdminConfig(companyId: self.companyId, idToken: self.idToken)

                let autoRateCandidates = self.scopedTickets.filter { $0.isAutoRateEligible }
                if !autoRateCandidates.isEmpty {
                    self.checkAndApplyAutoRatings(candidates: autoRateCandidates)
                }
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
        attachments: [AttachmentItem] = [],
        donVi: String = ""
    ) async -> String? {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date()) % 100
        let month = calendar.component(.month, from: Date())
        let yymm = String(format: "%02d%02d", year, month)
        let randNum = Int.random(in: 1000...9999)
        let generatedTicketCode = "APP-\(yymm)-\(randNum)"

        let effectiveDonVi = !donVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? donVi : user.donVi

        var fields: [String: Any] = [
            "ticketCode": ["stringValue": generatedTicketCode],
            "subject": ["stringValue": subject],
            "initialMessage": ["stringValue": initialMessage],
            "lastMessage": ["stringValue": initialMessage],
            "category": ["stringValue": category],
            "priority": ["stringValue": priority],
            "status": ["stringValue": "OPEN"],
            "creatorEmail": ["stringValue": user.email],
            "creatorName": ["stringValue": !user.fullName.isEmpty ? user.fullName : user.email],
            "creatorPhone": ["stringValue": user.phone],
            "donVi": ["stringValue": effectiveDonVi],
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
        if !attachments.isEmpty {
            fields["attachments"] = ["arrayValue": ["values": attachments.map { att in
                var attMap: [String: Any] = [
                    "name": ["stringValue": att.name],
                    "url": ["stringValue": att.url],
                    "size": ["integerValue": String(att.size)],
                    "type": ["stringValue": att.type],
                    "uploadedAt": ["integerValue": String(att.uploadedAt)]
                ]
                if !att.id.isEmpty { attMap["id"] = ["stringValue": att.id] }
                return ["mapValue": ["fields": attMap]]
            }]]
        }

        // TỰ ĐỘNG ĐIỀU PHỐI NGOÀI GIỜ / NGÀY NGHỈ LỄ THEO CỤM SỞ TẠI
        let offHoursCheck = WorkingHoursHelper.isHelpdeskOffHours(date: Date(), slaConfig: self.slaConfig)
        var autoDispatchedTech: AutoDispatchedTechnician? = nil

        if self.slaConfig.enableAutoDispatchOffHours && !offHoursCheck.isBusinessHours {
            let targetCluster = WorkingHoursHelper.resolveUnitCluster(units: self.companyUnits, donViName: effectiveDonVi)
            var workloadMap: [String: Int] = [:]
            for ktv in self.ktvTechnicians {
                workloadMap[ktv.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = getActiveTicketCount(email: ktv.email)
            }
            autoDispatchedTech = WorkingHoursHelper.findDutyTechnician(
                check: offHoursCheck,
                ktvList: self.ktvTechnicians,
                targetCluster: targetCluster,
                workloadMap: workloadMap
            )
            if let auto = autoDispatchedTech {
                fields["status"] = ["stringValue": "ASSIGNED"]
                fields["assignedDepartmentId"] = ["stringValue": auto.departmentId]
                fields["assignedDepartmentName"] = ["stringValue": auto.departmentName]
                fields["assignedToEmail"] = ["stringValue": auto.email]
                fields["assignedToName"] = ["stringValue": auto.name]
                fields["assignedCluster"] = ["stringValue": auto.assignedCluster]
                fields["assignedRole"] = ["stringValue": "TECH"]
                fields["assignedAt"] = ["integerValue": String(now)]
                fields["assignedByEmail"] = ["stringValue": "system_auto_dispatcher@qltb.vn"]
                fields["dispatchNote"] = ["stringValue": auto.dispatchNote]
                fields["scope"] = ["stringValue": "TECHNICAL"]
                fields["assignedTechnicianEmails"] = ["arrayValue": ["values": [["stringValue": auto.email]]]]
            }
        }

        let body: [String: Any] = ["fields": fields]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else { return nil }

        let id = name.components(separatedBy: "/").last ?? ""

        // Also add the first message into messages subcollection (earlier timestamp ensures it always shows above dispatch)
        let initTs = Int64(Date().timeIntervalSince1970 * 1000) - 1000
        sendMessage(ticketId: id, text: initialMessage, customTimestamp: initTs)

        // Ghi nhận log tin nhắn hệ thống nếu ticket được tự động điều phối ngoài giờ
        if let auto = autoDispatchedTech {
            let escMin = self.slaConfig.escalationTimeoutMinutes > 0 ? self.slaConfig.escalationTimeoutMinutes : 15
            let autoDispatchMsg = """
            ⏰ [TỰ ĐỘNG ĐIỀU PHỐI NGOÀI GIỜ]
            Sự cố phát sinh ngoài giờ trực của HelpDesk (\(offHoursCheck.reason)).
            Hệ thống đã tự động gán vé cho KTV \(auto.name) thuộc Cụm \(auto.assignedCluster).
            ⏱️ Vui lòng xác nhận tiếp nhận trong vòng \(escMin) phút.
            """
            sendMessage(ticketId: id, text: autoDispatchMsg, isSystemMessage: true, customTimestamp: now + 500)
        }

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
                attachments: attachments,
                donVi: donVi
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

            guard let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let documents = json["documents"] as? [[String: Any]] else {
                return
            }

            let msgs: [SupportMessage] = documents.compactMap { doc in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""

                // Parse attachments (arrayValue của URL strings từ Cloudinary)
                let attachmentItems: [AttachmentItem] = {
                    guard let arrVal = fields["attachments"] as? [String: Any],
                          let arr = arrVal["arrayValue"] as? [String: Any],
                          let vals = arr["values"] as? [[String: Any]] else { return [] }
                    return vals.compactMap { item -> AttachmentItem? in
                        let urlStr = FirestoreHelper.getString(item["stringValue"] as? [String: Any] ?? item)
                        guard !urlStr.isEmpty, let _ = URL(string: urlStr) else { return nil }
                        let ext = (urlStr as NSString).pathExtension.lowercased()
                        let isImg = ["png", "jpg", "jpeg", "webp", "bmp"].contains(ext)
                        return AttachmentItem(name: urlStr.components(separatedBy: "/").last ?? "file", url: urlStr, type: isImg ? "image" : "file")
                    }
                }()

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
                    isInternal: FirestoreHelper.getBool(fields["isInternal"] as? [String: Any]),
                    attachments: attachmentItems
                )
            }

            let curTicket = self.tickets.first(where: { $0.id == ticketId })
            let cEmail = (curTicket?.creatorEmail ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let cInitMsg = curTicket?.initialMessage ?? ""

            let sortedMsgs = msgs.sorted { a, b in
                let aIsCreator = (!a.isSystemMessage && !a.isAdminReply) && (a.senderEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cEmail || (!cInitMsg.isEmpty && a.message == cInitMsg))
                let bIsCreator = (!b.isSystemMessage && !b.isAdminReply) && (b.senderEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == cEmail || (!cInitMsg.isEmpty && b.message == cInitMsg))
                let aIsDispatch = (a.isSystemMessage || a.isAdminReply) && (a.message.contains("Điều phối") || a.message.contains("Chuyển giao tới"))
                let bIsDispatch = (b.isSystemMessage || b.isAdminReply) && (b.message.contains("Điều phối") || b.message.contains("Chuyển giao tới"))

                if aIsCreator && bIsDispatch && abs(a.timestamp - b.timestamp) <= 600_000 {
                    return true
                } else if bIsCreator && aIsDispatch && abs(a.timestamp - b.timestamp) <= 600_000 {
                    return false
                }
                return a.timestamp < b.timestamp
            }

            await MainActor.run {
                self.messages = sortedMsgs
            }
        }
    }

    public func updateTicketCategory(ticketId: String, newCategory: String, completion: ((Bool) -> Void)? = nil) {
        // Optimistic UI update
        if let idx = tickets.firstIndex(where: { $0.id == ticketId }) {
            var updated = tickets[idx]
            updated.category = newCategory
            tickets[idx] = updated
        }
        Task {
            let mask = "updateMask.fieldPaths=category"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let f: [String: Any] = ["category": ["stringValue": newCategory]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            let resp = await FirestoreHelper.executeSafeRequest(request)
            let isSuccess = resp != nil && (resp!.1.statusCode >= 200 && resp!.1.statusCode < 300)
            DispatchQueue.main.async { completion?(isSuccess) }
        }
    }

    public func updateTicketPriority(ticketId: String, newPriority: String, completion: ((Bool) -> Void)? = nil) {
        let cleanPriority = newPriority.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let priorityLabel: String = {
            switch cleanPriority {
            case "urgent": return "Khẩn cấp"
            case "high": return "Cần gấp"
            case "normal": return "Thường"
            case "low": return "Thấp"
            default: return cleanPriority.uppercased()
            }
        }()
        // Optimistic UI update
        if let idx = tickets.firstIndex(where: { $0.id == ticketId }) {
            var updated = tickets[idx]
            updated.priority = cleanPriority
            tickets[idx] = updated
        }
        if let idx = rawTickets.firstIndex(where: { $0.id == ticketId }) {
            var updated = rawTickets[idx]
            updated.priority = cleanPriority
            rawTickets[idx] = updated
        }
        Task {
            let mask = "updateMask.fieldPaths=priority"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let f: [String: Any] = ["priority": ["stringValue": cleanPriority]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            let resp = await FirestoreHelper.executeSafeRequest(request)
            let isSuccess = resp != nil && (resp!.1.statusCode >= 200 && resp!.1.statusCode < 300)
            if isSuccess {
                let msg = "⚡ [Ưu tiên SLA] Đã cập nhật mức độ ưu tiên thành: \(priorityLabel)"
                let sender = (!user.fullName.isEmpty && user.fullName.lowercased() != "admin" && user.fullName.lowercased() != "user") ? user.fullName : "Bộ phận HelpDesk"
                sendMessage(ticketId: ticketId, text: msg, customSenderName: sender, isSystemMessage: true)
                self.fetchTickets()
            }
            DispatchQueue.main.async { completion?(isSuccess) }
        }
    }

    public func sendMessage(
        ticketId: String,
        text: String,
        isInternal: Bool = false,
        attachmentUrls: [String] = [],
        customSenderName: String? = nil,
        isSystemMessage: Bool = false,
        customTimestamp: Int64? = nil
    ) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty || !attachmentUrls.isEmpty else { return }

        isSendingMessage = true
        Task {
            let now = customTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)/messages"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Build attachments arrayValue nếu có file đính kèm
            let attachmentsField: [String: Any] = attachmentUrls.isEmpty ? [:] : [
                "attachments": [
                    "arrayValue": [
                        "values": attachmentUrls.map { ["stringValue": $0] }
                    ]
                ]
            ]

            let effectiveSenderName = customSenderName ?? (!user.fullName.isEmpty ? user.fullName : user.email)
            let effectiveSenderEmail = isSystemMessage ? "system@sgcoop.com" : user.email
            var fields: [String: Any] = [
                "senderEmail": ["stringValue": effectiveSenderEmail],
                "senderName": ["stringValue": effectiveSenderName],
                "message": ["stringValue": cleanText.isEmpty ? "📎 Đã gửi \(attachmentUrls.count) tệp đính kèm" : cleanText],
                "timestamp": ["integerValue": String(now)],
                "isAdminReply": ["booleanValue": user.isAdmin || user.isHelpDesk || user.isTechnician || user.isSpecialist],
                "donVi": ["stringValue": user.donVi],
                "departmentId": ["stringValue": user.departmentId],
                "isInternal": ["booleanValue": isInternal],
                "isSystemMessage": ["booleanValue": isSystemMessage]
            ]
            for (k, v) in attachmentsField { fields[k] = v }

            let body: [String: Any] = ["fields": fields]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            // Update ticket lastMessage & lastMessageAt
            let lastMsg = cleanText.isEmpty ? "📎 Đính kèm \(attachmentUrls.count) tệp" : cleanText
            let patchUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            if let patchUrl = URL(string: patchUrlStr) {
                var pReq = URLRequest(url: patchUrl)
                pReq.httpMethod = "PATCH"
                pReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                pReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let pBody: [String: Any] = [
                    "fields": [
                        "lastMessage": ["stringValue": lastMsg],
                        "lastMessageAt": ["integerValue": String(now)]
                    ]
                ]
                pReq.httpBody = try? JSONSerialization.data(withJSONObject: pBody)
                _ = await FirestoreHelper.executeSafeRequest(pReq)
            }

            await MainActor.run {
                self.isSendingMessage = false
                self.fetchMessages(for: ticketId)
            }
        }
    }

    // MARK: - KTV / SPECIALIST TIẾP NHẬN / PHƯƠNG ÁN XỬ LÝ (ĐỒNG BỘ 1:1 ANDROID)
    public func acknowledgeTicket(ticketId: String) {
        VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
        let ticket = rawTickets.first { $0.id == ticketId }
        if let t = ticket {
            if t.status.uppercased() == "CLOSED" || t.closedAt > 0 || t.status.uppercased() == "RESOLVED" || t.resolvedAt > 0 {
                print("[SupportVM] Ticket \(ticketId) is already CLOSED or RESOLVED, cannot acknowledge.")
                return
            }
            if t.isAcknowledged || t.acknowledgedAt > 0 {
                print("[SupportVM] Ticket \(ticketId) is already acknowledged, skipping duplicate acknowledge.")
                return
            }
        }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let isClaiming = (ticket?.assignedToEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            var maskFields = [
                "isAcknowledged", "acknowledged", "acknowledgedAt", "acknowledgedBy", "acknowledgedByName"
            ]
            if isClaiming {
                maskFields.append(contentsOf: ["assignedTo", "assignedToEmail", "assignedToName", "assignedRole"])
            }
            let maskStr = maskFields.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var f: [String: Any] = [
                "isAcknowledged": ["booleanValue": true],
                "acknowledged": ["booleanValue": true],
                "acknowledgedAt": ["integerValue": String(now)],
                "acknowledgedBy": ["stringValue": user.email],
                "acknowledgedByName": ["stringValue": user.fullName]
            ]
            if isClaiming {
                f["assignedTo"] = ["stringValue": user.email]
                f["assignedToEmail"] = ["stringValue": user.email]
                f["assignedToName"] = ["stringValue": user.fullName]
                f["assignedRole"] = ["stringValue": (ticket?.isSpecialistAssigned == true || user.isSpecialist) ? "SPECIALIST" : "TECH"]
            }

            let body: [String: Any] = ["fields": f]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            let isSpecialist = ticket?.isSpecialistAssigned == true || (ticket?.assignedRole.uppercased() == "SPECIALIST") || (user.isSpecialist && ticket?.assignedRole.uppercased() != "TECH")
            let rolePrefix = isSpecialist ? "Chuyên viên" : "KTV"
            let ackMsg = "🎯 [Tiếp nhận ca] \(rolePrefix) \(user.fullName) đã tiếp nhận xử lý sự cố."
            sendMessage(ticketId: ticketId, text: ackMsg, isSystemMessage: true)
            self.fetchTickets()
        }
    }

    public func selectHandlingMethod(ticketId: String, method: String, completion: ((Bool) -> Void)? = nil) {
        VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
        let ticket = rawTickets.first { $0.id == ticketId }
        if let t = ticket {
            if t.status.uppercased() == "CLOSED" || t.closedAt > 0 || t.status.uppercased() == "RESOLVED" || t.resolvedAt > 0 {
                print("[SupportVM] Ticket \(ticketId) is already CLOSED or RESOLVED, cannot select handling method.")
                completion?(false)
                return
            }
            if t.isAcknowledged && t.handlingMethod.uppercased() == method.uppercased() {
                print("[SupportVM] Ticket \(ticketId) already selected method \(method), skipping duplicate.")
                completion?(true)
                return
            }
        }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let isClaiming = (ticket?.assignedToEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            var maskFields = [
                "handlingMethod", "handlingMethodUpdatedAt",
                "isAcknowledged", "acknowledged", "acknowledgedAt",
                "acknowledgedBy", "acknowledgedByName"
            ]
            if isClaiming {
                maskFields.append(contentsOf: ["assignedTo", "assignedToEmail", "assignedToName", "assignedRole"])
            }
            let maskStr = maskFields.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            var f: [String: Any] = [
                "handlingMethod": ["stringValue": method],
                "handlingMethodUpdatedAt": ["integerValue": String(now)],
                "isAcknowledged": ["booleanValue": true],
                "acknowledged": ["booleanValue": true],
                "acknowledgedAt": ["integerValue": String(now)],
                "acknowledgedBy": ["stringValue": user.email],
                "acknowledgedByName": ["stringValue": user.fullName]
            ]
            if isClaiming {
                f["assignedTo"] = ["stringValue": user.email]
                f["assignedToEmail"] = ["stringValue": user.email]
                f["assignedToName"] = ["stringValue": user.fullName]
                f["assignedRole"] = ["stringValue": (ticket?.isSpecialistAssigned == true || user.isSpecialist) ? "SPECIALIST" : "TECH"]
            }

            let body: [String: Any] = ["fields": f]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            let isSpecialist = ticket?.isSpecialistAssigned == true || (ticket?.assignedRole.uppercased() == "SPECIALIST") || (user.isSpecialist && ticket?.assignedRole.uppercased() != "TECH")
            let rolePrefix = isSpecialist ? "Chuyên viên" : "KTV"
            let donViText = !(ticket?.donVi ?? "").isEmpty ? " (\(ticket!.donVi))" : ""
            let modeText = method == "REMOTE" ? "XỬ LÝ TỪ XA (UltraViewer / ĐT)" : "DI CHUYỂN ĐẾN ĐƠN VỊ\(donViText)"
            let icon = method == "REMOTE" ? "💻" : "🛵"
            let msg = "\(icon) [Tiếp nhận ca] \(rolePrefix) \(user.fullName) đã chọn phương án: \(modeText)."
            sendMessage(ticketId: ticketId, text: msg, isSystemMessage: true)
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
            _ = await FirestoreHelper.executeSafeRequest(request)

            let ticket = rawTickets.first { $0.id == ticketId }
            let isSpecialist = ticket?.isSpecialistAssigned == true || (ticket?.assignedRole.uppercased() == "SPECIALIST") || (user.isSpecialist && ticket?.assignedRole.uppercased() != "TECH")
            let rolePrefix = isSpecialist ? "Chuyên viên" : "KTV"
            let msg = "🛠️ \(rolePrefix) \(user.fullName) báo cáo ĐÃ XỬ LÝ XONG: \(note). Mời bạn nghiệm thu & đánh giá chất lượng."
            sendMessage(ticketId: ticketId, text: msg)

            // Tự động gửi Email nghiệm thu & 1-Click Rating nếu đủ điều kiện
            Task {
                await self.trySendResolutionEmail(ticketId: ticketId)
            }

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
            _ = await FirestoreHelper.executeSafeRequest(request)

            let closeMsg = !note.isEmpty ? "🔒 Yêu cầu hỗ trợ đã được đóng bởi \(user.fullName): \(note)" : "🔒 Yêu cầu hỗ trợ đã được đóng bởi \(user.fullName)."
            sendMessage(ticketId: ticketId, text: closeMsg)

            // Tự động gửi Email nghiệm thu & 1-Click Rating nếu đủ điều kiện (Đồng bộ 100% Android & Desktop)
            Task {
                await self.trySendResolutionEmail(ticketId: ticketId)
            }

            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - TỰ ĐỘNG GỬI EMAIL NGHIỆM THU & 1-CLICK RATING (ĐỒNG BỘ ANDROID)
    public func trySendResolutionEmail(ticketId: String) async {
        guard let ticket = rawTickets.first(where: { $0.id == ticketId }) else { return }
        let recipientEmail = (!ticket.creatorEmail.isEmpty ? ticket.creatorEmail : ticket.externalSenderId)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard recipientEmail.contains("@"), !ticket.ratingEmailSent else { return }

        guard let emailCfg = await fetchCompanyEmailConfig(),
              emailCfg.autoSendRatingEmailOnClose && emailCfg.isConfigured else { return }

        let res = await IosEmailSender.sendResolutionRatingEmail(ticket: ticket, config: emailCfg)
        switch res {
        case .success:
            let nowTime = Int64(Date().timeIntervalSince1970 * 1000)
            let updateUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=ratingEmailSent&updateMask.fieldPaths=ratingEmailSentAt"
            if let u = URL(string: updateUrl) {
                var req = URLRequest(url: u)
                req.httpMethod = "PATCH"
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let body: [String: Any] = [
                    "fields": [
                        "ratingEmailSent": ["booleanValue": true],
                        "ratingEmailSentAt": ["integerValue": String(nowTime)]
                    ]
                ]
                req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                _ = await FirestoreHelper.executeSafeRequest(req)
            }

            let auditMsg = "✉️ [Hệ thống]: Đã tự động gửi email nghiệm thu & liên kết đánh giá 1-Click Rating tới \(recipientEmail)."
            self.sendMessage(ticketId: ticketId, text: auditMsg)
        case .failure(let err):
            print("[SupportVM] Không thể gửi email nghiệm thu trên iOS: \(err.localizedDescription)")
        }
    }

    public func fetchCompanyEmailConfig() async -> CompanyEmailConfig? {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return nil }

        // 1. Tìm cấu hình riêng của công ty: companies/{compId}/system_config/email_integration
        let compDocUrl = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/system_config/email_integration"
        if let u = URL(string: compDocUrl), let (data, resp) = await FirestoreHelper.safeGet(url: u, idToken: idToken), resp == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let cfg = CompanyEmailConfig.fromFirestore(fields)
                if cfg.isConfigured { return cfg }
            }
        }

        // 2. Fallback: Cấu hình dùng chung toàn hệ thống /system_config/email_integration
        let globalDocUrl = "\(FirebaseConfig.firestoreBaseUrl)/system_config/email_integration"
        if let u = URL(string: globalDocUrl), let (data, resp) = await FirestoreHelper.safeGet(url: u, idToken: idToken), resp == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let cfg = CompanyEmailConfig.fromFirestore(fields)
                if cfg.isConfigured { return cfg }
            }
        }

        return nil
    }

    // MARK: - TỪ CHỐI TICKET (ĐỒNG BỘ 1:1 VỚI rejectTicket TRÊN ANDROID)
    public func rejectTicket(ticketId: String, reason: String, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let finalReason = reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yêu cầu không phù hợp" : reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let roleTitle = user.isAdmin ? "Admin" : (user.isHelpDesk ? "HelpDesk" : (user.isManager ? "Quản lý phòng ban" : "HelpDesk"))
            let name = !user.fullName.isEmpty ? user.fullName : user.email
            let finalRejectMsg = "🚫 [\(roleTitle): \(name)] Đã đóng yêu cầu (Không phù hợp): \(finalReason)"

            var mask = "updateMask.fieldPaths=status"
            mask += "&updateMask.fieldPaths=isInvalid"
            mask += "&updateMask.fieldPaths=invalidReason"
            mask += "&updateMask.fieldPaths=isAutoRated"
            mask += "&updateMask.fieldPaths=rating"
            mask += "&updateMask.fieldPaths=ratingRequested"
            mask += "&updateMask.fieldPaths=lastMessage"
            mask += "&updateMask.fieldPaths=lastMessageAt"
            mask += "&updateMask.fieldPaths=closedByEmail"
            mask += "&updateMask.fieldPaths=closedByName"
            mask += "&updateMask.fieldPaths=closedByRole"
            mask += "&updateMask.fieldPaths=closedAt"

            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let fields: [String: Any] = [
                "status": ["stringValue": "CLOSED"],
                "isInvalid": ["booleanValue": true],
                "invalidReason": ["stringValue": finalReason],
                "isAutoRated": ["booleanValue": false],
                "rating": ["integerValue": "0"],
                "ratingRequested": ["booleanValue": false],
                "lastMessage": ["stringValue": finalRejectMsg],
                "lastMessageAt": ["integerValue": String(now)],
                "closedByEmail": ["stringValue": user.email],
                "closedByName": ["stringValue": name],
                "closedByRole": ["stringValue": user.role],
                "closedAt": ["integerValue": String(now)]
            ]

            let body: [String: Any] = ["fields": fields]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: finalRejectMsg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - REOPEN TICKET (MỞ LẠI SỰ CỐ)
    public func reopenTicket(ticketId: String, reason: String, completion: ((Bool) -> Void)? = nil) {
        guard isTicketReopenEnabled else {
            completion?(false)
            return
        }
        guard let ticket = rawTickets.first(where: { $0.id == ticketId }) else { completion?(false); return }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=reopenCount&updateMask.fieldPaths=reopenedAt&updateMask.fieldPaths=reopenedByEmail&updateMask.fieldPaths=reopenedByName&updateMask.fieldPaths=reopenReason&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=resolvedReason&updateMask.fieldPaths=rating&updateMask.fieldPaths=isQualityPassed&updateMask.fieldPaths=previousRating&updateMask.fieldPaths=previousFeedback"
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
                    "resolvedReason": ["stringValue": ""],
                    "rating": ["integerValue": "0"],
                    "isQualityPassed": ["booleanValue": false],
                    "previousRating": ["integerValue": String(ticket.rating)],
                    "previousFeedback": ["stringValue": ticket.feedback]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

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
            let satisfactionDesc: String = {
                switch rating {
                case 1: return "Rất không hài lòng"
                case 2: return "Không hài lòng"
                case 3: return "Bình thường"
                case 4: return "Hài lòng"
                default: return "Rất hài lòng"
                }
            }()
            let cleanFb = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
            let fbDetail = cleanFb.isEmpty ? satisfactionDesc : cleanFb
            let finalCloseMsg = "⭐ [Khách hàng đánh giá \(rating)/5★]: \(fbDetail). Phiếu hỗ trợ đã được đóng tự động."

            let fields = "updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt&updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=closedByName&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(fields)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "rating": ["integerValue": String(rating)],
                    "feedback": ["stringValue": cleanFb],
                    "feedbackAt": ["integerValue": String(now)],
                    "status": ["stringValue": "CLOSED"],
                    "closedAt": ["integerValue": String(now)],
                    "closedByEmail": ["stringValue": user.email],
                    "closedByName": ["stringValue": user.fullName],
                    "lastMessage": ["stringValue": finalCloseMsg],
                    "lastMessageAt": ["integerValue": String(now)]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            // Ghi nhận tin nhắn thông báo đánh giá vào cuộc hội thoại
            sendMessage(ticketId: ticketId, text: finalCloseMsg, customSenderName: "Hệ thống (Nghiệm thu)", isSystemMessage: true)

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
            _ = await FirestoreHelper.executeSafeRequest(request)

            let clusterMsg = cluster.isEmpty ? "" : " (Cụm: \(cluster))"
            let noteMsg = note.isEmpty ? "" : " - Ghi chú: \(note)"
            let msg = "📌 Ticket đã được điều phối cho KTV \(ktvName)\(clusterMsg)\(noteMsg)"
            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - ĐIỀU PHỐI TICKET ĐỒNG BỘ 1:1 ANDROID (assignTicket)
    public func assignTicket(
        ticketId: String,
        deptId: String,
        deptName: String,
        techEmail: String,
        techName: String,
        note: String = "",
        assignedCluster: String = "",
        assignedRegion: String = "",
        assignedApplication: String = "",
        assignedRole: String = "TECH",
        newPriority: String? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        if let t = rawTickets.first(where: { $0.id == ticketId }), t.status.uppercased() == "CLOSED" || t.closedAt > 0 {
            print("[SupportVM] Ticket \(ticketId) is already CLOSED, cannot assign.")
            completion?(false)
            return
        }
        if let t = rawTickets.first(where: { $0.id == ticketId }),
           t.assignedToEmail.caseInsensitiveCompare(techEmail) == .orderedSame,
           t.assignedDepartmentId.caseInsensitiveCompare(deptId) == .orderedSame,
           t.dispatchNote == note {
            print("[SupportVM] Ticket \(ticketId) already assigned to \(techEmail), skipping duplicate dispatch.")
            completion?(true)
            return
        }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let isSpecialist = assignedRole.uppercased() == "SPECIALIST" ||
                               deptId.hasPrefix("TO_") ||
                               SpecialistTeamDefaults.TEAMS.contains { $0.id.caseInsensitiveCompare(deptId) == .orderedSame }
            let rolePrefix = isSpecialist ? "Chuyên viên" : "KTV"
            let effectiveCluster = isSpecialist ? "" : assignedCluster
            let effectiveRegion = isSpecialist ? "" : assignedRegion

            let clusterRegionDetail: String
            if isSpecialist {
                clusterRegionDetail = ""
            } else if !effectiveCluster.isEmpty && !effectiveRegion.isEmpty && effectiveCluster.caseInsensitiveCompare(effectiveRegion) != .orderedSame {
                clusterRegionDetail = "thuộc Cụm \(effectiveCluster), Khu vực \(effectiveRegion)"
            } else if !effectiveCluster.isEmpty {
                clusterRegionDetail = "thuộc Cụm \(effectiveCluster)"
            } else if !effectiveRegion.isEmpty {
                clusterRegionDetail = "thuộc Khu vực \(effectiveRegion)"
            } else {
                clusterRegionDetail = ""
            }

            let rawTeamName: String
            if isSpecialist {
                let r1 = SpecialistTeamDefaults.resolveTeamDisplayName(deptId)
                let r2 = r1.isEmpty ? SpecialistTeamDefaults.resolveTeamDisplayName(deptName) : r1
                rawTeamName = r2.isEmpty ? deptName : r2
            } else {
                rawTeamName = deptName
            }

            let cleanTeam: String
            if isSpecialist && !rawTeamName.isEmpty {
                if rawTeamName.lowercased().hasPrefix("tổ ") || rawTeamName.lowercased().hasPrefix("khối ") {
                    cleanTeam = rawTeamName
                } else {
                    cleanTeam = "Tổ \(rawTeamName)"
                }
            } else {
                cleanTeam = ""
            }

            let teamDetail = !cleanTeam.isEmpty ? " (\(cleanTeam))" : ""
            let finalDeptName = (isSpecialist && !cleanTeam.isEmpty) ? cleanTeam : (deptName.isEmpty ? "IT TẬP TRUNG" : deptName)

            let techInfo: String
            if !techName.isEmpty {
                if isSpecialist && !teamDetail.isEmpty {
                    techInfo = " (\(rolePrefix): \(techName)\(teamDetail))"
                } else if !clusterRegionDetail.isEmpty {
                    techInfo = " (\(rolePrefix): \(techName) \(clusterRegionDetail))"
                } else {
                    techInfo = " (\(rolePrefix): \(techName))"
                }
            } else if !clusterRegionDetail.isEmpty {
                techInfo = " (\(clusterRegionDetail))"
            } else {
                techInfo = ""
            }

            let appInfo = !assignedApplication.isEmpty ? " • Ứng dụng: \(assignedApplication)" : ""
            let noteInfo = !note.isEmpty ? " • Ghi chú: \(note)" : ""
            let dispatchMsg = "🔄 [Điều phối] HelpDesk đã chuyển giao yêu cầu cho \(finalDeptName)\(techInfo)\(appInfo)\(noteInfo)"

            // Lấy ticket hiện tại để cập nhật coTechnicians và assignedTechnicianEmails
            let currentTicket = self.rawTickets.first { $0.id == ticketId }
            let existingCoTechs = (currentTicket?.coTechnicians ?? []).filter {
                $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != techEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            let existingCoTechEmails = existingCoTechs.map { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

            var allAssignedEmails: [String] = []
            let cleanTech = techEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanTech.isEmpty {
                allAssignedEmails.append(cleanTech)
            }
            for e in existingCoTechEmails {
                if !e.isEmpty && !allAssignedEmails.contains(e) {
                    allAssignedEmails.append(e)
                }
            }

            var maskFields = [
                "assignedDepartmentId", "assignedDepartmentName", "toNghiepVu",
                "assignedToEmail", "assignedToName", "assignedCluster", "assignedRegion",
                "assignedApplication", "assignedRole", "scope", "isSpecialistAssigned",
                "assignedByEmail", "assignedAt", "dispatchNote", "lastMessage", "lastMessageAt",
                "isAcknowledged", "acknowledged", "acknowledgedAt", "acknowledgedBy", "acknowledgedByName",
                "tracking", "coTechnicians", "assignedTechnicianEmails"
            ]
            let cleanNewPriority = (newPriority ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanNewPriority.isEmpty {
                maskFields.append("priority")
            }
            let maskStr = maskFields.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let coTechsValues: [[String: Any]] = existingCoTechs.map { co in
                return [
                    "mapValue": [
                        "fields": [
                            "email": ["stringValue": co.email],
                            "name": ["stringValue": co.name],
                            "phone": ["stringValue": co.phone],
                            "role": ["stringValue": co.role],
                            "assignedAt": ["integerValue": String(co.assignedAt)],
                            "assignedBy": ["stringValue": co.assignedBy],
                            "isAcknowledged": ["booleanValue": co.isAcknowledged],
                            "acknowledgedAt": ["integerValue": String(co.acknowledgedAt)]
                        ]
                    ]
                ]
            }

            let assignedEmailsValues: [[String: Any]] = allAssignedEmails.map { email in
                return ["stringValue": email]
            }

            var f: [String: Any] = [
                "assignedDepartmentId": ["stringValue": deptId],
                "assignedDepartmentName": ["stringValue": finalDeptName],
                "toNghiepVu": ["stringValue": isSpecialist ? deptId : ""],
                "assignedToEmail": ["stringValue": techEmail],
                "assignedToName": ["stringValue": techName],
                "assignedCluster": ["stringValue": effectiveCluster],
                "assignedRegion": ["stringValue": effectiveRegion],
                "assignedApplication": ["stringValue": assignedApplication],
                "assignedRole": ["stringValue": isSpecialist ? "SPECIALIST" : "TECH"],
                "scope": ["stringValue": isSpecialist ? "DEPARTMENT" : "UNIT"],
                "isSpecialistAssigned": ["booleanValue": isSpecialist],
                "assignedByEmail": ["stringValue": user.email],
                "assignedAt": ["integerValue": String(now)],
                "dispatchNote": ["stringValue": note],
                "isAcknowledged": ["booleanValue": false],
                "acknowledged": ["booleanValue": false],
                "acknowledgedAt": ["integerValue": "0"],
                "acknowledgedBy": ["stringValue": ""],
                "acknowledgedByName": ["stringValue": ""],
                "tracking": ["nullValue": NSNull()],
                "coTechnicians": ["arrayValue": ["values": coTechsValues]],
                "assignedTechnicianEmails": ["arrayValue": ["values": assignedEmailsValues]],
                "lastMessage": ["stringValue": dispatchMsg],
                "lastMessageAt": ["integerValue": String(now)]
            ]
            if !cleanNewPriority.isEmpty {
                f["priority"] = ["stringValue": cleanNewPriority]
            }

            let body: [String: Any] = ["fields": f]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)

            let rawAssignerName = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            let assignerName = (!rawAssignerName.isEmpty && rawAssignerName.lowercased() != "admin" && rawAssignerName.lowercased() != "user") ? rawAssignerName : "Bộ phận HelpDesk"

            sendMessage(ticketId: ticketId, text: dispatchMsg, customSenderName: assignerName, isSystemMessage: true)
            self.fetchTickets()

            // Tự động gửi email điều phối kèm nút 1-Click Resolve nếu có cấu hình
            if !techEmail.isEmpty && techEmail.contains("@") {
                Task {
                    if let emailCfg = await self.fetchCompanyEmailConfig(), emailCfg.isConfigured {
                        if let currentT = self.rawTickets.first(where: { $0.id == ticketId }) {
                            _ = await IosEmailSender.sendDispatchNotificationEmail(
                                ticket: currentT,
                                config: emailCfg,
                                targetEmail: techEmail,
                                targetName: techName,
                                isSpecialist: isSpecialist,
                                dispatchNote: note,
                                helpdeskName: assignerName
                            )
                        }
                    }
                }
            }

            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - BÀN GIAO CA / CHUYỂN TICKET (ĐỒNG BỘ 1:1 VỚI ANDROID handoverTicket)
    public func handoverTicket(
        ticketId: String,
        toType: String, // "TECHNICIAN" or "HELPDESK"
        targetTechEmail: String = "",
        targetTechName: String = "",
        targetCluster: String = "",
        targetRegion: String = "",
        targetDeptId: String = "",
        targetDeptName: String = "",
        targetIsSpecialist: Bool = false,
        reason: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        Task {
            let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanReason.isEmpty else {
                completion?(false)
                return
            }

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let fromName = !user.fullName.isEmpty ? user.fullName : (user.email.components(separatedBy: "@").first ?? user.email)
            let isFromSpecialist = user.isSpecialist ||
                user.role.uppercased().contains("CHUYENVIEN") ||
                user.role.uppercased().contains("SPECIALIST") ||
                !user.toNghiepVu.isEmpty ||
                user.departmentId.uppercased().contains("NGHIỆP VỤ") ||
                user.departmentId.uppercased().contains("NGHIEP VU") ||
                user.donVi.uppercased().contains("NGHIỆP VỤ") ||
                user.donVi.uppercased().contains("NGHIEP VU")
            let fromTitle = isFromSpecialist ? "Chuyên viên" : "KTV"
            let targetTitle = targetIsSpecialist ? "Chuyên viên" : "KTV"

            let handoverId = "ho_\(now)_\(Int.random(in: 1000...9999))"
            let currentTicket = self.rawTickets.first(where: { $0.id == ticketId })

            var maskFields = [
                "assignedByEmail", "assignedByName", "assignedAt",
                "dispatchNote", "lastMessage", "lastMessageAt",
                "isAcknowledged", "acknowledged", "acknowledgedAt",
                "acknowledgedBy", "acknowledgedByName", "handlingMethod",
                "assignedTechnicianEmails", "coTechnicians", "tracking", "handoverHistory",
                "toNghiepVu", "assignedApplication", "scope", "isSpecialistAssigned"
            ]

            var f: [String: Any] = [
                "assignedByEmail": ["stringValue": user.email],
                "assignedByName": ["stringValue": fromName],
                "dispatchNote": ["stringValue": cleanReason],
                "isAcknowledged": ["booleanValue": false],
                "acknowledged": ["booleanValue": false],
                "acknowledgedAt": ["integerValue": "0"],
                "acknowledgedBy": ["stringValue": ""],
                "acknowledgedByName": ["stringValue": ""],
                "handlingMethod": ["stringValue": ""],
                "tracking": ["nullValue": NSNull()]
            ]

            let systemMsg: String
            let myEmailClean = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if toType == "TECHNICIAN" {
                let cleanTargetEmail = targetTechEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let targetName = !targetTechName.isEmpty ? targetTechName : (cleanTargetEmail.components(separatedBy: "@").first ?? cleanTargetEmail)
                systemMsg = "🔄 [Bàn giao ca] \(fromTitle) \(fromName) đã bàn giao yêu cầu cho \(targetTitle) \(targetName). Lý do: \(cleanReason)"

                f["assignedAt"] = ["integerValue": String(now)]
                maskFields.append(contentsOf: ["assignedTo", "assignedToEmail", "assignedToName", "assignedRole", "assignedCluster"])
                f["assignedTo"] = ["stringValue": cleanTargetEmail]
                f["assignedToEmail"] = ["stringValue": cleanTargetEmail]
                f["assignedToName"] = ["stringValue": targetName]
                f["assignedRole"] = ["stringValue": targetIsSpecialist ? "SPECIALIST" : "TECH"]
                f["scope"] = ["stringValue": targetIsSpecialist ? "DEPARTMENT" : "UNIT"]
                f["isSpecialistAssigned"] = ["booleanValue": targetIsSpecialist]

                if !targetRegion.isEmpty {
                    maskFields.append("assignedRegion")
                    f["assignedRegion"] = ["stringValue": targetRegion]
                }

                if targetIsSpecialist {
                    f["assignedCluster"] = ["stringValue": ""]
                    f["toNghiepVu"] = ["stringValue": !targetDeptName.isEmpty ? targetDeptName : targetDeptId]
                    f["assignedApplication"] = ["stringValue": ""]
                    if !targetDeptId.isEmpty {
                        maskFields.append("assignedDepartmentId")
                        f["assignedDepartmentId"] = ["stringValue": targetDeptId]
                    }
                    if !targetDeptName.isEmpty {
                        maskFields.append("assignedDepartmentName")
                        f["assignedDepartmentName"] = ["stringValue": targetDeptName]
                    }
                } else {
                    f["assignedCluster"] = ["stringValue": targetCluster]
                    f["toNghiepVu"] = ["stringValue": ""]
                    f["assignedApplication"] = ["stringValue": ""]
                    if !targetDeptId.isEmpty {
                        maskFields.append("assignedDepartmentId")
                        f["assignedDepartmentId"] = ["stringValue": targetDeptId]
                    }
                    if !targetDeptName.isEmpty {
                        maskFields.append("assignedDepartmentName")
                        f["assignedDepartmentName"] = ["stringValue": targetDeptName]
                    }
                }

                // Loại bỏ cả KTV nhận mới VÀ KTV bàn giao ra khỏi danh sách KTV phụ (đồng bộ Android)
                let existingCoTechs = (currentTicket?.coTechnicians ?? []).filter {
                    let e = $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return !e.isEmpty && e != cleanTargetEmail && e != myEmailClean
                }
                let coTechValues: [[String: Any]] = existingCoTechs.map { c in
                    return [
                        "mapValue": [
                            "fields": [
                                "email": ["stringValue": c.email],
                                "name": ["stringValue": c.name],
                                "phone": ["stringValue": c.phone],
                                "role": ["stringValue": c.role],
                                "assignedAt": ["integerValue": String(c.assignedAt)],
                                "assignedBy": ["stringValue": c.assignedBy],
                                "isAcknowledged": ["booleanValue": c.isAcknowledged],
                                "acknowledgedAt": ["integerValue": String(c.acknowledgedAt)]
                            ]
                        ]
                    ]
                }
                f["coTechnicians"] = ["arrayValue": ["values": coTechValues]]

                var allAssignedEmails: [String] = []
                if !cleanTargetEmail.isEmpty {
                    allAssignedEmails.append(cleanTargetEmail)
                }
                for c in existingCoTechs {
                    let ce = c.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !ce.isEmpty && ce != myEmailClean && !allAssignedEmails.contains(ce) {
                        allAssignedEmails.append(ce)
                    }
                }
                f["assignedTechnicianEmails"] = ["arrayValue": ["values": allAssignedEmails.map { ["stringValue": $0] }]]

                // Tạo handover record
                let handoverRecord = HandoverRecord(
                    handoverId: handoverId,
                    fromEmail: myEmailClean,
                    fromName: fromName,
                    fromTitle: fromTitle,
                    toType: toType,
                    toEmail: cleanTargetEmail,
                    toName: targetName,
                    toTitle: targetTitle,
                    toCluster: targetCluster.trimmingCharacters(in: .whitespacesAndNewlines),
                    reason: cleanReason,
                    timestamp: now
                )
                var historyList = currentTicket?.handoverHistory ?? []
                historyList.append(handoverRecord)

                let historyArrayValue: [[String: Any]] = historyList.map { h in
                    return [
                        "mapValue": [
                            "fields": [
                                "handoverId": ["stringValue": h.handoverId],
                                "fromEmail": ["stringValue": h.fromEmail],
                                "fromName": ["stringValue": h.fromName],
                                "fromTitle": ["stringValue": h.fromTitle],
                                "toType": ["stringValue": h.toType],
                                "toEmail": ["stringValue": h.toEmail],
                                "toName": ["stringValue": h.toName],
                                "toTitle": ["stringValue": h.toTitle],
                                "toCluster": ["stringValue": h.toCluster],
                                "reason": ["stringValue": h.reason],
                                "timestamp": ["integerValue": String(h.timestamp)]
                            ]
                        ]
                    ]
                }
                f["handoverHistory"] = ["arrayValue": ["values": historyArrayValue]]
            } else {
                systemMsg = "↩️ [Chuyển về HelpDesk] \(fromTitle) \(fromName) đã chuyển trả ticket cho HelpDesk tiếp nhận lại. Lý do: \(cleanReason)"

                f["assignedAt"] = ["integerValue": "0"]
                f["assignedTechnicianEmails"] = ["arrayValue": ["values": []]]
                f["coTechnicians"] = ["arrayValue": ["values": []]]
                maskFields.append(contentsOf: [
                    "status", "assignedTo", "assignedToEmail", "assignedToName", "assignedRole", "assignedCluster",
                    "assignedDepartmentId", "assignedDepartmentName", "assignedRegion", "helpdeskAcknowledgedAt"
                ])
                f["status"] = ["stringValue": "OPEN"]
                f["assignedTo"] = ["stringValue": ""]
                f["assignedToEmail"] = ["stringValue": ""]
                f["assignedToName"] = ["stringValue": ""]
                f["assignedRole"] = ["stringValue": "TECH"]
                f["scope"] = ["stringValue": "UNIT"]
                f["isSpecialistAssigned"] = ["booleanValue": false]
                f["toNghiepVu"] = ["stringValue": ""]
                f["assignedApplication"] = ["stringValue": ""]
                f["assignedCluster"] = ["stringValue": ""]
                f["assignedRegion"] = ["stringValue": ""]
                f["assignedDepartmentId"] = ["stringValue": ""]
                f["assignedDepartmentName"] = ["stringValue": ""]
                f["helpdeskAcknowledgedAt"] = ["integerValue": "0"]

                // Tạo handover record
                let handoverRecord = HandoverRecord(
                    handoverId: handoverId,
                    fromEmail: myEmailClean,
                    fromName: fromName,
                    fromTitle: fromTitle,
                    toType: toType,
                    toEmail: "",
                    toName: "Bộ phận HelpDesk",
                    toTitle: "HelpDesk",
                    toCluster: "",
                    reason: cleanReason,
                    timestamp: now
                )
                var historyList = currentTicket?.handoverHistory ?? []
                historyList.append(handoverRecord)

                let historyArrayValue: [[String: Any]] = historyList.map { h in
                    return [
                        "mapValue": [
                            "fields": [
                                "handoverId": ["stringValue": h.handoverId],
                                "fromEmail": ["stringValue": h.fromEmail],
                                "fromName": ["stringValue": h.fromName],
                                "fromTitle": ["stringValue": h.fromTitle],
                                "toType": ["stringValue": h.toType],
                                "toEmail": ["stringValue": h.toEmail],
                                "toName": ["stringValue": h.toName],
                                "toTitle": ["stringValue": h.toTitle],
                                "toCluster": ["stringValue": h.toCluster],
                                "reason": ["stringValue": h.reason],
                                "timestamp": ["integerValue": String(h.timestamp)]
                            ]
                        ]
                    ]
                }
                f["handoverHistory"] = ["arrayValue": ["values": historyArrayValue]]
            }

            f["lastMessage"] = ["stringValue": systemMsg]
            f["lastMessageAt"] = ["integerValue": String(now)]

            var uniqueFields: [String] = []
            for field in maskFields {
                if !uniqueFields.contains(field) {
                    uniqueFields.append(field)
                }
            }
            let maskStr = uniqueFields.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])

            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(
                ticketId: ticketId,
                text: systemMsg,
                customSenderName: "\(fromName) (\(fromTitle))",
                isSystemMessage: true
            )
            VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - NGƯỜI DÙNG TỰ XỬ LÝ XONG (ĐỒNG BỘ 1:1 VỚI ANDROID AdminSupportChatScreen.kt selfResolve)
    public func selfResolveTicket(
        ticketId: String,
        reason: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        Task {
            guard !companyId.isEmpty, !ticketId.isEmpty else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let creatorNameStr = !user.fullName.isEmpty ? user.fullName : (user.email.components(separatedBy: "@").first ?? "Người yêu cầu")
            let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
            let reasonSuffix = !cleanReason.isEmpty ? " (\(cleanReason))" : ""
            let selfResolveMsg = "💡 \(creatorNameStr) (Người yêu cầu) đã tự xử lý xong sự cố\(reasonSuffix) • Dừng KTV"

            let maskFields = [
                "status", "closedAt", "resolvedReason", "resolutionNote",
                "lastMessage", "lastMessageAt", "tracking.status", "tracking.cancelReason", "tracking.cancelledAt", "tracking.lastUpdatedAt"
            ]

            let trackingFields: [String: Any] = [
                "status": ["stringValue": "CANCELLED_SELF_RESOLVED"],
                "cancelReason": ["stringValue": cleanReason],
                "cancelledAt": ["integerValue": String(now)],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]

            var f: [String: Any] = [
                "status": ["stringValue": "CLOSED"],
                "closedAt": ["integerValue": String(now)],
                "resolvedReason": ["stringValue": "SELF_RESOLVED"],
                "resolutionNote": ["stringValue": cleanReason],
                "lastMessage": ["stringValue": selfResolveMsg],
                "lastMessageAt": ["integerValue": String(now)],
                "tracking": ["mapValue": ["fields": trackingFields]]
            ]

            let maskStr = maskFields.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])

            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(
                ticketId: ticketId,
                text: selfResolveMsg,
                customSenderName: "\(creatorNameStr) (Người yêu cầu)",
                isSystemMessage: true
            )

            VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - TỰ ĐỘNG GHI NHẬN 5★ SAU 24H HOÀN TẤT (ĐỒNG BỘ 1:1 VỚI ANDROID checkAndApplyAutoRatings)
    public func checkAndApplyAutoRatings(candidates: [SupportTicket]) {
        guard !companyId.isEmpty, !candidates.isEmpty else { return }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let autoMsg = "🤖 [Hệ thống tự động ghi nhận 5★ sau 24h hoàn tất]: Phiếu hỗ trợ đã được đóng nghiệm thu."
            let autoFb = "[Hệ thống tự động ghi nhận Rất hài lòng (5★) sau 24h hoàn tất]"

            for ticket in candidates {
                guard ticket.hasAssignee && !ticket.isSelfResolved && ticket.isAutoRateEligible else { continue }
                let maskStr = "updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt&updateMask.fieldPaths=isAutoRated&updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
                let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticket.id)?\(maskStr)"
                guard let url = URL(string: urlStr) else { continue }

                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let closedTime = ticket.closedAt > 0 ? ticket.closedAt : now
                let f: [String: Any] = [
                    "rating": ["integerValue": "5"],
                    "feedback": ["stringValue": autoFb],
                    "feedbackAt": ["integerValue": String(now)],
                    "isAutoRated": ["booleanValue": true],
                    "status": ["stringValue": "CLOSED"],
                    "closedAt": ["integerValue": String(closedTime)],
                    "lastMessage": ["stringValue": autoMsg],
                    "lastMessageAt": ["integerValue": String(now)]
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
                _ = await FirestoreHelper.executeSafeRequest(request)

                // Gửi tin nhắn nghiệm thu tự động vào messages subcollection
                sendMessage(
                    ticketId: ticket.id,
                    text: autoMsg,
                    customSenderName: "Hệ thống (Nghiệm thu)",
                    isSystemMessage: true
                )
            }
        }
    }

    // MARK: - LIVE TRACKING METHODS (ĐỒNG BỘ 1:1 VỚI LIVETRACKINGMAP.KT)
    public func startTrip(
        ticketId: String,
        startLat: Double,
        startLng: Double,
        startAddress: String,
        destLat: Double,
        destLng: Double,
        destAddress: String,
        distanceKm: Double = 0.0,
        etaMinutes: Int = 0,
        isSpecialist: Bool = false,
        isCoTech: Bool = false,
        routeCoordinates: [[Double]] = [],
        completion: ((Bool) -> Void)? = nil
    ) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let sanitizedKey = user.email.lowercased().replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            let fieldPrefix = isCoTech ? "collaboratorTrackings.\(sanitizedKey)" : "tracking"

            var mask = "updateMask.fieldPaths=\(fieldPrefix).status&updateMask.fieldPaths=\(fieldPrefix).ticketId&updateMask.fieldPaths=\(fieldPrefix).technicianEmail&updateMask.fieldPaths=\(fieldPrefix).technicianName&updateMask.fieldPaths=\(fieldPrefix).technicianPhone&updateMask.fieldPaths=\(fieldPrefix).currentLat&updateMask.fieldPaths=\(fieldPrefix).currentLng&updateMask.fieldPaths=\(fieldPrefix).startLat&updateMask.fieldPaths=\(fieldPrefix).startLng&updateMask.fieldPaths=\(fieldPrefix).startAddress&updateMask.fieldPaths=\(fieldPrefix).destLat&updateMask.fieldPaths=\(fieldPrefix).destLng&updateMask.fieldPaths=\(fieldPrefix).destAddress&updateMask.fieldPaths=\(fieldPrefix).distanceKm&updateMask.fieldPaths=\(fieldPrefix).etaMinutes&updateMask.fieldPaths=\(fieldPrefix).lastUpdatedAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"

            var trackingMap: [String: Any] = [
                "ticketId": ["stringValue": ticketId],
                "technicianEmail": ["stringValue": user.email],
                "technicianName": ["stringValue": user.fullName],
                "technicianPhone": ["stringValue": user.phone],
                "status": ["stringValue": "EN_ROUTE"],
                "currentLat": ["doubleValue": startLat],
                "currentLng": ["doubleValue": startLng],
                "startLat": ["doubleValue": startLat],
                "startLng": ["doubleValue": startLng],
                "startAddress": ["stringValue": startAddress],
                "destLat": ["doubleValue": destLat],
                "destLng": ["doubleValue": destLng],
                "destAddress": ["stringValue": destAddress],
                "distanceKm": ["doubleValue": distanceKm],
                "etaMinutes": ["integerValue": String(etaMinutes)],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]

            if !routeCoordinates.isEmpty {
                mask += "&updateMask.fieldPaths=\(fieldPrefix).routeCoordinates"
                let coordsArray: [[String: Any]] = routeCoordinates.map { pt in
                    ["mapValue": ["fields": [
                        "lat": ["doubleValue": pt[0]],
                        "lng": ["doubleValue": pt[1]]
                    ]]]
                }
                trackingMap["routeCoordinates"] = ["arrayValue": ["values": coordsArray]]
            }

            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let title = isSpecialist ? (isCoTech ? "Chuyên viên phối hợp" : "Chuyên viên") : (isCoTech ? "KTV phối hợp" : "KTV")
            let msg = "🛵 \(title) \(user.fullName) đã bắt đầu di chuyển tới điểm hỗ trợ"

            var f: [String: Any] = [
                "lastMessage": ["stringValue": msg],
                "lastMessageAt": ["integerValue": String(now)]
            ]
            if isCoTech {
                f["collaboratorTrackings"] = ["mapValue": ["fields": [
                    sanitizedKey: ["mapValue": ["fields": trackingMap]]
                ]]]
            } else {
                f["tracking"] = ["mapValue": ["fields": trackingMap]]
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    public func updateTripLocation(
        ticketId: String,
        currentLat: Double,
        currentLng: Double,
        speedKmh: Float = 0,
        heading: Float = 0,
        distanceKm: Double = 0,
        etaMinutes: Int = 0,
        traveledKm: Double = 0,
        routeCoordinates: [[Double]] = [],
        isCoTech: Bool = false
    ) {
        guard !ticketId.isEmpty, currentLat != 0, currentLng != 0 else { return }
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let sanitizedKey = user.email.lowercased().replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            let fieldPrefix = isCoTech ? "collaboratorTrackings.\(sanitizedKey)" : "tracking"

            var mask = "updateMask.fieldPaths=\(fieldPrefix).currentLat&updateMask.fieldPaths=\(fieldPrefix).currentLng&updateMask.fieldPaths=\(fieldPrefix).speedKmh&updateMask.fieldPaths=\(fieldPrefix).heading&updateMask.fieldPaths=\(fieldPrefix).lastUpdatedAt"
            if distanceKm > 0 { mask += "&updateMask.fieldPaths=\(fieldPrefix).distanceKm&updateMask.fieldPaths=\(fieldPrefix).etaMinutes" }
            if traveledKm > 0 { mask += "&updateMask.fieldPaths=\(fieldPrefix).traveledDistanceKm" }

            var trackingFields: [String: Any] = [
                "currentLat": ["doubleValue": currentLat],
                "currentLng": ["doubleValue": currentLng],
                "speedKmh": ["doubleValue": Double(speedKmh)],
                "heading": ["doubleValue": Double(heading)],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]
            if distanceKm > 0 {
                trackingFields["distanceKm"] = ["doubleValue": distanceKm]
                trackingFields["etaMinutes"] = ["integerValue": String(etaMinutes)]
            }
            if traveledKm > 0 {
                trackingFields["traveledDistanceKm"] = ["doubleValue": traveledKm]
            }

            if !routeCoordinates.isEmpty {
                mask += "&updateMask.fieldPaths=\(fieldPrefix).routeCoordinates"
                let coordsArray: [[String: Any]] = routeCoordinates.map { pt in
                    ["mapValue": ["fields": [
                        "lat": ["doubleValue": pt[0]],
                        "lng": ["doubleValue": pt[1]]
                    ]]]
                }
                trackingFields["routeCoordinates"] = ["arrayValue": ["values": coordsArray]]
            }

            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let fieldsPayload: [String: Any]
            if isCoTech {
                fieldsPayload = [
                    "collaboratorTrackings": ["mapValue": ["fields": [
                        sanitizedKey: ["mapValue": ["fields": trackingFields]]
                    ]]]
                ]
            } else {
                fieldsPayload = [
                    "tracking": ["mapValue": ["fields": trackingFields]]
                ]
            }

            let body: [String: Any] = ["fields": fieldsPayload]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = await FirestoreHelper.executeSafeRequest(request)
        }
    }

    public func markArrived(ticketId: String, isSpecialist: Bool = false, isCoTech: Bool = false, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let sanitizedKey = user.email.lowercased().replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            let fieldPrefix = isCoTech ? "collaboratorTrackings.\(sanitizedKey)" : "tracking"
            let mask = "updateMask.fieldPaths=\(fieldPrefix).status&updateMask.fieldPaths=\(fieldPrefix).isArrivedVerified&updateMask.fieldPaths=\(fieldPrefix).lastUpdatedAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let title = isSpecialist ? (isCoTech ? "Chuyên viên phối hợp" : "Chuyên viên") : (isCoTech ? "KTV phối hợp" : "KTV")
            let msg = "✅ \(title) \(user.fullName) đã đến điểm hỗ trợ an toàn"
            let trackingFields: [String: Any] = [
                "status": ["stringValue": "ARRIVED"],
                "isArrivedVerified": ["booleanValue": true],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]
            var f: [String: Any] = [
                "lastMessage": ["stringValue": msg],
                "lastMessageAt": ["integerValue": String(now)]
            ]
            if isCoTech {
                f["collaboratorTrackings"] = ["mapValue": ["fields": [
                    sanitizedKey: ["mapValue": ["fields": trackingFields]]
                ]]]
            } else {
                f["tracking"] = ["mapValue": ["fields": trackingFields]]
            }

            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    public func switchToRemote(ticketId: String, isSpecialist: Bool = false, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let mask = "updateMask.fieldPaths=handlingMethod&updateMask.fieldPaths=tracking.status&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let title = isSpecialist ? "Chuyên viên" : "KTV"
            let msg = "💻 [Tiếp nhận ca] \(title) \(user.fullName) đã chọn phương án: XỬ LÝ TỪ XA."
            let trackingFields: [String: Any] = [
                "status": ["stringValue": "CANCELLED"],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]
            let f: [String: Any] = [
                "handlingMethod": ["stringValue": "REMOTE"],
                "tracking": ["mapValue": ["fields": trackingFields]],
                "lastMessage": ["stringValue": msg],
                "lastMessageAt": ["integerValue": String(now)]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    public func cancelTrip(ticketId: String, reason: String = "HelpDesk hủy chuyến", completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let mask = "updateMask.fieldPaths=tracking.status&updateMask.fieldPaths=tracking.cancelReason&updateMask.fieldPaths=tracking.cancelledAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let msg = "🛑 Chuyến đi đã bị hủy: \(reason)"
            let trackingFields: [String: Any] = [
                "status": ["stringValue": "CANCELLED"],
                "cancelReason": ["stringValue": reason],
                "cancelledAt": ["integerValue": String(now)],
                "lastUpdatedAt": ["integerValue": String(now)]
            ]
            let f: [String: Any] = [
                "tracking": ["mapValue": ["fields": trackingFields]],
                "lastMessage": ["stringValue": msg],
                "lastMessageAt": ["integerValue": String(now)]
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])
            _ = await FirestoreHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    // MARK: - STAFF & SPECIALIST TEAMS FETCH (Đồng bộ 1:1 Android AndroidDispatchDialog)
    public func fetchStaffAndSpecialistTeams() {
        isLoadingStaff = true
        Task {
            let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

            // 1. Fetch Users từ /companies/{comp}/users (và fallback nếu rỗng)
            var loadedStaff: [User] = []
            let usersUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/users?pageSize=200"
            if let uUrl = URL(string: usersUrlStr) {
                var uReq = URLRequest(url: uUrl)
                if !idToken.isEmpty { uReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (uData, uResp) = await FirestoreHelper.executeSafeRequest(uReq),
                   uResp.statusCode == 200,
                   let uJson = try? JSONSerialization.jsonObject(with: uData) as? [String: Any],
                   let uDocs = uJson["documents"] as? [[String: Any]], !uDocs.isEmpty {
                    loadedStaff = parseStaffUsers(from: uDocs, companyId: comp, nowMs: nowMs)
                }
            }

            if loadedStaff.isEmpty {
                let rootUsersUrl = "\(FirebaseConfig.firestoreBaseUrl)/users?pageSize=200"
                if let rUrl = URL(string: rootUsersUrl) {
                    var rReq = URLRequest(url: rUrl)
                    if !idToken.isEmpty { rReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                    if let (rData, rResp) = await FirestoreHelper.executeSafeRequest(rReq),
                       rResp.statusCode == 200,
                       let rJson = try? JSONSerialization.jsonObject(with: rData) as? [String: Any],
                       let rDocs = rJson["documents"] as? [[String: Any]] {
                        loadedStaff = parseStaffUsers(from: rDocs, companyId: comp, nowMs: nowMs)
                    }
                }
            }

            if !loadedStaff.isEmpty {
                self.allStaffList = loadedStaff
            }

            // 2. Fetch Specialist Teams từ Firestore /companies/{comp}/specialist_teams
            let specUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/specialist_teams?pageSize=50"
            if let sUrl = URL(string: specUrlStr) {
                var sReq = URLRequest(url: sUrl)
                if !idToken.isEmpty { sReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (sData, sResp) = await FirestoreHelper.executeSafeRequest(sReq),
                   sResp.statusCode == 200,
                   let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
                   let sDocs = sJson["documents"] as? [[String: Any]], !sDocs.isEmpty {
                    let dynamicTeams = sDocs.compactMap { doc -> SpecialistTeamInfo? in
                        guard let docName = doc["name"] as? String,
                              let fields = doc["fields"] as? [String: Any] else { return nil }
                        let id = docName.components(separatedBy: "/").last ?? ""
                        let teamId = FirestoreHelper.getString(fields["teamId"] as? [String: Any]).isEmpty ? id : FirestoreHelper.getString(fields["teamId"] as? [String: Any])
                        let teamName = FirestoreHelper.getString(fields["teamName"] as? [String: Any]).isEmpty ? (FirestoreHelper.getString(fields["name"] as? [String: Any]).isEmpty ? teamId : FirestoreHelper.getString(fields["name"] as? [String: Any])) : FirestoreHelper.getString(fields["teamName"] as? [String: Any])
                        let apps = FirestoreHelper.getStringArray(fields["applications"] as? [String: Any])
                        let desc = FirestoreHelper.getString(fields["description"] as? [String: Any])
                        return SpecialistTeamInfo(teamId: teamId, teamName: teamName, applications: apps, description: desc)
                    }.sorted { $0.teamName.localizedCaseInsensitiveCompare($1.teamName) == .orderedAscending }

                    if !dynamicTeams.isEmpty {
                        self.specialistTeams = dynamicTeams
                    }
                }
            }

            self.isLoadingStaff = false
        }
    }

    private func parseStaffUsers(from docs: [[String: Any]], companyId: String, nowMs: Int64) -> [User] {
        return docs.compactMap { doc -> User? in
            guard let docName = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let rawEmail = FirestoreHelper.getString(fields["email"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let email = !rawEmail.isEmpty && rawEmail.contains("@") ? rawEmail : (docName.components(separatedBy: "/").last?.lowercased() ?? "")
            guard email.contains("@") && !email.hasPrefix("device_") else { return nil }

            let rawDept = FirestoreHelper.getString(fields["departmentId"] as? [String: Any])
            let rawPb = FirestoreHelper.getString(fields["phongBan"] as? [String: Any])
            let finalDept = rawDept.isEmpty ? rawPb : rawDept
            let name = FirestoreHelper.getString(fields["fullName"] as? [String: Any]).isEmpty
                ? (FirestoreHelper.getString(fields["name"] as? [String: Any]).isEmpty
                    ? (FirestoreHelper.getString(fields["displayName"] as? [String: Any]).isEmpty
                        ? FirestoreHelper.getString(fields["hoTen"] as? [String: Any])
                        : FirestoreHelper.getString(fields["displayName"] as? [String: Any]))
                    : FirestoreHelper.getString(fields["name"] as? [String: Any]))
                : FirestoreHelper.getString(fields["fullName"] as? [String: Any])
            let maKhuVuc = FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any]).isEmpty
                ? FirestoreHelper.getString(fields["khuVuc"] as? [String: Any])
                : FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])
            var toNghiepVu = FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
            if toNghiepVu.isEmpty && maKhuVuc.hasPrefix("TO_") {
                toNghiepVu = maKhuVuc
            }

            let lastActiveAt = FirestoreHelper.getInt64(fields["lastActiveAt"] as? [String: Any])
            let rawOnline = FirestoreHelper.getBool(fields["isOnline"] as? [String: Any]) || FirestoreHelper.getBool(fields["online"] as? [String: Any])
            let isOnDuty = FirestoreHelper.getBool(fields["isOnDuty"] as? [String: Any])
            let onDutyShift = FirestoreHelper.getString(fields["onDutyShift"] as? [String: Any])
            let onDutySource = FirestoreHelper.getString(fields["onDutySource"] as? [String: Any])
            let onDutySince = FirestoreHelper.getInt64(fields["onDutySince"] as? [String: Any])
            let isOnline = (rawOnline && (lastActiveAt > 0) && (nowMs - lastActiveAt <= 15 * 60 * 1000)) || isOnDuty

            return User(
                maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                email: email,
                role: FirestoreHelper.getString(fields["role"] as? [String: Any]).isEmpty ? "STAFF" : FirestoreHelper.getString(fields["role"] as? [String: Any]),
                fullName: name.isEmpty ? (email.components(separatedBy: "@").first ?? "") : name,
                phone: FirestoreHelper.getString(fields["phone"] as? [String: Any]),
                donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                companyId: companyId,
                departmentId: finalDept,
                status: FirestoreHelper.getString(fields["status"] as? [String: Any]).isEmpty ? "ACTIVE" : FirestoreHelper.getString(fields["status"] as? [String: Any]),
                avatarUrl: FirestoreHelper.getString(fields["avatarUrl"] as? [String: Any]),
                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                mustChangePassword: FirestoreHelper.getBool(fields["mustChangePassword"] as? [String: Any]),
                maKhuVuc: maKhuVuc,
                toNghiepVu: toNghiepVu,
                lastActiveAt: lastActiveAt,
                isOnline: isOnline,
                permissions: FirestoreHelper.getStringArray(fields["permissions"] as? [String: Any]),
                disabledReason: FirestoreHelper.getString(fields["disabledReason"] as? [String: Any]),
                isOnDuty: isOnDuty,
                onDutyShift: onDutyShift,
                onDutySource: onDutySource,
                onDutySince: onDutySince
            )
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

            guard let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let docs = json["documents"] as? [[String: Any]] else {
                self.isLoadingKtvs = false
                return
            }

            // 1. Lấy tọa độ GPS thời gian thực từ technician_locations
            var techGpsMap: [String: (lat: Double, lng: Double)] = [:]
            if let tLocUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/technician_locations?pageSize=200") {
                var tLocReq = URLRequest(url: tLocUrl)
                if !idToken.isEmpty { tLocReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (tData, tResp) = await FirestoreHelper.executeSafeRequest(tLocReq),
                   tResp.statusCode == 200,
                   let tJson = try? JSONSerialization.jsonObject(with: tData) as? [String: Any],
                   let tDocs = tJson["documents"] as? [[String: Any]] {
                    for td in tDocs {
                        guard let tFields = td["fields"] as? [String: Any] else { continue }
                        let docName = (td["name"] as? String)?.components(separatedBy: "/").last ?? ""
                        let tEmail = FirestoreHelper.getString(tFields["email"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let keyEmail = tEmail.isEmpty ? docName.lowercased() : tEmail
                        let tLat = FirestoreHelper.getDouble(tFields["lat"] as? [String: Any])
                        let tLng = FirestoreHelper.getDouble(tFields["lng"] as? [String: Any])
                        if tLat != 0.0 && tLng != 0.0 {
                            techGpsMap[keyEmail] = (tLat, tLng)
                            techGpsMap[keyEmail.replacingOccurrences(of: "/", with: "_")] = (tLat, tLng)
                        }
                    }
                }
            }

            // 2. Lấy tọa độ các đơn vị / chi nhánh từ bảng units
            var unitCoordsMap: [String: (lat: Double, lng: Double)] = [:]
            if let unitsUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/units?pageSize=300") {
                var uReq = URLRequest(url: unitsUrl)
                if !idToken.isEmpty { uReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (uData, uResp) = await FirestoreHelper.executeSafeRequest(uReq),
                   uResp.statusCode == 200,
                   let uJson = try? JSONSerialization.jsonObject(with: uData) as? [String: Any],
                   let uDocs = uJson["documents"] as? [[String: Any]] {
                    for ud in uDocs {
                        guard let uFields = ud["fields"] as? [String: Any] else { continue }
                        let uName = FirestoreHelper.getString(uFields["unitName"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let uLat = FirestoreHelper.getDouble(uFields["lat"] as? [String: Any])
                        let uLng = FirestoreHelper.getDouble(uFields["lng"] as? [String: Any])
                        if !uName.isEmpty && uLat != 0.0 && uLng != 0.0 {
                            unitCoordsMap[uName] = (uLat, uLng)
                        }
                    }
                }
            }

            // 3. Lấy phân ca làm việc tuần hiện tại
            var cal = Calendar(identifier: .gregorian)
            cal.firstWeekday = 2 // Thứ 2
            let today = Date()
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
            let currentWeekId = String(format: "%04d-W%02d", comps.yearForWeekOfYear ?? 2026, comps.weekOfYear ?? 1)
            var shiftCodeMap: [String: String] = [:]

            let dfDate = DateFormatter()
            dfDate.dateFormat = "yyyy-MM-dd"
            let todayKeyDate = dfDate.string(from: today)
            let dfDdMm = DateFormatter()
            dfDdMm.dateFormat = "dd/MM/yyyy"
            let todayKeyDdMm = dfDdMm.string(from: today)
            let weekdayIdx = (cal.component(.weekday, from: today) - 2 + 7) % 7
            let shortDays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
            let todayKeyShort = shortDays[weekdayIdx]

            if let schedUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)") {
                var sReq = URLRequest(url: schedUrl)
                if !idToken.isEmpty { sReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (sData, sResp) = await FirestoreHelper.executeSafeRequest(sReq),
                   sResp.statusCode == 200,
                   let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
                   let sFields = sJson["fields"] as? [String: Any],
                   let rawEntries = (sFields["entries"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let valList = rawEntries["values"] as? [[String: Any]] {
                    for v in valList {
                        guard let mapFields = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] else { continue }
                        let empId = FirestoreHelper.getString(mapFields["employeeId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let empName = FirestoreHelper.getString(mapFields["employeeName"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if let daysMap = (mapFields["days"] as? [String: Any])?["mapValue"] as? [String: Any],
                           let dayFields = daysMap["fields"] as? [String: Any] {
                            let code = FirestoreHelper.getString(dayFields[todayKeyDate] as? [String: Any]).isEmpty
                                ? (FirestoreHelper.getString(dayFields[todayKeyShort] as? [String: Any]).isEmpty
                                    ? FirestoreHelper.getString(dayFields[todayKeyDdMm] as? [String: Any])
                                    : FirestoreHelper.getString(dayFields[todayKeyShort] as? [String: Any]))
                                : FirestoreHelper.getString(dayFields[todayKeyDate] as? [String: Any])
                            if !code.isEmpty {
                                if !empId.isEmpty { shiftCodeMap[empId] = code }
                                if !empName.isEmpty { shiftCodeMap[empName] = code }
                            }
                        }
                    }
                }
            }

            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let onlineWindowMs: Int64 = 15 * 60 * 1000 // 15 phút

            var result: [KtvOnlineLocation] = []
            for doc in docs {
                guard let fields = doc["fields"] as? [String: Any] else { continue }
                let email = FirestoreHelper.getString(fields["email"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if email.isEmpty { continue }

                let role = FirestoreHelper.getString(fields["role"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let deptId = (FirestoreHelper.getString(fields["departmentId"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["phongBan"] as? [String: Any])
                    : FirestoreHelper.getString(fields["departmentId"] as? [String: Any])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let deptName = (FirestoreHelper.getString(fields["departmentName"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["deptName"] as? [String: Any])
                    : FirestoreHelper.getString(fields["departmentName"] as? [String: Any])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let toNghiepVu = FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let donVi = FirestoreHelper.getString(fields["donVi"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                // 1. Loại trừ các vai trò không thuộc đội kỹ thuật/chuyên viên
                let isExcluded = role == "user" || role == "admin" || role == "superadmin" || role == "super_admin" || role == "helpdesk" || role == "hd" ||
                    role.contains("admin") || role.contains("helpdesk") || role.contains("nhan vien") || role.contains("nhanvien") || role.contains("nhân viên")

                // 2. Nhận diện Kỹ thuật viên (KTV)
                let isKtv = role == "ktv" || role == "technician" || role == "kythuat" || role == "ky_thuat" || role == "incident_handler" ||
                    role.contains("ktv") || role.contains("technician") || role.contains("kythuat") || role.contains("kỹ thuật")

                // 3. Nhận diện Chuyên viên (Specialist)
                let isSpecialist = role == "specialist" || role == "chuyenvien" || role == "chuyen_vien" ||
                    role.contains("specialist") || role.contains("chuyenvien") || role.contains("chuyên viên") ||
                    deptId.contains("nghiep vu") || deptId.contains("ung dung") ||
                    deptName.contains("nghiệp vụ") || deptName.contains("ứng dụng") ||
                    donVi.contains("nghiệp vụ") || donVi.contains("nghiep vu") ||
                    !toNghiepVu.isEmpty

                if isExcluded || (!isKtv && !isSpecialist) {
                    continue
                }

                let rawOnline = (fields["isOnline"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let lastActiveAt = FirestoreHelper.getInt64(fields["lastActiveAt"] as? [String: Any])
                let isOnDuty = (fields["isOnDuty"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let isOnline = (rawOnline && (lastActiveAt > 0) && ((nowMs - lastActiveAt) < onlineWindowMs)) || isOnDuty

                let name = FirestoreHelper.getString(fields["fullName"] as? [String: Any]).isEmpty
                    ? FirestoreHelper.getString(fields["name"] as? [String: Any])
                    : FirestoreHelper.getString(fields["fullName"] as? [String: Any])
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

                let violCount = Int(FirestoreHelper.getInt64(fields["offlineViolationsCount"] as? [String: Any]))
                let isBlacklisted = (fields["isBlacklisted"] as? [String: Any])?["booleanValue"] as? Bool ?? (violCount >= 5)

                let shiftCode = shiftCodeMap[maNhanVien.lowercased()] ?? shiftCodeMap[name.lowercased()] ?? ""
                let offCodes = Set(["OFF", "NC", "P", "NM", "NL"])
                let isScheduledOff = offCodes.contains(shiftCode.uppercased())

                // Giải quyết tọa độ KTV (Ưu tiên: 1. Live GPS -> 2. User doc -> 3. Units -> 4. CoopmartDirectory -> 5. MaKhuVuc)
                let jitterLat = (Double(abs(email.hashValue) % 70) - 35.0) / 10000.0
                let jitterLng = (Double(abs((email + "x").hashValue) % 70) - 35.0) / 10000.0

                let liveGps = techGpsMap[email] ?? techGpsMap[email.replacingOccurrences(of: "/", with: "_")]
                let docLat = FirestoreHelper.getDouble(fields["latitude"] as? [String: Any]) != 0 ? FirestoreHelper.getDouble(fields["latitude"] as? [String: Any]) : FirestoreHelper.getDouble(fields["lat"] as? [String: Any])
                let docLng = FirestoreHelper.getDouble(fields["longitude"] as? [String: Any]) != 0 ? FirestoreHelper.getDouble(fields["longitude"] as? [String: Any]) : FirestoreHelper.getDouble(fields["lng"] as? [String: Any])

                let unitCoord = unitCoordsMap[unitName.lowercased()] ?? unitCoordsMap[donVi.lowercased()]
                let coopStore = (liveGps == nil && docLat == 0.0 && unitCoord == nil) ? CoopmartDirectory.resolve(unitName.isEmpty ? donVi : unitName) : nil

                var finalLat: Double = 0.0
                var finalLng: Double = 0.0

                if let gps = liveGps, gps.lat != 0.0 && gps.lng != 0.0 {
                    finalLat = gps.lat
                    finalLng = gps.lng
                } else if docLat != 0.0 && docLng != 0.0 {
                    finalLat = docLat
                    finalLng = docLng
                } else if let uc = unitCoord, uc.lat != 0.0 && uc.lng != 0.0 {
                    finalLat = uc.lat + jitterLat
                    finalLng = uc.lng + jitterLng
                } else if let cs = coopStore, cs.lat != 0.0 && cs.lng != 0.0 {
                    finalLat = cs.lat + jitterLat
                    finalLng = cs.lng + jitterLng
                } else {
                    switch maKhuVuc.uppercased() {
                    case "HCM_1": finalLat = 10.7769 + jitterLat; finalLng = 106.7009 + jitterLng
                    case "HCM_2": finalLat = 10.7550 + jitterLat; finalLng = 106.6600 + jitterLng
                    case "HCM_3": finalLat = 10.8000 + jitterLat; finalLng = 106.7200 + jitterLng
                    case "HCM_BD": finalLat = 10.9450 + jitterLat; finalLng = 106.7020 + jitterLng
                    case "MIENTAY": finalLat = 10.0333 + jitterLat; finalLng = 105.7833 + jitterLng
                    case "MIENTRUNG": finalLat = 16.0544 + jitterLat; finalLng = 108.2022 + jitterLng
                    case "MIENBAC": finalLat = 21.0285 + jitterLat; finalLng = 105.8542 + jitterLng
                    case "DONGNAI": finalLat = 10.9574 + jitterLat; finalLng = 106.8427 + jitterLng
                    default: finalLat = 10.7769 + jitterLat; finalLng = 106.7009 + jitterLng
                    }
                }

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
                    latitude: finalLat,
                    longitude: finalLng,
                    role: role,
                    departmentId: deptId,
                    departmentName: deptName,
                    isSpecialist: isSpecialist,
                    todayShiftCode: shiftCode,
                    isScheduledOff: isScheduledOff,
                    violationsThisMonth: violCount,
                    isBlacklisted: isBlacklisted,
                    isOnDuty: isOnDuty,
                    onDutyShift: FirestoreHelper.getString(fields["onDutyShift"] as? [String: Any])
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
                let finishTime = t.resolvedAt > 0 ? t.resolvedAt : t.closedAt
                if finishTime > t.createdAt && t.createdAt > 0 {
                    let hours = Double(finishTime - t.createdAt) / (1000.0 * 3600.0)
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

        guard let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
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
