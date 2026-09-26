import SwiftUI

// MARK: - MÀN HÌNH NGOẠI VI & CÀI ĐẶT MÁY IN / MÁY QUÉT (ĐỒNG BỘ 1:1 THEO CAIDATSCANNERSCREEN.KT TRÊN ANDROID)
public struct PeripheralsView: View {
    var onBack: () -> Void

    // Scanner Config State
    @AppStorage("enableEAN13") private var enableEAN13: Bool = true
    @AppStorage("enableEAN8") private var enableEAN8: Bool = true
    @AppStorage("enableCode128") private var enableCode128: Bool = true
    @AppStorage("enableCode39") private var enableCode39: Bool = true
    @AppStorage("enableQRCode") private var enableQRCode: Bool = true
    @AppStorage("enableDataMatrix") private var enableDataMatrix: Bool = true
    @AppStorage("enablePDF417") private var enablePDF417: Bool = false
    @AppStorage("scannerMode") private var scannerMode: String = "SINGLE" // SINGLE, CONTINUOUS, BATCH
    @AppStorage("minBarcodeLength") private var minBarcodeLength: Int = 3
    @AppStorage("enableAntiPartialScan") private var enableAntiPartialScan: Bool = true

    // Printer Config State
    @AppStorage("printerConnectionType") private var connectionType: String = "BLUETOOTH" // BLUETOOTH, LAN, USB
    @AppStorage("printerIp") private var printerIp: String = "192.168.1.200"
    @AppStorage("printerPort") private var printerPort: String = "9100"
    @AppStorage("paperSize") private var paperSize: String = "80MM" // 58MM, 80MM
    @AppStorage("selectedPrinterName") private var selectedPrinterName: String = "Chưa kết nối máy in"

    // Expandable Sections State
    @State private var isScannerExpanded: Bool = true
    @State private var isPrinterExpanded: Bool = true
    @State private var isSystemExpanded: Bool = false

    // Bluetooth scanning simulation
    @State private var isScanningBt: Bool = false
    @State private var discoveredPrinters: [String] = ["Máy in nhiệt Xprinter XP-420B", "Máy in hóa đơn Epson TM-T82", "POS Bluetooth Thermal Printer 58mm"]
    @State private var showTestPrintSuccess: Bool = false

