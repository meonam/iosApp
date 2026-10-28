import SwiftUI
import AVFoundation
import AudioToolbox

public struct CameraScannerView: UIViewControllerRepresentable {
    public var onBarcodeScanned: (String) -> Void
    public var isTorchOn: Bool
    
    public init(isTorchOn: Bool = false, onBarcodeScanned: @escaping (String) -> Void) {
        self.isTorchOn = isTorchOn
        self.onBarcodeScanned = onBarcodeScanned
    }
    
    public func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    public func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(onBarcodeScanned: onBarcodeScanned)
    }
    
    public class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onBarcodeScanned: (String) -> Void
        private var lastScannedCode = ""
        private var lastScannedTime: Date = Date.distantPast
        
        init(onBarcodeScanned: @escaping (String) -> Void) {
            self.onBarcodeScanned = onBarcodeScanned
        }
        
        public func didScanBarcode(code: String) {
            // Chống quét trùng lặp trong vòng 1.2 giây
            let now = Date()
            if code == lastScannedCode && now.timeIntervalSince(lastScannedTime) < 1.2 {
                return
            }
            lastScannedCode = code
            lastScannedTime = now
            
            // Rung phản hồi & Âm thanh bíp chuẩn quét mã
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            AudioServicesPlaySystemSound(1057) // Mã âm thanh Beep chuẩn iOS
            
            DispatchQueue.main.async {
                self.onBarcodeScanned(code)
            }
        }
    }
}

public protocol ScannerViewControllerDelegate: AnyObject {
    func didScanBarcode(code: String)
}

public class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    public weak var delegate: ScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [
                .ean13, .ean8, .upce, .code128, .code39, .code93, .qr, .itf14, .interleaved2of5
            ]
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    public func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = first.stringValue else { return }
        delegate?.didScanBarcode(code: code)
    }
}
