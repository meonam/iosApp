import SwiftUI
import AVFoundation
import Vision

// MARK: - MÀN HÌNH QUÉT MÃ QR / BARCODE (ĐỒNG BỘ 1:1 HOÀN TOÀN VỚI QRSCANNERSCREEN.KT TRÊN ANDROID)
public struct QRScannerView: View {
    public var viewModel: DeviceViewModel? = nil
    public var onScanResult: (String) -> Void
    public var onDismiss: () -> Void
    public var onNavigateToDetail: ((String) -> Void)? = nil
    public var onNavigateToAdd: ((String) -> Void)? = nil

    // User preferences từ ScannerSettings
    @AppStorage("scanner_beep") private var beepOnScan = true
    @AppStorage("scanner_vibrate") private var vibrateOnScan = true
    @AppStorage("enableAntiPartialScan") private var enableAntiPartialScan = true
    @AppStorage("minBarcodeLength") private var minBarcodeLength = 3

    // Camera State
    @State private var isFlashOn = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    @State private var isProcessing = false
    @State private var hasCameraPermission = false
    @State private var isPermissionDetermined = false

    // Manual Input Dialog
    @State private var showManualInput = false
    @State private var manualCode = ""

    // Settings sheet
    @State private var showSettings = false

    // Photo Library Picker
    @State private var showPhotoPicker = false

    // Unrecognized code dialog state
    @State private var unrecognizedCode: String? = nil

    // Toast banner
    @State private var toastMessage: String? = nil
    @State private var toastWorkItem: DispatchWorkItem? = nil

