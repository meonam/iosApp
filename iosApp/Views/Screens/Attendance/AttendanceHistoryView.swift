import SwiftUI

// MARK: - ATTENDANCE HISTORY VIEW (ĐỒNG BỘ 1:1 VỚI ATTENDANCEHISTORYSCREEN.KT TRÊN ANDROID)
public struct AttendanceHistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void

    @State private var selectedMonth: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f.string(from: Date())
    }()
    @State private var monthDropdownExpanded = false
    @State private var searchQuery: String = ""
    @State private var records: [AttendanceRecord] = []
    @State private var isLoading: Bool = false

    private let monthsList: [String] = {
        var list: [String] = []
        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        var d = Date()
        for _ in 0..<12 {
            list.append(f.string(from: d))
            if let prev = cal.date(byAdding: .month, value: -1, to: d) {
                d = prev
            }
        }
        return list
    }()

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }

    private var currentUser: User? { authViewModel.currentUser }
    private var userName: String {
        guard let u = currentUser else { return "" }
        return u.fullName.isEmpty ? u.email.components(separatedBy: "@").first ?? "" : u.fullName
    }
    private var userDept: String {
        guard let u = currentUser else { return "Kỹ thuật" }
        return u.departmentName.isEmpty ? (u.donVi.isEmpty ? "Kỹ thuật" : u.donVi) : u.departmentName
    }

    // Filtered records
    private var filteredRecords: [AttendanceRecord] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return records
        }
        let q = searchQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return records.filter { rec in
            rec.date.lowercased().contains(q) ||
            rec.note.lowercased().contains(q) ||
            rec.checkInAddress.lowercased().contains(q) ||
            rec.checkOutAddress.lowercased().contains(q)
        }
    }

    // KPI stats
    private var totalRecords: Int { records.count }
    private var onTimeCount: Int { records.filter { $0.checkInStatus == "ON_TIME" }.count }
    private var lateCount: Int { records.filter { $0.checkInStatus == "LATE" || $0.checkOutStatus == "EARLY" }.count }
    private var onTimePercent: Double {
        guard totalRecords > 0 else { return 0 }
        return (Double(onTimeCount) / Double(totalRecords)) * 100.0
    }
    private var totalWorkHours: Double {
        records.reduce(0.0) { sum, rec in
            if rec.totalWorkMinutes > 0 {
                return sum + Double(rec.totalWorkMinutes) / 60.0
            } else if rec.isCheckedIn && rec.isCheckedOut {
                let diffM = max(0, Double(rec.checkOutTime - rec.checkInTime) / 60000.0)
                return sum + (diffM / 60.0)
            }
            return sum
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR CHUẨN ANDROID (Xanh Đậm #002A8F)
                    topBarView(safeAreaTop: SafeAreaHelper.top(geometry))

                    // THANH LỌC THÁNG & Ô TÌM KIẾM
                    filterHeaderView

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "#F40266"))
                            .scaleEffect(1.2)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                // KPI TỔNG KẾT THÁNG
                                kpiSummarySection

                                // TIÊU ĐỀ DANH SÁCH
                                HStack {
                                    Text("📋 Chi Tiết Từng Ngày (\(filteredRecords.count) bản ghi)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#002A8F"))
                                    Spacer()
                                }
                                .padding(.top, 4)

                                // DANH SÁCH BẢN GHI
                                if filteredRecords.isEmpty {
                                    emptyView
                                } else {
                                    ForEach(filteredRecords) { record in
                                        recordCardView(record: record)
                                    }
                                }

                                Spacer(minLength: 32)
                            }
                            .padding(14)
                        }
                        .refreshable {
                            await loadDataAsync()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadData()
        }
    }

    // MARK: - TOP BAR
    private func topBarView(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Nhật Ký Chấm Công Cá Nhân")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    if !userName.isEmpty {
                        Text("\(userName) • \(userDept)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: { loadData() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
        }
        .background(Color(hex: "#002A8F"))
    }

    // MARK: - FILTER HEADER VIEW
    private var filterHeaderView: some View {
        VStack(spacing: 8) {
            // Hàng 1: Nút chọn tháng + Tổng số ngày
            HStack {
                Menu {
                    ForEach(monthsList, id: \.self) { m in
                        Button(action: {
                            selectedMonth = m
                            loadData()
                        }) {
                            HStack {
                                Text(m)
                                if m == selectedMonth {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#2563EB"))

                        Text("Tháng: \(selectedMonth)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#1E40AF"))

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#1E40AF"))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#93C5FD"), lineWidth: 1))
                }

                Spacer()

                Text("\(records.count) ngày đã chấm")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#16A34A"))
            }

            // Hàng 2: Ô tìm kiếm
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Color.appTextSecondary)

                TextField("Tìm theo ngày (vd: 2026-08-29), ghi chú...", text: $searchQuery)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color.appTextPrimary)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }
            .padding(10)
            .background(Color.appSurfaceVariant)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
    }

    // MARK: - KPI SUMMARY SECTION
    private var kpiSummarySection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                kpiCard(title: "Tổng Ngày Công", value: "\(totalRecords) ngày", icon: "calendar.badge.checkmark", iconColor: Color(hex: "#2563EB"), bg: Color.dynamic(light: "#EFF6FF", dark: "#1E293B"))
                kpiCard(title: "Tỷ Lệ Đúng Giờ", value: String(format: "%.0f%%", onTimePercent), icon: "checkmark.circle.fill", iconColor: Color(hex: "#16A34A"), bg: Color.dynamic(light: "#DCFCE7", dark: "#064E3B").opacity(0.35))
            }
            HStack(spacing: 10) {
                kpiCard(title: "Đi Muộn / Sớm", value: "\(lateCount) lần", icon: "exclamationmark.triangle.fill", iconColor: Color(hex: "#D97706"), bg: Color.dynamic(light: "#FEF3C7", dark: "#78350F").opacity(0.35))
                kpiCard(title: "Tổng Giờ Làm", value: String(format: "%.1f giờ", totalWorkHours), icon: "hourglass", iconColor: Color(hex: "#7C3AED"), bg: Color.dynamic(light: "#F3E8FF", dark: "#581C87").opacity(0.35))
            }
        }
    }

    private func kpiCard(title: String, value: String, icon: String, iconColor: Color, bg: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 16, weight: .bold)).foregroundColor(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 14.5, weight: .black))
                    .foregroundColor(Color.appTextPrimary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(bg)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - RECORD CARD VIEW
    private func recordCardView(record: AttendanceRecord) -> some View {
        let isToday: Bool = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return record.date == f.string(from: Date())
        }()

        return VStack(spacing: 10) {
            // Hàng 1: Ngày, Nhãn Ca, Lịch, Trạng thái
            HStack {
                HStack(spacing: 6) {
                    Text(record.date)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    // Ca ngày / đêm
                    Text(record.isNightShift ? "🌙 Ca đêm" : "☀️ Ca ngày")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(record.isNightShift ? Color(hex: "#7C3AED") : Color(hex: "#2563EB"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(record.isNightShift ? Color(hex: "#EDE9FE") : Color(hex: "#EFF6FF"))
                        .cornerRadius(4)

                    // Phân ca
                    if !record.scheduledShiftCode.isEmpty {
                        Text(record.isUnscheduled ? "Ngoài lịch (\(record.scheduledShiftCode))" : "Lịch: \(record.scheduledShiftCode)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(record.isUnscheduled ? Color(hex: "#DC2626") : Color(hex: "#7E22CE"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(record.isUnscheduled ? Color(hex: "#FEE2E2") : Color(hex: "#F3E8FF"))
                            .cornerRadius(4)
                    } else if record.isUnscheduled {
                        Text("Ngoài lịch")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#B45309"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#FEF3C7"))
                            .cornerRadius(4)
                    }

                    if isToday {
                        Text("Hôm nay")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#16A34A"))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                let onTime = record.checkInStatus == "ON_TIME"
                Text(onTime ? "✅ Đúng giờ" : "⚠️ Đi muộn")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(onTime ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(onTime ? Color.dynamic(light: "#DCFCE7", dark: "#064E3B").opacity(0.4) : Color.dynamic(light: "#FEF3C7", dark: "#78350F").opacity(0.4))
                    .cornerRadius(6)
            }

            Divider().background(Color.appDivider)

            // Hàng 2: Giờ Vào & Giờ Ra & Tổng Giờ
            HStack {
                // Vào ca
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(record.isNightShift ? Color(hex: "#7C3AED") : Color(hex: "#16A34A"))
                            .frame(width: 8, height: 8)
                        Text(record.isNightShift ? "Vào ca (Đêm)" : "Vào ca (Sáng)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Text(record.checkInTimeFormatted)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(record.isNightShift ? Color(hex: "#6D28D9") : Color(hex: "#15803D"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Tan ca
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "#2563EB"))
                            .frame(width: 8, height: 8)
                        Text(record.isNightShift ? "Tan ca (Đêm)" : "Tan ca (Chiều)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    Text(record.checkOutTimeFormatted)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(Color(hex: "#1D4ED8"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Tổng giờ
                VStack(alignment: .trailing, spacing: 2) {
                    Text("⏱️ Tổng giờ")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                    Text(record.workHoursFormatted)
                        .font(.system(size: 14.5, weight: .heavy))
                        .foregroundColor(Color.appTextPrimary)
                }
            }

            // Ghi chú & Địa chỉ nếu có
            if !record.note.isEmpty || !record.checkInAddress.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    if !record.note.isEmpty {
                        HStack(spacing: 4) {
                            Text("📝")
                            Text(record.note)
                                .font(.system(size: 11.5))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                    if !record.checkInAddress.isEmpty {
                        HStack(spacing: 4) {
                            Text("📍")
                            Text(record.checkInAddress)
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextMuted)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(Color.appSurfaceVariant)
                .cornerRadius(6)
            }
        }
        .padding(14)
        .background(isToday ? Color.dynamic(light: "#F0FDF4", dark: "#064E3B").opacity(0.35) : Color.appSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isToday ? Color(hex: "#10B981") : Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundColor(Color.appTextMuted)

            Text("Không có dữ liệu chấm công cho kỳ \(selectedMonth)")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - LOAD DATA
    private func loadData() {
        Task { await loadDataAsync() }
    }

    private func loadDataAsync() async {
        let comp = authViewModel.currentCompanyId.uppercased()
        let token = authViewModel.currentIdToken ?? ""
        let email = authViewModel.currentUser?.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !comp.isEmpty, !token.isEmpty, !email.isEmpty else { return }

        DispatchQueue.main.async { self.isLoading = true }

        let queryUrlStr = "\(FirebaseConfig.firestoreBaseUrl):runQuery"
        guard let queryUrl = URL(string: queryUrlStr) else {
            DispatchQueue.main.async { self.isLoading = false }
            return
        }

        var req = URLRequest(url: queryUrl)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "attendances"]],
                "where": [
                    "compositeFilter": [
                        "op": "AND",
                        "filters": [
                            [
                                "fieldFilter": [
                                    "field": ["fieldPath": "userEmail"],
                                    "op": "EQUAL",
                                    "value": ["stringValue": email]
                                ]
                            ]
                        ]
                    ]
                ],
                "orderBy": [
                    [
                        "field": ["fieldPath": "date"],
                        "direction": "DESCENDING"
                    ]
                ]
            ],
            "parent": "projects/\(FirebaseConfig.projectId)/databases/(default)/documents/companies/\(comp)"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        var list: [AttendanceRecord] = []
        if let (data, resp) = try? await URLSession.shared.data(for: req),
           let http = resp as? HTTPURLResponse, http.statusCode == 200,
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {

            for item in arr {
                if let doc = item["document"] as? [String: Any],
                   let f = doc["fields"] as? [String: Any],
                   let docName = doc["name"] as? String {

                    let d = FirestoreHelper.getString(f["date"] as? [String: Any])
                    if d.hasPrefix(selectedMonth) {
                        let docId = docName.components(separatedBy: "/").last ?? ""
                        let rec = AttendanceRecord(
                            id: docId,
                            userEmail: FirestoreHelper.getString(f["userEmail"] as? [String: Any]),
                            userName: FirestoreHelper.getString(f["userName"] as? [String: Any]),
                            userPhone: FirestoreHelper.getString(f["userPhone"] as? [String: Any]),
                            maNhanVien: FirestoreHelper.getString(f["maNhanVien"] as? [String: Any]),
                            employeeId: FirestoreHelper.getString(f["employeeId"] as? [String: Any]),
                            departmentId: FirestoreHelper.getString(f["departmentId"] as? [String: Any]),
                            departmentName: FirestoreHelper.getString(f["departmentName"] as? [String: Any]),
                            donVi: FirestoreHelper.getString(f["donVi"] as? [String: Any]),
                            date: d,
                            checkInTime: FirestoreHelper.getInt64(f["checkInTime"] as? [String: Any]),
                            checkInLat: FirestoreHelper.getDouble(f["checkInLat"] as? [String: Any]),
                            checkInLng: FirestoreHelper.getDouble(f["checkInLng"] as? [String: Any]),
                            checkInAddress: FirestoreHelper.getString(f["checkInAddress"] as? [String: Any]),
                            checkInStatus: FirestoreHelper.getString(f["checkInStatus"] as? [String: Any]),
                            checkOutTime: FirestoreHelper.getInt64(f["checkOutTime"] as? [String: Any]),
                            checkOutLat: FirestoreHelper.getDouble(f["checkOutLat"] as? [String: Any]),
                            checkOutLng: FirestoreHelper.getDouble(f["checkOutLng"] as? [String: Any]),
                            checkOutAddress: FirestoreHelper.getString(f["checkOutAddress"] as? [String: Any]),
                            checkOutStatus: FirestoreHelper.getString(f["checkOutStatus"] as? [String: Any]),
                            totalWorkMinutes: FirestoreHelper.getInt(f["totalWorkMinutes"] as? [String: Any]),
                            note: FirestoreHelper.getString(f["note"] as? [String: Any]),
                            companyId: comp,
                            shiftType: FirestoreHelper.getString(f["shiftType"] as? [String: Any]),
                            scheduledShiftCode: FirestoreHelper.getString(f["scheduledShiftCode"] as? [String: Any]),
                            isUnscheduled: (f["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                        )
                        list.append(rec)
                    }
                }
            }
        }

        // Fallback đọc trực tiếp
        if list.isEmpty {
            let listUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/attendances?pageSize=300"
            if let listUrl = URL(string: listUrlStr) {
                var listReq = URLRequest(url: listUrl)
                listReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if let (data, resp) = try? await URLSession.shared.data(for: listReq),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {

                    for doc in docs {
                        if let f = doc["fields"] as? [String: Any],
                           let docName = doc["name"] as? String {
                            let docEmail = FirestoreHelper.getString(f["userEmail"] as? [String: Any])
                            let d = FirestoreHelper.getString(f["date"] as? [String: Any])
                            if docEmail.caseInsensitiveCompare(email) == .orderedSame && d.hasPrefix(selectedMonth) {
                                let docId = docName.components(separatedBy: "/").last ?? ""
                                let rec = AttendanceRecord(
                                    id: docId,
                                    userEmail: docEmail,
                                    userName: FirestoreHelper.getString(f["userName"] as? [String: Any]),
                                    userPhone: FirestoreHelper.getString(f["userPhone"] as? [String: Any]),
                                    maNhanVien: FirestoreHelper.getString(f["maNhanVien"] as? [String: Any]),
                                    employeeId: FirestoreHelper.getString(f["employeeId"] as? [String: Any]),
                                    departmentId: FirestoreHelper.getString(f["departmentId"] as? [String: Any]),
                                    departmentName: FirestoreHelper.getString(f["departmentName"] as? [String: Any]),
                                    donVi: FirestoreHelper.getString(f["donVi"] as? [String: Any]),
                                    date: d,
                                    checkInTime: FirestoreHelper.getInt64(f["checkInTime"] as? [String: Any]),
                                    checkInLat: FirestoreHelper.getDouble(f["checkInLat"] as? [String: Any]),
                                    checkInLng: FirestoreHelper.getDouble(f["checkInLng"] as? [String: Any]),
                                    checkInAddress: FirestoreHelper.getString(f["checkInAddress"] as? [String: Any]),
                                    checkInStatus: FirestoreHelper.getString(f["checkInStatus"] as? [String: Any]),
                                    checkOutTime: FirestoreHelper.getInt64(f["checkOutTime"] as? [String: Any]),
                                    checkOutLat: FirestoreHelper.getDouble(f["checkOutLat"] as? [String: Any]),
                                    checkOutLng: FirestoreHelper.getDouble(f["checkOutLng"] as? [String: Any]),
                                    checkOutAddress: FirestoreHelper.getString(f["checkOutAddress"] as? [String: Any]),
                                    checkOutStatus: FirestoreHelper.getString(f["checkOutStatus"] as? [String: Any]),
                                    totalWorkMinutes: FirestoreHelper.getInt(f["totalWorkMinutes"] as? [String: Any]),
                                    note: FirestoreHelper.getString(f["note"] as? [String: Any]),
                                    companyId: comp,
                                    shiftType: FirestoreHelper.getString(f["shiftType"] as? [String: Any]),
                                    scheduledShiftCode: FirestoreHelper.getString(f["scheduledShiftCode"] as? [String: Any]),
                                    isUnscheduled: (f["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                                )
                                list.append(rec)
                            }
                        }
                    }
                }
            }
        }

        list.sort { $0.date > $1.date }

        DispatchQueue.main.async {
            self.records = list
            self.isLoading = false
        }
    }
}
