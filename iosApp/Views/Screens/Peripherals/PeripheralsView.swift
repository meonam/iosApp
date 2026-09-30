import SwiftUI

public struct PeripheralsView: View {
    @Environment(\.colorScheme) private var colorScheme
    private var isDark: Bool { colorScheme == .dark }
    
    let onBack: () -> Void
    
    // Scanner Settings
    @AppStorage("scanner_mode") private var scannerMode = "ALL"
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
    @AppStorage("printer_bt_device") private var selectedBtDevice = ""
    
    @State private var isScannerExpanded = false
    @State private var isPrinterExpanded = false
    @State private var showingTestAlert = false
    @State private var isTestingConnection = false
    @State private var bluetoothDeviceList: [String] = []
    @State private var isScanningBt = false
    
    public init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                (isDark ? Color(hex: "#0B1120") : Color(hex: "#F8FAFC")).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top bar với safe area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        topBar
                    }
                    .background(isDark ? Color(hex: "#0A192F") : Color(hex: "#002A8F"))
                    
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
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text("Cài đặt máy in & máy quét")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var scannerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isScannerExpanded.toggle()
                    if isScannerExpanded { isPrinterExpanded = false }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20))
                        .foregroundColor(isScannerExpanded ? .white : Color.appPrimaryPink)
                    Text("Cài đặt máy quét")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isScannerExpanded ? .white : (isDark ? Color(hex: "#F8FAFC") : Color(hex: "#002A8F")))
                    Spacer()
                    Image(systemName: isScannerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isScannerExpanded ? .white : (isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B")))
                }
                .padding(16)
                .background(isScannerExpanded ? Color.appPrimaryPink : (isDark ? Color(hex: "#1E293B") : Color.white))
                .customCornerRadius(isScannerExpanded ? 16 : 16, corners: [.topLeft, .topRight])
                .customCornerRadius(isScannerExpanded ? 0 : 16, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isScannerExpanded ? Color.clear : (isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0")), lineWidth: 1)
                )
            }
            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 3, y: 1)
            
            if isScannerExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Scanner Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chế độ quét")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
                        let modes: [(String, String)] = [
                            ("ALL", "Tất cả"),
                            ("CAMERA", "Camera"),
                            ("DATALOGIC", "Máy quét cứng")
                        ]
                        
                        HStack(spacing: 8) {
                            ForEach(modes, id: \.0) { mode in
                                Button(action: { scannerMode = mode.0 }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: scannerMode == mode.0 ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(scannerMode == mode.0 ? Color.appPrimaryPink : (isDark ? Color(hex: "#64748B") : Color(hex: "#94A3B8")))
                                        Text(mode.1)
                                            .font(.system(size: 12.5, weight: scannerMode == mode.0 ? .bold : .regular))
                                            .foregroundColor(scannerMode == mode.0 ? Color.appPrimaryPink : (isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A")))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 2. Âm báo & Phản hồi
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Âm báo & Phản hồi")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
                        Toggle("Phát tiếng Beep khi quét", isOn: $beepOnScan)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                            .tint(.appPrimaryPink)
                        Toggle("Rung khi quét", isOn: $vibrateOnScan)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                            .tint(.appPrimaryPink)
                    }
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 3. Anti-partial Scan
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16))
                                .foregroundColor(enableAntiPartialScan ? Color.appPrimaryPink : (isDark ? Color(hex: "#64748B") : Color(hex: "#94A3B8")))
                            Text("Chống quét thiếu mã (Xác thực 2 frame)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                            Spacer()
                            Toggle("", isOn: $enableAntiPartialScan)
                                .labelsHidden()
                                .tint(.appPrimaryPink)
                        }
                        Text("Tránh nhận nhầm khi lia camera qua mã vạch 1D (Code 128 / Code 39) chưa bao trọn toàn bộ mã.")
                            .font(.system(size: 11))
                            .foregroundColor(isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B"))
                    }
                    .padding(12)
                    .background(enableAntiPartialScan ? (isDark ? Color(hex: "#4A0020") : Color(hex: "#FCE4EC")) : (isDark ? Color(hex: "#0F172A") : Color(hex: "#F8FAFC")))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(enableAntiPartialScan ? Color.appPrimaryPink.opacity(0.4) : (isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0")), lineWidth: 1)
                    )
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 4. Min length
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Độ dài mã tối thiểu (bỏ qua chuỗi ngắn hơn):")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
                        HStack(spacing: 8) {
                            ForEach([3, 4, 6], id: \.self) { len in
                                Button(action: { minBarcodeLength = len }) {
                                    Text("≥ \(len) ký tự")
                                        .font(.system(size: 12, weight: minBarcodeLength == len ? .bold : .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(minBarcodeLength == len ? Color.appPrimaryPink : (isDark ? Color(hex: "#0F172A") : Color(hex: "#F1F5F9")))
                                        .foregroundColor(minBarcodeLength == len ? .white : (isDark ? Color(hex: "#CBD5E1") : Color(hex: "#334155")))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(minBarcodeLength == len ? Color.clear : (isDark ? Color(hex: "#334155") : Color(hex: "#CBD5E1")), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 5. Formats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Định dạng mã cho phép:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
                        Group {
                            toggleRow(title: "Code 128 (Công nghiệp)", isOn: $enableCode128)
                            toggleRow(title: "Mã QR (QR Code)", isOn: $enableQRCode)
                            toggleRow(title: "EAN-13 (Bán lẻ)", isOn: $enableEAN13)
                            toggleRow(title: "Code 39 (Công nghiệp)", isOn: $enableCode39)
                            toggleRow(title: "EAN-8", isOn: $enableEAN8)
                            toggleRow(title: "UPC-A (Siêu thị)", isOn: $enableUPCA)
                            toggleRow(title: "Data Matrix (2D)", isOn: $enableDataMatrix)
                            toggleRow(title: "PDF-417 (Căn cước / Bằng lái)", isOn: $enablePDF417)
                        }
                    }
                }
                .padding(16)
                .background(isDark ? Color(hex: "#1E293B") : Color.white)
                .customCornerRadius(16, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 3, y: 1)
            }
        }
    }
    
    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
            .tint(.appPrimaryPink)
    }
    
    private var printerSection: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation {
                    isPrinterExpanded.toggle()
                    if isPrinterExpanded { isScannerExpanded = false }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isPrinterExpanded ? .white : Color.appPrimaryPink)
                    Text("Cài đặt máy in")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isPrinterExpanded ? .white : (isDark ? Color(hex: "#F8FAFC") : Color(hex: "#002A8F")))
                    Spacer()
                    Image(systemName: isPrinterExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isPrinterExpanded ? .white : (isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B")))
                }
                .padding(16)
                .background(isPrinterExpanded ? Color.appPrimaryPink : (isDark ? Color(hex: "#1E293B") : Color.white))
                .customCornerRadius(isPrinterExpanded ? 16 : 16, corners: [.topLeft, .topRight])
                .customCornerRadius(isPrinterExpanded ? 0 : 16, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isPrinterExpanded ? Color.clear : (isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0")), lineWidth: 1)
                )
            }
            .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 3, y: 1)
            
            if isPrinterExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // 1. Connection type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phương thức kết nối")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
                        HStack {
                            ForEach(["Bluetooth", "USB-OTG", "Wifi/LAN"], id: \.self) { mode in
                                Button(action: { connectionType = mode }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: connectionType == mode ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(connectionType == mode ? Color.appPrimaryPink : (isDark ? Color(hex: "#64748B") : Color(hex: "#94A3B8")))
                                        Text(mode)
                                            .font(.system(size: 12.5, weight: connectionType == mode ? .bold : .regular))
                                            .foregroundColor(connectionType == mode ? Color.appPrimaryPink : (isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A")))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // 2. Dynamic config based on type
                    if connectionType == "Wifi/LAN" {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Địa chỉ IP")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B"))
                                TextField("192.168.1.x", text: $printerIp)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(10)
                                    .background(isDark ? Color(hex: "#0F172A") : Color(hex: "#F8FAFC"))
                                    .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isDark ? Color(hex: "#334155") : Color(hex: "#CBD5E1"), lineWidth: 1))
                                    .keyboardType(.decimalPad)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Cổng (Port)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B"))
                                TextField("9100", text: $printerPort)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(10)
                                    .background(isDark ? Color(hex: "#0F172A") : Color(hex: "#F8FAFC"))
                                    .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isDark ? Color(hex: "#334155") : Color(hex: "#CBD5E1"), lineWidth: 1))
                                    .keyboardType(.numberPad)
                            }
                            .frame(width: 85)
                        }
                    } else if connectionType == "Bluetooth" {
                        VStack(alignment: .leading, spacing: 12) {
                            Button(action: startScanningBluetooth) {
                                HStack {
                                    if isScanningBt {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("Đang dò tìm...")
                                    } else {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                        Text("Dò tìm thiết bị Bluetooth")
                                    }
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(Color.appPrimaryPink)
                                .cornerRadius(8)
                            }
                            
                            if bluetoothDeviceList.isEmpty {
                                Text(isScanningBt ? "Đang quét..." : "Chưa có thiết bị nào được ghép đôi.")
                                    .font(.system(size: 12))
                                    .foregroundColor(isDark ? Color(hex: "#94A3B8") : Color(hex: "#64748B"))
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(bluetoothDeviceList, id: \.self) { device in
                                        Button(action: { selectedBtDevice = device }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: selectedBtDevice == device ? "largecircle.fill.circle" : "circle")
                                                    .foregroundColor(selectedBtDevice == device ? Color.appPrimaryPink : (isDark ? Color(hex: "#64748B") : Color(hex: "#94A3B8")))
                                                Text(device)
                                                    .font(.system(size: 12.5, weight: selectedBtDevice == device ? .bold : .regular))
                                                    .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "cable.connector")
                                .foregroundColor(Color.appPrimaryPink)
                            Text("Đã chọn chế độ in qua cáp USB-OTG.")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
                        }
                        .padding(12)
                        .background(isDark ? Color(hex: "#0F172A") : Color(hex: "#F1F5F9"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDark ? Color(hex: "#334155") : Color(hex: "#CBD5E1"), lineWidth: 1)
                        )
                    }
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 3. Paper size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Khổ giấy mặc định")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDark ? Color(hex: "#60A5FA") : Color(hex: "#002A8F"))
                        
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
                    
                    Divider().background(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"))
                    
                    // 4. Test button
                    Button(action: {
                        isTestingConnection = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isTestingConnection = false
                            showingTestAlert = true
                        }
                    }) {
                        HStack {
                            if isTestingConnection {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Đang kiểm tra...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "printer.dotmatrix")
                                Text("Kiểm tra kết nối máy in")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(isTestingConnection ? Color.gray : Color(hex: "#16A34A"))
                        .cornerRadius(8)
                    }
                    .disabled(isTestingConnection)
                }
                .padding(16)
                .background(isDark ? Color(hex: "#1E293B") : Color.white)
                .customCornerRadius(16, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDark ? Color(hex: "#334155") : Color(hex: "#E2E8F0"), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(isDark ? 0.2 : 0.05), radius: 3, y: 1)
            }
        }
    }
    
    private func startScanningBluetooth() {
        guard !isScanningBt else { return }
        isScanningBt = true
        bluetoothDeviceList = []
        
        // Mock Bluetooth scanning
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            bluetoothDeviceList = [
                "Máy in QLTB (00:11:22:33:FF:EE)",
                "XPrinter XP-58 (AA:BB:CC:DD:EE:FF)"
            ]
            isScanningBt = false
        }
    }
    
    @ViewBuilder
    private func paperSizeOption(_ size: String) -> some View {
        Button(action: { paperSize = size }) {
            HStack(spacing: 6) {
                Image(systemName: paperSize == size ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(paperSize == size ? Color.appPrimaryPink : (isDark ? Color(hex: "#64748B") : Color(hex: "#94A3B8")))
                Text(size)
                    .font(.system(size: 12.5, weight: paperSize == size ? .bold : .regular))
                    .foregroundColor(isDark ? Color(hex: "#F8FAFC") : Color(hex: "#0F172A"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PeripheralsRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

private extension View {
    func customCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(PeripheralsRoundedCorner(radius: radius, corners: corners))
    }
}
