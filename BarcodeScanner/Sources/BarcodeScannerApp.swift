import SwiftUI

@main
struct BarcodeScannerApp: App {
    init() {
        // Khởi tạo và kiểm tra database SQLite tại thư mục Documents
        _ = DatabaseHelper.shared
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