    public init(
        viewModel: DeviceViewModel? = nil,
        onScanResult: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void,
        onNavigateToDetail: ((String) -> Void)? = nil,
        onNavigateToAdd: ((String) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onScanResult = onScanResult
        self.onDismiss = onDismiss
        self.onNavigateToDetail = onNavigateToDetail
        self.onNavigateToAdd = onNavigateToAdd
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar với SafeArea top
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        topBar
                    }
                    .background(Color.appTopBarColor)

                    if isPermissionDetermined {
                        if hasCameraPermission {
                            ZStack {
                                // Camera Preview
                                CameraPreviewView(
                                    isFlashOn: $isFlashOn,
                                    cameraPosition: $cameraPosition,
                                    isProcessing: $isProcessing,
                                    onScanResult: handleScannedCode
                                )
                                .edgesIgnoringSafeArea(.bottom)

                                // Khung ngắm & Laser Animation
                                ScannerOverlayView(
                                    isProcessing: isProcessing,
                                    batchCount: (viewModel?.isBatchModeEnabled == true) ? viewModel?.selectedBatchDeviceIds.count : nil
                                )

                                // Nút nhập tay mã ở đáy màn hình
                                VStack {
                                    Spacer()
                                    Button(action: {
                                        manualCode = ""
                                        showManualInput = true
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "keyboard")
                                                .font(.system(size: 15))
                                            Text("Nhập tay mã")
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 22)
                                        .padding(.vertical, 12)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .padding(.bottom, 36)
                                }
                            }
                        } else {
                            // Màn hình khi từ chối quyền Camera
                            cameraPermissionDeniedView
                        }
                    } else {
                        VStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimaryPink))
                            Spacer()
                        }
                    }
                }

                // Toast Banner thông báo (Đồng bộ Android Toast)
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                            .frame(height: SafeAreaHelper.top(geometry) + 60)
                        HStack(spacing: 10) {
                            Text(toast)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#1E293B").opacity(0.92))
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .zIndex(100)
                }

                // Hộp thoại nhập tay mã
                if showManualInput {
                    manualInputDialog
                }

                // Hộp thoại "Chưa có thiết bị này" (Đồng bộ 1:1 Compose AlertDialog trên Android)
                if let code = unrecognizedCode {
                    unrecognizedCodeDialog(for: code)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            checkCameraPermission()
        }
        .sheet(isPresented: $showPhotoPicker) {
            ImagePickerSheet(isPresented: $showPhotoPicker) { img in
                detectBarcodesFromImage(img)
            }
        }
        .sheet(isPresented: $showSettings) {
            ScannerSettingsView(onBack: { showSettings = false })
        }
    }

    // MARK: - TOP BAR (1:1 VỚI ANDROID TOPAPPBAR)
    private var topBar: some View {
        HStack(spacing: 8) {
            // Nút Quay lại
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 44)
            }

            Text("Quét mã QR / Barcode")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if hasCameraPermission {
                // Nút Bật/Tắt Flashlight
                Button(action: {
                    isFlashOn.toggle()
                }) {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isFlashOn ? Color(hex: "#FBBF24") : .white)
                        .frame(width: 38, height: 38)
                }

                // Nút Quét từ thư viện ảnh
                Button(action: { showPhotoPicker = true }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                }

                // Nút Cài đặt Scanner & Máy in
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - MÀN HÌNH TỪ CHỐI QUYỀN CAMERA (1:1 VỚI ANDROID)
    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Circle()
                .fill(Color(hex: "#1E293B"))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "camera.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 38, height: 38)
                        .foregroundColor(Color.appPrimaryPink)
                )

            Text("Yêu cầu quyền truy cập Camera")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Ứng dụng cần sử dụng máy ảnh để quét mã QR và mã vạch trên thiết bị quản lý.")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#94A3B8"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Cấp quyền Camera")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.appPrimaryPink)
                .cornerRadius(12)
            }
            Spacer()
        }
    }

    // MARK: - DIALOG CHƯA CÓ THIẾT BỊ NÀY (ĐỒNG BỘ 1:1 ANDROID ALERTDIALOG)
    private func unrecognizedCodeDialog(for code: String) -> some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    unrecognizedCode = nil
                    isProcessing = false
                }

            VStack(spacing: 16) {
                // Biểu tượng tròn đỏ trợ giúp
                Circle()
                    .fill(Color(hex: "#FEF2F2"))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Color(hex: "#DC2626"))
                    )

                Text("Chưa có thiết bị này")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .multilineTextAlignment(.center)

                Text("Mã vừa quét chưa được liên kết với bất kỳ thiết bị nào trong hệ thống:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // Khung hiển thị mã vừa quét
                Text(code)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#0F172A"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#F1F5F9"))
                    .cornerRadius(8)

                Text("Bạn có muốn thêm mới một thiết bị và gán mã này ngay không?")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                // Action Buttons
                HStack(spacing: 12) {
                    // Nút Quét lại
                    Button(action: {
                        unrecognizedCode = nil
                        isProcessing = false
                    }) {
                        Text("Quét lại")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Nút Thêm máy mới
                    Button(action: {
                        let targetCode = code
                        unrecognizedCode = nil
                        isProcessing = false
                        onDismiss()
                        onNavigateToAdd?(targetCode)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text("Thêm máy mới")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 4)
            }
            .padding(22)
            .background(Color.white)
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 28)
        }
        .zIndex(150)
    }

    // MARK: - DIALOG NHẬP TAY MÃ
    private var manualInputDialog: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture {
                    showManualInput = false
                }

            VStack(spacing: 16) {
                Text("Nhập tay mã thiết bị")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Nhập mã thiết bị (Serial / ID) cần tra cứu hoặc gán:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Ví dụ: TB001, POCO-X6...", text: $manualCode)
                    .font(.system(size: 15))
                    .padding(12)
                    .background(Color.appBackground)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.appPrimaryPink.opacity(0.5), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    Button(action: {
                        showManualInput = false
                        manualCode = ""
                    }) {
                        Text("Hủy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    Button(action: {
                        let clean = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                        showManualInput = false
                        manualCode = ""
                        if !clean.isEmpty {
                            handleScannedCode(clean)
                        }
                    }) {
                        Text("Xác nhận")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(22)
            .background(Color.white)
            .cornerRadius(18)
            .padding(.horizontal, 28)
        }
        .zIndex(150)
    }

    // MARK: - LOGIC QUÉT VÀ TRA CỨU THIẾT BỊ (1:1 VỚI ANDROID)
    private func handleScannedCode(_ rawCode: String) {
        guard !isProcessing && unrecognizedCode == nil && !showManualInput else { return }
        isProcessing = true

        let cleanCode = extractDeviceId(from: rawCode)

        // Kiểm tra chống quét một phần
        if enableAntiPartialScan && cleanCode.count < minBarcodeLength {
            isProcessing = false
            return
        }

        // Phản hồi âm thanh và rung
        if beepOnScan {
            AudioServicesPlaySystemSound(1052)
        }
        if vibrateOnScan {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }

        // Chế độ quét hàng loạt (Batch Mode)
        if let vm = viewModel, vm.isBatchModeEnabled {
            vm.selectedBatchDeviceIds.insert(cleanCode)
            showToastNotification("⚡ Đã quét chọn: \(cleanCode) (Tổng: \(vm.selectedBatchDeviceIds.count))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.isProcessing = false
            }
            return
        }

        // Tra cứu thiết bị tự động
        if let vm = viewModel {
            // 1. Kiểm tra trong cache nội bộ trước (nhanh tức thì, không cần mạng)
            if let local = vm.rawDevices.first(where: { $0.id.caseInsensitiveCompare(cleanCode) == .orderedSame }) {
                showToastNotification("✅ Đã tìm thấy: \(local.ten)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    if let navigateDetail = self.onNavigateToDetail {
                        navigateDetail(local.id)
                    } else {
                        self.onScanResult(cleanCode)
                    }
                }
                return
            }

            // 2. Tra cứu trực tiếp từ Firestore qua Document ID
            Task {
                if let dev = await vm.getDeviceById(cleanCode) {
                    showToastNotification("✅ Đã tìm thấy: \(dev.ten)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        self.isProcessing = false
                        if let navigateDetail = self.onNavigateToDetail {
                            navigateDetail(dev.id)
                        } else {
                            self.onScanResult(cleanCode)
                        }
                    }
                } else {
                    self.isProcessing = false
                    self.unrecognizedCode = cleanCode
                }
            }
        } else {
            // Trường hợp màn hình gọi không truyền viewModel (ví dụ: AddDeviceView, LichSuView)
            self.onScanResult(cleanCode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.isProcessing = false
            }
        }
    }

    // Trích xuất mã ID từ URL hoặc Barcode thuần
    private func extractDeviceId(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let url = URL(string: trimmed), let host = url.host, !host.isEmpty {
            // Check Query parameters
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let items = components.queryItems {
                if let idParam = items.first(where: {
                    let name = $0.name.lowercased()
                    return name == "id" || name == "initialid" || name == "deviceid" || name == "code"
                })?.value, !idParam.isEmpty {
                    return idParam
                }
            }
            // Check Path segments (/device/{id} hoặc /devices/{id})
            let paths = url.pathComponents.filter { $0 != "/" }
            if let idx = paths.firstIndex(where: {
                let p = $0.lowercased()
                return p == "device" || p == "devices"
            }), idx + 1 < paths.count {
                return paths[idx + 1]
            }
            if let last = paths.last, !last.isEmpty {
                return last
            }
        }
        return trimmed
    }

    // Hiển thị Toast thông báo nhanh
    private func showToastNotification(_ message: String) {
        toastWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            toastMessage = message
        }
        let item = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.toastMessage = nil
            }
        }
        toastWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: item)
    }

    // MARK: - QUÉT MÃ TỪ ẢNH TRONG THƯ VIỆN (VISION FRAMEWORK)
    private func detectBarcodesFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            showToastNotification("❌ Không thể đọc file ảnh")
            return
        }
        let request = VNDetectBarcodesRequest { req, _ in
            guard let results = req.results as? [VNBarcodeObservation],
                  let first = results.first,
                  let payload = first.payloadStringValue,
                  !payload.isEmpty else {
                DispatchQueue.main.async {
                    self.showToastNotification("Không nhận diện được mã QR/Barcode trong ảnh")
                }
                return
            }
            DispatchQueue.main.async {
                self.handleScannedCode(payload)
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    // Kiểm tra quyền Camera
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
            isPermissionDetermined = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.hasCameraPermission = granted
                    self.isPermissionDetermined = true
                }
            }
        default:
            hasCameraPermission = false
            isPermissionDetermined = true
        }
    }
}

