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

    public var isTechnician: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["KYTHUAT", "KYTHUATVIEN", "KTV", "TECHNICIAN", "IT"].contains(r) || r.contains("KTV") || r.contains("KYTHUAT")
    }

    public var isSpecialist: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["CHUYENVIEN", "CHUYEN_VIEN", "SPECIALIST"].contains(r) || r.contains("CHUYENVIEN")
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
        let cleanEmail = email.components(separatedBy: "@").first?.filter { $0.isLetter || $0.isNumber }.prefix(5).uppercased() ?? ""
        return !cleanEmail.isEmpty ? "NV\(cleanEmail)" : "NV"
    }
}
