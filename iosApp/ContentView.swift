import SwiftUI
import Combine
import CoreLocation

// MARK: - 1. THEME & COLORS (Chuẩn 100% Android Color.kt)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    static let appPrimaryPink = Color(hex: "#F40266")           // Hồng rực rỡ QLTB SGCOOP
    static let appPrimaryPinkLight = Color(hex: "#FF4081")
    static let appSecondaryDarkBlue = Color(hex: "#002A8F")     // Xanh Đậm SGCOOP
    static let appTopBar = Color(hex: "#002A8F")                // Xanh Đậm TopBar
    static let appBottomBar = Color(hex: "#0A192F")             // Xanh Đậm Đêm BottomBar
    static let appBottomBarSelected = Color(hex: "#F40266")     // Hồng highlight tab
    static let appBottomBarUnselected = Color(hex: "#94A3B8")   // Slate muted
    static let appBackground = Color(hex: "#F8FAFC")            // Nền xám slate nhạt
    static let appCardBorder = Color(hex: "#E2E8F0")            // Viền card
    static let appTextPrimary = Color(hex: "#0F172A")           // Chữ đen đậm
    static let appTextSecondary = Color(hex: "#475569")         // Chữ xám đậm
    static let appTextMuted = Color(hex: "#94A3B8")             // Chữ xám nhạt

    // Status colors
    static let statusNew = Color(hex: "#0288D1")
    static let statusInUse = Color(hex: "#16A34A")
    static let statusRepair = Color(hex: "#EA580C")
    static let statusBroken = Color(hex: "#DC2626")
}

// MARK: - 2. DATA MODELS (Khớp 100% Firestore Collections)
struct DeviceItem: Identifiable, Hashable, Sendable {
    var id: String
    var code: String
    var name: String
    var category: String
    var serialNumber: String
    var unit: String
    var status: String
    var department: String
    var iconName: String
    var createdBy: String = ""
}

struct SupportTicket: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var unit: String
    var priority: String
    var status: String
    var slaRemaining: String
    var assignedKtv: String
    var creatorEmail: String
    var createdAt: String
    var lastMessage: String

    // Android v1.2.0 Parity
    var creatorName: String = ""
    var creatorPhone: String = ""
    var creatorUserId: String = ""
    var departmentId: String = ""
    var assignedTo: String = ""
    var assignedToEmail: String = ""
    var assignedToName: String = ""
    var assignedDepartmentId: String = ""
    var assignedDepartmentName: String = ""
    var assignedCluster: String = ""
    var assignedRole: String = "TECH"
    var toNghiepVu: String = ""
    var source: String = "APP" // APP, EMAIL, ZALO, WEB, PHONE
    var rating: Int = 0 // 0 = Chưa đánh giá, 1..5 sao
    var feedback: String = ""
    var ratingRequested: Bool = false
    var isAcknowledged: Bool = false
    var resolutionNote: String = ""
    var resolvedBy: String = ""
    var resolvedByName: String = ""
    var closedByEmail: String = ""
    var closedByName: String = ""
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    var id: String
    var senderName: String
    var senderEmail: String
    var text: String
    var time: String
    var isMe: Bool
    var imageUrl: String = ""
    var reactions: [String: String] = [:]
}

struct UserItem: Identifiable, Hashable, Sendable {
    var id: String { email }
    var email: String
    var fullName: String
    var phone: String
    var role: String
    var status: String
    var donVi: String
    var companyId: String
    var departmentId: String
    var maNhanVien: String
    var isOnline: Bool
    var createdAt: String
}

struct PendingStaffItem: Identifiable, Hashable, Sendable {
    var id: String { email }
    var email: String
    var fullName: String
    var phone: String
    var maNhanVien: String
    var companyId: String
    var departmentId: String
    var unitId: String
    var donVi: String
    var phongBan: String
    var createdAt: String
}

struct DepartmentItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var managerName: String
    var hotline: String
    var description: String
}

struct UnitItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var address: String
    var phone: String
}

struct RegionItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var code: String = ""
    var description: String = ""
    var leader: String = ""
    var phone: String = ""
}

struct DeviceTypeItem: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var icon: String
    var count: Int
}

struct DeviceHistoryItem: Identifiable, Hashable, Sendable {
    var id: String
    var deviceId: String
    var action: String
    var performedBy: String
    var timestamp: String
    var note: String
    var oldStatus: String
    var newStatus: String
}

struct AttendanceRecordItem: Identifiable, Hashable, Sendable {
    var id: String
    var userEmail: String
    var userName: String
    var date: String
    var checkInTime: String
    var checkOutTime: String
    var checkInAddress: String
    var checkInStatus: String
    var totalWorkMinutes: Int
}

struct ShiftEntryItem: Identifiable, Hashable, Sendable {
    var id: String { employeeId }
    var employeeId: String
    var employeeName: String
    var shiftCode: String
    var shiftName: String
    var donVi: String
    var khuVuc: String
}

struct OnlineKtvItem: Identifiable, Hashable, Sendable {
    var id: String { email }
    var email: String
    var name: String
    var isOnline: Bool
    var lastActive: String
    var currentUnit: String
    var assignedTickets: Int
}

struct SystemNotificationItem: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var message: String
    var createdAt: String
    var isUrgent: Bool
    var targetGroup: String
}

struct SupportRatingItem: Identifiable, Hashable, Sendable {
    var id: String
    var ticketId: String
    var stars: Int
    var feedback: String
    var userEmail: String
    var createdAt: String
}

