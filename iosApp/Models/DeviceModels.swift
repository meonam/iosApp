import SwiftUI

// MARK: - DEVICE STATUS CONSTANTS (ĐỒNG BỘ 1:1 VỚI THIETBI.KT TRÊN ANDROID)
public struct DeviceStatusConstants {
    public static let statusNew = "Mới nhập"
    public static let statusInStock = "Trong kho (Sẵn sàng)"
    public static let statusInUse = "Đang sử dụng"
    public static let statusOnLoan = "Đang cho mượn"
    public static let statusRepair = "Đang sửa chữa / Bảo hành"
    public static let statusBroken = "Hỏng / Chờ xử lý"
    public static let statusLiquidated = "Đã thanh lý"

    public static let allStatuses: [String] = [
        statusNew,
        statusInStock,
        statusInUse,
        statusOnLoan,
        statusRepair,
        statusBroken,
        statusLiquidated
    ]

    public static func normalize(_ raw: String?, phongBan: String? = nil, roleOrUser: String? = nil) -> String {
        guard let s = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return (phongBan != nil && !phongBan!.isEmpty) || (roleOrUser != nil && !roleOrUser!.isEmpty) ? statusInUse : statusInStock
        }
        let lower = s.lowercased()
        if s.caseInsensitiveCompare("Bình thường") == .orderedSame || s.caseInsensitiveCompare("binh_thuong") == .orderedSame {
            return (phongBan != nil && !phongBan!.isEmpty) || (roleOrUser != nil && !roleOrUser!.isEmpty) ? statusInUse : statusInStock
        }
        if s.caseInsensitiveCompare(statusNew) == .orderedSame || lower == "mới" || lower == "moi" || lower == "mới nhập" {
            return statusNew
        }
        if s.caseInsensitiveCompare(statusInStock) == .orderedSame || lower.contains("trong kho") || lower.contains("sẵn sàng") || lower == "san_sang" || lower == "ready" {
            return statusInStock
        }
        if s.caseInsensitiveCompare(statusInUse) == .orderedSame || lower.contains("sử dụng") || lower == "su_dung" || lower == "in_use" || lower == "active" {
            return statusInUse
        }
        if s.caseInsensitiveCompare(statusOnLoan) == .orderedSame || lower.contains("cho mượn") || lower.contains("mượn") || lower == "loan" || lower == "on_loan" {
            return statusOnLoan
        }
        if s.caseInsensitiveCompare(statusRepair) == .orderedSame || lower.contains("sửa") || lower.contains("bảo hành") || lower == "repair" || lower == "warranty" {
            return statusRepair
        }
        if s.caseInsensitiveCompare(statusBroken) == .orderedSame || lower.contains("hỏng") || lower.contains("xử lý") || lower == "broken" || lower == "chờ sửa" {
            return statusBroken
        }
        if s.caseInsensitiveCompare(statusLiquidated) == .orderedSame || lower.contains("thanh lý") || lower == "liquidated" {
            return statusLiquidated
        }
        return s
    }

    public static func color(for status: String) -> Color {
        let norm = normalize(status)
        switch norm {
        case statusNew: return .statusNew
        case statusInStock: return .statusInStock
        case statusInUse: return .statusInUse
        case statusOnLoan: return .statusOnLoan
        case statusRepair: return .statusRepair
        case statusBroken: return .statusBroken
        case statusLiquidated: return .statusLiquidated
        default: return .appTextSecondary
        }
    }
}

// MARK: - DEVICE MODEL (ĐỒNG BỘ 1:1 VỚI DATA CLASS THIETBI TRÊN ANDROID)
public struct ThietBi: Identifiable, Codable, Hashable {
    public var id: String
    public var ten: String
    public var tenDonVi: String
    public var trangThai: String
    public var createdAt: Int64
    public var role: String?
    public var loai: String?
    public var phongBan: String?
    public var moTa: String?
    public var createdBy: String?
    public var companyId: String?
    public var synced: Bool
    public var donViMuon: String?
    public var phongBanMuon: String?
    public var nguoiMuon: String?
    public var ngayMuon: String?
    public var ngayHenTra: String?
    public var timestamp: Double

    public init(
        id: String,
        ten: String,
        tenDonVi: String,
        trangThai: String,
        createdAt: Int64 = 0,
        role: String? = nil,
        loai: String? = nil,
        phongBan: String? = nil,
        moTa: String? = nil,
        createdBy: String? = nil,
        companyId: String? = nil,
        synced: Bool = true,
        donViMuon: String? = nil,
        phongBanMuon: String? = nil,
        nguoiMuon: String? = nil,
        ngayMuon: String? = nil,
        ngayHenTra: String? = nil,
        timestamp: Double = 0.0
    ) {
        self.id = id
        self.ten = ten
        self.tenDonVi = tenDonVi
        self.trangThai = trangThai
        self.createdAt = createdAt
        self.role = role
        self.loai = loai
        self.phongBan = phongBan
        self.moTa = moTa
        self.createdBy = createdBy
        self.companyId = companyId
        self.synced = synced
        self.donViMuon = donViMuon
        self.phongBanMuon = phongBanMuon
        self.nguoiMuon = nguoiMuon
        self.ngayMuon = ngayMuon
        self.ngayHenTra = ngayHenTra
        self.timestamp = timestamp
    }

    public var statusNormalized: String {
        DeviceStatusConstants.normalize(trangThai, phongBan: phongBan, roleOrUser: role)
    }

    public var statusColor: Color {
        DeviceStatusConstants.color(for: statusNormalized)
    }
}

// MARK: - DEVICE HISTORY MODEL (LICHSUTHIETBI.KT)
public struct LichSuThietBi: Identifiable, Codable, Hashable {
    public var id: String
    public var thietBiId: String
    public var tenThietBi: String
    public var hanhDong: String
    public var trangThaiMoi: String
    public var ngay: String
    public var nguoiThucHien: String
    public var emailNguoiThucHien: String
    public var moTa: String
    public var donVi: String
    public var phongBan: String
    public var donViMuon: String?
    public var phongBanMuon: String?
    public var nguoiMuon: String?
    public var ngayMuon: String?
    public var ngayHenTra: String?
    public var timestamp: Double

    public init(
        id: String = UUID().uuidString,
        thietBiId: String = "",
        tenThietBi: String = "",
        hanhDong: String = "",
        trangThaiMoi: String = "",
        ngay: String = "",
        nguoiThucHien: String = "",
        emailNguoiThucHien: String = "",
        moTa: String = "",
        donVi: String = "",
        phongBan: String = "",
        donViMuon: String? = nil,
        phongBanMuon: String? = nil,
        nguoiMuon: String? = nil,
        ngayMuon: String? = nil,
        ngayHenTra: String? = nil,
        timestamp: Double = 0.0
    ) {
        self.id = id
        self.thietBiId = thietBiId
        self.tenThietBi = tenThietBi
        self.hanhDong = hanhDong
        self.trangThaiMoi = trangThaiMoi
        self.ngay = ngay
        self.nguoiThucHien = nguoiThucHien
        self.emailNguoiThucHien = emailNguoiThucHien
        self.moTa = moTa
        self.donVi = donVi
        self.phongBan = phongBan
        self.donViMuon = donViMuon
        self.phongBanMuon = phongBanMuon
        self.nguoiMuon = nguoiMuon
        self.ngayMuon = ngayMuon
        self.ngayHenTra = ngayHenTra
        self.timestamp = timestamp
    }
}
