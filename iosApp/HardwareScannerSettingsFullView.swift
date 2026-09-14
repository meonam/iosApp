import SwiftUI
import UIKit
import Network

// MARK: - HARDWARE & SCANNER SETTINGS FULL VIEW (Matches Android CaiDatScannerScreen.kt)
struct HardwareScannerSettingsFullView: View {
    var onDismiss: () -> Void

    // Scanner Config (Persisted in UserDefaults)
    @AppStorage("cfg_anti_partial_scan") private var enableAntiPartialScan: Bool = true
    @AppStorage("cfg_min_barcode_length") private var minBarcodeLength: Int = 3
    @AppStorage("cfg_enable_code128") private var enableCode128: Bool = true
    @AppStorage("cfg_enable_qrcode") private var enableQRCode: Bool = true
    @AppStorage("cfg_enable_ean13") private var enableEAN13: Bool = true
    @AppStorage("cfg_enable_code39") private var enableCode39: Bool = true
    @AppStorage("cfg_enable_ean8") private var enableEAN8: Bool = true
    @AppStorage("cfg_enable_upca") private var enableUPCA: Bool = true
    @AppStorage("cfg_enable_datamatrix") private var enableDataMatrix: Bool = true
    @AppStorage("cfg_enable_pdf417") private var enablePDF417: Bool = true
    @AppStorage("cfg_scan_beep") private var enableScanBeep: Bool = true
    @AppStorage("cfg_scan_vibrate") private var enableScanVibrate: Bool = true

    // Printer Config (Persisted in UserDefaults)
    @AppStorage("cfg_printer_conn_type") private var connectionType: String = "Bluetooth" // "Bluetooth", "Wifi/LAN", "AirPrint"
    @AppStorage("cfg_printer_ip") private var printerIp: String = "192.168.1.200"
    @AppStorage("cfg_printer_port") private var printerPort: String = "9100"
    @AppStorage("cfg_printer_paper_size") private var paperSize: String = "Giấy in nhiệt K80"
    @AppStorage("cfg_selected_bt_name") private var selectedBtName: String = ""

    // Section expansion state
    @State private var isScannerExpanded: Bool = true
    @State private var isPrinterExpanded: Bool = false

    // Bluetooth printer state
    @StateObject private var btPrinter = BluetoothPrinterService.shared

    // Test print status
    @State private var testPrintStatus: String? = nil
    @State private var isTestingPrint: Bool = false

    // Swipe back offset
    @State private var dragOffsetX: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Company Header Banner Ticker
                        coopmartBanner

                        // SECTION 1: SCANNER CONFIG
                        scannerSectionCard

