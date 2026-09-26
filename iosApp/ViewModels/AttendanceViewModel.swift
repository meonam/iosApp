import SwiftUI
import CoreLocation

// MARK: - CẤU HÌNH GEOFENCE (đồng bộ AttendanceCheckInScreen.kt)
public struct TravelExpenseConfig {
    public var targetLatitude: Double = 0
    public var targetLongitude: Double = 0
    public var targetAddress: String = ""
    public var geofenceRadiusMeters: Double = 150.0
    public var strictGeofenceBlocking: Bool = false
}

// MARK: - ATTENDANCE VIEW MODEL (ĐỒNG BỘ 1:1 VỚI ATTENDANCECHECKINSCREEN.KT TRÊN ANDROID)
@MainActor
public class AttendanceViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var todayRecord: AttendanceRecord? = nil
    @Published public var currentLocation: CLLocationCoordinate2D? = nil
    @Published public var currentAddress: String = "Đang xác định vị trí GPS..."
    @Published public var selectedShiftType: String = "HC" // tự động từ giờ hiện tại
    @Published public var isLocating: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var successMessage: String? = nil
    @Published public var errorMessage: String? = nil

    // Geofence (đồng bộ AttendanceCheckInScreen.kt)
    @Published public var travelConfig: TravelExpenseConfig = TravelExpenseConfig()
    @Published public var distanceToWorkMeters: Double? = nil
    @Published public var isWithinGeofence: Bool = true
    @Published public var isLoadingConfig: Bool = false

    private let locationManager = CLLocationManager()

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        // Auto-detect ca từ giờ hiện tại (đồng bộ Android lines 140-148)
        self.selectedShiftType = Self.autoDetectShiftType()
    }

    // MARK: - AUTO DETECT CA (đồng bộ Android AttendanceCheckInScreen.kt lines 140-148)
    public static func autoDetectShiftType() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 6 && hour <= 12 { return "HC" }
        else if hour >= 13 && hour <= 20 { return "SHIFT_2" }
        else { return "NIGHT" }
    }

    // MARK: - TÍNH TRẠNG THÁI CHECK-IN (đồng bộ Android: LATE / ON_TIME / EARLY)
    public func computeCheckInStatus(shiftType: String) -> String {
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)

        // Thời gian bắt đầu ca và ngưỡng trễ (15 phút)
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

            // Tính khoảng cách đến vị trí công ty nếu có config
            if self.travelConfig.targetLatitude != 0 {
                let targetLocation = CLLocation(
                    latitude: self.travelConfig.targetLatitude,
                    longitude: self.travelConfig.targetLongitude
                )
                let distanceM = loc.distance(from: targetLocation)
                self.distanceToWorkMeters = distanceM
                self.isWithinGeofence = distanceM <= self.travelConfig.geofenceRadiusMeters
            }

            // Reverse Geocoding lấy địa chỉ
            CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
                if let p = placemarks?.first {
                    let addr = [p.name, p.subLocality, p.locality, p.administrativeArea]
                        .compactMap { $0 }.joined(separator: ", ")
                    Task { @MainActor in
                        self.currentAddress = addr.isEmpty
                            ? "Vị trí GPS: \(loc.coordinate.latitude), \(loc.coordinate.longitude)"
                            : addr
                    }
                }
            }
        }
    }

    // MARK: - FETCH TRAVEL EXPENSE CONFIG (đồng bộ Android: system_config/travel_expense_config)
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

                // Nếu đã có vị trí GPS, tính lại khoảng cách ngay
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

    // Lấy ngày hôm nay định dạng YYYY-MM-DD
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

    // Tải thông tin chấm công hôm nay
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

    // Chấm công Vào (Check-in)
    public func performCheckIn() {
        guard let loc = currentLocation else {
            errorMessage = "Chưa nhận diện được vị trí GPS, vui lòng thử lại!"
            return
        }

        // Kiểm tra geofence nếu bật strict blocking
        if travelConfig.strictGeofenceBlocking && !isWithinGeofence {
            let distance = distanceToWorkMeters.map { Int($0) } ?? 0
            errorMessage = "Bạn đang ở ngoài phạm vi chấm công (\(distance)m). Vui lòng đến gần hơn trong \(Int(travelConfig.geofenceRadiusMeters))m!"
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
            let statusText = checkInStatus == "LATE" ? " (Trễ ca)" : checkInStatus == "EARLY" ? " (Sớm ca)" : ""
            self.successMessage = "Chấm công VÀO ca thành công!\(statusText)"
            self.fetchTodayAttendance()
        }
    }

    // Chấm công Ra (Check-out)
    public func performCheckOut() {
        guard let loc = currentLocation else {
            errorMessage = "Chưa nhận diện được vị trí GPS, vui lòng thử lại!"
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
            self.successMessage = "Chấm công RA ca thành công!"
            self.fetchTodayAttendance()
        }
    }
}
