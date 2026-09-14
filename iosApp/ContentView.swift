import SwiftUI
import Combine

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
}

struct ChatMessage: Identifiable, Hashable, Sendable {
    var id: String
    var senderName: String
    var senderEmail: String
    var text: String
    var time: String
    var isMe: Bool
}

// MARK: - 3. FIREBASE SERVICE ENGINE (Native Swift REST & Firestore Sync)
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    let apiKey = "AIzaSyAehFfYkaZZnaOw3zXQNxokB21D2XcUG6A"
    let projectId = "qltb-81f4c"

    @Published var isLoggedIn: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authError: String? = nil

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

    // --- A. ĐĂNG NHẬP (FIREBASE AUTH) ---
    func signIn(email: String, pass: String) async -> Bool {
        await MainActor.run {
            self.isAuthenticating = true
            self.authError = nil
        }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

                    await MainActor.run {
                        self.currentUserEmail = cleanEmail
                        self.currentUserIdToken = idToken
                        self.currentRefreshToken = refreshToken
                        self.isLoggedIn = true
                        self.isAuthenticating = false

                        // Lưu Session vào UserDefaults
                        UserDefaults.standard.set(cleanEmail, forKey: "fb_user_email")
                        UserDefaults.standard.set(idToken, forKey: "fb_id_token")
                        UserDefaults.standard.set(refreshToken, forKey: "fb_refresh_token")
                    }

                    // Tải dữ liệu người dùng & Firestore
                    await self.loadUserProfile()
                    await self.loadDevices()
                    await self.loadTickets()
                    await MainActor.run { self.startRealtimePolling() }

                    return true
                }
            } else {
                var errDesc = "Đăng nhập thất bại. Vui lòng kiểm tra email và mật khẩu."
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let msg = errorObj["message"] as? String {
                    if msg.contains("INVALID_LOGIN_CREDENTIALS") || msg.contains("INVALID_PASSWORD") {
                        errDesc = "Mật khẩu không chính xác."
                    } else if msg.contains("EMAIL_NOT_FOUND") {
                        errDesc = "Tài khoản email này chưa được đăng ký."
                    } else if msg.contains("USER_DISABLED") {
                        errDesc = "Tài khoản đã bị tạm khóa."
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

    // --- C. ĐỒNG BỘ HỒ SƠ NGƯỜI DÙNG TỪ FIRESTORE ---
    func loadUserProfile() async {
        let cleanEmail = currentUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if cleanEmail.isEmpty { return }

        let userDocUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/users/\(cleanEmail)"
        guard let url = URL(string: userDocUrl) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {

                    let fn = parseString(fields, "fullName")
                    let n = parseString(fields, "name")
                    let r = parseString(fields, "role")
                    let dv = parseString(fields, "donVi")
                    let dp = parseString(fields, "phongBan")
                    let ph = parseString(fields, "phone").isEmpty ? parseString(fields, "phoneNumber") : parseString(fields, "phone")

                    await MainActor.run {
                        self.userName = !fn.isEmpty ? fn : (!n.isEmpty ? n : cleanEmail)
                        self.userRole = self.formatRoleTitle(r)
                        self.userDonVi = !dv.isEmpty ? dv : "Co.opmart Cần Thơ"
                        self.userDept = !dp.isEmpty ? dp : "Phòng Công nghệ thông tin"
                        self.userPhone = ph

                        // Lưu cache local
                        UserDefaults.standard.set(self.userName, forKey: "cache_name")
                        UserDefaults.standard.set(self.userRole, forKey: "cache_role")
                        UserDefaults.standard.set(self.userDonVi, forKey: "cache_donvi")
                        UserDefaults.standard.set(self.userDept, forKey: "cache_dept")
                        UserDefaults.standard.set(self.userPhone, forKey: "cache_phone")
                    }
                }
            }
        } catch {}
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
                            iconName: self.iconForCategory(category)
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

                        let t = SupportTicket(
                            id: docId,
                            title: !subject.isEmpty ? subject : "Sự cố kỹ thuật",
                            unit: !donVi.isEmpty ? donVi : "Co.opmart",
                            priority: self.formatPriority(priority),
                            status: !status.isEmpty ? status.uppercased() : "OPEN",
                            slaRemaining: status == "CLOSED" ? "Đã đóng" : "Đang xử lý SLA",
                            assignedKtv: !ktv.isEmpty ? ktv : "Chưa tiếp nhận",
                            creatorEmail: creator,
                            createdAt: "Vừa xong",
                            lastMessage: lastMsg
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

                        let m = ChatMessage(
                            id: docId,
                            senderName: !sender.isEmpty ? sender : "KTV",
                            senderEmail: senderEmail,
                            text: text,
                            time: dateStr,
                            isMe: isMe
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
    func sendMessage(ticketId: String, text: String) async -> Bool {
        let endpoint = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/companies/\(companyId)/support_tickets/\(ticketId)/messages"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "message": ["stringValue": text],
                "senderName": ["stringValue": userName],
                "senderEmail": ["stringValue": currentUserEmail],
                "departmentId": ["stringValue": userDept],
                "donVi": ["stringValue": userDonVi],
                "timestamp": ["integerValue": "\(nowMs)"]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                // Cập nhật lại tin nhắn hiển thị
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
                MainAppView()
                    .environmentObject(firebase)
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
struct MainAppView: View {
    @EnvironmentObject var firebase: FirebaseService

    @State private var selectedTab: Int = 0
    @State private var showDrawer: Bool = false
    @State private var showNotifications: Bool = false
    @State private var showGuide: Bool = false
    @State private var showLogoutDialog: Bool = false
    @State private var showAddDeviceSheet: Bool = false
    @State private var showScannerSheet: Bool = false
    @State private var showTicketDetail: SupportTicket? = nil
    @State private var showQuickSupportSheet: Bool = false

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
                            onOpenGuide: { showGuide = true },
                            onOpenNotifications: { showNotifications = true },
                            onOpenLogout: { showLogoutDialog = true },
                            onNavigateTab: { tab in selectedTab = tab },
                            onScanQr: { showScannerSheet = true },
                            onAddDevice: { showAddDeviceSheet = true }
                        )
                    case 1:
                        DeviceListView(
                            onOpenDrawer: { showDrawer = true },
                            onAddDevice: { showAddDeviceSheet = true },
                            onScanDevice: { showScannerSheet = true }
                        )
                    case 2:
                        SupportHubView(
                            onOpenDrawer: { showDrawer = true },
                            onSelectTicket: { ticket in showTicketDetail = ticket },
                            onCreateTicket: { showQuickSupportSheet = true }
                        )
                    case 3:
                        SettingsView(
                            onOpenDrawer: { showDrawer = true },
                            onLogout: { showLogoutDialog = true }
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
                    Button(action: { showQuickSupportSheet = true }) {
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
                            if route == "home" { selectedTab = 0 }
                            else if route == "devices" { selectedTab = 1 }
                            else if route == "support" { selectedTab = 2 }
                            else if route == "settings" { selectedTab = 3 }
                        },
                        onLogout: {
                            showDrawer = false
                            showLogoutDialog = true
                        }
                    )
                    .frame(width: 300)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showScannerSheet) {
            ScannerMockView(onDismiss: { showScannerSheet = false })
        }
        .sheet(isPresented: $showAddDeviceSheet) {
            AddDeviceModalView(onDismiss: { showAddDeviceSheet = false })
        }
        .sheet(isPresented: $showNotifications) {
            NotificationListView(onDismiss: { showNotifications = false })
        }
        .sheet(isPresented: $showGuide) {
            GuideTourModalView(onDismiss: { showGuide = false })
        }
        .sheet(isPresented: $showQuickSupportSheet) {
            QuickSupportModalView(onDismiss: { showQuickSupportSheet = false })
        }
        .sheet(item: $showTicketDetail) { ticket in
            TicketChatDetailView(ticket: ticket, onDismiss: { showTicketDetail = nil })
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
                        onSettings: { onNavigateTab(3) }
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
    let onSettings: () -> Void

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
                QuickCardItem(title: "Chấm công", icon: "clock.fill", color: Color(hex: "#059669"), bgColor: Color(hex: "#D1FAE5"), action: {})
                QuickCardItem(title: "Phân ca", icon: "calendar.badge.clock", color: Color(hex: "#7C3AED"), bgColor: Color(hex: "#EDE9FE"), action: {})
                QuickCardItem(title: "Thống kê", icon: "chart.bar.fill", color: Color(hex: "#D97706"), bgColor: Color(hex: "#FEF3C7"), action: {})
                QuickCardItem(title: "In tem", icon: "printer.fill", color: Color(hex: "#4F46E5"), bgColor: Color(hex: "#EEF2FF"), action: onSettings)
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

    @State private var searchText: String = ""
    @State private var selectedFilter: String = "Tất cả"
    let filterOptions = ["Tất cả", "Đang sử dụng", "Mới", "Sửa chữa", "Hỏng"]

    var filteredDevices: [DeviceItem] {
        firebase.devices.filter { item in
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
                            DeviceCardItemView(device: item)
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
}

// MARK: - 13. SUPPORT HUB VIEW (Live Firestore)
struct SupportHubView: View {
    @EnvironmentObject var firebase: FirebaseService

    let onOpenDrawer: () -> Void
    let onSelectTicket: (SupportTicket) -> Void
    let onCreateTicket: () -> Void

    @State private var selectedStatus: String = "OPEN"

    var filteredTickets: [SupportTicket] {
        if selectedStatus == "ALL" { return firebase.tickets }
        return firebase.tickets.filter { $0.status == selectedStatus }
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
            HStack(spacing: 0) {
                TicketTabButton(title: "Chờ tiếp nhận", count: firebase.tickets.filter { $0.status == "OPEN" }.count, isSelected: selectedStatus == "OPEN") {
                    selectedStatus = "OPEN"
                }
                TicketTabButton(title: "Đang xử lý", count: firebase.tickets.filter { $0.status == "IN_PROGRESS" }.count, isSelected: selectedStatus == "IN_PROGRESS") {
                    selectedStatus = "IN_PROGRESS"
                }
                TicketTabButton(title: "Đã xong", count: firebase.tickets.filter { $0.status == "CLOSED" || $0.status == "RESOLVED" }.count, isSelected: selectedStatus == "CLOSED") {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(ticket.priority)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(priorityColor.opacity(0.12))
                    .cornerRadius(4)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                    Text(ticket.slaRemaining)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(priorityColor)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                AppLogoImage(size: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(firebase.userName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(firebase.currentUserEmail)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                Text("🏬 \(firebase.userDonVi)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSecondaryDarkBlue)

            ScrollView {
                VStack(spacing: 4) {
                    DrawerItem(title: "Trang chủ", icon: "house.fill", action: { onSelectRoute("home") })
                    DrawerItem(title: "Quản lý thiết bị", icon: "laptopcomputer", action: { onSelectRoute("devices") })
                    DrawerItem(title: "Trung tâm Hỗ trợ Kỹ thuật", icon: "headphones", action: { onSelectRoute("support") })
                    DrawerItem(title: "Cấu hình & Ngoại vi", icon: "gearshape.fill", action: { onSelectRoute("settings") })
                    Divider().padding(.vertical, 8)
                    DrawerItem(title: "Đăng xuất", icon: "rectangle.portrait.and.arrow.right", isDestructive: true, action: onLogout)
                }
                .padding(.vertical, 12)
            }
        }
        .background(Color.white)
        .ignoresSafeArea()
    }
}

struct DrawerItem: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isDestructive ? Color(hex: "#DC2626") : Color.appSecondaryDarkBlue)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isDestructive ? Color(hex: "#DC2626") : Color.appTextPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
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

struct TicketChatDetailView: View {
    @EnvironmentObject var firebase: FirebaseService
    let ticket: SupportTicket
    let onDismiss: () -> Void

    @State private var messageInput: String = ""
    @State private var isSending: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Ticket Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ticket.id)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                        Spacer()
                        Text(ticket.priority)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#DC2626"))
                    }
                    Text(ticket.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
                .padding(14)
                .background(Color.white)
                .overlay(Rectangle().fill(Color.appCardBorder).frame(height: 1), alignment: .bottom)

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
                                HStack {
                                    if msg.isMe { Spacer() }

                                    VStack(alignment: msg.isMe ? .trailing : .leading, spacing: 3) {
                                        Text(msg.senderName)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.appTextSecondary)

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

                                        Text(msg.time)
                                            .font(.system(size: 9))
                                            .foregroundColor(Color.appTextMuted)
                                    }

                                    if !msg.isMe { Spacer() }
                                }
                            }
                        }
                    }
                    .padding(16)
                }

                // Input bar
                HStack(spacing: 10) {
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
                                .frame(width: 40, height: 40)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.appPrimaryPink)
                                .clipShape(Circle())
                        }
                    }
                    .disabled(isSending || messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(Color.white)
            }
            .navigationTitle("Trao Đổi Sự Cố")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await firebase.loadMessages(for: ticket.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                }
            }
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
