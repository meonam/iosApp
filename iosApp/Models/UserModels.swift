import Foundation

// MARK: - SUPER ADMIN CONFIG (ĐỒNG BỘ 1:1 VỚI SUPERADMINCONFIG TRÊN ANDROID)
public struct SuperAdminConfig {
    public static let superAdminEmails: Set<String> = [
        "nammeo0101@gmail.com",
        "devicemanagement0101@gmail.com",
        "huyenhan@gmail.com",
        "developer@qltb.com",
        "superadmin@qltb.com",
        "admin@qltb.com",
        "dev@qltb.com"
    ]

    public static func isSuperAdmin(email: String?, role: String? = nil) -> Bool {
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty {
            if superAdminEmails.contains(email) || email.hasPrefix("dev.") || email.hasPrefix("superadmin.") || email.hasPrefix("dev_") || email.hasPrefix("superadmin_") {
                return true
            }
        }
        if let role = role?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !role.isEmpty {
            if role == "SUPER_ADMIN" || role == "SUPERADMIN" || role == "DEVELOPER" {
                return true
            }
        }
        return false
    }
}

// MARK: - USER MODEL (ĐỒNG BỘ 1:1 VỚI USER.KT TRÊN ANDROID)
public struct User: Identifiable, Codable, Hashable {
    public var id: String { email }
    public var maNhanVien: String
    public var email: String
    public var role: String
    public var fullName: String
    public var phone: String
    public var donVi: String
    public var companyId: String
    public var departmentId: String
    public var status: String
    public var avatarUrl: String
    public var createdAt: Int64
    public var mustChangePassword: Bool
    public var maKhuVuc: String
    public var toNghiepVu: String
    public var lastActiveAt: Int64
    public var isOnline: Bool
    public var permissions: [String]

    public init(
        maNhanVien: String = "",
        email: String = "",
        role: String = "STAFF",
        fullName: String = "",
        phone: String = "",
        donVi: String = "",
        companyId: String = "",
        departmentId: String = "",
        status: String = "ACTIVE",
        avatarUrl: String = "",
        createdAt: Int64 = 0,
        mustChangePassword: Bool = false,
        maKhuVuc: String = "",
        toNghiepVu: String = "",
        lastActiveAt: Int64 = 0,
        isOnline: Bool = false,
        permissions: [String] = []
    ) {
        self.maNhanVien = maNhanVien
        self.email = email
        self.role = role
        self.fullName = fullName
        self.phone = phone
        self.donVi = donVi
        self.companyId = companyId
        self.departmentId = departmentId
        self.status = status
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
        self.mustChangePassword = mustChangePassword
        self.maKhuVuc = maKhuVuc
        self.toNghiepVu = toNghiepVu
        self.lastActiveAt = lastActiveAt
        self.isOnline = isOnline
        self.permissions = permissions
    }

    // Computed Properties phân quyền chuẩn xác 1:1 theo User.kt
    public var unitId: String { donVi }

    public var isSuperAdmin: Bool {
        SuperAdminConfig.isSuperAdmin(email: email, role: role)
    }

    public var isAdmin: Bool {
        if isSuperAdmin { return true }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return r == "ADMIN" || r == "QUANTRI" || r == "QUAN_TRI" || r.contains("ADMIN")
    }

    public var isHelpDesk: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return r == "HELPDESK" || r == "HELP_DESK" || r == "HD" || r.contains("HELPDESK")
    }

    public var isWarehouse: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["WAREHOUSE", "KHO", "THUKHO", "QUANLYKHO"].contains(r) || r.contains("KHO") || r.contains("WAREHOUSE")
    }

    public var isManager: Bool {
        if isSuperAdmin || isAdmin || isHelpDesk || isWarehouse { return false }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["PHONGBAN", "QUANLY", "MANAGER", "LEADER", "TRUONGPHONG", "PHOPHONG"].contains(r) ||
               r.contains("PHONG") || r.contains("QUANLY") || r.contains("TRUONG") || r.contains("MANAGER")
    }

    public var isSpecialist: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let d = departmentId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let t = toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["CHUYENVIEN", "CHUYEN_VIEN", "SPECIALIST"].contains(r) ||
               r.contains("CHUYENVIEN") || r.contains("SPECIALIST") || r.contains("CHUYEN VIEN") ||
               d.hasPrefix("TO_") || d.contains("NGHIỆP VỤ") || d.contains("NGHIEP VU") ||
               d.contains("ỨNG DỤNG") || d.contains("UNG DUNG") ||
               !t.isEmpty
    }

    public var isTechnician: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let d = departmentId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let dv = donVi.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isTechRoleOrDept = ["KYTHUAT", "KYTHUATVIEN", "KTV", "TECHNICIAN", "IT"].contains(r) ||
               r.contains("KTV") || r.contains("KYTHUAT") || r.contains("TECH") || r.contains("SUPPORT") ||
               d.contains("XỬ LÝ") || d.contains("SỰ CỐ") || d.contains("KỸ THUẬT") || d.contains("IT") || d.contains("BẢO TRÌ") ||
               dv.contains("KỸ THUẬT")
        return isTechRoleOrDept || isSpecialist
    }

    public var isStaff: Bool {
        return !isSuperAdmin && !isAdmin && !isHelpDesk && !isWarehouse && !isManager && !isTechnician && !isSpecialist
    }

    public var roleTitle: String {
        if isAdmin { return "Quản trị viên (Admin)" }
        if isHelpDesk { return "Phòng Helpdesk" }
        if isManager { return "Quản lý phòng ban" }
        if isTechnician { return "Kỹ thuật viên" }
        if isSpecialist { return "Chuyên viên" }
        return "Nhân viên"
    }

    public var roleDisplayName: String {
        return roleTitle
    }

    public var departmentName: String {
        return !donVi.isEmpty ? donVi : departmentId
    }

    public var companyName: String {
        return !companyId.isEmpty ? companyId : "SGCOOP"
    }

    public var mnvDisplay: String {
        if !maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let std = lookupStandardKtvMnv(email: email, fullName: fullName)
        if !std.isEmpty { return std }
        let cleanEmail = email.components(separatedBy: "@").first?.filter { $0.isLetter || $0.isNumber }.prefix(5).uppercased() ?? ""
        return !cleanEmail.isEmpty ? "NV\(cleanEmail)" : "NV"
    }
}

// MARK: - TRA CỨU MÃ NHÂN VIÊN CHUẨN KTV/CHUYÊN VIÊN (ĐỒNG BỘ 1:1 ANDROID USER.KT)
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