// MARK: - 3. FIREBASE SERVICE ENGINE (Native Swift REST & Firestore Sync)
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    let apiKey = "AIzaSyAehFfYkaZZnaOw3zXQNxokB21D2XcUG6A"
    let projectId = "qltb-81f4c"

    @Published var isLoggedIn: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authError: String? = nil

    // Trạng thái tài khoản (ACTIVE vs PENDING)
    @Published var userAccountStatus: String = "ACTIVE"

    // Bộ nhớ Cache Phân hệ
    @Published var pendingStaffList: [PendingStaffItem] = []
    @Published var allUsersList: [UserItem] = []
    @Published var departmentsList: [DepartmentItem] = []
    @Published var unitsList: [UnitItem] = []
    @Published var regionsList: [RegionItem] = []
    @Published var deviceTypesList: [DeviceTypeItem] = []
    @Published var attendanceRecords: [AttendanceRecordItem] = []
    @Published var onlineKtvs: [OnlineKtvItem] = []
    @Published var shiftSchedules: [ShiftEntryItem] = []
    @Published var systemNotificationsList: [SystemNotificationItem] = []
    @Published var deviceHistoryList: [DeviceHistoryItem] = []
    @Published var supportRatingsList: [SupportRatingItem] = []

    @Published var currentUserEmail: String = ""
    @Published var currentUserIdToken: String = ""
    @Published var currentRefreshToken: String = ""

    // Profile người dùng
    @Published var companyId: String = "SGCOOP"
    @Published var userName: String = "Người dùng SGCOOP"
    @Published var userRole: String = "Nhân viên"
    @Published var userDonVi: String = "Co.opmart Cần Thơ"
    @Published var userDept: String = "Phòng Công nghệ thông tin"
    @Published var userPhone: String = ""

    // Dữ liệu Realtime từ Firestore
    @Published var devices: [DeviceItem] = []
    @Published var tickets: [SupportTicket] = []
    @Published var activeChatMessages: [ChatMessage] = []

    @Published var isLoadingDevices: Bool = false
    @Published var isLoadingTickets: Bool = false
    @Published var isLoadingMessages: Bool = false

    private var syncCancellable: AnyCancellable?
    private var presenceCancellable: AnyCancellable?

    // MARK: - VAI TRÒ & PHÂN QUYỀN CHUẨN ANDROID (AdminSupportViewModel.kt)
    @Published var rawRole: String = "nhanvien"

    var isAdmin: Bool {
        let r = rawRole.lowercased().trimmingCharacters(in: .whitespaces)
        return r == "admin" || r == "superadmin" || r == "super_admin" || r == "developer"
    }

    var isHelpDesk: Bool {
        let r = rawRole.lowercased().trimmingCharacters(in: .whitespaces)
        if r == "helpdesk" || r.contains("helpdesk") { return true }
        let d = userDept.lowercased()
        let dv = userDonVi.lowercased()
        return d.contains("helpdesk") || dv.contains("helpdesk")
    }

    var isManager: Bool {
        let r = rawRole.lowercased().trimmingCharacters(in: .whitespaces)
        return r == "phongban" || r == "quanly" || r == "manager" || r == "truongphong"
    }

    var isTechnician: Bool {
        let r = rawRole.lowercased().trimmingCharacters(in: .whitespaces)
        if ["kythuat", "technician", "ktv", "ky_thuat", "tech"].contains(r) || r.contains("kythuat") || r.contains("technician") || r.contains("ktv") {
            return true
        }
        if isAdmin || isHelpDesk || isManager {
            return false
        }
        let d = userDept.lowercased()
        let dv = userDonVi.lowercased()
        return d.contains("kỹ thuật") || d.contains("ky thuat") || d.contains("sửa chữa") || d.contains("sua chua") ||
               d.contains("bảo trì") || d.contains("bao tri") || d.contains("xử lý sự cố") || d.contains("xu ly su co") ||
               d.contains("cntt") || d.contains("it") || dv.contains("kỹ thuật")
    }

    var isManagerOrAdmin: Bool {
        isAdmin || isHelpDesk || isManager
    }

    // MARK: - FILTERING LOGIC CHUẨN ANDROID v1.2.0 (AdminSupportViewModel.isTicketVisible)
    var userFilteredTickets: [SupportTicket] {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return [] }

        // 1. Admin và Helpdesk luôn thấy toàn bộ ticket
        if isAdmin || isHelpDesk {
            return tickets
        }

        func isSameUser(_ a: String, _ b: String) -> Bool {
            let c1 = a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let c2 = b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if c1.isEmpty || c2.isEmpty { return false }
            if c1 == c2 { return true }
            let p1 = c1.components(separatedBy: "@").first ?? ""
            let p2 = c2.components(separatedBy: "@").first ?? ""
            return !p1.isEmpty && p1 == p2
        }

        return tickets.filter { ticket in
            let tAssignedTech = ticket.assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tAssignedTo = ticket.assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isAssignedToMe = isSameUser(tAssignedTech, cleanEmail) ||
                                 isSameUser(tAssignedTo, cleanEmail) ||
                                 isSameUser(ticket.assignedKtv, userName)

            // 2. Người tạo Ticket luôn thấy
            let tCreator = ticket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tCreatorUserId = ticket.creatorUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if isSameUser(tCreator, cleanEmail) || isSameUser(tCreatorUserId, cleanEmail) {
                return true
            }

            // 2b. Khớp đơn vị
            let myDonVi = userDonVi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tDonVi = ticket.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !myDonVi.isEmpty && (tDonVi == myDonVi || tDonVi.contains(myDonVi) || myDonVi.contains(tDonVi)) {
                return true
            }

            if isAssignedToMe {
                return true
            }

            // 3. Kỹ thuật viên: thấy ticket được gán hoặc ticket OPEN chưa ai nhận
            if isTechnician {
                if ticket.status == "OPEN" && tAssignedTech.isEmpty && tAssignedTo.isEmpty {
                    return true
                }
            }

            // 4. Quản lý phòng ban: thấy ticket phòng ban mình
            if isManager {
                let myDept = userDept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let tDept = ticket.departmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let tDeptName = ticket.assignedDepartmentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if (!myDept.isEmpty && (tDept.contains(myDept) || myDept.contains(tDept) || tDeptName.contains(myDept) || myDept.contains(tDeptName))) {
                    return true
                }
            }

            return false
        }
    }

    var userFilteredDevices: [DeviceItem] {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return devices }

        // Admin, Helpdesk, Manager, Technician thấy toàn bộ thiết bị công ty
        if isAdmin || isHelpDesk || isManager || isTechnician {
            return devices
        }

        // Staff thông thường: thiết bị do mình tạo hoặc cùng đơn vị/phòng ban
        let myDept = userDept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myDonVi = userDonVi.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = devices.filter { dev in
            let c = dev.createdBy.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !c.isEmpty && c == cleanEmail { return true }
            let d = dev.department.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !myDept.isEmpty && (d == myDept || d.contains(myDept) || myDept.contains(d)) { return true }
            let u = dev.unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !myDonVi.isEmpty && (u == myDonVi || u.contains(myDonVi) || myDonVi.contains(u)) { return true }
            return false
        }

        return filtered.isEmpty ? devices : filtered
    }

    // Bộ đệm thời gian tạo ticket chống spam (1 phút cooldown theo Android)
    private var lastTicketCreatedTime: [String: Double] = [:]

    func checkTicketCooldown(email: String) -> (canCreate: Bool, remainingSecs: Int) {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let lastTime = lastTicketCreatedTime[clean] else { return (true, 0) }
        let elapsed = Date().timeIntervalSince1970 - lastTime
        if elapsed < 60 {
            return (false, Int(60 - elapsed))
        }
        return (true, 0)
    }

    func recordTicketCreated(email: String) {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        lastTicketCreatedTime[clean] = Date().timeIntervalSince1970
    }

    init() {
        // Tự động kiểm tra phiên đăng nhập đã lưu trong máy
        let savedEmail = UserDefaults.standard.string(forKey: "fb_user_email") ?? ""
        let savedToken = UserDefaults.standard.string(forKey: "fb_id_token") ?? ""
        let savedRefresh = UserDefaults.standard.string(forKey: "fb_refresh_token") ?? ""

        if !savedEmail.isEmpty && !savedToken.isEmpty {
            self.currentUserEmail = savedEmail
            self.currentUserIdToken = savedToken
            self.currentRefreshToken = savedRefresh
            self.isLoggedIn = true

            // Tải dữ liệu từ cache local trước cho trải nghiệm tức thì
            loadLocalCache()

            // Đồng bộ trực tiếp từ Firestore
            Task { @MainActor in
                await self.loadUserProfile()
                await self.loadDevices()
                await self.loadTickets()
                self.startRealtimePolling()
            }
        }
    }

    // --- A1. NHẬN DIỆN SỐ ĐIỆN THOẠI & TRA CỨU EMAIL (UserCompanyResolver.kt) ---
    func isLikelyPhoneNumber(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") { return false }
        let digits = trimmed.filter { "0123456789".contains($0) }
        return digits.count >= 8 && digits.count <= 12
    }

    func resolveEmailFromPhone(_ phoneInput: String) async -> String? {
        guard let guestToken = await ensureGuestToken() else { return nil }
        let clean = phoneInput.trimmingCharacters(in: .whitespacesAndNewlines).filter { "0123456789+".contains($0) }
        var norm = clean
        if norm.hasPrefix("+84") {
            norm = "0" + norm.dropFirst(3)
        } else if norm.hasPrefix("84") && norm.count >= 11 {
            norm = "0" + norm.dropFirst(2)
        }

        let variations = [clean, norm, "+84" + (norm.hasPrefix("0") ? String(norm.dropFirst()) : norm)]
        let queryUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery"
        guard let qUrl = URL(string: queryUrl) else { return nil }

        for variant in variations {
            for field in ["phone", "phoneNumber", "sdt"] {
                var req = URLRequest(url: qUrl)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer \(guestToken)", forHTTPHeaderField: "Authorization")
                req.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

                let queryBody: [String: Any] = [
                    "structuredQuery": [
                        "from": [["collectionId": "users", "allDescendants": true]],
                        "where": [
                            "fieldFilter": [
                                "field": ["fieldPath": field],
                                "op": "EQUAL",
                                "value": ["stringValue": variant]
                            ]
                        ],
                        "limit": 1
                    ]
                ]
                if let bData = try? JSONSerialization.data(withJSONObject: queryBody) {
                    req.httpBody = bData
                    if let (data, res) = try? await URLSession.shared.data(for: req),
                       let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
                       let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        for item in results {
                            if let doc = item["document"] as? [String: Any],
                               let fields = doc["fields"] as? [String: Any] {
                                let email = parseString(fields, "email")
                                if email.contains("@") {
                                    return email.lowercased()
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    // --- A2. BỘ GIẢI QUYẾT DOANH NGHIỆP ĐỘNG (UserCompanyResolver.kt) ---
    func resolveUserCompany(cleanEmail: String, idToken: String) async -> (String, [String: Any]?) {
        // 1. Kiểm tra cache công ty gần nhất đã lưu
        let cachedComp = UserDefaults.standard.string(forKey: "cache_company_id") ?? self.companyId
        if !cachedComp.isEmpty {
            if let fields = await fetchUserDoc(company: cachedComp, email: cleanEmail, token: idToken) {
                return (cachedComp.uppercased(), fields)
            }
        }

        // 2. Chạy Firestore REST runQuery trên collectionGroup("users") với Token đã xác thực
        let queryUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents:runQuery"
        if let qUrl = URL(string: queryUrl) {
            var req = URLRequest(url: qUrl)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

            let queryBody: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "users", "allDescendants": true]],
                    "where": [
                        "fieldFilter": [
                            "field": ["fieldPath": "email"],
                            "op": "EQUAL",
                            "value": ["stringValue": cleanEmail]
                        ]
                    ],
                    "limit": 1
                ]
            ]
            if let bData = try? JSONSerialization.data(withJSONObject: queryBody) {
                req.httpBody = bData
                if let (data, res) = try? await URLSession.shared.data(for: req),
                   let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
                   let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in results {
                        if let doc = item["document"] as? [String: Any],
                           let name = doc["name"] as? String,
                           let fields = doc["fields"] as? [String: Any] {
                            let parts = name.components(separatedBy: "/")
                            if let cIdx = parts.firstIndex(of: "companies"), cIdx + 1 < parts.count {
                                let compId = parts[cIdx + 1].uppercased()
                                return (compId, fields)
                            }
                            let compField = parseString(fields, "companyId").uppercased()
                            if !compField.isEmpty {
                                return (compField, fields)
                            }
                        }
                    }
                }
            }
        }

        // 3. Fallback: Kiểm tra công ty Admin bằng adminEmail
        if let qUrl = URL(string: queryUrl) {
            var req = URLRequest(url: qUrl)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

            let queryBody: [String: Any] = [
                "structuredQuery": [
                    "from": [["collectionId": "companies", "allDescendants": false]],
                    "where": [
                        "fieldFilter": [
                            "field": ["fieldPath": "adminEmail"],
                            "op": "EQUAL",
                            "value": ["stringValue": cleanEmail]
                        ]
                    ],
                    "limit": 1
                ]
            ]
            if let bData = try? JSONSerialization.data(withJSONObject: queryBody) {
                req.httpBody = bData
                if let (data, res) = try? await URLSession.shared.data(for: req),
                   let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
                   let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in results {
                        if let doc = item["document"] as? [String: Any],
                           let name = doc["name"] as? String {
                            let compId = name.components(separatedBy: "/").last?.uppercased() ?? ""
                            if !compId.isEmpty {
                                let fields = await fetchUserDoc(company: compId, email: cleanEmail, token: idToken)
                                return (compId, fields)
                            }
                        }
                    }
                }
            }
        }

        // 4. Fallback danh sách công ty phổ biến
        let defaultCompanies = ["SGCOOP", "COOP", "SAIGONCOOP"]
        for comp in defaultCompanies {
            if let fields = await fetchUserDoc(company: comp, email: cleanEmail, token: idToken) {
                return (comp, fields)
            }
        }

        return (cachedComp.isEmpty ? "SGCOOP" : cachedComp.uppercased(), nil)
    }

    private func fetchUserDoc(company: String, email: String, token: String) async -> [String: Any]? {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanComp = company.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanComp)/users/\(cleanEmail)"
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let fields = json["fields"] as? [String: Any] {
            return fields
        }
        return nil
    }

    // --- A. ĐĂNG NHẬP (FIREBASE AUTH & SĐT/EMAIL CHUẨN ANDROID) ---
    func signIn(email: String, pass: String) async -> Bool {
        await MainActor.run {
            self.isAuthenticating = true
            self.authError = nil
        }

        let trimmedAccount = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Nhận diện nếu nhập Số điện thoại thì tự động tra cứu Email tương ứng
        let cleanEmail: String
        if isLikelyPhoneNumber(trimmedAccount) {
            if let resolvedEmail = await resolveEmailFromPhone(trimmedAccount) {
                cleanEmail = resolvedEmail
            } else {
                await MainActor.run {
                    self.authError = "Không tìm thấy tài khoản gắn với số điện thoại này."
                    self.isAuthenticating = false
                }
                return false
            }
        } else {
            cleanEmail = trimmedAccount.lowercased()
        }

        let authEndpoint = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)"
        guard let url = URL(string: authEndpoint) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "email": cleanEmail,
            "password": pass,
            "returnSecureToken": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let idToken = json["idToken"] as? String,
                   let refreshToken = json["refreshToken"] as? String {

                    // 2. Tự động giải quyết Doanh nghiệp & Hồ sơ người dùng từ Firestore
                    let (resolvedCompId, userFields) = await resolveUserCompany(cleanEmail: cleanEmail, idToken: idToken)

                    await MainActor.run {
                        self.currentUserEmail = cleanEmail
                        self.currentUserIdToken = idToken
                        self.currentRefreshToken = refreshToken
                        self.companyId = resolvedCompId.uppercased()

                        if let f = userFields {
                            let fn = self.parseString(f, "fullName")
                            let n = self.parseString(f, "name")
                            let r = self.parseString(f, "role")
                            let dv = self.parseString(f, "donVi")
                            let dp = self.parseString(f, "phongBan")
                            let ph = self.parseString(f, "phone").isEmpty ? self.parseString(f, "phoneNumber") : self.parseString(f, "phone")
                            let st = self.parseString(f, "status").uppercased()

                            self.rawRole = !r.isEmpty ? r.lowercased() : "nhanvien"
                            self.userName = !fn.isEmpty ? fn : (!n.isEmpty ? n : cleanEmail)
                            self.userRole = self.formatRoleTitle(r)
                            self.userDonVi = !dv.isEmpty ? dv : "Co.opmart Cần Thơ"
                            self.userDept = !dp.isEmpty ? dp : "Phòng Công nghệ thông tin"
                            self.userPhone = ph
                            self.userAccountStatus = !st.isEmpty ? st : "ACTIVE"
                        } else {
                            self.userAccountStatus = "ACTIVE"
                        }

                        self.isLoggedIn = true
                        self.isAuthenticating = false

                        // Lưu Session vào UserDefaults
                        UserDefaults.standard.set(cleanEmail, forKey: "fb_user_email")
                        UserDefaults.standard.set(idToken, forKey: "fb_id_token")
                        UserDefaults.standard.set(refreshToken, forKey: "fb_refresh_token")
                        UserDefaults.standard.set(self.companyId, forKey: "cache_company_id")
                        UserDefaults.standard.set(self.userName, forKey: "cache_name")
                        UserDefaults.standard.set(self.userRole, forKey: "cache_role")
                        UserDefaults.standard.set(self.rawRole, forKey: "cache_raw_role")
                        UserDefaults.standard.set(self.userDonVi, forKey: "cache_donvi")
                        UserDefaults.standard.set(self.userDept, forKey: "cache_dept")
                        UserDefaults.standard.set(self.userPhone, forKey: "cache_phone")
                        UserDefaults.standard.set(self.userAccountStatus, forKey: "cache_status")
                    }

                    // Tải dữ liệu các phân hệ
                    await self.loadDevices()
                    await self.loadTickets()
                    await MainActor.run { self.startRealtimePolling() }

                    return true
                }
            } else {
                var errDesc = "Tài khoản hoặc mật khẩu không chính xác."
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let msg = errorObj["message"] as? String {
                    if msg.contains("INVALID_LOGIN_CREDENTIALS") || msg.contains("INVALID_PASSWORD") || msg.contains("wrong-password") {
                        errDesc = "Tài khoản hoặc mật khẩu không chính xác."
                    } else if msg.contains("EMAIL_NOT_FOUND") || msg.contains("user-not-found") {
                        errDesc = "Tài khoản chưa được đăng ký trong hệ thống."
                    } else if msg.contains("USER_DISABLED") {
                        errDesc = "Tài khoản đã bị tạm khóa. Vui lòng liên hệ Quản trị viên."
                    } else if msg.contains("TOO_MANY_ATTEMPTS_TRY_LATER") {
                        errDesc = "Đã thử đăng nhập sai quá nhiều lần. Vui lòng đợi một lát rồi thử lại."
                    }
                }

                let finalErr = errDesc
                await MainActor.run {
                    self.authError = finalErr
                    self.isAuthenticating = false
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.authError = "Lỗi kết nối mạng: \(error.localizedDescription)"
                self.isAuthenticating = false
            }
            return false
        }
        return false
    }

    // --- B2. ĐẶT LẠI MẬT KHẨU (PASSWORD RESET) ---
    func resetPassword(email: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let endpoint = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "requestType": "PASSWORD_RESET",
            "email": cleanEmail
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
                return true
            }
        } catch {}
        return false
    }

    // --- B. ĐĂNG XUẤT ---
    func signOut() {
        // Gửi nhịp tim báo offline trước khi thoát
        Task {
            await self.sendPresence(isOnline: false)
        }

        stopRealtimePolling()

        UserDefaults.standard.removeObject(forKey: "fb_user_email")
        UserDefaults.standard.removeObject(forKey: "fb_id_token")
        UserDefaults.standard.removeObject(forKey: "fb_refresh_token")

        DispatchQueue.main.async {
            self.isLoggedIn = false
            self.currentUserEmail = ""
            self.currentUserIdToken = ""
            self.currentRefreshToken = ""
            self.devices = []
            self.tickets = []
        }
    }

    // --- C. ĐỒNG BỘ HỒ SƠ NGƯỜI DÙNG TỪ FIRESTORE (TỰ ĐỘNG NHẬN DIỆN DOANH NGHIỆP) ---
    func loadUserProfile() async {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return }

        // Gọi resolveUserCompany để luôn đảm bảo tải đúng công ty và hồ sơ
        let (resolvedComp, userFields) = await resolveUserCompany(cleanEmail: cleanEmail, idToken: currentUserIdToken)

        await MainActor.run {
            self.companyId = resolvedComp.uppercased()
            UserDefaults.standard.set(self.companyId, forKey: "cache_company_id")

            if let fields = userFields {
                let fn = self.parseString(fields, "fullName")
                let n = self.parseString(fields, "name")
                let r = self.parseString(fields, "role")
                let dv = self.parseString(fields, "donVi")
                let dp = self.parseString(fields, "phongBan")
                let ph = self.parseString(fields, "phone").isEmpty ? self.parseString(fields, "phoneNumber") : self.parseString(fields, "phone")
                let st = self.parseString(fields, "status").uppercased()

                self.rawRole = !r.isEmpty ? r.lowercased() : "nhanvien"
                self.userName = !fn.isEmpty ? fn : (!n.isEmpty ? n : cleanEmail)
                self.userRole = self.formatRoleTitle(r)
                self.userDonVi = !dv.isEmpty ? dv : "Co.opmart Cần Thơ"
                self.userDept = !dp.isEmpty ? dp : "Phòng Công nghệ thông tin"
                self.userPhone = ph
                self.userAccountStatus = !st.isEmpty ? st : "ACTIVE"

                UserDefaults.standard.set(self.userName, forKey: "cache_name")
                UserDefaults.standard.set(self.userRole, forKey: "cache_role")
                UserDefaults.standard.set(self.rawRole, forKey: "cache_raw_role")
                UserDefaults.standard.set(self.userDonVi, forKey: "cache_donvi")
                UserDefaults.standard.set(self.userDept, forKey: "cache_dept")
                UserDefaults.standard.set(self.userPhone, forKey: "cache_phone")
                UserDefaults.standard.set(self.userAccountStatus, forKey: "cache_status")
            }
        }
    }

    // --- D. ĐỌC DANH SÁCH THIẾT BỊ (FIRESTORE) ---
    func loadDevices() async {
        await MainActor.run { self.isLoadingDevices = true }
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices?pageSize=100"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {

                    var parsedList: [DeviceItem] = []
                    for doc in docs {
                        let docPath = doc["name"] as? String ?? ""
                        let docId = docPath.components(separatedBy: "/").last ?? UUID().uuidString
                        let f = doc["fields"] as? [String: Any] ?? [:]

                        let name = parseString(f, "ten")
                        let loai = parseString(f, "loai")
                        let trangThai = parseString(f, "trangThai")
                        let donVi = parseString(f, "tenDonVi")
                        let phongBan = parseString(f, "phongBan")
                        let idStr = parseString(f, "id")
                        let createdBy = parseString(f, "createdBy")

                        let category = !loai.isEmpty ? loai : "Thiết bị"
                        let item = DeviceItem(
                            id: docId,
                            code: !idStr.isEmpty ? idStr : docId,
                            name: !name.isEmpty ? name : "Thiết bị \(docId)",
                            category: category,
                            serialNumber: "SN-\(docId.prefix(8).uppercased())",
                            unit: !donVi.isEmpty ? donVi : "Co.opmart",
                            status: self.standardizeStatus(trangThai),
                            department: phongBan,
                            iconName: self.iconForCategory(category),
                            createdBy: createdBy
                        )
                        parsedList.append(item)
                    }

                    let finalDevices = parsedList
                    await MainActor.run {
                        self.devices = finalDevices
                        self.isLoadingDevices = false
                    }
                    return
                }
            }
        } catch {}

        await MainActor.run { self.isLoadingDevices = false }
    }

    // --- E. THÊM THIẾT BỊ MỚI (LƯU TRỰC TIẾP LÊN FIRESTORE) ---
    func addDeviceToFirestore(code: String, name: String, category: String, unit: String, status: String) async -> Bool {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices?documentId=\(cleanCode)"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "id": ["stringValue": cleanCode],
                "ten": ["stringValue": name],
                "loai": ["stringValue": category],
                "trangThai": ["stringValue": status],
                "tenDonVi": ["stringValue": unit],
                "phongBan": ["stringValue": userDept],
                "moTa": ["stringValue": "Nhập mới từ ứng dụng QLTB iOS"],
                "createdAt": ["integerValue": "\(nowMs)"],
                "createdBy": ["stringValue": currentUserEmail]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                // Tải lại danh sách ngay lập tức
                await self.loadDevices()
                return true
            }
        } catch {}
        return false
    }

    func addDevice(code: String, name: String, category: String, status: String, unit: String, department: String = "", serialNumber: String = "", price: String = "", warranty: String = "", imageUrl: String = "") async -> Bool {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices?documentId=\(cleanCode)"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let fields: [String: Any] = [
            "id": ["stringValue": cleanCode],
            "ten": ["stringValue": name],
            "loai": ["stringValue": category],
            "trangThai": ["stringValue": status],
            "tenDonVi": ["stringValue": unit],
            "phongBan": ["stringValue": department.isEmpty ? userDept : department],
            "serialNumber": ["stringValue": serialNumber],
            "donGia": ["stringValue": price],
            "thoiGianBaoHanh": ["stringValue": warranty],
            "hinhAnh": ["stringValue": imageUrl],
            "moTa": ["stringValue": "Nhập mới từ ứng dụng QLTB iOS"],
            "createdAt": ["integerValue": "\(nowMs)"],
            "createdBy": ["stringValue": currentUserEmail]
        ]
        let body: [String: Any] = ["fields": fields]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                await self.loadDevices()
                return true
            }
        } catch {}
        return false
    }

    // --- F. ĐỌC DANH SÁCH TICKET SỰ CỐ (FIRESTORE) ---
    func loadTickets() async {
        await MainActor.run { self.isLoadingTickets = true }
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets?pageSize=100"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {

                    var parsedTickets: [SupportTicket] = []
                    for doc in docs {
                        let docPath = doc["name"] as? String ?? ""
                        let docId = docPath.components(separatedBy: "/").last ?? UUID().uuidString
                        let f = doc["fields"] as? [String: Any] ?? [:]

                        let subject = parseString(f, "subject")
                        let donVi = parseString(f, "donVi")
                        let priority = parseString(f, "priority")
                        let status = parseString(f, "status")
                        let ktv = parseString(f, "assignedToName")
                        let creator = parseString(f, "creatorEmail")
                        let lastMsg = parseString(f, "lastMessage")

                        let creatorName = parseString(f, "creatorName")
                        let creatorPhone = parseString(f, "creatorPhone")
                        let creatorUserId = parseString(f, "creatorUserId")
                        let deptId = parseString(f, "departmentId")
                        let assignedTo = parseString(f, "assignedTo")
                        let assignedToEmail = parseString(f, "assignedToEmail")
                        let assignedToName = parseString(f, "assignedToName")
                        let assignedDeptId = parseString(f, "assignedDepartmentId")
                        let assignedDeptName = parseString(f, "assignedDepartmentName")
                        let assignedCluster = parseString(f, "assignedCluster")
                        let assignedRole = parseString(f, "assignedRole")
                        let toNghiepVu = parseString(f, "toNghiepVu")
                        let source = parseString(f, "source")
                        let rating = Int(parseInteger(f, "rating"))
                        let feedback = parseString(f, "feedback")
                        let ratingRequested = parseBoolean(f, "ratingRequested")
                        let isAcknowledged = parseBoolean(f, "isAcknowledged")
                        let resolutionNote = parseString(f, "resolutionNote")
                        let resolvedBy = parseString(f, "resolvedBy")
                        let resolvedByName = parseString(f, "resolvedByName")
                        let closedByEmail = parseString(f, "closedByEmail")
                        let closedByName = parseString(f, "closedByName")

                        let finalAssignedKtv = !assignedToName.isEmpty ? assignedToName : (!ktv.isEmpty ? ktv : "Chưa tiếp nhận")
                        let finalStatus = !status.isEmpty ? status.uppercased() : "OPEN"
                        let finalSlaRemaining = (finalStatus == "CLOSED" || finalStatus == "RESOLVED") ? "Đã xử lý xong" : "Đang xử lý SLA"

                        let t = SupportTicket(
                            id: docId,
                            title: !subject.isEmpty ? subject : "Sự cố kỹ thuật",
                            unit: !donVi.isEmpty ? donVi : "Co.opmart",
                            priority: self.formatPriority(priority),
                            status: finalStatus,
                            slaRemaining: finalSlaRemaining,
                            assignedKtv: finalAssignedKtv,
                            creatorEmail: creator,
                            createdAt: "Vừa xong",
                            lastMessage: lastMsg,
                            creatorName: creatorName,
                            creatorPhone: creatorPhone,
                            creatorUserId: creatorUserId,
                            departmentId: deptId,
                            assignedTo: assignedTo,
                            assignedToEmail: assignedToEmail,
                            assignedToName: assignedToName,
                            assignedDepartmentId: assignedDeptId,
                            assignedDepartmentName: assignedDeptName,
                            assignedCluster: assignedCluster,
                            assignedRole: !assignedRole.isEmpty ? assignedRole : "TECH",
                            toNghiepVu: toNghiepVu,
                            source: !source.isEmpty ? source.uppercased() : "APP",
                            rating: rating,
                            feedback: feedback,
                            ratingRequested: ratingRequested,
                            isAcknowledged: isAcknowledged,
                            resolutionNote: resolutionNote,
                            resolvedBy: resolvedBy,
                            resolvedByName: resolvedByName,
                            closedByEmail: closedByEmail,
                            closedByName: closedByName
                        )
                        parsedTickets.append(t)
                    }

                    let finalTickets = parsedTickets
                    await MainActor.run {
                        self.tickets = finalTickets
                        self.isLoadingTickets = false
                    }
                    return
                }
            }
        } catch {}

        await MainActor.run { self.isLoadingTickets = false }
    }

    // --- G. TẠO TICKET SỰ CỐ MỚI (LƯU LÊN FIRESTORE) ---
    func createTicketOnFirestore(subject: String, unit: String, priority: String) async -> Bool {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "subject": ["stringValue": subject],
                "donVi": ["stringValue": unit],
                "priority": ["stringValue": priority],
                "status": ["stringValue": "OPEN"],
                "creatorEmail": ["stringValue": currentUserEmail],
                "creatorName": ["stringValue": userName],
                "departmentId": ["stringValue": userDept],
                "createdAt": ["integerValue": "\(nowMs)"],
                "initialMessage": ["stringValue": subject],
                "lastMessage": ["stringValue": "Yêu cầu vừa được khởi tạo từ ứng dụng iOS"],
                "lastMessageAt": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    // --- H. ĐỌC TIN NHẮN SUBCOLLECTION MESSAGES ---
    func loadMessages(for ticketId: String) async {
        await MainActor.run { self.isLoadingMessages = true }
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(ticketId)/messages?pageSize=100"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {

                    var msgs: [ChatMessage] = []
                    for doc in docs {
                        let docPath = doc["name"] as? String ?? ""
                        let docId = docPath.components(separatedBy: "/").last ?? UUID().uuidString
                        let f = doc["fields"] as? [String: Any] ?? [:]

                        let sender = parseString(f, "senderName")
                        let senderEmail = parseString(f, "senderEmail")
                        let text = parseString(f, "message").isEmpty ? parseString(f, "text") : parseString(f, "message")
                        let ts = parseInteger(f, "timestamp")

                        let dateStr = self.formatTimestamp(ts)
                        let isMe = senderEmail.lowercased() == currentUserEmail.lowercased()

                        let imageUrl = self.parseString(f, "imageUrl").isEmpty ? self.parseString(f, "mediaUrl") : self.parseString(f, "imageUrl")
                        var reactionsMap: [String: String] = [:]
                        if let reactionsVal = f["reactions"] as? [String: Any],
                           let mapValue = reactionsVal["mapValue"] as? [String: Any],
                           let reactFields = mapValue["fields"] as? [String: Any] {
                            for (emoji, fieldData) in reactFields {
                                if let dict = fieldData as? [String: Any], let val = dict["stringValue"] as? String {
                                    reactionsMap[emoji] = val
                                }
                            }
                        }

                        let m = ChatMessage(
                            id: docId,
                            senderName: !sender.isEmpty ? sender : "KTV",
                            senderEmail: senderEmail,
                            text: text,
                            time: dateStr,
                            isMe: isMe,
                            imageUrl: imageUrl,
                            reactions: reactionsMap
                        )
                        msgs.append(m)
                    }

                    let finalMsgs = msgs
                    await MainActor.run {
                        self.activeChatMessages = finalMsgs
                        self.isLoadingMessages = false
                    }
                    return
                }
            }
        } catch {}

        await MainActor.run { self.isLoadingMessages = false }
    }

    // --- I. GỬI TIN NHẮN LÊN FIRESTORE SUBCOLLECTION ---
    func sendMessage(ticketId: String, text: String, imageUrl: String = "") async -> Bool {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(ticketId)/messages"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        var fields: [String: Any] = [
            "message": ["stringValue": text],
            "senderName": ["stringValue": userName],
            "senderEmail": ["stringValue": currentUserEmail],
            "departmentId": ["stringValue": userDept],
            "donVi": ["stringValue": userDonVi],
            "timestamp": ["integerValue": "\(nowMs)"]
        ]
        if !imageUrl.isEmpty {
            fields["imageUrl"] = ["stringValue": imageUrl]
        }

        let body: [String: Any] = ["fields": fields]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                await self.loadMessages(for: ticketId)
                return true
            }
        } catch {}
        return false
    }

    func addReaction(ticketId: String, messageId: String, emoji: String) async -> Bool {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(ticketId)/messages/\(messageId)?updateMask.fieldPaths=reactions"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "fields": [
                "reactions": [
                    "mapValue": [
                        "fields": [
                            emoji: ["stringValue": currentUserEmail]
                        ]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                await self.loadMessages(for: ticketId)
                return true
            }
        } catch {}
        return false
    }

    // --- J. ĐỔI HỌ TÊN & SĐT (LƯU LÊN FIRESTORE) ---
    func updateProfile(newName: String, newPhone: String) async -> Bool {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=fullName&updateMask.fieldPaths=name&updateMask.fieldPaths=phone&updateMask.fieldPaths=phoneNumber"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "fields": [
                "fullName": ["stringValue": newName],
                "name": ["stringValue": newName],
                "phone": ["stringValue": newPhone],
                "phoneNumber": ["stringValue": newPhone]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                await MainActor.run {
                    self.userName = newName
                    self.userPhone = newPhone
                    UserDefaults.standard.set(newName, forKey: "cache_name")
                    UserDefaults.standard.set(newPhone, forKey: "cache_phone")
                }
                return true
            }
        } catch {}
        return false
    }

    // --- K. PHÁT NHỊP TIM HIỆN DIỆN ONLINE (PRESENCE MONITOR) ---
    func sendPresence(isOnline: Bool) async {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return }

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/technician_locations/\(cleanEmail)?updateMask.fieldPaths=isOnline&updateMask.fieldPaths=lastUpdatedAt&updateMask.fieldPaths=name"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "isOnline": ["booleanValue": isOnline],
                "lastUpdatedAt": ["integerValue": "\(nowMs)"],
                "name": ["stringValue": userName]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: request)
        } catch {}
    }

    // --- L. CHU KỲ POLLING REALTIME & HEARTBEAT ---
    private func startRealtimePolling() {
        stopRealtimePolling()

        // Định kỳ 15 giây lấy cập nhật thiết bị và ticket mới
        syncCancellable = Timer.publish(every: 15, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isLoggedIn else { return }
                Task {
                    await self.loadDevices()
                    await self.loadTickets()
                }
            }

        // Định kỳ 30 giây gửi nhịp tim hiện diện online tới Desktop / Server
        presenceCancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isLoggedIn else { return }
                Task {
                    await self.sendPresence(isOnline: true)
                }
            }

        // Gửi nhịp tim online ngay lập tức
        Task {
            await self.sendPresence(isOnline: true)
        }
    }

    private func stopRealtimePolling() {
        syncCancellable?.cancel()
        syncCancellable = nil
        presenceCancellable?.cancel()
        presenceCancellable = nil
    }

    private func loadLocalCache() {
        self.userName = UserDefaults.standard.string(forKey: "cache_name") ?? "Người dùng SGCOOP"
        self.userRole = UserDefaults.standard.string(forKey: "cache_role") ?? "Nhân viên"
        self.userDonVi = UserDefaults.standard.string(forKey: "cache_donvi") ?? "Co.opmart Cần Thơ"
        self.userDept = UserDefaults.standard.string(forKey: "cache_dept") ?? "Phòng Công nghệ thông tin"
        self.userPhone = UserDefaults.standard.string(forKey: "cache_phone") ?? ""
    }

    // Helper functions
    private func parseString(_ f: [String: Any], _ key: String) -> String {
        if let obj = f[key] as? [String: Any], let val = obj["stringValue"] as? String {
            return val
        }
        return ""
    }

    private func parseInteger(_ f: [String: Any], _ key: String) -> Int64 {
        if let obj = f[key] as? [String: Any], let val = obj["integerValue"] as? String, let num = Int64(val) {
            return num
        }
        return 0
    }

    private func parseBoolean(_ f: [String: Any], _ key: String) -> Bool {
        if let obj = f[key] as? [String: Any], let val = obj["booleanValue"] as? Bool {
            return val
        }
        return false
    }

    // MARK: - TICKET LIFECYCLE OPERATIONS (Parity với Android AdminSupportViewModel.kt)

    // 1. TIẾP NHẬN TICKET (KTV / HELPDESK)
    func acceptTicket(ticketId: String) async -> Bool {
        let cleanId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty { return false }

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(cleanId)?updateMask.fieldPaths=status&updateMask.fieldPaths=assignedToEmail&updateMask.fieldPaths=assignedToName&updateMask.fieldPaths=assignedTo&updateMask.fieldPaths=isAcknowledged&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let sysMsg = "🛠️ KTV \(userName) đã tiếp nhận yêu cầu hỗ trợ và đang xử lý."

        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "IN_PROGRESS"],
                "assignedToEmail": ["stringValue": currentUserEmail],
                "assignedToName": ["stringValue": userName],
                "assignedTo": ["stringValue": currentUserEmail],
                "isAcknowledged": ["booleanValue": true],
                "lastMessage": ["stringValue": sysMsg],
                "lastMessageAt": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                _ = await sendMessage(ticketId: cleanId, text: sysMsg)
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    // 2. BÁO XỬ LÝ XONG (RESOLVED)
    func resolveTicket(ticketId: String, note: String) async -> Bool {
        let cleanId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty { return false }

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(cleanId)?updateMask.fieldPaths=status&updateMask.fieldPaths=resolvedAt&updateMask.fieldPaths=resolvedBy&updateMask.fieldPaths=resolvedByName&updateMask.fieldPaths=resolutionNote&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let noteDesc = cleanNote.isEmpty ? "Hoàn tất xử lý sự cố." : cleanNote
        let sysMsg = "🛠️ KTV \(userName) báo xong! Đã xử lý xong: \(noteDesc). Chờ nghiệm thu và đánh giá."

        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "RESOLVED"],
                "resolvedAt": ["integerValue": "\(nowMs)"],
                "resolvedBy": ["stringValue": currentUserEmail],
                "resolvedByName": ["stringValue": userName],
                "resolutionNote": ["stringValue": cleanNote],
                "lastMessage": ["stringValue": sysMsg],
                "lastMessageAt": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                _ = await sendMessage(ticketId: cleanId, text: sysMsg)
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    // 3. ĐÓNG / NGHIỆM THU TICKET
    func closeTicket(ticketId: String, note: String = "") async -> Bool {
        let cleanId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty { return false }

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(cleanId)?updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=closedByName&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let noteDesc = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let sysMsg = "✅ [\(userName)] Đã nghiệm thu và hoàn tất đóng yêu cầu hỗ trợ\(noteDesc.isEmpty ? "." : " (\(noteDesc)).")"

        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "CLOSED"],
                "closedAt": ["integerValue": "\(nowMs)"],
                "closedByEmail": ["stringValue": currentUserEmail],
                "closedByName": ["stringValue": userName],
                "lastMessage": ["stringValue": sysMsg],
                "lastMessageAt": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                _ = await sendMessage(ticketId: cleanId, text: sysMsg)
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    // 4. BÀN GIAO CA (KTV / HELPDESK)
    func handoverTicket(ticketId: String, toType: String, targetEmail: String, targetName: String, reason: String) async -> Bool {
        let cleanId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty || cleanReason.isEmpty { return false }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let isTech = toType == "TECHNICIAN"

        let mask = isTech
            ? "updateMask.fieldPaths=assignedToEmail&updateMask.fieldPaths=assignedToName&updateMask.fieldPaths=assignedByEmail&updateMask.fieldPaths=assignedByName&updateMask.fieldPaths=dispatchNote&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt&updateMask.fieldPaths=isAcknowledged"
            : "updateMask.fieldPaths=status&updateMask.fieldPaths=assignedToEmail&updateMask.fieldPaths=assignedToName&updateMask.fieldPaths=assignedByEmail&updateMask.fieldPaths=assignedByName&updateMask.fieldPaths=dispatchNote&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt&updateMask.fieldPaths=isAcknowledged"

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(cleanId)?\(mask)"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let sysMsg = isTech
            ? "🔄 [Bàn giao ca] KTV \(userName) đã bàn giao yêu cầu cho KTV \(targetName). Lý do: \(cleanReason)"
            : "↩️ [Chuyển về HelpDesk] KTV \(userName) đã chuyển trả ticket cho HelpDesk. Lý do: \(cleanReason)"

        var fields: [String: Any] = [
            "assignedByEmail": ["stringValue": currentUserEmail],
            "assignedByName": ["stringValue": userName],
            "dispatchNote": ["stringValue": cleanReason],
            "isAcknowledged": ["booleanValue": false],
            "lastMessage": ["stringValue": sysMsg],
            "lastMessageAt": ["integerValue": "\(nowMs)"]
        ]

        if isTech {
            fields["assignedToEmail"] = ["stringValue": targetEmail]
            fields["assignedToName"] = ["stringValue": targetName]
        } else {
            fields["status"] = ["stringValue": "OPEN"]
            fields["assignedToEmail"] = ["stringValue": ""]
            fields["assignedToName"] = ["stringValue": ""]
        }

        let body: [String: Any] = ["fields": fields]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                _ = await sendMessage(ticketId: cleanId, text: sysMsg)
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    // 5. ĐÁNH GIÁ CHẤT LƯỢNG CSAT 5 SAO (NGƯỜI TẠO TICKET)
    func submitRating(ticketId: String, stars: Int, comment: String) async -> Bool {
        let cleanId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty { return false }

        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(cleanId)?updateMask.fieldPaths=rating&updateMask.fieldPaths=feedback&updateMask.fieldPaths=feedbackAt&updateMask.fieldPaths=status&updateMask.fieldPaths=closedAt&updateMask.fieldPaths=closedByEmail&updateMask.fieldPaths=closedByName&updateMask.fieldPaths=lastMessage&updateMask.fieldPaths=lastMessageAt"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let cleanComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let ratingDesc = whenSatisfaction(stars)
        let finalFeedback = cleanComment.isEmpty ? ratingDesc : cleanComment
        let sysMsg = "⭐ [Khách hàng đánh giá \(stars)/5★]: \(finalFeedback). Phiếu hỗ trợ đã được đóng tự động."

        let body: [String: Any] = [
            "fields": [
                "rating": ["integerValue": "\(stars)"],
                "feedback": ["stringValue": finalFeedback],
                "feedbackAt": ["integerValue": "\(nowMs)"],
                "status": ["stringValue": "CLOSED"],
                "closedAt": ["integerValue": "\(nowMs)"],
                "closedByEmail": ["stringValue": currentUserEmail],
                "closedByName": ["stringValue": userName],
                "lastMessage": ["stringValue": sysMsg],
                "lastMessageAt": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                _ = await sendMessage(ticketId: cleanId, text: sysMsg)
                await self.loadTickets()
                return true
            }
        } catch {}
        return false
    }

    func whenSatisfaction(_ stars: Int) -> String {
        switch stars {
        case 1: return "Rất không hài lòng"
        case 2: return "Không hài lòng"
        case 3: return "Bình thường"
        case 4: return "Hài lòng"
        default: return "Rất hài lòng"
        }
    }

    private func formatRoleTitle(_ rawRole: String) -> String {
        let r = rawRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch r {
        case "admin": return "Quản trị viên (Admin)"
        case "helpdesk": return "Phòng Helpdesk"
        case "kythuat", "technician": return "Kỹ thuật viên"
        case "phongban", "quanly": return "Quản lý phòng ban"
        default: return "Nhân viên"
        }
    }

    private func formatPriority(_ rawP: String) -> String {
        let p = rawP.uppercased()
        if p.contains("HIGH") || p.contains("P1") || p.contains("URGENT") { return "P1 - Khẩn cấp" }
        if p.contains("MEDIUM") || p.contains("P2") { return "P2 - Cao" }
        return "P3 - Bình thường"
    }

    private func standardizeStatus(_ raw: String) -> String {
        let s = raw.lowercased()
        if s.contains("trong kho") || s.contains("mới") { return "Mới" }
        if s.contains("sửa") || s.contains("bảo hành") { return "Sửa chữa" }
        if s.contains("hỏng") || s.contains("thanh lý") { return "Hỏng" }
        return "Đang sử dụng"
    }

    // --- P. QUẢN LÝ TÀI KHOẢN CHỜ PHÊ DUYỆT (PENDING STAFF) ---
    func checkUserApprovalStatus() async {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return }
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let fields = json["fields"] as? [String: Any] {
            let st = parseString(fields, "status")
            await MainActor.run {
                self.userAccountStatus = !st.isEmpty ? st.uppercased() : "ACTIVE"
            }
        }
    }

    func fetchPendingStaff() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users?pageSize=100"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [PendingStaffItem] = []
            for d in docs {
                let f = d["fields"] as? [String: Any] ?? [:]
                let st = parseString(f, "status").uppercased()
                if st == "PENDING" {
                    let item = PendingStaffItem(
                        email: parseString(f, "email"),
                        fullName: parseString(f, "fullName"),
                        phone: parseString(f, "phone"),
                        maNhanVien: parseString(f, "maNhanVien"),
                        companyId: parseString(f, "companyId"),
                        departmentId: parseString(f, "departmentId"),
                        unitId: parseString(f, "unitId"),
                        donVi: parseString(f, "donVi"),
                        phongBan: parseString(f, "phongBan"),
                        createdAt: formatTimestamp(parseInteger(f, "createdAt"))
                    )
                    list.append(item)
                }
            }
            let finalList = list
            await MainActor.run { self.pendingStaffList = finalList }
        }
    }

    func approveStaffMember(email: String, role: String, dept: String, unit: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=status&updateMask.fieldPaths=role&updateMask.fieldPaths=phongBan&updateMask.fieldPaths=donVi"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "ACTIVE"],
                "role": ["stringValue": role],
                "phongBan": ["stringValue": dept],
                "donVi": ["stringValue": unit]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            await fetchPendingStaff()
            return true
        }
        return false
    }

    func rejectStaffMember(email: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=status"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": ["status": ["stringValue": "REJECTED"]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            await fetchPendingStaff()
            return true
        }
        return false
    }

    // --- Q. QUẢN LÝ NGƯỜI DÙNG & PHÂN QUYỀN (USER MANAGEMENT) ---
    func fetchAllUsers() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users?pageSize=100"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [UserItem] = []
            for d in docs {
                let f = d["fields"] as? [String: Any] ?? [:]
                let em = parseString(f, "email")
                if !em.isEmpty {
                    let u = UserItem(
                        email: em,
                        fullName: parseString(f, "fullName").isEmpty ? parseString(f, "name") : parseString(f, "fullName"),
                        phone: parseString(f, "phone"),
                        role: parseString(f, "role").isEmpty ? "nhanvien" : parseString(f, "role"),
                        status: parseString(f, "status").isEmpty ? "ACTIVE" : parseString(f, "status").uppercased(),
                        donVi: parseString(f, "donVi"),
                        companyId: parseString(f, "companyId"),
                        departmentId: parseString(f, "departmentId"),
                        maNhanVien: parseString(f, "maNhanVien"),
                        isOnline: (f["isOnline"] as? [String: Any])?["booleanValue"] as? Bool ?? false,
                        createdAt: formatTimestamp(parseInteger(f, "createdAt"))
                    )
                    list.append(u)
                }
            }
            let finalList = list
            await MainActor.run { self.allUsersList = finalList }
        }
    }

    func changeUserRole(email: String, newRole: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=role"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": ["role": ["stringValue": newRole]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            await fetchAllUsers()
            return true
        }
        return false
    }

    func toggleUserBlock(email: String, block: Bool) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let newSt = block ? "BLOCKED" : "ACTIVE"
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=status"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": ["status": ["stringValue": newSt]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            await fetchAllUsers()
            return true
        }
        return false
    }

    func addUserByAdmin(email: String, fullName: String, mnv: String, phone: String, role: String, unit: String, dept: String, password: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return false }
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "email": ["stringValue": cleanEmail],
                "name": ["stringValue": fullName],
                "fullName": ["stringValue": fullName],
                "maNhanVien": ["stringValue": mnv],
                "employeeId": ["stringValue": mnv],
                "phone": ["stringValue": phone],
                "phoneNumber": ["stringValue": phone],
                "sdt": ["stringValue": phone],
                "role": ["stringValue": role],
                "departmentId": ["stringValue": dept],
                "unitId": ["stringValue": unit],
                "donVi": ["stringValue": unit],
                "companyId": ["stringValue": companyId],
                "status": ["stringValue": "ACTIVE"],
                "password": ["stringValue": password],
                "createdAt": ["integerValue": "\(nowMs)"]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            await fetchAllUsers()
            return true
        }
        return false
    }

    func transferUser(email: String, newUnit: String, newDept: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return false }
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=donVi&updateMask.fieldPaths=unitId&updateMask.fieldPaths=departmentId"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "donVi": ["stringValue": newUnit],
                "unitId": ["stringValue": newUnit],
                "departmentId": ["stringValue": newDept]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            await fetchAllUsers()
            return true
        }
        return false
    }

    // --- R. QUẢN LÝ PHÒNG BAN, ĐƠN VỊ, KHU VỰC, LOẠI THIẾT BỊ ---
    func fetchDepartments() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/departments?pageSize=100"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [DepartmentItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let name = parseString(f, "deptName").isEmpty ? (parseString(f, "departmentName").isEmpty ? docId : parseString(f, "departmentName")) : parseString(f, "deptName")
                let item = DepartmentItem(
                    id: docId,
                    name: name,
                    managerName: parseString(f, "managerName"),
                    hotline: parseString(f, "hotline"),
                    description: parseString(f, "description")
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.departmentsList = finalList }
        }
    }

    func saveDepartment(id: String, name: String, manager: String, hotline: String, desc: String) async -> Bool {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanId.isEmpty else { return false }
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/departments/\(cleanId)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "deptId": ["stringValue": cleanId],
                "deptName": ["stringValue": name],
                "departmentName": ["stringValue": name],
                "managerName": ["stringValue": manager],
                "hotline": ["stringValue": hotline],
                "description": ["stringValue": desc],
                "location": ["stringValue": desc],
                "companyId": ["stringValue": companyId]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            await fetchDepartments()
            return true
        }
        return false
    }

    func addDepartment(id: String, name: String, manager: String, hotline: String) async -> Bool {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/departments/\(cleanId)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "deptId": ["stringValue": cleanId],
                "deptName": ["stringValue": name],
                "managerName": ["stringValue": manager],
                "hotline": ["stringValue": hotline],
                "companyId": ["stringValue": companyId]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            await fetchDepartments()
            return true
        }
        return false
    }

    func deleteDepartment(id: String) async -> Bool {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/departments/\(id)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 204) {
            await fetchDepartments()
            return true
        }
        return false
    }

    func fetchUnits() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/units?pageSize=100"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [UnitItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let name = parseString(f, "unitName").isEmpty ? (parseString(f, "tenDonVi").isEmpty ? docId : parseString(f, "tenDonVi")) : parseString(f, "unitName")
                let item = UnitItem(
                    id: docId,
                    name: name,
                    address: parseString(f, "address"),
                    phone: parseString(f, "phone")
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.unitsList = finalList }
        }
    }

    func addUnit(id: String, name: String, address: String, phone: String) async -> Bool {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/units/\(cleanId)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "unitId": ["stringValue": cleanId],
                "unitName": ["stringValue": name],
                "address": ["stringValue": address],
                "phone": ["stringValue": phone],
                "companyId": ["stringValue": companyId]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            await fetchUnits()
            return true
        }
        return false
    }

    func deleteUnit(id: String) async -> Bool {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/units/\(id)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 204) {
            await fetchUnits()
            return true
        }
        return false
    }

    func approveUser(email: String, role: String, unitId: String, unitName: String, deptId: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return false }
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=status&updateMask.fieldPaths=role&updateMask.fieldPaths=unitId&updateMask.fieldPaths=donVi&updateMask.fieldPaths=departmentId&updateMask.fieldPaths=phongBan"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "ACTIVE"],
                "role": ["stringValue": role.uppercased()],
                "unitId": ["stringValue": unitId],
                "donVi": ["stringValue": unitName],
                "departmentId": ["stringValue": deptId],
                "phongBan": ["stringValue": deptId]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            let delUrlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/pending_staff/\(cleanEmail)"
            if let delUrl = URL(string: delUrlStr) {
                var delReq = URLRequest(url: delUrl)
                delReq.httpMethod = "DELETE"
                delReq.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
                _ = try? await URLSession.shared.data(for: delReq)
            }
            await fetchPendingStaff()
            await fetchAllUsers()
            return true
        }
        return false
    }

    func rejectUser(email: String) async -> Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return false }
        let delUrlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/pending_staff/\(cleanEmail)"
        if let delUrl = URL(string: delUrlStr) {
            var delReq = URLRequest(url: delUrl)
            delReq.httpMethod = "DELETE"
            delReq.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: delReq)
        }
        let userUrlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=status"
        if let userUrl = URL(string: userUrlStr) {
            var userReq = URLRequest(url: userUrl)
            userReq.httpMethod = "PATCH"
            userReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            userReq.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
            let body: [String: Any] = ["fields": ["status": ["stringValue": "REJECTED"]]]
            userReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: userReq)
        }
        await fetchPendingStaff()
        await fetchAllUsers()
        return true
    }

    func fetchShiftSchedules(weekId: String) async -> [String: [String: String]] {
        let cleanWeek = weekId.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/shift_schedules/\(cleanWeek)"
        guard let url = URL(string: urlStr) else { return [:] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let fields = json["fields"] as? [String: Any] {
            var result: [String: [String: String]] = [:]
            for (ktvKey, val) in fields {
                if let mapVal = val as? [String: Any],
                   let mapFields = (mapVal["mapValue"] as? [String: Any])?["fields"] as? [String: Any] {
                    var dayMap: [String: String] = [:]
                    for (dayKey, dayVal) in mapFields {
                        if let dMap = dayVal as? [String: Any],
                           let s = dMap["stringValue"] as? String {
                            dayMap[dayKey] = s
                        }
                    }
                    result[ktvKey] = dayMap
                }
            }
            return result
        }
        return [:]
    }

    func saveShiftSchedule(weekId: String, ktvEmail: String, dayKey: String, shiftCode: String) async -> Bool {
        let cleanWeek = weekId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanKey = ktvEmail.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/shift_schedules/\(cleanWeek)?updateMask.fieldPaths=\(cleanKey).\(dayKey)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                cleanKey: [
                    "mapValue": [
                        "fields": [
                            dayKey: ["stringValue": shiftCode]
                        ]
                    ]
                ]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            return true
        }
        return false
    }

    func saveUnit(id: String, name: String, address: String, phone: String) async -> Bool {
        return await addUnit(id: id, name: name, address: address, phone: phone)
    }

    func saveRegion(code: String, name: String, leader: String, phone: String) async -> Bool {
        await addRegion(id: code, name: name, leader: leader, phone: phone, desc: "")
        return true
    }

    func fetchRegions() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/regions?pageSize=100"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [RegionItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let name = parseString(f, "name").isEmpty ? (parseString(f, "regionName").isEmpty ? docId : parseString(f, "regionName")) : parseString(f, "name")
                let item = RegionItem(
                    id: docId,
                    name: name,
                    code: docId,
                    description: parseString(f, "description"),
                    leader: parseString(f, "leader"),
                    phone: parseString(f, "phone")
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.regionsList = finalList }
        }
    }

    func addRegion(id: String, name: String, leader: String, phone: String, desc: String) async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/regions?documentId=\(id)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": [
                "name": ["stringValue": name],
                "regionName": ["stringValue": name],
                "leader": ["stringValue": leader],
                "phone": ["stringValue": phone],
                "description": ["stringValue": desc]
            ]
        ]
        if let b = try? JSONSerialization.data(withJSONObject: body) {
            req.httpBody = b
            _ = try? await URLSession.shared.data(for: req)
            await fetchRegions()
        }
    }

    func deleteRegion(id: String) async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/regions/\(id)"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
        await fetchRegions()
    }

    // --- S. LỊCH SỬ THIẾT BỊ & CẬP NHẬT TRẠNG THÁI ---
    func updateDeviceStatus(deviceId: String, newStatus: String, note: String) async -> Bool {
        let cleanId = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices/\(cleanId)?updateMask.fieldPaths=trangThai"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "fields": ["trangThai": ["stringValue": newStatus]]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200 {
            // Ghi nhật ký vào subcollection history
            await addDeviceHistoryRecord(deviceId: cleanId, action: "Đổi trạng thái -> \(newStatus)", note: note, newSt: newStatus)
            await loadDevices()
            return true
        }
        return false
    }

    func addDeviceHistoryRecord(deviceId: String, action: String, note: String, newSt: String) async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices/\(deviceId)/history"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "action": ["stringValue": action],
                "note": ["stringValue": note],
                "performedBy": ["stringValue": userName],
                "userEmail": ["stringValue": currentUserEmail],
                "newStatus": ["stringValue": newSt],
                "timestamp": ["integerValue": "\(nowMs)"]
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }

    func fetchDeviceHistory(deviceId: String) async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/devices/\(deviceId)/history?pageSize=50"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [DeviceHistoryItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let item = DeviceHistoryItem(
                    id: docId,
                    deviceId: deviceId,
                    action: parseString(f, "action"),
                    performedBy: parseString(f, "performedBy"),
                    timestamp: formatTimestamp(parseInteger(f, "timestamp")),
                    note: parseString(f, "note"),
                    oldStatus: parseString(f, "oldStatus"),
                    newStatus: parseString(f, "newStatus")
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.deviceHistoryList = finalList }
        }
    }

    // --- T. CHẤM CÔNG GPS & ĐIỀU PHỐI (ATTENDANCE & SHIFTS) ---
    func checkInAttendance(isCheckIn: Bool, lat: Double, lng: Double, address: String) async -> Bool {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: Date())
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let docId = "att_\(dateStr)_\(cleanEmail.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_"))"
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/attendances/\(docId)"
        guard let url = URL(string: urlStr) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        var fields: [String: Any] = [
            "userEmail": ["stringValue": cleanEmail],
            "userName": ["stringValue": userName],
            "donVi": ["stringValue": userDonVi],
            "departmentId": ["stringValue": userDept],
            "companyId": ["stringValue": companyId],
            "date": ["stringValue": dateStr]
        ]
        if isCheckIn {
            fields["checkInTime"] = ["integerValue": "\(nowMs)"]
            fields["checkInLat"] = ["doubleValue": lat]
            fields["checkInLng"] = ["doubleValue": lng]
            fields["checkInAddress"] = ["stringValue": address]
            fields["checkInStatus"] = ["stringValue": "ON_TIME"]
        } else {
            fields["checkOutTime"] = ["integerValue": "\(nowMs)"]
            fields["checkOutLat"] = ["doubleValue": lat]
            fields["checkOutLng"] = ["doubleValue": lng]
            fields["checkOutAddress"] = ["stringValue": address]
            fields["checkOutStatus"] = ["stringValue": "NORMAL"]
        }

        let body = ["fields": fields]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        if let (_, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
            await fetchAttendanceRecords()
            return true
        }
        return false
    }

    func fetchAttendanceRecords() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/attendances?pageSize=50"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [AttendanceRecordItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let inTime = parseInteger(f, "checkInTime")
                let outTime = parseInteger(f, "checkOutTime")
                let item = AttendanceRecordItem(
                    id: docId,
                    userEmail: parseString(f, "userEmail"),
                    userName: parseString(f, "userName"),
                    date: parseString(f, "date"),
                    checkInTime: formatTimestamp(inTime),
                    checkOutTime: outTime > 0 ? formatTimestamp(outTime) : "--:--",
                    checkInAddress: parseString(f, "checkInAddress"),
                    checkInStatus: parseString(f, "checkInStatus").isEmpty ? "Đúng giờ" : "Đúng giờ",
                    totalWorkMinutes: Int((outTime - inTime) / 60000)
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.attendanceRecords = finalList }
        }
    }

    func fetchOnlineKtvs() async {
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/technician_locations?pageSize=50"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        if let (data, res) = try? await URLSession.shared.data(for: req),
           let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let docs = json["documents"] as? [[String: Any]] {
            var list: [OnlineKtvItem] = []
            for d in docs {
                let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
                let f = d["fields"] as? [String: Any] ?? [:]
                let isOnline = (f["isOnline"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                let item = OnlineKtvItem(
                    email: docId,
                    name: parseString(f, "name").isEmpty ? docId : parseString(f, "name"),
                    isOnline: isOnline,
                    lastActive: formatTimestamp(parseInteger(f, "lastUpdatedAt")),
                    currentUnit: parseString(f, "currentUnit").isEmpty ? "IT Tập trung" : parseString(f, "currentUnit"),
                    assignedTickets: Int((f["activeTickets"] as? [String: Any])?["integerValue"] as? String ?? "0") ?? 0
                )
                list.append(item)
            }
            let finalList = list
            await MainActor.run { self.onlineKtvs = finalList }
        }
    }

    // Helper Date formatting
    private func SimpleDateFormat(_ pattern: String, _ locale: Locale) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = pattern
        f.locale = locale
        return f
    }

    // --- M. XÁC THỰC & TRA CỨU DOANH NGHIỆP / PHÒNG BAN / ĐƠN VỊ ---
    private var cachedGuestToken: String = ""
    private var guestTokenExpiry: Date = .distantPast

    func ensureGuestToken() async -> String? {
        if !cachedGuestToken.isEmpty && Date() < guestTokenExpiry {
            return cachedGuestToken
        }
        let authUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)"
        guard let url = URL(string: authUrl) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "email": "guest_lookup_qltb@gmail.com",
            "password": "GuestLookup@2026!",
            "returnSecureToken": true
        ]
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let idToken = json["idToken"] as? String {
                let expiresIn = Double(json["expiresIn"] as? String ?? "3600") ?? 3600
                self.cachedGuestToken = idToken
                self.guestTokenExpiry = Date().addingTimeInterval(expiresIn - 60)
                return idToken
            }
        } catch {}
        return nil
    }

    func checkCompanyExists(code: String) async -> (Bool, String?) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCodeUpper = cleanCode.uppercased()
        if cleanCode.isEmpty { return (false, nil) }
        guard let token = await ensureGuestToken() else { return (false, nil) }

        let directUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanCodeUpper)"
        if let url = URL(string: directUrl) {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, res) = try? await URLSession.shared.data(for: req),
               let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let name = parseString(fields, "companyName").isEmpty ? parseString(fields, "name") : parseString(fields, "companyName")
                let finalName = !name.isEmpty ? name : cleanCodeUpper
                return (true, finalName)
            }
        }

        let listUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies?pageSize=50"
        if let url = URL(string: listUrl) {
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let (data, res) = try? await URLSession.shared.data(for: req),
               let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    let docPath = doc["name"] as? String ?? ""
                    let docId = docPath.components(separatedBy: "/").last ?? ""
                    let f = doc["fields"] as? [String: Any] ?? [:]
                    let cId = parseString(f, "companyId").isEmpty ? docId : parseString(f, "companyId")
                    let cName = parseString(f, "companyName").isEmpty ? parseString(f, "name") : parseString(f, "companyName")
                    if cId.caseInsensitiveCompare(cleanCode) == .orderedSame ||
                       cId.caseInsensitiveCompare(cleanCodeUpper) == .orderedSame ||
                       cName.caseInsensitiveCompare(cleanCode) == .orderedSame {
                        let finalName = !cName.isEmpty ? cName : cleanCodeUpper
                        return (true, finalName)
                    }
                }
            }
        }
        return (false, nil)
    }

    func checkDepartmentExists(companyId: String, deptInput: String) async -> (Bool, String?) {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanDept = deptInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanComp.isEmpty || cleanDept.isEmpty { return (false, nil) }
        guard let token = await ensureGuestToken() else { return (false, nil) }

        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanComp)/departments?pageSize=100"
        guard let url = URL(string: urlStr) else { return (false, nil) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    let docPath = doc["name"] as? String ?? ""
                    let docId = docPath.components(separatedBy: "/").last ?? ""
                    let f = doc["fields"] as? [String: Any] ?? [:]
                    let dId = parseString(f, "deptId").isEmpty ? (parseString(f, "departmentId").isEmpty ? docId : parseString(f, "departmentId")) : parseString(f, "deptId")
                    let dName = parseString(f, "deptName").isEmpty ? (parseString(f, "departmentName").isEmpty ? parseString(f, "name") : parseString(f, "departmentName")) : parseString(f, "deptName")
                    let finalName = !dName.isEmpty ? dName : dId
                    if dId.caseInsensitiveCompare(cleanDept) == .orderedSame ||
                       dName.caseInsensitiveCompare(cleanDept) == .orderedSame {
                        return (true, finalName)
                    }
                }
                for doc in docs {
                    let docPath = doc["name"] as? String ?? ""
                    let docId = docPath.components(separatedBy: "/").last ?? ""
                    let f = doc["fields"] as? [String: Any] ?? [:]
                    let dId = parseString(f, "deptId").isEmpty ? (parseString(f, "departmentId").isEmpty ? docId : parseString(f, "departmentId")) : parseString(f, "deptId")
                    let dName = parseString(f, "deptName").isEmpty ? (parseString(f, "departmentName").isEmpty ? parseString(f, "name") : parseString(f, "departmentName")) : parseString(f, "deptName")
                    let finalName = !dName.isEmpty ? dName : dId
                    if dName.localizedCaseInsensitiveContains(cleanDept) || cleanDept.localizedCaseInsensitiveContains(dId) {
                        return (true, finalName)
                    }
                }
            }
        } catch {}
        return (false, nil)
    }

    func checkUnitExists(companyId: String, unitInput: String) async -> (Bool, String?) {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanUnit = unitInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanComp.isEmpty || cleanUnit.isEmpty { return (false, nil) }
        guard let token = await ensureGuestToken() else { return (false, nil) }

        let urlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanComp)/units?pageSize=100"
        guard let url = URL(string: urlStr) else { return (false, nil) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    let docPath = doc["name"] as? String ?? ""
                    let docId = docPath.components(separatedBy: "/").last ?? ""
                    let f = doc["fields"] as? [String: Any] ?? [:]
                    let uId = parseString(f, "unitId").isEmpty ? (parseString(f, "id").isEmpty ? docId : parseString(f, "id")) : parseString(f, "unitId")
                    let uName = parseString(f, "unitName").isEmpty ? (parseString(f, "tenDonVi").isEmpty ? parseString(f, "name") : parseString(f, "tenDonVi")) : parseString(f, "unitName")
                    let finalName = !uName.isEmpty ? uName : uId
                    if uId.caseInsensitiveCompare(cleanUnit) == .orderedSame ||
                       uName.caseInsensitiveCompare(cleanUnit) == .orderedSame {
                        return (true, finalName)
                    }
                }
                for doc in docs {
                    let docPath = doc["name"] as? String ?? ""
                    let docId = docPath.components(separatedBy: "/").last ?? ""
                    let f = doc["fields"] as? [String: Any] ?? [:]
                    let uId = parseString(f, "unitId").isEmpty ? (parseString(f, "id").isEmpty ? docId : parseString(f, "id")) : parseString(f, "unitId")
                    let uName = parseString(f, "unitName").isEmpty ? (parseString(f, "tenDonVi").isEmpty ? parseString(f, "name") : parseString(f, "tenDonVi")) : parseString(f, "unitName")
                    let finalName = !uName.isEmpty ? uName : uId
                    if uName.localizedCaseInsensitiveContains(cleanUnit) || cleanUnit.localizedCaseInsensitiveContains(uId) {
                        return (true, finalName)
                    }
                }
            }
        } catch {}
        return (false, nil)
    }

    // --- N. ĐĂNG KÝ DOANH NGHIỆP (ADMIN TẠO MỚI) ---
    func registerEnterprise(
        fullName: String,
        phone: String,
        email: String,
        pass: String,
        companyName: String,
        companyCode: String,
        taxCode: String,
        address: String
    ) async -> (success: Bool, message: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCompanyId = companyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // 1. Tạo tài khoản Firebase Auth
        let signUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)"
        guard let url = URL(string: signUpUrl) else {
            return (false, "Lỗi tạo đường dẫn đăng ký.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let authBody: [String: Any] = [
            "email": cleanEmail,
            "password": pass,
            "returnSecureToken": true
        ]

        var newIdToken = ""
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: authBody)
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse {
                if httpRes.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tok = json["idToken"] as? String {
                    newIdToken = tok
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? [String: Any],
                       let msg = err["message"] as? String {
                        if msg.contains("EMAIL_EXISTS") {
                            return (false, "Email này đã được sử dụng trên hệ thống. Vui lòng sử dụng email khác.")
                        } else if msg.contains("WEAK_PASSWORD") {
                            return (false, "Mật khẩu quá yếu. Vui lòng nhập tối thiểu 6 ký tự.")
                        }
                    }
                    return (false, "Đăng ký tài khoản không thành công. Vui lòng thử lại.")
                }
            }
        } catch {
            return (false, "Lỗi kết nối mạng: \(error.localizedDescription)")
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let tokenToUse = !newIdToken.isEmpty ? newIdToken : (await ensureGuestToken() ?? "")

        // 2. Tạo document công ty: companies/{companyId}
        let compUrlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanCompanyId)"
        if let compUrl = URL(string: compUrlStr) {
            var compReq = URLRequest(url: compUrl)
            compReq.httpMethod = "PATCH"
            compReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            compReq.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
            let compBody: [String: Any] = [
                "fields": [
                    "companyId": ["stringValue": cleanCompanyId],
                    "companyName": ["stringValue": companyName],
                    "taxCode": ["stringValue": taxCode],
                    "address": ["stringValue": address],
                    "phone": ["stringValue": phone],
                    "adminEmail": ["stringValue": cleanEmail],
                    "status": ["stringValue": "ACTIVE"],
                    "createdAt": ["integerValue": "\(nowMs)"]
                ]
            ]
            compReq.httpBody = try? JSONSerialization.data(withJSONObject: compBody)
            _ = try? await URLSession.shared.data(for: compReq)
        }

        // 3. Tạo document người dùng admin: companies/{companyId}/users/{cleanEmail}
        let userUrlStr = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanCompanyId)/users/\(cleanEmail)"
        if let userUrl = URL(string: userUrlStr) {
            var userReq = URLRequest(url: userUrl)
            userReq.httpMethod = "PATCH"
            userReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            userReq.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
            let finalName = !fullName.isEmpty ? fullName : "Admin \(companyName)"
            let userBody: [String: Any] = [
                "fields": [
                    "email": ["stringValue": cleanEmail],
                    "role": ["stringValue": "admin"],
                    "fullName": ["stringValue": finalName],
                    "phone": ["stringValue": phone],
                    "donVi": ["stringValue": companyName],
                    "companyId": ["stringValue": cleanCompanyId],
                    "departmentId": ["stringValue": "ADMIN"],
                    "status": ["stringValue": "ACTIVE"],
                    "password": ["stringValue": pass],
                    "createdAt": ["integerValue": "\(nowMs)"]
                ]
            ]
            userReq.httpBody = try? JSONSerialization.data(withJSONObject: userBody)
            _ = try? await URLSession.shared.data(for: userReq)
        }

        return (true, "Đăng ký doanh nghiệp \(companyName) (\(cleanCompanyId)) thành công!")
    }

    // --- O. GIA NHẬP CÔNG TY (NHÂN VIÊN GỬI YÊU CẦU XÉT DUYỆT) ---
    func joinCompany(
        fullName: String,
        mnv: String,
        phone: String,
        email: String,
        pass: String,
        companyCode: String,
        deptCode: String,
        deptName: String,
        unitCode: String,
        unitName: String
    ) async -> (success: Bool, message: String) {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCompId = companyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanMnv = mnv.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = unitCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDept = deptCode.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Tạo tài khoản Firebase Auth
        let signUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)"
        guard let url = URL(string: signUpUrl) else {
            return (false, "Lỗi tạo đường dẫn đăng ký.")
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let authBody: [String: Any] = [
            "email": cleanEmail,
            "password": pass,
            "returnSecureToken": true
        ]

        var newIdToken = ""
        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: authBody)
            let (data, res) = try await URLSession.shared.data(for: req)
            if let httpRes = res as? HTTPURLResponse {
                if httpRes.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let tok = json["idToken"] as? String {
                    newIdToken = tok
                } else {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let err = json["error"] as? [String: Any],
                       let msg = err["message"] as? String {
                        if msg.contains("EMAIL_EXISTS") {
                            return (false, "❌ Email này đã được đăng ký trên hệ thống. Vui lòng đăng nhập hoặc sử dụng email khác!")
                        } else if msg.contains("WEAK_PASSWORD") {
                            return (false, "❌ Mật khẩu quá yếu, vui lòng nhập tối thiểu 6 ký tự!")
                        } else if msg.contains("INVALID_EMAIL") {
                            return (false, "❌ Định dạng email không hợp lệ!")
                        }
                    }
                    return (false, "❌ Không thể tạo tài khoản xác thực. Vui lòng thử lại sau.")
                }
            }
        } catch {
            return (false, "❌ Lỗi kết nối mạng: \(error.localizedDescription)")
        }

        // 2. Gửi email xác thực tài khoản
        if !newIdToken.isEmpty {
            let verifyUrl = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(apiKey)"
            if let vUrl = URL(string: verifyUrl) {
                var vReq = URLRequest(url: vUrl)
                vReq.httpMethod = "POST"
                vReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let vBody: [String: Any] = [
                    "requestType": "VERIFY_EMAIL",
                    "idToken": newIdToken
                ]
                vReq.httpBody = try? JSONSerialization.data(withJSONObject: vBody)
                _ = try? await URLSession.shared.data(for: vReq)
            }
        }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let tokenToUse = !newIdToken.isEmpty ? newIdToken : (await ensureGuestToken() ?? "")

        // 3. Ghi nhận thông tin người dùng vào Firestore: companies/{companyId}/users/{email}
        let userDocUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanCompId)/users/\(cleanEmail)"
        if let uUrl = URL(string: userDocUrl) {
            var uReq = URLRequest(url: uUrl)
            uReq.httpMethod = "PATCH"
            uReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            uReq.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")

            var fields: [String: Any] = [
                "email": ["stringValue": cleanEmail],
                "fullName": ["stringValue": fullName],
                "phone": ["stringValue": phone],
                "role": ["stringValue": "nhanvien"],
                "companyId": ["stringValue": cleanCompId],
                "unitId": ["stringValue": cleanUnit.uppercased()],
                "donVi": ["stringValue": !unitName.isEmpty ? unitName : cleanUnit],
                "departmentId": ["stringValue": cleanDept],
                "phongBan": ["stringValue": !deptName.isEmpty ? deptName : cleanDept],
                "status": ["stringValue": "PENDING"],
                "emailVerified": ["booleanValue": false],
                "password": ["stringValue": pass],
                "createdAt": ["integerValue": "\(nowMs)"]
            ]
            if !cleanMnv.isEmpty {
                fields["maNhanVien"] = ["stringValue": cleanMnv]
                fields["employeeId"] = ["stringValue": cleanMnv]
            }

            let uBody: [String: Any] = ["fields": fields]
            uReq.httpBody = try? JSONSerialization.data(withJSONObject: uBody)
            _ = try? await URLSession.shared.data(for: uReq)
        }

        // 4. Gửi thông báo tới Quản trị viên: companies/{companyId}/notifications
        let notifUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(cleanCompId)/notifications"
        if let nUrl = URL(string: notifUrl) {
            var nReq = URLRequest(url: nUrl)
            nReq.httpMethod = "POST"
            nReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            nReq.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")

            let mnvMsg = !cleanMnv.isEmpty ? " | MNV: \(cleanMnv)" : ""
            let nBody: [String: Any] = [
                "fields": [
                    "title": ["stringValue": "📩 Yêu cầu gia nhập mới"],
                    "message": ["stringValue": "Nhân viên \(fullName) (\(cleanEmail)\(mnvMsg) | SĐT: \(phone)) đã gửi yêu cầu gia nhập [Phòng: \(!deptName.isEmpty ? deptName : cleanDept) | Đơn vị: \(!unitName.isEmpty ? unitName : cleanUnit)]"],
                    "companyId": ["stringValue": cleanCompId],
                    "type": ["stringValue": "JOIN_REQUEST"],
                    "targetGroup": ["stringValue": "ADMIN"],
                    "createdAt": ["integerValue": "\(nowMs)"]
                ]
            ]
            nReq.httpBody = try? JSONSerialization.data(withJSONObject: nBody)
            _ = try? await URLSession.shared.data(for: nReq)
        }

        return (true, cleanEmail)
    }

    private func iconForCategory(_ cat: String) -> String {
        let c = cat.lowercased()
        if c.contains("pos") { return "computermouse.fill" }
        if c.contains("scan") || c.contains("quét") { return "barcode.viewfinder" }
        if c.contains("print") || c.contains("in") { return "printer.fill" }
        if c.contains("wifi") || c.contains("ap") || c.contains("mạng") { return "wifi" }
        if c.contains("ups") || c.contains("điện") { return "bolt.batteryblock.fill" }
        return "desktopcomputer"
    }

    private func formatTimestamp(_ ts: Int64) -> String {
        if ts <= 0 { return "Vừa xong" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts / 1000))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 4. ROOT VIEW (Điều hướng Đăng nhập / Màn hình chính)
