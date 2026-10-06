import Foundation

// MARK: - BUSINESS HOURS CHECK RESULT
public struct BusinessHoursCheckResult {
    public let isBusinessHours: Bool
    public let reason: String
    public let isLunchBreak: Bool
    public let isWeekend: Bool
    public let formattedTime: String

    public init(
        isBusinessHours: Bool,
        reason: String,
        isLunchBreak: Bool = false,
        isWeekend: Bool = false,
        formattedTime: String = ""
    ) {
        self.isBusinessHours = isBusinessHours
        self.reason = reason
        self.isLunchBreak = isLunchBreak
        self.isWeekend = isWeekend
        self.formattedTime = formattedTime
    }
}

// MARK: - AUTO DISPATCHED TECHNICIAN MODEL
public struct AutoDispatchedTechnician {
    public let email: String
    public let name: String
    public let departmentId: String
    public let departmentName: String
    public let assignedCluster: String
    public let shiftType: String
    public let dispatchNote: String

    public init(
        email: String,
        name: String,
        departmentId: String = "ITTT",
        departmentName: String = "IT TẬP TRUNG",
        assignedCluster: String = "HCM_1",
        shiftType: String = "",
        dispatchNote: String = ""
    ) {
        self.email = email
        self.name = name
        self.departmentId = departmentId
        self.departmentName = departmentName
        self.assignedCluster = assignedCluster
        self.shiftType = shiftType
        self.dispatchNote = dispatchNote
    }
}

// MARK: - CLUSTER TECH SUGGESTION MODEL (GỢI Ý KTV THEO CỤM)
public struct ClusterTechSuggestion {
    public let email: String
    public let name: String
    public let cluster: String
    public let isOnline: Bool
    public let workload: Int
    public let reason: String
    public let isSameCluster: Bool

    public init(
        email: String,
        name: String,
        cluster: String,
        isOnline: Bool,
        workload: Int,
        reason: String,
        isSameCluster: Bool
    ) {
        self.email = email
        self.name = name
        self.cluster = cluster
        self.isOnline = isOnline
        self.workload = workload
        self.reason = reason
        self.isSameCluster = isSameCluster
    }
}

// MARK: - WORKING HOURS HELPER (ĐỒNG BỘ 1:1 VỚI ANDROID, DESKTOP VÀ WEB)
public enum WorkingHoursHelper {

