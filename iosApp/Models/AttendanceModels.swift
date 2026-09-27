import Foundation

// MARK: - SHIFT CODE DEFINITIONS (ĐỒNG BỘ 1:1 VỚI ATTENDANCEMODELS.KT TRÊN ANDROID)
public struct ShiftCode {
    public static let SANG = "S"
    public static let CHIEU = "C"
    public static let HANH_CHANH = "HC"
    public static let TRUC = "TR"
    public static let NGHI_CA = "NC"
    public static let PHEP = "P"
    public static let NGHI_LE = "NL"
    public static let NGHI_MAT = "NM"
    public static let CONG_TAC = "CT"
    public static let HOP = "H"

    public static func label(_ code: String) -> String {
        let clean = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch clean {
        case SANG: return "Ca 1 (Sáng)"
        case CHIEU: return "Ca 2 (Chiều)"
        case HANH_CHANH: return "Hành chính"
        case TRUC: return "Ca 3 (Trực đêm)"
        case NGHI_CA: return "Nghỉ ca"
        case PHEP: return "Nghỉ phép"
        case NGHI_LE: return "Nghỉ lễ"
        case NGHI_MAT: return "Nghỉ mát"
        case CONG_TAC: return "Đi công tác"
        case HOP: return "Đi họp"
        default: return code.isEmpty ? "Chưa xếp ca" : code
        }
    }
}

// MARK: - TRAVEL EXPENSE CONFIG (ĐỒNG BỘ 1:1 VỚI TRAVEL_EXPENSE_CONFIG TRÊN ANDROID)
public struct TravelExpenseConfig: Codable {
    public var standardCheckInTime: String = "08:00"
    public var standardCheckOutTime: String = "17:00"
    public var shift1CheckInTime: String = "07:00"
    public var shift1CheckOutTime: String = "15:00"
    public var shift2CheckInTime: String = "14:00"
    public var shift2CheckOutTime: String = "22:00"
    public var nightCheckInTime: String = "22:00"
    public var nightCheckOutTime: String = "06:00"
    public var maxCheckInLateMinutes: Int = 15
    public var geofenceRadiusMeters: Double = 250.0
    public var arrivalRadiusMeters: Double = 150.0
    public var targetLatitude: Double = 0.0
    public var targetLongitude: Double = 0.0
    public var targetAddress: String = ""
    public var pricePerKm: Double = 5000.0
    public var tripBaseAllowance: Double = 50000.0
    public var overtimeMultiplier: Double = 0.0
    public var strictGeofenceBlocking: Bool = false
    public var autoCaptureGpsOnOpen: Bool = true

    public init(
        standardCheckInTime: String = "08:00",
        standardCheckOutTime: String = "17:00",
        shift1CheckInTime: String = "07:00",
        shift1CheckOutTime: String = "15:00",
        shift2CheckInTime: String = "14:00",
        shift2CheckOutTime: String = "22:00",
        nightCheckInTime: String = "22:00",
        nightCheckOutTime: String = "06:00",
        maxCheckInLateMinutes: Int = 15,
        geofenceRadiusMeters: Double = 250.0,
        arrivalRadiusMeters: Double = 150.0,
        targetLatitude: Double = 0.0,
        targetLongitude: Double = 0.0,
        targetAddress: String = "",
        pricePerKm: Double = 5000.0,
        tripBaseAllowance: Double = 50000.0,
        overtimeMultiplier: Double = 0.0,
        strictGeofenceBlocking: Bool = false,
        autoCaptureGpsOnOpen: Bool = true
    ) {
        self.standardCheckInTime = standardCheckInTime
        self.standardCheckOutTime = standardCheckOutTime
        self.shift1CheckInTime = shift1CheckInTime
        self.shift1CheckOutTime = shift1CheckOutTime
        self.shift2CheckInTime = shift2CheckInTime
        self.shift2CheckOutTime = shift2CheckOutTime
        self.nightCheckInTime = nightCheckInTime
        self.nightCheckOutTime = nightCheckOutTime
        self.maxCheckInLateMinutes = maxCheckInLateMinutes
        self.geofenceRadiusMeters = geofenceRadiusMeters
        self.arrivalRadiusMeters = arrivalRadiusMeters
        self.targetLatitude = targetLatitude
        self.targetLongitude = targetLongitude
        self.targetAddress = targetAddress
        self.pricePerKm = pricePerKm
        self.tripBaseAllowance = tripBaseAllowance
        self.overtimeMultiplier = overtimeMultiplier
        self.strictGeofenceBlocking = strictGeofenceBlocking
        self.autoCaptureGpsOnOpen = autoCaptureGpsOnOpen
    }
}

// MARK: - ATTENDANCE RECORD (ĐỒNG BỘ 1:1 VỚI ATTENDANCEMODELS.KT)
public struct AttendanceRecord: Identifiable, Codable, Hashable {
    public var id: String                        // att_YYYYMMDD_email_SHIFT
    public var userEmail: String
    public var userName: String
    public var userPhone: String
    public var maNhanVien: String
    public var employeeId: String
    public var departmentId: String
    public var departmentName: String
    public var donVi: String
    public var date: String                      // "2026-08-29"
    public var checkInTime: Int64
    public var checkInLat: Double
    public var checkInLng: Double
    public var checkInAddress: String
    public var checkInStatus: String              // "ON_TIME", "LATE"
    public var checkOutTime: Int64
    public var checkOutLat: Double
    public var checkOutLng: Double
    public var checkOutAddress: String
    public var checkOutStatus: String             // "NORMAL", "EARLY", "OVERTIME"
    public var totalWorkMinutes: Int
    public var note: String
    public var companyId: String
    public var shiftType: String                 // "HC", "SHIFT_1", "SHIFT_2", "NIGHT"
    public var scheduledShiftCode: String        // "S", "C", "HC", "TR", "NC", "P", "NL"
    public var isUnscheduled: Bool