struct ContentView: View {
    @StateObject private var firebase = FirebaseService.shared

    var body: some View {
        Group {
            if firebase.isLoggedIn {
                if firebase.userAccountStatus == "PENDING" {
                    PendingApprovalView()
                        .environmentObject(firebase)
                } else {
                    MainAppView()
                        .environmentObject(firebase)
                }
            } else {
                LoginScreenView()
                    .environmentObject(firebase)
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - 4.1. LOGO COMPONENT (Hiển thị Logo App từ Asset Catalog & Vector Fallback)
struct AppLogoImage: View {
    var size: CGFloat = 110

    var body: some View {
        if let uiImage = UIImage(named: "logo_app") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Fallback Vector Logo Lá chắn chuẩn Saigon Co.op
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                Image(systemName: "shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.72, height: size * 0.72)
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Image(systemName: "desktopcomputer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.38, height: size * 0.38)
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - 4.2. SHEET QUÊN MẬT KHẨU
struct ForgotPasswordSheet: View {
    @EnvironmentObject var firebase: FirebaseService
    @Binding var isPresented: Bool
    @State private var emailInput: String = ""
    @State private var isSending: Bool = false
    @State private var message: String? = nil
    @State private var isSuccess: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Nhập email tài khoản để nhận liên kết đặt lại mật khẩu từ hệ thống Saigon Co.op.")
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email đã đăng ký")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)

                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(width: 20)
                        TextField("Nhập email đã đăng ký", text: $emailInput)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .tint(Color.appSecondaryDarkBlue)
                    }
                    .padding(12)
                    .background(Color.appBackground)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .padding(.horizontal, 16)

                if let msg = message {
                    Text(msg)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isSuccess ? Color.statusInUse : Color.statusBroken)
                        .padding(.horizontal, 16)
                }

                Button(action: {
                    let clean = emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    isSending = true
                    Task {
                        let ok = await firebase.resetPassword(email: clean)
                        isSending = false
                        isSuccess = ok
                        message = ok ? "✅ Đã gửi liên kết đặt lại mật khẩu! Vui lòng kiểm tra hộp thư." : "❌ Không tìm thấy tài khoản hoặc lỗi kết nối."
                    }
                }) {
                    HStack {
                        if isSending {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Gửi liên kết đặt lại mật khẩu")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appSecondaryDarkBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSending || emailInput.isEmpty)
                .padding(.horizontal, 16)

                Spacer()
            }
            .navigationTitle("Quên mật khẩu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 4.3. SHEET TRỢ GIÚP & HƯỚNG DẪN
struct HelpInstructionSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        AppLogoImage(size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quản Lý Thiết Bị")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text("Hệ thống quản lý tài sản & điều phối KTV")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .padding(.bottom, 8)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Hướng dẫn Đăng nhập:")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("""
• Sử dụng tài khoản email nội bộ do Saigon Co.op cấp (VD: admin@sgcoop.com).
• Nếu chưa có tài khoản, vui lòng liên hệ Quản lý phòng ban hoặc HelpDesk CNTT.
""")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)

                        Text("2. Quản lý Thiết bị:")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("""
• Tra cứu thiết bị theo mã vạch, tên máy hoặc số Serial.
• Cập nhật trạng thái thiết bị trực tuyến (Đang dùng, Đang sửa, Hỏng...).
""")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)

                        Text("3. Yêu cầu Hỗ trợ Kỹ thuật:")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("""
• Bấm nút tròn nổi (FAB) màu xanh để tạo nhanh phiếu cứu hộ sự cố quầy thu ngân.
• Nhắn tin trao đổi thời gian thực trực tiếp với Kỹ thuật viên qua khung chat.
""")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Trợ giúp & Hướng dẫn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - 4.35. MÀN HÌNH CHỜ PHÊ DUYỆT (PENDING APPROVAL - CHUẨN 100% ANDROID)
struct PendingApprovalView: View {
    @EnvironmentObject var firebase: FirebaseService
    @State private var isChecking: Bool = false
    @State private var checkMessage: String? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    // Biểu tượng đồng hồ cát chờ duyệt
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#FEF3C7"))
                            .frame(width: 90, height: 90)
                        Image(systemName: "hourglass.badge.eye")
                            .font(.system(size: 42))
                            .foregroundColor(Color(hex: "#D97706"))
                    }

                    Text("Tài Khoản Đang Chờ Phê Duyệt")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .multilineTextAlignment(.center)

                    Text("Yêu cầu gia nhập của bạn đã được chuyển tới Ban Quản Trị hệ thống Saigon Co.op.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    // Thẻ thông tin tài khoản
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Email đăng ký:")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                            Text(firebase.currentUserEmail)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                        }
                        Divider()
                        HStack {
                            Text("Mã doanh nghiệp:")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                            Text(firebase.companyId)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                        Divider()
                        HStack {
                            Text("Trạng thái xét duyệt:")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#F59E0B")).frame(width: 8, height: 8)
                                Text("ĐANG CHỜ DUYỆT")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(hex: "#D97706"))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "#FFFBEB"))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#FDE68A"), lineWidth: 1))

                    if let msg = checkMessage {
                        Text(msg)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(Color(hex: "#D97706"))
                    }

                    // Nút Kiểm tra lại
                    Button(action: {
                        isChecking = true
                        Task {
                            await firebase.checkUserApprovalStatus()
                            isChecking = false
                            if firebase.userAccountStatus == "ACTIVE" {
                                checkMessage = "✅ Tài khoản đã được phê duyệt! Đang vào hệ thống..."
                            } else {
                                checkMessage = "⏳ Tài khoản vẫn đang chờ phê duyệt. Vui lòng liên hệ Quản lý phòng ban."
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isChecking {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.clockwise")
                                Text("Kiểm tra lại trạng thái")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(12)
                    }
                    .disabled(isChecking)

                    // Nút Đăng xuất
                    Button(action: {
                        firebase.signOut()
                    }) {
                        Text("Đăng xuất tài khoản")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.statusBroken)
                    }
                    .padding(.top, 4)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - 4.4. SHEET ĐĂNG KÝ DOANH NGHIỆP (ADMIN TẠO MỚI)
struct RegisterEnterpriseSheet: View {
    @EnvironmentObject var firebase: FirebaseService
    @Binding var isPresented: Bool

    @State private var adminFullName: String = ""
    @State private var adminPhone: String = ""
    @State private var adminEmail: String = ""
    @State private var adminPassword: String = ""
    @State private var adminPasswordVisible: Bool = false
    @State private var companyNameInput: String = ""
    @State private var customCompanyCode: String = ""
    @State private var taxCode: String = ""
    @State private var companyAddress: String = ""

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessAlert: Bool = false
    @State private var successAlertMsg: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection
                        adminInfoFields
                        companyInfoFields
                        if let err = errorMessage {
                            errorBanner(err)
                        }
                        submitButton
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Đăng ký doanh nghiệp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
            .alert("Thông báo", isPresented: $showSuccessAlert) {
                Button("Đăng nhập ngay") {
                    isPresented = false
                }
            } message: {
                Text(successAlertMsg)
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Thông tin Doanh nghiệp & Quản trị viên")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)

            Text("Vui lòng nhập đầy đủ tất cả các trường thông tin bắt buộc (*)")
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
        }
    }

    @ViewBuilder
    private var adminInfoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Họ và tên Quản trị viên (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("VD: Nguyễn Văn A", text: $adminFullName)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Số điện thoại liên hệ (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("VD: 0901234567", text: $adminPhone)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                        .keyboardType(.phonePad)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email Quản trị viên (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("admin@congty.com", text: $adminEmail)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mật khẩu Quản trị viên (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    if adminPasswordVisible {
                        TextField("Tối thiểu 6 ký tự", text: $adminPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .tint(Color.appSecondaryDarkBlue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Tối thiểu 6 ký tự", text: $adminPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .tint(Color.appSecondaryDarkBlue)
                    }
                    Button(action: { adminPasswordVisible.toggle() }) {
                        Image(systemName: adminPasswordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(Color.appTextMuted)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }
        }
    }

    @ViewBuilder
    private var companyInfoFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tên Doanh nghiệp / Tổ chức (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("VD: Saigon Co.op, Co.opmart Cần Thơ...", text: $companyNameInput)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mã doanh nghiệp (Viết tắt) (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("VD: SGCOOP, SATRA...", text: Binding(
                        get: { customCompanyCode },
                        set: { customCompanyCode = $0.uppercased() }
                    ))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .tint(Color.appSecondaryDarkBlue)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))

                Text("Mã định danh duy nhất của doanh nghiệp, không thể đổi sau khi tạo.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Color.appPrimaryPink)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mã số thuế (nếu có)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("Mã số thuế doanh nghiệp", text: $taxCode)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Địa chỉ trụ sở (nếu có)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)
                    TextField("Địa chỉ trụ sở chính", text: $companyAddress)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }
        }
    }

    @ViewBuilder
    private func errorBanner(_ err: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
            Text(err)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusBroken)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var submitButton: some View {
        Button(action: {
            handleRegister()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Tạo Doanh Nghiệp & Kích Hoạt")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.appPrimaryPink)
            .cornerRadius(12)
        }
        .disabled(isLoading)
        .padding(.top, 8)
    }

    private func handleRegister() {
        let cleanName = adminFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = adminPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = adminEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPass = adminPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCompName = companyNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCompCode = customCompanyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if cleanName.isEmpty || cleanPhone.isEmpty || cleanEmail.isEmpty || cleanPass.isEmpty || cleanCompName.isEmpty || cleanCompCode.isEmpty {
            errorMessage = "Vui lòng nhập đầy đủ tất cả các trường bắt buộc (*)"
            return
        }

        if cleanPass.count < 6 {
            errorMessage = "Mật khẩu phải có tối thiểu 6 ký tự."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            let (success, msg) = await firebase.registerEnterprise(
                fullName: cleanName,
                phone: cleanPhone,
                email: cleanEmail,
                pass: cleanPass,
                companyName: cleanCompName,
                companyCode: cleanCompCode,
                taxCode: taxCode.trimmingCharacters(in: .whitespacesAndNewlines),
                address: companyAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            await MainActor.run {
                isLoading = false
                if success {
                    successAlertMsg = "Đăng ký thành công! Đã tạo doanh nghiệp \(cleanCompName) với mã [\(cleanCompCode)]. Bạn có thể đăng nhập ngay bằng tài khoản Admin vừa tạo."
                    showSuccessAlert = true
                } else {
                    errorMessage = msg
                }
            }
        }
    }
}

// MARK: - 4.5. SHEET GIA NHẬP CÔNG TY (NHÂN VIÊN / KTV)
struct JoinCompanySheet: View {
    @EnvironmentObject var firebase: FirebaseService
    @Binding var isPresented: Bool

    @State private var staffFullName: String = ""
    @State private var staffMnv: String = ""
    @State private var staffPhone: String = ""
    @State private var staffEmail: String = ""
    @State private var staffPassword: String = ""
    @State private var staffPasswordVisible: Bool = false
    @State private var staffCompanyCode: String = ""
    @State private var staffDeptCodeInput: String = ""
    @State private var staffUnitCodeInput: String = ""

    // Real-time verification states
    @State private var isVerifyingCompany: Bool = false
    @State private var verifiedCompanyName: String? = nil
    @State private var isVerifyingDept: Bool = false
    @State private var verifiedDeptName: String? = nil
    @State private var isVerifyingUnit: Bool = false
    @State private var verifiedUnitName: String? = nil

    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessDialog: Bool = false
    @State private var successEmailSentTo: String = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 14) {
                        headerSection
                        staffPersonalFields
                        organizationLookupFields
                        if let err = errorMessage {
                            errorBanner(err)
                        }
                        submitButton
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Gia nhập công ty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { isPresented = false }
                }
            }
            .alert("Gửi Yêu Cầu Thành Công!", isPresented: $showSuccessDialog) {
                Button("Đã Hiểu") {
                    isPresented = false
                }
            } message: {
                Text("Hệ thống đã gửi liên kết kích hoạt đến email:\n\(successEmailSentTo)\n\nVui lòng mở hòm thư (kể cả mục Thư rác / Spam) và nhấp vào liên kết để xác thực email trước khi Quản trị viên phê duyệt.")
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Thông tin Nhân viên / Kỹ thuật viên")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appPrimaryPink)

            Text("Vui lòng nhập đầy đủ tất cả các trường thông tin bắt buộc (*)")
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
        }
    }

    @ViewBuilder
    private var staffPersonalFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Họ tên
            VStack(alignment: .leading, spacing: 6) {
                Text("Họ và tên (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: Nguyễn Văn B", text: $staffFullName)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            // Mã NV (MNV)
            VStack(alignment: .leading, spacing: 6) {
                Text("Mã nhân viên (MNV) (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: 7075, 43144...", text: $staffMnv)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            // SĐT
            VStack(alignment: .leading, spacing: 6) {
                Text("Số điện thoại liên hệ (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: 0987654321", text: $staffPhone)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                        .keyboardType(.phonePad)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("nhanvien@congty.com", text: Binding(
                        get: { staffEmail },
                        set: { staffEmail = $0.lowercased() }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextPrimary)
                    .tint(Color.appSecondaryDarkBlue)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }

            // Mật khẩu
            VStack(alignment: .leading, spacing: 6) {
                Text("Mật khẩu (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    if staffPasswordVisible {
                        TextField("Tối thiểu 6 ký tự", text: $staffPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .tint(Color.appSecondaryDarkBlue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Tối thiểu 6 ký tự", text: $staffPassword)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                            .tint(Color.appSecondaryDarkBlue)
                    }
                    Button(action: { staffPasswordVisible.toggle() }) {
                        Image(systemName: staffPasswordVisible ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(Color.appTextMuted)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
            }
        }
    }

    @ViewBuilder
    private var organizationLookupFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Mã DN
            VStack(alignment: .leading, spacing: 6) {
                Text("Mã doanh nghiệp xin gia nhập (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: SGCOOP", text: Binding(
                        get: { staffCompanyCode },
                        set: {
                            staffCompanyCode = $0.uppercased()
                            triggerCompanyCheck(code: $0.uppercased())
                        }
                    ))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .tint(Color.appSecondaryDarkBlue)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)

                    if isVerifyingCompany {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))

                if isVerifyingCompany {
                    Text("Đang tìm kiếm thông tin doanh nghiệp...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appPrimaryPink)
                } else if !staffCompanyCode.isEmpty && verifiedCompanyName == nil {
                    Text("Mã doanh nghiệp không tồn tại trên hệ thống.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.statusBroken)
                } else if let cName = verifiedCompanyName {
                    Text("✓ Gia nhập: \(cName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#15803D"))
                }
            }

            // Mã Phòng Ban
            VStack(alignment: .leading, spacing: 6) {
                Text("Mã phòng ban (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: HELPDESK, CNTT, IT...", text: Binding(
                        get: { staffDeptCodeInput },
                        set: {
                            staffDeptCodeInput = $0
                            triggerDeptCheck(dept: $0)
                        }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextPrimary)
                    .tint(Color.appSecondaryDarkBlue)

                    if isVerifyingDept {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))

                if isVerifyingDept {
                    Text("Đang kiểm tra phòng ban...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appPrimaryPink)
                } else if !staffDeptCodeInput.isEmpty && verifiedDeptName == nil && verifiedCompanyName != nil {
                    Text("Không tìm thấy phòng ban này trong doanh nghiệp.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.statusBroken)
                } else if let dName = verifiedDeptName {
                    Text("✓ Phòng: \(dName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#15803D"))
                }
            }

            // Mã Đơn Vị
            VStack(alignment: .leading, spacing: 6) {
                Text("Mã đơn vị / Chi nhánh làm việc (*)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                HStack {
                    Image(systemName: "storefront.fill")
                        .foregroundColor(Color.appPrimaryPink)
                        .frame(width: 20)
                    TextField("VD: CT, HCM, 001, COOPMART...", text: Binding(
                        get: { staffUnitCodeInput },
                        set: {
                            staffUnitCodeInput = $0
                            triggerUnitCheck(unit: $0)
                        }
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextPrimary)
                    .tint(Color.appSecondaryDarkBlue)

                    if isVerifyingUnit {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))

                if isVerifyingUnit {
                    Text("Đang kiểm tra đơn vị...")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appPrimaryPink)
                } else if !staffUnitCodeInput.isEmpty && verifiedUnitName == nil && verifiedCompanyName != nil {
                    Text("Không tìm thấy đơn vị này trong doanh nghiệp.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.statusBroken)
                } else if let uName = verifiedUnitName {
                    Text("✓ Đơn vị: \(uName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#15803D"))
                }
            }
        }
    }

    @ViewBuilder
    private func errorBanner(_ err: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.white)
            Text(err)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.statusBroken)
        .cornerRadius(10)
    }

    @ViewBuilder
    private var submitButton: some View {
        Button(action: {
            handleJoin()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Gửi Yêu Cầu Xét Duyệt")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.appPrimaryPink)
            .cornerRadius(12)
        }
        .disabled(isLoading || verifiedCompanyName == nil || verifiedDeptName == nil || verifiedUnitName == nil)
        .opacity((verifiedCompanyName == nil || verifiedDeptName == nil || verifiedUnitName == nil) ? 0.6 : 1.0)
        .padding(.top, 8)
    }

    private func triggerCompanyCheck(code: String) {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else {
            verifiedCompanyName = nil
            isVerifyingCompany = false
            return
        }
        isVerifyingCompany = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let (exists, name) = await firebase.checkCompanyExists(code: clean)
            await MainActor.run {
                self.isVerifyingCompany = false
                self.verifiedCompanyName = exists ? name : nil
                if exists {
                    if !staffDeptCodeInput.isEmpty { triggerDeptCheck(dept: staffDeptCodeInput) }
                    if !staffUnitCodeInput.isEmpty { triggerUnitCheck(unit: staffUnitCodeInput) }
                }
            }
        }
    }

    private func triggerDeptCheck(dept: String) {
        let cleanDept = dept.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanComp = staffCompanyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanDept.isEmpty, !cleanComp.isEmpty else {
            verifiedDeptName = nil
            isVerifyingDept = false
            return
        }
        isVerifyingDept = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let (exists, name) = await firebase.checkDepartmentExists(companyId: cleanComp, deptInput: cleanDept)
            await MainActor.run {
                self.isVerifyingDept = false
                self.verifiedDeptName = exists ? name : nil
            }
        }
    }

    private func triggerUnitCheck(unit: String) {
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanComp = staffCompanyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanUnit.isEmpty, !cleanComp.isEmpty else {
            verifiedUnitName = nil
            isVerifyingUnit = false
            return
        }
        isVerifyingUnit = true
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            let (exists, name) = await firebase.checkUnitExists(companyId: cleanComp, unitInput: cleanUnit)
            await MainActor.run {
                self.isVerifyingUnit = false
                self.verifiedUnitName = exists ? name : nil
            }
        }
    }

    private func handleJoin() {
        let cleanName = staffFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMnv = staffMnv.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPhone = staffPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = staffEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPass = staffPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanComp = staffCompanyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanDept = staffDeptCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUnit = staffUnitCodeInput.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanName.isEmpty || cleanMnv.isEmpty || cleanPhone.isEmpty || cleanEmail.isEmpty || cleanPass.isEmpty || cleanComp.isEmpty || cleanDept.isEmpty || cleanUnit.isEmpty {
            errorMessage = "Vui lòng nhập đầy đủ tất cả các trường bắt buộc (*)"
            return
        }

        if verifiedCompanyName == nil {
            errorMessage = "Mã doanh nghiệp không tồn tại trên hệ thống."
            return
        }
        if verifiedDeptName == nil {
            errorMessage = "Không tìm thấy phòng ban hợp lệ trong doanh nghiệp."
            return
        }
        if verifiedUnitName == nil {
            errorMessage = "Không tìm thấy đơn vị hợp lệ trong doanh nghiệp."
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            let (success, resMsg) = await firebase.joinCompany(
                fullName: cleanName,
                mnv: cleanMnv,
                phone: cleanPhone,
                email: cleanEmail,
                pass: cleanPass,
                companyCode: cleanComp,
                deptCode: cleanDept,
                deptName: verifiedDeptName ?? cleanDept,
                unitCode: cleanUnit,
                unitName: verifiedUnitName ?? cleanUnit
            )

            await MainActor.run {
                isLoading = false
                if success {
                    successEmailSentTo = resMsg
                    showSuccessDialog = true
                } else {
                    errorMessage = resMsg
                }
            }
        }
    }
}


// MARK: - 7. PHÂN HỆ QUẢN LÝ THIẾT BỊ & TÀI SẢN (DEVICE ECOSYSTEM)

// MARK: - 7.1. CHI TIẾT THIẾT BỊ (DEVICE DETAIL VIEW - CHUẨN ANDROID DeviceScreen.kt)
struct DeviceDetailView: View {
    @EnvironmentObject var firebase: FirebaseService
    var device: DeviceItem
    var onDismiss: () -> Void

    @State private var showStatusPicker: Bool = false
    @State private var selectedStatus: String = ""
    @State private var statusNote: String = ""
    @State private var showHistorySheet: Bool = false
    @State private var showPrintSheet: Bool = false
    @State private var isUpdating: Bool = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    specsCard
                    actionsCard
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Chi tiết thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .sheet(isPresented: $showHistorySheet) {
                DeviceHistorySheetView(device: device, onDismiss: { showHistorySheet = false })
                    .environmentObject(firebase)
            }
            .sheet(isPresented: $showPrintSheet) {
                PrintScreenView(device: device)
            }
            .confirmationDialog("Cập nhật trạng thái thiết bị", isPresented: $showStatusPicker, titleVisibility: .visible) {
                Button("Mới nhập") { updateStatus("Mới nhập") }
                Button("Trong kho (Sẵn sàng)") { updateStatus("Trong kho (Sẵn sàng)") }
                Button("Đang sử dụng") { updateStatus("Đang sử dụng") }
                Button("Đang sửa chữa / Bảo hành") { updateStatus("Đang sửa chữa / Bảo hành") }
                Button("Hỏng / Chờ xử lý", role: .destructive) { updateStatus("Hỏng / Chờ xử lý") }
                Button("Đã thanh lý", role: .destructive) { updateStatus("Đã thanh lý") }
                Button("Hủy", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#EFF6FF"))
                        .frame(width: 64, height: 64)
                    Image(systemName: device.iconName)
                        .font(.system(size: 30))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Text("Mã: \(device.code)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Serial: \(device.serialNumber)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
            }

            Divider()

            HStack {
                Text("Trạng thái hiện tại:")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
                Text(device.status)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(device.status))
                    .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var specsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THÔNG TIN VẬN HÀNH")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.appTextMuted)

            infoRow(label: "Chủng loại", val: device.category, icon: "tag.fill")
            infoRow(label: "Đơn vị sử dụng", val: device.unit, icon: "storefront.fill")
            infoRow(label: "Phòng ban quản lý", val: device.department.isEmpty ? "Chưa gán" : device.department, icon: "building.2.fill")
            infoRow(label: "Doanh nghiệp", val: firebase.companyId, icon: "building.columns.fill")
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var actionsCard: some View {
        VStack(spacing: 10) {
            Button(action: { showStatusPicker = true }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Đổi trạng thái thiết bị")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appPrimaryPink)
                .cornerRadius(12)
            }

            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        await firebase.fetchDeviceHistory(deviceId: device.code)
                        showHistorySheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Lịch sử bảo trì")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
                }

                Button(action: { showPrintSheet = true }) {
                    HStack {
                        Image(systemName: "printer.fill")
                        Text("In tem nhãn QR")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1.2))
                }
            }
        }
    }

    private func infoRow(label: String, val: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color.appSecondaryDarkBlue)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13.5))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(val)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
        }
    }

    private func statusColor(_ st: String) -> Color {
        let s = st.lowercased()
        if s.contains("mới") || s.contains("kho") { return Color.statusNew }
        if s.contains("dùng") || s.contains("hoạt động") { return Color.statusInUse }
        if s.contains("sửa") || s.contains("bảo hành") { return Color.statusRepair }
        return Color.statusBroken
    }

    private func updateStatus(_ newSt: String) {
        Task {
            _ = await firebase.updateDeviceStatus(deviceId: device.code, newStatus: newSt, note: "Cập nhật qua ứng dụng iOS")
        }
    }
}

// MARK: - 7.2. LỊCH SỬ THIẾT BỊ (DEVICE HISTORY VIEW - LichSuScreen.kt)
struct DeviceHistorySheetView: View {
    @EnvironmentObject var firebase: FirebaseService
    var device: DeviceItem
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            Group {
                if firebase.deviceHistoryList.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundColor(Color.appTextMuted)
                        Text("Chưa có biến động bảo trì nào")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.appTextSecondary)
                        Text("Thiết bị hoạt động ổn định từ ngày nhập kho.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextMuted)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(firebase.deviceHistoryList) { h in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(h.action)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Spacer()
                                    Text(h.timestamp)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appTextMuted)
                                }
                                if !h.note.isEmpty {
                                    Text(h.note)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                HStack {
                                    Text("Bởi: \(h.performedBy)")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.appTextMuted)
                                    Spacer()
                                    if !h.newStatus.isEmpty {
                                        Text(h.newStatus)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Color.statusInUse)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Lịch sử thiết bị \(device.code)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 7.3. IN TEM NHÃN MÃ VẠCH QR (PRINT SCREEN - PrintScreen.kt)
struct PrintBarcodeView: View {
    var device: DeviceItem? = nil
    var onDismiss: () -> Void

    private var targetDevice: DeviceItem {
        device ?? DeviceItem(id: "DEMO", code: "POS-01", name: "Máy POS Thu Ngân", category: "POS", serialNumber: "SN-SGCOOP-8899", unit: "Co.opmart Cần Thơ", status: "Đang sử dụng", department: "Thu Ngân", iconName: "computermouse.fill")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Tem nhãn chuẩn siêu thị Saigon Co.op
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SAIGON CO.OP")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text("HỆ THỐNG QUẢN LÝ THIẾT BỊ")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appPrimaryPink)
                    }

                    Divider()

                    HStack(spacing: 16) {
                        // QR Code đồ hoạ
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black, lineWidth: 2)
                                .frame(width: 90, height: 90)
                            VStack(spacing: 3) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 60))
                                    .foregroundColor(.black)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(targetDevice.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .lineLimit(2)
                            Text("MÃ TB: \(targetDevice.code)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text("SN: \(targetDevice.serialNumber)")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text("ĐV: \(targetDevice.unit)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.black)
                        }
                        Spacer()
                    }
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#CBD5E1"), lineWidth: 1.5))
                .padding(.horizontal, 24)

                Text("Tem nhãn QR chuẩn dùng để dán lên thân thiết bị, hỗ trợ quét nhanh bằng camera máy tính bảng hoặc máy quét cầm tay Datalogic.")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // Nút In
                VStack(spacing: 12) {
                    Button(action: {
                        onDismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "printer.fill")
                            Text("In Tem Qua AirPrint / Máy In WiFi")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        onDismiss()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Chia sẻ tệp tem nhãn (PDF)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("In tem nhãn QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 7.4. THỐNG KÊ & BÁO CÁO (STATISTICS VIEW - ThongkeScreen.kt)
struct StatisticsView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    overviewGrid
                    statusBreakdownCard
                    categoryBreakdownCard
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Thống kê tài sản thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var overviewGrid: some View {
        let total = firebase.devices.count
        let inUse = firebase.devices.filter { $0.status.contains("dùng") || $0.status.contains("Đang") }.count
        let repair = firebase.devices.filter { $0.status.contains("sửa") || $0.status.contains("hành") }.count
        let broken = firebase.devices.filter { $0.status.contains("Hỏng") || $0.status.contains("hỏng") }.count

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statBox(title: "TỔNG THIẾT BỊ", count: total, color: Color.appSecondaryDarkBlue, icon: "desktopcomputer")
            statBox(title: "ĐANG SỬ DỤNG", count: inUse, color: Color.statusInUse, icon: "checkmark.seal.fill")
            statBox(title: "ĐANG SỬA CHỮA", count: repair, color: Color.statusRepair, icon: "wrench.and.screwdriver.fill")
            statBox(title: "HỎNG HÓC", count: broken, color: Color.statusBroken, icon: "exclamationmark.octagon.fill")
        }
    }

    private func statBox(title: String, count: Int, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text("\(count)")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(color)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var statusBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TỶ LỆ PHÂN BỔ TRẠNG THÁI")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.appTextMuted)

            let total = max(1, firebase.devices.count)
            let inUse = firebase.devices.filter { $0.status.contains("dùng") || $0.status.contains("Đang") }.count
            let inStock = firebase.devices.filter { $0.status.contains("kho") || $0.status.contains("Mới") }.count
            let repair = firebase.devices.filter { $0.status.contains("sửa") || $0.status.contains("hành") }.count

            progressBar(label: "Đang sử dụng", count: inUse, total: total, color: Color.statusInUse)
            progressBar(label: "Trong kho / Mới", count: inStock, total: total, color: Color.statusNew)
            progressBar(label: "Sửa chữa / Bảo hành", count: repair, total: total, color: Color.statusRepair)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PHÂN THEO CHỦNG LOẠI THIẾT BỊ")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.appTextMuted)

            let categories = ["POS", "Máy in", "Máy quét", "Mạng WiFi", "UPS"]
            ForEach(categories, id: \.self) { cat in
                let cCount = firebase.devices.filter { $0.category.localizedCaseInsensitiveContains(cat) }.count
                HStack {
                    Text(cat)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Text("\(cCount) máy")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }
                Divider()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func progressBar(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                Text("\(count)/\(total) (\(Int(Double(count) / Double(total) * 100))%)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#F1F5F9")).frame(height: 8)
                    Capsule().fill(color).frame(width: geo.size.width * CGFloat(Double(count) / Double(total)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - 7.5. QUẢN LÝ LOẠI THIẾT BỊ (DEVICE TYPE MANAGER - DeviceTypeManagerScreen.kt)
struct DeviceTypeManagerView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var newTypeName: String = ""
    @State private var showAddDialog: Bool = false

    var defaultTypes = [
        ("Máy bán hàng POS", "computermouse.fill", "#2563EB"),
        ("Máy quét mã vạch", "barcode.viewfinder", "#059669"),
        ("Máy in bill nhiệt", "printer.fill", "#7C3AED"),
        ("Thiết bị mạng WiFi", "wifi", "#0891B2"),
        ("Bộ lưu điện UPS", "bolt.batteryblock.fill", "#EA580C"),
        ("Máy vi tính PC", "desktopcomputer", "#475569")
    ]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("DANH MỤC THIẾT BỊ CHÍNH THỨC")) {
                    ForEach(defaultTypes, id: \.0) { t in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(hex: t.2).opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: t.1)
                                    .foregroundColor(Color(hex: t.2))
                            }
                            Text(t.0)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.appTextPrimary)
                            Spacer()
                            let count = firebase.devices.filter { $0.category.localizedCaseInsensitiveContains(t.0.prefix(5)) }.count
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.appSecondaryDarkBlue))
                        }
                    }
                }
            }
            .navigationTitle("Danh mục loại thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 8. PHÂN HỆ QUẢN TRỊ NHÂN SỰ & TỔ CHỨC (HR & ORGANIZATION)

// MARK: - 8.1. DUYỆT NHÂN VIÊN MỚI (APPROVE STAFF VIEW - ApproveStaffScreen.kt)
struct ApproveStaffView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var isLoading: Bool = false
    @State private var selectedStaff: PendingStaffItem? = nil
    @State private var selectedRole: String = "nhanvien"

    var body: some View {
        NavigationView {
            Group {
                if firebase.pendingStaffList.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 54))
                            .foregroundColor(Color.statusInUse)
                        Text("Không có yêu cầu chờ duyệt")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("Tất cả nhân viên đăng ký đã được Quản trị viên xử lý.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(firebase.pendingStaffList) { staff in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(staff.fullName)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.appTextPrimary)
                                        Text(staff.email)
                                            .font(.system(size: 12.5))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                    Spacer()
                                    Text("MNV: \(staff.maNhanVien.isEmpty ? "--" : staff.maNhanVien)")
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: "#EFF6FF"))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                        .cornerRadius(6)
                                }

                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "phone.fill").font(.system(size: 11))
                                        Text(staff.phone)
                                    }
                                    HStack(spacing: 4) {
                                        Image(systemName: "storefront.fill").font(.system(size: 11))
                                        Text(staff.donVi.isEmpty ? staff.unitId : staff.donVi)
                                    }
                                }
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)

                                Divider()

                                HStack(spacing: 10) {
                                    Button(action: {
                                        Task {
                                            _ = await firebase.rejectStaffMember(email: staff.email)
                                        }
                                    }) {
                                        Text("Từ chối")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color.statusBroken)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.statusBroken, lineWidth: 1))
                                    }

                                    Button(action: {
                                        Task {
                                            _ = await firebase.approveStaffMember(
                                                email: staff.email,
                                                role: "nhanvien",
                                                dept: staff.phongBan,
                                                unit: staff.donVi
                                            )
                                        }
                                    }) {
                                        Text("Phê duyệt")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(Color.statusInUse)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Duyệt nhân viên mới (\(firebase.pendingStaffList.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .onAppear {
                Task { await firebase.fetchPendingStaff() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 8.2. QUẢN LÝ NGƯỜI DÙNG (USER MANAGEMENT - UserManagementScreen.kt)
struct UserManagementView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var filterRole: String = "ALL"

    var filteredUsers: [UserItem] {
        firebase.allUsersList.filter { u in
            let matchSearch = searchText.isEmpty ||
                u.fullName.localizedCaseInsensitiveContains(searchText) ||
                u.email.localizedCaseInsensitiveContains(searchText) ||
                u.phone.contains(searchText)
            let matchRole = filterRole == "ALL" || u.role.localizedCaseInsensitiveContains(filterRole)
            return matchSearch && matchRole
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.appTextMuted)
                    TextField("Tìm theo tên, email, số điện thoại...", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(12)

                // Danh sách người dùng
                List {
                    ForEach(filteredUsers) { u in
                        HStack(spacing: 12) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(avatarColor(u.role))
                                    .frame(width: 40, height: 40)
                                Text(u.fullName.prefix(1).uppercased())
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(u.fullName)
                                        .font(.system(size: 14.5, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                    Spacer()
                                    Text(u.role.uppercased())
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(roleColor(u.role))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(roleColor(u.role).opacity(0.12))
                                        .cornerRadius(6)
                                }
                                Text(u.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                                HStack {
                                    Text(u.donVi.isEmpty ? "Co.opmart" : u.donVi)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.appTextMuted)
                                    Spacer()
                                    if u.status == "BLOCKED" {
                                        Text("ĐÃ KHÓA")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.statusBroken)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contextMenu {
                            Button("Đổi quyền -> Admin") { changeRole(u.email, "admin") }
                            Button("Đổi quyền -> Kỹ thuật viên") { changeRole(u.email, "kythuat") }
                            Button("Đổi quyền -> Quản lý phòng") { changeRole(u.email, "quanly") }
                            Button("Đổi quyền -> Nhân viên") { changeRole(u.email, "nhanvien") }
                            Divider()
                            if u.status == "BLOCKED" {
                                Button("Mở khóa tài khoản") { toggleBlock(u.email, false) }
                            } else {
                                Button("Khóa tài khoản", role: .destructive) { toggleBlock(u.email, true) }
                            }
                        }
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Quản lý thành viên (\(firebase.allUsersList.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .onAppear {
                Task { await firebase.fetchAllUsers() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    private func roleColor(_ r: String) -> Color {
        let rl = r.lowercased()
        if rl.contains("admin") { return Color.appPrimaryPink }
        if rl.contains("kythuat") || rl.contains("tech") { return Color(hex: "#059669") }
        if rl.contains("quanly") || rl.contains("phong") { return Color(hex: "#7C3AED") }
        return Color.appSecondaryDarkBlue
    }

    private func avatarColor(_ r: String) -> Color {
        roleColor(r)
    }

    private func changeRole(_ email: String, _ role: String) {
        Task { _ = await firebase.changeUserRole(email: email, newRole: role) }
    }

    private func toggleBlock(_ email: String, _ block: Bool) {
        Task { _ = await firebase.toggleUserBlock(email: email, block: block) }
    }
}

// MARK: - 8.3. QUẢN LÝ PHÒNG BAN (DEPARTMENT MANAGER - DepartmentManagerScreen.kt)
struct DepartmentManagerView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var showAddSheet: Bool = false
    @State private var newDeptId: String = ""
    @State private var newDeptName: String = ""
    @State private var newDeptManager: String = ""
    @State private var newDeptHotline: String = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(firebase.departmentsList) { d in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(d.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Text(d.id)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#EFF6FF"))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .cornerRadius(6)
                        }
                        if !d.managerName.isEmpty {
                            Text("Phụ trách: \(d.managerName)")
                                .font(.system(size: 12.5))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        if !d.hotline.isEmpty {
                            Text("Hotline: \(d.hotline)")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextMuted)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { idx in
                    for i in idx {
                        let id = firebase.departmentsList[i].id
                        Task { _ = await firebase.deleteDepartment(id: id) }
                    }
                }
            }
            .navigationTitle("Quản lý phòng ban")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Thêm") { showAddSheet = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addDeptSheet
            }
            .onAppear {
                Task { await firebase.fetchDepartments() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var addDeptSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN PHÒNG BAN MỚI")) {
                    TextField("Mã phòng ban (VD: HELPDESK, CNTT)", text: $newDeptId)
                        .autocapitalization(.allCharacters)
                    TextField("Tên phòng ban (*)", text: $newDeptName)
                    TextField("Họ tên Trưởng phòng / Phụ trách", text: $newDeptManager)
                    TextField("Số điện thoại Hotline", text: $newDeptHotline)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Thêm phòng ban")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        Task {
                            _ = await firebase.addDepartment(
                                id: newDeptId,
                                name: newDeptName,
                                manager: newDeptManager,
                                hotline: newDeptHotline
                            )
                            showAddSheet = false
                            newDeptId = ""
                            newDeptName = ""
                        }
                    }
                    .disabled(newDeptId.isEmpty || newDeptName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 8.4. QUẢN LÝ ĐƠN VỊ (UNIT MANAGER - UnitManagerScreen.kt)
struct UnitManagerView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var showAddSheet: Bool = false
    @State private var newUnitId: String = ""
    @State private var newUnitName: String = ""
    @State private var newUnitAddress: String = ""
    @State private var newUnitPhone: String = ""

    var body: some View {
        NavigationView {
            List {
                ForEach(firebase.unitsList) { u in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(u.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Text(u.id)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#EFF6FF"))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .cornerRadius(6)
                        }
                        if !u.address.isEmpty {
                            Text(u.address)
                                .font(.system(size: 12.5))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { idx in
                    for i in idx {
                        let id = firebase.unitsList[i].id
                        Task { _ = await firebase.deleteUnit(id: id) }
                    }
                }
            }
            .navigationTitle("Quản lý đơn vị Co.opmart")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Thêm") { showAddSheet = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addUnitSheet
            }
            .onAppear {
                Task { await firebase.fetchUnits() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var addUnitSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN ĐƠN VỊ / CHI NHÁNH")) {
                    TextField("Mã đơn vị (VD: CT, HCM, 001)", text: $newUnitId)
                        .autocapitalization(.allCharacters)
                    TextField("Tên đơn vị (*)", text: $newUnitName)
                    TextField("Địa chỉ chi nhánh", text: $newUnitAddress)
                    TextField("Số điện thoại liên hệ", text: $newUnitPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Thêm đơn vị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        Task {
                            _ = await firebase.addUnit(
                                id: newUnitId,
                                name: newUnitName,
                                address: newUnitAddress,
                                phone: newUnitPhone
                            )
                            showAddSheet = false
                            newUnitId = ""
                            newUnitName = ""
                        }
                    }
                    .disabled(newUnitId.isEmpty || newUnitName.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

struct RegionManagerView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var showAddSheet: Bool = false
    @State private var newRegionName: String = ""
    @State private var newRegionLeader: String = ""
    @State private var newRegionPhone: String = ""
    @State private var newRegionDesc: String = ""

    var body: some View {
        NavigationView {
            List {
                if firebase.regionsList.isEmpty {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color.appTextMuted)
                        Text("Chưa có khu vực nào")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    ForEach(firebase.regionsList) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Spacer()
                                Text(r.id)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.appTextMuted)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.12))
                                    .cornerRadius(4)
                            }
                            if !r.leader.isEmpty {
                                Text("👤 Phụ trách: \(r.leader)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            if !r.phone.isEmpty {
                                Text("📞 Hotline: \(r.phone)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            if !r.description.isEmpty {
                                Text(r.description)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indices in
                        for i in indices {
                            let item = firebase.regionsList[i]
                            Task { await firebase.deleteRegion(id: item.id) }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Quản lý khu vực")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { onDismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await firebase.fetchRegions()
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationView {
                    Form {
                        Section(header: Text("THÔNG TIN KHU VỰC")) {
                            TextField("Tên khu vực (VD: Khu Vực Miền Tây)", text: $newRegionName)
                            TextField("Người phụ trách khu vực", text: $newRegionLeader)
                            TextField("Số điện thoại liên hệ", text: $newRegionPhone)
                                .keyboardType(.phonePad)
                            TextField("Ghi chú / Mô tả", text: $newRegionDesc)
                        }
                    }
                    .navigationTitle("Thêm Khu Vực")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Hủy") { showAddSheet = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Lưu") {
                                let name = newRegionName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                let id = "KV_\(abs(name.hashValue % 9000) + 1000)"
                                Task {
                                    await firebase.addRegion(id: id, name: name, leader: newRegionLeader, phone: newRegionPhone, desc: newRegionDesc)
                                    newRegionName = ""
                                    newRegionLeader = ""
                                    newRegionPhone = ""
                                    newRegionDesc = ""
                                    showAddSheet = false
                                }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                            .disabled(newRegionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}


// MARK: - 9. PHÂN HỆ CHẤM CÔNG & ĐIỀU PHỐI (ATTENDANCE & DISPATCH)

// MARK: - 9.1. ĐIỂM DANH CHẤM CÔNG GPS (ATTENDANCE CHECKIN - AttendanceCheckInScreen.kt)
// MARK: - 2.9. CORE LOCATION GPS MANAGER (Định vị chuẩn iOS)
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var latitude: Double = 10.0352
    @Published var longitude: Double = 105.7890
    @Published var lastLocation: CLLocation? = nil
    @Published var isAuthorized: Bool = false
    @Published var locationStr: String = "10.0352° N, 105.7890° E"

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.lastLocation = loc
        self.latitude = loc.coordinate.latitude
        self.longitude = loc.coordinate.longitude
        let latDir = loc.coordinate.latitude >= 0 ? "N" : "S"
        let lonDir = loc.coordinate.longitude >= 0 ? "E" : "W"
        self.locationStr = String(format: "%.4f° %@, %.4f° %@", abs(loc.coordinate.latitude), latDir, abs(loc.coordinate.longitude), lonDir)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        #if os(iOS)
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            self.isAuthorized = true
            manager.startUpdatingLocation()
        default:
            self.isAuthorized = false
        }
        #endif
    }
}

struct AttendanceCheckInView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @StateObject private var locationManager = LocationManager()
    @State private var isProcessing: Bool = false
    @State private var resultMessage: String? = nil
    @State private var currentTimeStr: String = ""

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header Đồng hồ lớn
                VStack(spacing: 6) {
                    Text(currentTimeStr.isEmpty ? "08:00:00" : currentTimeStr)
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Hôm nay: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none))")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.top, 16)
                .onReceive(timer) { _ in
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm:ss"
                    currentTimeStr = f.string(from: Date())
                }

                // Thẻ Vị trí GPS
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(Color.appPrimaryPink)
                        Text("VỊ TRÍ ĐIỂM DANH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextMuted)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color.statusInUse).frame(width: 8, height: 8)
                            Text("GPS HỢP LỆ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.statusInUse)
                        }
                    }

                    Text("Địa điểm: \(firebase.userDonVi)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    if let loc = locationManager.lastLocation,
                       let store = CoopmartDirectory.resolveLocation(firebase.userDonVi) {
                        let distMeters = Int(store.distance(from: loc.coordinate.latitude, loc.coordinate.longitude) * 1000.0)
                        let isOk = distMeters <= 300
                        HStack {
                            Image(systemName: isOk ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isOk ? .green : .orange)
                            Text("Khoảng cách tới siêu thị: \(distMeters)m (\(isOk ? "Trong bán kính hợp lệ" : "Vượt quá 300m"))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isOk ? .green : .orange)
                        }
                    } else {
                        Text("Tọa độ thực tế: \(locationManager.locationStr) (Bán kính hợp lệ: 300m)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(.horizontal, 16)

                if let msg = resultMessage {
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.statusInUse)
                        .padding(.horizontal, 16)
                }

                Spacer()

                // Nút Chấm công Vào / Ra Ca
                HStack(spacing: 12) {
                    Button(action: {
                        handleCheck(isCheckIn: true)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.down.to.bracket")
                                .font(.system(size: 22, weight: .bold))
                            Text("VÀO CA")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(16)
                    }

                    Button(action: {
                        handleCheck(isCheckIn: false)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.and.arrow.down.left.rectangle")
                                .font(.system(size: 22, weight: .bold))
                            Text("RA CA")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(16)
                    }
                }
                .disabled(isProcessing)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Điểm danh chấm công GPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    private func handleCheck(isCheckIn: Bool) {
        isProcessing = true
        Task {
            let ok = await firebase.checkInAttendance(
                isCheckIn: isCheckIn,
                lat: locationManager.latitude,
                lng: locationManager.longitude,
                address: firebase.userDonVi
            )
            isProcessing = false
            resultMessage = ok ? "✅ Điểm danh \(isCheckIn ? "vào ca" : "ra ca") thành công tại \(firebase.userDonVi)!" : "❌ Không thể ghi nhận chấm công."
        }
    }
}

// MARK: - 9.2. BÁO CÁO CÔNG & LỊCH SỬ (ATTENDANCE REPORT - AttendanceReportScreen.kt)
struct AttendanceReportView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            Group {
                if firebase.attendanceRecords.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 48))
                            .foregroundColor(Color.appTextMuted)
                        Text("Chưa có dữ liệu chấm công")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(32)
                } else {
                    List {
                        ForEach(firebase.attendanceRecords) { rec in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(rec.userName)
                                        .font(.system(size: 14.5, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                    Spacer()
                                    Text(rec.date)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                                HStack(spacing: 16) {
                                    Text("Vào: \(rec.checkInTime)")
                                        .font(.system(size: 12.5))
                                        .foregroundColor(Color.statusInUse)
                                    Text("Ra: \(rec.checkOutTime)")
                                        .font(.system(size: 12.5))
                                        .foregroundColor(Color.statusRepair)
                                    Spacer()
                                    Text(rec.checkInStatus)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.statusInUse)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Báo cáo chấm công")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .onAppear {
                Task { await firebase.fetchAttendanceRecords() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 9.3. LỊCH TRỰC CA (SHIFT SCHEDULE - ShiftScheduleScreen.kt)
struct ShiftScheduleView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    var sampleShifts = [
        ("Dam Huu Phuc", "Sáng", "06:00 - 14:00", "IT TẬP TRUNG"),
        ("Ngo Duy Linh", "Chiều", "14:00 - 22:00", "IT TẬP TRUNG"),
        ("Huỳnh Nguyễn Anh Đức", "Hành chính", "08:00 - 17:00", "Co.opmart Cần Thơ"),
        ("Nguyễn Trung Hiếu", "Trực HT", "24/7 Hotline", "Phòng HelpDesk")
    ]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("LỊCH TRỰC KỸ THUẬT TUẦN NÀY")) {
                    ForEach(sampleShifts, id: \.0) { s in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.appSecondaryDarkBlue.opacity(0.12)).frame(width: 38, height: 38)
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.0)
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                Text(s.3)
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(s.1)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                Text(s.2)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.appTextMuted)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Lịch trực & Phân ca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 9.4. THEO DÕI KTV ONLINE (ONLINE KTV MONITOR - OnlineKtvMonitorScreen.kt)
struct OnlineKtvMonitorView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            Group {
                if firebase.onlineKtvs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 48))
                            .foregroundColor(Color.appTextMuted)
                        Text("Đang tải dữ liệu KTV...")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appTextSecondary)
                    }
                } else {
                    List {
                        ForEach(firebase.onlineKtvs) { ktv in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(ktv.isOnline ? Color.statusInUse : Color.gray.opacity(0.3)).frame(width: 12, height: 12)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ktv.name)
                                        .font(.system(size: 14.5, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                    Text(ktv.email)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appTextSecondary)
                                    Text("Địa bàn: \(ktv.currentUnit)")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.appTextMuted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(ktv.isOnline ? "TRỰC TUYẾN" : "OFFLINE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(ktv.isOnline ? Color.statusInUse : Color.gray)
                                    Text(ktv.lastActive)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextMuted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Theo dõi KTV trực tuyến")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
            .onAppear {
                Task { await firebase.fetchOnlineKtvs() }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 10. HỆ THỐNG & BẢN QUYỀN (SYSTEM & LICENSING)

// MARK: - 10.1. THÔNG BÁO HỆ THỐNG (SYSTEM NOTIFICATIONS - SystemNotificationScreen.kt)
struct SystemNotificationFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    var sampleNotifs = [
        ("🚨 Bảo trì hệ thống POS", "Hệ thống máy tính tiền POS tại Co.opmart Cần Thơ sẽ được cập nhật phần mềm lúc 22:30 hôm nay.", "10 phút trước", true),
        ("📢 Thông báo lịch trực Lễ", "Đề nghị các Kỹ thuật viên kiểm tra lịch phân ca trực Lễ 2/9 trong mục Lịch trực ca.", "2 giờ trước", false),
        ("🔔 Cập nhật ứng dụng QLTB v1.0.0", "Phiên bản mới đã bổ sung 100% chức năng Quản lý thiết bị, Chấm công GPS và Phê duyệt nhân sự.", "Hôm qua", false)
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(sampleNotifs, id: \.0) { n in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(n.0)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(n.3 ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                            Spacer()
                            Text(n.2)
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextMuted)
                        }
                        Text(n.1)
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextPrimary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Thông báo toàn hệ thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}

// MARK: - 10.2. GÓI CƯỚC & BẢN QUYỀN (PAYWALL - PaywallScreen.kt)
struct PaywallView: View {
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                ZStack {
                    Circle().fill(Color(hex: "#FEF3C7")).frame(width: 80, height: 80)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 38))
                        .foregroundColor(Color(hex: "#D97706"))
                }

                Text("QLTB ENTERPRISE PRO")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Hệ thống quản lý tài sản doanh nghiệp chính thức dành cho Saigon Co.op")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 10) {
                    proFeatureRow("Đồng bộ Firestore thời gian thực 2 chiều")
                    proFeatureRow("Chấm công định vị GPS chuẩn cự ly siêu thị")
                    proFeatureRow("Quản lý toàn diện thiết bị, in mã vạch QR")
                    proFeatureRow("Điều phối KTV và chat hỗ trợ khẩn cấp SLA")
                    proFeatureRow("Bảo mật tài khoản doanh nghiệp cao cấp")
                }
                .padding(18)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(.horizontal, 20)

                Spacer()

                Button(action: { onDismiss() }) {
                    Text("Đã Kích Hoạt Bản Quyền Doanh Nghiệp")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.statusInUse)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Bản quyền hệ thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    private func proFeatureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.statusInUse)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
        }
    }
}

// MARK: - 5. LOGIN VIEW (Màn hình Đăng nhập Co.opmart)
struct LoginScreenView: View {
    @EnvironmentObject var firebase: FirebaseService
    @State private var emailInput: String = ""
    @State private var passInput: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var showForgotSheet: Bool = false
    @State private var showRegisterEnterpriseSheet: Bool = false
    @State private var showJoinCompanySheet: Bool = false
    @State private var showHelpSheet: Bool = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Top Bar with Language Selector
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Text("🇻🇳")
                            Text("Tiếng Việt")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                    Spacer(minLength: 16)

                    // Main Card matching Android 1:1
                    VStack(spacing: 0) {
                        // 1. Logo
                        AppLogoImage(size: 115)
                            .padding(.top, 8)
                            .padding(.bottom, 12)

                        // 2. Title & Subtitle
                        Text("Quản Lý Thiết Bị")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        Text("Quản lý thiết bị & tài sản doanh nghiệp")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.top, 4)

                        // 3. Version badge
                        HStack(spacing: 4) {
                            Text("Phiên bản v1.0.0 (Build 1)")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#F1F5F9"))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                        .padding(.top, 8)
                        .padding(.bottom, 22)

                        // 4. Input Fields
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email hoặc Số điện thoại")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)

                            HStack {
                                Image(systemName: emailInput.contains("@") ? "envelope.fill" : "person.crop.circle.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 22)

                                TextField("Nhập email hoặc số điện thoại", text: $emailInput)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appTextPrimary)
                                    .tint(Color.appSecondaryDarkBlue)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1.2))
                        }
                        .padding(.bottom, 14)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mật khẩu")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)

                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 22)

                                if isPasswordVisible {
                                    TextField("Nhập mật khẩu", text: $passInput)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.appTextPrimary)
                                        .tint(Color.appSecondaryDarkBlue)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                } else {
                                    SecureField("Nhập mật khẩu", text: $passInput)
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.appTextPrimary)
                                        .tint(Color.appSecondaryDarkBlue)
                                }

                                Button(action: { isPasswordVisible.toggle() }) {
                                    Image(systemName: isPasswordVisible ? "eye.fill" : "eye.slash.fill")
                                        .foregroundColor(Color.appTextMuted)
                                }
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1.2))
                        }

                        // Quên mật khẩu link
                        HStack {
                            Spacer()
                            Button("Quên mật khẩu?") {
                                showForgotSheet = true
                            }
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .padding(.top, 6)
                        }
                        .padding(.bottom, 8)

                        // Error message
                        if let err = firebase.authError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.white)
                                Text(err)
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.statusBroken)
                            .cornerRadius(10)
                            .padding(.bottom, 10)
                        }

                        // 5. Nút Đăng nhập
                        Button(action: {
                            Task {
                                _ = await firebase.signIn(email: emailInput, pass: passInput)
                            }
                        }) {
                            HStack(spacing: 8) {
                                if firebase.isAuthenticating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("Đăng nhập")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.appSecondaryDarkBlue)
                            .cornerRadius(12)
                        }
                        .disabled(firebase.isAuthenticating || emailInput.isEmpty || passInput.isEmpty)
                        .padding(.top, 6)
                        .padding(.bottom, 20)

                        // 6. Lựa chọn Đăng ký
                        VStack(spacing: 10) {
                            Text("Chưa có tài khoản?")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)

                            HStack(spacing: 8) {
                                Button(action: {
                                    showRegisterEnterpriseSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 13))
                                        Text("Đăng ký công ty\n(Admin)")
                                            .font(.system(size: 11, weight: .bold))
                                            .multilineTextAlignment(.center)
                                    }
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                                }

                                Button(action: {
                                    showJoinCompanySheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.badge.plus")
                                            .font(.system(size: 13))
                                        Text("Gia nhập công ty\n(Nhân viên)")
                                            .font(.system(size: 11, weight: .bold))
                                            .multilineTextAlignment(.center)
                                    }
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                                }
                            }

                            // Trợ giúp link
                            Button(action: { showHelpSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 14))
                                    Text("Trợ giúp & Hướng dẫn sử dụng")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(24)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)

                    Spacer(minLength: 20)
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showForgotSheet) {
            ForgotPasswordSheet(isPresented: $showForgotSheet)
                .environmentObject(firebase)
        }
        .sheet(isPresented: $showHelpSheet) {
            HelpInstructionSheet(isPresented: $showHelpSheet)
        }
        .sheet(isPresented: $showRegisterEnterpriseSheet) {
            RegisterEnterpriseSheet(isPresented: $showRegisterEnterpriseSheet)
                .environmentObject(firebase)
        }
        .sheet(isPresented: $showJoinCompanySheet) {
            JoinCompanySheet(isPresented: $showJoinCompanySheet)
                .environmentObject(firebase)
        }
    }
}

// MARK: - 6. MAIN APP VIEW (Được nhúng sau khi đăng nhập)

enum ActiveSheet: Identifiable {
    case deviceDetail(DeviceItem)
    case scanner
    case addDevice
    case printBarcode
    case statistics
    case deviceType
    case approveStaff
    case userMgmt
    case department
    case unit
    case region
    case attendance
    case attendanceReport
    case shiftSchedule
    case ktvMonitor
    case systemNotif
    case paywall
    case notifications
    case guide
    case quickSupport
    case ticketDetail(SupportTicket)
    case deviceMgmtFull
    case supportRatingReport
    case scannerSettings
    case specialistTeam

    var id: String {
        switch self {
        case .deviceDetail(let d): return "dev_\(d.id)"
        case .scanner: return "scanner"
        case .addDevice: return "addDevice"
        case .printBarcode: return "printBarcode"
        case .statistics: return "statistics"
        case .deviceType: return "deviceType"
        case .approveStaff: return "approveStaff"
        case .userMgmt: return "userMgmt"
        case .department: return "department"
        case .unit: return "unit"
        case .region: return "region"
        case .attendance: return "attendance"
        case .attendanceReport: return "attendanceReport"
        case .shiftSchedule: return "shiftSchedule"
        case .ktvMonitor: return "ktvMonitor"
        case .systemNotif: return "systemNotif"
        case .paywall: return "paywall"
        case .notifications: return "notifications"
        case .guide: return "guide"
        case .quickSupport: return "quickSupport"
        case .ticketDetail(let t): return "ticket_\(t.id)"
        case .deviceMgmtFull: return "deviceMgmtFull"
        case .supportRatingReport: return "supportRatingReport"
        case .scannerSettings: return "scannerSettings"
        case .specialistTeam: return "specialistTeam"
        }
    }
}

struct MainAppView: View {
    @EnvironmentObject var firebase: FirebaseService

    @State private var selectedTab: Int = 0
    @State private var showDrawer: Bool = false
    @State private var showLogoutDialog: Bool = false
    @State private var activeSheet: ActiveSheet? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nội dung 4 Tab
                Group {
                    switch selectedTab {
                    case 0:
                        HomeScreenView(
                            onOpenDrawer: { showDrawer = true },
                            onOpenGuide: { activeSheet = .guide },
                            onOpenNotifications: { activeSheet = .notifications },
                            onOpenLogout: { showLogoutDialog = true },
                            onNavigateTab: { tab in selectedTab = tab },
                            onScanQr: { activeSheet = .scanner },
                            onAddDevice: { activeSheet = .addDevice },
                            onOpenAttendance: { activeSheet = .attendance },
                            onOpenShiftSchedule: { activeSheet = .shiftSchedule },
                            onOpenStatistics: { activeSheet = .statistics },
                            onOpenPrintBarcode: { activeSheet = .printBarcode }
                        )
                    case 1:
                        DeviceListView(
                            onOpenDrawer: { showDrawer = true },
                            onAddDevice: { activeSheet = .addDevice },
                            onScanDevice: { activeSheet = .scanner },
                            onSelectDevice: { device in activeSheet = .deviceDetail(device) },
                            onOpenAdvancedManagement: { activeSheet = .deviceMgmtFull }
                        )
                    case 2:
                        SupportHubView(
                            onOpenDrawer: { showDrawer = true },
                            onSelectTicket: { ticket in activeSheet = .ticketDetail(ticket) },
                            onCreateTicket: { activeSheet = .quickSupport },
                            onOpenRatingReport: { activeSheet = .supportRatingReport }
                        )
                    case 3:
                        SettingsView(
                            onOpenDrawer: { showDrawer = true },
                            onLogout: { showLogoutDialog = true },
                            onOpenPaywall: { activeSheet = .paywall },
                            onOpenDeviceTypes: { activeSheet = .deviceType },
                            onOpenDepartments: { activeSheet = .department },
                            onOpenUnits: { activeSheet = .unit },
                            onOpenRegions: { activeSheet = .region },
                            onOpenUserManagement: { activeSheet = .userMgmt },
                            onOpenApproveStaff: { activeSheet = .approveStaff },
                            onOpenSystemNotifications: { activeSheet = .systemNotif }
                        )
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Thanh điều hướng đáy (ProBottomBar chuẩn Android)
                ProBottomBarView(selectedTab: $selectedTab)
            }

            // Nút nổi Floating Action Button (Hỗ trợ khẩn cấp)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { activeSheet = .quickSupport }) {
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(Color.appSecondaryDarkBlue)
                                .frame(width: 58, height: 58)
                                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                                .overlay(
                                    Image(systemName: "headphones")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                )

                            let openCount = firebase.tickets.filter { $0.status == "OPEN" }.count
                            if openCount > 0 {
                                Text("\(openCount)")
                                    .font(.system(size: 11, weight: .heavy))
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Circle().fill(Color.appPrimaryPink))
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 74)
                }
            }

            // Menu Trượt Sidebar Drawer
            if showDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { showDrawer = false } }

                HStack {
                    AppSidebarDrawer(
                        onSelectRoute: { route in
                            withAnimation { showDrawer = false }
                            switch route {
                            case "home": selectedTab = 0
                            case "devices": selectedTab = 1
                            case "devices_full": activeSheet = .deviceMgmtFull
                            case "support": selectedTab = 2
                            case "settings": selectedTab = 3
                            case "cai_dat_scanner": activeSheet = .scannerSettings
                            case "add_device": activeSheet = .addDevice
                            case "printscreen": activeSheet = .printBarcode
                            case "thongke": activeSheet = .statistics
                            case "device_types": activeSheet = .deviceType
                            case "approve_staff": activeSheet = .approveStaff
                            case "user_mgmt": activeSheet = .userMgmt
                            case "department_manager": activeSheet = .department
                            case "specialist_team_manager": activeSheet = .specialistTeam
                            case "unit_manager": activeSheet = .unit
                            case "region_manager": activeSheet = .region
                            case "attendance_checkin": activeSheet = .attendance
                            case "attendance_report": activeSheet = .attendanceReport
                            case "support_rating_report": activeSheet = .supportRatingReport
                            case "shift_schedule": activeSheet = .shiftSchedule
                            case "online_ktv_monitor": activeSheet = .ktvMonitor
                            case "system_notifications": activeSheet = .systemNotif
                            case "paywall": activeSheet = .paywall
                            case "help": activeSheet = .guide
                            default: break
                            }
                        },
                        onLogout: {
                            showDrawer = false
                            showLogoutDialog = true
                        }
                    )
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetDestination(sheet)
                .environmentObject(firebase)
        }
        .alert(isPresented: $showLogoutDialog) {
            Alert(
                title: Text("Đăng xuất tài khoản"),
                message: Text("Bạn có chắc chắn muốn đăng xuất khỏi tài khoản \(firebase.currentUserEmail)?"),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    firebase.signOut()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    @ViewBuilder
    private func sheetDestination(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .deviceDetail(let dev):
            DeviceDetailView(device: dev, onDismiss: { activeSheet = nil })
        case .scanner:
            ScannerMockView(onDismiss: { activeSheet = nil })
        case .addDevice:
            AddDeviceFullView(onDismiss: { activeSheet = nil })
        case .printBarcode:
            PrintBarcodeView(device: firebase.devices.first, onDismiss: { activeSheet = nil })
        case .statistics:
            AssetStatisticsFullView(onDismiss: { activeSheet = nil })
        case .deviceType:
            DeviceTypeManagerFullView(onDismiss: { activeSheet = nil })
        case .approveStaff:
            ApproveStaffFullView(onDismiss: { activeSheet = nil })
        case .userMgmt:
            UserManagementFullView(onDismiss: { activeSheet = nil })
        case .department:
            DepartmentManagerFullView(onDismiss: { activeSheet = nil })
        case .unit:
            UnitRegionManagerFullView(onDismiss: { activeSheet = nil }, initialTab: 0)
        case .region:
            UnitRegionManagerFullView(onDismiss: { activeSheet = nil }, initialTab: 1)
        case .attendance:
            AttendanceCheckInFullView(onDismiss: { activeSheet = nil })
        case .attendanceReport:
            AttendanceReportFullView(onDismiss: { activeSheet = nil })
        case .deviceMgmtFull:
            DeviceManagementFullView(onDismiss: { activeSheet = nil })
        case .shiftSchedule:
            ShiftScheduleFullView(onDismiss: { activeSheet = nil })
        case .ktvMonitor:
            OnlineKtvMonitorFullView(onDismiss: { activeSheet = nil })
        case .supportRatingReport:
            SupportRatingReportFullView(onDismiss: { activeSheet = nil })
        case .systemNotif:
            SystemNotificationFullView(onDismiss: { activeSheet = nil })
        case .paywall:
            PaywallLicenseFullView(onDismiss: { activeSheet = nil })
        case .scannerSettings:
            HardwareScannerSettingsFullView(onDismiss: { activeSheet = nil })
        case .notifications:
            NotificationListView(onDismiss: { activeSheet = nil })
        case .guide:
            GuideTourModalView(onDismiss: { activeSheet = nil })
        case .quickSupport:
            QuickSupportModalView(onDismiss: { activeSheet = nil })
        case .ticketDetail(let ticket):
            TicketChatDetailView(ticket: ticket, onDismiss: { activeSheet = nil })
        case .specialistTeam:
            SpecialistTeamManagerFullView(onDismiss: { activeSheet = nil })
        }
    }
}

// MARK: - 7. PRO BOTTOM BAR COMPONENT
struct ProBottomBarView: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            BottomBarTabItem(
                title: "Trang chủ",
                icon: "house.fill",
                isSelected: selectedTab == 0,
                action: { selectedTab = 0 }
            )
            BottomBarTabItem(
                title: "Thiết bị",
                icon: "laptopcomputer.and.iphone",
                isSelected: selectedTab == 1,
                action: { selectedTab = 1 }
            )
            BottomBarTabItem(
                title: "Hỗ trợ",
                icon: "person.crop.circle.badge.questionmark",
                isSelected: selectedTab == 2,
                action: { selectedTab = 2 }
            )
            BottomBarTabItem(
                title: "Cài đặt",
                icon: "gearshape.fill",
                isSelected: selectedTab == 3,
                action: { selectedTab = 3 }
            )
        }
        .frame(height: 64)
        .background(Color.appBottomBar.ignoresSafeArea(edges: .bottom))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct BottomBarTabItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.appPrimaryPink.opacity(0.2))
                            .frame(width: 48, height: 26)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.appBottomBarSelected : Color.appBottomBarUnselected)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 8. HOME SCREEN VIEW (Tích hợp Live Firebase)
struct HomeScreenView: View {
    @EnvironmentObject var firebase: FirebaseService

    let onOpenDrawer: () -> Void
    let onOpenGuide: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenLogout: () -> Void
    let onNavigateTab: (Int) -> Void
    let onScanQr: () -> Void
    let onAddDevice: () -> Void
    var onOpenAttendance: (() -> Void)? = nil
    var onOpenShiftSchedule: (() -> Void)? = nil
    var onOpenStatistics: (() -> Void)? = nil
    var onOpenPrintBarcode: (() -> Void)? = nil

    @State private var showEditNameAlert: Bool = false
    @State private var showEditPhoneAlert: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // TopBar Xanh Đậm (#002A8F)
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                HStack(spacing: 8) {
                    AppLogoImage(size: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("Trang chủ")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                // Nút Bóng đèn Hướng dẫn (Vàng)
                Button(action: onOpenGuide) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FBBF24"))
                        .frame(width: 34, height: 34)
                }

                // Chuông Thông báo
                Button(action: onOpenNotifications) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)

                        Circle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 8, height: 8)
                            .offset(x: -4, y: 4)
                    }
                }

                // Menu 3 chấm
                Menu {
                    Button(action: onOpenGuide) {
                        Label("Trợ giúp & Hướng dẫn", systemImage: "questionmark.circle")
                    }
                    Button(action: { onNavigateTab(3) }) {
                        Label("Cấu hình hệ thống", systemImage: "gearshape")
                    }
                    Divider()
                    Button(role: .destructive, action: onOpenLogout) {
                        Label("Đăng xuất", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Banner Ticker Thông báo khẩn
            HStack(spacing: 8) {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#002A8F"))
                Text("SGCOOP: Nhắc nhở KTV hoàn tất bảo dưỡng POS siêu thị trước 17:00")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#0F172A"))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(hex: "#FEF08A"))

            // Nội dung cuộn chính
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. Thẻ Hồ Sơ Người Dùng (Live Firestore)
                    UserProfileCardView(
                        userName: firebase.userName,
                        userRole: firebase.userRole,
                        userEmail: firebase.currentUserEmail,
                        userPhone: firebase.userPhone,
                        userDept: firebase.userDept,
                        userDonVi: firebase.userDonVi,
                        onEditName: { showEditNameAlert = true },
                        onEditPhone: { showEditPhoneAlert = true }
                    )

                    // 2. Hàng Thống Kê Tổng Quan (Live Firestore)
                    DashboardStatsRowView(
                        deviceCount: firebase.devices.count,
                        openTicketCount: firebase.tickets.filter { $0.status == "OPEN" }.count,
                        onDeviceClick: { onNavigateTab(1) },
                        onTicketClick: { onNavigateTab(2) }
                    )

                    // 3. Lưới 8 Thao Tác Nhanh
                    QuickAccessSectionView(
                        onScanQr: onScanQr,
                        onAddDevice: onAddDevice,
                        onDeviceList: { onNavigateTab(1) },
                        onSupportHub: { onNavigateTab(2) },
                        onAttendance: onOpenAttendance,
                        onShiftSchedule: onOpenShiftSchedule,
                        onStatistics: onOpenStatistics,
                        onPrintBarcode: onOpenPrintBarcode
                    )

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .sheet(isPresented: $showEditNameAlert) {
            EditNameModal(isPresented: $showEditNameAlert)
        }
        .sheet(isPresented: $showEditPhoneAlert) {
            EditPhoneModal(isPresented: $showEditPhoneAlert)
        }
    }
}

// MARK: - 9. USER PROFILE CARD COMPONENT
struct UserProfileCardView: View {
    let userName: String
    let userRole: String
    let userEmail: String
    let userPhone: String
    let userDept: String
    let userDonVi: String
    let onEditName: () -> Void
    let onEditPhone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.appSecondaryDarkBlue, Color.appPrimaryPink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)

                    Text(getInitials(name: userName))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(userName)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)

                        Button(action: onEditName) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color.appPrimaryPink)
                        }

                        Spacer()

                        Text(userRole)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appSecondaryDarkBlue.opacity(0.12))
                            .cornerRadius(6)
                    }

                    Text(userEmail)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appPrimaryPink)

                        Text(userPhone.isEmpty ? "Chưa có SĐT" : userPhone)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(userPhone.isEmpty ? Color.appTextMuted : Color.appTextPrimary)

                        Button(action: onEditPhone) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                }
            }

            Divider().background(Color.appCardBorder)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("🏛️")
                        .font(.system(size: 13))
                    Text(userDept)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Text("🏬")
                        .font(.system(size: 13))
                    Text(userDonVi)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func getInitials(name: String) -> String {
        let parts = name.split(separator: " ")
        if let last = parts.last, let firstChar = last.first {
            return String(firstChar)
        }
        return "S"
    }
}

