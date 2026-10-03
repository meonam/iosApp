import Foundation

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
    public var pricePerKm: Double = 1500.0
    public var tripBaseAllowance: Double = 50000.0
    public var overtimeMultiplier: Double = 0.0
    public var strictGeofenceBlocking: Bool = false
    public var autoCaptureGpsOnOpen: Bool = true
    public var cancellationThresholdPercent: Int = 50
    public var underThresholdPolicy: String = "HALF_TRIP"
    public var underThresholdFlatFee: Double = 30000.0
    public var aboveThresholdPolicy: String = "FULL_TRIP"

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
        pricePerKm: Double = 1500.0,
        tripBaseAllowance: Double = 50000.0,
        overtimeMultiplier: Double = 0.0,
        strictGeofenceBlocking: Bool = false,
        autoCaptureGpsOnOpen: Bool = true,
        cancellationThresholdPercent: Int = 50,
        underThresholdPolicy: String = "HALF_TRIP",
        underThresholdFlatFee: Double = 30000.0,
        aboveThresholdPolicy: String = "FULL_TRIP"
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
        self.cancellationThresholdPercent = cancellationThresholdPercent
        self.underThresholdPolicy = underThresholdPolicy
        self.underThresholdFlatFee = underThresholdFlatFee
        self.aboveThresholdPolicy = aboveThresholdPolicy
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
    public var checkInDeviceId: String
    public var checkInDeviceName: String
    public var checkOutDeviceId: String
    public var checkOutDeviceName: String

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
        isUnscheduled: Bool = false,
        checkInDeviceId: String = "",
        checkInDeviceName: String = "",
        checkOutDeviceId: String = "",
        checkOutDeviceName: String = ""
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
        self.checkInDeviceId = checkInDeviceId
        self.checkInDeviceName = checkInDeviceName
        self.checkOutDeviceId = checkOutDeviceId
        self.checkOutDeviceName = checkOutDeviceName
    }