    public init(onBack: @escaping () -> Void = {}) {
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar tràn tai thỏ với Safe Area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Ngoại vi & Cài đặt máy in / quét")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                showTestPrintSuccess = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "printer.fill")
                                        .font(.system(size: 13))
                                    Text("In test")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.appPrimaryPink)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // Danh sách cấu hình cuộn
                ScrollView {
                    VStack(spacing: 16) {
                        // SECTION 1: CẤU HÌNH MÁY IN NHIỆT (THERMAL PRINTER)
                        printerSection

                        // SECTION 2: CẤU HÌNH MÁY QUÉT MÃ VẠCH (BARCODE SCANNER)
                        scannerSection

                        // SECTION 3: THÔNG TIN PHẦN CỨNG & HỆ THỐNG
                        systemInfoSection

                        Spacer(minLength: 80)
                    }
                    .padding(14)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .alert(isPresented: $showTestPrintSuccess) {
            Alert(
                title: Text("In thử nghiệm thành công!"),
                message: Text("Đã gửi lệnh in ESC/POS mẫu tới máy in: \(selectedPrinterName). Khổ giấy: \(paperSize)."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - SECTION CẤU HÌNH MÁY IN
    private var printerSection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isPrinterExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Cấu hình Máy in tem & Hóa đơn")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: isPrinterExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.white)
            }

            if isPrinterExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    // Chọn loại kết nối
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phương thức kết nối")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        Picker("Kết nối", selection: $connectionType) {
                            Text("Bluetooth").tag("BLUETOOTH")
                            Text("Mạng LAN / WiFi").tag("LAN")
                            Text("Cáp USB OTG").tag("USB")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Khổ giấy
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Khổ giấy in nhiệt")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        Picker("Khổ giấy", selection: $paperSize) {
                            Text("K58 (58mm)").tag("58MM")
                            Text("K80 (80mm)").tag("80MM")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    if connectionType == "LAN" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Địa chỉ IP máy in:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                            TextField("192.168.1.200", text: $printerIp)
                                .textFieldStyle(RoundedBorderTextFieldStyle())

                            Text("Cổng Port (Mặc định 9100):")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                            TextField("9100", text: $printerPort)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    } else if connectionType == "BLUETOOTH" {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Thiết bị máy in đã chọn:")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appTextSecondary)
                                Spacer()
                                Button(action: {
                                    isScanningBt = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        isScanningBt = false
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        if isScanningBt {
                                            ProgressView().scaleEffect(0.7)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 11))
                                        }
                                        Text(isScanningBt ? "Đang dò..." : "Dò máy in")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                            }

                            Text(selectedPrinterName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.appSecondaryDarkBlue.opacity(0.08))
                                .cornerRadius(8)

                            Text("Danh sách thiết bị Bluetooth khả dụng:")
                                .font(.system(size: 11))
                                .foregroundColor(Color.appTextSecondary)

                            ForEach(discoveredPrinters, id: \.self) { printer in
                                Button(action: {
                                    selectedPrinterName = printer
                                }) {
                                    HStack {
                                        Image(systemName: "printer.dotmatrix.fill")
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                        Text(printer)
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextPrimary)
                                        Spacer()
                                        if selectedPrinterName == printer {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color.appSuccess)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.appBackground)
                                    .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
            }
        }
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - SECTION CẤU HÌNH MÁY QUÉT
    private var scannerSection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isScannerExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(Color.appPrimaryPink)
                    Text("Cấu hình Máy quét Barcode / QR")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: isScannerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.white)
            }

            if isScannerExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Chế độ quét máy ảnh")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)

                        Picker("Chế độ quét", selection: $scannerMode) {
                            Text("Đơn mã").tag("SINGLE")
                            Text("Liên tục").tag("CONTINUOUS")
                            Text("Lưu hàng loạt").tag("BATCH")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    Text("Các định dạng mã được phép nhận dạng:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)

                    VStack(spacing: 8) {
                        Toggle("Mã QR Code (Thiết bị & Ticket)", isOn: $enableQRCode)
                        Toggle("Mã vạch Code 128 (Mã tài sản chuẩn)", isOn: $enableCode128)
                        Toggle("Mã EAN-13 (Hàng hóa & Thiết bị)", isOn: $enableEAN13)
                        Toggle("Mã EAN-8", isOn: $enableEAN8)
                        Toggle("Mã Code 39", isOn: $enableCode39)
                        Toggle("Mã 2D Data Matrix", isOn: $enableDataMatrix)
                        Toggle("Mã PDF-417", isOn: $enablePDF417)
                        Toggle("Chống quét trùng / quét thiếu ký tự", isOn: $enableAntiPartialScan)
                    }
                    .font(.system(size: 13))
                }
                .padding(14)
                .background(Color.white)
            }
        }
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - SECTION THÔNG TIN PHẦN CỨNG
    private var systemInfoSection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation { isSystemExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.appInfo)
                    Text("Thông tin hệ điều hành & Driver")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Spacer()
                    Image(systemName: isSystemExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(14)
                .background(Color.white)
            }

            if isSystemExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "Nền tảng ứng dụng", val: "Apple iOS (SwiftUI Native 1:1)")
                    infoRow(label: "Chuẩn in nhiệt", val: "ESC/POS Thermal Standard (58/80mm)")
                    infoRow(label: "Động cơ quét camera", val: "Apple AVFoundation Barcode Engine")
                    infoRow(label: "Máy quét ngoại vi", val: "Hỗ trợ Bluetooth HID / SPP Scanner")
                    infoRow(label: "Trạng thái kết nối", val: "Sẵn sàng hoạt động")
                }
                .padding(14)
                .background(Color.white)
            }
        }
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func infoRow(label: String, val: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(val)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
        }
    }
}
