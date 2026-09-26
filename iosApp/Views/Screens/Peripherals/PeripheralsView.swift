import SwiftUI

public struct PeripheralsView: View {
    let onBack: () -> Void
    
    // Scanner Settings
    @AppStorage("scanner_ean13") private var enableEAN13 = true
    @AppStorage("scanner_ean8") private var enableEAN8 = true
    @AppStorage("scanner_code128") private var enableCode128 = true
    @AppStorage("scanner_code39") private var enableCode39 = true
    @AppStorage("scanner_upca") private var enableUPCA = true
    @AppStorage("scanner_qrcode") private var enableQRCode = true
    @AppStorage("scanner_datamatrix") private var enableDataMatrix = true
    @AppStorage("scanner_pdf417") private var enablePDF417 = true
    @AppStorage("scanner_min_length") private var minBarcodeLength = 3
    @AppStorage("scanner_anti_partial") private var enableAntiPartialScan = true
    @AppStorage("scanner_beep") private var beepOnScan = true
    @AppStorage("scanner_vibrate") private var vibrateOnScan = true
    
    // Printer Settings
    @AppStorage("printer_connection") private var connectionType = "Wifi/LAN"
    @AppStorage("printer_ip") private var printerIp = "192.168.1.100"
    @AppStorage("printer_port") private var printerPort = "9100"
    @AppStorage("printer_paper_size") private var paperSize = "Khổ A4"
    
    @State private var isScannerExpanded = false
    @State private var isPrinterExpanded = false
    @State private var showingTestAlert = false
    
