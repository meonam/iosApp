import Foundation

// MARK: - SUPER ADMIN CONFIG (ĐỒNG BỘ 1:1 VỚI SUPERADMINCONFIG TRÊN ANDROID)
public struct SuperAdminConfig {
    public static let superAdminEmails: Set<String> = [
        "superadmin@qltb.com",
        "admin@qltb.com",
        "developer@qltb.com",
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
    public var disabledReason: String
    public var emailVerified: Bool
    public var disabledAt: Int64
    public var disabledBy: String

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
        permissions: [String] = [],
        disabledReason: String = "",
        emailVerified: Bool = false,
        disabledAt: Int64 = 0,
        disabledBy: String = ""
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
        self.disabledReason = disabledReason
        self.emailVerified = emailVerified
        self.disabledAt = disabledAt
        self.disabledBy = disabledBy
    }

    // Computed Properties phân quyền chuẩn xác 1:1 theo User.kt
    public var unitId: String { donVi }
    public var khuVuc: String { maKhuVuc }

    public var isSuperAdmin: Bool {
        SuperAdminConfig.isSuperAdmin(email: email, role: role)
    }

    public var isAdmin: Bool {
        if isSuperAdmin { return true }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return r == "ADMIN" || r == "QUANTRI" || r == "QUAN_TRI"
    }

    public var isHelpDesk: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return r == "HELPDESK" || r == "HELP_DESK" || r == "HD"
    }

    public var isWarehouse: Bool {
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["WAREHOUSE", "KHO", "THUKHO", "QUANLYKHO"].contains(r)
    }

    public var isSpecialist: Bool {
        if isSuperAdmin || isAdmin || isHelpDesk || isWarehouse { return false }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let t = toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines)
        let dept = departmentId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["CHUYENVIEN", "CHUYEN_VIEN", "SPECIALIST", "CHUYÊN VIÊN"].contains(r) ||
               r.contains("CHUYENVIEN") || r.contains("SPECIALIST") || r.contains("CHUYEN VIEN") ||
               !t.isEmpty || dept.hasPrefix("TO_") || dept.contains("NGHIEP_VU") || dept.contains("NGHIỆP VỤ")
    }

    public var isManager: Bool {
        if isSuperAdmin || isAdmin || isHelpDesk || isWarehouse || isSpecialist { return false }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["PHONGBAN", "QUANLY", "MANAGER", "LEADER", "TRUONGPHONG", "PHOPHONG"].contains(r)
    }

    public var isTechnician: Bool {
        if isSuperAdmin || isAdmin || isHelpDesk || isWarehouse || isSpecialist { return false }
        let r = role.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return ["KYTHUAT", "KYTHUATVIEN", "KTV", "KY_THUAT", "TECHNICIAN", "KỸ THUẬT", "KỸ THUẬT VIÊN", "INCIDENT_HANDLER"].contains(r) ||
               r.contains("KTV") || r.contains("KYTHUAT") || r.contains("TECHNICIAN") || r.contains("INCIDENT_HANDLER")
    }

    public var isStaff: Bool {
        return !isSuperAdmin && !isAdmin && !isHelpDesk && !isWarehouse && !isManager && !isTechnician && !isSpecialist
    }

    /// Quyền tạo yêu cầu hỗ trợ mới: Chỉ dành cho Nhân viên (Staff/User) và Quản lý phòng ban (Manager).
    /// Admin, HelpDesk, Kỹ thuật viên (KTV), và Chuyên viên nghiệp vụ KHÔNG được tạo phiếu mới (chỉ nhận và xử lý điều phối).
    /// Đồng bộ chuẩn xác 1:1 với MainActivity.kt (Android), SupportTicketList.tsx (Web), và SupportScreen.kt (Desktop).
    public var canCreateTicket: Bool {
        return !isSuperAdmin && !isAdmin && !isHelpDesk && !isTechnician && !isSpecialist
    }

    public var roleTitle: String {
        if isAdmin { return "Quản trị viên (Admin)" }
        if isHelpDesk { return "Phòng Helpdesk" }
        if isWarehouse { return "Quản trị kho" }
        if isManager { return "Quản lý phòng ban" }
        if isSpecialist { return "Chuyên viên" }
        if isTechnician { return "KTV" }
        return "Nhân viên"
    }

    public var roleDisplayName: String {
        return roleTitle
    }

    public var departmentName: String {
        return !departmentId.isEmpty ? departmentId : donVi
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
