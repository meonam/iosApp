import SwiftUI
import AVFoundation
import Vision
import PhotosUI

// MARK: - MÀN HÌNH QUÉT MÃ QR / BARCODE (ĐỒNG BỘ 1:1 VỚI QRSCANNERSCREEN.KT TRÊN ANDROID)
public struct QRScannerView: View {
    public var viewModel: DeviceViewModel? = nil
    public var onScanResult: (String) -> Void
    public var onDismiss: () -> Void
    public var onNavigateToDetail: ((String) -> Void)? = nil
    public var onNavigateToAdd: ((String) -> Void)? = nil

    @AppStorage("scanner_beep") private var beepOnScan = true
    @AppStorage("scanner_vibrate") private var vibrateOnScan = true

    @State private var isFlashOn = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    @State private var showManualInput = false
    @State private var manualCode = ""
    @State private var isProcessing = false

    @State private var hasCameraPermission = false
    @State private var isPermissionDetermined = false

    // Settings sheet
    @State private var showSettings = false

    // Photo Library Picker
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    // Unrecognized code alert
    @State private var unrecognizedCode: String? = nil

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
                    // Top bar với safe area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appTopBarColor)

                    if isPermissionDetermined {
                        if hasCameraPermission {
                            ZStack {
                                CameraPreviewView(
                                    isFlashOn: $isFlashOn,
                                    cameraPosition: $cameraPosition,
                                    isProcessing: $isProcessing,
                                    onScanResult: handleScannedCode
                                )
                                .edgesIgnoringSafeArea(.bottom)

                                ScannerOverlayView(isProcessing: isProcessing)

                                VStack {
                                    Spacer()
                                    Button(action: {
                                        showManualInput = true
                                    }) {
                                        HStack {
                                            Image(systemName: "keyboard")
                                            Text("Nhập tay mã")
                                                .fontWeight(.bold)
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(24)
                                    }
                                    .padding(.bottom, 40)
                                }
                            }
                        } else {
                            // Permission Denied View
                            VStack(spacing: 20) {
                                Spacer()
                                Image(systemName: "camera.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)

                                Text("Yêu cầu quyền truy cập Camera")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                Text("Ứng dụng cần sử dụng máy ảnh để quét mã QR và mã vạch trên thiết bị quản lý.")
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 32)

                                Button(action: {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text("Mở Cài đặt")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 12)
                                        .background(Color.appPrimaryPink)
                                        .cornerRadius(10)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .alert("Nhập tay mã thiết bị", isPresented: $showManualInput) {
                TextField("Nhập mã thiết bị (Serial)...", text: $manualCode)
                Button("Xác nhận") {
                    let code = manualCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !code.isEmpty {
                        handleScannedCode(code)
                    }
                    manualCode = ""
                }
                Button("Hủy", role: .cancel) {
                    manualCode = ""
                }
            } message: {
                Text("Vui lòng nhập chính xác mã thiết bị")
            }
            .alert("Chưa có thiết bị này", isPresented: Binding(
                get: { unrecognizedCode != nil },
                set: { if !$0 { unrecognizedCode = nil } }
            )) {
                Button("Thêm mới thiết bị") {
                    if let code = unrecognizedCode {
                        unrecognizedCode = nil
                        onNavigateToAdd?(code)
                    }
                }
                Button("Quét lại", role: .cancel) {
                    unrecognizedCode = nil
                    isProcessing = false
                }
            } message: {
                Text("Mã vừa quét [\(unrecognizedCode ?? "")] chưa được liên kết với bất kỳ thiết bị nào trong hệ thống. Bạn có muốn thêm mới thiết bị với mã này không?")
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            checkCameraPermission()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    detectBarcodesFromImage(uiImage)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            ScannerSettingsView(onBack: { showSettings = false })
        }
    }

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

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
            }

            Text("Quét mã QR / Barcode")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if hasCameraPermission {
                // Flashlight
                Button(action: {
                    isFlashOn.toggle()
                }) {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isFlashOn ? Color(hex: "#FBBF24") : .white)
                        .padding(.horizontal, 6)
                }

                // Gallery Image Picker
                Button(action: { showPhotoPicker = true }) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                }

                // Settings
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                }
            }
        }
        .padding(.trailing, 8)
    }

    private func detectBarcodesFromImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        let request = VNDetectBarcodesRequest { req, err in
            guard let results = req.results as? [VNBarcodeObservation], let first = results.first, let payload = first.payloadStringValue else {
                return
            }
            DispatchQueue.main.async {
                self.handleScannedCode(payload)
            }
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    private func handleScannedCode(_ code: String) {
        guard !isProcessing && unrecognizedCode == nil else { return }
        isProcessing = true

        if beepOnScan {
            AudioServicesPlaySystemSound(1052)
        }
        if vibrateOnScan {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }

        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        // If viewModel is provided, perform 1:1 auto-lookup
        if let vm = viewModel {
            Task {
                if let dev = await vm.getDeviceById(cleanCode) {
                    self.isProcessing = false
                    self.onScanResult(cleanCode)
                    self.onNavigateToDetail?(dev.id)
                } else {
                    self.isProcessing = false
                    self.unrecognizedCode = cleanCode
                }
            }
        } else {
            onScanResult(cleanCode)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isProcessing = false
            }
        }
    }
}

// MARK: - Camera Preview Wrapper
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

// MARK: - Scanner View Controller
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
            metadataOutput.metadataObjectTypes = [
                .qr,
                .ean13,
                .ean8,
                .code128,
                .code39,
                .pdf417,
                .dataMatrix,
                .upce
            ]
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
              let stringValue = readableObject.stringValue else { return }

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

// MARK: - Scanner Overlay
struct ScannerOverlayView: View {
    let isProcessing: Bool
    @State private var scanLineOffset: CGFloat = -130

    var body: some View {
        GeometryReader { geometry in
            ZStack {
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

                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 260, height: 260)

                ScannerCorners()
                    .stroke(Color.appPrimaryPink, lineWidth: 4)
                    .frame(width: 260, height: 260)

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

                VStack {
                    Spacer()
                    Text("Căn chỉnh mã QR hoặc Barcode vào giữa khung")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.65))
                        .cornerRadius(20)
                        .padding(.bottom, geometry.size.height / 2 - 170)
                }
            }
        }
    }
}

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
