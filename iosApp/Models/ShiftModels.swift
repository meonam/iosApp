import Foundation

// MARK: - SHIFT CODE (MÃ CA LÀM VIỆC CHUẨN)
public struct ShiftCode {
    public static let sang = "S"          // Sáng
    public static let chieu = "C"         // Chiều
    public static let nghiCa = "NC"       // Nghỉ ca
    public static let congTac = "CT"      // Công tác / Kiểm kê
    public static let phep = "P"          // Nghỉ phép
    public static let hanhChanh = "HC"    // Hành chánh
    public static let truc = "TR"         // Trực hỗ trợ
    public static let hop = "H"           // Hội họp / Đào tạo
    public static let nghiMat = "NM"      // Nghỉ mát
    public static let nghiLe = "NL"       // Nghỉ lễ

    public static let allCodes: [String] = [
        sang, chieu, nghiCa, congTac, phep, hanhChanh, truc, hop, nghiMat, nghiLe
    ]

    public static func label(for code: String) -> String {
        switch code.uppercased() {
        case sang: return "Sáng"
        case chieu: return "Chiều"
        case nghiCa: return "Nghỉ ca"
        case congTac: return "Công tác"
        case phep: return "Nghỉ phép"
        case hanhChanh: return "Hành chánh"
        case truc: return "Trực HT"
        case hop: return "Hội họp"
        case nghiMat: return "Nghỉ mát"
        case nghiLe: return "Nghỉ lễ"
        default: return code
        }
    }
}

// MARK: - SHIFT ENTRY (DÒNG LỊCH CA CỦA NHÂN VIÊN)
public struct ShiftEntry: Identifiable, Codable, Hashable {
    public var id: String { employeeId }
    public var employeeId: String
    public var employeeName: String
    public var days: [String: String] // "mon" -> "S", "tue" -> "C", etc.
    public var maKhuVuc: String
    public var donVi: String

    public init(
        employeeId: String = "",
        employeeName: String = "",
        days: [String: String] = [:],
        maKhuVuc: String = "",
        donVi: String = ""
    ) {
        self.employeeId = employeeId
        self.employeeName = employeeName
        self.days = days
        self.maKhuVuc = maKhuVuc
        self.donVi = donVi
    }
}

// MARK: - SHIFT SCHEDULE (BẢNG LỊCH CA TUẦN)
public struct ShiftSchedule: Identifiable, Codable, Hashable {
    public var id: String            // weekId: "2026-W37"
    public var companyId: String
    public var weekStart: Int64       // Timestamp Thứ 2 đầu tuần
    public var updatedBy: String
    public var updatedAt: Int64
    public var entries: [ShiftEntry]

    public init(
        id: String = "",
        companyId: String = "",
        weekStart: Int64 = 0,
        updatedBy: String = "",
        updatedAt: Int64 = 0,
        entries: [ShiftEntry] = []
    ) {
        self.id = id
        self.companyId = companyId
        self.weekStart = weekStart
        self.updatedBy = updatedBy
        self.updatedAt = updatedAt
        self.entries = entries
    }
}
