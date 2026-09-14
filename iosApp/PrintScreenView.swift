import SwiftUI

public enum LabelPaperSize: String, CaseIterable, Identifiable {
    case decal1 = "Decal 1 tem (50x30 mm)"
    case decal40x30 = "Decal 1 tem (40x30 mm)"
    case decal50x25 = "Decal 1 tem (50x25 mm)"
    case decal2 = "Decal 2 tem (35x22 mm)"
    case decal3 = "Decal 3 tem (35x22 mm)"
    case tomyA4_65 = "A4 - 65 tem (Tomy 145)"
    case k80 = "Giấy in nhiệt K80"
    case k58 = "Giấy in nhiệt K58"

    public var id: String { rawValue }
}

public enum LabelLayoutMode: String, CaseIterable, Identifiable {
    case qrLeftTextRight = "Mã QR Trái - Chữ Phải"
    case qrTopTextBottom = "Mã QR Trên - Chữ Dưới"
    case qrOnlyWithCode = "QR + Serial (Tối giản)"

    public var id: String { rawValue }
}

public struct PrintScreenView: View {
    public let device: DeviceItem?
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var printerService = BluetoothPrinterService.shared
    @State private var paperSize: LabelPaperSize = .decal1
    @State private var layoutMode: LabelLayoutMode = .qrLeftTextRight
    @State private var showQr: Bool = true
    @State private var showBarcode: Bool = false
    @State private var showCompanyName: Bool = true
    @State private var customHeader: String = "SAIGON CO.OP"
    @State private var showDeviceId: Bool = true
    @State private var showDeviceName: Bool = true
    @State private var showUnit: Bool = true
    @State private var showDepartment: Bool = false
    @State private var showBorder: Bool = true
    @State private var fontSizeScale: Double = 1.0
    @State private var copies: Int = 1

    @State private var showBluetoothSheet: Bool = false
    @State private var toastMessage: String? = nil

    public init(device: DeviceItem?) {
        self.device = device
    }