// MARK: - 10. DASHBOARD STATS ROW
struct DashboardStatsRowView: View {
    let deviceCount: Int
    let openTicketCount: Int
    let onDeviceClick: () -> Void
    let onTicketClick: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onDeviceClick) {
                StatsCardItem(
                    title: "Thiết bị",
                    count: "\(deviceCount)",
                    subtitle: "Tổng Firestore",
                    icon: "laptopcomputer",
                    accentColor: Color(hex: "#2563EB"),
                    bgColor: Color(hex: "#EFF6FF")
                )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onTicketClick) {
                StatsCardItem(
                    title: "Sự cố mở",
                    count: "\(openTicketCount)",
                    subtitle: openTicketCount > 0 ? "Cần xử lý ngay" : "Đang ổn định",
                    icon: openTicketCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.seal.fill",
                    accentColor: openTicketCount > 0 ? Color(hex: "#DC2626") : Color(hex: "#16A34A"),
                    bgColor: openTicketCount > 0 ? Color(hex: "#FEF2F2") : Color(hex: "#F0FDF4")
                )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {}) {
                StatsCardItem(
                    title: "Điểm danh",
                    count: "GPS",
                    subtitle: "Vào / Ra ca",
                    icon: "clock.badge.checkmark.fill",
                    accentColor: Color(hex: "#0D9488"),
                    bgColor: Color(hex: "#F0FDFA")
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct StatsCardItem: View {
    let title: String
    let count: String
    let subtitle: String
    let icon: String
    let accentColor: Color
    let bgColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(bgColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                Spacer()

                Text(count)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 11. QUICK ACCESS SECTION
struct QuickAccessSectionView: View {
    let onScanQr: () -> Void
    let onAddDevice: () -> Void
    let onDeviceList: () -> Void
    let onSupportHub: () -> Void
    var onAttendance: (() -> Void)? = nil
    var onShiftSchedule: (() -> Void)? = nil
    var onStatistics: (() -> Void)? = nil
    var onPrintBarcode: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Truy cập nhanh chức năng")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("8 lối tắt chính")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextMuted)
            }

            HStack(spacing: 10) {
                QuickCardItem(title: "Quét QR", icon: "qrcode.viewfinder", color: Color(hex: "#E11D48"), bgColor: Color(hex: "#FFE4E6"), action: onScanQr)
                QuickCardItem(title: "Thêm TB", icon: "plus.app.fill", color: Color(hex: "#2563EB"), bgColor: Color(hex: "#DBEAFE"), action: onAddDevice)
                QuickCardItem(title: "Thiết bị", icon: "laptopcomputer", color: Color(hex: "#0D9488"), bgColor: Color(hex: "#CCFBF1"), action: onDeviceList)
                QuickCardItem(title: "Hỗ trợ", icon: "person.crop.circle.badge.questionmark.fill", color: Color(hex: "#EA580C"), bgColor: Color(hex: "#FFEDD5"), action: onSupportHub)
            }

            HStack(spacing: 10) {
                QuickCardItem(title: "Chấm công", icon: "clock.fill", color: Color(hex: "#059669"), bgColor: Color(hex: "#D1FAE5"), action: { onAttendance?() })
                QuickCardItem(title: "Phân ca", icon: "calendar.badge.clock", color: Color(hex: "#7C3AED"), bgColor: Color(hex: "#EDE9FE"), action: { onShiftSchedule?() })
                QuickCardItem(title: "Thống kê", icon: "chart.bar.fill", color: Color(hex: "#D97706"), bgColor: Color(hex: "#FEF3C7"), action: { onStatistics?() })
                QuickCardItem(title: "In tem", icon: "printer.fill", color: Color(hex: "#4F46E5"), bgColor: Color(hex: "#EEF2FF"), action: { onPrintBarcode?() })
            }
        }
    }
}

struct QuickCardItem: View {
    let title: String
    let icon: String
    let color: Color
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(bgColor)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 12. DEVICE LIST VIEW (Live Firestore)
struct DeviceListView: View {
    @EnvironmentObject var firebase: FirebaseService

    let onOpenDrawer: () -> Void
    let onAddDevice: () -> Void
    let onScanDevice: () -> Void
    var onSelectDevice: ((DeviceItem) -> Void)? = nil
    var onOpenAdvancedManagement: (() -> Void)? = nil

    @State private var searchText: String = ""
    @State private var selectedFilter: String = "Tất cả"
    let filterOptions = ["Tất cả", "Đang sử dụng", "Mới", "Sửa chữa", "Hỏng"]

    var filteredDevices: [DeviceItem] {
        firebase.userFilteredDevices.filter { item in
            let matchSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.code.localizedCaseInsensitiveContains(searchText) ||
                item.serialNumber.localizedCaseInsensitiveContains(searchText)

            let matchFilter = selectedFilter == "Tất cả" || item.status == selectedFilter
            return matchSearch && matchFilter
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Danh sách Thiết bị")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if firebase.isLoadingDevices {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                if let advAction = onOpenAdvancedManagement {
                    Button(action: advAction) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }

                Button(action: onScanDevice) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                Button(action: onAddDevice) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Thanh tìm kiếm
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextMuted)
                TextField("Tìm theo tên, mã máy, Serial Number...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextPrimary)
                    .tint(Color.appSecondaryDarkBlue)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chip Lọc Trạng Thái
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filterOptions, id: \.self) { opt in
                        Button(action: { selectedFilter = opt }) {
                            Text(opt)
                                .font(.system(size: 12, weight: selectedFilter == opt ? .bold : .medium))
                                .foregroundColor(selectedFilter == opt ? .white : Color.appTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == opt ? Color.appSecondaryDarkBlue : Color.white)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.appCardBorder, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            // Danh sách thiết bị thật
            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredDevices.isEmpty && !firebase.isLoadingDevices {
                        VStack(spacing: 12) {
                            Image(systemName: "tray.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color.appTextMuted)
                            Text("Chưa có thiết bị nào phù hợp")
                                .font(.system(size: 14))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredDevices) { item in
                            DeviceCardItemView(device: item) {
                                onSelectDevice?(item)
                            }
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
    }
}

struct DeviceCardItemView: View {
    let device: DeviceItem
    var onTap: (() -> Void)? = nil

    var statusColor: Color {
        switch device.status {
        case "Đang sử dụng": return Color.statusInUse
        case "Mới": return Color.statusNew
        case "Sửa chữa": return Color.statusRepair
        case "Hỏng": return Color.statusBroken
        default: return Color.gray
        }
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(statusColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: device.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(device.code)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        Spacer()

                        Text(device.status)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(statusColor.opacity(0.12))
                            .cornerRadius(6)
                    }

                    Text(device.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("SN: \(device.serialNumber)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextMuted)

                        Text("•")
                            .foregroundColor(Color.appTextMuted)

                        Text(device.unit)
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 13. SUPPORT HUB VIEW (Live Firestore)
struct SupportHubView: View {
    @EnvironmentObject var firebase: FirebaseService

    let onOpenDrawer: () -> Void
    let onSelectTicket: (SupportTicket) -> Void
    let onCreateTicket: () -> Void
    var onOpenRatingReport: (() -> Void)? = nil

    @State private var selectedStatus: String = "OPEN"

    var filteredTickets: [SupportTicket] {
        let base = firebase.userFilteredTickets
        if selectedStatus == "ALL" { return base }
        if selectedStatus == "CLOSED" {
            return base.filter { $0.status == "CLOSED" || $0.status == "RESOLVED" }
        }
        return base.filter { $0.status == selectedStatus }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Trung tâm Hỗ trợ Kỹ thuật")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if firebase.isLoadingTickets {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }

                if let reportAction = onOpenRatingReport {
                    Button(action: reportAction) {
                        Image(systemName: "star.bubble.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                }

                Button(action: onCreateTicket) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            // Status Tabs
            let baseList = firebase.userFilteredTickets
            HStack(spacing: 0) {
                TicketTabButton(title: "Chờ tiếp nhận", count: baseList.filter { $0.status == "OPEN" }.count, isSelected: selectedStatus == "OPEN") {
                    selectedStatus = "OPEN"
                }
                TicketTabButton(title: "Đang xử lý", count: baseList.filter { $0.status == "IN_PROGRESS" }.count, isSelected: selectedStatus == "IN_PROGRESS") {
                    selectedStatus = "IN_PROGRESS"
                }
                TicketTabButton(title: "Đã xong", count: baseList.filter { $0.status == "CLOSED" || $0.status == "RESOLVED" }.count, isSelected: selectedStatus == "CLOSED") {
                    selectedStatus = "CLOSED"
                }
            }
            .background(Color.white)
            .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 12) {
                    if filteredTickets.isEmpty && !firebase.isLoadingTickets {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color.statusInUse)
                            Text("Không có sự cố nào trong mục này")
                                .font(.system(size: 14))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredTickets) { ticket in
                            Button(action: { onSelectTicket(ticket) }) {
                                TicketCardItemView(ticket: ticket)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
    }
}

struct TicketTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? Color.appPrimaryPink : Color.appTextSecondary)
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isSelected ? Color.appPrimaryPink : Color.gray))
                    }
                }
                .padding(.top, 12)

                Rectangle()
                    .fill(isSelected ? Color.appPrimaryPink : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct TicketCardItemView: View {
    let ticket: SupportTicket

    var priorityColor: Color {
        if ticket.priority.contains("P1") { return Color(hex: "#DC2626") }
        if ticket.priority.contains("P2") { return Color(hex: "#EA580C") }
        return Color(hex: "#2563EB")
    }

    var sourceBadge: (text: String, icon: String, fg: Color, bg: Color) {
        let src = ticket.source.uppercased()
        switch src {
        case "EMAIL":
            return ("Email M365", "envelope.fill", Color(hex: "#6D28D9"), Color(hex: "#EDE9FE"))
        case "ZALO":
            return ("Zalo OA", "bubble.left.and.bubble.right.fill", Color(hex: "#0284C7"), Color(hex: "#E0F2FE"))
        case "WEB":
            return ("Web Portal", "globe", Color(hex: "#0D9488"), Color(hex: "#CCFBF1"))
        case "PHONE":
            return ("Hotline", "phone.fill", Color(hex: "#16A34A"), Color(hex: "#DCFCE7"))
        default:
            return ("App Di động", "iphone", Color.appPrimaryPink, Color(hex: "#FCE7F3"))
        }
    }

    var statusBadge: (text: String, fg: Color, bg: Color) {
        switch ticket.status {
        case "OPEN":
            return ("Chờ tiếp nhận", Color(hex: "#D97706"), Color(hex: "#FEF3C7"))
        case "IN_PROGRESS":
            return ("Đang xử lý", Color(hex: "#2563EB"), Color(hex: "#DBEAFE"))
        case "RESOLVED":
            return ("Đã xử lý xong", Color(hex: "#4F46E5"), Color(hex: "#EEF2FF"))
        case "CLOSED":
            return ("Đã đóng", Color(hex: "#16A34A"), Color(hex: "#DCFCE7"))
        default:
            return (ticket.status, Color.secondary, Color(hex: "#F1F5F9"))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Badges row: Priority, Omni-Channel Source, Status
            HStack(spacing: 6) {
                Text(ticket.priority)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.12))
                    .cornerRadius(4)

                // Omni-channel badge
                let src = sourceBadge
                HStack(spacing: 3) {
                    Image(systemName: src.icon)
                        .font(.system(size: 9))
                    Text(src.text)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(src.fg)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(src.bg)
                .cornerRadius(4)

                Spacer()

                // Status badge
                let st = statusBadge
                Text(st.text)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(st.fg)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(st.bg)
                    .cornerRadius(6)
            }

            Text(ticket.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
                .lineLimit(2)

            if !ticket.lastMessage.isEmpty {
                Text(ticket.lastMessage)
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextMuted)
                    .lineLimit(1)
            }

            // Rating Stars Banner if already rated
            if ticket.rating > 0 {
                HStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= ticket.rating ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#F59E0B"))
                        }
                    }
                    Text("(\(ticket.rating)/5★\(ticket.feedback.isEmpty ? "" : " - \(ticket.feedback)"))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#92400E"))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FFFBEB"))
                .cornerRadius(6)
            }

            Divider().background(Color.appCardBorder)

            HStack {
                Text("🏬 \(ticket.unit)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)

                Spacer()

                Text("👤 \(ticket.assignedKtv)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }
}

// MARK: - 14. SETTINGS VIEW
struct SettingsView: View {
    @EnvironmentObject var firebase: FirebaseService

    let onOpenDrawer: () -> Void
    let onLogout: () -> Void
    var onOpenPaywall: (() -> Void)? = nil
    var onOpenDeviceTypes: (() -> Void)? = nil
    var onOpenDepartments: (() -> Void)? = nil
    var onOpenUnits: (() -> Void)? = nil
    var onOpenRegions: (() -> Void)? = nil
    var onOpenUserManagement: (() -> Void)? = nil
    var onOpenApproveStaff: (() -> Void)? = nil
    var onOpenSystemNotifications: (() -> Void)? = nil

    @State private var printThermalAuto: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onOpenDrawer) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Cài đặt & Ngoại vi")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .background(Color.appTopBar)

            ScrollView {
                VStack(spacing: 16) {
                    // MÁY IN NHIỆT & MÃ VẠCH
                    VStack(alignment: .leading, spacing: 10) {
                        Text("MÁY IN NHIỆT & MÃ VẠCH")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "printer.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text("Máy in nhiệt Bluetooth (ESC/POS)")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Kết nối máy in tem cầm tay 58mm/80mm")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextMuted)
                                }
                                Spacer()
                                Text("Đã ghép đôi")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.statusInUse)
                            }
                            .padding(14)

                            Divider()

                            Toggle(isOn: $printThermalAuto) {
                                HStack {
                                    Image(systemName: "doc.plaintext.fill")
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                        .frame(width: 28)
                                    Text("Tự động in phiếu sau khi sửa chữa")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(14)
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                    }

                    // QUẢN TRỊ DOANH NGHIỆP & HỆ THỐNG
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUẢN TRỊ DOANH NGHIỆP & HỆ THỐNG")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            settingsNavButton(title: "Quản trị người dùng & Phân quyền", icon: "person.2.fill", action: { onOpenUserManagement?() })
                            Divider()
                            settingsNavButton(title: "Duyệt nhân viên mới", icon: "person.crop.circle.badge.checkmark", badge: firebase.pendingStaffList.count, action: { onOpenApproveStaff?() })
                            Divider()
                            settingsNavButton(title: "Quản lý danh mục loại thiết bị", icon: "square.grid.2x2.fill", action: { onOpenDeviceTypes?() })
                            Divider()
                            settingsNavButton(title: "Quản lý phòng ban", icon: "building.2.fill", action: { onOpenDepartments?() })
                            Divider()
                            settingsNavButton(title: "Quản lý đơn vị / cơ sở", icon: "building.columns.fill", action: { onOpenUnits?() })
                            Divider()
                            settingsNavButton(title: "Quản lý khu vực", icon: "map.fill", action: { onOpenRegions?() })
                            Divider()
                            settingsNavButton(title: "Thông báo hệ thống toàn quốc", icon: "bell.badge.fill", action: { onOpenSystemNotifications?() })
                        }
                        .background(Color.white)
                        .cornerRadius(14)
                    }

                    // TÀI KHOẢN & BẢN QUYỀN DOANH NGHIỆP
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TÀI KHOẢN & BẢN QUYỀN DOANH NGHIỆP")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 12) {
                            SettingsInfoRow(title: "Tài khoản hiện tại", value: firebase.currentUserEmail)
                            Divider()
                            SettingsInfoRow(title: "Doanh nghiệp", value: "SAIGON CO.OP (\(firebase.companyId))")
                            Divider()
                            SettingsInfoRow(title: "Chức danh", value: firebase.userRole)
                            Divider()
                            SettingsInfoRow(title: "Gói bản quyền", value: "Enterprise PRO (Không giới hạn)")
                            Divider()
                            SettingsInfoRow(title: "Thời hạn bản quyền", value: "31/12/2026")
                            Divider()
                            SettingsInfoRow(title: "Phiên bản iOS", value: "v1.0.0 (Build 34773809159)")
                        }
                        .padding(14)
                        .background(Color.white)
                        .cornerRadius(14)

                        Button(action: { onOpenPaywall?() }) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(Color(hex: "#F59E0B"))
                                Text("Nâng cấp gói Doanh nghiệp PRO")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color(hex: "#D97706"))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "#D97706"))
                            }
                            .padding(12)
                            .background(Color(hex: "#FEF3C7"))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Button(action: onLogout) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .bold))
                            Text("Đăng xuất tài khoản")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "#DC2626"))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 80)
                }
                .padding(16)
            }
        }
    }

    private func settingsNavButton(title: String, icon: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .frame(width: 28)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.appPrimaryPink))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextMuted)
            }
            .padding(14)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
        }
    }
}

