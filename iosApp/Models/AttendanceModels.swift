import Foundation

// MARK: - ATTENDANCE RECORD (ĐỒNG BỘ 1:1 VỚI ATTENDANCEMODELS.KT)
public struct AttendanceRecord: Identifiable, Codable, Hashable {
    public var id: String                        // att_YYYYMMDD_email
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

    public var shiftDisplayName: String {
        switch shiftType.uppercased() {
        case "SHIFT_1": return "Ca 1 (Sáng)"
        case "SHIFT_2": return "Ca 2 (Chiều)"
        case "NIGHT", "SHIFT_3": return "Ca 3 (Đêm)"
        case "DAY", "HC": return "Hành chính"
        default: return shiftType
        }
    }
}