    public init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar với safe area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            scannerSection
                            printerSection
                        }
                        .padding(16)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert("Kiểm tra kết nối", isPresented: $showingTestAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Kết nối đến máy in thành công!")
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
                    .padding()
            }
            
            Text("Cài đặt hệ thống")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
        }
    }
    
    private var scannerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isScannerExpanded.toggle()
                    if isScannerExpanded { isPrinterExpanded = false }
                }
            }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .foregroundColor(isScannerExpanded ? .white : .appPrimary)
                    Text("Cài đặt máy quét")
                        .font(.headline)
                        .foregroundColor(isScannerExpanded ? .white : .primary)
                    Spacer()
                    Image(systemName: isScannerExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(isScannerExpanded ? .white : .gray)
                }
                .padding()
                .background(isScannerExpanded ? Color.appPrimary : Color.white)
                .cornerRadius(isScannerExpanded ? 16 : 16, corners: [.topLeft, .topRight])
                .cornerRadius(isScannerExpanded ? 0 : 16, corners: [.bottomLeft, .bottomRight])
            }
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            
            if isScannerExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Âm báo
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Âm báo & Phản hồi")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                        
                        Toggle("Phát tiếng Beep khi quét", isOn: $beepOnScan)
                            .tint(.appPrimary)
                        Toggle("Rung khi quét", isOn: $vibrateOnScan)
                            .tint(.appPrimary)
                    }
                    
                    Divider()
                    
                    // Anti-partial
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(enableAntiPartialScan ? .appPrimary : .gray)
                            Text("Chống quét thiếu mã")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.appPrimary)
                            Spacer()
                            Toggle("", isOn: $enableAntiPartialScan)
                                .labelsHidden()
                                .tint(.appPrimary)
                        }
                        Text("Tránh nhận nhầm khi lia camera qua mã vạch 1D (Code 128 / Code 39) chưa bao trọn toàn bộ mã.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(enableAntiPartialScan ? Color.appPrimary.opacity(0.05) : Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(enableAntiPartialScan ? Color.appPrimary.opacity(0.3) : Color(UIColor.systemGray4), lineWidth: 1)
                    )
                    
                    Divider()
                    
                    // Min length
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Độ dài mã tối thiểu:")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach([3, 4, 6], id: \.self) { len in
                                Button(action: { minBarcodeLength = len }) {
                                    Text("≥ \(len) ký tự")
                                        .font(.caption)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(minBarcodeLength == len ? Color.appPrimary : Color.clear)
                                        .foregroundColor(minBarcodeLength == len ? .white : .primary)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(minBarcodeLength == len ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Formats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Định dạng mã cho phép:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Group {
                            Toggle("Code 128", isOn: $enableCode128).tint(.appPrimary)
                            Toggle("QR Code", isOn: $enableQRCode).tint(.appPrimary)
                            Toggle("EAN-13", isOn: $enableEAN13).tint(.appPrimary)
                            Toggle("Code 39", isOn: $enableCode39).tint(.appPrimary)
                            Toggle("EAN-8", isOn: $enableEAN8).tint(.appPrimary)
                            Toggle("UPC-A", isOn: $enableUPCA).tint(.appPrimary)
                            Toggle("Data Matrix", isOn: $enableDataMatrix).tint(.appPrimary)
                            Toggle("PDF417", isOn: $enablePDF417).tint(.appPrimary)
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
        }
    }
    
    private var printerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isPrinterExpanded.toggle()
                    if isPrinterExpanded { isScannerExpanded = false }
                }
            }) {
                HStack {
                    Image(systemName: "printer")
                        .foregroundColor(isPrinterExpanded ? .white : .appPrimary)
                    Text("Cài đặt máy in")
                        .font(.headline)
                        .foregroundColor(isPrinterExpanded ? .white : .primary)
                    Spacer()
                    Image(systemName: isPrinterExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(isPrinterExpanded ? .white : .gray)
                }
                .padding()
                .background(isPrinterExpanded ? Color.appPrimary : Color.white)
                .cornerRadius(isPrinterExpanded ? 16 : 16, corners: [.topLeft, .topRight])
                .cornerRadius(isPrinterExpanded ? 0 : 16, corners: [.bottomLeft, .bottomRight])
            }
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            
            if isPrinterExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Connection type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phương thức kết nối")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                        
                        HStack {
                            ForEach(["Bluetooth", "USB-OTG", "Wifi/LAN"], id: \.self) { mode in
                                Button(action: { connectionType = mode }) {
                                    HStack {
                                        Image(systemName: connectionType == mode ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(connectionType == mode ? .appPrimary : .gray)
                                        Text(mode)
                                            .font(.caption)
                                            .foregroundColor(connectionType == mode ? .appPrimary : .primary)
                                            .fontWeight(connectionType == mode ? .bold : .regular)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // Dynamic config based on type
                    if connectionType == "Wifi/LAN" {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading) {
                                Text("Địa chỉ IP")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextField("192.168.1.x", text: $printerIp)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Cổng (Port)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                TextField("9100", text: $printerPort)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                            .frame(width: 80)
                        }
                    } else if connectionType == "Bluetooth" {
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: { }) {
                                HStack {
                                    Image(systemName: "dot.radiowaves.left.and.right")
                                    Text("Dò tìm thiết bị Bluetooth")
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.appPrimary)
                                .cornerRadius(8)
                            }
                            
                            Text("Chưa có thiết bị nào được ghép đôi.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 4)
                        }
                    } else {
                        HStack {
                            Image(systemName: "cable.connector")
                                .foregroundColor(.appPrimary)
                            Text("Đã chọn chế độ in qua cáp USB-OTG.")
                                .font(.caption)
                                .foregroundColor(.appPrimary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Paper size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Khổ giấy mặc định")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appPrimary)
                        
                        let sizes = ["Giấy in nhiệt K80", "Giấy in nhiệt K58", "Khổ A4", "Khổ A5"]
                        
                        VStack(spacing: 8) {
                            HStack {
                                paperSizeOption(sizes[0])
                                paperSizeOption(sizes[1])
                            }
                            HStack {
                                paperSizeOption(sizes[2])
                                paperSizeOption(sizes[3])
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Test button
                    Button(action: {
                        showingTestAlert = true
                    }) {
                        HStack {
                            Image(systemName: "printer.dotmatrix")
                            Text("Kiểm tra kết nối máy in")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            }
        }
    }
    
    @ViewBuilder
    private func paperSizeOption(_ size: String) -> some View {
        Button(action: { paperSize = size }) {
            HStack {
                Image(systemName: paperSize == size ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(paperSize == size ? .appPrimary : .gray)
                Text(size)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Extension to support partial rounded corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
