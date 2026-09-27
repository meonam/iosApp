import SwiftUI
import CoreLocation

// MARK: - ATTENDANCE VIEW MODEL (ĐỒNG BỘ 1:1 VỚI ATTENDANCECHECKINSCREEN.KT & ATTENDANCEREPOSITORY.KT TRÊN ANDROID)
@MainActor
public class AttendanceViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    public var user: User
    public var companyId: String
    public var idToken: String

    // Realtime Clock & Vietnamese Date (Đồng bộ Android lines 200-207)
    @Published public var currentTimeString: String = ""
    @Published public var currentDateString: String = ""
    private var clockTimer: Timer? = nil

    // User Profile Cache (Đồng bộ Android lines 284-338)
    @Published public var userName: String = ""
    @Published public var userMnv: String = ""
    @Published public var userDeptId: String = ""
    @Published public var userDeptName: String = ""
    @Published public var userDonVi: String = ""
    @Published public var userRole: String = ""
    @Published public var profileImageUrl: String = ""

    // Records & Active Shift (Đồng bộ Android lines 120-135)
    @Published public var todayRecord: AttendanceRecord? = nil
    @Published public var selectedShiftType: String = "HC" // "HC", "SHIFT_1", "SHIFT_2", "NIGHT"
    @Published public var scheduledShiftCode: String = "" // "S", "C", "HC", "TR", "NC", "P", "NL"
    @Published public var scheduledShiftLabel: String = ""
    @Published public var isScheduledOffDay: Bool = false
    @Published public var totalMonthDays: Int = 0
    @Published public var noteInput: String = ""

    // GPS & Geofence (Đồng bộ Android lines 209-270)
    @Published public var currentLocation: CLLocationCoordinate2D? = nil
    @Published public var currentAddress: String = "Đang xác định vị trí GPS..."
    @Published public var isLocating: Bool = false
    @Published public var travelConfig: TravelExpenseConfig = TravelExpenseConfig()
    @Published public var distanceToWorkMeters: Double? = nil
    @Published public var isWithinGeofence: Bool = true
    @Published public var isLoadingConfig: Bool = false

    // Geofence Blocking Alert (Đồng bộ Android lines 247-270 & 1956-2007)
    @Published public var showGeofenceAlert: Bool = false
    @Published public var geofenceAlertTitle: String = ""
    @Published public var geofenceAlertMessage: String = ""

    // Actions & Feedback
    @Published public var isSubmitting: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var successMessage: String? = nil
    @Published public var errorMessage: String? = nil

    // History (Đồng bộ AttendanceHistoryScreen.kt)
    @Published public var attendanceHistory: [AttendanceRecord] = []
    @Published public var isLoadingHistory: Bool = false
    @Published public var selectedMonth: Date = Date()

    // Computed Stats
    public var totalDays: Int { attendanceHistory.count }
    public var lateDays: Int { attendanceHistory.filter { $0.checkInStatus == "LATE" }.count }
    public var earlyDays: Int { attendanceHistory.filter { $0.checkOutStatus == "EARLY" }.count }
    public var onTimeDays: Int { attendanceHistory.filter { $0.checkInStatus == "ON_TIME" }.count }

    private let locationManager = CLLocationManager()

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.idToken = idToken
        self.userName = user.fullName.isEmpty ? user.email.components(separatedBy: "@").first ?? "" : user.fullName
        self.userMnv = user.maNhanVien
        self.userDeptId = user.departmentId
        self.userDeptName = user.departmentName
        self.userDonVi = user.donVi
        self.userRole = user.role
        super.init()

        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.selectedShiftType = Self.autoDetectShiftType()

        startClockTimer()
    }

    deinit {
        clockTimer?.invalidate()
    }

    // MARK: - REALTIME CLOCK (ĐỒNG BỘ ANDROID lines 200-207)
    public func startClockTimer() {
        clockTimer?.invalidate()
        updateClockStrings()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateClockStrings()
            }
        }
    }

    private func updateClockStrings() {
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        currentTimeString = timeFormatter.string(from: now)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")
        dateFormatter.dateFormat = "EEEE, dd/MM/yyyy"
        let rawDateStr = dateFormatter.string(from: now)
        currentDateString = rawDateStr.prefix(1).capitalized + rawDateStr.dropFirst()
    }

    // MARK: - AUTO DETECT CA (ĐỒNG BỘ ANDROID AttendanceCheckInScreen.kt)
    public static func autoDetectShiftType() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour <= 12 { return "HC" }
        else if hour >= 13 && hour <= 20 { return "SHIFT_2" }
        else { return "NIGHT" }
    }

    // MARK: - GPS & LOCATION
    public func startUpdatingLocation() {
        isLocating = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    public func refreshLocation() {
        startUpdatingLocation()
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc.coordinate
            self.isLocating = false
            self.locationManager.stopUpdatingLocation()

            self.calculateGeofenceDistance(loc: loc.coordinate)

            // Reverse Geocoding
            CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
                if let p = placemarks?.first {
                    let parts = [p.name, p.subLocality, p.locality, p.administrativeArea]
                        .compactMap { $0 }
                        .filter { !$0.isEmpty }
                    let addr = parts.joined(separator: ", ")
                    Task { @MainActor in
                        self.currentAddress = addr.isEmpty
                            ? String(format: "Tọa độ: %.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude)
                            : addr
                    }
                } else {
                    Task { @MainActor in
                        self.currentAddress = String(format: "Tọa độ: %.5f, %.5f", loc.coordinate.latitude, loc.coordinate.longitude)
                    }
                }
            }
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.isLocating = false
            self.currentAddress = "Chưa có tín hiệu GPS. Vui lòng bật Định vị."
        }
    }

    private func calculateGeofenceDistance(loc: CLLocationCoordinate2D) {
        if travelConfig.targetLatitude != 0 && travelConfig.targetLongitude != 0 {
            let current = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            let target = CLLocation(latitude: travelConfig.targetLatitude, longitude: travelConfig.targetLongitude)
            let dist = current.distance(from: target)
            self.distanceToWorkMeters = dist
            self.isWithinGeofence = dist <= travelConfig.geofenceRadiusMeters
        } else {
            self.distanceToWorkMeters = nil
            self.isWithinGeofence = true
        }
    }

    // MARK: - VALIDATE LOCATION FOR ATTENDANCE (ĐỒNG BỘ ANDROID lines 247-270)
    public func validateLocationForAttendance() -> Bool {
        if !travelConfig.strictGeofenceBlocking {
            return true
        }

        guard let loc = currentLocation, loc.latitude != 0, loc.longitude != 0 else {
            geofenceAlertTitle = "Chưa Có Tín Hiệu GPS"
            geofenceAlertMessage = "Không xác định được vị trí GPS hiện tại của thiết bị.\n\nVui lòng bật Vị trí (GPS) trên iPhone và bấm 'Cập nhật GPS' để hệ thống xác thực trước khi điểm danh."
            showGeofenceAlert = true
            return false
        }

        if travelConfig.targetLatitude != 0 && travelConfig.targetLongitude != 0 {
            let current = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            let target = CLLocation(latitude: travelConfig.targetLatitude, longitude: travelConfig.targetLongitude)
            let dist = current.distance(from: target)
            if dist > travelConfig.geofenceRadiusMeters {
                let targetAddr = travelConfig.targetAddress.isEmpty ? "Trụ sở công ty" : travelConfig.targetAddress
                geofenceAlertTitle = "Ngoài Vùng Chấm Công Hợp Lệ"
                geofenceAlertMessage = "Bạn đang ở cách địa điểm làm việc quy định \(Int(dist))m (vượt quá bán kính cho phép \(Int(travelConfig.geofenceRadiusMeters))m).\n\n📍 Điểm làm việc chuẩn: \(targetAddr)\n\nVui lòng di chuyển đến đúng vị trí để điểm danh ca làm việc!"
                showGeofenceAlert = true
                return false
            }
        }
        return true
    }

    // MARK: - LOAD INITIAL DATA
    public func loadInitialData() {
        Task {
            isLoading = true
            fetchUserProfileRealtime()
            fetchTravelExpenseConfig()
            fetchWeeklyShiftSchedule()
            fetchTodayAttendance()
            fetchUserMonthAttendanceCount()
            if travelConfig.autoCaptureGpsOnOpen {
                refreshLocation()
            }
            isLoading = false
        }
    }

    // MARK: - FETCH USER PROFILE REALTIME (ĐỒNG BỘ ANDROID lines 531-586)
    public func fetchUserProfileRealtime() {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanComp.isEmpty, !cleanEmail.isEmpty else { return }

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/users/\(cleanEmail)"
            guard let url = URL(string: urlStr) else { return }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {

                let name = FirestoreHelper.getString(fields["fullName"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["name"] as? [String: Any]) : FirestoreHelper.getString(fields["fullName"] as? [String: Any])
                let mnv = FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["employeeId"] as? [String: Any]) : FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any])
                let dept = FirestoreHelper.getString(fields["departmentId"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["phongBan"] as? [String: Any]) : FirestoreHelper.getString(fields["departmentId"] as? [String: Any])
                let donVi = FirestoreHelper.getString(fields["donVi"] as? [String: Any])
                let role = FirestoreHelper.getString(fields["role"] as? [String: Any])
                let avatar = FirestoreHelper.getString(fields["profileImageUrl"] as? [String: Any])
                    .isEmpty ? FirestoreHelper.getString(fields["avatarUrl"] as? [String: Any]) : FirestoreHelper.getString(fields["profileImageUrl"] as? [String: Any])

                await MainActor.run {
                    if !name.isEmpty { self.userName = name }
                    if !mnv.isEmpty { self.userMnv = mnv }
                    if !dept.isEmpty { self.userDeptId = dept; self.userDeptName = dept }
                    if !donVi.isEmpty { self.userDonVi = donVi }
                    if !role.isEmpty { self.userRole = role }
                    if !avatar.isEmpty { self.profileImageUrl = avatar }
                }
            }
        }
    }

    // MARK: - FETCH TRAVEL EXPENSE CONFIG (ĐỒNG BỘ ANDROID lines 502-530)
    public func fetchTravelExpenseConfig() {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanComp.isEmpty else { return }

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/system_config/travel_expense_config"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {

                var cfg = TravelExpenseConfig()
                cfg.standardCheckInTime = FirestoreHelper.getString(fields["standardCheckInTime"] as? [String: Any])
                if cfg.standardCheckInTime.isEmpty { cfg.standardCheckInTime = "08:00" }
                cfg.standardCheckOutTime = FirestoreHelper.getString(fields["standardCheckOutTime"] as? [String: Any])
                if cfg.standardCheckOutTime.isEmpty { cfg.standardCheckOutTime = "17:00" }

                cfg.shift1CheckInTime = FirestoreHelper.getString(fields["shift1CheckInTime"] as? [String: Any])
                if cfg.shift1Check1InTimeEmpty(cfg.shift1CheckInTime) { cfg.shift1CheckInTime = "07:00" }
                cfg.shift1CheckOutTime = FirestoreHelper.getString(fields["shift1CheckOutTime"] as? [String: Any])
                if cfg.shift1CheckOutTime.isEmpty { cfg.shift1CheckOutTime = "15:00" }

                cfg.shift2CheckInTime = FirestoreHelper.getString(fields["shift2CheckInTime"] as? [String: Any])
                if cfg.shift2CheckInTime.isEmpty { cfg.shift2CheckInTime = "14:00" }
                cfg.shift2CheckOutTime = FirestoreHelper.getString(fields["shift2CheckOutTime"] as? [String: Any])
                if cfg.shift2CheckOutTime.isEmpty { cfg.shift2CheckOutTime = "22:00" }

                cfg.nightCheckInTime = FirestoreHelper.getString(fields["nightCheckInTime"] as? [String: Any])
                if cfg.nightCheckInTime.isEmpty { cfg.nightCheckInTime = "22:00" }
                cfg.nightCheckOutTime = FirestoreHelper.getString(fields["nightCheckOutTime"] as? [String: Any])
                if cfg.nightCheckOutTime.isEmpty { cfg.nightCheckOutTime = "06:00" }

                let lateM = FirestoreHelper.getInt(fields["maxCheckInLateMinutes"] as? [String: Any])
                cfg.maxCheckInLateMinutes = lateM > 0 ? lateM : 15

                let radius = FirestoreHelper.getDouble(fields["geofenceRadiusMeters"] as? [String: Any])
                cfg.geofenceRadiusMeters = radius > 0 ? radius : 250.0

                cfg.targetLatitude = FirestoreHelper.getDouble(fields["targetLatitude"] as? [String: Any])
                cfg.targetLongitude = FirestoreHelper.getDouble(fields["targetLongitude"] as? [String: Any])
                cfg.targetAddress = FirestoreHelper.getString(fields["targetAddress"] as? [String: Any])
                cfg.strictGeofenceBlocking = (fields["strictGeofenceBlocking"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                cfg.autoCaptureGpsOnOpen = (fields["autoCaptureGpsOnOpen"] as? [String: Any])?["booleanValue"] as? Bool ?? true

                await MainActor.run {
                    self.travelConfig = cfg
                    if let loc = self.currentLocation {
                        self.calculateGeofenceDistance(loc: loc)
                    }
                }
            }
        }
    }

    private func shift1Check1InTimeEmpty(_ s: String) -> Bool {
        return s.isEmpty
    }

    // MARK: - FETCH WEEKLY SHIFT SCHEDULE (ĐỒNG BỘ ANDROID lines 339-460 & 588-696)
    public func fetchWeeklyShiftSchedule() {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanComp.isEmpty, !cleanEmail.isEmpty else { return }

        // Tính ID Tuần ISO: yyyy-Www (Ví dụ: 2026-W39)
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Thứ 2
        cal.minimumDaysInFirstWeek = 4
        let now = Date()
        let week = cal.component(.weekOfYear, from: now)
        let year = cal.component(.yearForWeekOfYear, from: now)
        let weekId = String(format: "%04d-W%02d", year, week)

        // Các key ngày hôm nay
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let todayDateKey = dateFmt.string(from: now)
        dateFmt.dateFormat = "dd/MM/yyyy"
        let todayDdMmYyyy = dateFmt.string(from: now)

        let weekday = cal.component(.weekday, from: now)
        let todayKey: String = {
            switch weekday {
            case 2: return "mon"
            case 3: return "tue"
            case 4: return "wed"
            case 5: return "thu"
            case 6: return "fri"
            case 7: return "sat"
            default: return "sun"
            }
        }()
        let todayKeyVi: String = {
            switch weekday {
            case 2: return "T2"
            case 3: return "T3"
            case 4: return "T4"
            case 5: return "T5"
            case 6: return "T6"
            case 7: return "T7"
            default: return "CN"
            }
        }()

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/shift_schedules/\(weekId)"
            guard let url = URL(string: urlStr) else { return }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let entriesArray = (fields["entries"] as? [String: Any])?["arrayValue"] as? [String: Any],
               let values = entriesArray["values"] as? [[String: Any]] {

                let emailPrefix = cleanEmail.components(separatedBy: "@").first ?? ""
                let cleanUserName = stripAccents(self.userName)
                let cleanMnv = self.userMnv.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

                var foundCode = ""

                for val in values {
                    guard let itemFields = (val["mapValue"] as? [String: Any])?["fields"] as? [String: Any] else { continue }
                    let empId = FirestoreHelper.getString(itemFields["employeeId"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let empName = FirestoreHelper.getString(itemFields["employeeName"] as? [String: Any]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let empEmail = FirestoreHelper.getString(itemFields["employeeEmail"] as? [String: Any])
                        .isEmpty ? FirestoreHelper.getString(itemFields["email"] as? [String: Any]) : FirestoreHelper.getString(itemFields["employeeEmail"] as? [String: Any])
                    let cleanEmpEmail = empEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                    let cleanEmpName = self.stripAccents(empName)
                    let cleanEmpId = empId.uppercased()

                    let matchEmail = !cleanEmpEmail.isEmpty && cleanEmpEmail == cleanEmail
                    let matchId = !cleanMnv.isEmpty && (
                        cleanEmpId == cleanMnv ||
                        empId.uppercased() == cleanMnv ||
                        cleanEmpId.hasSuffix(cleanMnv) ||
                        cleanMnv.hasSuffix(cleanEmpId)
                    )
                    let matchName = !empName.isEmpty && (
                        empName.caseInsensitiveCompare(self.userName) == .orderedSame ||
                        cleanEmpName == cleanUserName
                    )
                    let matchPrefix = !emailPrefix.isEmpty && (
                        cleanEmpName == emailPrefix ||
                        empId.lowercased() == emailPrefix
                    )
                    let matchPartial = cleanUserName.count >= 3 && cleanEmpName.count >= 3 && (
                        cleanEmpName.contains(cleanUserName) || cleanUserName.contains(cleanEmpName)
                    )

                    if matchEmail || matchId || matchName || matchPrefix || matchPartial {
                        if let daysMap = (itemFields["days"] as? [String: Any])?["mapValue"] as? [String: Any],
                           let dayFields = daysMap["fields"] as? [String: Any] {
                            let rawCode = FirestoreHelper.getString(dayFields[todayDateKey] as? [String: Any])
                                .isEmpty ? FirestoreHelper.getString(dayFields[todayKey] as? [String: Any])
                                : FirestoreHelper.getString(dayFields[todayDateKey] as? [String: Any])
                            let fallbackCode = rawCode.isEmpty ? FirestoreHelper.getString(dayFields[todayDdMmYyyy] as? [String: Any]) : rawCode
                            let finalCode = fallbackCode.isEmpty ? FirestoreHelper.getString(dayFields[todayKeyVi] as? [String: Any]) : fallbackCode
                            foundCode = finalCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                            break
                        }
                    }
                }

                await MainActor.run {
                    self.scheduledShiftCode = foundCode
                    if !foundCode.isEmpty {
                        self.scheduledShiftLabel = ShiftCode.label(foundCode)
                        switch foundCode {
                        case ShiftCode.SANG:
                            self.selectedShiftType = "SHIFT_1"
                            self.isScheduledOffDay = false
                        case ShiftCode.CHIEU:
                            self.selectedShiftType = "SHIFT_2"
                            self.isScheduledOffDay = false
                        case ShiftCode.HANH_CHANH, ShiftCode.CONG_TAC, ShiftCode.HOP:
                            self.selectedShiftType = "HC"
                            self.isScheduledOffDay = false
                        case ShiftCode.TRUC:
                            self.selectedShiftType = "NIGHT"
                            self.isScheduledOffDay = false
                        case ShiftCode.NGHI_CA, ShiftCode.PHEP, ShiftCode.NGHI_LE, ShiftCode.NGHI_MAT:
                            self.isScheduledOffDay = true
                        default:
                            self.isScheduledOffDay = false
                        }
                    }
                }
            }
        }
    }

    private func stripAccents(_ s: String) -> String {
        return s.folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "d")
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - TODAY ATTENDANCE (ĐỒNG BỘ ANDROID lines 119-215)
    public var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public var todayDocId: String {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanDate = todayDateString.replacingOccurrences(of: "-", with: "")
        let shift = selectedShiftType.isEmpty ? "HC" : selectedShiftType
        return "att_\(cleanDate)_\(cleanEmail)_\(shift)"
    }

    public func fetchTodayAttendance() {
        Task {
            let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanDate = todayDateString.replacingOccurrences(of: "-", with: "")
            let shift = selectedShiftType.isEmpty ? "HC" : selectedShiftType

            var docIdsToTry = [
                "att_\(cleanDate)_\(cleanEmail)_\(shift)"
            ]

            // Nếu là ca đêm và đang là buổi sáng, thử kiểm tra ca đêm hôm qua (Android lines 135-158)
            let hour = Calendar.current.component(.hour, from: Date())
            if (shift == "NIGHT" || shift == "SHIFT_3") && hour < 14 {
                if let yest = Calendar.current.date(byAdding: .day, value: -1, to: Date()) {
                    let yFmt = DateFormatter()
                    yFmt.dateFormat = "yyyyMMdd"
                    let yStr = yFmt.string(from: yest)
                    docIdsToTry.append("att_\(yStr)_\(cleanEmail)_\(shift)")
                    docIdsToTry.append("att_\(yStr)_\(cleanEmail)_NIGHT")
                }
            }

            // Fallback định dạng cũ
            if shift == "HC" || shift == "DAY" {
                docIdsToTry.append("att_\(cleanDate)_\(cleanEmail)_DAY")
                docIdsToTry.append("att_\(cleanDate)_\(cleanEmail)")
            }

            for docId in docIdsToTry {
                let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(docId)"
                guard let url = URL(string: urlStr) else { continue }

                var req = URLRequest(url: url)
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   let http = resp as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {

                    let rec = AttendanceRecord(
                        id: docId,
                        userEmail: FirestoreHelper.getString(fields["userEmail"] as? [String: Any]).isEmpty ? cleanEmail : FirestoreHelper.getString(fields["userEmail"] as? [String: Any]),
                        userName: FirestoreHelper.getString(fields["userName"] as? [String: Any]),
                        userPhone: FirestoreHelper.getString(fields["userPhone"] as? [String: Any]),
                        maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                        employeeId: FirestoreHelper.getString(fields["employeeId"] as? [String: Any]),
                        departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                        departmentName: FirestoreHelper.getString(fields["departmentName"] as? [String: Any]),
                        donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                        date: FirestoreHelper.getString(fields["date"] as? [String: Any]),
                        checkInTime: FirestoreHelper.getInt64(fields["checkInTime"] as? [String: Any]),
                        checkInLat: FirestoreHelper.getDouble(fields["checkInLat"] as? [String: Any]),
                        checkInLng: FirestoreHelper.getDouble(fields["checkInLng"] as? [String: Any]),
                        checkInAddress: FirestoreHelper.getString(fields["checkInAddress"] as? [String: Any]),
                        checkInStatus: FirestoreHelper.getString(fields["checkInStatus"] as? [String: Any]),
                        checkOutTime: FirestoreHelper.getInt64(fields["checkOutTime"] as? [String: Any]),
                        checkOutLat: FirestoreHelper.getDouble(fields["checkOutLat"] as? [String: Any]),
                        checkOutLng: FirestoreHelper.getDouble(fields["checkOutLng"] as? [String: Any]),
                        checkOutAddress: FirestoreHelper.getString(fields["checkOutAddress"] as? [String: Any]),
                        checkOutStatus: FirestoreHelper.getString(fields["checkOutStatus"] as? [String: Any]),
                        totalWorkMinutes: FirestoreHelper.getInt(fields["totalWorkMinutes"] as? [String: Any]),
                        note: FirestoreHelper.getString(fields["note"] as? [String: Any]),
                        companyId: self.companyId,
                        shiftType: FirestoreHelper.getString(fields["shiftType"] as? [String: Any]),
                        scheduledShiftCode: FirestoreHelper.getString(fields["scheduledShiftCode"] as? [String: Any]),
                        isUnscheduled: (fields["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                    )

                    await MainActor.run {
                        self.todayRecord = rec
                    }
                    return
                }
            }

            await MainActor.run {
                self.todayRecord = nil
            }
        }
    }

    // MARK: - MONTH COUNT (ĐỒNG BỘ ANDROID lines 466 & 1836)
    public func fetchUserMonthAttendanceCount() {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let ym = String(todayDateString.prefix(7)) // "yyyy-MM"
        guard !cleanEmail.isEmpty else { return }

        Task {
            let listUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances?pageSize=300"
            guard let url = URL(string: listUrlStr) else { return }

            var req = URLRequest(url: url)
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {

                var count = 0
                for doc in docs {
                    if let f = doc["fields"] as? [String: Any] {
                        let e = FirestoreHelper.getString(f["userEmail"] as? [String: Any])
                        let d = FirestoreHelper.getString(f["date"] as? [String: Any])
                        if e.caseInsensitiveCompare(cleanEmail) == .orderedSame && d.hasPrefix(ym) {
                            count += 1
                        }
                    }
                }
                await MainActor.run {
                    self.totalMonthDays = count
                }
            }
        }
    }

    // MARK: - CHECK-IN (ĐỒNG BỘ ANDROID lines 1393-1467 & 217-253)
    public func performCheckIn() {
        if isSubmitting { return }
        if !validateLocationForAttendance() { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let dateStr = todayDateString

        // Tính muộn (isLate) theo Android lines 1402-1423
        let startCfg: String = {
            switch selectedShiftType {
            case "SHIFT_1": return travelConfig.shift1CheckInTime
            case "SHIFT_2": return travelConfig.shift2CheckInTime
            case "NIGHT", "SHIFT_3": return travelConfig.nightCheckInTime
            default: return travelConfig.standardCheckInTime
            }
        }()

        let parts = startCfg.components(separatedBy: ":")
        let cfgHour = Int(parts.first ?? "8") ?? 8
        let cfgMin = Int(parts.dropFirst().first ?? "0") ?? 0

        let cal = Calendar.current
        let curHour = cal.component(.hour, from: Date())
        let curMin = cal.component(.minute, from: Date())

        let isNight = selectedShiftType == "NIGHT" || selectedShiftType == "SHIFT_3"
        let isLate: Bool = {
            if isNight {
                if curHour >= 12 {
                    return (curHour > cfgHour) || (curHour == cfgHour && curMin > (cfgMin + travelConfig.maxCheckInLateMinutes))
                } else {
                    return true
                }
            } else {
                return (curHour > cfgHour) || (curHour == cfgHour && curMin > (cfgMin + travelConfig.maxCheckInLateMinutes))
            }
        }()

        // Tự động nhận diện làm ngoài lịch / tăng ca
        let isOff = ["NC", "P", "NL", "NM"].contains(scheduledShiftCode)
        let isDiff: Bool = {
            switch selectedShiftType {
            case "SHIFT_1": return !scheduledShiftCode.isEmpty && scheduledShiftCode != "S"
            case "SHIFT_2": return !scheduledShiftCode.isEmpty && scheduledShiftCode != "C"
            case "NIGHT", "SHIFT_3": return !scheduledShiftCode.isEmpty && scheduledShiftCode != "TR"
            case "HC", "DAY": return !scheduledShiftCode.isEmpty && scheduledShiftCode != "HC" && scheduledShiftCode != "CT"
            default: return false
            }
        }()
        let isUnscheduled = scheduledShiftCode.isEmpty || isOff || isDiff

        let docId = todayDocId
        let lat = currentLocation?.latitude ?? 0.0
        let lng = currentLocation?.longitude ?? 0.0
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(docId)"
            guard let url = URL(string: urlStr) else {
                self.isSubmitting = false
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "fields": [
                    "id": ["stringValue": docId],
                    "userEmail": ["stringValue": cleanEmail],
                    "userName": ["stringValue": self.userName],
                    "userPhone": ["stringValue": self.user.phone],
                    "maNhanVien": ["stringValue": self.userMnv],
                    "employeeId": ["stringValue": self.userMnv],
                    "departmentId": ["stringValue": self.userDeptId],
                    "departmentName": ["stringValue": self.userDeptName],
                    "donVi": ["stringValue": self.userDonVi],
                    "date": ["stringValue": dateStr],
                    "checkInTime": ["integerValue": String(now)],
                    "checkInLat": ["doubleValue": lat],
                    "checkInLng": ["doubleValue": lng],
                    "checkInAddress": ["stringValue": self.currentAddress],
                    "checkInStatus": ["stringValue": isLate ? "LATE" : "ON_TIME"],
                    "shiftType": ["stringValue": self.selectedShiftType],
                    "scheduledShiftCode": ["stringValue": self.scheduledShiftCode],
                    "isUnscheduled": ["booleanValue": isUnscheduled],
                    "note": ["stringValue": self.noteInput.trimmingCharacters(in: .whitespacesAndNewlines)],
                    "companyId": ["stringValue": self.companyId]
                ]
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)

            if let (_, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {

                await MainActor.run {
                    self.isSubmitting = false
                    self.totalMonthDays += 1
                    let shiftName = ShiftCode.label(self.selectedShiftType)
                    self.successMessage = "Điểm danh vào ca (\(shiftName)) thành công!"
                    self.fetchTodayAttendance()
                }
            } else {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Điểm danh thất bại, vui lòng thử lại!"
                }
            }
        }
    }

    // MARK: - CHECK-OUT (ĐỒNG BỘ ANDROID lines 1542-1668 & 255-279)
    public func performCheckOut() {
        if isSubmitting { return }
        guard let currentRec = todayRecord, currentRec.isCheckedIn else {
            errorMessage = "Vui lòng Check-in vào ca trước khi Check-out!"
            return
        }
        if !validateLocationForAttendance() { return }

        isSubmitting = true
        errorMessage = nil
        successMessage = nil

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let inTime = currentRec.checkInTime
        let totalMins = max(0, Int((now - inTime) / 60000))

        let endCfg: String = {
            switch selectedShiftType {
            case "SHIFT_1": return travelConfig.shift1CheckOutTime
            case "SHIFT_2": return travelConfig.shift2CheckOutTime
            case "NIGHT", "SHIFT_3": return travelConfig.nightCheckOutTime
            default: return travelConfig.standardCheckOutTime
            }
        }()

        let parts = endCfg.components(separatedBy: ":")
        let cfgHour = Int(parts.first ?? "17") ?? 17
        let cfgMin = Int(parts.dropFirst().first ?? "0") ?? 0

        let cal = Calendar.current
        let curHour = cal.component(.hour, from: Date())
        let curMin = cal.component(.minute, from: Date())

        let isNight = selectedShiftType == "NIGHT" || selectedShiftType == "SHIFT_3"
        let isEarly: Bool = {
            if isNight {
                if curHour >= 18 { return true }
                return curHour < cfgHour || (curHour == cfgHour && curMin < cfgMin)
            } else {
                return curHour < cfgHour || (curHour == cfgHour && curMin < cfgMin)
            }
        }()

        // Mốc thời gian kết thúc ca chuẩn
        var inCal = cal
        inCal.timeZone = .current
        let inDate = Date(timeIntervalSince1970: TimeInterval(inTime) / 1000.0)
        var endComponents = cal.dateComponents([.year, .month, .day], from: inDate)
        if isNight && cal.component(.hour, from: inDate) >= 18 {
            endComponents.day = (endComponents.day ?? 1) + 1
        }
        endComponents.hour = cfgHour
        endComponents.minute = cfgMin
        endComponents.second = 0
        let shiftEndDate = cal.date(from: endComponents) ?? Date()
        let shiftEndTimestamp = Int64(shiftEndDate.timeIntervalSince1970 * 1000)

        let lat = currentLocation?.latitude ?? 0.0
        let lng = currentLocation?.longitude ?? 0.0
        let docId = currentRec.id.isEmpty ? todayDocId : currentRec.id

        Task {
            // Kiểm tra ticket OT sau giờ tan ca (Android lines 1590-1612)
            var hasOvertimeTicket = false
            var overtimeTicketCount = 0
            if !isEarly && now > shiftEndTimestamp {
                let cleanEmail = self.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let tUrlStr = "\(FirebaseConfig.firestoreBaseUrl):runQuery"
                if let tUrl = URL(string: tUrlStr) {
                    var tReq = URLRequest(url: tUrl)
                    tReq.httpMethod = "POST"
                    tReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                    tReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

                    let tBody: [String: Any] = [
                        "structuredQuery": [
                            "from": [["collectionId": "support_tickets"]],
                            "where": [
                                "fieldFilter": [
                                    "field": ["fieldPath": "assignedToEmail"],
                                    "op": "EQUAL",
                                    "value": ["stringValue": cleanEmail]
                                ]
                            ]
                        ],
                        "parent": "projects/\(FirebaseConfig.projectId)/databases/(default)/documents/companies/\(companyId)"
                    ]
                    tReq.httpBody = try? JSONSerialization.data(withJSONObject: tBody)

                    if let (tData, tResp) = try? await URLSession.shared.data(for: tReq),
                       let tHttp = tResp as? HTTPURLResponse, tHttp.statusCode == 200,
                       let tArr = try? JSONSerialization.jsonObject(with: tData) as? [[String: Any]] {
                        for tResult in tArr {
                            if let doc = tResult["document"] as? [String: Any],
                               let f = doc["fields"] as? [String: Any] {
                                let status = FirestoreHelper.getString(f["status"] as? [String: Any])
                                let closedAt = FirestoreHelper.getInt64(f["closedAt"] as? [String: Any])
                                let assignedAt = FirestoreHelper.getInt64(f["assignedAt"] as? [String: Any])
                                let isClosed = status.caseInsensitiveCompare("CLOSED") == .orderedSame || closedAt > 0
                                if !isClosed || closedAt >= shiftEndTimestamp || assignedAt >= shiftEndTimestamp {
                                    hasOvertimeTicket = true
                                    overtimeTicketCount += 1
                                }
                            }
                        }
                    }
                }
            }

            let checkOutStatus: String = {
                if isEarly { return "EARLY" }
                if hasOvertimeTicket { return "OVERTIME" }
                return "NORMAL"
            }()

            // Nếu quên check-out (không có ticket), chốt trần thời gian tính công
            let effectiveWorkMins: Int = {
                if !isEarly && !hasOvertimeTicket && now > shiftEndTimestamp {
                    return max(0, Int((shiftEndTimestamp - inTime) / 60000))
                }
                return totalMins
            }()

            let noteSuffix: String = {
                if hasOvertimeTicket {
                    return " [Tăng ca OT: \(overtimeTicketCount) sự cố ngoài giờ]"
                }
                if !isEarly && now > (shiftEndTimestamp + 30 * 60 * 1000) {
                    return " [Chốt công theo ca chuẩn \(self.selectedShiftType) (\(endCfg))]"
                }
                return ""
            }()

            let combinedNote = (self.noteInput.trimmingCharacters(in: .whitespacesAndNewlines) + noteSuffix).trimmingCharacters(in: .whitespacesAndNewlines)

            let patchUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(docId)?updateMask.fieldPaths=checkOutTime&updateMask.fieldPaths=checkOutLat&updateMask.fieldPaths=checkOutLng&updateMask.fieldPaths=checkOutAddress&updateMask.fieldPaths=checkOutStatus&updateMask.fieldPaths=totalWorkMinutes&updateMask.fieldPaths=shiftType&updateMask.fieldPaths=note"
            guard let patchUrl = URL(string: patchUrlStr) else {
                self.isSubmitting = false
                return
            }

            var patchReq = URLRequest(url: patchUrl)
            patchReq.httpMethod = "PATCH"
            patchReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let patchBody: [String: Any] = [
                "fields": [
                    "checkOutTime": ["integerValue": String(now)],
                    "checkOutLat": ["doubleValue": lat],
                    "checkOutLng": ["doubleValue": lng],
                    "checkOutAddress": ["stringValue": self.currentAddress],
                    "checkOutStatus": ["stringValue": checkOutStatus],
                    "totalWorkMinutes": ["integerValue": String(effectiveWorkMins)],
                    "shiftType": ["stringValue": self.selectedShiftType],
                    "note": ["stringValue": combinedNote]
                ]
            ]
            patchReq.httpBody = try? JSONSerialization.data(withJSONObject: patchBody)

            if let (_, resp) = try? await URLSession.shared.data(for: patchReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200 {

                await MainActor.run {
                    self.isSubmitting = false
                    if checkOutStatus == "OVERTIME" {
                        self.successMessage = "🔥 Check-out tăng ca (OT) thành công! Đã ghi nhận giờ làm việc thực tế & phụ cấp ngoài giờ."
                    } else {
                        self.successMessage = "✅ Check-out tan ca thành công!"
                    }
                    self.fetchTodayAttendance()
                }
            } else {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMessage = "Check-out thất bại, vui lòng thử lại!"
                }
            }
        }
    }

    // MARK: - FETCH ATTENDANCE HISTORY (ĐỒNG BỘ ANDROID AttendanceHistoryScreen.kt)
    public func fetchAttendanceHistory(month: Date) {
        Task {
            await MainActor.run { self.isLoadingHistory = true }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthStr = formatter.string(from: month)

            let queryUrl = "\(FirebaseConfig.firestoreBaseUrl):runQuery"
            guard let qUrl = URL(string: queryUrl) else {
                await MainActor.run { self.isLoadingHistory = false }
                return
            }
            var qRequest = URLRequest(url: qUrl)
            qRequest.httpMethod = "POST"
            qRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            qRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                                        "value": ["stringValue": cleanEmail]
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
                "parent": "projects/\(FirebaseConfig.projectId)/databases/(default)/documents/companies/\(companyId)"
            ]
            qRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

            var records: [AttendanceRecord] = []
            if let (data, response) = try? await URLSession.shared.data(for: qRequest),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {

                for docResult in jsonArray {
                    if let doc = docResult["document"] as? [String: Any],
                       let fields = doc["fields"] as? [String: Any],
                       let docName = doc["name"] as? String {

                        let dateVal = FirestoreHelper.getString(fields["date"] as? [String: Any])
                        if dateVal.hasPrefix(monthStr) {
                            let docId = docName.components(separatedBy: "/").last ?? ""
                            let record = AttendanceRecord(
                                id: docId,
                                userEmail: FirestoreHelper.getString(fields["userEmail"] as? [String: Any]),
                                userName: FirestoreHelper.getString(fields["userName"] as? [String: Any]),
                                userPhone: FirestoreHelper.getString(fields["userPhone"] as? [String: Any]),
                                maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                                employeeId: FirestoreHelper.getString(fields["employeeId"] as? [String: Any]),
                                departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                                departmentName: FirestoreHelper.getString(fields["departmentName"] as? [String: Any]),
                                donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                                date: dateVal,
                                checkInTime: FirestoreHelper.getInt64(fields["checkInTime"] as? [String: Any]),
                                checkInLat: FirestoreHelper.getDouble(fields["checkInLat"] as? [String: Any]),
                                checkInLng: FirestoreHelper.getDouble(fields["checkInLng"] as? [String: Any]),
                                checkInAddress: FirestoreHelper.getString(fields["checkInAddress"] as? [String: Any]),
                                checkInStatus: FirestoreHelper.getString(fields["checkInStatus"] as? [String: Any]),
                                checkOutTime: FirestoreHelper.getInt64(fields["checkOutTime"] as? [String: Any]),
                                checkOutLat: FirestoreHelper.getDouble(fields["checkOutLat"] as? [String: Any]),
                                checkOutLng: FirestoreHelper.getDouble(fields["checkOutLng"] as? [String: Any]),
                                checkOutAddress: FirestoreHelper.getString(fields["checkOutAddress"] as? [String: Any]),
                                checkOutStatus: FirestoreHelper.getString(fields["checkOutStatus"] as? [String: Any]),
                                totalWorkMinutes: FirestoreHelper.getInt(fields["totalWorkMinutes"] as? [String: Any]),
                                note: FirestoreHelper.getString(fields["note"] as? [String: Any]),
                                companyId: self.companyId,
                                shiftType: FirestoreHelper.getString(fields["shiftType"] as? [String: Any]),
                                scheduledShiftCode: FirestoreHelper.getString(fields["scheduledShiftCode"] as? [String: Any]),
                                isUnscheduled: (fields["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                            )
                            records.append(record)
                        }
                    }
                }
            }

            // Fallback đọc trực tiếp collection attendances nếu runQuery không có index
            if records.isEmpty {
                let listUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances?pageSize=300"
                if let listUrl = URL(string: listUrlStr) {
                    var listReq = URLRequest(url: listUrl)
                    listReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                    if let (data, response) = try? await URLSession.shared.data(for: listReq),
                       let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let docs = json["documents"] as? [[String: Any]] {
                        for doc in docs {
                            if let fields = doc["fields"] as? [String: Any],
                               let docName = doc["name"] as? String {
                                let docEmail = FirestoreHelper.getString(fields["userEmail"] as? [String: Any])
                                if docEmail.caseInsensitiveCompare(cleanEmail) == .orderedSame {
                                    let dateVal = FirestoreHelper.getString(fields["date"] as? [String: Any])
                                    if dateVal.hasPrefix(monthStr) {
                                        let docId = docName.components(separatedBy: "/").last ?? ""
                                        let record = AttendanceRecord(
                                            id: docId,
                                            userEmail: docEmail,
                                            userName: FirestoreHelper.getString(fields["userName"] as? [String: Any]),
                                            userPhone: FirestoreHelper.getString(fields["userPhone"] as? [String: Any]),
                                            maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                                            employeeId: FirestoreHelper.getString(fields["employeeId"] as? [String: Any]),
                                            departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                                            departmentName: FirestoreHelper.getString(fields["departmentName"] as? [String: Any]),
                                            donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                                            date: dateVal,
                                            checkInTime: FirestoreHelper.getInt64(fields["checkInTime"] as? [String: Any]),
                                            checkInLat: FirestoreHelper.getDouble(fields["checkInLat"] as? [String: Any]),
                                            checkInLng: FirestoreHelper.getDouble(fields["checkInLng"] as? [String: Any]),
                                            checkInAddress: FirestoreHelper.getString(fields["checkInAddress"] as? [String: Any]),
                                            checkInStatus: FirestoreHelper.getString(fields["checkInStatus"] as? [String: Any]),
                                            checkOutTime: FirestoreHelper.getInt64(fields["checkOutTime"] as? [String: Any]),
                                            checkOutLat: FirestoreHelper.getDouble(fields["checkOutLat"] as? [String: Any]),
                                            checkOutLng: FirestoreHelper.getDouble(fields["checkOutLng"] as? [String: Any]),
                                            checkOutAddress: FirestoreHelper.getString(fields["checkOutAddress"] as? [String: Any]),
                                            checkOutStatus: FirestoreHelper.getString(fields["checkOutStatus"] as? [String: Any]),
                                            totalWorkMinutes: FirestoreHelper.getInt(fields["totalWorkMinutes"] as? [String: Any]),
                                            note: FirestoreHelper.getString(fields["note"] as? [String: Any]),
                                            companyId: self.companyId,
                                            shiftType: FirestoreHelper.getString(fields["shiftType"] as? [String: Any]),
                                            scheduledShiftCode: FirestoreHelper.getString(fields["scheduledShiftCode"] as? [String: Any]),
                                            isUnscheduled: (fields["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                                        )
                                        records.append(record)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            records.sort { $0.date > $1.date }

            await MainActor.run {
                self.attendanceHistory = records
                self.isLoadingHistory = false
            }
        }
    }

    // MARK: - FETCH ALL ATTENDANCE HISTORY (CHO BÁO CÁO QUẢN LÝ / ADMIN)
    public func fetchAllAttendanceHistory(month: Date) {
        Task {
            await MainActor.run { self.isLoadingHistory = true }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthStr = formatter.string(from: month)

            let listUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances?pageSize=300"
            guard let listUrl = URL(string: listUrlStr) else {
                await MainActor.run { self.isLoadingHistory = false }
                return
            }

            var listReq = URLRequest(url: listUrl)
            listReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            var records: [AttendanceRecord] = []
            if let (data, resp) = try? await URLSession.shared.data(for: listReq),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {

                for doc in docs {
                    if let f = doc["fields"] as? [String: Any],
                       let docName = doc["name"] as? String {
                        let d = FirestoreHelper.getString(f["date"] as? [String: Any])
                        if d.hasPrefix(monthStr) {
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
                                companyId: self.companyId,
                                shiftType: FirestoreHelper.getString(f["shiftType"] as? [String: Any]),
                                scheduledShiftCode: FirestoreHelper.getString(f["scheduledShiftCode"] as? [String: Any]),
                                isUnscheduled: (f["isUnscheduled"] as? [String: Any])?["booleanValue"] as? Bool ?? false
                            )
                            records.append(rec)
                        }
                    }
                }
            }

            records.sort { $0.date > $1.date }

            await MainActor.run {
                self.attendanceHistory = records
                self.isLoadingHistory = false
            }
        }
    }
}
