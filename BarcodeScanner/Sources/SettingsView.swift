import SwiftUI

public struct SettingsView: View {
    // Barcode symbologies
    @AppStorage("pref_ean13") private var ean13: Bool = true
    @AppStorage("pref_ean8") private var ean8: Bool = true
    @AppStorage("pref_upca") private var upca: Bool = true
    @AppStorage("pref_code128") private var code128: Bool = true
    @AppStorage("pref_code39") private var code39: Bool = true
    @AppStorage("pref_qrcode") private var qrcode: Bool = true
    
    // Scanner feedback
    @AppStorage("pref_beep") private var enableBeep: Bool = true
    @AppStorage("pref_vibrate") private var enableVibrate: Bool = true
    
    // Wi-Fi Sync Mode: 0: Auto (theo IT PC), 1: Always Direct, 2: Always Queue
    @AppStorage("pref_wifi_sync_mode") private var wifiSyncMode: Int = 0
    
    @State private var showSavedAlert: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("CÀI ĐẶT MÃ VẠCH")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Card 1: Loại mã vạch được quét
                VStack(alignment: .leading, spacing: 12) {
                    Text("LOẠI MÃ VẠCH HỖ TRỢ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Toggle("Mã vạch EAN-13 (Phổ biến)", isOn: $ean13)
                        Divider()
                        Toggle("Mã vạch EAN-8", isOn: $ean8)
                        Divider()
                        Toggle("Mã vạch UPC-A", isOn: $upca)
                        Divider()
                        Toggle("Mã vạch Code 128 (Tem siêu thị)", isOn: $code128)
                        Divider()
                        Toggle("Mã vạch Code 39", isOn: $code39)
                        Divider()
                        Toggle("Mã hai chiều QR Code", isOn: $qrcode)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Card 2: Âm thanh & Rung
                VStack(alignment: .leading, spacing: 12) {
                    Text("PHẢN HỒI KHI QUÉT THÀNH CÔNG")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Toggle("Phát tiếng Bíp khi quét", isOn: $enableBeep)
                        Divider()
                        Toggle("Rung phản hồi (Haptic feedback)", isOn: $enableVibrate)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Card 3: Chế độ truyền Wi-Fi / Internet
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                        Text("CHẾ ĐỘ TRUYỀN DỮ LIỆU WI-FI")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 10) {
                        // Option 0: Auto
                        Button(action: { wifiSyncMode = 0 }) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: wifiSyncMode == 0 ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(wifiSyncMode == 0 ? .blue : .gray)
                                    .font(.system(size: 18))
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tự động (Khuyên dùng)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Theo thiết lập máy tính IT (Queue hoặc Direct)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        // Option 1: Direct
                        Button(action: { wifiSyncMode = 1 }) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: wifiSyncMode == 1 ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(wifiSyncMode == 1 ? .green : .gray)
                                    .font(.system(size: 18))
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Luôn truyền trực tiếp (Direct)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Không vào hàng đợi, PC tự lưu & máy tự hoàn tất ngay (Dùng khi IT đi vắng / ngủ đêm)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Divider()
                        
                        // Option 2: Queue
                        Button(action: { wifiSyncMode = 2 }) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: wifiSyncMode == 2 ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(wifiSyncMode == 2 ? .blue : .gray)
                                    .font(.system(size: 18))
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Luôn hàng đợi (Queue)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("Xếp hàng chờ IT tiếp nhận và in biên bản tại chỗ")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Button Lưu
                Button(action: {
                    showSavedAlert = true
                }) {
                    Text("LƯU CÀI ĐẶT")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .alert(isPresented: $showSavedAlert) {
            Alert(
                title: Text("Thông báo"),
                message: Text("Đã lưu các thiết lập quét thành công."),
                dismissButton: .default(Text("Đồng ý"))
            )
        }
    }
}
