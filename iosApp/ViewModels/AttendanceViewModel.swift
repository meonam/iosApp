import SwiftUI
import CoreLocation

// MARK: - Cáº¤U HÃŒNH GEOFENCE (Ä‘á»“ng bá»™ AttendanceCheckInScreen.kt)
public struct TravelExpenseConfig {
    public var targetLatitude: Double = 0
    public var targetLongitude: Double = 0
    public var targetAddress: String = ""
    public var geofenceRadiusMeters: Double = 150.0
    public var strictGeofenceBlocking: Bool = false
}

// MARK: - ATTENDANCE VIEW MODEL (Äá»’NG Bá»˜ 1:1 Vá»šI ATTENDANCECHECKINSCREEN.KT TRÃŠN ANDROID)
@MainActor
public class AttendanceViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var todayRecord: AttendanceRecord? = nil
    @Published public var currentLocation: CLLocationCoordinate2D? = nil
    @Published public var currentAddress: String = "Äang xÃ¡c Ä‘á»‹nh vá»‹ trÃ­ GPS..."
    @Published public var selectedShiftType: String = "HC" // tá»± Ä‘á»™ng tá»« giá» hiá»‡n táº¡i
    @Published public var isLocating: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var successMessage: String? = nil
    @Published public var errorMessage: String? = nil

    // Geofence (Ä‘á»“ng bá»™ AttendanceCheckInScreen.kt)
    @Published public var travelConfig: TravelExpenseConfig = TravelExpenseConfig()
    @Published public var distanceToWorkMeters: Double? = nil
    @Published public var isWithinGeofence: Bool = true
    @Published public var isLoadingConfig: Bool = false

    // History (`"ng bT AttendanceHistoryScreen.kt)
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
        self.companyId = companyId
        self.idToken = idToken
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Auto-detect ca tá»« giá» hiá»‡n táº¡i (Ä‘á»“ng bá»™ Android lines 140-148)
        self.selectedShiftType = Self.autoDetectShiftType()
    }

    // MARK: - AUTO DETECT CA (Ä‘á»“ng bá»™ Android AttendanceCheckInScreen.kt lines 140-148)
    public static func autoDetectShiftType() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour <= 12 { return "HC" }
        else if hour >= 13 && hour <= 20 { return "SHIFT_2" }
        else { return "NIGHT" }
    }

    // MARK: - TÃNH TRáº NG THÃI CHECK-IN (Ä‘á»“ng bá»™ Android: LATE / ON_TIME / EARLY)
    public func computeCheckInStatus(shiftType: String) -> String {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)

        // Thá»i gian báº¯t Ä‘áº§u ca vÃ  ngÆ°á»¡ng trá»… (15 phÃºt)
        let (startHour, startMinute): (Int, Int)
        switch shiftType {
        case "HC":
            startHour = 8; startMinute = 0
        case "SHIFT_1":
            startHour = 7; startMinute = 0
        case "SHIFT_2":
            startHour = 14; startMinute = 0
        case "NIGHT":
            startHour = 22; startMinute = 0
        default:
            startHour = 8; startMinute = 0
        }

        let lateThresholdMinute = startMinute + 15

        if hour < startHour { return "EARLY" }
        if hour == startHour && minute <= lateThresholdMinute { return "ON_TIME" }
        if hour > startHour || (hour == startHour && minute > lateThresholdMinute) { return "LATE" }
        return "ON_TIME"
    }

    // MARK: - GPS
    public func startUpdatingLocation() {
        isLocating = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = loc.coordinate
            self.isLocating = false
            self.locationManager.stopUpdatingLocation()

            // TÃ­nh khoáº£ng cÃ¡ch Ä‘áº¿n vá»‹ trÃ­ cÃ´ng ty náº¿u cÃ³ config
            if self.travelConfig.targetLatitude != 0 {
                let targetLocation = CLLocation(
                    latitude: self.travelConfig.targetLatitude,
                    longitude: self.travelConfig.targetLongitude
                )
                let distanceM = loc.distance(from: targetLocation)
                self.distanceToWorkMeters = distanceM
                self.isWithinGeofence = distanceM <= self.travelConfig.geofenceRadiusMeters
            }

            // Reverse Geocoding láº¥y Ä‘á»‹a chá»‰
            CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
                if let p = placemarks?.first {
                    let addr = [p.name, p.subLocality, p.locality, p.administrativeArea]
                        .compactMap { $0 }.joined(separator: ", ")
                    Task { @MainActor in
                        self.currentAddress = addr.isEmpty
                            ? "Vá»‹ trÃ­ GPS: \(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                            : addr
                    }
                }
            }
        }
    }

    // MARK: - FETCH TRAVEL EXPENSE CONFIG (Ä‘á»“ng bá»™ Android: system_config/travel_expense_config)
    public func fetchTravelExpenseConfig() {
        isLoadingConfig = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/system_config/travel_expense_config"
            guard let url = URL(string: urlStr) else {
                await MainActor.run { self.isLoadingConfig = false }
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                await MainActor.run { self.isLoadingConfig = false }
                return
            }

            var config = TravelExpenseConfig()
            config.targetLatitude = FirestoreHelper.getDouble(fields["targetLatitude"] as? [String: Any])
            config.targetLongitude = FirestoreHelper.getDouble(fields["targetLongitude"] as? [String: Any])
            config.targetAddress = FirestoreHelper.getString(fields["targetAddress"] as? [String: Any])
            let radius = FirestoreHelper.getDouble(fields["geofenceRadiusMeters"] as? [String: Any])
            config.geofenceRadiusMeters = radius > 0 ? radius : 150.0
            config.strictGeofenceBlocking = (fields["strictGeofenceBlocking"] as? [String: Any])?["booleanValue"] as? Bool ?? false

            await MainActor.run {
                self.travelConfig = config
                self.isLoadingConfig = false

                // Náº¿u Ä‘Ã£ cÃ³ vá»‹ trÃ­ GPS, tÃ­nh láº¡i khoáº£ng cÃ¡ch ngay
                if let loc = self.currentLocation, config.targetLatitude != 0 {
                    let current = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                    let target = CLLocation(latitude: config.targetLatitude, longitude: config.targetLongitude)
                    let d = current.distance(from: target)
                    self.distanceToWorkMeters = d
                    self.isWithinGeofence = d <= config.geofenceRadiusMeters
                }
            }
        }
    }

    // Láº¥y ngÃ y hÃ´m nay Ä‘á»‹nh dáº¡ng YYYY-MM-DD
    public var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    public var todayDocId: String {
        let cleanEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanDate = todayDateString.replacingOccurrences(of: "-", with: "")
        return "att_\(cleanDate)_\(cleanEmail)"
    }

    // Táº£i thÃ´ng tin cháº¥m cÃ´ng hÃ´m nay
    public func fetchTodayAttendance() {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(todayDocId)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let fields = json["fields"] as? [String: Any] else {
                return
            }

            self.todayRecord = AttendanceRecord(
                id: todayDocId,
                userEmail: user.email,
                userName: user.fullName,
                donVi: user.donVi,
                date: todayDateString,
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
                shiftType: FirestoreHelper.getString(fields["shiftType"] as? [String: Any])
            )
        }
    }

    // Cháº¥m cÃ´ng VÃ o (Check-in)
    public func performCheckIn() {
        guard let loc = currentLocation else {
            errorMessage = "ChÆ°a nháº­n diá»‡n Ä‘Æ°á»£c vá»‹ trÃ­ GPS, vui lÃ²ng thá»­ láº¡i!"
            return
        }

        // Kiá»ƒm tra geofence náº¿u báº­t strict blocking
        if travelConfig.strictGeofenceBlocking && !isWithinGeofence {
            let distance = distanceToWorkMeters.map { Int($0) } ?? 0
            errorMessage = "Báº¡n Ä‘ang á»Ÿ ngoÃ i pháº¡m vi cháº¥m cÃ´ng (\(distance)m). Vui lÃ²ng Ä‘áº¿n gáº§n hÆ¡n trong \(Int(travelConfig.geofenceRadiusMeters))m!"
            return
        }

        isSubmitting = true
        errorMessage = nil
        let checkInStatus = computeCheckInStatus(shiftType: selectedShiftType)

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(todayDocId)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let body: [String: Any] = [
                "fields": [
                    "userEmail": ["stringValue": user.email],
                    "userName": ["stringValue": user.fullName],
                    "donVi": ["stringValue": user.donVi],
                    "date": ["stringValue": todayDateString],
                    "checkInTime": ["integerValue": String(now)],
                    "checkInLat": ["doubleValue": loc.latitude],
                    "checkInLng": ["doubleValue": loc.longitude],
                    "checkInAddress": ["stringValue": currentAddress],
                    "checkInStatus": ["stringValue": checkInStatus],
                    "shiftType": ["stringValue": selectedShiftType],
                    "distanceToWorkMeters": ["doubleValue": distanceToWorkMeters ?? 0]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
            self.isSubmitting = false
            let statusText = checkInStatus == "LATE" ? " (Trá»… ca)" : checkInStatus == "EARLY" ? " (Sá»›m ca)" : ""
            self.successMessage = "Cháº¥m cÃ´ng VÃ€O ca thÃ nh cÃ´ng!\(statusText)"
            self.fetchTodayAttendance()
        }
    }

    // Cháº¥m cÃ´ng Ra (Check-out)
    public func performCheckOut() {
        guard let loc = currentLocation else {
            errorMessage = "ChÆ°a nháº­n diá»‡n Ä‘Æ°á»£c vá»‹ trÃ­ GPS, vui lÃ²ng thá»­ láº¡i!"
            return
        }

        isSubmitting = true
        errorMessage = nil
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendances/\(todayDocId)?updateMask.fieldPaths=checkOutTime&updateMask.fieldPaths=checkOutLat&updateMask.fieldPaths=checkOutLng&updateMask.fieldPaths=checkOutAddress&updateMask.fieldPaths=checkOutStatus"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let body: [String: Any] = [
                "fields": [
                    "checkOutTime": ["integerValue": String(now)],
                    "checkOutLat": ["doubleValue": loc.latitude],
                    "checkOutLng": ["doubleValue": loc.longitude],
                    "checkOutAddress": ["stringValue": currentAddress],
                    "checkOutStatus": ["stringValue": "NORMAL"]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
            self.isSubmitting = false
            self.successMessage = "Cháº¥m cÃ´ng RA ca thÃ nh cÃ´ng!"
            self.fetchTodayAttendance()
        }
    }

    // MARK: - FETCH ATTENDANCE HISTORY
    public func fetchAttendanceHistory(month: Date) {
        Task {
            await MainActor.run { self.isLoadingHistory = true }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthStr = formatter.string(from: month)

            let queryUrl = "$(FirebaseConfig.firestoreBaseUrl):runQuery"
            guard let qUrl = URL(string: queryUrl) else { return }
            var qRequest = URLRequest(url: qUrl)
            qRequest.httpMethod = "POST"
            qRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            qRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                                        "value": ["stringValue": user.email]
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
            
            guard let (data, response) = try? await URLSession.shared.data(for: qRequest),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                
                await MainActor.run {
                    self.isLoadingHistory = false
                    self.attendanceHistory = []
                }
                return
            }
            
            var records: [AttendanceRecord] = []
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
                            shiftType: FirestoreHelper.getString(fields["shiftType"] as? [String: Any])
                        )
                        records.append(record)
                    }
                }
            }
            
            await MainActor.run {
                self.attendanceHistory = records
                self.isLoadingHistory = false
            }
        }
    }
}