// MARK: - CAMERA PREVIEW CONTROLLER WRAPPER
struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var isFlashOn: Bool
    @Binding var cameraPosition: AVCaptureDevice.Position
    @Binding var isProcessing: Bool
    let onScanResult: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScanResult = onScanResult
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.updateFlash(isFlashOn: isFlashOn)
        uiViewController.updateCameraPosition(position: cameraPosition)
        uiViewController.isProcessing = isProcessing
    }
}

// MARK: - SCANNER VIEW CONTROLLER (AVFOUNDATION)
class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onScanResult: ((String) -> Void)?
    var isProcessing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        captureSession = AVCaptureSession()
        setupCamera(position: .back)
    }

    func setupCamera(position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        captureSession.outputs.forEach { captureSession.removeOutput($0) }

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            captureSession.commitConfiguration()
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

            // Đọc cài đặt định dạng mã từ ScannerSettings
            var enabledTypes: [AVMetadataObject.ObjectType] = []
            let ud = UserDefaults.standard

            if ud.object(forKey: "enableQRCode") as? Bool ?? true { enabledTypes.append(.qr) }
            if ud.object(forKey: "enableCode128") as? Bool ?? true { enabledTypes.append(.code128) }
            if ud.object(forKey: "enableCode39") as? Bool ?? true { enabledTypes.append(.code39) }
            if ud.object(forKey: "enableEAN13") as? Bool ?? true { enabledTypes.append(.ean13) }
            if ud.object(forKey: "enableEAN8") as? Bool ?? true { enabledTypes.append(.ean8) }
            if ud.object(forKey: "enableUPCA") as? Bool ?? true { enabledTypes.append(.upce) }
            if ud.object(forKey: "enableDataMatrix") as? Bool ?? true { enabledTypes.append(.dataMatrix) }
            if ud.object(forKey: "enablePDF417") as? Bool ?? true { enabledTypes.append(.pdf417) }

            if enabledTypes.isEmpty {
                enabledTypes = [.qr, .code128, .code39, .ean13, .ean8, .upce, .dataMatrix, .pdf417]
            }

            metadataOutput.metadataObjectTypes = enabledTypes
        }

        captureSession.commitConfiguration()

        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.layer.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessing,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue,
              !stringValue.isEmpty else { return }

        onScanResult?(stringValue)
    }

    func updateFlash(isFlashOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = isFlashOn ? .on : .off
        device.unlockForConfiguration()
    }

    func updateCameraPosition(position: AVCaptureDevice.Position) {
        guard let currentInput = captureSession?.inputs.first as? AVCaptureDeviceInput else { return }
        if currentInput.device.position != position {
            setupCamera(position: position)
        }
    }
}