// MARK: - 15. APP SIDEBAR DRAWER
struct AppSidebarDrawer: View {
    @EnvironmentObject var firebase: FirebaseService

    let onSelectRoute: (String) -> Void
    let onLogout: () -> Void

    @State private var isDeviceExpanded: Bool = true
    @State private var isPersonnelExpanded: Bool = true
    @State private var isAttendanceExpanded: Bool = true
    @State private var isSystemExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Công ty & Hồ sơ
            drawerHeader

            // Scrollable Menu
            ScrollView {
                VStack(spacing: 4) {
                    DrawerItem(title: "Trang chủ", icon: "house.fill", iconColor: Color(hex: "#0284C7"), action: { onSelectRoute("home") })

                    let openTickets = firebase.userFilteredTickets.filter { $0.status == "OPEN" }.count
                    DrawerItem(title: "Hỗ trợ kỹ thuật", icon: "headphones", iconColor: Color.appPrimaryPink, badgeCount: openTickets, action: { onSelectRoute("support") })

                    // Section 1: Quản lý thiết bị
                    drawerSectionHeader(title: "QUẢN LÝ THIẾT BỊ", color: Color(hex: "#059669"), isExpanded: $isDeviceExpanded)
                    if isDeviceExpanded {
                        DrawerItem(title: "Danh sách thiết bị", icon: "laptopcomputer", iconColor: Color(hex: "#10B981"), action: { onSelectRoute("devices") })
                        DrawerItem(title: "Quản lý nâng cao (Gom nhóm)", icon: "square.stack.3d.up.fill", iconColor: Color(hex: "#059669"), action: { onSelectRoute("devices_full") })
                        DrawerItem(title: "Thêm thiết bị mới", icon: "plus.app.fill", iconColor: Color(hex: "#8B5CF6"), action: { onSelectRoute("add_device") })
                        DrawerItem(title: "Danh mục loại thiết bị", icon: "square.grid.2x2.fill", iconColor: Color(hex: "#0EA5E9"), action: { onSelectRoute("device_types") })
                        DrawerItem(title: "In ấn & Tem nhãn QR", icon: "printer.fill", iconColor: Color(hex: "#A855F7"), action: { onSelectRoute("printscreen") })
                        DrawerItem(title: "Thống kê thiết bị", icon: "chart.bar.xaxis", iconColor: Color(hex: "#14B8A6"), action: { onSelectRoute("thongke") })
                    }

                    // Section 2: Quản lý nhân sự & Tổ chức (Admin / Quản lý)
                    if firebase.isManagerOrAdmin {
                        drawerSectionHeader(title: "QUẢN LÝ NHÂN SỰ & TỔ CHỨC", color: Color(hex: "#6366F1"), isExpanded: $isPersonnelExpanded)
                        if isPersonnelExpanded {
                            DrawerItem(title: "Quản lý người dùng", icon: "person.2.fill", iconColor: Color(hex: "#3B82F6"), action: { onSelectRoute("user_mgmt") })
                            DrawerItem(title: "Duyệt nhân viên mới", icon: "person.crop.circle.badge.checkmark", iconColor: Color(hex: "#10B981"), badgeCount: firebase.pendingStaffList.count, action: { onSelectRoute("approve_staff") })
                            DrawerItem(title: "Quản lý phòng ban", icon: "building.2.fill", iconColor: Color(hex: "#818CF8"), action: { onSelectRoute("department_manager") })
                            DrawerItem(title: "Quản lý tổ nghiệp vụ", icon: "briefcase.fill", iconColor: Color(hex: "#0D9488"), action: { onSelectRoute("specialist_team_manager") })
                            DrawerItem(title: "Quản lý đơn vị", icon: "building.columns.fill", iconColor: Color(hex: "#6366F1"), action: { onSelectRoute("unit_manager") })
                            DrawerItem(title: "Quản lý khu vực", icon: "map.fill", iconColor: Color(hex: "#F59E0B"), action: { onSelectRoute("region_manager") })
                        }
                    }

                    // Section 3: Chấm công & Điều phối
                    drawerSectionHeader(title: "CHẤM CÔNG & ĐIỀU PHỐI", color: Color(hex: "#F97316"), isExpanded: $isAttendanceExpanded)
                    if isAttendanceExpanded {
                        DrawerItem(title: "Điểm danh Chấm công GPS", icon: "location.circle.fill", iconColor: Color(hex: "#06B6D4"), action: { onSelectRoute("attendance_checkin") })
                        DrawerItem(title: "Báo cáo công & OSRM", icon: "doc.text.magnifyingglass", iconColor: Color(hex: "#FB923C"), action: { onSelectRoute("attendance_report") })
                        DrawerItem(title: "Lịch trực & Phân ca", icon: "calendar.badge.clock", iconColor: Color(hex: "#8B5CF6"), action: { onSelectRoute("shift_schedule") })
                        DrawerItem(title: "Theo dõi KTV Online", icon: "antenna.radiowaves.left.and.right", iconColor: Color(hex: "#10B981"), action: { onSelectRoute("online_ktv_monitor") })
                        DrawerItem(title: "Đánh giá chất lượng CSAT & SLA", icon: "star.bubble.fill", iconColor: Color(hex: "#F59E0B"), action: { onSelectRoute("support_rating_report") })
                    }

                    // Section 4: Hệ thống & Cài đặt
                    drawerSectionHeader(title: "HỆ THỐNG & BẢN QUYỀN", color: Color(hex: "#64748B"), isExpanded: $isSystemExpanded)
                    if isSystemExpanded {
                        DrawerItem(title: "Cài đặt máy in / máy quét", icon: "gearshape.2.fill", iconColor: Color(hex: "#64748B"), action: { onSelectRoute("cai_dat_scanner") })
                        DrawerItem(title: "Thông báo hệ thống", icon: "bell.badge.fill", iconColor: Color(hex: "#475569"), action: { onSelectRoute("system_notifications") })
                        DrawerItem(title: "Gói cước & Bản quyền", icon: "crown.fill", iconColor: Color(hex: "#F59E0B"), action: { onSelectRoute("paywall") })
                        DrawerItem(title: "Cẩm nang trợ giúp", icon: "questionmark.circle.fill", iconColor: Color(hex: "#FBBF24"), action: { onSelectRoute("help") })
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            // Footer Đăng xuất
            drawerFooter
        }
        .frame(width: 320)
        .background(Color(hex: "#F8FAFC"))
        .ignoresSafeArea()
    }

    private var drawerHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AppLogoImage(size: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAIGON CO.OP")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("Mã DN: \(firebase.companyId)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#93C5FD"))
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.15))

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimaryPink)
                        .frame(width: 42, height: 42)
                    let initial = String(firebase.userName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
                    Text(initial.isEmpty ? "U" : initial)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(firebase.userName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(firebase.currentUserEmail)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#CBD5E1"))
                        .lineLimit(1)
                    Text(firebase.userRole)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#FDE68A"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSecondaryDarkBlue)
    }

    private var drawerFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button(action: onLogout) {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 14, weight: .bold))
                        Text("Đăng xuất")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#DC2626"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#FEE2E2"))
                    .cornerRadius(8)
                }
                Spacer()
                Text("v1.2.0 (Build 120)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.white)
    }

    private func drawerSectionHeader(title: String, color: Color, isExpanded: Binding<Bool>) -> some View {
        Button(action: { withAnimation { isExpanded.wrappedValue.toggle() } }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3.5, height: 13)
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(color)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color.opacity(0.8))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DrawerItem: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    var iconColor: Color = Color(hex: "#64748B")
    var badgeCount: Int = 0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDestructive ? Color.red.opacity(0.12) : iconColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15))
                        .foregroundColor(isDestructive ? .red : iconColor)
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isDestructive ? .red : Color(hex: "#334155"))
                    .lineLimit(1)
                Spacer()
                if badgeCount > 0 {
                    Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.appPrimaryPink))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 16. MODALS & SUBVIEWS
