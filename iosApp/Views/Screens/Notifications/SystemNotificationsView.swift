import SwiftUI

// MARK: - SYSTEM NOTIFICATIONS VIEW (ĐỒNG BỘ 1:1 TOÀN DIỆN VỚI ANDROID, DESKTOP VÀ WEB)
public struct SystemNotificationsView: View {
    public var companyId: String
    public var idToken: String
    public var userEmail: String
    public var userRole: String
    public var userDept: String
    public var userTeam: String
    public var userFullName: String
    public var isAdmin: Bool
    public var isHelpDesk: Bool
    public var isManager: Bool
    @State public var companyBannerText: String
    @State public var companyBannerType: String
    @State public var isCompanyBannerActive: Bool
    public var onBannerUpdated: ((String, String, Bool) -> Void)?
    public var onNotificationsRead: (() -> Void)?
    public var onBack: () -> Void

    @State private var notifications: [SysNotification] = []
    @State private var isLoading: Bool = true
    @State private var selectedFilter: NotifFilter = .all
    @State private var showBroadcastSheet: Bool = false
    @State private var showDeleteAllAlert: Bool = false
    @State private var selectedDetailNotif: SysNotification? = nil

    // Local cached read and deleted IDs
    @State private var readIds: Set<String> = []
    @State private var deletedIds: Set<String> = []

    public enum NotifFilter: String, CaseIterable {
        case all = "Tất cả"
        case info = "Tin tức"
        case warning = "Cảnh báo"
        case maintenance = "Bảo trì"
        case ticket = "Ticket"
        case attendance = "Chấm công"
        case device = "Thiết bị"
    }

    public struct SysNotification: Identifiable {
        public let id: String
        public let title: String
        public let message: String
        public let type: String
        public let targetGroup: String
        public let senderEmail: String
        public let senderName: String
        public let senderRole: String
        public var isRead: Bool
        public let timestamp: Int64
        public var readBy: [String]
    }

    public init(
        companyId: String = "",
        idToken: String = "",
        userEmail: String = "",
        userRole: String = "STAFF",
        userDept: String = "",
        userTeam: String = "",
        userFullName: String = "",
        isAdmin: Bool = false,
        isHelpDesk: Bool = false,
        isManager: Bool = false,
        companyBannerText: String = "",
        companyBannerType: String = "INFO",
        isCompanyBannerActive: Bool = false,
        onBannerUpdated: ((String, String, Bool) -> Void)? = nil,
        onNotificationsRead: (() -> Void)? = nil,
        onBack: @escaping () -> Void = {}
    ) {
        self.companyId = companyId
        self.idToken = idToken
        self.userEmail = userEmail
        self.userRole = userRole
        self.userDept = userDept
        self.userTeam = userTeam
        self.userFullName = userFullName
        self.isAdmin = isAdmin
        self.isHelpDesk = isHelpDesk
        self.isManager = isManager
        self._companyBannerText = State(initialValue: companyBannerText)
        self._companyBannerType = State(initialValue: companyBannerType)
        self._isCompanyBannerActive = State(initialValue: isCompanyBannerActive)
        self.onBannerUpdated = onBannerUpdated
        self.onNotificationsRead = onNotificationsRead
        self.onBack = onBack
    }

    @MainActor
    public init(authViewModel: AuthViewModel, onNotificationsRead: (() -> Void)? = nil, onBack: @escaping () -> Void = {}) {
        let u = authViewModel.currentUser
        self.companyId = u?.companyId ?? ""
        self.idToken = authViewModel.currentIdToken
        self.userEmail = u?.email ?? ""
        self.userRole = u?.role ?? "STAFF"
        self.userDept = u?.departmentId ?? ""
        self.userTeam = u?.toNghiepVu ?? ""
        self.userFullName = u?.fullName ?? ""
        self.isAdmin = u?.isAdmin ?? false
        self.isHelpDesk = u?.isHelpDesk ?? false
        self.isManager = u?.isManager ?? false
        self._companyBannerText = State(initialValue: "")
        self._companyBannerType = State(initialValue: "INFO")
        self._isCompanyBannerActive = State(initialValue: false)
        self.onBannerUpdated = nil
        self.onNotificationsRead = onNotificationsRead
        self.onBack = onBack
    }

    public init(onNotificationsRead: (() -> Void)? = nil, onBack: @escaping () -> Void = {}) {
        self.companyId = ""
        self.idToken = ""
        self.userEmail = ""
        self.userRole = "STAFF"
        self.userDept = ""
        self.userTeam = ""
        self.userFullName = ""
        self.isAdmin = false
        self.isHelpDesk = false
        self.isManager = false
        self._companyBannerText = State(initialValue: "")
        self._companyBannerType = State(initialValue: "INFO")
        self._isCompanyBannerActive = State(initialValue: false)
        self.onBannerUpdated = nil
        self.onNotificationsRead = onNotificationsRead
        self.onBack = onBack
    }