// MARK: - DEVICE BINDING RESULT (CHẶN ĐIỂM DANH HỘ)
public enum DeviceBindingResult {
    case success(isNewlyBound: Bool, deviceName: String)
    case deviceMismatch(boundDeviceName: String, currentDeviceName: String)
    case error(message: String)
}

    public var isCheckedIn: Bool { checkInTime > 0 }
    public var isCheckedOut: Bool { checkOutTime > 0 }

    public var isNightShift: Bool {
        let upper = shiftType.uppercased()
        return upper == "NIGHT" || upper == "SHIFT_3"
    }

    public var mnvDisplay: String {
        let clean = maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneClean = (clean.hasPrefix("0") && clean.count >= 9) || clean.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !clean.isEmpty && !isPhoneClean && clean.count >= 3 && clean.count <= 8 {
            return clean
        }
        let emp = employeeId.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneEmp = (emp.hasPrefix("0") && emp.count >= 9) || emp.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !emp.isEmpty && !isPhoneEmp && emp.count >= 3 && emp.count <= 8 {
            return emp
        }
        let standard = lookupStandardKtvMnv(email: userEmail, fullName: userName)
        return standard.isEmpty ? (clean.isEmpty ? emp : clean) : standard
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

// MARK: - STANDARD KTV MNV LOOKUP (ĐỒNG BỘ 1:1 VỚI ANDROID USER.KT)
public func lookupStandardKtvMnv(email: String?, fullName: String?) -> String {
    let em = (email ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let fn = (fullName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if em.hasPrefix("hieunt") || fn.contains("trung hiếu") || fn.contains("trung hieu") { return "24979" }
    if em.hasPrefix("tinnh") || fn.contains("hữu tín") || fn.contains("huu tin") { return "02104" }
    if em.hasPrefix("dungtt") || fn.contains("tiến dũng") || fn.contains("tien dung") { return "00289" }
    if em.hasPrefix("trinhtm") || fn.contains("minh trình") || fn.contains("minh trinh") { return "8564" }
    if em.hasPrefix("sangnt") || fn.contains("thanh sang") { return "19842" }
    if em.hasPrefix("nhat") || fn.contains("minh nhật") || fn.contains("minh nhat") { return "20972" }
    if em.hasPrefix("phucdh") || fn.contains("hữu phúc") || fn.contains("huu phuc") { return "26063" }
    if em.hasPrefix("tientb") || fn.contains("bá tiên") || fn.contains("ba tien") { return "28105" }
    if em.hasPrefix("trongpd") || fn.contains("đình trọng") || fn.contains("dinh trong") { return "31290" }
    if em.hasPrefix("huydq") || fn.contains("quốc huy") || fn.contains("quoc huy") { return "33430" }
    if em.hasPrefix("linhnd") || fn.contains("duy linh") { return "43144" }
    if em.hasPrefix("khanh-ht") || fn.contains("thân khánh") || fn.contains("than khanh") { return "35713" }
    if em.hasPrefix("duchna") || fn.contains("anh đức") || fn.contains("anh duc") { return "NVDUCHN" }
    if em.hasPrefix("hungnp") || fn.contains("phước hưng") || fn.contains("phuoc hung") { return "NVHUNGN" }
    if em.hasPrefix("haph") || fn.contains("hải hà") || fn.contains("hai ha") { return "NVHAPH" }
    if em.hasPrefix("minh") || fn.contains("huy minh") { return "NVMINH" }
    return ""
}

// MARK: - TECHNICIAN ATTENDANCE SUMMARY (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct TechnicianAttendanceSummary: Identifiable, Codable, Hashable {
    public var id: String { technicianEmail.isEmpty ? technicianName : technicianEmail }
    public var technicianEmail: String = ""
    public var technicianName: String = ""
    public var maNhanVien: String = ""
    public var employeeId: String = ""
    public var departmentName: String = ""
    public var totalDays: Int = 0
    public var onTimeDays: Int = 0
    public var lateDays: Int = 0
    public var earlyDays: Int = 0
    public var totalHours: Double = 0.0

    public init(
        technicianEmail: String = "",
        technicianName: String = "",
        maNhanVien: String = "",
        employeeId: String = "",
        departmentName: String = "",
        totalDays: Int = 0,
        onTimeDays: Int = 0,
        lateDays: Int = 0,
        earlyDays: Int = 0,
        totalHours: Double = 0.0
    ) {
        self.technicianEmail = technicianEmail
        self.technicianName = technicianName
        self.maNhanVien = maNhanVien
        self.employeeId = employeeId
        self.departmentName = departmentName
        self.totalDays = totalDays
        self.onTimeDays = onTimeDays
        self.lateDays = lateDays
        self.earlyDays = earlyDays
        self.totalHours = totalHours
    }

    public var onTimeRate: Double {
        totalDays > 0 ? (Double(onTimeDays) / Double(totalDays)) * 100.0 : 0.0
    }

    public var mnvDisplay: String {
        let clean = maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneClean = (clean.hasPrefix("0") && clean.count >= 9) || clean.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !clean.isEmpty && !isPhoneClean && clean.count >= 3 && clean.count <= 8 {
            return clean
        }
        let emp = employeeId.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneEmp = (emp.hasPrefix("0") && emp.count >= 9) || emp.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !emp.isEmpty && !isPhoneEmp && emp.count >= 3 && emp.count <= 8 {
            return emp
        }
        let standard = lookupStandardKtvMnv(email: technicianEmail, fullName: technicianName)
        return standard.isEmpty ? (clean.isEmpty ? emp : clean) : standard
    }
}

// MARK: - ATTENDANCE MONTHLY REPORT (ĐỒNG BỘ 1:1 VỚI ATTENDANCEMODELS.KT)
public struct AttendanceMonthlyReport: Identifiable, Codable {
    public var id: String { month }
    public var month: String = ""
    public var totalWorkDays: Int = 0
    public var totalRecords: Int = 0
    public var onTimeCount: Int = 0
    public var lateCount: Int = 0
    public var earlyLeaveCount: Int = 0
    public var totalWorkHours: Double = 0.0
    public var onTimePercentage: Double = 0.0
    public var records: [AttendanceRecord] = []
    public var technicianSummaries: [TechnicianAttendanceSummary] = []

    public init(
        month: String = "",
        totalWorkDays: Int = 0,
        totalRecords: Int = 0,
        onTimeCount: Int = 0,
        lateCount: Int = 0,
        earlyLeaveCount: Int = 0,
        totalWorkHours: Double = 0.0,
        onTimePercentage: Double = 0.0,
        records: [AttendanceRecord] = [],
        technicianSummaries: [TechnicianAttendanceSummary] = []
    ) {
        self.month = month
        self.totalWorkDays = totalWorkDays
        self.totalRecords = totalRecords
        self.onTimeCount = onTimeCount
        self.lateCount = lateCount
        self.earlyLeaveCount = earlyLeaveCount
        self.totalWorkHours = totalWorkHours
        self.onTimePercentage = onTimePercentage
        self.records = records
        self.technicianSummaries = technicianSummaries
    }
}

// MARK: - TRAVEL EXPENSE RECORD (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct TravelExpenseRecord: Identifiable, Codable, Hashable {
    public var id: String
    public var ticketId: String
    public var ticketSubject: String
    public var technicianEmail: String
    public var technicianName: String
    public var departmentId: String
    public var fromDonVi: String
    public var toDonVi: String
    public var date: String
    public var timestamp: Int64
    public var distanceKm: Double
    public var kmExpenseAmount: Double
    public var tripAllowanceAmount: Double
    public var totalAmount: Double
    public var status: String // "PENDING", "APPROVED", "PAID", "REJECTED"
    public var approvedBy: String
    public var approvedAt: Int64
    public var note: String
    public var rejectReason: String

    public init(
        id: String = "",
        ticketId: String = "",
        ticketSubject: String = "",
        technicianEmail: String = "",
        technicianName: String = "",
        departmentId: String = "",
        fromDonVi: String = "",
        toDonVi: String = "",
        date: String = "",
        timestamp: Int64 = 0,
        distanceKm: Double = 0.0,
        kmExpenseAmount: Double = 0.0,
        tripAllowanceAmount: Double = 0.0,
        totalAmount: Double = 0.0,
        status: String = "PENDING",
        approvedBy: String = "",
        approvedAt: Int64 = 0,
        note: String = "",
        rejectReason: String = ""
    ) {
        self.id = id
        self.ticketId = ticketId
        self.ticketSubject = ticketSubject
        self.technicianEmail = technicianEmail
        self.technicianName = technicianName
        self.departmentId = departmentId
        self.fromDonVi = fromDonVi
        self.toDonVi = toDonVi
        self.date = date
        self.timestamp = timestamp
        self.distanceKm = distanceKm
        self.kmExpenseAmount = kmExpenseAmount
        self.tripAllowanceAmount = tripAllowanceAmount
        self.totalAmount = totalAmount
        self.status = status
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.note = note
        self.rejectReason = rejectReason
    }
}

// MARK: - TECHNICIAN EXPENSE SUMMARY (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct TechnicianExpenseSummary: Identifiable, Codable, Hashable {
    public var id: String { technicianEmail.isEmpty ? technicianName : technicianEmail }
    public var technicianEmail: String = ""
    public var technicianName: String = ""
    public var maNhanVien: String = ""
    public var employeeId: String = ""
    public var departmentName: String = ""
    public var totalTrips: Int = 0
    public var totalDistanceKm: Double = 0.0
    public var totalAmount: Double = 0.0
    public var pendingAmount: Double = 0.0
    public var approvedAmount: Double = 0.0
    public var paidAmount: Double = 0.0
    public var rejectedAmount: Double = 0.0
    public var pendingCount: Int = 0
    public var approvedCount: Int = 0
    public var paidCount: Int = 0
    public var rejectedCount: Int = 0

    public init(
        technicianEmail: String = "",
        technicianName: String = "",
        maNhanVien: String = "",
        employeeId: String = "",
        departmentName: String = "",
        totalTrips: Int = 0,
        totalDistanceKm: Double = 0.0,
        totalAmount: Double = 0.0,
        pendingAmount: Double = 0.0,
        approvedAmount: Double = 0.0,
        paidAmount: Double = 0.0,
        rejectedAmount: Double = 0.0,
        pendingCount: Int = 0,
        approvedCount: Int = 0,
        paidCount: Int = 0,
        rejectedCount: Int = 0
    ) {
        self.technicianEmail = technicianEmail
        self.technicianName = technicianName
        self.maNhanVien = maNhanVien
        self.employeeId = employeeId
        self.departmentName = departmentName
        self.totalTrips = totalTrips
        self.totalDistanceKm = totalDistanceKm
        self.totalAmount = totalAmount
        self.pendingAmount = pendingAmount
        self.approvedAmount = approvedAmount
        self.paidAmount = paidAmount
        self.rejectedAmount = rejectedAmount
        self.pendingCount = pendingCount
        self.approvedCount = approvedCount
        self.paidCount = paidCount
        self.rejectedCount = rejectedCount
    }

    public var mnvDisplay: String {
        let clean = maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneClean = (clean.hasPrefix("0") && clean.count >= 9) || clean.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !clean.isEmpty && !isPhoneClean && clean.count >= 3 && clean.count <= 8 {
            return clean
        }
        let emp = employeeId.trimmingCharacters(in: .whitespacesAndNewlines)
        let isPhoneEmp = (emp.hasPrefix("0") && emp.count >= 9) || emp.range(of: "^[0-9]{10}$", options: .regularExpression) != nil
        if !emp.isEmpty && !isPhoneEmp && emp.count >= 3 && emp.count <= 8 {
            return emp
        }
        let standard = lookupStandardKtvMnv(email: technicianEmail, fullName: technicianName)
        return standard.isEmpty ? (clean.isEmpty ? emp : clean) : standard
    }
}

