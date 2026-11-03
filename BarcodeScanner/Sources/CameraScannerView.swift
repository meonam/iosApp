import SwiftUI
import AVFoundation
import AudioToolbox
import UIKit

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
    private var permissionNoticeView: UIView?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkCameraPermissionAndSetup()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSessionIfPossible()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSessionIfRunning()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        permissionNoticeView?.frame = view.bounds
    }
    
    // MARK: - Kiểm tra quyền Camera & Khởi tạo
    
    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionNotice(isDenied: true)
                    }
                }
            }
        case .denied, .restricted:
            showPermissionNotice(isDenied: true)
        @unknown default:
            showPermissionNotice(isDenied: true)
        }
    }
    
    private func setupCamera() {
        permissionNoticeView?.removeFromSuperview()
        permissionNoticeView = nil
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            // Trường hợp chạy trên iOS Simulator không có camera phần cứng
            showPermissionNotice(isDenied: false, customMessage: "Máy ảo / Simulator không có camera phần cứng.\nVui lòng nhập mã thủ công trên giao diện.")
            return
        }
        
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            showPermissionNotice(isDenied: true)
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            // Các loại mã quét được hỗ trợ
            let desiredTypes: [AVMetadataObject.ObjectType] = [
                .qr, .ean13, .ean8, .upce, .code128, .code39, .code93, .itf14, .interleaved2of5, .pdf417, .aztec, .dataMatrix
            ]
            let available = output.availableMetadataObjectTypes
            output.metadataObjectTypes = desiredTypes.filter { available.contains($0) }
        }
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        
        self.previewLayer = preview
        self.captureSession = session
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func startSessionIfPossible() {
        guard let session = captureSession, !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    private func stopSessionIfRunning() {
        guard let session = captureSession, session.isRunning else { return }
        session.stopRunning()
    }
    
    public func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            print("Lỗi bật/tắt đèn Flash: \(error)")
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = first.stringValue, !code.isEmpty else { return }
        delegate?.didScanBarcode(code: code)
    }
    
    // MARK: - Giao diện thông báo khi chưa có quyền Camera hoặc Máy ảo
    
    private func showPermissionNotice(isDenied: Bool, customMessage: String? = nil) {
        permissionNoticeView?.removeFromSuperview()
        
        let container = UIView(frame: view.bounds)
        container.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: isDenied ? "camera.badge.ellipsis" : "camera.metering.unknown")
        iconView.tintColor = .systemOrange
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.heightAnchor.constraint(equalToConstant: 50).isActive = true
        iconView.widthAnchor.constraint(equalToConstant: 50).isActive = true
        stack.addArrangedSubview(iconView)
        
        let label = UILabel()
        label.text = customMessage ?? "Ứng dụng cần quyền Camera để quét mã vạch và QR UID máy tính.\nVui lòng cấp quyền trong Cài đặt của máy."
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        stack.addArrangedSubview(label)
        
        if isDenied {
            let btn = UIButton(type: .system)
            btn.setTitle("Mở Cài đặt hệ thống", for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = .systemBlue
            btn.layer.cornerRadius = 8
            btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            btn.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }
        
        view.addSubview(container)
        self.permissionNoticeView = container
    }
    
    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
