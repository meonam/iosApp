import SwiftUI
import UIKit
import UserNotifications

// MARK: - HOME VIEW MODEL (ĐỒNG BỘ 1:1 VỚI HOMESCREEN.KT TRÊN ANDROID)
@MainActor
public class HomeViewModel: ObservableObject {
    @Published public var user: User
    @Published public var companyId: String
    @Published public var idToken: String

    @Published public var devices: [ThietBi] = []
    @Published public var totalDevicesCount: Int = 0
    @Published public var openTicketsCount: Int = 0
    @Published public var pendingStaffCount: Int = 0
    @Published public var unreadNotificationCount: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var isUploadingAvatar: Bool = false

    // Cấu hình Banner chạy chữ doanh nghiệp (đồng bộ 1:1 theo Android NotificationHelper & MainActivity)
    @Published public var isCompanyBannerActive: Bool = false
    @Published public var companyBannerText: String = ""
    @Published public var companyBannerType: String = "INFO"

    // Cấu hình tính năng phân quyền Helpdesk
    @Published public var allowHelpdeskUserManagement: Bool = false

    // Cấu hình Bật/Tắt module Quản lý thiết bị (đồng bộ Web/Desktop/Android/iOS)
    @Published public var enableDeviceManagement: Bool = true

    // Modal đổi mật khẩu
    @Published public var showChangePasswordModal: Bool = false
    @Published public var showOverflowMenu: Bool = false