// MARK: - TRAVEL EXPENSE REPORT (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct TravelExpenseReport: Identifiable, Codable {
    public var id: String { month }
    public var month: String = ""
    public var totalTrips: Int = 0
    public var totalDistanceKm: Double = 0.0
    public var totalExpenseAmount: Double = 0.0
    public var pendingAmount: Double = 0.0
    public var approvedAmount: Double = 0.0
    public var paidAmount: Double = 0.0
    public var rejectedAmount: Double = 0.0
    public var records: [TravelExpenseRecord] = []
    public var technicianSummaries: [TechnicianExpenseSummary] = []

    public init(
        month: String = "",
        totalTrips: Int = 0,
        totalDistanceKm: Double = 0.0,
        totalExpenseAmount: Double = 0.0,
        pendingAmount: Double = 0.0,
        approvedAmount: Double = 0.0,
        paidAmount: Double = 0.0,
        rejectedAmount: Double = 0.0,
        records: [TravelExpenseRecord] = [],
        technicianSummaries: [TechnicianExpenseSummary] = []
    ) {
        self.month = month
        self.totalTrips = totalTrips
        self.totalDistanceKm = totalDistanceKm
        self.totalExpenseAmount = totalExpenseAmount
        self.pendingAmount = pendingAmount
        self.approvedAmount = approvedAmount
        self.paidAmount = paidAmount
        self.rejectedAmount = rejectedAmount
        self.records = records
        self.technicianSummaries = technicianSummaries
    }
}
