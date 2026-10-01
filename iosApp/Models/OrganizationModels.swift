import Foundation

// MARK: - DEPARTMENT MODEL (PHÒNG BAN - ĐỒNG BỘ 1:1 VỚI DEPARTMENT.KT)
public struct Department: Identifiable, Codable, Hashable {
    public var id: String { departmentId }
    public var departmentId: String
    public var companyId: String
    public var departmentName: String
    public var departmentType: String // IT, EQUIPMENT, UNIT, GENERAL, HELPDESK, INCIDENT_HANDLER, WAREHOUSE
    public var isHelpDesk: Bool
    public var isIncidentHandler: Bool
    public var isWarehouse: Bool
    public var isApplicationSupport: Bool
    public var managerEmail: String
    public var managerName: String
    public var hotline: String
    public var location: String
    public var assignedRegionId: String
    public var slaResponseMinutes: Int
    public var slaResolveMinutes: Int
    public var isActive: Bool
    public var parentDepartmentId: String
    public var colorHex: String
    public var khuVucPhuTrach: [String]

    public init(
        departmentId: String = "",
        companyId: String = "",
        departmentName: String = "",
        departmentType: String = "GENERAL",
        isHelpDesk: Bool = false,
        isIncidentHandler: Bool = false,
        isWarehouse: Bool = false,
        isApplicationSupport: Bool = false,
        managerEmail: String = "",
        managerName: String = "",
        hotline: String = "",
        location: String = "",
        assignedRegionId: String = "",
        slaResponseMinutes: Int = 30,
        slaResolveMinutes: Int = 240,
        isActive: Bool = true,
        parentDepartmentId: String = "",
        colorHex: String = "#3B82F6",
        khuVucPhuTrach: [String] = []
    ) {
        self.departmentId = departmentId
        self.companyId = companyId
        self.departmentName = departmentName
        self.departmentType = departmentType
        self.isHelpDesk = isHelpDesk
        self.isIncidentHandler = isIncidentHandler
        self.isWarehouse = isWarehouse
        self.isApplicationSupport = isApplicationSupport
        self.managerEmail = managerEmail
        self.managerName = managerName
        self.hotline = hotline
        self.location = location
        self.assignedRegionId = assignedRegionId
        self.slaResponseMinutes = slaResponseMinutes
        self.slaResolveMinutes = slaResolveMinutes
        self.isActive = isActive
        self.parentDepartmentId = parentDepartmentId
        self.colorHex = colorHex
        self.khuVucPhuTrach = khuVucPhuTrach
    }
}

// MARK: - DON VI MODEL (ĐƠN VỊ / CHI NHÁNH - ĐỒNG BỘ 1:1 VỚI DONVI.KT)
public struct DonVi: Identifiable, Codable, Hashable {
    public var id: String
    public var tenDonVi: String
    public var maKhuVuc: String
    public var companyId: String

    public init(id: String, tenDonVi: String, maKhuVuc: String = "", companyId: String = "") {
        self.id = id
        self.tenDonVi = tenDonVi
        self.maKhuVuc = maKhuVuc
        self.companyId = companyId
    }
}

// MARK: - KHU VUC MODEL (CỤM / KHU VỰC - ĐỒNG BỘ 1:1 VỚI KHUVUC.KT)
public struct KhuVuc: Identifiable, Codable, Hashable {
    public var id: String { maKhuVuc.isEmpty ? UUID().uuidString : maKhuVuc }
    public var maKhuVuc: String
    public var tenKhuVuc: String
    public var moTa: String
    public var nguoiPhuTrach: String
    public var sdtLienHe: String
    public var companyId: String
    public var createdAt: Int64

    public init(
        id: String = "",
        maKhuVuc: String,
        tenKhuVuc: String,
        moTa: String = "",
        nguoiPhuTrach: String = "",
        sdtLienHe: String = "",
        companyId: String = "",
        createdAt: Int64 = 0
    ) {
        self.maKhuVuc = maKhuVuc
        self.tenKhuVuc = tenKhuVuc
        self.moTa = moTa
        self.nguoiPhuTrach = nguoiPhuTrach
        self.sdtLienHe = sdtLienHe
        self.companyId = companyId
        self.createdAt = createdAt
    }
}
// MARK: - SPECIALIST TEAM
public struct SpecialistTeam: Identifiable, Codable, Hashable {
    public var id: String
    public var teamId: String
    public var teamName: String
    public var applications: [String]
    public var description: String
    public var moTa: String
    public var truongTo: String
    public var sdtLienHe: String
    public var companyId: String
    public var updatedAt: Int64

    public init(id: String, teamId: String, teamName: String, applications: [String] = [], description: String = "", moTa: String = "", truongTo: String = "", sdtLienHe: String = "", companyId: String = "", updatedAt: Int64 = 0) {
        self.id = id
        self.teamId = teamId
        self.teamName = teamName
        self.applications = applications
        self.description = description
        self.moTa = moTa
        self.truongTo = truongTo
        self.sdtLienHe = sdtLienHe
        self.companyId = companyId
        self.updatedAt = updatedAt
    }
}

