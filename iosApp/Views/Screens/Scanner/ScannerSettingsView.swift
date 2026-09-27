import SwiftUI

// MARK: - MÀN HÌNH CÀI ĐẶT SCANNER VÀ NGOẠI VI (ĐỒNG BỘ 1:1 VỚI CAIDATSCANNERSCREEN.KT TRÊN ANDROID)
public struct ScannerSettingsView: View {
    var onBack: () -> Void

    // Scanner Formats
    @AppStorage("enableQRCode") private var enableQRCode: Bool = true
    @AppStorage("enableCode128") private var enableCode128: Bool = true
    @AppStorage("enableCode39") private var enableCode39: Bool = true
    @AppStorage("enableEAN13") private var enableEAN13: Bool = true
    @AppStorage("enableEAN8") private var enableEAN8: Bool = true
    @AppStorage("enableUPCA") private var enableUPCA: Bool = true
    @AppStorage("enableDataMatrix") private var enableDataMatrix: Bool = true
    @AppStorage("enablePDF417") private var enablePDF417: Bool = true

    // Audio & Haptics
    @AppStorage("scanner_beep") private var beepOnScan: Bool = true
    @AppStorage("scanner_vibrate") private var vibrateOnScan: Bool = true
    @AppStorage("enableAntiPartialScan") private var enableAntiPartialScan: Bool = true
    @AppStorage("minBarcodeLength") private var minBarcodeLength: Int = 3

    // Printer settings
    @AppStorage("printerConnectionType") private var printerConnectionType: String = "WIFI"
    @AppStorage("printerIp") private var printerIp: String = "192.168.1.200"
    @AppStorage("printerPort") private var printerPort: String = "9100"
    @AppStorage("printerPaperSize") private var printerPaperSize: String = "50x30 mm"

    @State private var isScannerSectionExpanded: Bool = true
    @State private var isPrinterSectionExpanded: Bool = true

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Cài đặt Scanner & Máy in")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            // SECTION 1: CẤU HÌNH MÁY QUÉT MÃ VẠCH
                            scannerSection()

                            // SECTION 2: CẤU HÌNH MÁY IN TEM / BIÊN BẢN
                            printerSection()
                        }
                        .padding(16)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private func scannerSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isScannerSectionExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(Color.appPrimaryPink)
                    Text("Cấu hình bộ giải mã Scanner")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                    Image(systemName: isScannerSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            if isScannerSectionExpanded {
                Divider()

                VStack(spacing: 10) {
                    Toggle("Mã QR (QR Code)", isOn: $enableQRCode)
                    Toggle("Code 128 (Công nghiệp)", isOn: $enableCode128)
                    Toggle("Code 39", isOn: $enableCode39)
                    Toggle("EAN-13 (Bán lẻ)", isOn: $enableEAN13)
                    Toggle("EAN-8", isOn: $enableEAN8)
                    Toggle("UPC-A", isOn: $enableUPCA)
                    Toggle("Data Matrix", isOn: $enableDataMatrix)
                    Toggle("PDF-417", isOn: $enablePDF417)
                }
                .font(.system(size: 14))

                Divider()

                VStack(spacing: 10) {
                    Toggle("Phát tiếng bíp khi quét", isOn: $beepOnScan)
                    Toggle("Rung phản hồi khi quét", isOn: $vibrateOnScan)
                    Toggle("Chống quét một phần (Anti-partial)", isOn: $enableAntiPartialScan)
                }
                .font(.system(size: 14))
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func printerSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isPrinterSectionExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Cấu hình Máy in Tem & Báo cáo")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                    Image(systemName: isPrinterSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            if isPrinterSectionExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Phương thức kết nối")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Picker("Kết nối", selection: $printerConnectionType) {
                        Text("Wi-Fi / LAN (TCP/IP)").tag("WIFI")
                        Text("Apple AirPrint").tag("AIRPRINT")
                        Text("Bluetooth ESC/POS").tag("BLUETOOTH")
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    if printerConnectionType == "WIFI" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Địa chỉ IP máy in")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                            TextField("192.168.1.200", text: $printerIp)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color.appBackground)
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cổng kết nối (Port)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                            TextField("9100", text: $printerPort)
                                .font(.system(size: 14))
                                .padding(10)
                                .background(Color.appBackground)
                                .cornerRadius(8)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Khổ giấy / Khổ tem mặc định")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appTextSecondary)

                        Picker("Khổ tem", selection: $printerPaperSize) {
                            Text("50x30 mm").tag("50x30 mm")
                            Text("40x30 mm").tag("40x30 mm")
                            Text("80 mm (Cuộn)").tag("80 mm")
                            Text("Khổ A4 (Biên bản)").tag("A4")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.appBackground)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }
}
