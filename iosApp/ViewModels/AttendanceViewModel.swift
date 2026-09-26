import SwiftUI
import CoreLocation

// MARK: - ATTENDANCE VIEW MODEL (ĐỒNG BỘ 1:1 VỚI ATTENDANCECHECKINSCREEN.KT TRÊN ANDROID)
@MainActor
public class AttendanceViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var todayRecord: AttendanceRecord? = nil
    @Published public var currentLocation: CLLocationCoordinate2D? = nil
    @Published public var currentAddress: String = "Đang xác định vị trí GPS..."
    @Published public var selectedShiftType: String = "HC" // "HC", "SHIFT_1", "SHIFT_2", "NIGHT"
    @Published public var isLocating: Bool = false
    @Published public var isSubmitting: Bool = false
    @Published public var successMessage: String? = nil
    @Published public var errorMessage: String? = nil

    private let locationManager = CLLocationManager()

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    public func startUpdatingLocation() {
        isLocating = true
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.currentLocation = loc.coordinate
        self.isLocating = false
        self.locationManager.stopUpdatingLocation()

        // Reverse Geocoding lấy địa chỉ
        CLGeocoder().reverseGeocodeLocation(loc) { placemarks, _ in
            if let p = placemarks?.first {
                let addr = [p.name, p.subLocality, p.locality, p.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                Task { @MainActor in
                    self.currentAddress = addr.isEmpty ? "Vị trí GPS: \(loc.coordinate.latitude), \(loc.coordinate.longitude)" : addr
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

        isSubmitting = true
        errorMessage = nil
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
                    "checkInStatus": ["stringValue": "ON_TIME"],
                    "shiftType": ["stringValue": selectedShiftType]
                ]
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
            self.isSubmitting = false
            self.successMessage = "Chấm công VÀO ca thành công!"
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
