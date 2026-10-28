import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Trang chủ & Quét mã
            ScanBarcodeView()
                .tabItem {
                    Image(systemName: "camera.viewfinder")
                    Text("Quét mã")
                }
                .tag(0)
            
            // Tab 1: Wi-Fi
            WifiSyncView()
                .tabItem {
                    Image(systemName: "wifi")
                    Text("Wi-Fi")
                }
                .tag(1)
            
            // Tab 2: Kiểm kê kho
            KiemKeListView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Kiểm kê")
                }
                .tag(2)
            
            // Tab 3: Cài đặt
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Cài đặt")
                }
                .tag(3)
            
            // Tab 4: Thông tin
            InfoView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("Thông tin")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}