// MARK: - SCANNER OVERLAY VÀ HIỆU ỨNG TIA LASER (1:1 VỚI ANDROID SCANNEROVERLAY)
struct ScannerOverlayView: View {
    let isProcessing: Bool
    var batchCount: Int? = nil

    @State private var scanLineOffset: CGFloat = -130

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed Overlay với hình chữ nhật bo tròn ở giữa được đục lỗ
                Color.black.opacity(0.5)
                    .mask(
                        ZStack {
                            Rectangle()
                                .fill(Color.white)

                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.black)
                                .frame(width: 260, height: 260)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )

                // Viền mờ màu trắng quanh khung quét
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 260, height: 260)

                // 4 Góc khung ngắm công nghệ cao màu Hồng PrimaryPink
                ScannerCorners()
                    .stroke(Color.appPrimaryPink, lineWidth: 4)
                    .frame(width: 260, height: 260)

                // Tia Laser chạy quét
                if !isProcessing {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.appPrimaryPink, .white, Color.appPrimaryPink, .clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 260, height: 3)
                        .offset(y: scanLineOffset)
                        .onAppear {
                            withAnimation(Animation.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                                scanLineOffset = 130
                            }
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimaryPink))
                        .scaleEffect(1.5)
                }

                // Hướng dẫn và trạng thái quét
                VStack(spacing: 8) {
                    Spacer()

                    // Badge hướng dẫn
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 16))
                            .foregroundColor(Color.appPrimaryPink)
                        Text("Căn chỉnh mã QR hoặc Barcode vào giữa khung")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .cornerRadius(20)

                    // Badge quét hàng loạt nếu đang bật
                    if let count = batchCount {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#10B981"))
                            Text("Chế độ quét liên tục: \(count) thiết bị đã chọn")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#10B981"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(16)
                    }

                    Spacer()
                        .frame(height: geometry.size.height / 2 - 190)
                }
            }
        }
    }
}

// 4 Góc khung ngắm công nghệ cao
struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = 28

        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // Top Right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // Bottom Left
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))

        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))

        return path
    }
}

// MARK: - IMAGE PICKER (TƯƠNG THÍCH IOS 15+)
struct ImagePickerSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerSheet

        init(_ parent: ImagePickerSheet) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
