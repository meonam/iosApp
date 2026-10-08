import SwiftUI
import UIKit

// MARK: - UI COLOR HEX EXTENSION
public extension UIColor {
    convenience init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

// MARK: - APP THEME COLORS (ĐỒNG BỘ 1:1 VỚI ANDROID THEME & COLOR.KT, HỖ TRỢ DARK MODE TỰ ĐỘNG)
public extension Color {
    // Tiện ích tạo màu động thích ứng Light / Dark mode
    static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

    // 1. Mã màu chủ đạo thương hiệu (chuẩn 1:1 theo Color.kt trên Android)
    static let appPrimaryPink = Color(hex: "#F40266")          // Hồng rực rỡ thương hiệu
    static let appPrimaryPinkLight = Color(hex: "#FF4081")     // Hồng sáng
    static let appPrimaryPinkContainer = Color.dynamic(light: "#FCE4EC", dark: "#4A0020") // Hồng nhạt container
    static let appSecondaryDarkBlue = Color.dynamic(light: "#002A8F", dark: "#60A5FA")   // Xanh Đậm trong Light, Sky Blue trong Dark
    static let appDarkBlueContainer = Color.dynamic(light: "#E8EAF6", dark: "#1E293B")    // Xanh đậm container nhạt
    static let appTopBarColor = Color.dynamic(light: "#002A8F", dark: "#0A192F")          // Xanh Đậm (Thanh trên)
    static let appHeaderDarkNavy = Color.dynamic(light: "#002A8F", dark: "#0A192F")       // Header Dark Navy (Đảm bảo chữ trắng luôn tương phản cao, không bị chói)
    static let appDarkButtonBackground = Color.dynamic(light: "#002A8F", dark: "#1E40AF") // Nền nút xanh đậm (Đảm bảo chữ trắng luôn sắc nét)
    static let appPrimary = Color.dynamic(light: "#002A8F", dark: "#60A5FA")              // Xanh Đậm Primary

    // 2. Màu thanh điều hướng dưới & Nút nổi FAB
    static let appBottomBarBackground = Color.dynamic(light: "#0A192F", dark: "#0A192F")  // Xanh Đậm Đêm (Thanh dưới)
    static let appBottomBarSelected = Color(hex: "#F40266")    // Hồng Highlight khi chọn
    static let appBottomBarUnselected = Color(hex: "#94A3B8")  // Slate Muted
    static let appFabGreen = Color(hex: "#2E7D32")             // Xanh lá nút nổi Hỗ trợ (FAB)

    // 3. Màu nền và text hệ thống (Tự động thích ứng Light / Dark mode)
    static let appBackground = Color.dynamic(light: "#F8FAFC", dark: "#0B1120")
    static let appSurface = Color.dynamic(light: "#FFFFFF", dark: "#1E293B")
    static let appSurfaceVariant = Color.dynamic(light: "#F1F5F9", dark: "#334155")
    static let appCardBorder = Color.dynamic(light: "#E2E8F0", dark: "#334155")
    static let appBorder = Color.dynamic(light: "#E2E8F0", dark: "#334155")
    static let appTextPrimary = Color.dynamic(light: "#0F172A", dark: "#F8FAFC")
    static let appTextSecondary = Color.dynamic(light: "#475569", dark: "#CBD5E1")
    static let appTextMuted = Color.dynamic(light: "#94A3B8", dark: "#64748B")
    static let appDivider = Color.dynamic(light: "#CBD5E1", dark: "#334155")

    // 4. Màu trạng thái hệ thống
    static let appSuccess = Color(hex: "#10B981")
    static let appWarning = Color(hex: "#F59E0B")
    static let appDanger = Color(hex: "#EF4444")
    static let appInfo = Color.dynamic(light: "#3B82F6", dark: "#60A5FA")

    // 5. Màu trạng thái thiết bị chuẩn (DeviceStatusConstants)
    static let statusNew = Color(hex: "#3B82F6")          // Mới nhập - Xanh dương
    static let statusInStock = Color(hex: "#10B981")     // Trong kho (Sẵn sàng) - Xanh lá
    static let statusInUse = Color(hex: "#8B5CF6")       // Đang sử dụng - Tím
    static let statusOnLoan = Color(hex: "#EC4899")      // Đang cho mượn - Hồng đậm
    static let statusInTransit = Color(hex: "#EA580C")   // Đang điều chuyển - Cam đậm
    static let statusRepair = Color(hex: "#F59E0B")      // Đang sửa chữa - Vàng cam
    static let statusBroken = Color(hex: "#EF4444")      // Hỏng / Chờ xử lý - Đỏ
    static let statusLiquidated = Color(hex: "#6B7280")  // Đã thanh lý - Xám

    // Tiện ích tạo Color từ Hex code hỗ trợ 3, 6, 8 ký tự
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - SAFE AREA HELPER (ĐẢM BẢO TOPBAR TRÊN MỌI THIẾT BỊ KHÔNG BỊ TRÙNG CỘT SÓNG / TAI THỎ / DYNAMIC ISLAND)
public struct SafeAreaHelper {
    public static var topInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                let top = window.safeAreaInsets.top
                if top > 0 { return top }
            }
        }
        if let window = UIApplication.shared.windows.first {
            let top = window.safeAreaInsets.top
            if top > 0 { return top }
        }
        return 47.0 // Fallback an toàn cho iOS Notch / Dynamic Island
    }

    public static func top(_ geometry: GeometryProxy) -> CGFloat {
        let insets = geometry.safeAreaInsets.top
        return insets > 0 ? insets : topInset
    }

    public static var bottomInset: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                let bottom = window.safeAreaInsets.bottom
                if bottom > 0 { return bottom }
            }
        }
        if let window = UIApplication.shared.windows.first {
            let bottom = window.safeAreaInsets.bottom
            if bottom > 0 { return bottom }
        }
        return 34.0 // Fallback an toàn cho iOS Home Indicator (iPhone X trở lên)
    }

    public static func bottom(_ geometry: GeometryProxy) -> CGFloat {
        let insets = geometry.safeAreaInsets.bottom
        return insets > 0 ? insets : bottomInset
    }
}