                        // SECTION 2: PRINTER CONFIG
                        printerSectionCard

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onDismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Trở lại")
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("CÀI ĐẶT MÁY IN & MÁY QUÉT")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { resetToDefaults() }) {
                        Text("Mặc định")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffsetX = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        onDismiss()
                    }
                    dragOffsetX = 0
                }
        )
    }

    // MARK: - BANNER TICKER
    private var coopmartBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color.appPrimaryPink)
                .font(.system(size: 14))
            Text("Cấu hình thiết bị phần cứng dùng chung cho toàn bộ tính năng kiểm kê & in ấn Saigon Co.op.")
                .font(.system(size: 12))
                .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.8))
                .lineLimit(2)
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
        )
    }

    // MARK: - SCANNER SECTION
    private var scannerSectionCard: some View {
        VStack(spacing: 0) {
            // Header Accordion
            Button(action: {
                withAnimation(.spring()) {
                    isScannerExpanded.toggle()
                    if isScannerExpanded { isPrinterExpanded = false }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isScannerExpanded ? .white : Color.appSecondaryDarkBlue)
                    Text("CÀI ĐẶT MÁY QUÉT MÃ VẠCH")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isScannerExpanded ? .white : Color.appSecondaryDarkBlue)
                    Spacer()
                    Image(systemName: isScannerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isScannerExpanded ? .white : .gray)
                }
                .padding(16)
                .background(isScannerExpanded ? Color.appPrimaryPink : Color.white)
                .cornerRadius(isScannerExpanded ? 14 : 14, corners: isScannerExpanded ? [.topLeft, .topRight] : [.allCorners])
            }

            if isScannerExpanded {
                VStack(spacing: 16) {
                    // 1. Multi-frame Anti-Partial Scan
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(enableAntiPartialScan ? Color.appPrimaryPink : .gray)
                                .font(.system(size: 16))
                            Text("Chống quét thiếu mã (Xác thực 2 frame)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Toggle("", isOn: $enableAntiPartialScan)
                                .labelsHidden()
                                .tint(Color.appPrimaryPink)
                        }
                        Text("Tránh nhận diện nhầm khi lia nhanh camera qua mã vạch 1D dài (Code 128 / Code 39) chưa bao trọn toàn bộ mã.")
                            .font(.system(size: 11))
                            .foregroundColor(Color.gray)
                            .padding(.top, 2)
                    }
                    .padding(12)
                    .background(enableAntiPartialScan ? Color.appPrimaryPink.opacity(0.06) : Color(hex: "#F8FAFC"))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(enableAntiPartialScan ? Color.appPrimaryPink.opacity(0.3) : Color(hex: "#E2E8F0"), lineWidth: 1)
                    )

                    // 2. Minimum Barcode Length
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Độ dài mã tối thiểu (bỏ qua chuỗi ngắn hơn):")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        HStack(spacing: 8) {
                            ForEach([3, 4, 6], id: \.self) { len in
                                let isSel = minBarcodeLength == len
                                Button(action: { minBarcodeLength = len }) {
                                    Text("≥ \(len) ký tự")
                                        .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                        .foregroundColor(isSel ? .white : Color.appSecondaryDarkBlue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(isSel ? Color.appPrimaryPink : Color(hex: "#F1F5F9"))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }

                    // 3. Audio & Haptic Feedback
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .font(.system(size: 14))
                            Text("Âm thanh bíp khi quét thành công")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Toggle("", isOn: $enableScanBeep)
                                .labelsHidden()
                                .tint(Color.appPrimaryPink)
                        }

                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .font(.system(size: 14))
                            Text("Rung phản hồi xúc giác (Haptic feedback)")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Toggle("", isOn: $enableScanVibrate)
                                .labelsHidden()
                                .tint(Color.appPrimaryPink)
                        }
                    }

                    Divider()

                    // 4. Barcode Formats Toggles
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ĐỊNH DẠNG MÃ CHO PHÉP NHẬN DIỆN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        formatToggleRow(title: "Code 128 (Mã tài sản tiêu chuẩn Saigon Co.op)", isOn: $enableCode128)
                        formatToggleRow(title: "QR Code 2D (Tem thiết bị & Chấm công)", isOn: $enableQRCode)
                        formatToggleRow(title: "EAN-13 (Mã vạch sản phẩm bán lẻ)", isOn: $enableEAN13)
                        formatToggleRow(title: "Code 39 (Mã công nghiệp cũ)", isOn: $enableCode39)
                        formatToggleRow(title: "EAN-8 (Mã vạch ngắn)", isOn: $enableEAN8)
                        formatToggleRow(title: "UPC-A (Tiêu chuẩn quốc tế)", isOn: $enableUPCA)
                        formatToggleRow(title: "Data Matrix 2D", isOn: $enableDataMatrix)
                        formatToggleRow(title: "PDF417 (Thẻ CCCD / Bằng lái)", isOn: $enablePDF417)
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(14, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                )
            }
        }
    }

    private func formatToggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(Color.appSecondaryDarkBlue)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.appPrimaryPink)
        }
    }

    // MARK: - PRINTER SECTION
    private var printerSectionCard: some View {
        VStack(spacing: 0) {
            // Header Accordion
            Button(action: {
                withAnimation(.spring()) {
                    isPrinterExpanded.toggle()
                    if isPrinterExpanded { isScannerExpanded = false }
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isPrinterExpanded ? .white : Color.appSecondaryDarkBlue)
                    Text("CÀI ĐẶT MÁY IN NHIỆT & TEM NHÃN")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isPrinterExpanded ? .white : Color.appSecondaryDarkBlue)
                    Spacer()
                    Image(systemName: isPrinterExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isPrinterExpanded ? .white : .gray)
                }
                .padding(16)
                .background(isPrinterExpanded ? Color.appPrimaryPink : Color.white)
                .cornerRadius(isPrinterExpanded ? 14 : 14, corners: isPrinterExpanded ? [.topLeft, .topRight] : [.allCorners])
            }

            if isPrinterExpanded {
                VStack(spacing: 16) {
                    // 1. Connection Method
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PHƯƠNG THỨC KẾT NỐI MÁY IN")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            ForEach(["Bluetooth", "Wifi/LAN", "AirPrint"], id: \.self) { method in
                                let isSel = connectionType == method
                                Button(action: { connectionType = method }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                                            .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                            .font(.system(size: 13))
                                        Text(method)
                                            .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                            .foregroundColor(isSel ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(isSel ? Color.appPrimaryPink.opacity(0.08) : Color(hex: "#F8FAFC"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? Color.appPrimaryPink : Color(hex: "#E2E8F0"), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    // 2. Details depending on Connection Method
                    if connectionType == "Bluetooth" {
                        bluetoothSettingsBlock
                    } else if connectionType == "Wifi/LAN" {
                        wifiLanSettingsBlock
                    } else {
                        airPrintSettingsBlock
                    }

                    Divider()

                    // 3. Paper Size Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("KHỔ GIẤY IN MẶC ĐỊNH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)

                        let paperOptions = [
                            "Giấy in nhiệt K80",
                            "Giấy in nhiệt K58",
                            "Khổ A4 (Tem nhãn)",
                            "Khổ A5"
                        ]

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(paperOptions, id: \.self) { size in
                                let isSel = paperSize == size
                                Button(action: { paperSize = size }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isSel ? "record.circle" : "circle")
                                            .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                                            .font(.system(size: 13))
                                        Text(size)
                                            .font(.system(size: 12, weight: isSel ? .bold : .regular))
                                            .foregroundColor(isSel ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(isSel ? Color.appPrimaryPink.opacity(0.08) : Color(hex: "#F8FAFC"))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? Color.appPrimaryPink : Color(hex: "#E2E8F0"), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }

                    // 4. Test Print Button & Status
                    if let status = testPrintStatus {
                        HStack {
                            Image(systemName: status.contains("thành công") ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundColor(status.contains("thành công") ? .green : .orange)
                            Text(status)
                                .font(.system(size: 12))
                                .foregroundColor(status.contains("thành công") ? .green : .orange)
                            Spacer()
                        }
                        .padding(10)
                        .background(status.contains("thành công") ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Button(action: { executeTestPrint() }) {
                        HStack(spacing: 8) {
                            if isTestingPrint {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "printer.dotmatrix.fill")
                            }
                            Text("In thử nghiệm mẫu tem / hóa đơn")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(10)
                    }
                    .disabled(isTestingPrint)
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(14, corners: [.bottomLeft, .bottomRight])
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - BLUETOOTH BLOCK
    private var bluetoothSettingsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: {
                    btPrinter.startScan()
                }) {
                    HStack(spacing: 6) {
                        if btPrinter.isScanning {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Đang dò tìm...")
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Dò tìm máy in Bluetooth")
                        }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(8)
                }
                .disabled(btPrinter.isScanning)

                Spacer()

                if !selectedBtName.isEmpty {
                    Text("Đã chọn: \(selectedBtName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.appPrimaryPink)
                        .lineLimit(1)
                }
            }

            if btPrinter.discoveredPrinters.isEmpty {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .foregroundColor(.gray)
                    Text("Chưa tìm thấy máy in nhiệt Bluetooth nào gần đây. Hãy bật Bluetooth trên máy in và bấm 'Dò tìm'.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#F8FAFC"))
                .cornerRadius(8)
            } else {
                VStack(spacing: 6) {
                    ForEach(btPrinter.discoveredPrinters, id: \.identifier) { p in
                        let isConnected = btPrinter.connectedPrinter?.identifier == p.identifier
                        HStack {
                            Image(systemName: "printer.fill")
                                .foregroundColor(isConnected ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name ?? "Máy in nhiệt không tên")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text("UUID: \(p.identifier.uuidString.prefix(12))...")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            Spacer()

                            if isConnected {
                                Text("ĐÃ KẾT NỐI")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .cornerRadius(6)
                            } else {
                                Button("Kết nối") {
                                    btPrinter.connect(to: p)
                                    selectedBtName = p.name ?? "Máy in Bluetooth"
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appPrimaryPink.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        .padding(10)
                        .background(isConnected ? Color.appPrimaryPink.opacity(0.06) : Color(hex: "#F8FAFC"))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isConnected ? Color.appPrimaryPink : Color(hex: "#E2E8F0"), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - WIFI / LAN BLOCK
    private var wifiLanSettingsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CẤU HÌNH MẠNG LAN MÁY IN (TCP/IP ESC/POS)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Địa chỉ IP máy in")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("192.168.1.200", text: $printerIp)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 13, design: .monospaced))
                        .keyboardType(.decimalPad)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cổng Port")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("9100", text: $printerPort)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 13, design: .monospaced))
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }
            }

            Text("Mẹo: Các máy in nhiệt LAN Xprinter, Bixolon, Epson tại siêu thị Co.opmart thường chạy cổng mặc định 9100.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }

    // MARK: - AIRPRINT BLOCK
    private var airPrintSettingsBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplayaudio")
                .font(.system(size: 24))
                .foregroundColor(Color.appSecondaryDarkBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text("In không dây chuẩn Apple AirPrint")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text("Hỗ trợ in trực tiếp ra bất kỳ máy in nào cùng mạng WiFi có hỗ trợ AirPrint mà không cần cài driver.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color(hex: "#F8FAFC"))
        .cornerRadius(10)
    }

    // MARK: - ACTIONS
    private func resetToDefaults() {
        enableAntiPartialScan = true
        minBarcodeLength = 3
        enableCode128 = true
        enableQRCode = true
        enableEAN13 = true
        enableCode39 = true
        enableEAN8 = true
        enableUPCA = true
        enableDataMatrix = true
        enablePDF417 = true
        enableScanBeep = true
        enableScanVibrate = true
        connectionType = "Bluetooth"
        printerIp = "192.168.1.200"
        printerPort = "9100"
        paperSize = "Giấy in nhiệt K80"
        testPrintStatus = "Đã khôi phục cài đặt mặc định!"
    }

    private func executeTestPrint() {
        isTestingPrint = true
        testPrintStatus = "Đang gửi lệnh in thử nghiệm..."

        if connectionType == "Bluetooth" {
            // Send test ESC/POS bytes to Bluetooth
            if btPrinter.connectedPrinter != nil {
                let testText = "SAIGON CO.OP - QLTB\nIN THU NGHIEM THANH CONG\nNgay: \(Date().formatted())\n--------------------------\n\n\n"
                if let data = testText.data(using: .utf8) {
                    btPrinter.sendData(data)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.isTestingPrint = false
                        self.testPrintStatus = "Đã gửi lệnh in thành công tới máy in Bluetooth!"
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isTestingPrint = false
                    self.testPrintStatus = "Chưa kết nối máy in Bluetooth nào. Vui lòng kết nối trước!"
                }
            }
        } else if connectionType == "Wifi/LAN" {
            // Test TCP socket to IP:Port
            testTcpSocketPrint()
        } else {
            // AirPrint standard preview
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.isTestingPrint = false
                self.testPrintStatus = "Đã khởi động dịch vụ in Apple AirPrint!"
            }
        }
    }

    private func testTcpSocketPrint() {
        guard let port = UInt16(printerPort), let endpointPort = NWEndpoint.Port(rawValue: port) else {
            isTestingPrint = false
            testPrintStatus = "Cổng Port không hợp lệ!"
            return
        }

        let host = NWEndpoint.Host(printerIp)
        let connection = NWConnection(host: host, port: endpointPort, using: .tcp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let testPayload = "\u{1B}@" + "SAIGON CO.OP - IN THU LAN\nIP: \(printerIp):\(printerPort)\nOK!\n\n\n\u{1D}V\u{01}"
                let data = testPayload.data(using: .ascii) ?? Data()
                connection.send(content: data, completion: .contentProcessed({ error in
                    DispatchQueue.main.async {
                        self.isTestingPrint = false
                        if let error = error {
                            self.testPrintStatus = "Lỗi gửi dữ liệu in: \(error.localizedDescription)"
                        } else {
                            self.testPrintStatus = "In thử nghiệm qua WiFi/LAN thành công!"
                        }
                        connection.cancel()
                    }
                }))
            case .failed(let error):
                DispatchQueue.main.async {
                    self.isTestingPrint = false
                    self.testPrintStatus = "Không thể kết nối tới \(printerIp):\(printerPort) - \(error.localizedDescription)"
                    connection.cancel()
                }
            case .cancelled:
                break
            default:
                break
            }
        }

        connection.start(queue: .global())
    }
}

// MARK: - CORNER RADIUS EXTENSION FOR ACCORDION
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
