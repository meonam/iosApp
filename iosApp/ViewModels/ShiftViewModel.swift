import SwiftUI

// MARK: - SHIFT VIEW MODEL (ĐỒNG BỘ 1:1 VỚI SHIFTSCHEDULESCREEN.KT TRÊN ANDROID)
@MainActor
public class ShiftViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var currentWeekSchedule: ShiftSchedule? = nil
    @Published public var currentWeekOffset: Int = 0 // 0: Tuần này, -1: Tuần trước, 1: Tuần sau
    @Published public var isLoading: Bool = false
    @Published public var isSaving: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId.isEmpty ? "SGCOOP" : companyId
        self.idToken = idToken
    }

    // Phân quyền chuẩn Android
    public var canEditShift: Bool {
        user.isAdmin || user.isSuperAdmin || user.isHelpDesk
    }

    public var canAccessSchedule: Bool {
        user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isManager || user.isTechnician || user.isSpecialist
    }

    // MARK: - TÍNH TOÁN NGÀY VÀ TUẦN THEO CHUẨN THỨ HAI ĐẦU TUẦN (ISO 8601 ĐỒNG BỘ ANDROID)
    public var currentMondayDate: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        cal.minimumDaysInFirstWeek = 4
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        // Calendar weekday: 1 = Sun, 2 = Mon, 3 = Tue, ... 7 = Sat
        let daysFromMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: cal.startOfDay(for: now)) ?? now
        return cal.date(byAdding: .weekOfYear, value: currentWeekOffset, to: thisMonday) ?? thisMonday
    }

    public var currentWeekId: String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let target = currentMondayDate
        let year = cal.component(.yearForWeekOfYear, from: target)
        let week = cal.component(.weekOfYear, from: target)
        return String(format: "%04d-W%02d", year, week)
    }

    public var currentWeekNumber: Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal.component(.weekOfYear, from: currentMondayDate)
    }

    public var fullDateKeys: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var keys: [String] = []
        let monday = currentMondayDate
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: monday) {
                keys.append(formatter.string(from: d))
            }
        }
        return keys
    }

    public var dateLabels: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        var labels: [String] = []
        let monday = currentMondayDate
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: monday) {
                labels.append(formatter.string(from: d))
            }
        }
        return labels
    }

    public var shortDateLabels: [String] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM"
        var labels: [String] = []
        let monday = currentMondayDate
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: monday) {
                labels.append(formatter.string(from: d))
            }
        }
        return labels
    }

    public var weekDateRangeLabel: String {
        let labels = shortDateLabels
        if labels.count >= 7 {
            return "\(labels.first!) - \(labels.last!)"
        }
        return ""
    }

    public var weekDisplayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        let monday = currentMondayDate
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
        return String(format: "Tuần %02d (%@ - %@)", currentWeekNumber, f.string(from: monday), f.string(from: sunday))
    }

    // MARK: - TẢI PHÂN CA TUẦN TỪ FIRESTORE (ĐỒNG BỘ 1:1 ANDROID lines 280-335 & 814-822)
    public func fetchShiftSchedule() {
        isLoading = true
        errorMessage = nil
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                self.isLoading = false
                // Template mặc định nếu tuần chưa được tạo: lấy KTV từ default template
                self.currentWeekSchedule = ShiftSchedule(
                    id: currentWeekId,
                    companyId: companyId,
                    weekStart: Int64(currentMondayDate.timeIntervalSince1970 * 1000),
                    entries: DEFAULT_KTVS
                )
                return
            }

            let shortKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
            let fKeys = self.fullDateKeys
            let dLabels = self.dateLabels
            let sLabels = self.shortDateLabels

            var parsedEntries: [ShiftEntry] = []

            // 1. Parse 'entries' array chuẩn 1:1 theo Android
            if let entriesObj = fields["entries"] as? [String: Any],
               let arrayVal = entriesObj["arrayValue"] as? [String: Any],
               let values = arrayVal["values"] as? [[String: Any]] {
                for item in values {
                    if let mapVal = item["mapValue"] as? [String: Any],
                       let subFields = mapVal["fields"] as? [String: Any] {
                        var empId = FirestoreHelper.getString(subFields["employeeId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let empName = FirestoreHelper.getString(subFields["employeeName"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let maKhuVuc = FirestoreHelper.getString(subFields["maKhuVuc"] as? [String: Any])
                        let donVi = FirestoreHelper.getString(subFields["donVi"] as? [String: Any])

                        // Standardize MNV if phone or empty
                        let isOldPhone = (empId.hasPrefix("0") && empId.count >= 9) || empId.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
                        if isOldPhone || empId.isEmpty || empId.contains("@") {
                            let std = lookupStandardKtvMnv(email: nil, fullName: empName)
                            if !std.isEmpty { empId = std }
                        }

                        var rawDays: [String: String] = [:]
                        if let daysObj = subFields["days"] as? [String: Any],
                           let daysMapVal = daysObj["mapValue"] as? [String: Any],
                           let dayFields = daysMapVal["fields"] as? [String: Any] {
                            for (dayKey, dayCodeVal) in dayFields {
                                let code = FirestoreHelper.getString(dayCodeVal as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !code.isEmpty {
                                    rawDays[dayKey.lowercased()] = code
                                }
                            }
                        }

                        // Bi-directional key synchronization: populate BOTH shortKeys ("mon") and fullDateKeys ("2026-09-14")
                        var daysMap: [String: String] = [:]
                        for (k, v) in rawDays {
                            daysMap[k] = v
                            for (dIdx, sk) in shortKeys.enumerated() {
                                let fk = fKeys.indices.contains(dIdx) ? fKeys[dIdx] : ""
                                let dl = dLabels.indices.contains(dIdx) ? dLabels[dIdx] : ""
                                let sl = sLabels.indices.contains(dIdx) ? sLabels[dIdx] : ""
                                let sdk = sl.replacingOccurrences(of: "/", with: "-")

                                if k == sk || k == fk || k == dl || k == sl || k == sdk || (fk.count >= 10 && k.hasSuffix(String(fk.suffix(5)))) {
                                    daysMap[sk] = v
                                    if !fk.isEmpty { daysMap[fk] = v }
                                    if !dl.isEmpty { daysMap[dl] = v }
                                    if !sl.isEmpty { daysMap[sl] = v }
                                }
                            }
                        }

                        if !empId.isEmpty || !empName.isEmpty {
                            parsedEntries.append(ShiftEntry(
                                employeeId: empId,
                                employeeName: empName,
                                days: daysMap,
                                maKhuVuc: maKhuVuc,
                                donVi: donVi
                            ))
                        }
                    }
                }
            }

            // 2. Fallback: Parse các key lẻ emp_ / ktv_
            if parsedEntries.isEmpty {
                for (key, valObj) in fields {
                    if key.starts(with: "emp_") || key.starts(with: "ktv_") || key.allSatisfy({ $0.isNumber }) {
                        if let map = (valObj as? [String: Any])?["mapValue"] as? [String: Any],
                           let subFields = map["fields"] as? [String: Any] {
                            var rawDays: [String: String] = [:]
                            for dayKey in shortKeys {
                                let code = FirestoreHelper.getString(subFields[dayKey] as? [String: Any])
                                if !code.isEmpty {
                                    rawDays[dayKey] = code
                                }
                            }
                            var daysMap: [String: String] = [:]
                            for (k, v) in rawDays {
                                daysMap[k] = v
                                if let idx = shortKeys.firstIndex(of: k), fKeys.indices.contains(idx) {
                                    daysMap[fKeys[idx]] = v
                                }
                            }
                            let empName = FirestoreHelper.getString(subFields["name"] as? [String: Any])
                            let cleanId = key.replacingOccurrences(of: "emp_", with: "").replacingOccurrences(of: "ktv_", with: "")
                            parsedEntries.append(ShiftEntry(employeeId: cleanId, employeeName: empName.isEmpty ? cleanId : empName, days: daysMap))
                        }
                    }
                }
            }

            if parsedEntries.isEmpty {
                parsedEntries = DEFAULT_KTVS
            }

            self.currentWeekSchedule = ShiftSchedule(
                id: currentWeekId,
                companyId: companyId,
                weekStart: Int64(currentMondayDate.timeIntervalSince1970 * 1000),
                entries: parsedEntries
            )
            self.isLoading = false
        }
    }

    // MARK: - CẬP NHẬT CA TRỰC CHO MỘT Ô (CELL)
    public func updateShiftCode(employeeId: String, dayKey: String, newCode: String) {
        let cleanDayKey = dayKey.lowercased()
        guard var currentEntries = self.currentWeekSchedule?.entries else { return }

        let shortKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let fKeys = self.fullDateKeys
        let dLabels = self.dateLabels
        let sLabels = self.shortDateLabels

        var matchedIdx: Int? = nil
        for (idx, sk) in shortKeys.enumerated() {
            let fk = fKeys.indices.contains(idx) ? fKeys[idx].lowercased() : ""
            if cleanDayKey == sk || cleanDayKey == fk {
                matchedIdx = idx
                break
            }
        }

        if let idx = currentEntries.firstIndex(where: { $0.employeeId == employeeId }) {
            if newCode.isEmpty {
                currentEntries[idx].days.removeValue(forKey: cleanDayKey)
                if let mIdx = matchedIdx {
                    currentEntries[idx].days.removeValue(forKey: shortKeys[mIdx])
                    if fKeys.indices.contains(mIdx) { currentEntries[idx].days.removeValue(forKey: fKeys[mIdx]) }
                    if dLabels.indices.contains(mIdx) { currentEntries[idx].days.removeValue(forKey: dLabels[mIdx]) }
                    if sLabels.indices.contains(mIdx) { currentEntries[idx].days.removeValue(forKey: sLabels[mIdx]) }
                }
            } else {
                currentEntries[idx].days[cleanDayKey] = newCode
                if let mIdx = matchedIdx {
                    currentEntries[idx].days[shortKeys[mIdx]] = newCode
                    if fKeys.indices.contains(mIdx) { currentEntries[idx].days[fKeys[mIdx]] = newCode }
                    if dLabels.indices.contains(mIdx) { currentEntries[idx].days[dLabels[mIdx]] = newCode }
                    if sLabels.indices.contains(mIdx) { currentEntries[idx].days[sLabels[mIdx]] = newCode }
                }
            }
            self.currentWeekSchedule?.entries = currentEntries
        }
    }

    // MARK: - THÊM KTV MỚI VÀO BẢNG PHÂN CA
    public func addEmployee(employeeId: String, employeeName: String, maKhuVuc: String = "", donVi: String = "") {
        guard var currentEntries = self.currentWeekSchedule?.entries else { return }
        let cleanId = employeeId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = employeeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty || !cleanName.isEmpty else { return }

        guard !currentEntries.contains(where: { $0.employeeId.lowercased() == cleanId.lowercased() }) else { return }

        currentEntries.append(ShiftEntry(
            employeeId: cleanId,
            employeeName: cleanName.isEmpty ? cleanId : cleanName,
            days: [:],
            maKhuVuc: maKhuVuc,
            donVi: donVi
        ))

        self.currentWeekSchedule?.entries = currentEntries
    }

    // MARK: - XÓA KTV KHỎI PHÂN CA
    public func deleteEmployee(employeeId: String) {
        guard var currentEntries = self.currentWeekSchedule?.entries else { return }
        currentEntries.removeAll { $0.employeeId == employeeId }
        self.currentWeekSchedule?.entries = currentEntries
    }

    // MARK: - GÁN CA NHANH (QUICK ASSIGN)
    public func quickAssign(targetEmployeeId: String?, shiftCode: String, days: [String]) {
        guard var currentEntries = self.currentWeekSchedule?.entries else { return }

        for idx in 0..<currentEntries.count {
            if targetEmployeeId == nil || currentEntries[idx].employeeId == targetEmployeeId {
                for d in days {
                    currentEntries[idx].days[d.lowercased()] = shiftCode
                }
            }
        }

        self.currentWeekSchedule?.entries = currentEntries
    }

    // MARK: - ĐỒNG BỘ DANH SÁCH KTV TỪ USER COLLECTION (GIỮ NGUYÊN CA ĐÃ GÁN)
    public func syncKtvUsers() async {
        guard !companyId.isEmpty else { return }
        isLoading = true
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/users?pageSize=100"
        guard let url = URL(string: urlStr) else { isLoading = false; return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            isLoading = false
            return
        }

        var fetchedKtvs: [ShiftEntry] = []
        for doc in documents {
            guard let fields = doc["fields"] as? [String: Any] else { continue }
            let role = FirestoreHelper.getString(fields["role"] as? [String: Any]).uppercased()
            let dept = FirestoreHelper.getString(fields["departmentId"] as? [String: Any]).uppercased()
            let dv = FirestoreHelper.getString(fields["donVi"] as? [String: Any]).uppercased()
            let toNv = FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any]).uppercased()
            let fullName = FirestoreHelper.getString(fields["fullName"] as? [String: Any])
            let mnv = FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any])
            let maKhuVuc = FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])

            let isTech = role.contains("KTV") || role.contains("KYTHUAT") || role.contains("TECH") ||
                         role.contains("CHUYENVIEN") || role.contains("SPECIALIST") ||
                         dept.contains("SỰ CỐ") || dept.contains("KỸ THUẬT") || dept.contains("IT") ||
                         dv.contains("KỸ THUẬT") || !toNv.isEmpty

            if isTech {
                let id = mnv.isEmpty ? String(fullName.prefix(6)) : mnv
                fetchedKtvs.append(ShiftEntry(
                    employeeId: id,
                    employeeName: fullName.isEmpty ? id : fullName,
                    days: [:],
                    maKhuVuc: maKhuVuc,
                    donVi: dv
                ))
            }
        }

        if !fetchedKtvs.isEmpty {
            var existingEntries = self.currentWeekSchedule?.entries ?? []
            for ktv in fetchedKtvs {
                if let existing = existingEntries.first(where: { $0.employeeId == ktv.employeeId || $0.employeeName == ktv.employeeName }) {
                    // Giữ nguyên ca đã gán
                    continue
                } else {
                    existingEntries.append(ktv)
                }
            }
            self.currentWeekSchedule?.entries = existingEntries
            self.successMessage = "Đã đồng bộ \(fetchedKtvs.count) nhân sự kỹ thuật!"
        }
        isLoading = false
    }

    // MARK: - SAO CHÉP PHÂN CA TỪ TUẦN TRƯỚC
    public func copyPreviousWeekSchedule() async {
        guard !companyId.isEmpty else { return }
        isLoading = true

        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let prevTarget = cal.date(byAdding: .weekOfYear, value: currentWeekOffset - 1, to: currentMondayDate) ?? currentMondayDate
        let prevYear = cal.component(.yearForWeekOfYear, from: prevTarget)
        let prevWeek = cal.component(.weekOfYear, from: prevTarget)
        let prevWeekId = String(format: "%04d-W%02d", prevYear, prevWeek)

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(prevWeekId)"
        guard let url = URL(string: urlStr) else { isLoading = false; return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any] else {
            isLoading = false
            self.errorMessage = "Không tìm thấy dữ liệu ca trực tuần trước (\(prevWeekId))."
            return
        }

        var prevEntries: [ShiftEntry] = []
        if let entriesObj = fields["entries"] as? [String: Any],
           let arrayVal = entriesObj["arrayValue"] as? [String: Any],
           let values = arrayVal["values"] as? [[String: Any]] {
            for item in values {
                if let mapVal = item["mapValue"] as? [String: Any],
                   let subFields = mapVal["fields"] as? [String: Any] {
                    let empId = FirestoreHelper.getString(subFields["employeeId"] as? [String: Any])
                    let empName = FirestoreHelper.getString(subFields["employeeName"] as? [String: Any])
                    let maKhuVuc = FirestoreHelper.getString(subFields["maKhuVuc"] as? [String: Any])
                    let donVi = FirestoreHelper.getString(subFields["donVi"] as? [String: Any])
                    
                    var daysMap: [String: String] = [:]
                    if let daysObj = subFields["days"] as? [String: Any],
                       let daysMapVal = daysObj["mapValue"] as? [String: Any],
                       let dayFields = daysMapVal["fields"] as? [String: Any] {
                        for (dayKey, dayCodeVal) in dayFields {
                            let code = FirestoreHelper.getString(dayCodeVal as? [String: Any])
                            if !code.isEmpty {
                                daysMap[dayKey.lowercased()] = code
                            }
                        }
                    }
                    prevEntries.append(ShiftEntry(employeeId: empId, employeeName: empName, days: daysMap, maKhuVuc: maKhuVuc, donVi: donVi))
                }
            }
        }

        if !prevEntries.isEmpty {
            self.currentWeekSchedule?.entries = prevEntries
            self.successMessage = "Đã sao chép phân ca từ tuần trước (\(prevWeekId))!"
        }
        isLoading = false
    }

    // MARK: - LƯU PHÂN CA TUẦN LÊN FIRESTORE
    public func saveSchedule() async {
        guard let entries = self.currentWeekSchedule?.entries else { return }
        isSaving = true
        errorMessage = nil

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/shift_schedules/\(currentWeekId)?updateMask.fieldPaths=entries&updateMask.fieldPaths=updatedAt&updateMask.fieldPaths=updatedBy&updateMask.fieldPaths=weekStart"
        guard let url = URL(string: urlStr) else { isSaving = false; return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var arrayValues: [[String: Any]] = []
        let shortKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        let fKeys = self.fullDateKeys

        for entry in entries {
            var dayFields: [String: Any] = [:]
            for (k, v) in entry.days {
                if !v.isEmpty {
                    dayFields[k.lowercased()] = ["stringValue": v]
                }
            }
            // Ensure both shortKey ("mon") and fullDateKey ("2026-09-14") are present
            for (dIdx, sk) in shortKeys.enumerated() {
                let fk = fKeys.indices.contains(dIdx) ? fKeys[dIdx] : ""
                let code = entry.days[sk] ?? (!fk.isEmpty ? entry.days[fk] : nil) ?? ""
                if !code.isEmpty {
                    dayFields[sk] = ["stringValue": code]
                    if !fk.isEmpty { dayFields[fk] = ["stringValue": code] }
                }
            }
            let entryMap: [String: Any] = [
                "mapValue": [
                    "fields": [
                        "employeeId": ["stringValue": entry.employeeId],
                        "employeeName": ["stringValue": entry.employeeName],
                        "maKhuVuc": ["stringValue": entry.maKhuVuc],
                        "donVi": ["stringValue": entry.donVi],
                        "days": [
                            "mapValue": [
                                "fields": dayFields
                            ]
                        ]
                    ]
                ]
            ]
            arrayValues.append(entryMap)
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let weekStartMillis = Int64(currentMondayDate.timeIntervalSince1970 * 1000)
        let body: [String: Any] = [
            "fields": [
                "weekStart": ["integerValue": String(weekStartMillis)],
                "entries": [
                    "arrayValue": [
                        "values": arrayValues
                    ]
                ],
                "updatedAt": ["integerValue": String(now)],
                "updatedBy": ["stringValue": user.email]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                self.successMessage = "✅ Đã lưu phân ca tuần thành công!"
            } else {
                let respStr = String(data: data, encoding: .utf8) ?? ""
                self.errorMessage = "Lỗi lưu: \(respStr)"
            }
        } catch {
            self.errorMessage = "Lỗi mạng khi lưu: \(error.localizedDescription)"
        }
        isSaving = false
    }

    // MARK: - XUẤT CSV LỊCH PHÂN CA
    public func exportCsvString() -> String {
        guard let entries = self.currentWeekSchedule?.entries else { return "" }
        var csv = "MNV,Ho Ten,Cum,\(dateLabels.joined(separator: ","))\n"
        let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
        for e in entries {
            let rowDays = dayKeys.map { e.days[$0] ?? "" }
            csv += "\"\(e.employeeId)\",\"\(e.employeeName)\",\"\(e.maKhuVuc)\",\(rowDays.joined(separator: ","))\n"
        }
        return csv
    }
}

// MARK: - DEFAULT KTV TEMPLATE (CHUẨN ANDROID)
public let DEFAULT_KTVS: [ShiftEntry] = [
    ShiftEntry(employeeId: "26063", employeeName: "Dam Huu Phuc", days: [:], maKhuVuc: "HCM_1", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "33430", employeeName: "Dinh Quoc Huy", days: [:], maKhuVuc: "HCM_3", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "NVDUCHN", employeeName: "Huỳnh Nguyễn Anh Đức", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "35713", employeeName: "Hồ Thân Khánh", days: [:], maKhuVuc: "HCM_BD", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "43144", employeeName: "Ngo Duy Linh", days: [:], maKhuVuc: "HCM_3", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "20972", employeeName: "Nguyen Minh Nhat", days: [:], maKhuVuc: "HCM_1", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "19842", employeeName: "Nguyen Thanh Sang", days: [:], maKhuVuc: "HCM_3", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "02104", employeeName: "Nguyễn Hữu Tín", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "NVHUNGN", employeeName: "Nguyễn Phước Hưng", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "24979", employeeName: "Nguyễn Trung Hiếu", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "31290", employeeName: "Pham Dinh Trong", days: [:], maKhuVuc: "HCM_3", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "NVHAPH", employeeName: "Phạm Hải Hà", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "28105", employeeName: "Tran Ba Tien", days: [:], maKhuVuc: "HCM_3", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "NVMINH", employeeName: "Tran Huy Minh", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "8564", employeeName: "Trần Minh Trình", days: [:], maKhuVuc: "HCM_1", donVi: "IT TẬP TRUNG"),
    ShiftEntry(employeeId: "00289", employeeName: "Trần Tiến Dũng", days: [:], maKhuVuc: "HCM_2", donVi: "IT TẬP TRUNG")
]
