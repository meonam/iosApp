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
    @Published public var filterStatus: String = "ALL" // "ALL", "OPEN", "CLOSED"
    public var filterTab: String {
        get { filterStatus }
        set { filterStatus = newValue }
    }
    @Published public var filterSource: String = "ALL" // "ALL", "APP", "ZALO", "EMAIL", "DEPARTMENT"
    @Published public var searchQuery: String = ""
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    @Published public var isTicketReopenEnabled: Bool = false
    @Published public var enableKtvViolationTracking: Bool = true
    @Published public var ktvOfflineViolationMinutes: Int = 15
    @Published public var ktvKpiWarningThreshold: Int = 3
    @Published public var ktvBlacklistThreshold: Int = 5
    @Published public var ktvKpiDeductionPercent: Int = 10
    @Published public var slaConfig: SlaConfig = SlaConfig()
    @Published public var companyUnits: [DonVi] = []

    // Chat realtime
    @Published public var currentTicket: SupportTicket? = nil
    @Published public var messages: [SupportMessage] = []
    @Published public var isSendingMessage: Bool = false

    // KTV Online Monitor (đồng bộ OnlineKtvMonitorScreen.kt)
    @Published public var ktvTechnicians: [KtvOnlineLocation] = []
    @Published public var isLoadingKtvs: Bool = false
    @Published public var shiftHours: [String: (inTime: String, outTime: String)] = [
        "shift1": ("08:00", "15:00"),
        "shift2": ("14:00", "22:00"),
        "hc": ("08:00", "17:00"),
        "night": ("22:00", "06:00")
    ]

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

        // Lắng nghe tín hiệu background fetch / silent push từ AppDelegate → fetch ngay lập tức
        NotificationCenter.default.addObserver(
            forName: Notification.Name("QLTB_BackgroundFetch"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.fetchTicketsSilent()
        }

        fetchSystemToggleConfig()
        fetchTravelExpenseConfig()
        fetchSlaConfig()
        fetchCompanyUnits()
        fetchKtvTechnicians()
    }

    // MARK: - SYSTEM TOGGLE CONFIG (ĐỒNG BỘ CẤU HÌNH ADMIN / REOPEN TICKET)
    public func fetchSystemToggleConfig() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/system_config/system_toggle_config"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty {
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            var fetchedFields: [String: Any]? = nil
            if let (data, httpResp) = await DatabaseHelper.executeSafeRequest(req), httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                fetchedFields = fields
            } else if let fallbackUrl = URL(string: "\(ServerConfig.documentsBaseUrl)/system_config/system_toggle_config") {
                var fallbackReq = URLRequest(url: fallbackUrl)
                if !idToken.isEmpty { fallbackReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (data, httpResp) = await DatabaseHelper.executeSafeRequest(fallbackReq), httpResp.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {
                    fetchedFields = fields
                }
            }

            if let fields = fetchedFields {
                let allowReopen = (fields["allowTicketReopen"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let enableViolations = (fields["enableKtvViolationTracking"] as? [String: Any])?["booleanValue"] as? Bool ?? true
                let offlineMinutes = Int((fields["ktvOfflineViolationMinutes"] as? [String: Any])?["integerValue"] as? String ?? "") ?? 15
                let kpiWarnThresh = Int((fields["ktvKpiWarningThreshold"] as? [String: Any])?["integerValue"] as? String ?? "") ?? 3
                let blThresh = Int((fields["ktvBlacklistThreshold"] as? [String: Any])?["integerValue"] as? String ?? "") ?? 5
                let kpiDeduct = Int((fields["ktvKpiDeductionPercent"] as? [String: Any])?["integerValue"] as? String ?? "") ?? 10
                await MainActor.run {
                    self.isTicketReopenEnabled = allowReopen
                    self.enableKtvViolationTracking = enableViolations
                    self.ktvOfflineViolationMinutes = offlineMinutes
                    self.ktvKpiWarningThreshold = kpiWarnThresh
                    self.ktvBlacklistThreshold = blThresh
                    self.ktvKpiDeductionPercent = kpiDeduct
                }
            } else {
                await MainActor.run {
                    self.isTicketReopenEnabled = false
                    self.enableKtvViolationTracking = true
                    self.ktvOfflineViolationMinutes = 15
                    self.ktvKpiWarningThreshold = 3
                    self.ktvBlacklistThreshold = 5
                    self.ktvKpiDeductionPercent = 10
                }
            }
        }
    }

    // MARK: - TRAVEL EXPENSE CONFIG / CẤU HÌNH CA KÍP (ĐỒNG BỘ 1:1 VỚI ANDROID/WEB/DESKTOP)
    public func fetchTravelExpenseConfig() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/system_config/travel_expense_config"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty {
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            if let (data, httpResp) = await DatabaseHelper.executeSafeRequest(req), httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let s1In = DatabaseHelper.getString(fields["shift1CheckInTime"] as? [String: Any]).isEmpty ? "08:00" : DatabaseHelper.getString(fields["shift1CheckInTime"] as? [String: Any])
                let s1Out = DatabaseHelper.getString(fields["shift1CheckOutTime"] as? [String: Any]).isEmpty ? "15:00" : DatabaseHelper.getString(fields["shift1CheckOutTime"] as? [String: Any])
                let s2In = DatabaseHelper.getString(fields["shift2CheckInTime"] as? [String: Any]).isEmpty ? "14:00" : DatabaseHelper.getString(fields["shift2CheckInTime"] as? [String: Any])
                let s2Out = DatabaseHelper.getString(fields["shift2CheckOutTime"] as? [String: Any]).isEmpty ? "22:00" : DatabaseHelper.getString(fields["shift2CheckOutTime"] as? [String: Any])
                let hcIn = DatabaseHelper.getString(fields["standardCheckInTime"] as? [String: Any]).isEmpty ? "08:00" : DatabaseHelper.getString(fields["standardCheckInTime"] as? [String: Any])
                let hcOut = DatabaseHelper.getString(fields["standardCheckOutTime"] as? [String: Any]).isEmpty ? "17:00" : DatabaseHelper.getString(fields["standardCheckOutTime"] as? [String: Any])
                let nightIn = DatabaseHelper.getString(fields["nightCheckInTime"] as? [String: Any]).isEmpty ? "22:00" : DatabaseHelper.getString(fields["nightCheckInTime"] as? [String: Any])
                let nightOut = DatabaseHelper.getString(fields["nightCheckOutTime"] as? [String: Any]).isEmpty ? "06:00" : DatabaseHelper.getString(fields["nightCheckOutTime"] as? [String: Any])

                await MainActor.run {
                    self.shiftHours = [
                        "shift1": (s1In, s1Out),
                        "shift2": (s2In, s2Out),
                        "hc": (hcIn, hcOut),
                        "night": (nightIn, nightOut)
                    ]
                }
            }
        }
    }

    // MARK: - SLA CONFIG & AUTO DISPATCH
    public func fetchSlaConfig() {
        guard !companyId.isEmpty else { return }
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/system_config/sla_config"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty {
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            if let (data, httpResp) = await DatabaseHelper.executeSafeRequest(req), httpResp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                var cfg = SlaConfig()
                let rDef = DatabaseHelper.getInt(fields["responseMinutesDefault"] as? [String: Any])
                if rDef > 0 {
                    cfg.responseMinutesDefault = rDef
                }
                let rUrg = DatabaseHelper.getInt(fields["resolveMinutesUrgent"] as? [String: Any])
                if rUrg > 0 {
                    cfg.resolveMinutesUrgent = rUrg
                }
                let rHigh = DatabaseHelper.getInt(fields["resolveMinutesHigh"] as? [String: Any])
                if rHigh > 0 {
                    cfg.resolveMinutesHigh = rHigh
                }
                let rNorm = DatabaseHelper.getInt(fields["resolveMinutesNormal"] as? [String: Any])
                if rNorm > 0 {
                    cfg.resolveMinutesNormal = rNorm
                }
                let rLow = DatabaseHelper.getInt(fields["resolveMinutesLow"] as? [String: Any])
                if rLow > 0 {
                    cfg.resolveMinutesLow = rLow
                }
                let qUrg = DatabaseHelper.getInt(fields["qualityTrackingHoursUrgent"] as? [String: Any])
                if qUrg > 0 {
                    cfg.qualityTrackingHoursUrgent = qUrg
                }
                let qHigh = DatabaseHelper.getInt(fields["qualityTrackingHoursHigh"] as? [String: Any])
                if qHigh > 0 {
                    cfg.qualityTrackingHoursHigh = qHigh
                }
                let qNorm = DatabaseHelper.getInt(fields["qualityTrackingHoursNormal"] as? [String: Any])
                if qNorm > 0 {
                    cfg.qualityTrackingHoursNormal = qNorm
                }
                let qLow = DatabaseHelper.getInt(fields["qualityTrackingHoursLow"] as? [String: Any])
                if qLow > 0 {
                    cfg.qualityTrackingHoursLow = qLow
                }
                let wMin = DatabaseHelper.getInt(fields["warningBeforeBreachMinutes"] as? [String: Any])
                if wMin > 0 {
                    cfg.warningBeforeBreachMinutes = wMin
                }
                if fields["slaPenaltyPercentDefault"] != nil {
                    let pen = DatabaseHelper.getInt(fields["slaPenaltyPercentDefault"] as? [String: Any])
                    cfg.slaPenaltyPercentDefault = pen
                }
                if let eh = fields["enableHelpdeskSla"] as? [String: Any], let b = eh["booleanValue"] as? Bool {
                    cfg.enableHelpdeskSla = b
                }
                if let autoOff = fields["enableAutoDispatchOffHours"] as? [String: Any], let b = autoOff["booleanValue"] as? Bool {
                    cfg.enableAutoDispatchOffHours = b
                }
                let wdS = DatabaseHelper.getString(fields["helpdeskWeekdayStart"] as? [String: Any])
                if !wdS.isEmpty { cfg.helpdeskWeekdayStart = wdS }
                let wdE = DatabaseHelper.getString(fields["helpdeskWeekdayEnd"] as? [String: Any])
                if !wdE.isEmpty { cfg.helpdeskWeekdayEnd = wdE }
                let satS = DatabaseHelper.getString(fields["helpdeskSaturdayStart"] as? [String: Any])
                if !satS.isEmpty { cfg.helpdeskSaturdayStart = satS }
                let satE = DatabaseHelper.getString(fields["helpdeskSaturdayEnd"] as? [String: Any])
                if !satE.isEmpty { cfg.helpdeskSaturdayEnd = satE }
                let escMin = DatabaseHelper.getInt(fields["escalationTimeoutMinutes"] as? [String: Any])
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/units?pageSize=300"
            guard let url = URL(string: urlStr) else { return }
            var req = URLRequest(url: url)
            if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            if let (data, resp) = await DatabaseHelper.executeSafeRequest(req), resp.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                let units: [DonVi] = docs.compactMap { doc in
                    guard let fields = doc["fields"] as? [String: Any],
                          let name = doc["name"] as? String else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    let uName = DatabaseHelper.getString(fields["unitName"] as? [String: Any]).isEmpty
                        ? (DatabaseHelper.getString(fields["name"] as? [String: Any]).isEmpty ? id : DatabaseHelper.getString(fields["name"] as? [String: Any]))
                        : DatabaseHelper.getString(fields["unitName"] as? [String: Any])
                    let maKhuVuc = DatabaseHelper.getString(fields["maKhuVuc"] as? [String: Any])
                    return DonVi(id: id, tenDonVi: uName, maKhuVuc: maKhuVuc, companyId: cleanComp)
                }
                await MainActor.run {
                    self.companyUnits = units
                }
            }
        }
    }

    // MARK: - XÓA VĨNH VIỄN KHỎI DATABASE (ADMIN ONLY)
    public func deleteTicketPermanently(id: String) {
        guard !id.isEmpty, !companyId.isEmpty else { return }
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/tickets/\(id)"
        guard let url = URL(string: urlStr) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: req) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.rawTickets.removeAll { $0.id == id }
            }
        }.resume()
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

            // 2b. Quản lý Đơn vị / Chi nhánh (Manager): mới được theo dõi ticket đơn vị mình
            // (Bắt buộc cả cleanDonVi và tDonVi đều KHÔNG rỗng để tránh String.contains("") khớp chuỗi rỗng của ticket Email)
            if user.isManager {
                if !cleanDonVi.isEmpty && !tDonVi.isEmpty && (tDonVi == cleanDonVi || tDonVi.contains(cleanDonVi) || cleanDonVi.contains(tDonVi)) {
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

    // MARK: - TAB COUNTS (3 TABS: ALL, OPEN, CLOSED)
    public var allCount: Int {
        scopedTickets.count
    }

    public var openCount: Int {
        scopedTickets.filter { $0.isOpen }.count
    }

    public var closedCount: Int {
        scopedTickets.filter { $0.isClosed }.count
    }

    public func isEmailTicket(_ t: SupportTicket) -> Bool {
        t.source.uppercased() == "EMAIL" || t.externalSenderId.contains("@")
    }

    public func isZaloTicket(_ t: SupportTicket) -> Bool {
        t.source.uppercased() == "ZALO" || t.externalChannelName.localizedCaseInsensitiveContains("zalo")
    }

    public func isDeptTicket(_ t: SupportTicket) -> Bool {
        if isEmailTicket(t) || isZaloTicket(t) { return false }
        return t.scope.uppercased() == "DEPARTMENT" ||
            t.source.uppercased() == "DEPARTMENT" ||
            t.isSpecialistAssigned ||
            t.assignedRole.uppercased() == "SPECIALIST" ||
            t.assignedDepartmentId.uppercased().hasPrefix("TO_") ||
            t.assignedDepartmentName.localizedCaseInsensitiveContains("ứng dụng") ||
            t.assignedDepartmentName.localizedCaseInsensitiveContains("nghiệp vụ") ||
            t.subject.localizedCaseInsensitiveContains("kênh phòng ban")
    }

    public var appCount: Int {
        scopedTickets.filter { t in
            !isEmailTicket(t) && !isZaloTicket(t) && !isDeptTicket(t)
        }.count
    }

    public var emailCount: Int {
        scopedTickets.filter { t in
            isEmailTicket(t)
        }.count
    }

    public var zaloCount: Int {
        scopedTickets.filter { t in
            isZaloTicket(t)
        }.count
    }

    public var deptCount: Int {
        scopedTickets.filter { t in
            !isEmailTicket(t) && !isZaloTicket(t) && isDeptTicket(t)
        }.count
    }

    // MARK: - FILTERED TICKETS BY STATUS, CHANNEL & SEARCH
    public var filteredTickets: [SupportTicket] {
        let baseList = scopedTickets

        let statusFiltered = baseList.filter { t in
            switch filterStatus {
            case "OPEN": return t.isOpen
            case "CLOSED": return t.isClosed
            default: return true // "ALL"
            }
        }

        let channelFiltered = statusFiltered.filter { t in
            let isEm = isEmailTicket(t)
            let isZa = isZaloTicket(t)
            let isDep = !isEm && !isZa && isDeptTicket(t)
            let isAp = !isEm && !isZa && !isDep

            switch filterSource {
            case "APP": return isAp
            case "ZALO": return isZa
            case "EMAIL": return isEm
            case "DEPARTMENT": return isDep
            default: return true // "ALL"
            }
        }

        let result: [SupportTicket]
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = channelFiltered
        } else {
            let q = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            result = channelFiltered.filter { t in
                t.subject.lowercased().contains(q) ||
                t.id.lowercased().contains(q) ||
                t.creatorName.lowercased().contains(q) ||
                t.creatorEmail.lowercased().contains(q) ||
                t.donVi.lowercased().contains(q) ||
                t.assignedToName.lowercased().contains(q) ||
                t.assetName.lowercased().contains(q)
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
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

        // Sort keys: "Hôm nay" first, "Hôm qua" second, then by date descending (newest date first)
        let sortedKeys = grouped.keys.sorted { k1, k2 in
            if k1 == "Hôm nay" { return true }
            if k2 == "Hôm nay" { return false }
            if k1 == "Hôm qua" { return true }
            if k2 == "Hôm qua" { return false }
            let d1 = dateFormatter.date(from: k1) ?? Date.distantPast
            let d2 = dateFormatter.date(from: k2) ?? Date.distantPast
            return d1 > d2
        }

        return sortedKeys.map { key in
            let sortedInGroup = (grouped[key] ?? []).sorted { $0.createdAt > $1.createdAt }
            return (dateGroup: key, tickets: sortedInGroup)
        }
    }

    // MARK: - REAL-TIME TICKET AUTO POLLING (TỐI ƯU HÓA TIẾT KIỆM BỘ ĐỌC FIRESTORE & PIN)
    private var autoPollingTimer: Timer?
    private var pollingDispatchSource: DispatchSourceTimer?
    private var firestoreListenTask: Task<Void, Never>?
    private var isFetchingSilent: Bool = false

    public func startAutoPolling(interval: TimeInterval = 45.0) {
        stopAutoPolling()

        // Sử dụng DispatchSourceTimer trên background queue với tần suất vừa phải (45s) khi người dùng đang mở App
        let queue = DispatchQueue.global(qos: .utility)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval, leeway: .seconds(2))
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.fetchTicketsSilent()
            }
        }
        timer.resume()
        self.pollingDispatchSource = timer
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(compId):listen"
            guard let url = URL(string: urlStr) else { return }

            let listenBody: [String: Any] = [
                "addTarget": [
                    "query": [
                        "parent": "\(ServerConfig.documentsBaseUrl)/companies/\(compId)",
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

    // MARK: - GIỮ TRẠNG THÁI KHI APP CHẠY NỀN (TIẾT KIỆM TỐI ĐA BỘ ĐỌC VÀ PIN)
    private var bgPollingTaskId: UIBackgroundTaskIdentifier = .invalid
    private var bgPollingRenewalTask: Task<Void, Never>?

    public func keepPollingInBackground() {
        // Khi app xuống nền (Background), dừng triệt để polling và audio keep-alive
        // Nhiệm vụ đánh thức khi có vé mới được bàn giao 100% cho Apple Push Notification (APNs/FCM)
        stopAutoPolling()
        BackgroundKeepAliveService.shared.stop()
        if bgPollingTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(bgPollingTaskId)
            bgPollingTaskId = .invalid
        }
        bgPollingRenewalTask?.cancel()
    }

    // MARK: - FETCH ALL TICKETS (FIRESTORE RUN QUERY & DIRECT FALLBACK)
    public func fetchTickets() {
        guard !companyId.isEmpty else { return }
        Task {
            await self.executeFetchTickets(showSpinner: true)
        }
    }

    /// Tải vé ngầm tự động (không hiện vòng quay loading spinner, không gián đoạn cuộn trang)
    public func fetchTicketsSilently() {
        guard !companyId.isEmpty else { return }
        Task {
            await self.executeFetchTickets(showSpinner: false)
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
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp):runQuery"
        guard let url = URL(string: urlStr) else {
            if showSpinner {
                await MainActor.run { self.isLoading = false }
            }
            return
        }

        let queryLimit = 500
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

        if let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
           httpResponse.statusCode == 200 {
            responseData = data
            isSuccess = true
        }

        // Fallback: Nếu runQuery bị lỗi hoặc không có dữ liệu, dùng trực tiếp document listing
        if !isSuccess || responseData == nil {
            let listUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets?pageSize=500"
            if let listUrl = URL(string: listUrlStr) {
                var listReq = URLRequest(url: listUrl)
                if !idToken.isEmpty {
                    listReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                }
                if let (lData, lHttp) = await DatabaseHelper.executeSafeRequest(listReq),
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

                let ackBool = DatabaseHelper.getBool(fields["isAcknowledged"] as? [String: Any]) || DatabaseHelper.getBool(fields["acknowledged"] as? [String: Any])
                let ackAt = DatabaseHelper.getInt64(fields["acknowledgedAt"] as? [String: Any])
                let ackBy = DatabaseHelper.getString(fields["acknowledgedBy"] as? [String: Any])
                let ackByName = DatabaseHelper.getString(fields["acknowledgedByName"] as? [String: Any])
                let hdAckAt = DatabaseHelper.getInt64(fields["helpdeskAcknowledgedAt"] as? [String: Any])
                let hdAckBy = DatabaseHelper.getString(fields["helpdeskAcknowledgedBy"] as? [String: Any])
                let rawMethod = DatabaseHelper.getString(fields["handlingMethod"] as? [String: Any])
                let rawStatus = DatabaseHelper.getString(fields["status"] as? [String: Any]).uppercased()
                let ack = ackBool || ackAt > 0 || !ackBy.isEmpty || !rawMethod.isEmpty || ["PROCESSING", "IN_PROGRESS", "ASSIGNED", "RESOLVED", "CLOSED"].contains(rawStatus)

                // Parse attachments if any
                var attachmentsList: [AttachmentItem] = []
                if let attArray = (fields["attachments"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let values = attArray["values"] as? [[String: Any]] {
                    for (i, v) in values.enumerated() {
                        if let mMap = v["mapValue"] as? [String: Any], let mFields = mMap["fields"] as? [String: Any] {
                            let aId = DatabaseHelper.getString(mFields["id"] as? [String: Any])
                            let aName = DatabaseHelper.getString(mFields["name"] as? [String: Any])
                            let aUrl = DatabaseHelper.getString(mFields["url"] as? [String: Any])
                            let aSize = DatabaseHelper.getInt64(mFields["size"] as? [String: Any])
                            let aType = DatabaseHelper.getString(mFields["type"] as? [String: Any])
                            if !aUrl.isEmpty {
                                attachmentsList.append(AttachmentItem(id: aId.isEmpty ? "att_\(i)" : aId, name: aName.isEmpty ? "file" : aName, url: aUrl, size: aSize, type: aType.isEmpty ? "other" : aType))
                            }
                        } else {
                            let s = DatabaseHelper.getString(v["stringValue"] as? [String: Any] ?? v)
                            if !s.isEmpty {
                                attachmentsList.append(AttachmentItem(id: "att_\(i)", name: "Tệp đính kèm", url: s, type: "image"))
                            }
                        }
                    }
                }
                if attachmentsList.isEmpty {
                    let imgList = DatabaseHelper.getStringArray(fields["images"] as? [String: Any])
                    for (i, url) in imgList.enumerated() {
                        if !url.isEmpty {
                            attachmentsList.append(AttachmentItem(id: "img_\(i)", name: "Ảnh sự cố ban đầu", url: url, type: "image"))
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
                                let lat = DatabaseHelper.getDouble(vm["lat"] as? [String: Any])
                                let lng = DatabaseHelper.getDouble(vm["lng"] as? [String: Any])
                                if lat != 0 && lng != 0 {
                                    routeCoords.append([lat, lng])
                                }
                            }
                        }
                    }
                    parsedTracking = TicketTracking(
                        ticketId: DatabaseHelper.getString(tFields["ticketId"] as? [String: Any]),
                        technicianEmail: DatabaseHelper.getString(tFields["technicianEmail"] as? [String: Any]),
                        technicianName: DatabaseHelper.getString(tFields["technicianName"] as? [String: Any]),
                        technicianPhone: DatabaseHelper.getString(tFields["technicianPhone"] as? [String: Any]),
                        currentLat: DatabaseHelper.getDouble(tFields["currentLat"] as? [String: Any]),
                        currentLng: DatabaseHelper.getDouble(tFields["currentLng"] as? [String: Any]),
                        speedKmh: Float(DatabaseHelper.getDouble(tFields["speedKmh"] as? [String: Any])),
                        heading: Float(DatabaseHelper.getDouble(tFields["heading"] as? [String: Any])),
                        startLat: DatabaseHelper.getDouble(tFields["startLat"] as? [String: Any]),
                        startLng: DatabaseHelper.getDouble(tFields["startLng"] as? [String: Any]),
                        startAddress: DatabaseHelper.getString(tFields["startAddress"] as? [String: Any]),
                        startName: DatabaseHelper.getString(tFields["startName"] as? [String: Any]),
                        destLat: DatabaseHelper.getDouble(tFields["destLat"] as? [String: Any]),
                        destLng: DatabaseHelper.getDouble(tFields["destLng"] as? [String: Any]),
                        destAddress: DatabaseHelper.getString(tFields["destAddress"] as? [String: Any]),
                        destName: DatabaseHelper.getString(tFields["destName"] as? [String: Any]),
                        distanceKm: DatabaseHelper.getDouble(tFields["distanceKm"] as? [String: Any]),
                        traveledDistanceKm: DatabaseHelper.getDouble(tFields["traveledDistanceKm"] as? [String: Any]),
                        etaMinutes: DatabaseHelper.getInt(tFields["etaMinutes"] as? [String: Any]),
                        status: DatabaseHelper.getString(tFields["status"] as? [String: Any]),
                        lastUpdatedAt: DatabaseHelper.getInt64(tFields["lastUpdatedAt"] as? [String: Any]),
                        isGpsLost: DatabaseHelper.getBool(tFields["isGpsLost"] as? [String: Any]),
                        lastGpsLostAt: DatabaseHelper.getInt64(tFields["lastGpsLostAt"] as? [String: Any]),
                        isArrivedVerified: DatabaseHelper.getBool(tFields["isArrivedVerified"] as? [String: Any]),
                        cancelledBy: DatabaseHelper.getString(tFields["cancelledBy"] as? [String: Any]),
                        cancelReason: DatabaseHelper.getString(tFields["cancelReason"] as? [String: Any]),
                        cancelledAt: DatabaseHelper.getInt64(tFields["cancelledAt"] as? [String: Any]),
                        routeCoordinates: routeCoords
                    )
                }

                // Parse coTechnicians if any
                var parsedCoTechs: [CoTechnician] = []
                if let coArr = (fields["coTechnicians"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let coVals = coArr["values"] as? [[String: Any]] {
                    for cv in coVals {
                        if let cm = (cv["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                            let email = DatabaseHelper.getString(cm["email"] as? [String: Any])
                            if !email.isEmpty {
                                parsedCoTechs.append(CoTechnician(
                                    email: email,
                                    name: DatabaseHelper.getString(cm["name"] as? [String: Any]),
                                    phone: DatabaseHelper.getString(cm["phone"] as? [String: Any]),
                                    role: DatabaseHelper.getString(cm["role"] as? [String: Any]),
                                    assignedAt: DatabaseHelper.getInt64(cm["assignedAt"] as? [String: Any]),
                                    assignedBy: DatabaseHelper.getString(cm["assignedBy"] as? [String: Any]),
                                    isAcknowledged: DatabaseHelper.getBool(cm["isAcknowledged"] as? [String: Any]),
                                    acknowledgedAt: DatabaseHelper.getInt64(cm["acknowledgedAt"] as? [String: Any])
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
                                        let lat = DatabaseHelper.getDouble(rm["lat"] as? [String: Any])
                                        let lng = DatabaseHelper.getDouble(rm["lng"] as? [String: Any])
                                        if lat != 0 && lng != 0 {
                                            cRouteCoords.append([lat, lng])
                                        }
                                    }
                                }
                            }

                            parsedCollabs[k] = TicketTracking(
                                ticketId: DatabaseHelper.getString(vFields["ticketId"] as? [String: Any]),
                                technicianEmail: DatabaseHelper.getString(vFields["technicianEmail"] as? [String: Any]),
                                technicianName: DatabaseHelper.getString(vFields["technicianName"] as? [String: Any]),
                                technicianPhone: DatabaseHelper.getString(vFields["technicianPhone"] as? [String: Any]),
                                currentLat: DatabaseHelper.getDouble(vFields["currentLat"] as? [String: Any]),
                                currentLng: DatabaseHelper.getDouble(vFields["currentLng"] as? [String: Any]),
                                speedKmh: Float(DatabaseHelper.getDouble(vFields["speedKmh"] as? [String: Any])),
                                heading: Float(DatabaseHelper.getDouble(vFields["heading"] as? [String: Any])),
                                startLat: DatabaseHelper.getDouble(vFields["startLat"] as? [String: Any]),
                                startLng: DatabaseHelper.getDouble(vFields["startLng"] as? [String: Any]),
                                startAddress: DatabaseHelper.getString(vFields["startAddress"] as? [String: Any]),
                                startName: DatabaseHelper.getString(vFields["startName"] as? [String: Any]),
                                destLat: DatabaseHelper.getDouble(vFields["destLat"] as? [String: Any]),
                                destLng: DatabaseHelper.getDouble(vFields["destLng"] as? [String: Any]),
                                destAddress: DatabaseHelper.getString(vFields["destAddress"] as? [String: Any]),
                                destName: DatabaseHelper.getString(vFields["destName"] as? [String: Any]),
                                distanceKm: DatabaseHelper.getDouble(vFields["distanceKm"] as? [String: Any]),
                                traveledDistanceKm: DatabaseHelper.getDouble(vFields["traveledDistanceKm"] as? [String: Any]),
                                etaMinutes: DatabaseHelper.getInt(vFields["etaMinutes"] as? [String: Any]),
                                status: DatabaseHelper.getString(vFields["status"] as? [String: Any]),
                                lastUpdatedAt: DatabaseHelper.getInt64(vFields["lastUpdatedAt"] as? [String: Any]),
                                isGpsLost: DatabaseHelper.getBool(vFields["isGpsLost"] as? [String: Any]),
                                lastGpsLostAt: DatabaseHelper.getInt64(vFields["lastGpsLostAt"] as? [String: Any]),
                                isArrivedVerified: DatabaseHelper.getBool(vFields["isArrivedVerified"] as? [String: Any]),
                                cancelledBy: DatabaseHelper.getString(vFields["cancelledBy"] as? [String: Any]),
                                cancelReason: DatabaseHelper.getString(vFields["cancelReason"] as? [String: Any]),
                                cancelledAt: DatabaseHelper.getInt64(vFields["cancelledAt"] as? [String: Any]),
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
                            let handoverId = DatabaseHelper.getString(hm["handoverId"] as? [String: Any])
                            let fromEmail = DatabaseHelper.getString(hm["fromEmail"] as? [String: Any])
                            let fromName = DatabaseHelper.getString(hm["fromName"] as? [String: Any])
                            let fromTitle = DatabaseHelper.getString(hm["fromTitle"] as? [String: Any])
                            let toType = DatabaseHelper.getString(hm["toType"] as? [String: Any])
                            let toEmail = DatabaseHelper.getString(hm["toEmail"] as? [String: Any])
                            let toName = DatabaseHelper.getString(hm["toName"] as? [String: Any])
                            let toTitle = DatabaseHelper.getString(hm["toTitle"] as? [String: Any])
                            let toCluster = DatabaseHelper.getString(hm["toCluster"] as? [String: Any])
                            let reason = DatabaseHelper.getString(hm["reason"] as? [String: Any])
                            let timestamp = DatabaseHelper.getInt64(hm["timestamp"] as? [String: Any])

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

                var parsedInitMsg = DatabaseHelper.getString(fields["initialMessage"] as? [String: Any])
                if parsedInitMsg.isEmpty {
                    parsedInitMsg = DatabaseHelper.getString(fields["description"] as? [String: Any])
                }
                if parsedInitMsg.isEmpty {
                    parsedInitMsg = DatabaseHelper.getString(fields["moTa"] as? [String: Any])
                }
                if parsedInitMsg.isEmpty {
                    parsedInitMsg = DatabaseHelper.getString(fields["content"] as? [String: Any])
                }

                return SupportTicket(
                    id: id,
                    ticketCode: DatabaseHelper.getString(fields["ticketCode"] as? [String: Any]),
                    creatorEmail: DatabaseHelper.getString(fields["creatorEmail"] as? [String: Any]),
                    creatorName: DatabaseHelper.getString(fields["creatorName"] as? [String: Any]),
                    creatorPhone: DatabaseHelper.getString(fields["creatorPhone"] as? [String: Any]),
                    creatorUserId: DatabaseHelper.getString(fields["creatorUserId"] as? [String: Any]),
                    creatorLat: DatabaseHelper.getDouble(fields["creatorLat"] as? [String: Any]),
                    creatorLng: DatabaseHelper.getDouble(fields["creatorLng"] as? [String: Any]),
                    creatorAddress: DatabaseHelper.getString(fields["creatorAddress"] as? [String: Any]),
                    subject: DatabaseHelper.getString(fields["subject"] as? [String: Any]),
                    status: DatabaseHelper.getString(fields["status"] as? [String: Any]),
                    category: DatabaseHelper.getString(fields["category"] as? [String: Any]),
                    priority: DatabaseHelper.getString(fields["priority"] as? [String: Any]),
                    assetId: DatabaseHelper.getString(fields["assetId"] as? [String: Any]),
                    assetName: DatabaseHelper.getString(fields["assetName"] as? [String: Any]),
                    images: DatabaseHelper.getStringArray(fields["images"] as? [String: Any]),
                    attachments: attachmentsList,
                    createdAt: DatabaseHelper.getInt64(fields["createdAt"] as? [String: Any]),
                    lastMessage: DatabaseHelper.getString(fields["lastMessage"] as? [String: Any]),
                    lastMessageAt: DatabaseHelper.getInt64(fields["lastMessageAt"] as? [String: Any]),
                    companyId: DatabaseHelper.getString(fields["companyId"] as? [String: Any]),
                    departmentId: DatabaseHelper.getString(fields["departmentId"] as? [String: Any]),
                    donVi: DatabaseHelper.getString(fields["donVi"] as? [String: Any]),
                    initialMessage: parsedInitMsg,
                    rating: DatabaseHelper.getInt(fields["rating"] as? [String: Any]),
                    feedback: DatabaseHelper.getString(fields["feedback"] as? [String: Any]),
                    feedbackAt: DatabaseHelper.getInt64(fields["feedbackAt"] as? [String: Any]),
                    parentTicketId: DatabaseHelper.getString(fields["parentTicketId"] as? [String: Any]),
                    assignedTo: DatabaseHelper.getString(fields["assignedTo"] as? [String: Any]),
                    assignedDepartmentId: DatabaseHelper.getString(fields["assignedDepartmentId"] as? [String: Any]),
                    assignedDepartmentName: DatabaseHelper.getString(fields["assignedDepartmentName"] as? [String: Any]),
                    assignedToEmail: DatabaseHelper.getString(fields["assignedToEmail"] as? [String: Any]),
                    assignedToName: DatabaseHelper.getString(fields["assignedToName"] as? [String: Any]),
                    assignedCluster: DatabaseHelper.getString(fields["assignedCluster"] as? [String: Any]),
                    assignedRegion: DatabaseHelper.getString(fields["assignedRegion"] as? [String: Any]),
                    assignedByEmail: DatabaseHelper.getString(fields["assignedByEmail"] as? [String: Any]),
                    assignedAt: DatabaseHelper.getInt64(fields["assignedAt"] as? [String: Any]),
                    dispatchNote: DatabaseHelper.getString(fields["dispatchNote"] as? [String: Any]),
                    handlingMethod: DatabaseHelper.getString(fields["handlingMethod"] as? [String: Any]),
                    handlingMethodUpdatedAt: DatabaseHelper.getInt64(fields["handlingMethodUpdatedAt"] as? [String: Any]),
                    coTechnicians: parsedCoTechs,
                    tracking: parsedTracking,
                    collaboratorTrackings: parsedCollabs,
                    isAcknowledged: ack,
                    acknowledgedAt: ackAt,
                    acknowledgedBy: ackBy,
                    acknowledgedByName: ackByName,
                    helpdeskAcknowledgedAt: hdAckAt,
                    helpdeskAcknowledgedBy: hdAckBy,
                    resolvedAt: DatabaseHelper.getInt64(fields["resolvedAt"] as? [String: Any]),
                    resolvedBy: DatabaseHelper.getString(fields["resolvedBy"] as? [String: Any]),
                    resolvedByName: DatabaseHelper.getString(fields["resolvedByName"] as? [String: Any]),
                    resolutionNote: DatabaseHelper.getString(fields["resolutionNote"] as? [String: Any]),
                    resolvedReason: DatabaseHelper.getString(fields["resolvedReason"] as? [String: Any]),
                    closedAt: DatabaseHelper.getInt64(fields["closedAt"] as? [String: Any]),
                    closedByEmail: DatabaseHelper.getString(fields["closedByEmail"] as? [String: Any]),
                    closedByName: DatabaseHelper.getString(fields["closedByName"] as? [String: Any]),
                    ratingResponse: DatabaseHelper.getInt(fields["ratingResponse"] as? [String: Any]),
                    ratingResolve: DatabaseHelper.getInt(fields["ratingResolve"] as? [String: Any]),
                    ratingAttitude: DatabaseHelper.getInt(fields["ratingAttitude"] as? [String: Any]),
                    ratingQuality: DatabaseHelper.getInt(fields["ratingQuality"] as? [String: Any]),
                    isAutoRated: DatabaseHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                    reopenCount: DatabaseHelper.getInt(fields["reopenCount"] as? [String: Any]),
                    isQualityPassed: DatabaseHelper.getBool(fields["isQualityPassed"] as? [String: Any]),
                    source: DatabaseHelper.getString(fields["source"] as? [String: Any]),
                    isInvalid: DatabaseHelper.getBool(fields["isInvalid"] as? [String: Any]),
                    invalidReason: DatabaseHelper.getString(fields["invalidReason"] as? [String: Any]),
                    previousRating: DatabaseHelper.getInt(fields["previousRating"] as? [String: Any]),
                    previousFeedback: DatabaseHelper.getString(fields["previousFeedback"] as? [String: Any]),
                    isObjectiveExclusion: DatabaseHelper.getBool(fields["isObjectiveExclusion"] as? [String: Any]),
                    objectiveExclusionReason: DatabaseHelper.getString(fields["objectiveExclusionReason"] as? [String: Any]),
                    reopenedAt: DatabaseHelper.getInt64(fields["reopenedAt"] as? [String: Any]),
                    reopenedByEmail: DatabaseHelper.getString(fields["reopenedByEmail"] as? [String: Any]),
                    reopenedByName: DatabaseHelper.getString(fields["reopenedByName"] as? [String: Any]),
                    reopenReason: DatabaseHelper.getString(fields["reopenReason"] as? [String: Any]),
                    handoverHistory: parsedHandoverHistory,
                    assignedApplication: DatabaseHelper.getString(fields["assignedApplication"] as? [String: Any]),
                    assignedRole: DatabaseHelper.getString(fields["assignedRole"] as? [String: Any]),
                    scope: DatabaseHelper.getString(fields["scope"] as? [String: Any]),
                    toNghiepVu: DatabaseHelper.getString(fields["toNghiepVu"] as? [String: Any]),
                    messageCount: {
                        let c = DatabaseHelper.getInt(fields["messageCount"] as? [String: Any])
                        return c > 0 ? c : 1
                    }(),
                    hasNewReply: DatabaseHelper.getBool(fields["hasNewReply"] as? [String: Any]),
                    isThreadActive: DatabaseHelper.getBool(fields["isThreadActive"] as? [String: Any]),
                    lastSenderName: DatabaseHelper.getString(fields["lastSenderName"] as? [String: Any]),
                    lastSenderEmail: DatabaseHelper.getString(fields["lastSenderEmail"] as? [String: Any]),
                    conversationId: DatabaseHelper.getString(fields["conversationId"] as? [String: Any]),
                    normalizedSubject: DatabaseHelper.getString(fields["normalizedSubject"] as? [String: Any])
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
        phone: String = "",
        images: [String] = [],
        attachments: [AttachmentItem] = [],
        donVi: String = "",
        gpsLat: Double = 0.0,
        gpsLng: Double = 0.0,
        scope: String = "UNIT"
    ) async -> String? {
        // Kiểm tra quyền tạo ticket: Kỹ thuật viên (KTV), Chuyên viên, Helpdesk, Admin không được tạo phiếu mới
        guard user.canCreateTicket else {
            print("⚠️ SupportVM: User \(user.email) (role: \(user.role)) is not allowed to create tickets.")
            await MainActor.run {
                self.errorMessage = "Kỹ thuật viên / Chuyên viên không được phép tạo phiếu hỗ trợ. Chỉ người dùng đơn vị mới được phép gửi yêu cầu."
            }
            return nil
        }

        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (user.companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "SGCOOP" : user.companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased())
            : companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        var token = self.idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if token.isEmpty || !token.hasPrefix("ey") {
            if let saved = UserDefaults.standard.string(forKey: "saved_auth_token"), saved.hasPrefix("ey") {
                token = saved
            }
        }
        if token.isEmpty {
            if let guest = await AuthService.shared.ensureGuestToken() {
                token = guest
            }
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date()) % 100
        let month = calendar.component(.month, from: Date())
        let yymm = String(format: "%02d%02d", year, month)
        let randNum = Int.random(in: 1000...9999)
        let generatedTicketCode = "APP-\(yymm)-\(randNum)"
        let customTicketId = "ticket_\(now)_\(randNum)"

        let effectiveDonVi = !donVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? donVi : user.donVi
        let effectivePhone = !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? phone : user.phone

        var fields: [String: Any] = [
            "id": ["stringValue": customTicketId],
            "ticketCode": ["stringValue": generatedTicketCode],
            "subject": ["stringValue": subject],
            "initialMessage": ["stringValue": initialMessage],
            "lastMessage": ["stringValue": initialMessage],
            "category": ["stringValue": category],
            "priority": ["stringValue": priority],
            "status": ["stringValue": "OPEN"],
            "creatorUserId": ["stringValue": !user.id.isEmpty ? user.id : user.maNhanVien],
            "creatorEmail": ["stringValue": user.email],
            "creatorName": ["stringValue": !user.fullName.isEmpty ? user.fullName : user.email],
            "creatorPhone": ["stringValue": effectivePhone],
            "phone": ["stringValue": effectivePhone],
            "donVi": ["stringValue": effectiveDonVi],
            "departmentId": ["stringValue": user.departmentId],
            "companyId": ["stringValue": cleanComp],
            "createdAt": ["integerValue": String(now)],
            "lastMessageAt": ["integerValue": String(now)],
            "source": ["stringValue": "APP"],
            "scope": ["stringValue": !scope.isEmpty ? scope : "UNIT"]
        ]

        if !assetId.isEmpty { fields["assetId"] = ["stringValue": assetId] }
        if !assetName.isEmpty { fields["assetName"] = ["stringValue": assetName] }
        if gpsLat != 0.0 { fields["creatorLat"] = ["doubleValue": gpsLat] }
        if gpsLng != 0.0 { fields["creatorLng"] = ["doubleValue": gpsLng] }
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
        let jsonBody = try? JSONSerialization.data(withJSONObject: body)

        // 1. Cố gắng tạo document bằng PATCH với customTicketId (đồng bộ 1:1 theo Android SupportRestRepository.kt)
        let patchUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets/\(customTicketId)"
        var finalTicketId = customTicketId
        var creationSuccess = false

        if let patchUrl = URL(string: patchUrlStr) {
            var patchRequest = URLRequest(url: patchUrl)
            patchRequest.httpMethod = "PATCH"
            patchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            patchRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            patchRequest.httpBody = jsonBody

            if let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(patchRequest),
               (200...299).contains(httpResponse.statusCode) {
                creationSuccess = true
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = json["name"] as? String {
                    let parsed = name.components(separatedBy: "/").last ?? ""
                    if !parsed.isEmpty { finalTicketId = parsed }
                }
            }
        }

        // 2. Fallback sang POST /companies/{cleanComp}/support_tickets nếu PATCH chưa thành công
        if !creationSuccess, let postUrl = URL(string: "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets") {
            var postRequest = URLRequest(url: postUrl)
            postRequest.httpMethod = "POST"
            postRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            postRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            postRequest.httpBody = jsonBody

            if let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(postRequest),
               (200...299).contains(httpResponse.statusCode) {
                creationSuccess = true
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let name = json["name"] as? String {
                    let parsed = name.components(separatedBy: "/").last ?? ""
                    if !parsed.isEmpty { finalTicketId = parsed }
                }
            }
        }

        guard creationSuccess else {
            print("[SupportVM] ❌ Tạo ticket thất bại trên cả PATCH và POST")
            return nil
        }

        // Nội dung ban đầu của sự cố được lưu tại ticket.initialMessage để hiển thị tại mục "📝 Nội dung yêu cầu:", không gửi trùng vào messages subcollection

        // Ghi nhận log tin nhắn hệ thống nếu ticket được tự động điều phối ngoài giờ
        if let auto = autoDispatchedTech {
            let escMin = self.slaConfig.escalationTimeoutMinutes > 0 ? self.slaConfig.escalationTimeoutMinutes : 15
            let autoDispatchMsg = """
            ⏰ [TỰ ĐỘNG ĐIỀU PHỐI NGOÀI GIỜ]
            Sự cố phát sinh ngoài giờ trực của HelpDesk (\(offHoursCheck.reason)).
            Hệ thống đã tự động gán vé cho KTV \(auto.name) thuộc Cụm \(auto.assignedCluster).
            ⏱️ Vui lòng xác nhận tiếp nhận trong vòng \(escMin) phút.
            """
            sendMessage(ticketId: finalTicketId, text: autoDispatchMsg, isSystemMessage: true, customTimestamp: now + 500)
        }

        fetchTickets()
        return finalTicketId
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
        scope: String = "UNIT",
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
                phone: phone,
                images: images,
                attachments: attachments,
                donVi: donVi,
                gpsLat: gpsLat,
                gpsLng: gpsLng,
                scope: scope
            )
            DispatchQueue.main.async {
                completion?(res != nil)
            }
        }
    }

    // MARK: - CHAT MESSAGES
    public func fetchMessages(for ticketId: String) {
        Task {
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let safeToken = idToken.isEmpty ? "default_token" : idToken
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets/\(ticketId)/messages?pageSize=100"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(safeToken)", forHTTPHeaderField: "Authorization")

            guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }

            let documents = (json["documents"] as? [[String: Any]]) ?? []
            if documents.isEmpty {
                await MainActor.run {
                    self.messages = []
                }
                return
            }

            let msgs: [SupportMessage] = documents.compactMap { doc in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""

                // Parse attachments (hỗ trợ cả mapValue chuẩn và stringValue fallback)
                let attachmentItems: [AttachmentItem] = {
                    guard let arrVal = fields["attachments"] as? [String: Any],
                          let arr = arrVal["arrayValue"] as? [String: Any],
                          let vals = arr["values"] as? [[String: Any]] else { return [] }
                    return vals.compactMap { item -> AttachmentItem? in
                        if let mapVal = item["mapValue"] as? [String: Any],
                           let mv = mapVal["fields"] as? [String: Any] {
                            let urlStr = DatabaseHelper.getString(mv["url"] as? [String: Any])
                            guard !urlStr.isEmpty else { return nil }
                            let nameStr = DatabaseHelper.getString(mv["name"] as? [String: Any])
                            let typeStr = DatabaseHelper.getString(mv["type"] as? [String: Any])
                            let sizeVal = DatabaseHelper.getInt64(mv["size"] as? [String: Any])
                            let idStr = DatabaseHelper.getString(mv["id"] as? [String: Any])
                            let ext = (urlStr as NSString).pathExtension.lowercased()
                            let isImg = ["png", "jpg", "jpeg", "webp", "bmp"].contains(ext) || typeStr.lowercased() == "image"
                            return AttachmentItem(
                                id: idStr.isEmpty ? "att_\(urlStr.hashValue)" : idStr,
                                name: nameStr.isEmpty ? (urlStr.components(separatedBy: "/").last ?? "file") : nameStr,
                                url: urlStr,
                                size: sizeVal,
                                type: isImg ? "image" : (typeStr.isEmpty ? "file" : typeStr)
                            )
                        } else {
                            let urlStr = DatabaseHelper.getString(item["stringValue"] as? [String: Any] ?? item)
                            guard !urlStr.isEmpty, let _ = URL(string: urlStr) else { return nil }
                            let ext = (urlStr as NSString).pathExtension.lowercased()
                            let isImg = ["png", "jpg", "jpeg", "webp", "bmp"].contains(ext)
                            return AttachmentItem(name: urlStr.components(separatedBy: "/").last ?? "file", url: urlStr, type: isImg ? "image" : "file")
                        }
                    }
                }()

                return SupportMessage(
                    id: id,
                    senderEmail: DatabaseHelper.getString(fields["senderEmail"] as? [String: Any]),
                    senderName: DatabaseHelper.getString(fields["senderName"] as? [String: Any]),
                    message: DatabaseHelper.getString(fields["message"] as? [String: Any]),
                    timestamp: DatabaseHelper.getInt64(fields["timestamp"] as? [String: Any]),
                    isAdminReply: DatabaseHelper.getBool(fields["isAdminReply"] as? [String: Any]),
                    donVi: DatabaseHelper.getString(fields["donVi"] as? [String: Any]),
                    departmentId: DatabaseHelper.getString(fields["departmentId"] as? [String: Any]),
                    isSystemMessage: DatabaseHelper.getBool(fields["isSystemMessage"] as? [String: Any]),
                    isInternal: DatabaseHelper.getBool(fields["isInternal"] as? [String: Any]),
                    attachments: attachmentItems
                )
            }

            // Lọc bỏ tin nhắn trùng lặp (theo ID hoặc cùng nội dung trong vòng 5 giây)
            var deduplicated: [SupportMessage] = []
            for msg in msgs {
                let isDup = deduplicated.contains { existing in
                    let sameContent = existing.message.trimmingCharacters(in: .whitespacesAndNewlines) == msg.message.trimmingCharacters(in: .whitespacesAndNewlines) &&
                        existing.senderEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == msg.senderEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let closeTime = abs(existing.timestamp - msg.timestamp) <= 5000
                    let isSys = msg.isSystemMessage || msg.message.contains("Điều phối") || msg.message.contains("xử lý xong")
                    return existing.id == msg.id || (sameContent && closeTime) || (sameContent && isSys)
                }
                if !isDup {
                    deduplicated.append(msg)
                }
            }

            let curTicket = self.tickets.first(where: { $0.id == ticketId })
            let cEmail = (curTicket?.creatorEmail ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let cInitMsg = curTicket?.initialMessage ?? ""

            let sortedMsgs = deduplicated.sorted { a, b in
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            let resp = await DatabaseHelper.executeSafeRequest(request)
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            let resp = await DatabaseHelper.executeSafeRequest(request)
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
            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let safeToken = idToken.isEmpty ? "default_token" : idToken
            let now = customTimestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets/\(ticketId)/messages"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(safeToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Build attachments arrayValue nếu có file đính kèm dưới dạng mapValue đồng bộ với Web & Android
            let attachmentsField: [String: Any] = attachmentUrls.isEmpty ? [:] : [
                "attachments": [
                    "arrayValue": [
                        "values": attachmentUrls.map { url in
                            let ext = (url as NSString).pathExtension.lowercased()
                            let isImg = ["png", "jpg", "jpeg", "webp", "bmp"].contains(ext)
                            let fileName = url.components(separatedBy: "/").last ?? "file"
                            return [
                                "mapValue": [
                                    "fields": [
                                        "id": ["stringValue": "att_\(Int64(Date().timeIntervalSince1970 * 1000))_\(Int.random(in: 1000...9999))"],
                                        "name": ["stringValue": fileName],
                                        "url": ["stringValue": url],
                                        "type": ["stringValue": isImg ? "image" : "file"],
                                        "size": ["integerValue": "0"]
                                    ]
                                ]
                            ]
                        }
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
            _ = await DatabaseHelper.executeSafeRequest(request)

            // Update ticket lastMessage & lastMessageAt (chỉ cập nhật lastMessage nếu không phải ghi chú nội bộ)
            let lastMsg = cleanText.isEmpty ? "📎 Đính kèm \(attachmentUrls.count) tệp" : cleanText
            let patchUrlStr = isInternal
                ? "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets/\(ticketId)?updateMask.fieldPaths=lastMessageAt"
                : "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/support_tickets/\(ticketId)?updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            if let patchUrl = URL(string: patchUrlStr) {
                var pReq = URLRequest(url: patchUrl)
                pReq.httpMethod = "PATCH"
                pReq.setValue("Bearer \(safeToken)", forHTTPHeaderField: "Authorization")
                pReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                var patchFields: [String: Any] = [
                    "lastMessageAt": ["integerValue": String(now)]
                ]
                if !isInternal {
                    patchFields["lastMessage"] = ["stringValue": lastMsg]
                }
                let pBody: [String: Any] = [
                    "fields": patchFields
                ]
                pReq.httpBody = try? JSONSerialization.data(withJSONObject: pBody)
                _ = await DatabaseHelper.executeSafeRequest(pReq)
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=resolvedBy&updateMask.fieldPaths=resolvedByName&updateMask.fieldPaths=resolutionNote"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let updateUrl = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=ratingEmailSent&updateMask.fieldPaths=ratingEmailSentAt"
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
                _ = await DatabaseHelper.executeSafeRequest(req)
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
        let compDocUrl = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/system_config/email_integration"
        if let u = URL(string: compDocUrl), let (data, resp) = await DatabaseHelper.safeGet(url: u, idToken: idToken), resp == 200 {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let cfg = CompanyEmailConfig.fromFirestore(fields)
                if cfg.isConfigured { return cfg }
            }
        }

        // 2. Fallback: Cấu hình dùng chung toàn hệ thống /system_config/email_integration
        let globalDocUrl = "\(ServerConfig.documentsBaseUrl)/system_config/email_integration"
        if let u = URL(string: globalDocUrl), let (data, resp) = await DatabaseHelper.safeGet(url: u, idToken: idToken), resp == 200 {
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

            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?updateMask.fieldPaths=status&updateMask.fieldPaths=reopenCount&updateMask.fieldPaths=reopenedAt&updateMask.fieldPaths=reopenedByEmail&updateMask.fieldPaths=reopenedByName&updateMask.fieldPaths=reopenReason&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=resolvedReason&updateMask.fieldPaths=rating&updateMask.fieldPaths=isQualityPassed&updateMask.fieldPaths=previousRating&updateMask.fieldPaths=previousFeedback"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(fields)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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

            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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

            // Lấy ticket hiện tại để kiểm tra trạng thái và phát hiện điều phối lại
            let currentTicket = self.rawTickets.first { $0.id == ticketId }
            let curStatus = (currentTicket?.status ?? "").uppercased()
            if curStatus == "CLOSED" || curStatus == "RESOLVED" || (currentTicket?.closedAt ?? 0) > 0 || (currentTicket?.resolvedAt ?? 0) > 0 {
                completion?(false)
                return
            }

            let curAssigned = (currentTicket?.assignedToEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanTech = techEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !curAssigned.isEmpty && curAssigned == cleanTech && (currentTicket?.assignedDepartmentId ?? "") == deptId && (currentTicket?.dispatchNote ?? "") == note {
                completion?(true)
                return
            }

            let isReDispatch = !curAssigned.isEmpty && curAssigned != cleanTech
            let oldName = (currentTicket?.assignedToName ?? "").isEmpty ? curAssigned : (currentTicket?.assignedToName ?? "")
            let dispatchPrefix = isReDispatch
                ? "🔄 [Điều phối lại] Chuyển giao từ \(oldName) sang \(finalDeptName)\(techInfo)"
                : "🔄 [Điều phối] HelpDesk đã chuyển giao yêu cầu cho \(finalDeptName)\(techInfo)"

            let appInfo = !assignedApplication.isEmpty ? " • Ứng dụng: \(assignedApplication)" : ""
            let noteInfo = !note.isEmpty ? " • Ghi chú: \(note)" : ""
            let dispatchMsg = "\(dispatchPrefix)\(appInfo)\(noteInfo)"

            let existingCoTechs = (currentTicket?.coTechnicians ?? []).filter {
                $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != cleanTech
            }
            let existingCoTechEmails = existingCoTechs.map { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

            var allAssignedEmails: [String] = []
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else { completion?(false); return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])

            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(maskStr)"
            guard let url = URL(string: urlStr) else {
                DispatchQueue.main.async { completion?(false) }
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": f])

            _ = await DatabaseHelper.executeSafeRequest(request)

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
                let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticket.id)?\(maskStr)"
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
                _ = await DatabaseHelper.executeSafeRequest(request)

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

            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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

            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)
        }
    }

    public func markArrived(ticketId: String, isSpecialist: Bool = false, isCoTech: Bool = false, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let sanitizedKey = user.email.lowercased().replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            let fieldPrefix = isCoTech ? "collaboratorTrackings.\(sanitizedKey)" : "tracking"
            let mask = "updateMask.fieldPaths=\(fieldPrefix).status&updateMask.fieldPaths=\(fieldPrefix).isArrivedVerified&updateMask.fieldPaths=\(fieldPrefix).lastUpdatedAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    public func switchToRemote(ticketId: String, isSpecialist: Bool = false, completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let mask = "updateMask.fieldPaths=handlingMethod&updateMask.fieldPaths=tracking.status&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

            sendMessage(ticketId: ticketId, text: msg)
            self.fetchTickets()
            DispatchQueue.main.async { completion?(true) }
        }
    }

    public func cancelTrip(ticketId: String, reason: String = "HelpDesk hủy chuyến", completion: ((Bool) -> Void)? = nil) {
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let mask = "updateMask.fieldPaths=tracking.status&updateMask.fieldPaths=tracking.cancelReason&updateMask.fieldPaths=tracking.cancelledAt&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets/\(ticketId)?\(mask)"
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
            _ = await DatabaseHelper.executeSafeRequest(request)

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
            let usersUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(comp)/users?pageSize=200"
            if let uUrl = URL(string: usersUrlStr) {
                var uReq = URLRequest(url: uUrl)
                if !idToken.isEmpty { uReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (uData, uResp) = await DatabaseHelper.executeSafeRequest(uReq),
                   uResp.statusCode == 200,
                   let uJson = try? JSONSerialization.jsonObject(with: uData) as? [String: Any],
                   let uDocs = uJson["documents"] as? [[String: Any]], !uDocs.isEmpty {
                    loadedStaff = parseStaffUsers(from: uDocs, companyId: comp, nowMs: nowMs)
                }
            }

            if loadedStaff.isEmpty {
                let rootUsersUrl = "\(ServerConfig.documentsBaseUrl)/users?pageSize=200"
                if let rUrl = URL(string: rootUsersUrl) {
                    var rReq = URLRequest(url: rUrl)
                    if !idToken.isEmpty { rReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                    if let (rData, rResp) = await DatabaseHelper.executeSafeRequest(rReq),
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
            let specUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(comp)/specialist_teams?pageSize=50"
            if let sUrl = URL(string: specUrlStr) {
                var sReq = URLRequest(url: sUrl)
                if !idToken.isEmpty { sReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (sData, sResp) = await DatabaseHelper.executeSafeRequest(sReq),
                   sResp.statusCode == 200,
                   let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
                   let sDocs = sJson["documents"] as? [[String: Any]], !sDocs.isEmpty {
                    let dynamicTeams = sDocs.compactMap { doc -> SpecialistTeamInfo? in
                        guard let docName = doc["name"] as? String,
                              let fields = doc["fields"] as? [String: Any] else { return nil }
                        let id = docName.components(separatedBy: "/").last ?? ""
                        let teamId = DatabaseHelper.getString(fields["teamId"] as? [String: Any]).isEmpty ? id : DatabaseHelper.getString(fields["teamId"] as? [String: Any])
                        let teamName = DatabaseHelper.getString(fields["teamName"] as? [String: Any]).isEmpty ? (DatabaseHelper.getString(fields["name"] as? [String: Any]).isEmpty ? teamId : DatabaseHelper.getString(fields["name"] as? [String: Any])) : DatabaseHelper.getString(fields["teamName"] as? [String: Any])
                        let apps = DatabaseHelper.getStringArray(fields["applications"] as? [String: Any])
                        let desc = DatabaseHelper.getString(fields["description"] as? [String: Any])
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
            let rawEmail = DatabaseHelper.getString(fields["email"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let email = !rawEmail.isEmpty && rawEmail.contains("@") ? rawEmail : (docName.components(separatedBy: "/").last?.lowercased() ?? "")
            guard email.contains("@") && !email.hasPrefix("device_") else { return nil }

            let rawDept = DatabaseHelper.getString(fields["departmentId"] as? [String: Any])
            let rawPb = DatabaseHelper.getString(fields["phongBan"] as? [String: Any])
            let finalDept = rawDept.isEmpty ? rawPb : rawDept
            let name = DatabaseHelper.getString(fields["fullName"] as? [String: Any]).isEmpty
                ? (DatabaseHelper.getString(fields["name"] as? [String: Any]).isEmpty
                    ? (DatabaseHelper.getString(fields["displayName"] as? [String: Any]).isEmpty
                        ? DatabaseHelper.getString(fields["hoTen"] as? [String: Any])
                        : DatabaseHelper.getString(fields["displayName"] as? [String: Any]))
                    : DatabaseHelper.getString(fields["name"] as? [String: Any]))
                : DatabaseHelper.getString(fields["fullName"] as? [String: Any])
            let maKhuVuc = DatabaseHelper.getString(fields["maKhuVuc"] as? [String: Any]).isEmpty
                ? DatabaseHelper.getString(fields["khuVuc"] as? [String: Any])
                : DatabaseHelper.getString(fields["maKhuVuc"] as? [String: Any])
            var toNghiepVu = DatabaseHelper.getString(fields["toNghiepVu"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
            if toNghiepVu.isEmpty && maKhuVuc.hasPrefix("TO_") {
                toNghiepVu = maKhuVuc
            }

            let lastActiveAt = DatabaseHelper.getInt64(fields["lastActiveAt"] as? [String: Any])
            let rawOnline = DatabaseHelper.getBool(fields["isOnline"] as? [String: Any]) || DatabaseHelper.getBool(fields["online"] as? [String: Any])
            let isOnDuty = DatabaseHelper.getBool(fields["isOnDuty"] as? [String: Any])
            let onDutyShift = DatabaseHelper.getString(fields["onDutyShift"] as? [String: Any])
            let onDutySource = DatabaseHelper.getString(fields["onDutySource"] as? [String: Any])
            let onDutySince = DatabaseHelper.getInt64(fields["onDutySince"] as? [String: Any])
            let isOnline = (rawOnline && (lastActiveAt > 0) && (nowMs - lastActiveAt <= 15 * 60 * 1000)) || isOnDuty

            return User(
                maNhanVien: DatabaseHelper.getString(fields["maNhanVien"] as? [String: Any]),
                email: email,
                role: DatabaseHelper.getString(fields["role"] as? [String: Any]).isEmpty ? "STAFF" : DatabaseHelper.getString(fields["role"] as? [String: Any]),
                fullName: name.isEmpty ? (email.components(separatedBy: "@").first ?? "") : name,
                phone: DatabaseHelper.getString(fields["phone"] as? [String: Any]),
                donVi: DatabaseHelper.getString(fields["donVi"] as? [String: Any]),
                companyId: companyId,
                departmentId: finalDept,
                status: DatabaseHelper.getString(fields["status"] as? [String: Any]).isEmpty ? "ACTIVE" : DatabaseHelper.getString(fields["status"] as? [String: Any]),
                avatarUrl: DatabaseHelper.getString(fields["avatarUrl"] as? [String: Any]),
                createdAt: DatabaseHelper.getInt64(fields["createdAt"] as? [String: Any]),
                mustChangePassword: DatabaseHelper.getBool(fields["mustChangePassword"] as? [String: Any]),
                maKhuVuc: maKhuVuc,
                toNghiepVu: toNghiepVu,
                lastActiveAt: lastActiveAt,
                isOnline: isOnline,
                permissions: DatabaseHelper.getStringArray(fields["permissions"] as? [String: Any]),
                disabledReason: DatabaseHelper.getString(fields["disabledReason"] as? [String: Any]),
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
            let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users?pageSize=200"
            guard let url = URL(string: urlStr) else {
                self.isLoadingKtvs = false
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let docs = json["documents"] as? [[String: Any]] else {
                self.isLoadingKtvs = false
                return
            }

            // 1. Lấy tọa độ GPS thời gian thực từ technician_locations
            var techGpsMap: [String: (lat: Double, lng: Double)] = [:]
            if let tLocUrl = URL(string: "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/technician_locations?pageSize=200") {
                var tLocReq = URLRequest(url: tLocUrl)
                if !idToken.isEmpty { tLocReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (tData, tResp) = await DatabaseHelper.executeSafeRequest(tLocReq),
                   tResp.statusCode == 200,
                   let tJson = try? JSONSerialization.jsonObject(with: tData) as? [String: Any],
                   let tDocs = tJson["documents"] as? [[String: Any]] {
                    for td in tDocs {
                        guard let tFields = td["fields"] as? [String: Any] else { continue }
                        let docName = (td["name"] as? String)?.components(separatedBy: "/").last ?? ""
                        let tEmail = DatabaseHelper.getString(tFields["email"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let keyEmail = tEmail.isEmpty ? docName.lowercased() : tEmail
                        let tLat = DatabaseHelper.getDouble(tFields["lat"] as? [String: Any])
                        let tLng = DatabaseHelper.getDouble(tFields["lng"] as? [String: Any])
                        if tLat != 0.0 && tLng != 0.0 {
                            techGpsMap[keyEmail] = (tLat, tLng)
                            techGpsMap[keyEmail.replacingOccurrences(of: "/", with: "_")] = (tLat, tLng)
                        }
                    }
                }
            }

            // 2. Lấy tọa độ các đơn vị / chi nhánh từ bảng units
            var unitCoordsMap: [String: (lat: Double, lng: Double)] = [:]
            if let unitsUrl = URL(string: "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/units?pageSize=300") {
                var uReq = URLRequest(url: unitsUrl)
                if !idToken.isEmpty { uReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (uData, uResp) = await DatabaseHelper.executeSafeRequest(uReq),
                   uResp.statusCode == 200,
                   let uJson = try? JSONSerialization.jsonObject(with: uData) as? [String: Any],
                   let uDocs = uJson["documents"] as? [[String: Any]] {
                    for ud in uDocs {
                        guard let uFields = ud["fields"] as? [String: Any] else { continue }
                        let uName = DatabaseHelper.getString(uFields["unitName"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let uLat = DatabaseHelper.getDouble(uFields["lat"] as? [String: Any])
                        let uLng = DatabaseHelper.getDouble(uFields["lng"] as? [String: Any])
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

            if let schedUrl = URL(string: "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)") {
                var sReq = URLRequest(url: schedUrl)
                if !idToken.isEmpty { sReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                if let (sData, sResp) = await DatabaseHelper.executeSafeRequest(sReq),
                   sResp.statusCode == 200,
                   let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
                   let sFields = sJson["fields"] as? [String: Any],
                   let rawEntries = (sFields["entries"] as? [String: Any])?["arrayValue"] as? [String: Any],
                   let valList = rawEntries["values"] as? [[String: Any]] {
                    for v in valList {
                        guard let mapFields = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] else { continue }
                        let empId = DatabaseHelper.getString(mapFields["employeeId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let empName = DatabaseHelper.getString(mapFields["employeeName"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        if let daysMap = (mapFields["days"] as? [String: Any])?["mapValue"] as? [String: Any],
                           let dayFields = daysMap["fields"] as? [String: Any] {
                            let code = DatabaseHelper.getString(dayFields[todayKeyDate] as? [String: Any]).isEmpty
                                ? (DatabaseHelper.getString(dayFields[todayKeyShort] as? [String: Any]).isEmpty
                                    ? DatabaseHelper.getString(dayFields[todayKeyDdMm] as? [String: Any])
                                    : DatabaseHelper.getString(dayFields[todayKeyShort] as? [String: Any]))
                                : DatabaseHelper.getString(dayFields[todayKeyDate] as? [String: Any])
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
                let email = DatabaseHelper.getString(fields["email"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if email.isEmpty { continue }

                let role = DatabaseHelper.getString(fields["role"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let deptId = (DatabaseHelper.getString(fields["departmentId"] as? [String: Any]).isEmpty
                    ? DatabaseHelper.getString(fields["phongBan"] as? [String: Any])
                    : DatabaseHelper.getString(fields["departmentId"] as? [String: Any])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let deptName = (DatabaseHelper.getString(fields["departmentName"] as? [String: Any]).isEmpty
                    ? DatabaseHelper.getString(fields["deptName"] as? [String: Any])
                    : DatabaseHelper.getString(fields["departmentName"] as? [String: Any])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let toNghiepVu = DatabaseHelper.getString(fields["toNghiepVu"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let donVi = DatabaseHelper.getString(fields["donVi"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

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
                let lastActiveAt = DatabaseHelper.getInt64(fields["lastActiveAt"] as? [String: Any])
                let isOnDuty = (fields["isOnDuty"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let isOnline = (rawOnline && (lastActiveAt > 0) && ((nowMs - lastActiveAt) < onlineWindowMs)) || isOnDuty

                let name = DatabaseHelper.getString(fields["fullName"] as? [String: Any]).isEmpty
                    ? DatabaseHelper.getString(fields["name"] as? [String: Any])
                    : DatabaseHelper.getString(fields["fullName"] as? [String: Any])
                let phone = DatabaseHelper.getString(fields["phone"] as? [String: Any])
                let maNhanVien = DatabaseHelper.getString(fields["maNhanVien"] as? [String: Any]).isEmpty
                    ? DatabaseHelper.getString(fields["employeeId"] as? [String: Any])
                    : DatabaseHelper.getString(fields["maNhanVien"] as? [String: Any])
                let maKhuVuc = DatabaseHelper.getString(fields["maKhuVuc"] as? [String: Any])
                let unitName = DatabaseHelper.getString(fields["donVi"] as? [String: Any]).isEmpty
                    ? DatabaseHelper.getString(fields["departmentId"] as? [String: Any])
                    : DatabaseHelper.getString(fields["donVi"] as? [String: Any])

                var lastSeen = "Không rõ"
                if lastActiveAt > 0 {
                    let diffSeconds = (nowMs - lastActiveAt) / 1000
                    if diffSeconds < 60 { lastSeen = "Vừa xong" }
                    else if diffSeconds < 3600 { lastSeen = "\(diffSeconds / 60) phút trước" }
                    else { lastSeen = "\(diffSeconds / 3600) giờ trước" }
                }

                let violCount = Int(DatabaseHelper.getInt64(fields["offlineViolationsCount"] as? [String: Any]))
                let isBlacklisted = (fields["isBlacklisted"] as? [String: Any])?["booleanValue"] as? Bool ?? (violCount >= 5)

                let shiftCode = shiftCodeMap[maNhanVien.lowercased()] ?? shiftCodeMap[name.lowercased()] ?? ""
                let offCodes = Set(["OFF", "NC", "P", "NM", "NL"])
                let isScheduledOff = offCodes.contains(shiftCode.uppercased())

                // Giải quyết tọa độ KTV (Ưu tiên: 1. Live GPS -> 2. User doc -> 3. Units -> 4. CoopmartDirectory -> 5. MaKhuVuc)
                let jitterLat = (Double(abs(email.hashValue) % 70) - 35.0) / 10000.0
                let jitterLng = (Double(abs((email + "x").hashValue) % 70) - 35.0) / 10000.0

                let liveGps = techGpsMap[email] ?? techGpsMap[email.replacingOccurrences(of: "/", with: "_")]
                let docLat = DatabaseHelper.getDouble(fields["latitude"] as? [String: Any]) != 0 ? DatabaseHelper.getDouble(fields["latitude"] as? [String: Any]) : DatabaseHelper.getDouble(fields["lat"] as? [String: Any])
                let docLng = DatabaseHelper.getDouble(fields["longitude"] as? [String: Any]) != 0 ? DatabaseHelper.getDouble(fields["longitude"] as? [String: Any]) : DatabaseHelper.getDouble(fields["lng"] as? [String: Any])

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
                    onDutyShift: DatabaseHelper.getString(fields["onDutyShift"] as? [String: Any])
                ))
            }

            result.sort { $0.isOnline && !$1.isOnline }
            self.ktvTechnicians = result
            self.isLoadingKtvs = false
        }
    }

    // MARK: - GÁN / ĐỔI / XÓA CA TRỰC HÔM NAY CHO KTV (ĐỒNG BỘ 1:1 ANDROID/WEB/DESKTOP)
    public func assignShiftForTech(tech: KtvOnlineLocation, newCode: String) async -> Bool {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return false }

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Thứ 2
        cal.minimumDaysInFirstWeek = 4
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: today)) ?? today
        let year = cal.component(.yearForWeekOfYear, from: thisMonday)
        let week = cal.component(.weekOfYear, from: thisMonday)
        let wId = String(format: "%04d-W%02d", year, week)

        let dfDate = DateFormatter()
        dfDate.dateFormat = "yyyy-MM-dd"
        let todayDateKey = dfDate.string(from: today)

        let dfDdMm = DateFormatter()
        dfDdMm.dateFormat = "dd/MM/yyyy"
        let todayDdMm = dfDdMm.string(from: today)

        let weekdayIdx = (cal.component(.weekday, from: today) - 2 + 7) % 7
        let shortDays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let todayKeyShort = shortDays[weekdayIdx]

        let todayDdMmHyphen = todayDdMm.replacingOccurrences(of: "/", with: "-")
        let todayMonthDay = String(todayDateKey.suffix(5))
        let todayDdMmShort = String(todayDdMm.prefix(5))
        let todayDdMmShortHyphen = todayDdMmShort.replacingOccurrences(of: "/", with: "-")

        let allTodayKeys = [
            todayDateKey,
            todayKeyShort,
            todayDdMm,
            todayDdMmHyphen,
            todayMonthDay,
            todayDdMmShort,
            todayDdMmShortHyphen
        ].map { $0.lowercased() }

        let cleanCode = newCode.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Fetch current week's schedule
        let schedUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/shift_schedules/\(wId)"
        guard let schedUrl = URL(string: schedUrlStr) else { return false }

        var getReq = URLRequest(url: schedUrl)
        if !idToken.isEmpty { getReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        var currentEntries: [[String: Any]] = []
        var existingWeekStart: Int64 = Int64(thisMonday.timeIntervalSince1970 * 1000)

        if let (sData, sResp) = await DatabaseHelper.executeSafeRequest(getReq),
           sResp.statusCode == 200,
           let sJson = try? JSONSerialization.jsonObject(with: sData) as? [String: Any],
           let sFields = sJson["fields"] as? [String: Any] {
            let ws = DatabaseHelper.getInt64(sFields["weekStart"] as? [String: Any])
            if ws > 0 {
                existingWeekStart = ws
            }
            if let rawEntries = (sFields["entries"] as? [String: Any])?["arrayValue"] as? [String: Any],
               let valList = rawEntries["values"] as? [[String: Any]] {
                for v in valList {
                    if let mapVal = v["mapValue"] as? [String: Any],
                       let f = mapVal["fields"] as? [String: Any] {
                        currentEntries.append(f)
                    }
                }
            }
        }

        // 2. Tìm KTV trong entries
        let targetId = tech.mnvDisplay.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let targetName = tech.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let targetEmail = tech.email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var foundIndex = -1
        for (i, entryFields) in currentEntries.enumerated() {
            let eId = DatabaseHelper.getString(entryFields["employeeId"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let eName = DatabaseHelper.getString(entryFields["employeeName"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let eEmail = DatabaseHelper.getString(entryFields["employeeEmail"] as? [String: Any]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if (!targetId.isEmpty && eId == targetId) ||
               (!targetName.isEmpty && eName == targetName) ||
               (!targetEmail.isEmpty && (eEmail == targetEmail || eId == targetEmail)) {
                foundIndex = i
                break
            }
        }

        if foundIndex >= 0 {
            var entryFields = currentEntries[foundIndex]
            var daysFields: [String: Any] = [:]
            if let daysObj = (entryFields["days"] as? [String: Any])?["mapValue"] as? [String: Any],
               let existingDays = daysObj["fields"] as? [String: Any] {
                daysFields = existingDays
            }

            // Xóa sạch toàn bộ key của ngày hôm nay
            for key in allTodayKeys {
                daysFields.removeValue(forKey: key)
                daysFields.removeValue(forKey: key.uppercased())
            }

            // Nếu có mã ca mới, thêm vào
            if !cleanCode.isEmpty {
                daysFields[todayDateKey] = ["stringValue": cleanCode]
                daysFields[todayKeyShort] = ["stringValue": cleanCode]
                daysFields[todayDdMm] = ["stringValue": cleanCode]
            }

            entryFields["days"] = ["mapValue": ["fields": daysFields]]
            currentEntries[foundIndex] = entryFields
        } else if !cleanCode.isEmpty {
            // Thêm mới entry nếu KTV chưa có trong bảng
            let newDays: [String: Any] = [
                todayDateKey: ["stringValue": cleanCode],
                todayKeyShort: ["stringValue": cleanCode],
                todayDdMm: ["stringValue": cleanCode]
            ]
            let newEntryFields: [String: Any] = [
                "employeeId": ["stringValue": tech.mnvDisplay.isEmpty ? tech.maNhanVien : tech.mnvDisplay],
                "employeeName": ["stringValue": tech.name],
                "employeeEmail": ["stringValue": tech.email],
                "maKhuVuc": ["stringValue": tech.maKhuVuc],
                "donVi": ["stringValue": tech.unitName],
                "days": ["mapValue": ["fields": newDays]]
            ]
            currentEntries.append(newEntryFields)
        }

        // 3. Chuẩn bị payload lưu lại lên Firestore
        let entryValues: [[String: Any]] = currentEntries.map { f in
            ["mapValue": ["fields": f]]
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let patchUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(cleanComp)/shift_schedules/\(wId)?updateMask.fieldPaths=entries&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=updatedBy&updateMask.fieldPaths=weekStart"
        guard let patchUrl = URL(string: patchUrlStr) else { return false }

        var patchReq = URLRequest(url: patchUrl)
        patchReq.httpMethod = "PATCH"
        if !idToken.isEmpty { patchReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "fields": [
                "weekStart": ["integerValue": String(existingWeekStart)],
                "updatedBy": ["stringValue": user.email],
                "updatedAt": ["integerValue": String(now)],
                "entries": ["arrayValue": ["values": entryValues]]
            ]
        ]
        patchReq.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let patchResult = await DatabaseHelper.executeSafeRequest(patchReq)
        let success = (patchResult?.1.statusCode == 200)

        if success {
            await MainActor.run {
                if let idx = self.ktvTechnicians.firstIndex(where: { $0.id == tech.id }) {
                    var updated = self.ktvTechnicians[idx]
                    updated.todayShiftCode = cleanCode
                    let offCodes = Set(["OFF", "NC", "P", "NM", "NL"])
                    updated.isScheduledOff = offCodes.contains(cleanCode.uppercased())
                    self.ktvTechnicians[idx] = updated
                }
            }
        }

        return success
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
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId):runQuery"
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

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
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
                creatorEmail: DatabaseHelper.getString(fields["creatorEmail"] as? [String: Any]),
                creatorName: DatabaseHelper.getString(fields["creatorName"] as? [String: Any]),
                subject: DatabaseHelper.getString(fields["subject"] as? [String: Any]),
                status: DatabaseHelper.getString(fields["status"] as? [String: Any]),
                priority: DatabaseHelper.getString(fields["priority"] as? [String: Any]),
                createdAt: DatabaseHelper.getInt64(fields["createdAt"] as? [String: Any]),
                donVi: DatabaseHelper.getString(fields["donVi"] as? [String: Any]),
                rating: DatabaseHelper.getInt(fields["rating"] as? [String: Any]),
                feedback: DatabaseHelper.getString(fields["feedback"] as? [String: Any]),
                feedbackAt: DatabaseHelper.getInt64(fields["feedbackAt"] as? [String: Any]),
                assignedDepartmentName: DatabaseHelper.getString(fields["assignedDepartmentName"] as? [String: Any]),
                assignedToEmail: DatabaseHelper.getString(fields["assignedToEmail"] as? [String: Any]),
                assignedToName: DatabaseHelper.getString(fields["assignedToName"] as? [String: Any]),
                closedAt: DatabaseHelper.getInt64(fields["closedAt"] as? [String: Any]),
                isAutoRated: DatabaseHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                isInvalid: DatabaseHelper.getBool(fields["isInvalid"] as? [String: Any])
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