    private var syncTimer: Timer? = nil

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId.isEmpty ? "SGCOOP" : companyId
        self.idToken = idToken
    }

    deinit {
        syncTimer?.invalidate()
    }

    public func startRealtimeSync() {
        stopRealtimeSync()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.fetchUnreadNotifications()
                await self.fetchSystemToggleConfig()
            }
        }
    }

    public func stopRealtimeSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - TẢI TOÀN BỘ DỮ LIỆU DASHBOARD TRANG CHỦ
    public func loadDashboardData() {
        isLoading = true
        Task {
            await fetchUserProfileRealtime()
            await fetchCompanyBanner()
            await fetchSystemToggleConfig()
            await fetchGlobalControls()
            if self.enableDeviceManagement {
                await fetchDevices()
            }
            await fetchOpenTickets()
            await fetchUnreadNotifications()
            self.isLoading = false
            self.startRealtimeSync()
        }
    }

    // MARK: - TẢI CẤU HÌNH BANNER DOANH NGHIỆP
    public func fetchCompanyBanner() async {
        guard !companyId.isEmpty else { return }
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            return
        }

        let active = DatabaseHelper.getBool(fields["isBannerActive"] as? [String: Any])
        let text = DatabaseHelper.getString(fields["bannerText"] as? [String: Any])
        let type = DatabaseHelper.getString(fields["bannerType"] as? [String: Any])
        let devMgmt = DatabaseHelper.getBool(fields["enableDeviceManagement"] as? [String: Any], defaultValue: true)

        self.isCompanyBannerActive = active
        self.companyBannerText = text
        self.companyBannerType = type.isEmpty ? "INFO" : type
        self.enableDeviceManagement = devMgmt
    }

    // MARK: - TẢI CẤU HÌNH PHÂN QUYỀN HELPDESK (SYSTEM_TOGGLE_CONFIG)
    public func fetchSystemToggleConfig() async {
        guard !companyId.isEmpty else { return }
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/system_config/system_toggle_config"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            self.allowHelpdeskUserManagement = false
            return
        }

        self.allowHelpdeskUserManagement = DatabaseHelper.getBool(fields["allowHelpdeskUserManagement"] as? [String: Any])
        if let devToggle = fields["enableDeviceManagement"] as? [String: Any] {
            let toggleVal = DatabaseHelper.getBool(devToggle, defaultValue: true)
            if !toggleVal {
                self.enableDeviceManagement = false
            }
        }
    }

    // MARK: - TẢI CẤU HÌNH ĐIỀU KHIỂN TOÀN CẦU (GLOBAL_CONTROLS)
    public func fetchGlobalControls() async {
        let urlStr = "\(ServerConfig.documentsBaseUrl)/system_config/global_controls"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            return
        }

        if let devToggle = fields["enableDeviceManagement"] as? [String: Any] {
            let globalDev = DatabaseHelper.getBool(devToggle, defaultValue: true)
            if !globalDev {
                self.enableDeviceManagement = false
            }
        }
    }

    // MARK: - CẬP NHẬT BANNER DOANH NGHIỆP
    public func updateCompanyBanner(text: String, type: String = "INFO", isActive: Bool = true) async throws {
        let comp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !comp.isEmpty else { return }

        let cleanText = text.replacingOccurrences(of: "\r\n", with: "  •  ")
            .replacingOccurrences(of: "\n", with: "  •  ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(comp)?updateMask.fieldPaths=bannerText&updateMask.fieldPaths=bannerType&updateMask.fieldPaths=isBannerActive&updateMask.fieldPaths=bannerUpdatedAt"
        guard let url = URL(string: urlStr) else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "bannerText": ["stringValue": cleanText],
                "bannerType": ["stringValue": type],
                "isBannerActive": ["booleanValue": isActive],
                "bannerUpdatedAt": ["integerValue": String(now)]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = jsonData

        if let (_, response) = await DatabaseHelper.executeSafeRequest(request),
           (200...299).contains(response.statusCode) {
            await MainActor.run {
                self.companyBannerText = cleanText
                self.companyBannerType = type
                self.isCompanyBannerActive = isActive
            }
        }
    }

    // MARK: - 1. TẢI HỒ SƠ NGƯỜI DÙNG MỚI NHẤT TỪ FIRESTORE
    public func fetchUserProfileRealtime() async {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty else { return }

        let comp = companyId.isEmpty ? "SGCOOP" : companyId
        let urls = [
            "\(ServerConfig.documentsBaseUrl)/companies/\(comp)/users/\(cleanEmail)",
            "\(ServerConfig.documentsBaseUrl)/users/\(cleanEmail)"
        ]

        for urlStr in urls {
            guard let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }

            guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                continue
            }

            let newName = DatabaseHelper.getFirstNonEmptyString(fields, keys: ["fullName", "name", "hoTen"])
            if !newName.isEmpty { self.user.fullName = newName }

            let resolvedPhone = DatabaseHelper.resolvePhone(fields)
            if !resolvedPhone.isEmpty { self.user.phone = resolvedPhone }

            let newRole = DatabaseHelper.getString(fields["role"] as? [String: Any])
            if !newRole.isEmpty { self.user.role = newRole }

            let newDept = DatabaseHelper.getString(fields["departmentId"] as? [String: Any])
            let altDept = DatabaseHelper.getString(fields["phongBan"] as? [String: Any])
            if !newDept.isEmpty { self.user.departmentId = newDept }
            else if !altDept.isEmpty { self.user.departmentId = altDept }

            let newDonVi = DatabaseHelper.getString(fields["donVi"] as? [String: Any])
            let altDonVi = DatabaseHelper.getString(fields["tenDonVi"] as? [String: Any])
            let unitId = DatabaseHelper.getString(fields["unitId"] as? [String: Any])
            var donViVal = !newDonVi.isEmpty ? newDonVi : altDonVi
            if !unitId.isEmpty && !donViVal.isEmpty && donViVal != unitId {
                if !donViVal.contains(" - ") && !donViVal.hasPrefix(unitId) {
                    donViVal = "\(unitId) - \(donViVal)"
                }
            } else if !unitId.isEmpty && donViVal.isEmpty {
                donViVal = unitId
            }
            if !donViVal.isEmpty { self.user.donVi = donViVal }

            let newAvatar = DatabaseHelper.getFirstNonEmptyString(fields, keys: ["profileImageUrl", "avatarUrl", "photoUrl"])
            if !newAvatar.isEmpty { self.user.avatarUrl = newAvatar }

            let newToNghiepVu = DatabaseHelper.getString(fields["toNghiepVu"] as? [String: Any])
            if !newToNghiepVu.isEmpty { self.user.toNghiepVu = newToNghiepVu }

            break
        }
    }

    // MARK: - 2. TẢI DANH SÁCH THIẾT BỊ
    private func fetchDevices() async {
        let isFullAccess = user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isWarehouse
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/devices?pageSize=100"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return
        }

        let parsedDevices: [ThietBi] = documents.compactMap { doc in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let id = name.components(separatedBy: "/").last ?? ""
            return ThietBi(
                id: id,
                ten: DatabaseHelper.getString(fields["ten"] as? [String: Any]),
                tenDonVi: DatabaseHelper.getString(fields["tenDonVi"] as? [String: Any]),
                trangThai: DatabaseHelper.getString(fields["trangThai"] as? [String: Any]),
                createdAt: DatabaseHelper.getInt64(fields["createdAt"] as? [String: Any]),
                role: DatabaseHelper.getString(fields["role"] as? [String: Any]),
                loai: DatabaseHelper.getString(fields["loai"] as? [String: Any]),
                phongBan: DatabaseHelper.getString(fields["phongBan"] as? [String: Any]),
                moTa: DatabaseHelper.getString(fields["moTa"] as? [String: Any]),
                createdBy: DatabaseHelper.getString(fields["createdBy"] as? [String: Any]),
                companyId: DatabaseHelper.getString(fields["companyId"] as? [String: Any]),
                synced: true,
                donViMuon: DatabaseHelper.getString(fields["donViMuon"] as? [String: Any]),
                phongBanMuon: DatabaseHelper.getString(fields["phongBanMuon"] as? [String: Any]),
                nguoiMuon: DatabaseHelper.getString(fields["nguoiMuon"] as? [String: Any]),
                ngayMuon: DatabaseHelper.getString(fields["ngayMuon"] as? [String: Any]),
                ngayHenTra: DatabaseHelper.getString(fields["ngayHenTra"] as? [String: Any])
            )
        }

        self.devices = parsedDevices

        if isFullAccess {
            self.totalDevicesCount = parsedDevices.count
        } else {
            let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let myUser = myEmail.components(separatedBy: "@").first ?? myEmail
            self.totalDevicesCount = parsedDevices.filter { dev in
                let devCreator = (dev.createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let devBorrower = (dev.nguoiMuon ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !myEmail.isEmpty && (
                    devCreator == myEmail || devCreator == myUser || devCreator.contains(myEmail) ||
                    devBorrower == myEmail || devBorrower == myUser || devBorrower.contains(myEmail)
                )
            }.count
        }
    }

    // MARK: - 3. TẢI SỐ LƯỢNG TICKET ĐANG MỞ (SỰ CỐ MỞ)
    private func fetchOpenTickets() async {
        var docsList: [[String: Any]] = []

        // Thử lấy qua :runQuery trước
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId):runQuery"
        if let url = URL(string: urlStr) {
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
                    "limit": 300
                ]
            ]

            if let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) {
                request.httpBody = bodyData
                if let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
                   httpResponse.statusCode == 200,
                   let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for item in results {
                        if let doc = item["document"] as? [String: Any] {
                            docsList.append(doc)
                        }
                    }
                }
            }
        }

        // Fallback sang document listing nếu runQuery không có kết quả
        if docsList.isEmpty {
            let listUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/support_tickets?pageSize=300"
            if let listUrl = URL(string: listUrlStr) {
                var listReq = URLRequest(url: listUrl)
                if !idToken.isEmpty {
                    listReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                }
                if let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(listReq),
                   httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = json["documents"] as? [[String: Any]] {
                    docsList = documents
                }
            }
        }

        let isFullAdminOrHelpDesk = user.isAdmin || user.isSuperAdmin || user.isHelpDesk
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let emailPrefix = cleanEmail.contains("@") ? String(cleanEmail.split(separator: "@").first ?? "") : cleanEmail

        func isSameUser(_ target: String) -> Bool {
            let t = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if t.isEmpty || cleanEmail.isEmpty { return false }
            if t == cleanEmail { return true }
            let p = t.contains("@") ? String(t.split(separator: "@").first ?? "") : t
            return !p.isEmpty && !emailPrefix.isEmpty && p == emailPrefix
        }

        let openCount = docsList.filter { doc in
            guard let fields = doc["fields"] as? [String: Any] else { return false }

            let status = DatabaseHelper.getString(fields["status"] as? [String: Any]).uppercased()
            let closedAt = DatabaseHelper.getInt64(fields["closedAt"] as? [String: Any])
            let isInvalid = DatabaseHelper.getBool(fields["isInvalid"] as? [String: Any])

            let isClosed = status == "CLOSED" || status == "RESOLVED" || closedAt > 0
            let isRejected = status == "REJECTED" || status == "TU_CHOI"
            let isInvalidOrCanceled = isInvalid || status == "CANCELED" || isRejected

            if isClosed || isInvalidOrCanceled { return false }

            if isFullAdminOrHelpDesk {
                return true
            } else {
                let assignedToEmail = DatabaseHelper.getString(fields["assignedToEmail"] as? [String: Any])
                let assignedTo = DatabaseHelper.getString(fields["assignedTo"] as? [String: Any])
                let creatorEmail = DatabaseHelper.getString(fields["creatorEmail"] as? [String: Any])
                let creatorUserId = DatabaseHelper.getString(fields["creatorUserId"] as? [String: Any])

                let isAssigned = isSameUser(assignedToEmail) || isSameUser(assignedTo)
                let isCreator = isSameUser(creatorEmail) || isSameUser(creatorUserId)
                return isAssigned || isCreator
            }
        }.count

        self.openTicketsCount = openCount
    }

    // MARK: - 4. TẢI NHÂN VIÊN CHỜ DUYỆT (PENDING STAFF)
    // MARK: - 5. TẢI THÔNG BÁO CHƯA ĐỌC
    @MainActor
    public func clearUnreadNotifications() {
        self.unreadNotificationCount = 0
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        }
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    @MainActor
    public func fetchUnreadNotifications() async {
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/notifications?pageSize=30"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return
        }

        let readIds = Set(UserDefaults.standard.stringArray(forKey: "notification_read_ids") ?? [])
        let deletedIds = Set(UserDefaults.standard.stringArray(forKey: "notification_deleted_ids") ?? [])
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let unread = documents.filter { doc in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return false }
            let id = name.components(separatedBy: "/").last ?? ""
            if deletedIds.contains(id) || readIds.contains(id) { return false }

            let readByList = DatabaseHelper.getStringArray(fields["readBy"] as? [String: Any]).map { $0.lowercased() }
            if readByList.contains(myEmail) { return false }

            // Lọc quyền xem thông báo chuẩn xác theo vai trò & phòng ban
            let tg = DatabaseHelper.getString(fields["targetGroup"] as? [String: Any]).uppercased()
            let tp = DatabaseHelper.getString(fields["type"] as? [String: Any]).uppercased()
            let title = DatabaseHelper.getString(fields["title"] as? [String: Any]).lowercased()
            let msg = DatabaseHelper.getString(fields["message"] as? [String: Any]).isEmpty
                ? DatabaseHelper.getString(fields["body"] as? [String: Any]).lowercased()
                : DatabaseHelper.getString(fields["message"] as? [String: Any]).lowercased()

            // TUYỆT ĐỐI KHÔNG tính lệnh điều phối hoặc thông báo ticket vào Thông báo hệ thống
            if tp == "DISPATCHED" || tp == "TICKET" || fields["ticketId"] != nil ||
               title.contains("điều phối") || title.contains("lệnh điều phối") || title.contains("phiếu hỗ trợ") {
                return false
            }

            let isJoinRequest = tg == "ADMIN" || tp == "JOIN_REQUEST" ||
                title.contains("yêu cầu gia nhập") || title.contains("xin gia nhập") ||
                title.contains("xin vào") || title.contains("chờ duyệt") ||
                msg.contains("yêu cầu gia nhập") || msg.contains("xin gia nhập")

            if isJoinRequest {
                return self.user.isAdmin
            }

            if self.user.isAdmin || self.user.isHelpDesk {
                return true
            }

            let cleanDept = (self.user.departmentId.isEmpty ? self.user.donVi : self.user.departmentId).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            if tg.isEmpty || tg == "ALL" { return true }
            if tg == "MANAGEMENT" && self.user.isManager { return true }
            if tg == "TECHNICIAN" && self.user.isTechnician { return true }
            if tg == "STAFF" && self.user.isStaff { return true }
            if tg.hasPrefix("TEAM:") {
                let teamPart = String(tg.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanTeam = self.user.toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanTeam.caseInsensitiveCompare(teamPart) == .orderedSame || cleanTeam.localizedCaseInsensitiveContains(teamPart) {
                    return true
                }
            }
            if tg.hasPrefix("DEPT:") {
                let deptPart = String(tg.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                if deptPart.caseInsensitiveCompare(cleanDept) == .orderedSame { return true }
            }
            if tg.caseInsensitiveCompare(cleanDept) == .orderedSame { return true }

            let senderEmail = DatabaseHelper.getString(fields["senderEmail"] as? [String: Any]).lowercased()
            if !myEmail.isEmpty && senderEmail == myEmail { return true }
            if !myEmail.isEmpty && msg.contains(myEmail) { return true }

            return false
        }.count

        self.unreadNotificationCount = unread
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(unread) { _ in }
        }
        UIApplication.shared.applicationIconBadgeNumber = unread
    }

    // MARK: - 6. KIỂM TRA SỐ ĐIỆN THOẠI TRÙNG LẶP (isPhoneAlreadyUsed)
    public func isPhoneAlreadyUsed(cleanPhone: String, excludeEmail: String) async -> (isUsed: Bool, usedEmail: String?) {
        let digitsOnly = cleanPhone.filter { $0.isNumber }
        guard !digitsOnly.isEmpty else { return (false, nil) }

        let cleanExclude = excludeEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users?pageSize=150"
        guard let url = URL(string: urlStr) else { return (false, nil) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return (false, nil)
        }

        for doc in documents {
            guard let fields = doc["fields"] as? [String: Any] else { continue }
            let email = DatabaseHelper.getString(fields["email"] as? [String: Any]).lowercased()
            if !cleanExclude.isEmpty && email == cleanExclude { continue }

            let p1 = DatabaseHelper.getString(fields["phone"] as? [String: Any]).filter { $0.isNumber }
            let p2 = DatabaseHelper.getString(fields["phoneNumber"] as? [String: Any]).filter { $0.isNumber }
            let p3 = DatabaseHelper.getString(fields["sdt"] as? [String: Any]).filter { $0.isNumber }

            if p1 == digitsOnly || p2 == digitsOnly || p3 == digitsOnly {
                return (true, email)
            }
        }

        return (false, nil)
    }

    // MARK: - 7. CẬP NHẬT HỌ VÀ TÊN HIỂN THỊ
    public func updateUserName(newName: String) async throws {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw NSError(domain: "HomeViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Họ và tên không được để trống!"])
        }
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=fullName&updateMask.fieldPaths=name"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "fields": [
                "fullName": ["stringValue": cleanName],
                "name": ["stringValue": cleanName]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        if let (_, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
           (200...299).contains(httpResponse.statusCode) {
            self.user.fullName = cleanName
        }
    }

    // MARK: - 8. CẬP NHẬT SỐ ĐIỆN THOẠI (KIỂM TRA DUY NHẤT & ĐỒNG BỘ ĐẾN TICKETS)
    public func updateUserPhone(newPhone: String) async throws {
        let cleanPhone = newPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = cleanPhone.filter { $0.isNumber }

        if !cleanPhone.isEmpty && (digitsOnly.count < 8 || digitsOnly.count > 12) {
            throw NSError(domain: "HomeViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Số điện thoại không hợp lệ (từ 8 đến 12 chữ số)!"])
        }

        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Kiểm tra xem số điện thoại đã được dùng bởi tài khoản khác chưa
        if !cleanPhone.isEmpty {
            let (isUsed, usedEmail) = await isPhoneAlreadyUsed(cleanPhone: cleanPhone, excludeEmail: cleanEmail)
            if isUsed {
                let targetEmail = usedEmail ?? "tài khoản khác"
                throw NSError(domain: "HomeViewModel", code: 409, userInfo: [NSLocalizedDescriptionKey: "❌ Số điện thoại này đã được sử dụng bởi tài khoản khác (\(targetEmail))!"])
            }
        }

        let mask = "updateMask.fieldPaths=phone&updateMask.fieldPaths=phoneNumber&updateMask.fieldPaths=sdt&updateMask.fieldPaths=soDienThoai"
        let urls = [
            "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users/\(cleanEmail)?\(mask)",
            "\(ServerConfig.documentsBaseUrl)/users/\(cleanEmail)?\(mask)"
        ]

        let payload: [String: Any] = [
            "fields": [
                "phone": ["stringValue": cleanPhone],
                "phoneNumber": ["stringValue": cleanPhone],
                "sdt": ["stringValue": cleanPhone],
                "soDienThoai": ["stringValue": cleanPhone]
            ]
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: payload)

        var patchSuccess = false
        for urlStr in urls {
            guard let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            if let (_, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
               (200...299).contains(httpResponse.statusCode) {
                patchSuccess = true
            }
        }

        if patchSuccess {
            self.user.phone = cleanPhone

            // Cập nhật bộ nhớ đệm offline
            var offlineList = (UserDefaults.standard.array(forKey: "qltb_offline_users_cache") as? [[String: String]]) ?? []
            if let idx = offlineList.firstIndex(where: { ($0["email"] ?? "").caseInsensitiveCompare(cleanEmail) == .orderedSame }) {
                offlineList[idx]["phone"] = cleanPhone
            } else {
                offlineList.insert([
                    "email": cleanEmail,
                    "companyId": self.companyId,
                    "maNhanVien": self.user.maNhanVien,
                    "phone": cleanPhone
                ], at: 0)
            }
            UserDefaults.standard.set(offlineList, forKey: "qltb_offline_users_cache")

            // Đồng bộ sang technician_locations
            Task {
                let locUrlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/technician_locations/\(cleanEmail)?updateMask.fieldPaths=phone&updateMask.fieldPaths=lastUpdatedAt"
                guard let locUrl = URL(string: locUrlStr) else { return }
                var locReq = URLRequest(url: locUrl)
                locReq.httpMethod = "PATCH"
                locReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                locReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let locPayload: [String: Any] = [
                    "fields": [
                        "phone": ["stringValue": cleanPhone],
                        "lastUpdatedAt": ["integerValue": "\(Int64(Date().timeIntervalSince1970 * 1000))"]
                    ]
                ]
                locReq.httpBody = try? JSONSerialization.data(withJSONObject: locPayload)
                _ = await DatabaseHelper.executeSafeRequest(locReq)
            }
        }
    }

    // MARK: - 9. TẢI LÊN ẢNH ĐẠI DIỆN (AVATAR) LÊN CLOUDINARY & CẬP NHẬT FIRESTORE
    public func uploadAvatarImage(_ image: UIImage) async throws {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        guard let uploadedUrl = await CloudinaryService.uploadImage(image, folder: "profile_images") else {
            throw NSError(domain: "HomeViewModel", code: 500, userInfo: [NSLocalizedDescriptionKey: "Tải ảnh lên máy chủ thất bại! Vui lòng thử lại."])
        }

        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=profileImageUrl&updateMask.fieldPaths=avatarUrl"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "fields": [
                "profileImageUrl": ["stringValue": uploadedUrl],
                "avatarUrl": ["stringValue": uploadedUrl]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        if let (_, httpResponse) = await DatabaseHelper.executeSafeRequest(request),
           (200...299).contains(httpResponse.statusCode) {
            self.user.avatarUrl = uploadedUrl
        }
    }

    // MARK: - 10. ĐỔI MẬT KHẨU TÀI KHOẢN (TÁI XÁC THỰC MẬT KHẨU CŨ & CẬP NHẬT FIRESTORE)
    public func executeChangePassword(oldPass: String, newPass: String, confirmPass: String) async throws {
        let cleanOld = oldPass.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPass.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPass.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanOld.isEmpty {
            throw NSError(domain: "HomeViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập mật khẩu hiện tại!"])
        }
        if cleanNew.count < 6 {
            throw NSError(domain: "HomeViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mật khẩu mới phải có ít nhất 6 ký tự!"])
        }
        if cleanNew != cleanConfirm {
            throw NSError(domain: "HomeViewModel", code: 400, userInfo: [NSLocalizedDescriptionKey: "Mật khẩu xác nhận không khớp với mật khẩu mới!"])
        }

        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Tái xác thực mật khẩu cũ bằng signIn
        let reauthSession = try await AuthService.shared.signIn(email: cleanEmail, password: cleanOld)

        // 2. Cập nhật mật khẩu mới trên Firebase Auth
        try await AuthService.shared.updatePassword(idToken: reauthSession.idToken, newPassword: cleanNew)
        self.idToken = reauthSession.idToken

        // 3. Cập nhật thông tin mật khẩu trong Firestore
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let urlStr = "\(ServerConfig.documentsBaseUrl)/companies/\(companyId)/users/\(cleanEmail)?updateMask.fieldPaths=password&updateMask.fieldPaths=newPassword&updateMask.fieldPaths=mustChangePassword&updateMask.fieldPaths=updatedAt"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "fields": [
                "password": ["stringValue": cleanNew],
                "newPassword": ["stringValue": cleanNew],
                "mustChangePassword": ["booleanValue": false],
                "updatedAt": ["integerValue": "\(nowMs)"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        _ = await DatabaseHelper.executeSafeRequest(request)
    }
}