    public init(
        id: String = "",
        userEmail: String = "",
        userName: String = "",
        userPhone: String = "",
        maNhanVien: String = "",
        employeeId: String = "",
        departmentId: String = "",
        departmentName: String = "",
        donVi: String = "",
        date: String = "",
        checkInTime: Int64 = 0,
        checkInLat: Double = 0.0,
        checkInLng: Double = 0.0,
        checkInAddress: String = "",
        checkInStatus: String = "ON_TIME",
        checkOutTime: Int64 = 0,
        checkOutLat: Double = 0.0,
        checkOutLng: Double = 0.0,
        checkOutAddress: String = "",
        checkOutStatus: String = "NORMAL",
        totalWorkMinutes: Int = 0,
        note: String = "",
        companyId: String = "",
        shiftType: String = "HC",
        scheduledShiftCode: String = "",
        isUnscheduled: Bool = false
    ) {
        self.id = id
        self.userEmail = userEmail
        self.userName = userName
        self.userPhone = userPhone
        self.maNhanVien = maNhanVien
        self.employeeId = employeeId
        self.departmentId = departmentId
        self.departmentName = departmentName
        self.donVi = donVi
        self.date = date
        self.checkInTime = checkInTime
        self.checkInLat = checkInLat
        self.checkInLng = checkInLng
        self.checkInAddress = checkInAddress
        self.checkInStatus = checkInStatus
        self.checkOutTime = checkOutTime
        self.checkOutLat = checkOutLat
        self.checkOutLng = checkOutLng
        self.checkOutAddress = checkOutAddress
        self.checkOutStatus = checkOutStatus
        self.totalWorkMinutes = totalWorkMinutes
        self.note = note
        self.companyId = companyId
        self.shiftType = shiftType
        self.scheduledShiftCode = scheduledShiftCode
        self.isUnscheduled = isUnscheduled
    }

    public var isCheckedIn: Bool { checkInTime > 0 }
    public var isCheckedOut: Bool { checkOutTime > 0 }

    public var isNightShift: Bool {
        let upper = shiftType.uppercased()
        return upper == "NIGHT" || upper == "SHIFT_3"
    }

    public var mnvDisplay: String {
        if !maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return employeeId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var shiftDisplayName: String {
        switch shiftType.uppercased() {
        case "SHIFT_1": return "Ca 1 (Sáng)"
        case "SHIFT_2": return "Ca 2 (Chiều)"
        case "NIGHT", "SHIFT_3": return "Ca 3 (Đêm)"
        case "DAY", "HC": return "Hành chính"
        default: return shiftType
        }
    }

    public var shiftShortName: String {
        switch shiftType.uppercased() {
        case "SHIFT_1": return "Ca 1"
        case "SHIFT_2": return "Ca 2"
        case "NIGHT", "SHIFT_3": return "Ca 3"
        default: return "HC"
        }
    }

    public var checkInTimeFormatted: String {
        guard checkInTime > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(checkInTime) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    public var checkInTimeShort: String {
        guard checkInTime > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(checkInTime) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    public var checkOutTimeFormatted: String {
        guard checkOutTime > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(checkOutTime) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    public var checkOutTimeShort: String {
        guard checkOutTime > 0 else { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(checkOutTime) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    public var workHoursFormatted: String {
        guard totalWorkMinutes > 0 else {
            if isCheckedIn && isCheckedOut {
                let diffM = max(0, Int((checkOutTime - checkInTime) / 60000))
                return "\(diffM / 60)h \(diffM % 60)m"
            }
            return "0h 0m"
        }
        let hours = totalWorkMinutes / 60
        let mins = totalWorkMinutes % 60
        return "\(hours)h \(mins)m"
    }
}

// MARK: - ATTENDANCE MONTHLY REPORT (ĐỒNG BỘ 1:1 VỚI ATTENDANCEMODELS.KT)
public struct AttendanceMonthlyReport: Identifiable, Codable {
    public var id: String { month }
    public var month: String = ""
    public var records: [AttendanceRecord] = []
    public var totalRecords: Int = 0
    public var onTimeCount: Int = 0
    public var lateCount: Int = 0
    public var earlyLeaveCount: Int = 0
    public var totalWorkHours: Double = 0.0
    public var onTimePercentage: Double = 0.0

    public init(
        month: String = "",
        records: [AttendanceRecord] = [],
        totalRecords: Int = 0,
        onTimeCount: Int = 0,
        lateCount: Int = 0,
        earlyLeaveCount: Int = 0,
        totalWorkHours: Double = 0.0,
        onTimePercentage: Double = 0.0
    ) {
        self.month = month
        self.records = records
        self.totalRecords = totalRecords
        self.onTimeCount = onTimeCount
        self.lateCount = lateCount
        self.earlyLeaveCount = earlyLeaveCount
        self.totalWorkHours = totalWorkHours
        self.onTimePercentage = onTimePercentage
    }
}