    private var canBroadcast: Bool {
        isAdmin || isHelpDesk || isManager
    }

    // MARK: - BỘ LỌC QUYỀN XEM THÔNG BÁO (ĐỒNG BỘ 1:1 VỚI ANDROID NotificationHelper.isSystemNotificationVisibleToUser)
    private func isNotificationVisible(_ notif: SysNotification) -> Bool {
        let cleanRole = userRole.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let adminUser = isAdmin || cleanRole == "admin" || cleanRole == "superadmin"
        let helpDeskUser = isHelpDesk || cleanRole == "helpdesk" || cleanRole == "it"
        let managerUser = isManager || cleanRole == "quanly" || cleanRole == "phongban"
        let techUser = cleanRole == "ktv" || cleanRole == "technician" || cleanRole == "kythuat"
        let staffUser = cleanRole == "nhanvien" || cleanRole == "staff"

        let myEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let tg = notif.targetGroup.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let tp = notif.type.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let lowerTitle = notif.title.lowercased()
        let lowerMsg = notif.message.lowercased()
        let isJoinRequest = tg == "ADMIN" || tp == "JOIN_REQUEST" ||
            lowerTitle.contains("yêu cầu gia nhập") || lowerTitle.contains("xin gia nhập") ||
            lowerTitle.contains("xin vào") || lowerTitle.contains("chờ duyệt") ||
            lowerMsg.contains("yêu cầu gia nhập") || lowerMsg.contains("xin gia nhập")

        // 1. Yêu cầu xin gia nhập chỉ duy nhất Admin mới được thấy
        if isJoinRequest {
            return adminUser
        }

        // 2. Admin và Helpdesk xem được toàn bộ thông báo
        if adminUser || helpDeskUser { return true }

        // 3. Phân quyền theo targetGroup & phòng ban
        let cleanDept = userDept.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if tg.isEmpty || tg == "ALL" { return true }
        if tg == "MANAGEMENT" && managerUser { return true }
        if tg == "TECHNICIAN" && techUser { return true }
        if tg == "STAFF" && staffUser { return true }
        if tg.hasPrefix("TEAM:") {
            let teamPart = String(tg.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanTeam = userTeam.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleanTeam.caseInsensitiveCompare(teamPart) == .orderedSame || cleanTeam.localizedCaseInsensitiveContains(teamPart) {
                return true
            }
        }
        if tg.hasPrefix("DEPT:") {
            let deptPart = String(tg.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if deptPart.caseInsensitiveCompare(cleanDept) == .orderedSame { return true }
        }
        if tg.caseInsensitiveCompare(cleanDept) == .orderedSame { return true }

        // 4. Nếu là người gửi hoặc có email trong nội dung thì được thấy
        if !myEmail.isEmpty && notif.senderEmail.lowercased() == myEmail { return true }
        if !myEmail.isEmpty && notif.message.lowercased().contains(myEmail) { return true }

        return false
    }

    private var visibleNotifications: [SysNotification] {
        notifications
            .filter { !deletedIds.contains($0.id) }
            .filter { isNotificationVisible($0) }
    }

    private var filteredNotifs: [SysNotification] {
        switch selectedFilter {
        case .all:
            return visibleNotifications
        case .info:
            return visibleNotifications.filter { $0.type.uppercased() == "INFO" }
        case .warning:
            return visibleNotifications.filter { $0.type.uppercased() == "WARNING" }
        case .maintenance:
            return visibleNotifications.filter { $0.type.uppercased() == "MAINTENANCE" }
        case .ticket:
            return visibleNotifications.filter { $0.type.uppercased() == "TICKET" }
        case .attendance:
            return visibleNotifications.filter { $0.type.uppercased() == "ATTENDANCE" }
        case .device:
            return visibleNotifications.filter { $0.type.uppercased() == "DEVICE" }
        }
    }

    private var unreadCount: Int {
        visibleNotifications.filter { !$0.isRead }.count
    }

    private var groupedNotifs: [(String, [SysNotification])] {
        let calendar = Calendar.current
        var groups: [String: [SysNotification]] = [:]

        for notif in filteredNotifs {
            let date = Date(timeIntervalSince1970: TimeInterval(notif.timestamp) / 1000.0)
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
                return (key, list.sorted(by: { $0.timestamp > $1.timestamp }))
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
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        HStack(spacing: 10) {
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
                                    .foregroundColor(Color.appPrimaryPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }

                            Spacer()

                            // Nút Phát thông báo & Quản lý Banner cho Admin / HelpDesk / Manager
                            if canBroadcast {
                                Button(action: { showBroadcastSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "megaphone.fill")
                                            .font(.system(size: 14, weight: .bold))
                                        Text("Phát sóng")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.appPrimaryPink)
                                    .cornerRadius(16)
                                }
                            }

                            // Nút Đánh dấu đã đọc tất cả nhanh
                            if unreadCount > 0 {
                                Button(action: markAllAsRead) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13, weight: .bold))
                                        Text("Đã đọc tất cả")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.22))
                                    .cornerRadius(16)
                                }
                            }

                            Menu {
                                Button(action: markAllAsRead) {
                                    Label("Đánh dấu đã đọc tất cả", systemImage: "checkmark.circle.fill")
                                }
                                if !visibleNotifications.isEmpty {
                                    Button(role: .destructive, action: { showDeleteAllAlert = true }) {
                                        Label("Xóa tất cả thông báo", systemImage: "trash.fill")
                                    }
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
                    .background(Color.appTopBarColor)

                    // Thanh lọc Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NotifFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(selectedFilter == filter ? Color.appPrimary : Color.appSurface)
                                    .foregroundColor(selectedFilter == filter ? .white : Color.appTextPrimary)
                                    .cornerRadius(18)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(selectedFilter == filter ? Color.appPrimary : Color.appCardBorder, lineWidth: 1)
                                    )
                                    .onTapGesture {
                                        withAnimation { selectedFilter = filter }
                                    }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appBackground)

                    // Danh sách thông báo
                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải thông báo...")
                            .tint(Color.appPrimaryPink)
                        Spacer()
                    } else if filteredNotifs.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 44))
                                .foregroundColor(.gray.opacity(0.4))
                            Text("Không có thông báo nào")
                                .font(.system(size: 15, weight: .medium))
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
            .sheet(isPresented: $showBroadcastSheet) {
                BroadcastNotificationSheetView(
                    companyId: companyId,
                    idToken: idToken,
                    userEmail: userEmail,
                    userRole: userRole,
                    userDept: userDept,
                    userFullName: userFullName,
                    isAdmin: isAdmin,
                    isHelpDesk: isHelpDesk,
                    isManager: isManager,
                    currentBannerText: companyBannerText,
                    currentBannerType: companyBannerType,
                    currentBannerIsActive: isCompanyBannerActive,
                    onSuccess: {
                        Task { await fetchNotifications() }
                    },
                    onBannerSaved: { text, type, active in
                        companyBannerText = text
                        companyBannerType = type
                        isCompanyBannerActive = active
                        onBannerUpdated?(text, type, active)
                    }
                )
            }
            .alert("Xóa tất cả thông báo?", isPresented: $showDeleteAllAlert) {
                Button("Hủy", role: .cancel) {}
                Button("Xóa", role: .destructive) {
                    deleteAllNotifications()
                }
            } message: {
                Text("Toàn bộ thông báo đang hiển thị sẽ bị xóa khỏi danh sách của bạn.")
            }
            .onAppear {
                loadPreferences()
                Task {
                    await fetchNotifications()
                    await fetchCompanyBannerConfig()
                }
            }
            .alert(item: $selectedDetailNotif) { notif in
                Alert(
                    title: Text(notif.title),
                    message: Text("\(notif.message)\n\n📌 Phân loại: \(notif.type)\n👤 Người gửi: \(notif.senderName.isEmpty ? notif.senderEmail : notif.senderName)\n🕒 Thời gian: \(formatTime(notif.timestamp))"),
                    dismissButton: .default(Text("Đã hiểu"))
                )
            }
        }
    }

    // MARK: - CARD THÔNG BÁO
    private func notifCard(_ notif: SysNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor(type: notif.type).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: iconName(type: notif.type))
                    .font(.system(size: 19))
                    .foregroundColor(iconColor(type: notif.type))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(notif.title)
                        .font(.system(size: 14.5, weight: notif.isRead ? .regular : .bold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(2)
                    Spacer()
                    if !notif.isRead {
                        Circle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 8, height: 8)
                    }
                }

                if !notif.message.isEmpty {
                    Text(notif.message)
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(3)
                }

                HStack {
                    Text(formatTime(notif.timestamp))
                        .font(.system(size: 11))
                        .foregroundColor(.gray)

                    if !notif.senderName.isEmpty {
                        Text("•  \(notif.senderName)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { deleteNotification(notif.id) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                            .padding(4)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notif.isRead ? Color.appCardBorder : Color.appPrimaryPink.opacity(0.35), lineWidth: notif.isRead ? 1 : 1.5)
        )
        .onTapGesture {
            markAsRead(notif.id)
            selectedDetailNotif = notif
        }
    }

    private func iconName(type: String) -> String {
        switch type.uppercased() {
        case "WARNING": return "exclamationmark.triangle.fill"
        case "MAINTENANCE": return "wrench.and.screwdriver.fill"
        case "TICKET": return "ticket.fill"
        case "ATTENDANCE": return "calendar.badge.clock"
        case "DEVICE": return "desktopcomputer"
        case "SYSTEM": return "gearshape.fill"
        case "JOIN_REQUEST": return "person.crop.circle.badge.plus"
        default: return "megaphone.fill"
        }
    }

    private func iconColor(type: String) -> Color {
        switch type.uppercased() {
        case "WARNING": return Color(hex: "#D97706") // Vàng đậm
        case "MAINTENANCE": return Color(hex: "#7C3AED") // Tím
        case "TICKET": return Color(hex: "#2563EB") // Xanh dương
        case "ATTENDANCE": return Color(hex: "#059669") // Xanh lá
        case "DEVICE": return Color(hex: "#0284C7")
        case "SYSTEM": return Color(hex: "#EA580C")
        case "JOIN_REQUEST": return Color.appPrimaryPink
        default: return Color(hex: "#2563EB")
        }
    }

    private func formatTime(_ ts: Int64) -> String {
        guard ts > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let df = DateFormatter()
        df.dateFormat = "HH:mm dd/MM/yyyy"
        return df.string(from: date)
    }

    // MARK: - PREFERENCES (LƯU TRỮ TRẠNG THÁI ĐÃ ĐỌC & ĐÃ XÓA TRÊN THIẾT BỊ)
    private func loadPreferences() {
        let rList = UserDefaults.standard.stringArray(forKey: "notification_read_ids") ?? []
        self.readIds = Set(rList)
        let dList = UserDefaults.standard.stringArray(forKey: "notification_deleted_ids") ?? []
        self.deletedIds = Set(dList)
    }

    private func saveReadPreferences() {
        UserDefaults.standard.set(Array(readIds), forKey: "notification_read_ids")
        UserDefaults.standard.synchronize()
    }

    private func saveDeletedPreferences() {
        UserDefaults.standard.set(Array(deletedIds), forKey: "notification_deleted_ids")
        UserDefaults.standard.synchronize()
    }

    // MARK: - TẢI CẤU HÌNH BANNER
    private func fetchCompanyBannerConfig() async {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        guard let (data, resp) = await FirestoreHelper.executeSafeRequest(request),
              resp.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else { return }

        let active = FirestoreHelper.getBool(fields["isBannerActive"] as? [String: Any])
        let text = FirestoreHelper.getString(fields["bannerText"] as? [String: Any])
        let type = FirestoreHelper.getString(fields["bannerType"] as? [String: Any])

        await MainActor.run {
            self.isCompanyBannerActive = active
            self.companyBannerText = text
            self.companyBannerType = type.isEmpty ? "INFO" : type
        }
    }

    // MARK: - TẢI DANH SÁCH THÔNG BÁO TỪ FIRESTORE
    private func fetchNotifications() async {
        await MainActor.run { isLoading = true }
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/notifications?pageSize=100"
        guard let url = URL(string: urlStr) else {
            await MainActor.run { isLoading = false }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = await FirestoreHelper.executeSafeRequest(request),
              response.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            await MainActor.run { isLoading = false }
            return
        }

        var loaded: [SysNotification] = []
        let myEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for doc in documents {
            guard let fields = doc["fields"] as? [String: Any] else { continue }
            let docName = doc["name"] as? String ?? ""
            let id = docName.components(separatedBy: "/").last ?? ""

            let msg = FirestoreHelper.getString(fields["message"] as? [String: Any])
            let finalMsg = msg.isEmpty ? FirestoreHelper.getString(fields["body"] as? [String: Any]) : msg

            let rawTs = FirestoreHelper.getInt64(fields["timestamp"] as? [String: Any])
            let finalTs = rawTs > 0 ? rawTs : FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any])

            let readByList = FirestoreHelper.getStringArray(fields["readBy"] as? [String: Any]).map { $0.lowercased() }
            let isReadFinal = readByList.contains(myEmail) || readIds.contains(id)

            let targetGroup = FirestoreHelper.getString(fields["targetGroup"] as? [String: Any]).isEmpty
                ? FirestoreHelper.getString(fields["targetRole"] as? [String: Any])
                : FirestoreHelper.getString(fields["targetGroup"] as? [String: Any])

            let senderEmail = FirestoreHelper.getString(fields["senderEmail"] as? [String: Any]).isEmpty
                ? FirestoreHelper.getString(fields["createdByEmail"] as? [String: Any])
                : FirestoreHelper.getString(fields["senderEmail"] as? [String: Any])

            let nType = FirestoreHelper.getString(fields["type"] as? [String: Any])

            loaded.append(SysNotification(
                id: id,
                title: FirestoreHelper.getString(fields["title"] as? [String: Any]),
                message: finalMsg,
                type: nType.isEmpty ? "INFO" : nType,
                targetGroup: targetGroup.isEmpty ? "ALL" : targetGroup,
                senderEmail: senderEmail,
                senderName: FirestoreHelper.getString(fields["senderName"] as? [String: Any]),
                senderRole: FirestoreHelper.getString(fields["senderRole"] as? [String: Any]),
                isRead: isReadFinal,
                timestamp: finalTs,
                readBy: readByList
            ))
        }

        loaded.sort { $0.timestamp > $1.timestamp }
        let finalLoaded = loaded

        await MainActor.run {
            self.notifications = finalLoaded
            self.isLoading = false
        }
    }

    // MARK: - ĐÁNH DẤU ĐÃ ĐỌC 1 THÔNG BÁO
    private func markAsRead(_ id: String) {
        readIds.insert(id)
        saveReadPreferences()
        onNotificationsRead?()

        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
            let myEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !myEmail.isEmpty && !notifications[idx].readBy.contains(myEmail) {
                notifications[idx].readBy.append(myEmail)
            }

            let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let newReadBy = notifications[idx].readBy
            guard !cleanComp.isEmpty else { return }

            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/notifications/\(id)?updateMask.fieldPaths=readBy&updateMask.fieldPaths=isRead"
            guard let url = URL(string: urlStr) else { return }

            let body: [String: Any] = [
                "fields": [
                    "readBy": FirestoreHelper.valueToFirestore(newReadBy),
                    "isRead": ["booleanValue": true]
                ]
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return }
            Task {
                var req = URLRequest(url: url)
                req.httpMethod = "PATCH"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                req.httpBody = jsonData
                _ = await FirestoreHelper.executeSafeRequest(req)
            }
        }
    }

    // MARK: - ĐÁNH DẤU ĐÃ ĐỌC TẤT CẢ
    private func markAllAsRead() {
        guard !visibleNotifications.isEmpty else { return }

        let myEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for item in visibleNotifications {
            readIds.insert(item.id)
            if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
                notifications[idx].isRead = true
                if !myEmail.isEmpty && !notifications[idx].readBy.contains(myEmail) {
                    notifications[idx].readBy.append(myEmail)
                }
            }
        }
        saveReadPreferences()
        onNotificationsRead?()

        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        let targetItems = visibleNotifications
        Task {
            for item in targetItems {
                let newReadBy = notifications.first(where: { $0.id == item.id })?.readBy ?? (myEmail.isEmpty ? [] : [myEmail])
                let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/notifications/\(item.id)?updateMask.fieldPaths=readBy"
                guard let url = URL(string: urlStr) else { continue }
                let body: [String: Any] = [
                    "fields": [
                        "readBy": FirestoreHelper.valueToFirestore(newReadBy)
                    ]
                ]
                if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
                    var req = URLRequest(url: url)
                    req.httpMethod = "PATCH"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                    req.httpBody = jsonData
                    _ = await FirestoreHelper.executeSafeRequest(req)
                }
            }
        }
    }

    // MARK: - XÓA 1 THÔNG BÁO
    private func deleteNotification(_ id: String) {
        deletedIds.insert(id)
        saveDeletedPreferences()
        notifications.removeAll { $0.id == id }

        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/notifications/\(id)"
        guard let url = URL(string: urlStr) else { return }

        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            _ = await FirestoreHelper.executeSafeRequest(req)
        }
    }

    // MARK: - XÓA TẤT CẢ THÔNG BÁO KHỎI GIAO DIỆN
    private func deleteAllNotifications() {
        for n in visibleNotifications {
            deletedIds.insert(n.id)
        }
        saveDeletedPreferences()
    }
}

