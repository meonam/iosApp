import SwiftUI

// MARK: - APP THEME COLORS (ĐỒNG BỘ 1:1 VỚI ANDROID THEME & COLOR.KT)
public extension Color {
    // 1. Mã màu chủ đạo thương hiệu (chuẩn 1:1 theo Color.kt trên Android)
    static let appPrimaryPink = Color(hex: "#F40266")          // Hồng rực rỡ thương hiệu
    static let appPrimaryPinkLight = Color(hex: "#FF4081")     // Hồng sáng
    static let appPrimaryPinkContainer = Color(hex: "#FCE4EC") // Hồng nhạt container
    static let appSecondaryDarkBlue = Color(hex: "#002A8F")   // Xanh Đậm / Dark Navy Blue
    static let appDarkBlueContainer = Color(hex: "#E8EAF6")    // Xanh đậm container nhạt
    static let appTopBarColor = Color(hex: "#002A8F")          // Xanh Đậm (Thanh trên)

    // 2. Màu thanh điều hướng dưới & Nút nổi FAB
    static let appBottomBarBackground = Color(hex: "#0A192F")  // Xanh Đậm Đêm (Thanh dưới)
    static let appBottomBarSelected = Color(hex: "#F40266")    // Hồng Highlight khi chọn
    static let appBottomBarUnselected = Color(hex: "#94A3B8")  // Slate Muted
    static let appFabGreen = Color(hex: "#2E7D32")             // Xanh lá nút nổi Hỗ trợ (FAB)

    // 3. Màu nền và text hệ thống
    static let appBackground = Color(hex: "#F8FAFC")
    static let appSurface = Color.white
    static let appSurfaceVariant = Color(hex: "#F1F5F9")
    static let appCardBorder = Color(hex: "#E2E8F0")
    static let appTextPrimary = Color(hex: "#0F172A")
    static let appTextSecondary = Color(hex: "#475569")
    static let appTextMuted = Color(hex: "#94A3B8")
    static let appDivider = Color(hex: "#CBD5E1")

    // 3. Màu trạng thái hệ thống
    static let appSuccess = Color(hex: "#10B981")
    static let appWarning = Color(hex: "#F59E0B")
    static let appDanger = Color(hex: "#EF4444")
    static let appInfo = Color(hex: "#3B82F6")

    // 4. Màu trạng thái thiết bị chuẩn (DeviceStatusConstants)
    static let statusNew = Color(hex: "#3B82F6")          // Mới nhập - Xanh dương
    static let statusInStock = Color(hex: "#10B981")     // Trong kho (Sẵn sàng) - Xanh lá
    static let statusInUse = Color(hex: "#8B5CF6")       // Đang sử dụng - Tím
    static let statusOnLoan = Color(hex: "#EC4899")      // Đang cho mượn - Hồng đậm
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