    public static func getVietnamCalendar(date: Date = Date()) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        if let tz = TimeZone(identifier: "Asia/Ho_Chi_Minh") {
            cal.timeZone = tz
        }
        cal.locale = Locale(identifier: "vi_VN")
        return cal
    }

    public static func normalizeClusterCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }
        var result = trimmed.uppercased()
        if result.hasPrefix("KV_") {
            result = String(result.dropFirst(3))
        }
        return result.replacingOccurrences(of: " ", with: "_")
    }

    /**
     * Kiểm tra thời điểm hiện tại có phải Ngoài ca trực của HelpDesk hay không:
     * - Sau 12:00 trưa Thứ 7 (hoặc theo cấu hình helpdeskSaturdayEnd)
     * - Cả ngày Chủ Nhật (24/24)
     * - Các ngày nghỉ Lễ/Tết do HelpDesk tự điền trong cấu hình (holidaysList)
     * - Ngoài giờ làm việc Thứ 2 - Thứ 6 (Trước 08:00 hoặc Sau 17:30)
     */
    public static func isHelpdeskOffHours(date: Date = Date(), slaConfig: SlaConfig? = nil) -> BusinessHoursCheckResult {
        if let config = slaConfig, !config.enableAutoDispatchOffHours {
            return BusinessHoursCheckResult(
                isBusinessHours: true,
                reason: "Cơ chế điều phối tự động ngoài giờ đang tắt"
            )
        }

        let cal = getVietnamCalendar(date: date)
        let weekday = cal.component(.weekday, from: date) // 1: Sunday, 2: Monday, ..., 7: Saturday
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        let timeMinutes = hour * 60 + minute
        let year = cal.component(.year, from: date)
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
        let timeStr = String(format: "%02d:%02d", hour, minute)

        // 1. Kiểm tra ngày Lễ / Tết
        let holidays = slaConfig?.holidaysList ?? []
        if let matched = holidays.first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(dateStr) }) {
            return BusinessHoursCheckResult(
                isBusinessHours: false,
                reason: "Ngày nghỉ Lễ / Tết [\(matched)] (HelpDesk nghỉ trực)",
                isWeekend: true,
                formattedTime: "\(timeStr) ngày \(dateStr)"
            )
        }

        func parseMin(_ time: String, defH: Int, defM: Int) -> Int {
            let parts = time.split(separator: ":")
            let h = parts.count > 0 ? (Int(parts[0]) ?? defH) : defH
            let m = parts.count > 1 ? (Int(parts[1]) ?? defM) : defM
            return h * 60 + m
        }

        let satStart = parseMin(slaConfig?.helpdeskSaturdayStart ?? "08:00", defH: 8, defM: 0)
        let satEnd = parseMin(slaConfig?.helpdeskSaturdayEnd ?? "12:00", defH: 12, defM: 0)
        let wdStart = parseMin(slaConfig?.helpdeskWeekdayStart ?? "08:00", defH: 8, defM: 0)
        let wdEnd = parseMin(slaConfig?.helpdeskWeekdayEnd ?? "17:30", defH: 17, defM: 30)

        // 2. Chủ Nhật (weekday == 1): 24/24 HelpDesk nghỉ trực
        if weekday == 1 {
            return BusinessHoursCheckResult(
                isBusinessHours: false,
                reason: "Chủ nhật (HelpDesk không trực ca)",
                isWeekend: true,
                formattedTime: "\(timeStr) (Chủ nhật)"
            )
        }

        // 3. Thứ Bảy (weekday == 7): Chỉ trực sáng (08:00 - 12:00)
        if weekday == 7 {
            if timeMinutes >= satStart && timeMinutes < satEnd {
                return BusinessHoursCheckResult(
                    isBusinessHours: true,
                    reason: "Ca trực sáng Thứ Bảy của HelpDesk",
                    isWeekend: false,
                    formattedTime: "\(timeStr) (Thứ 7)"
                )
            } else {
                let detail = timeMinutes < satStart ? "Sáng sớm Thứ 7 trước ca trực" : "Chiều/Tối Thứ 7 ngoài giờ trực (Sau 12:00)"
                return BusinessHoursCheckResult(
                    isBusinessHours: false,
                    reason: "\(detail) (HelpDesk nghỉ trực)",
                    isWeekend: true,
                    formattedTime: "\(timeStr) (Thứ 7)"
                )
            }
        }

        // 4. Thứ Hai đến Thứ Sáu (weekday 2 đến 6)
        if timeMinutes >= wdStart && timeMinutes < wdEnd {
            return BusinessHoursCheckResult(
                isBusinessHours: true,
                reason: "Trong giờ làm việc HelpDesk",
                isWeekend: false,
                formattedTime: timeStr
            )
        } else {
            let detail = timeMinutes < wdStart ? "Sáng sớm trước giờ làm việc" : "Chiều tối / Đêm sau giờ làm việc"
            return BusinessHoursCheckResult(
                isBusinessHours: false,
                reason: "\(detail) ngoài giờ trực HelpDesk",
                isWeekend: false,
                formattedTime: timeStr
            )
        }
    }

    public static func checkBusinessHours(date: Date = Date()) -> BusinessHoursCheckResult {
        return isHelpdeskOffHours(date: date, slaConfig: nil)
    }

    /**
     * Xác định Cụm quản lý (maKhuVuc) của đơn vị/siêu thị tạo ticket.
     * Có fallback danh mục mặc định đồng bộ Android, Web và Desktop.
     */
    public static func resolveUnitCluster(units: [DonVi], donViName: String) -> String {
        let cleanDonVi = donViName.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanDonVi.isEmpty { return "" }

        for u in units {
            let uName = u.tenDonVi.trimmingCharacters(in: .whitespacesAndNewlines)
            let uCluster = u.maKhuVuc.trimmingCharacters(in: .whitespacesAndNewlines)
            if !uCluster.isEmpty && !uName.isEmpty {
                if cleanDonVi.localizedCaseInsensitiveContains(uName) || uName.localizedCaseInsensitiveContains(cleanDonVi) {
                    return normalizeClusterCode(uCluster)
                }
            }
        }

        // Fallback nhận diện theo từ khóa siêu thị/đơn vị
        let upper = cleanDonVi.uppercased()
        if upper.contains("BÌNH TÂN") || upper.contains("HÙNG VƯƠNG") || upper.contains("QUẬN 1") || upper.contains("QUẬN 5") {
            return "HCM_1"
        }
        if upper.contains("HÒA BÌNH") || upper.contains("TÂN BÌNH") || upper.contains("TÂN PHÚ") || upper.contains("GÒ VẤP") {
            return "HCM_2"
        }
        if upper.contains("VĨNH LONG") || upper.contains("CẦN THƠ") || upper.contains("TIỀN GIANG") || upper.contains("BẾN TRE") {
            return "MIENTAY_1"
        }
        if upper.contains("BÀ RỊA") || upper.contains("VŨNG TÀU") || upper.contains("ĐỒNG NAI") || upper.contains("BÌNH DƯƠNG") {
            return "DONGNAI"
        }

        return ""
    }

    /**
     * Tìm KTV phụ trách theo Cụm và Cân bằng tải công việc từ danh sách KtvOnlineLocation
     */
    public static func findDutyTechnician(
        check: BusinessHoursCheckResult,
        ktvList: [KtvOnlineLocation],
        targetCluster: String,
        workloadMap: [String: Int] = [:]
    ) -> AutoDispatchedTechnician? {
        let cleanCluster = normalizeClusterCode(targetCluster)
        if cleanCluster.isEmpty || ktvList.isEmpty { return nil }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // 1. Phân loại KTV Online (isOnline = true VÀ hoạt động trong vòng 15 phút)
        let onlineTechs = ktvList.filter { ktv in
            ktv.isOnline && ktv.lastActiveAt > 0 && (now - ktv.lastActiveAt) <= 15 * 60 * 1000
        }

        // Nhóm A: KTV Online cùng Cụm
        let onlineClusterTechs = onlineTechs.filter { ktv in
            let c = normalizeClusterCode(ktv.maKhuVuc)
            return c == cleanCluster || c.contains(cleanCluster) || cleanCluster.contains(c)
        }

        // Nhóm B: KTV thuộc Cụm vừa hoạt động trong vòng 15 phút (<= 900.000ms)
        let recentClusterTechs = ktvList.filter { ktv in
            let c = normalizeClusterCode(ktv.maKhuVuc)
            let isSameCluster = (c == cleanCluster || c.contains(cleanCluster) || cleanCluster.contains(c))
            return isSameCluster && ktv.lastActiveAt > 0 && (now - ktv.lastActiveAt) <= 15 * 60 * 1000
        }

        // Nhóm C: KTV Online trên toàn hệ thống
        let candidatePool: [KtvOnlineLocation]
        if !onlineClusterTechs.isEmpty {
            candidatePool = onlineClusterTechs
        } else if !recentClusterTechs.isEmpty {
            candidatePool = recentClusterTechs
        } else {
            candidatePool = onlineTechs
        }

        if candidatePool.isEmpty { return nil }

        // Sắp xếp: Ưu tiên ít việc nhất -> Online -> Hoạt động gần nhất
        let sorted = candidatePool.sorted { a, b in
            let loadA = workloadMap[a.email.lowercased()] ?? 0
            let loadB = workloadMap[b.email.lowercased()] ?? 0
            if loadA != loadB { return loadA < loadB }
            let activeA = a.isOnline && a.lastActiveAt > 0 && (now - a.lastActiveAt) <= 15 * 60 * 1000
            let activeB = b.isOnline && b.lastActiveAt > 0 && (now - b.lastActiveAt) <= 15 * 60 * 1000
            if activeA != activeB { return activeA && !activeB }
            return a.lastActiveAt > b.lastActiveAt
        }

        guard let chosen = sorted.first else { return nil }
        let chosenLoad = workloadMap[chosen.email.lowercased()] ?? 0
        let isSameCluster = onlineClusterTechs.contains(where: { $0.email == chosen.email }) ||
                            recentClusterTechs.contains(where: { $0.email == chosen.email })
        let clusterLabel = isSameCluster ? "Cụm \(cleanCluster)" : "Cụm \(chosen.maKhuVuc.isEmpty ? "khác" : chosen.maKhuVuc)"
        let isActuallyOnline = chosen.isOnline && chosen.lastActiveAt > 0 && (now - chosen.lastActiveAt) <= 15 * 60 * 1000
        let onlineStatusText = isActuallyOnline ? "Đang Online" : "Vừa hoạt động"
        let loadDesc = chosenLoad == 0 ? " • Đang rảnh (0 việc)" : " • Đang xử lý \(chosenLoad) việc (ít nhất)"

        return AutoDispatchedTechnician(
            email: chosen.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            name: !chosen.name.isEmpty ? chosen.name : chosen.email,
            departmentId: "ITTT",
            departmentName: "IT TẬP TRUNG",
            assignedCluster: isSameCluster ? cleanCluster : (!chosen.maKhuVuc.isEmpty ? chosen.maKhuVuc : cleanCluster),
            shiftType: "ONLINE",
            dispatchNote: "🤖 Hệ thống tự động chuyển cho KTV \(chosen.name) (\(onlineStatusText) • \(clusterLabel)\(loadDesc))"
        )
    }

    /**
     * Gợi ý KTV thông minh theo Cụm sở tại trên giao diện điều phối
     */
    public static func suggestClusterTechnician(
        ktvList: [KtvOnlineLocation],
        targetCluster: String,
        workloadMap: [String: Int] = [:]
    ) -> ClusterTechSuggestion? {
        let cleanCluster = normalizeClusterCode(targetCluster)
        if cleanCluster.isEmpty || ktvList.isEmpty { return nil }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        // Lọc KTV cùng Cụm
        let clusterTechs = ktvList.filter { ktv in
            let c = normalizeClusterCode(ktv.maKhuVuc)
            return c == cleanCluster || c.contains(cleanCluster) || cleanCluster.contains(c)
        }

        let isSame = !clusterTechs.isEmpty
        let pool = isSame ? clusterTechs : ktvList

        let sorted = pool.sorted { a, b in
            let loadA = workloadMap[a.email.lowercased()] ?? 0
            let loadB = workloadMap[b.email.lowercased()] ?? 0
            if loadA != loadB { return loadA < loadB }
            let activeA = a.isOnline && a.lastActiveAt > 0 && (now - a.lastActiveAt) <= 15 * 60 * 1000
            let activeB = b.isOnline && b.lastActiveAt > 0 && (now - b.lastActiveAt) <= 15 * 60 * 1000
            if activeA != activeB { return activeA && !activeB }
            return a.lastActiveAt > b.lastActiveAt
        }

        guard let top = sorted.first else { return nil }
        let load = workloadMap[top.email.lowercased()] ?? 0
        let isOnline = top.isOnline && top.lastActiveAt > 0 && (now - top.lastActiveAt) <= 15 * 60 * 1000
        let statusStr = isOnline ? "Đang Online" : "Vừa hoạt động"
        let reason = isSame
            ? "\(statusStr) • Cụm \(cleanCluster) • \(load) việc đang xử lý"
            : "\(statusStr) • Cụm \(top.maKhuVuc) (Gần nhất) • \(load) việc"

        return ClusterTechSuggestion(
            email: top.email,
            name: top.name,
            cluster: top.maKhuVuc.isEmpty ? cleanCluster : top.maKhuVuc,
            isOnline: isOnline,
            workload: load,
            reason: reason,
            isSameCluster: isSame
        )
    }
}