struct ScannerMockView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Hướng camera về phía mã vạch / QR thiết bị")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.top, 40)

                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.appPrimaryPink, lineWidth: 3)
                            .frame(width: 250, height: 250)

                        Rectangle()
                            .fill(Color.appPrimaryPink.opacity(0.8))
                            .frame(width: 230, height: 2)
                    }

                    Text("Hỗ trợ chuẩn: QR Code, Code128, EAN-13, Code39")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    Spacer()
                }
            }
            .navigationTitle("Quét Barcode / QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct AddDeviceModalView: View {
    @EnvironmentObject var firebase: FirebaseService
    let onDismiss: () -> Void

    @State private var code: String = ""
    @State private var name: String = ""
    @State private var category: String = "POS"
    @State private var unit: String = ""
    @State private var status: String = "Mới"
    @State private var isSubmitting: Bool = false

    let categories = ["POS", "Scanner", "Printer", "PC", "Network", "UPS"]
    let statuses = ["Mới", "Đang sử dụng", "Sửa chữa", "Hỏng"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN ĐỊNH DANH (FIRESTORE)")) {
                    TextField("Mã thiết bị (VD: SG-POS-113-99)", text: $code)
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                    TextField("Tên thiết bị (VD: Máy POS Sunmi)", text: $name)
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }

                Section(header: Text("PHÂN LOẠI & ĐƠN VỊ")) {
                    Picker("Danh mục", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Tình trạng", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    TextField("Đơn vị sử dụng", text: $unit)
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
            }
            .navigationTitle("Thêm Thiết Bị Mới")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                unit = firebase.userDonVi
                if code.isEmpty {
                    code = "SG-TB-\(Int.random(in: 1000...9999))"
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu lên Firestore") {
                        if !code.isEmpty && !name.isEmpty {
                            isSubmitting = true
                            Task {
                                let success = await firebase.addDeviceToFirestore(
                                    code: code,
                                    name: name,
                                    category: category,
                                    unit: unit,
                                    status: status
                                )
                                if success {
                                    onDismiss()
                                }
                                isSubmitting = false
                            }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .disabled(isSubmitting || code.isEmpty || name.isEmpty)
                }
            }
        }
    }
}