// MARK: - SHEET PHÁT THÔNG BÁO & QUẢN LÝ BANNER TOPBAR
public struct BroadcastNotificationSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var companyId: String
    var idToken: String
    var userEmail: String
    var userRole: String
    var userDept: String
    var userFullName: String
    var isAdmin: Bool
    var isHelpDesk: Bool
    var isManager: Bool
    var currentBannerText: String
    var currentBannerType: String
    var currentBannerIsActive: Bool

    var onSuccess: () -> Void
    var onBannerSaved: (String, String, Bool) -> Void

    @State private var selectedTab: Int = 0

    // Tab 0: Phát thông báo
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var announceType: String = "INFO"
    @State private var targetGroup: String = "ALL"
    @State private var departmentsList: [String] = []
    @State private var isSending: Bool = false
    @State private var sendErrorMessage: String? = nil

    // Tab 1: Banner TopBar
    @State private var bannerText: String = ""
    @State private var bannerType: String = "INFO"
    @State private var bannerIsActive: Bool = false
    @State private var isSavingBanner: Bool = false
    @State private var bannerErrorMessage: String? = nil

    public init(
        companyId: String,
        idToken: String,
        userEmail: String,
        userRole: String,
        userDept: String,
        userFullName: String,
        isAdmin: Bool,
        isHelpDesk: Bool,
        isManager: Bool,
        currentBannerText: String,
        currentBannerType: String,
        currentBannerIsActive: Bool,
        onSuccess: @escaping () -> Void,
        onBannerSaved: @escaping (String, String, Bool) -> Void
    ) {
        self.companyId = companyId
        self.idToken = idToken
        self.userEmail = userEmail
        self.userRole = userRole
        self.userDept = userDept
        self.userFullName = userFullName
        self.isAdmin = isAdmin
        self.isHelpDesk = isHelpDesk
        self.isManager = isManager
        self.currentBannerText = currentBannerText
        self.currentBannerType = currentBannerType
        self.currentBannerIsActive = currentBannerIsActive
        self.onSuccess = onSuccess
        self.onBannerSaved = onBannerSaved

        self._bannerText = State(initialValue: currentBannerText)
        self._bannerType = State(initialValue: currentBannerType.isEmpty ? "INFO" : currentBannerType)
        self._bannerIsActive = State(initialValue: currentBannerIsActive)
    }

    private var targetOptions: [(String, String)] {
        if !isAdmin && !isHelpDesk && isManager {
            return [
                ("DEPT:" + userDept, "🏢 Phòng ban của tôi (" + (userDept.isEmpty ? "Chưa rõ" : userDept) + ")")
            ]
        }
        var opts: [(String, String)] = [
            // 1. Khối chung
            ("ALL", "🌐 Toàn bộ nhân sự (Toàn công ty)"),
            ("MANAGEMENT", "👔 Khối Quản lý (Admin, Trưởng/Phó phòng)"),
            ("TECHNICIAN", "🔧 Khối Kỹ thuật & KTV (KTV / HelpDesk)"),
            ("STAFF", "👤 Khối Cơ sở / Cửa hàng (Nhân viên)"),
            // 2. Tổ chuyên môn
            ("TEAM:TO_HA_TANG_BAO_MAT", "⚡ Tổ Hạ tầng mạng & Bảo mật"),
            ("TEAM:TO_KY_THUAT_UNG_DUNG", "⚡ Tổ Kỹ thuật ứng dụng & Phần mềm"),
            ("TEAM:TO_PHAN_TICH_NGHIEP_VU", "⚡ Tổ Phân tích nghiệp vụ (MMS/OMNI/ERP)"),
            ("TEAM:TO_NEN_TANG_DU_LIEU", "⚡ Tổ Nền tảng dữ liệu & Báo cáo"),
            ("TEAM:TO_RND_CONG_NGHE", "⚡ Tổ R&D Công nghệ")
        ]
        // 3. Cơ cấu phòng ban
        for dept in departmentsList {
            let dName = dept.trimmingCharacters(in: .whitespacesAndNewlines)
            if !dName.isEmpty {
                opts.append(("DEPT:\(dName)", "🏢 Phòng ban: \(dName)"))
            }
        }
        if departmentsList.isEmpty && !userDept.isEmpty {
            opts.append(("DEPT:\(userDept)", "🏢 Phòng ban: \(userDept)"))
        }
        return opts
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Segmented Tab Picker (Chỉ Admin mới có Tab Banner TopBar)
                if isAdmin {
                    Picker("Chế độ", selection: $selectedTab) {
                        Text("Phát thông báo").tag(0)
                        Text("Banner TopBar").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }

                ScrollView {
                    if selectedTab == 0 || !isAdmin {
                        broadcastForm
                    } else {
                        bannerForm
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(selectedTab == 0 ? "Phát sóng thông báo" : "Quản lý Banner TopBar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(Color.appTextPrimary)
                }
            }
            .onAppear {
                if !isAdmin && !isHelpDesk && !userDept.isEmpty {
                    targetGroup = "DEPT:\(userDept)"
                }
                Task {
                    let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard !cleanComp.isEmpty else { return }
                    let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/departments?pageSize=100"
                    guard let url = URL(string: urlStr) else { return }
                    var req = URLRequest(url: url)
                    if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                    guard let (data, resp) = await FirestoreHelper.executeSafeRequest(req),
                          resp.statusCode == 200,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let docs = json["documents"] as? [[String: Any]] else { return }
                    let depts = docs.compactMap { doc -> String? in
                        guard let fields = doc["fields"] as? [String: Any] else { return nil }
                        let name = FirestoreHelper.getString(fields["name"] as? [String: Any])
                        let alt = FirestoreHelper.getString(fields["departmentName"] as? [String: Any])
                        let val = !name.isEmpty ? name : alt
                        return val.isEmpty ? nil : val
                    }
                    await MainActor.run {
                        self.departmentsList = Array(Set(depts)).sorted()
                    }
                }
            }
        }
    }

    // MARK: - FORM PHÁT THÔNG BÁO
    private var broadcastForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tiêu đề
            VStack(alignment: .leading, spacing: 6) {
                Text("Tiêu đề thông báo *")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                TextField("Nhập tiêu đề thông báo...", text: $title)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            // Loại thông báo
            VStack(alignment: .leading, spacing: 6) {
                Text("Loại thông báo")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                HStack(spacing: 8) {
                    typeChip(id: "INFO", label: "Tin tức", color: Color(hex: "#2563EB"))
                    typeChip(id: "WARNING", label: "Cảnh báo", color: Color(hex: "#D97706"))
                    typeChip(id: "MAINTENANCE", label: "Bảo trì", color: Color(hex: "#7C3AED"))
                }
            }

            // Đối tượng nhận
            VStack(alignment: .leading, spacing: 6) {
                Text("Đối tượng nhận")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Menu {
                    ForEach(targetOptions, id: \.0) { opt in
                        Button(action: { targetGroup = opt.0 }) {
                            HStack {
                                Text(opt.1)
                                if targetGroup == opt.0 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(targetOptions.first(where: { $0.0 == targetGroup })?.1 ?? "Chọn đối tượng...")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(12)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            // Nội dung chi tiết
            VStack(alignment: .leading, spacing: 6) {
                Text("Nội dung thông báo *")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                TextEditor(text: $message)
                    .font(.system(size: 14))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            if let err = sendErrorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            // Nút Gửi thông báo
            Button(action: sendBroadcastNotification) {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                        Text(isAdmin ? "Phát thông báo toàn doanh nghiệp" : "Phát sóng thông báo")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background((title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty || isSending) ? Color.gray.opacity(0.4) : Color.appPrimaryPink)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
        }
        .padding(16)
    }

    private func typeChip(id: String, label: String, color: Color) -> some View {
        let isSel = announceType == id
        return Button(action: { announceType = id }) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSel ? color.opacity(0.18) : Color.appSurface)
            .foregroundColor(isSel ? color : Color.appTextSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSel ? color : Color.appCardBorder, lineWidth: isSel ? 1.5 : 1)
            )
        }
    }

    // MARK: - FORM QUẢN LÝ BANNER TOPBAR
    private var bannerForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Công tắc Bật/Tắt
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trạng thái Banner")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Text("Bật để hiển thị dòng chữ chạy trên thanh TopBar")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }
                Spacer()
                Toggle("", isOn: $bannerIsActive)
                    .labelsHidden()
                    .tint(Color.appPrimaryPink)
            }
            .padding(14)
            .background(Color.appSurface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

            // Nội dung Banner
            VStack(alignment: .leading, spacing: 6) {
                Text("Nội dung Banner chạy chữ")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                TextField("Nhập nội dung thông báo quan trọng...", text: $bannerText)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            // Loại màu Banner
            VStack(alignment: .leading, spacing: 6) {
                Text("Loại màu sắc Banner")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                HStack(spacing: 8) {
                    bannerTypeChip(id: "INFO", label: "Xanh tin tức", color: Color(hex: "#2563EB"))
                    bannerTypeChip(id: "WARNING", label: "Vàng cảnh báo", color: Color(hex: "#D97706"))
                    bannerTypeChip(id: "MAINTENANCE", label: "Tím bảo trì", color: Color(hex: "#7C3AED"))
                }
            }

            // Xem trước Banner trực tiếp
            VStack(alignment: .leading, spacing: 6) {
                Text("Xem trước Banner:")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                if bannerText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("(Chưa nhập nội dung)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(10)
                } else {
                    CompanyBannerTickerView(
                        text: bannerText,
                        type: CompanyBannerTickerView.BannerType(rawValue: bannerType) ?? .info,
                        isActive: true
                    )
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            if let err = bannerErrorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            // Nút Lưu/Bật/Tắt Banner TopBar
            VStack(spacing: 10) {
                Button(action: {
                    bannerIsActive = true
                    saveBannerConfig()
                }) {
                    HStack(spacing: 8) {
                        if isSavingBanner && bannerIsActive {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 14))
                            Text("📢 Bật & Hiển thị Banner TopBar")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isSavingBanner ? Color.gray.opacity(0.4) : Color(hex: "#2563EB"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isSavingBanner || bannerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(action: {
                    bannerIsActive = false
                    saveBannerConfig()
                }) {
                    HStack(spacing: 8) {
                        if isSavingBanner && !bannerIsActive {
                            ProgressView().tint(.red)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Tắt Banner TopBar")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.12))
                    .foregroundColor(.red)
                    .cornerRadius(10)
                }
                .disabled(isSavingBanner)
            }
        }
        .padding(16)
    }

    private func bannerTypeChip(id: String, label: String, color: Color) -> some View {
        let isSel = bannerType == id
        return Button(action: { bannerType = id }) {
            Text(label)
                .font(.system(size: 12.5, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSel ? color.opacity(0.18) : Color.appSurface)
                .foregroundColor(isSel ? color : Color.appTextSecondary)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSel ? color : Color.appCardBorder, lineWidth: isSel ? 1.5 : 1)
                )
        }
    }

    // MARK: - GỬI THÔNG BÁO LÊN FIRESTORE
    private func sendBroadcastNotification() {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanMsg = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty && !cleanMsg.isEmpty else { return }

        isSending = true
        sendErrorMessage = nil

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/notifications"
        guard let url = URL(string: urlStr) else {
            isSending = false
            return
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let effectiveTarget = (!isAdmin && !isHelpDesk && !userDept.isEmpty) ? "DEPT:\(userDept)" : targetGroup
        let sName = userFullName.isEmpty ? userEmail.components(separatedBy: "@").first ?? userEmail : userFullName

        let docBody: [String: Any] = [
            "fields": [
                "title": ["stringValue": cleanTitle],
                "message": ["stringValue": cleanMsg],
                "body": ["stringValue": cleanMsg],
                "senderEmail": ["stringValue": userEmail.lowercased()],
                "createdByEmail": ["stringValue": userEmail.lowercased()],
                "senderName": ["stringValue": sName],
                "senderRole": ["stringValue": userRole],
                "companyId": ["stringValue": cleanComp],
                "targetGroup": ["stringValue": effectiveTarget],
                "targetRole": ["stringValue": effectiveTarget],
                "timestamp": ["integerValue": String(now)],
                "createdAt": ["integerValue": String(now)],
                "type": ["stringValue": announceType],
                "readBy": ["arrayValue": ["values": []]]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: docBody) else {
            isSending = false
            return
        }

        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            req.httpBody = jsonData

            if let (_, resp) = await FirestoreHelper.executeSafeRequest(req),
               (200...299).contains(resp.statusCode) {
                await MainActor.run {
                    isSending = false
                    onSuccess()
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isSending = false
                    sendErrorMessage = "Không thể gửi thông báo. Vui lòng thử lại."
                }
            }
        }
    }

    // MARK: - LƯU CẤU HÌNH BANNER TOPBAR LÊN FIRESTORE
    private func saveBannerConfig() {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        let cleanText = bannerText
            .replacingOccurrences(of: "\r\n", with: "  •  ")
            .replacingOccurrences(of: "\n", with: "  •  ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingBanner = true
        bannerErrorMessage = nil

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)?updateMask.fieldPaths=bannerText&updateMask.fieldPaths=bannerType&updateMask.fieldPaths=isBannerActive&updateMask.fieldPaths=bannerUpdatedAt"
        guard let url = URL(string: urlStr) else {
            isSavingBanner = false
            return
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "bannerText": ["stringValue": cleanText],
                "bannerType": ["stringValue": bannerType],
                "isBannerActive": ["booleanValue": bannerIsActive],
                "bannerUpdatedAt": ["integerValue": String(now)]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            isSavingBanner = false
            return
        }

        Task {
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !idToken.isEmpty { req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            req.httpBody = jsonData

            if let (_, resp) = await FirestoreHelper.executeSafeRequest(req),
               (200...299).contains(resp.statusCode) {
                await MainActor.run {
                    isSavingBanner = false
                    onBannerSaved(cleanText, bannerType, bannerIsActive)
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isSavingBanner = false
                    bannerErrorMessage = "Không thể cập nhật banner. Vui lòng thử lại."
                }
            }
        }
    }
}
