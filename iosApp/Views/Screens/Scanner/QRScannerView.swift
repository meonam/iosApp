import SwiftUI
import AVFoundation

public struct QRScannerView: View {
    let onScanResult: (String) -> Void
    let onDismiss: () -> Void
    
    @AppStorage("scanner_beep") private var beepOnScan = true
    @AppStorage("scanner_vibrate") private var vibrateOnScan = true
    
    @State private var isFlashOn = false
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    @State private var showManualInput = false
    @State private var manualCode = ""
    @State private var isProcessing = false
    
    @State private var hasCameraPermission = false
    @State private var isPermissionDetermined = false
    
    public init(onScanResult: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.onScanResult = onScanResult
        self.onDismiss = onDismiss
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
                    
                    if isPermissionDetermined {
                        if hasCameraPermission {
                            // Camera View & Overlay
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
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(Color.black.opacity(0.6))
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
                                        .background(Color.appPrimary)
                                        .cornerRadius(8)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Loading state while determining permission
                        VStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .alert("Nhập tay mã", isPresented: $showManualInput) {
                TextField("Nhập mã thiết bị", text: $manualCode)
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
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            checkCameraPermission()
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
                Image(systemName: "arrow.left")
                    .foregroundColor(.white)
                    .padding()
            }
            
            Text("Quét mã QR / Barcode")
                .font(.headline)
                .foregroundColor(.white)
            
            Spacer()
            
            if hasCameraPermission {
                Button(action: {
                    cameraPosition = (cameraPosition == .back) ? .front : .back
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .foregroundColor(.white)
                        .padding()
                }
                
                Button(action: {
                    isFlashOn.toggle()
                }) {
                    Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                        .foregroundColor(isFlashOn ? .yellow : .white)
                        .padding()
                }
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        guard !isProcessing else { return }
        isProcessing = true
        
        if beepOnScan {
            AudioServicesPlaySystemSound(1052)
        }
        if vibrateOnScan {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        
        onScanResult(code)
        
        // Reset processing after a delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
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
        
        // Remove existing inputs
        captureSession.inputs.forEach { captureSession.removeInput($0) }
        
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        // Only add output if not already added
        if captureSession.outputs.isEmpty {
            let metadataOutput = AVCaptureMetadataOutput()
            if (captureSession.canAddOutput(metadataOutput)) {
                captureSession.addOutput(metadataOutput)
                
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [
                    .qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .dataMatrix, .itf14, .upce
                ]
            }
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            onScanResult?(stringValue)
        }
    }
    
    func updateFlash(isFlashOn: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video),
              device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Torch could not be used")
        }
    }
    
    func updateCameraPosition(position: AVCaptureDevice.Position) {
        guard let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput else { return }
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
                // Dimmed background with clear hole
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
                
                // Viewfinder frame
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                
                // Corners
                ScannerCorners()
                    .stroke(Color.appPrimary, lineWidth: 4)
                    .frame(width: 260, height: 260)
                
                // Scan Line
                if !isProcessing {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color.appPrimary, .white, Color.appPrimary, .clear]),
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
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
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