struct NotificationListView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            List {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔔 KTV hoàn tất bảo dưỡng POS")
                        .font(.system(size: 14, weight: .bold))
                    Text("Đã cập nhật tình trạng 4 máy POS tại Co.opmart Cần Thơ hoạt động ổn định.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Text("10 phút trước")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextMuted)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ Cảnh báo SLA Sự cố P1")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#DC2626"))
                    Text("Sự cố quầy thu ngân 03 sắp hết hạn SLA (còn 15 phút). KTV vui lòng kiểm tra.")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Text("25 phút trước")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextMuted)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Thông Báo Hệ Thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                }
            }
        }
    }
}

struct GuideTourModalView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TourSectionItem(number: "1", title: "Hồ Sơ & Đơn Vị Trực Thuộc 👤", desc: "Hiển thị thông tin cá nhân, chức danh, phòng ban và chi nhánh Co.opmart bạn đang trực thuộc. Có thể bấm đổi họ tên và SĐT bất cứ lúc nào.")
                    TourSectionItem(number: "2", title: "Trung Tâm Thao Tác Nhanh ⚡", desc: "8 lối tắt chính: Quét QR, Thêm mới thiết bị, Quản lý danh sách, Xem Ticket hỗ trợ, Chấm công GPS và In tem phiếu qua máy in Bluetooth.")
                    TourSectionItem(number: "3", title: "Điều Phối & Hỗ Trợ Kỹ Thuật 🎧", desc: "Nút nổi hỗ trợ khẩn cấp luôn sẵn sàng ở góc dưới phải để tạo yêu cầu trợ giúp và chat trực tiếp với HelpDesk SGCOOP.")
                }
                .padding(20)
            }
            .navigationTitle("Cẩm Nang Ứng Dụng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đã hiểu", action: onDismiss)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
}

