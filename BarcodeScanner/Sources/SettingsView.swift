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
