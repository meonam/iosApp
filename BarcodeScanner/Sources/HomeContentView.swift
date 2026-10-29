import SwiftUI

public struct HomeContentView: View {
    @Binding var selectedTab: Int
    @State private var versionInfo: String = "Phiên bản 1.4.0 (Build 14)"
    @State private var dbStatus: String = "Hệ thống & CSDL sẵn sàng"
    @State private var totalRecords: Int = 0
    
    private let db = DatabaseHelper.shared
    
    public init(selectedTab: Binding<Int> = .constant(0)) {
        self._selectedTab = selectedTab
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.blue.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                        
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 24)
                    
                    Text("HỆ THỐNG KIỂM KÊ KHO")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Co.opmart Bến Tre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                // Status Card
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(dbStatus)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "tray.full.fill")
                            .foregroundColor(.blue)
                        Text("Tổng bản ghi đã kiểm:")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(totalRecords) dòng")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.gray)
                        Text(versionInfo)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                .padding(.horizontal, 16)
                
                // Quick Actions
                VStack(spacing: 12) {
                    Button(action: {
                        selectedTab = 2 // Chuyển sang Tab Quét mã
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bắt đầu Quét mã / Kiểm kê")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Quét barcode trực tiếp hoặc nhập thủ công")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    Button(action: {
                        selectedTab = 1 // Chuyển sang Tab Wi-Fi
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.green)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "wifi")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Gửi dữ liệu qua NET (Wi-Fi)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Đồng bộ dữ liệu kiểm kê với máy tính PC")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                
                // Instructions Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("HƯỚNG DẪN NHANH")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Tab 'Quét mã': Quét bằng Camera hoặc gõ mã vạch.", systemImage: "1.circle.fill")
                        Label("Xuất file: Tạo tệp WINCE.txt chia sẻ hoặc copy qua cáp USB.", systemImage: "2.circle.fill")
                        Label("Truyền Wi-Fi: Quét mã QR UID máy tính để gửi tự động.", systemImage: "3.circle.fill")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                
                Spacer(minLength: 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            totalRecords = db.getCount()
        }
    }
}