// MARK: - SPECIALIST TEAM INFO & DEFAULTS (ĐỒNG BỘ 1:1 VỚI ANDROID SPECIALISTTEAMDEFAULTS)
public struct SpecialistTeamInfo: Identifiable, Hashable, Codable {
    public var teamId: String
    public var teamName: String
    public var applications: [String]
    public var description: String

    public var id: String { teamId }
    public var name: String { teamName }

    public init(teamId: String, teamName: String, applications: [String] = [], description: String = "") {
        self.teamId = teamId
        self.teamName = teamName
        self.applications = applications
        self.description = description
    }
}

public struct SpecialistTeamDefaults {
    public static let TEAMS: [SpecialistTeamInfo] = [
        SpecialistTeamInfo(
            teamId: "TO_HA_TANG_BAO_MAT",
            teamName: "HẠ TẦNG MẠNG & BẢO MẬT",
            applications: ["HẠ TẦNG & MẠNG", "AN NINH BẢO MẬT"],
            description: "Chuyên trách hệ thống mạng, bảo mật, máy chủ hạ tầng"
        ),
        SpecialistTeamInfo(
            teamId: "TO_KY_THUAT_UNG_DUNG",
            teamName: "KỸ THUẬT ỨNG DỤNG",
            applications: ["MMS (Kỹ thuật)", "ORACLE", "Văn phòng điện tử", "KHTV", "TOPOS"],
            description: "Hỗ trợ kỹ thuật ứng dụng lõi, POS, CSDL Oracle"
        ),
        SpecialistTeamInfo(
            teamId: "TO_PHAN_TICH_NGHIEP_VU",
            teamName: "PHÂN TÍCH NGHIỆP VỤ",
            applications: ["MMS (Nghiệp vụ)", "OMNI", "Nhập liệu tự động", "ERP MCS/Bách Hóa"],
            description: "Nghiệp vụ MMS, bán lẻ OMNI, quy trình ERP"
        ),
        SpecialistTeamInfo(
            teamId: "TO_NEN_TANG_DU_LIEU",
            teamName: "NỀN TẢNG DỮ LIỆU",
            applications: ["TOOLS NỘI BỘ", "REPORT TOOL"],
            description: "Phân tích, báo cáo dữ liệu và công cụ nội bộ"
        ),
        SpecialistTeamInfo(
            teamId: "TO_RND_CONG_NGHE",
            teamName: "NGHIÊN CỨU VÀ PHÁT TRIỂN CÔNG NGHỆ",
            applications: ["CHƯƠNG TRÌNH ĐẶT HÀNG OMS", "CHƯƠNG TRÌNH ĐẶT HÀNG D&F", "APP CHÀO HÀNG ONLINE"],
            description: "Ứng dụng di động, OMS, thương mại điện tử R&D"
        )
    ]

    public static let ALL_APPLICATIONS: [String] = Array(Set(TEAMS.flatMap { $0.applications })).sorted()

    public static func getApplicationsForTeam(teamName: String) -> [String] {
        let team = TEAMS.first {
            $0.teamName.caseInsensitiveCompare(teamName) == .orderedSame ||
            $0.teamId.caseInsensitiveCompare(teamName) == .orderedSame
        }
        return team?.applications ?? []
    }

    public static func findTeamForApplication(app: String) -> SpecialistTeamInfo? {
        return TEAMS.first { team in
            team.applications.contains { $0.caseInsensitiveCompare(app) == .orderedSame }
        }
    }

    public static func resolveTeamDisplayName(_ raw: String) -> String {
        var t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("(") { t.removeFirst() }
        if t.hasSuffix(")") { t.removeLast() }
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = ["thuộc Tổ ", "thuộc tổ ", "Thuộc Tổ ", "Tổ ", "tổ ", "thuộc ", "Thuộc "]
        for p in prefixes {
            if t.lowercased().hasPrefix(p.lowercased()) {
                t = String(t.dropFirst(p.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        if t.isEmpty || t.caseInsensitiveCompare("thuộc") == .orderedSame || t.caseInsensitiveCompare("Tổ thuộc") == .orderedSame {
            return ""
        }

        if let found = TEAMS.first(where: {
            $0.teamId.caseInsensitiveCompare(t) == .orderedSame ||
            $0.teamName.caseInsensitiveCompare(t) == .orderedSame ||
            $0.teamId.localizedCaseInsensitiveContains(t) ||
            t.localizedCaseInsensitiveContains($0.teamId) ||
            $0.teamName.localizedCaseInsensitiveContains(t)
        }) {
            return found.teamName
        }

        let upper = t.uppercased()
        if upper.contains("HA_TANG") || upper.contains("HẠ TẦNG") { return "HẠ TẦNG MẠNG & BẢO MẬT" }
        if upper.contains("KY_THUAT") || upper.contains("KỸ THUẬT") { return "KỸ THUẬT ỨNG DỤNG" }
        if upper.contains("PHAN_TICH") || upper.contains("PHÂN TÍCH") { return "PHÂN TÍCH NGHIỆP VỤ" }
        if upper.contains("NEN_TANG") || upper.contains("NỀN TẢNG") { return "NỀN TẢNG DỮ LIỆU" }
        if upper.contains("RND") || upper.contains("NGHIÊN CỨU") || upper.contains("CONG_NGHE") { return "NGHIÊN CỨU VÀ PHÁT TRIỂN CÔNG NGHỆ" }

        return t
    }
}

