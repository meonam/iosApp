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
