import SwiftUI

public struct MainTabView: View {
    @State private var selectedTab: Int = 0
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Trang chủ (tương tự HomeFragment trên Android)
            HomeContentView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Trang chủ")
                }
                .tag(0)
            
            // Tab 1: Gửi qua NET (Wi-Fi)
            WifiSyncView()
                .tabItem {
                    Image(systemName: "wifi")
                    Text("Gửi qua NET")
                }
                .tag(1)
            
            // Tab 2: Quét mã (KiemKeScreen có nút [Quét mã] / [Dừng] tương tự Android)
            KiemKeListView()
                .tabItem {
                    Image(systemName: "barcode.viewfinder")
                    Text("Quét mã")
                }
                .tag(2)
            
            // Tab 3: Tùy chọn (Cài đặt)
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Tùy chọn")
                }
                .tag(3)
            
            // Tab 4: Thông tin
            InfoView()
                .tabItem {
                    Image(systemName: "info.circle.fill")
                    Text("Thông tin")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}
