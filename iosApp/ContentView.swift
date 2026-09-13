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
struct DeviceItem: Identifiable, Hashable {
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

struct SupportTicket: Identifiable, Hashable {
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

struct ChatMessage: Identifiable, Hashable {
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

                await MainActor.run {
                    self.authError = errDesc
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

                    await MainActor.run {
                        self.devices = parsedList
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

                    await MainActor.run {
                        self.tickets = parsedTickets
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

                    await MainActor.run {
                        self.activeChatMessages = msgs
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
    }
}

// MARK: - 5. LOGIN VIEW (Màn hình Đăng nhập Co.opmart)
struct LoginScreenView: View {
    @EnvironmentObject var firebase: FirebaseService
    @State private var emailInput: String = "admin@sgcoop.com"
    @State private var passInput: String = "Admin123"

    var body: some View {
        ZStack {
            Color.appSecondaryDarkBlue.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 84, height: 84)
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)

                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }

                    Text("QLTB SGCOOP")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)

                    Text("HỆ THỐNG QUẢN LÝ THIẾT BỊ & ĐIỀU PHỐI KTV")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)

                // Khung nhập liệu (Card Trắng)
                VStack(spacing: 18) {
                    Text("Đăng nhập tài khoản")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let err = firebase.authError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                            Text(err)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.statusBroken)
                        .cornerRadius(8)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email công việc")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextSecondary)

                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .frame(width: 20)
                            TextField("VD: admin@sgcoop.com", text: $emailInput)
                                .font(.system(size: 14))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        .padding(12)
                        .background(Color.appBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mật khẩu")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextSecondary)

                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .frame(width: 20)
                            SecureField("Nhập mật khẩu", text: $passInput)
                                .font(.system(size: 14))
                        }
                        .padding(12)
                        .background(Color.appBackground)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // Nút Đăng nhập chính
                    Button(action: {
                        Task {
                            _ = await firebase.signIn(email: emailInput, pass: passInput)
                        }
                    }) {
                        HStack {
                            if firebase.isAuthenticating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Đăng nhập hệ thống")
                                    .font(.system(size: 15, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(12)
                        .shadow(color: Color.appPrimaryPink.opacity(0.4), radius: 6, x: 0, y: 3)
                    }
                    .disabled(firebase.isAuthenticating || emailInput.isEmpty || passInput.isEmpty)

                    // Phím tắt tài khoản mẫu
                    VStack(spacing: 8) {
                        Text("HOẶC ĐĂNG NHẬP NHANH BẰNG TÀI KHOẢN MẪU:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.appTextMuted)

                        HStack(spacing: 10) {
                            Button("Admin") {
                                emailInput = "admin@sgcoop.com"
                                passInput = "Admin123"
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.appSecondaryDarkBlue.opacity(0.1))
                            .cornerRadius(8)

                            Button("KTV Cần Thơ") {
                                emailInput = "lethid@sgcoop.com"
                                passInput = "123456"
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.appSecondaryDarkBlue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(24)
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 20)
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)

                Spacer()

                Text("Saigon Co.op • Enterprise Device Management")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.appPrimaryPink)
                            .frame(width: 28, height: 28)
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }

                    Text("Trang chủ")
                        .font(.system(size: 19, weight: .bold))
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
                ZStack {
                    Circle().fill(Color.white).frame(width: 54, height: 54)
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

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
                    TextField("Tên thiết bị (VD: Máy POS Sunmi)", text: $name)
                }

                Section(header: Text("PHÂN LOẠI & ĐƠN VỊ")) {
                    Picker("Danh mục", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Tình trạng", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    TextField("Đơn vị sử dụng", text: $unit)
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
                    Picker("Mức độ ưu tiên", selection: $priority) {
                        Text("P1 - Khẩn cấp (SLA 30p)").tag("URGENT")
                        Text("P2 - Cao (SLA 2h)").tag("HIGH")
                        Text("P3 - Bình thường (SLA 8h)").tag("NORMAL")
                    }
                    TextField("Địa điểm / Quầy xảy ra sự cố", text: $unit)
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