struct TourSectionItem: View {
    let number: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Color.appSecondaryDarkBlue).frame(width: 32, height: 32)
                Text(number).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
    }
}

struct QuickSupportModalView: View {
    @EnvironmentObject var firebase: FirebaseService
    let onDismiss: () -> Void

    @State private var title: String = ""
    @State private var priority: String = "HIGH"
    @State private var unit: String = ""
    @State private var isSubmitting: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("YÊU CẦU TRỢ GIÚP KHẨN CẤP (LƯU LÊN FIRESTORE)")) {
                    TextField("Mô tả sự cố (VD: Máy in hóa đơn quầy 03 kẹt giấy)", text: $title)
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                    Picker("Mức độ ưu tiên", selection: $priority) {
                        Text("P1 - Khẩn cấp (SLA 30p)").tag("URGENT")
                        Text("P2 - Cao (SLA 2h)").tag("HIGH")
                        Text("P3 - Bình thường (SLA 8h)").tag("NORMAL")
                    }
                    TextField("Địa điểm / Quầy xảy ra sự cố", text: $unit)
                        .foregroundColor(Color.appTextPrimary)
                        .tint(Color.appSecondaryDarkBlue)
                }
            }
            .navigationTitle("Tạo Yêu Cầu Hỗ Trợ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                unit = firebase.userDonVi
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gửi Ticket") {
                        if !title.isEmpty {
                            isSubmitting = true
                            Task {
                                let success = await firebase.createTicketOnFirestore(subject: title, unit: unit, priority: priority)
                                if success {
                                    onDismiss()
                                }
                                isSubmitting = false
                            }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .disabled(isSubmitting || title.isEmpty)
                }
            }
        }
    }
}

// MARK: - ImagePickerModal (Native UIImagePickerController for iOS 15)
struct ImagePickerModal: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            picker.sourceType = sourceType
        } else {
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerModal
        init(_ parent: ImagePickerModal) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.selectedImage = img
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct TicketChatDetailView: View {
    @EnvironmentObject var firebase: FirebaseService
    let ticket: SupportTicket
    let onDismiss: () -> Void

    @State private var currentStatus: String = "OPEN"
    @State private var assignedKtvName: String = ""
    @State private var currentRating: Int = 0
    @State private var currentFeedback: String = ""

    @State private var messageInput: String = ""
    @State private var isSending: Bool = false
    @State private var showLiveTracking: Bool = false
    @State private var showIconPicker: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showAttachmentActionSheet: Bool = false
    @State private var selectedImage: UIImage? = nil
    @State private var isUploadingImage: Bool = false
    @State private var selectedViewerImageUrl: String? = nil
    @State private var activeReactionMessageId: String? = nil

    // Ticket Action Dialogs & Sheets
    @State private var showRatingModal: Bool = false
    @State private var showHandoverModal: Bool = false
    @State private var showResolveModal: Bool = false
    @State private var showCloseConfirmAlert: Bool = false
    @State private var isSubmittingAction: Bool = false

    // Rating states
    @State private var ratingStars: Int = 5
    @State private var ratingComment: String = ""

    // Handover states
    @State private var handoverToType: String = "TECHNICIAN" // TECHNICIAN or HELPDESK
    @State private var handoverTargetEmail: String = ""
    @State private var handoverTargetName: String = ""
    @State private var handoverReason: String = ""
    @State private var handoverSearch: String = ""

    // Resolve states
    @State private var resolveNote: String = ""

    var isCreator: Bool {
        let cleanMe = firebase.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanCreator = ticket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !cleanMe.isEmpty && cleanMe == cleanCreator
    }

    var canManageTicket: Bool {
        firebase.isAdmin || firebase.isHelpDesk || firebase.isTechnician
    }

    var canCloseTicket: Bool {
        firebase.isAdmin || firebase.isHelpDesk
    }

    var sourceBadge: (text: String, icon: String, fg: Color, bg: Color) {
        let src = ticket.source.uppercased()
        switch src {
        case "EMAIL":
            return ("Email M365", "envelope.fill", Color(hex: "#6D28D9"), Color(hex: "#EDE9FE"))
        case "ZALO":
            return ("Zalo OA", "bubble.left.and.bubble.right.fill", Color(hex: "#0284C7"), Color(hex: "#E0F2FE"))
        case "WEB":
            return ("Web Portal", "globe", Color(hex: "#0D9488"), Color(hex: "#CCFBF1"))
        case "PHONE":
            return ("Hotline", "phone.fill", Color(hex: "#16A34A"), Color(hex: "#DCFCE7"))
        default:
            return ("App Di động", "iphone", Color.appPrimaryPink, Color(hex: "#FCE7F3"))
        }
    }

    var statusBadge: (text: String, fg: Color, bg: Color) {
        switch currentStatus {
        case "OPEN":
            return ("Chờ tiếp nhận", Color(hex: "#D97706"), Color(hex: "#FEF3C7"))
        case "IN_PROGRESS":
            return ("Đang xử lý", Color(hex: "#2563EB"), Color(hex: "#DBEAFE"))
        case "RESOLVED":
            return ("Đã xử lý xong", Color(hex: "#4F46E5"), Color(hex: "#EEF2FF"))
        case "CLOSED":
            return ("Đã đóng", Color(hex: "#16A34A"), Color(hex: "#DCFCE7"))
        default:
            return (currentStatus, Color.secondary, Color(hex: "#F1F5F9"))
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Ticket Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("#\(ticket.id)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)

                        // Omni-channel source badge
                        let src = sourceBadge
                        HStack(spacing: 3) {
                            Image(systemName: src.icon)
                                .font(.system(size: 9))
                            Text(src.text)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(src.fg)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(src.bg)
                        .cornerRadius(4)

                        Spacer()

                        // Status badge
                        let st = statusBadge
                        Text(st.text)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(st.fg)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(st.bg)
                            .cornerRadius(6)

                        Text(ticket.priority)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#DC2626"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FEE2E2"))
                            .cornerRadius(4)
                    }

                    Text(ticket.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(ticket.unit.isEmpty ? "Co.opmart" : ticket.unit)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if !assignedKtvName.isEmpty && assignedKtvName != "Chưa tiếp nhận" {
                            Text("•")
                                .foregroundColor(.secondary)
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text(assignedKtvName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                        }

                        Spacer()

                        Button(action: { showLiveTracking = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "map.fill")
                                Text("Lộ trình GPS")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appSecondaryDarkBlue.opacity(0.12))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)

                // ACTION STRIP (Dành cho KTV, HelpDesk, Admin, Người tạo)
                actionStripView

                // CSAT RATING BANNER (Khi đã xử lý xong hoặc người tạo chưa đánh giá)
                if currentStatus == "RESOLVED" && isCreator && currentRating == 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#F59E0B"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KTV đã xử lý xong sự cố!")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#92400E"))
                            Text("Mời bạn đánh giá chất lượng phục vụ 1-5 sao.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#B45309"))
                        }
                        Spacer()
                        Button(action: { showRatingModal = true }) {
                            Text("Đánh giá ngay")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "#F59E0B"))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FFFBEB"))
                    .overlay(Rectangle().fill(Color(hex: "#FDE68A")).frame(height: 1), alignment: .bottom)
                }

                // Rated Summary Banner
                if currentRating > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Color(hex: "#16A34A"))
                        Text("Khách hàng đã đánh giá:")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Color(hex: "#166534"))
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { s in
                                Image(systemName: s <= currentRating ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#F59E0B"))
                            }
                        }
                        if !currentFeedback.isEmpty {
                            Text("• \(currentFeedback)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#15803D"))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#F0FDF4"))
                    .overlay(Rectangle().fill(Color(hex: "#BBF7D0")).frame(height: 1), alignment: .bottom)
                }

                // Danh sách tin nhắn thật từ Firestore subcollection
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if firebase.isLoadingMessages {
                            ProgressView("Đang tải tin nhắn từ Firestore...")
                                .padding(20)
                        } else if firebase.activeChatMessages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color.appTextMuted)
                                Text("Chưa có tin nhắn trao đổi. Hãy gửi tin nhắn đầu tiên!")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            .padding(.top, 40)
                        } else {
                            ForEach(firebase.activeChatMessages) { msg in
                                chatBubble(for: msg)
                            }
                        }
                    }
                    .padding(16)
                }

                if isUploadingImage {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Đang tải ảnh lên Cloudinary...")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                // Floating Reaction Bar khi đang chọn message
                if let msgId = activeReactionMessageId {
                    HStack {
                        Spacer()
                        ZaloReactionBar { emoji in
                            Task {
                                _ = await firebase.addReaction(ticketId: ticket.id, messageId: msgId, emoji: emoji)
                                activeReactionMessageId = nil
                            }
                        }
                        Spacer()
                    }
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Input bar (nếu ticket chưa đóng hoặc Admin/HelpDesk)
                if currentStatus != "CLOSED" || firebase.isAdmin || firebase.isHelpDesk {
                    HStack(spacing: 8) {
                        // Attachment button
                        Button(action: { showAttachmentActionSheet = true }) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                        }

                        // Zalo icon picker button
                        Button(action: { showIconPicker = true }) {
                            Image(systemName: "face.smiling.fill")
                                .font(.system(size: 26))
                                .foregroundColor(Color.orange)
                        }

                        TextField("Nhập nội dung trao đổi sự cố...", text: $messageInput)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))

                        Button(action: {
                            let text = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !text.isEmpty {
                                isSending = true
                                messageInput = ""
                                Task {
                                    _ = await firebase.sendMessage(ticketId: ticket.id, text: text)
                                    isSending = false
                                }
                            }
                        }) {
                            if isSending {
                                ProgressView()
                                    .frame(width: 38, height: 38)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(Color.appPrimaryPink)
                                    .clipShape(Circle())
                            }
                        }
                        .disabled(isSending || messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(10)
                    .background(Color.white)
                } else {
                    // Closed Notice
                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color.gray)
                        Text("Yêu cầu hỗ trợ này đã được đóng hoàn tất.")
                            .font(.system(size: 12))
                            .foregroundColor(Color.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#F1F5F9"))
                }
            }
            .navigationTitle("Trao Đổi Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                currentStatus = ticket.status
                assignedKtvName = ticket.assignedKtv
                currentRating = ticket.rating
                currentFeedback = ticket.feedback
                Task {
                    await firebase.loadMessages(for: ticket.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showLiveTracking = true }) {
                        Image(systemName: "map.fill")
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                }
            }
            .sheet(isPresented: $showLiveTracking) {
                LiveTrackingMapView(ticket: ticket, companyId: firebase.companyId)
            }
            .sheet(isPresented: $showIconPicker) {
                ZaloIconPickerSheet { iconCode in
                    messageInput += iconCode
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerModal(selectedImage: $selectedImage, sourceType: pickerSourceType)
            }
            .sheet(isPresented: $showRatingModal) {
                csatRatingSheet
            }
            .sheet(isPresented: $showHandoverModal) {
                handoverSheet
            }
            .sheet(isPresented: $showResolveModal) {
                resolveSheet
            }
            .alert(isPresented: $showCloseConfirmAlert) {
                Alert(
                    title: Text("Nghiệm thu & Đóng phiếu"),
                    message: Text("Xác nhận sự cố đã được khắc phục hoàn toàn và đóng yêu cầu hỗ trợ?"),
                    primaryButton: .default(Text("Đóng phiếu")) {
                        Task {
                            isSubmittingAction = true
                            let ok = await firebase.closeTicket(ticketId: ticket.id)
                            if ok {
                                currentStatus = "CLOSED"
                            }
                            isSubmittingAction = false
                        }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
            .sheet(isPresented: Binding(
                get: { selectedViewerImageUrl != nil },
                set: { if !$0 { selectedViewerImageUrl = nil } }
            )) {
                if let url = selectedViewerImageUrl {
                    MediaViewerSheet(imageUrl: url, title: "Hình ảnh sự cố #\(ticket.id)")
                }
            }
            .confirmationDialog("Đính kèm hình ảnh biên bản", isPresented: $showAttachmentActionSheet, titleVisibility: .visible) {
                Button("Chụp ảnh từ Camera") {
                    pickerSourceType = .camera
                    showImagePicker = true
                }
                Button("Chọn ảnh từ Thư viện") {
                    pickerSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("Hủy", role: .cancel) {}
            }
            .onChange(of: selectedImage) { img in
                if let img = img {
                    uploadAndSendImage(img)
                }
            }
        }
    }

    // MARK: - ACTION STRIP VIEW
    @ViewBuilder
    private var actionStripView: some View {
        if currentStatus != "CLOSED" && (canManageTicket || canCloseTicket) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 1. Nút Tiếp nhận (nếu OPEN)
                    if currentStatus == "OPEN" && canManageTicket {
                        Button(action: {
                            Task {
                                isSubmittingAction = true
                                let ok = await firebase.acceptTicket(ticketId: ticket.id)
                                if ok {
                                    currentStatus = "IN_PROGRESS"
                                    assignedKtvName = firebase.userName
                                }
                                isSubmittingAction = false
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Tiếp nhận")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#059669"))
                            .cornerRadius(16)
                        }
                        .disabled(isSubmittingAction)
                    }

                    // 2. Nút Báo xong (nếu IN_PROGRESS)
                    if currentStatus == "IN_PROGRESS" && canManageTicket {
                        Button(action: {
                            resolveNote = ""
                            showResolveModal = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                Text("Báo xử lý xong")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#4F46E5"))
                            .cornerRadius(16)
                        }
                    }

                    // 3. Nút Bàn giao ca (nếu OPEN hoặc IN_PROGRESS)
                    if (currentStatus == "OPEN" || currentStatus == "IN_PROGRESS") && canManageTicket {
                        Button(action: {
                            handoverReason = ""
                            handoverTargetEmail = ""
                            handoverTargetName = ""
                            handoverSearch = ""
                            showHandoverModal = true
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.swap")
                                Text("Bàn giao ca")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#92400E"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#FEF3C7"))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
                            .cornerRadius(16)
                        }
                    }

                    // 4. Nút Nghiệm thu & Đóng (Admin / HelpDesk)
                    if canCloseTicket {
                        Button(action: { showCloseConfirmAlert = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Nghiệm thu & Đóng")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#16A34A"))
                            .cornerRadius(16)
                        }
                        .disabled(isSubmittingAction)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(Color(hex: "#F8FAFC"))
            .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)
        }
    }

    // MARK: - CSAT 5-STAR RATING SHEET
    private var csatRatingSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 6) {
                    Text("ĐÁNH GIÁ CHẤT LƯỢNG PHỤC VỤ")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Sự hài lòng của bạn giúp nâng cao chất lượng hỗ trợ KTV")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 16)

                // 5 Interactive Stars
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { ratingStars = star }) {
                            Image(systemName: star <= ratingStars ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(star <= ratingStars ? Color(hex: "#F59E0B") : Color(hex: "#CBD5E1"))
                        }
                    }
                }
                .padding(.vertical, 8)

                // Satisfaction text
                Text(firebase.whenSatisfaction(ratingStars))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(ratingStars >= 4 ? Color(hex: "#15803D") : (ratingStars == 3 ? Color(hex: "#D97706") : Color(hex: "#DC2626")))

                // Quick feedback tag chips
                let quickTags = ["Xử lý rất nhanh", "Nhiệt tình", "Đúng giờ", "Chuyên môn tốt", "Hài lòng"]
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickTags, id: \.self) { tag in
                            Button(action: {
                                if ratingComment.isEmpty {
                                    ratingComment = tag
                                } else if !ratingComment.contains(tag) {
                                    ratingComment += ", " + tag
                                }
                            }) {
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "#EFF6FF"))
                                    .foregroundColor(Color(hex: "#1D4ED8"))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Comment field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ý kiến đóng góp thêm (tùy chọn):")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appTextSecondary)

                    TextEditor(text: $ratingComment)
                        .frame(height: 90)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .padding(.horizontal, 16)

                Spacer()

                // Submit Button
                Button(action: {
                    Task {
                        isSubmittingAction = true
                        let ok = await firebase.submitRating(ticketId: ticket.id, stars: ratingStars, comment: ratingComment)
                        isSubmittingAction = false
                        if ok {
                            currentRating = ratingStars
                            currentFeedback = ratingComment.isEmpty ? firebase.whenSatisfaction(ratingStars) : ratingComment
                            currentStatus = "CLOSED"
                            showRatingModal = false
                        }
                    }
                }) {
                    HStack {
                        if isSubmittingAction {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Gửi Đánh Giá & Hoàn Tất")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#059669"))
                    .cornerRadius(12)
                }
                .disabled(isSubmittingAction)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Đánh Giá Dịch Vụ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showRatingModal = false }
                }
            }
        }
    }

    // MARK: - HANDOVER SHEET
    private var handoverSheet: some View {
        NavigationView {
            VStack(spacing: 14) {
                Picker("Hình thức bàn giao", selection: $handoverToType) {
                    Text("Chuyển KTV").tag("TECHNICIAN")
                    Text("Chuyển về HelpDesk").tag("HELPDESK")
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.top, 12)

                if handoverToType == "TECHNICIAN" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chọn Kỹ thuật viên tiếp nhận (*):")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        TextField("Tìm kiếm tên hoặc email KTV...", text: $handoverSearch)
                            .padding(10)
                            .background(Color(hex: "#F1F5F9"))
                            .cornerRadius(8)

                        let cleanMe = firebase.currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let ktvCandidates = firebase.allUsersList.filter { u in
                            let r = u.role.lowercased()
                            let isTech = r.contains("kythuat") || r.contains("tech") || r.contains("ktv")
                            let isNotMe = u.email.lowercased() != cleanMe
                            let matchSearch = handoverSearch.isEmpty ||
                                              u.fullName.localizedCaseInsensitiveContains(handoverSearch) ||
                                              u.email.localizedCaseInsensitiveContains(handoverSearch)
                            return isTech && isNotMe && matchSearch
                        }

                        if ktvCandidates.isEmpty {
                            Text("Không tìm thấy KTV khác trong danh sách công ty.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray)
                                .padding(.vertical, 10)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach(ktvCandidates) { u in
                                        Button(action: {
                                            handoverTargetEmail = u.email
                                            handoverTargetName = u.fullName
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(u.fullName)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(Color.appTextPrimary)
                                                    Text(u.email)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Color.appTextSecondary)
                                                }
                                                Spacer()
                                                if handoverTargetEmail == u.email {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(Color(hex: "#059669"))
                                                }
                                            }
                                            .padding(10)
                                            .background(handoverTargetEmail == u.email ? Color(hex: "#ECFDF5") : Color.white)
                                            .cornerRadius(8)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(handoverTargetEmail == u.email ? Color(hex: "#10B981") : Color.appCardBorder, lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                    .padding(.horizontal, 16)
                } else {
                    // HelpDesk notice
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "headphones")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#D97706"))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Chuyển trả yêu cầu về HelpDesk")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#92400E"))
                            Text("Yêu cầu sẽ được chuyển về trạng thái Chờ tiếp nhận (OPEN). HelpDesk sẽ nhận được thông báo để điều phối người xử lý phù hợp.")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#B45309"))
                                .lineSpacing(2)
                        }
                    }
                    .padding(12)
                    .background(Color(hex: "#FFFBEB"))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                }

                // Mandatory Reason Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lý do bàn giao (* Bắt buộc do KTV nhập):")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    TextField("Ví dụ: Hết ca trực chiều, chuyển giao KTV ca đêm...", text: $handoverReason)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .padding(.horizontal, 16)

                Spacer()

                // Submit Button
                Button(action: {
                    Task {
                        isSubmittingAction = true
                        let ok = await firebase.handoverTicket(
                            ticketId: ticket.id,
                            toType: handoverToType,
                            targetEmail: handoverTargetEmail,
                            targetName: handoverTargetName,
                            reason: handoverReason
                        )
                        isSubmittingAction = false
                        if ok {
                            if handoverToType == "TECHNICIAN" {
                                assignedKtvName = handoverTargetName
                            } else {
                                currentStatus = "OPEN"
                                assignedKtvName = "Chưa tiếp nhận"
                            }
                            showHandoverModal = false
                        }
                    }
                }) {
                    HStack {
                        if isSubmittingAction {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.triangle.swap")
                            Text("Xác nhận Bàn Giao")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(12)
                }
                .disabled(isSubmittingAction || handoverReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (handoverToType == "TECHNICIAN" && handoverTargetEmail.isEmpty))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Bàn Giao Ca / Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showHandoverModal = false }
                }
            }
        }
    }

    // MARK: - RESOLVE SHEET
    private var resolveSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ghi chú kết quả xử lý sự cố (*):")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    TextEditor(text: $resolveNote)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                    Text("Ví dụ: Đã thay thế dây mạng CAT6, bấm lại đầu RJ45, máy POS kết nối mạng và in bill bình thường.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextMuted)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                Button(action: {
                    Task {
                        isSubmittingAction = true
                        let ok = await firebase.resolveTicket(ticketId: ticket.id, note: resolveNote)
                        isSubmittingAction = false
                        if ok {
                            currentStatus = "RESOLVED"
                            showResolveModal = false
                        }
                    }
                }) {
                    HStack {
                        if isSubmittingAction {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Xác Nhận Báo Xử Lý Xong")
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#4F46E5"))
                    .cornerRadius(12)
                }
                .disabled(isSubmittingAction || resolveNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationTitle("Báo Xử Lý Xong")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showResolveModal = false }
                }
            }
        }
    }

    @ViewBuilder
    private func chatBubble(for msg: ChatMessage) -> some View {
        let trimmed = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSingleIcon = trimmed.hasPrefix(":zalo_") && trimmed.hasSuffix(":") && trimmed.count == 9

        HStack {
            if msg.isMe { Spacer() }

            VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 4) {
                Text(msg.senderName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)

                if isSingleIcon, let icon = ZaloAssetConstants.iconMap[trimmed] {
                    AsyncImage(url: URL(string: icon.iconUrl)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().frame(width: 48, height: 48)
                        default:
                            Text("😀").font(.system(size: 32))
                        }
                    }
                    .padding(4)
                } else {
                    // Normal text bubble
                    if !msg.text.isEmpty {
                        Text(msg.text)
                            .font(.system(size: 14))
                            .foregroundColor(msg.isMe ? .white : Color.appTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(msg.isMe ? Color.appSecondaryDarkBlue : Color.white)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.appCardBorder, lineWidth: msg.isMe ? 0 : 1)
                            )
                    }
                }

                // Image preview if attached
                let imgUrl = !msg.imageUrl.isEmpty ? msg.imageUrl : (msg.text.hasPrefix("http") && (msg.text.contains("cloudinary") || msg.text.contains(".jpg") || msg.text.contains(".png")) ? msg.text : "")
                if !imgUrl.isEmpty {
                    Button(action: {
                        selectedViewerImageUrl = imgUrl
                    }) {
                        AsyncImage(url: URL(string: imgUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 140, height: 100)
                                    .background(Color.gray.opacity(0.1))
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 160, height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                            default:
                                Image(systemName: "photo")
                                    .frame(width: 140, height: 100)
                                    .background(Color.gray.opacity(0.1))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Reaction summary pills
                if !msg.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(msg.reactions.keys), id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 11))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }

                HStack(spacing: 6) {
                    Text(msg.time)
                        .font(.system(size: 9))
                        .foregroundColor(Color.appTextMuted)

                    Button(action: {
                        activeReactionMessageId = (activeReactionMessageId == msg.id) ? nil : msg.id
                    }) {
                        Image(systemName: "face.smiling")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !msg.isMe { Spacer() }
        }
    }

    private func uploadAndSendImage(_ img: UIImage) {
        isUploadingImage = true
        Task {
            if let uploadedUrl = await CloudinaryService.uploadImage(img, folder: "support_tickets") {
                _ = await firebase.sendMessage(ticketId: ticket.id, text: "[Hình ảnh đính kèm]", imageUrl: uploadedUrl)
            }
            selectedImage = nil
            isUploadingImage = false
        }
    }
}

struct EditNameModal: View {
    @EnvironmentObject var firebase: FirebaseService
    @Binding var isPresented: Bool
    @State private var input: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("HỌ VÀ TÊN HIỂN THỊ (LƯU LÊN FIRESTORE)")) {
                    TextField("Nhập họ và tên mới", text: $input)
                }
            }
            .navigationTitle("Đổi Họ Tên")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { input = firebase.userName }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !clean.isEmpty {
                            isSaving = true
                            Task {
                                _ = await firebase.updateProfile(newName: clean, newPhone: firebase.userPhone)
                                isSaving = false
                                isPresented = false
                            }
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .disabled(isSaving || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct EditPhoneModal: View {
    @EnvironmentObject var firebase: FirebaseService
    @Binding var isPresented: Bool
    @State private var input: String = ""
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("SỐ ĐIỆN THOẠI CỦA BẠN (LƯU LÊN FIRESTORE)")) {
                    TextField("Nhập số điện thoại (VD: 0908123456)", text: $input)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Đổi Số Điện Thoại")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { input = firebase.userPhone }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { isPresented = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        let clean = input.trimmingCharacters(in: .whitespacesAndNewlines)
                        isSaving = true
                        Task {
                            _ = await firebase.updateProfile(newName: firebase.userName, newPhone: clean)
                            isSaving = false
                            isPresented = false
                        }
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .disabled(isSaving)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