    private var sampleDevice: DeviceItem {
        device ?? DeviceItem(
            id: "DEV_SAMPLE",
            code: "SG-POS-2024-001",
            name: "Máy POS Tính Tiền Cảm Ứng",
            category: "Thiết bị bán hàng",
            serialNumber: "SN884920194",
            unit: "Co.opmart Cần Thơ",
            status: "Đang sử dụng",
            department: "Bộ phận Thu ngân",
            iconName: "desktopcomputer"
        )
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. LIVE LABEL PREVIEW CARD
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.appPrimaryPink)
                            Text("Xem trước tem nhãn tài sản")
                                .font(.headline)
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text(paperSize.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.appPrimaryPink.opacity(0.12))
                                .foregroundColor(.appPrimaryPink)
                                .clipShape(Capsule())
                        }

                        // THE LABEL CANVAS
                        VStack(spacing: 6) {
                            if showCompanyName {
                                Text(customHeader.isEmpty ? "SAIGON CO.OP" : customHeader)
                                    .font(.system(size: 13 * fontSizeScale, weight: .bold))
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                            }

                            switch layoutMode {
                            case .qrLeftTextRight:
                                HStack(alignment: .center, spacing: 12) {
                                    if showQr, let qrImg = BarcodeQrGenerator.generateQRCode(from: sampleDevice.code, size: 100) {
                                        Image(uiImage: qrImg)
                                            .resizable()
                                            .interpolation(.none)
                                            .frame(width: 74, height: 74)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        if showDeviceId {
                                            Text("Mã: \(sampleDevice.code)")
                                                .font(.system(size: 12 * fontSizeScale, weight: .bold))
                                                .foregroundColor(.black)
                                        }
                                        if showDeviceName {
                                            Text(sampleDevice.name)
                                                .font(.system(size: 11 * fontSizeScale, weight: .medium))
                                                .foregroundColor(.black)
                                                .lineLimit(2)
                                        }
                                        if showUnit {
                                            Text(sampleDevice.unit)
                                                .font(.system(size: 10 * fontSizeScale))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                        if showDepartment {
                                            Text(sampleDevice.department)
                                                .font(.system(size: 9 * fontSizeScale))
                                                .foregroundColor(.gray)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }

                            case .qrTopTextBottom:
                                VStack(spacing: 6) {
                                    if showQr, let qrImg = BarcodeQrGenerator.generateQRCode(from: sampleDevice.code, size: 100) {
                                        Image(uiImage: qrImg)
                                            .resizable()
                                            .interpolation(.none)
                                            .frame(width: 70, height: 70)
                                    }

                                    if showDeviceId {
                                        Text(sampleDevice.code)
                                            .font(.system(size: 12 * fontSizeScale, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    if showDeviceName {
                                        Text(sampleDevice.name)
                                            .font(.system(size: 11 * fontSizeScale))
                                            .foregroundColor(.black)
                                    }
                                }

                            case .qrOnlyWithCode:
                                VStack(spacing: 4) {
                                    if showQr, let qrImg = BarcodeQrGenerator.generateQRCode(from: sampleDevice.code, size: 120) {
                                        Image(uiImage: qrImg)
                                            .resizable()
                                            .interpolation(.none)
                                            .frame(width: 90, height: 90)
                                    }
                                    Text(sampleDevice.code)
                                        .font(.system(size: 13 * fontSizeScale, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }

                            if showBarcode, let barImg = BarcodeQrGenerator.generateBarcode(from: sampleDevice.code, width: 260, height: 50) {
                                Image(uiImage: barImg)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(height: 38)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(showBorder ? Color.black.opacity(0.7) : Color.clear, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 2. CONFIGURATION OPTIONS
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cấu hình in ấn")
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)

                        // Paper size picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Khổ giấy in / Tem")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Khổ giấy", selection: $paperSize) {
                                ForEach(LabelPaperSize.allCases) { size in
                                    Text(size.rawValue).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Layout picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bố cục tem")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("Bố cục", selection: $layoutMode) {
                                ForEach(LabelLayoutMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        // Toggles
                        Group {
                            Toggle("Hiện Mã QR", isOn: $showQr)
                            Toggle("Hiện Mã vạch (Code 128)", isOn: $showBarcode)
                            Toggle("Hiện Tiêu đề Đơn vị", isOn: $showCompanyName)
                            if showCompanyName {
                                TextField("Tên tiêu đề", text: $customHeader)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Toggle("Hiện Đơn vị", isOn: $showUnit)
                            Toggle("Hiện Phòng ban", isOn: $showDepartment)
                            Toggle("Vẽ khung viền tem", isOn: $showBorder)
                        }

                        // Copies
                        Stepper(value: $copies, in: 1...50) {
                            HStack {
                                Text("Số bản in:")
                                Spacer()
                                Text("\(copies) bản")
                                    .fontWeight(.bold)
                                    .foregroundColor(.appPrimaryPink)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // 3. BLUETOOTH PRINTER STATUS & CONTROLS
                    VStack(spacing: 12) {
                        HStack {
                            Circle()
                                .fill(printerService.isConnected ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            Text(printerService.isConnected ? "Đã kết nối: \(printerService.connectedPeripheral?.name ?? "Máy in")" : "Chưa kết nối máy in Bluetooth")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Chọn máy in") {
                                printerService.start()
                                printerService.startScan()
                                showBluetoothSheet = true
                            }
                            .font(.caption.bold())
                            .foregroundColor(.appPrimaryPink)
                        }

                        HStack(spacing: 12) {
                            // AirPrint Button
                            Button(action: {
                                triggerAirPrint()
                            }) {
                                HStack {
                                    Image(systemName: "printer.fill")
                                    Text("AirPrint / PDF")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.appSecondaryDarkBlue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Bluetooth Direct Print Button
                            Button(action: {
                                triggerBluetoothPrint()
                            }) {
                                HStack {
                                    Image(systemName: "bolt.horizontal.fill")
                                    Text("In Bluetooth")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.appPrimaryPink)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(16)
            }
            .navigationTitle("In Tem Thiết Bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .sheet(isPresented: $showBluetoothSheet) {
                BluetoothPrinterPickerSheet()
            }
            .overlay(
                Group {
                    if let msg = toastMessage {
                        VStack {
                            Spacer()
                            Text(msg)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.black.opacity(0.8))
                                .clipShape(Capsule())
                                .padding(.bottom, 20)
                        }
                        .transition(.opacity)
                    }
                }
            )
        }
    }

    private func triggerAirPrint() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        // Render label into PDF
        let pdfData = generatePdfData()
        printerService.printViaAirPrint(from: rootVC.view, documentData: pdfData, jobName: "QLTB_\(sampleDevice.code)")
    }

    private func triggerBluetoothPrint() {
        guard printerService.isConnected else {
            showBluetoothSheet = true
            printerService.startScan()
            return
        }

        // Print header & device info in ESC/POS
        for _ in 0..<copies {
            printerService.printText(customHeader, align: 1, isBold: true)
            printerService.printText("--------------------------------", align: 1)
            if showDeviceId {
                printerService.printText("Ma TB: \(sampleDevice.code)", align: 0, isBold: true)
            }
            if showDeviceName {
                printerService.printText("Ten: \(sampleDevice.name)", align: 0)
            }
            if showUnit {
                printerService.printText("Don vi: \(sampleDevice.unit)", align: 0)
            }
            if showDepartment {
                printerService.printText("Phong ban: \(sampleDevice.department)", align: 0)
            }
            printerService.printText("--------------------------------", align: 1)
            printerService.printCutPaper()
        }

        withAnimation {
            toastMessage = "Đã gửi lệnh in \(copies) bản!"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toastMessage = nil
        }
    }

    private func generatePdfData() -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 300, height: 200))
        return pdfRenderer.pdfData { context in
            context.beginPage()
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]

            (customHeader as NSString).draw(at: CGPoint(x: 20, y: 15), withAttributes: titleAttributes)
            ("Mã: \(sampleDevice.code)" as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: bodyAttributes)
            ("Tên: \(sampleDevice.name)" as NSString).draw(at: CGPoint(x: 20, y: 60), withAttributes: bodyAttributes)
            ("Đơn vị: \(sampleDevice.unit)" as NSString).draw(at: CGPoint(x: 20, y: 80), withAttributes: bodyAttributes)

            if let qr = BarcodeQrGenerator.generateQRCode(from: sampleDevice.code, size: 80) {
                qr.draw(in: CGRect(x: 200, y: 35, width: 80, height: 80))
            }
        }
    }
}

// MARK: - Bluetooth Printer Picker Modal Sheet
public struct BluetoothPrinterPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var printerService = BluetoothPrinterService.shared

    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Trạng thái")) {
                    HStack {
                        Text("Trạng thái:")
                        Spacer()
                        Text(printerService.statusMessage)
                            .foregroundColor(.secondary)
                    }
                    if printerService.isScanning {
                        HStack {
                            ProgressView()
                            Text("Đang tìm máy in...")
                                .padding(.leading, 8)
                        }
                    }
                }

                Section(header: Text("Máy in tìm thấy (\(printerService.discoveredPrinters.count))")) {
                    if printerService.discoveredPrinters.isEmpty && !printerService.isScanning {
                        Text("Không tìm thấy máy in nào gần đây. Hãy đảm bảo máy in đã bật Bluetooth.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(printerService.discoveredPrinters) { item in
                            Button(action: {
                                printerService.connect(to: item)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "printer.fill")
                                        .foregroundColor(.appPrimaryPink)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text("RSSI: \(item.rssi.intValue) dBm")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if printerService.connectedPeripheral?.identifier == item.peripheral.identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kết Nối Máy In Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Quét lại") {
                        printerService.startScan()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        printerService.stopScan()
                        dismiss()
                    }
                }
            }
        }
    }
}
