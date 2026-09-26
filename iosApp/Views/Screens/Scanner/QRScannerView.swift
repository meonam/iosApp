import SwiftUI
import AVFoundation

// MARK: - MÀN HÌNH QUÉT MÃ QR / BARCODE (ĐỒNG BỘ 1:1 THEO SCANNER TRÊN ANDROID)
public struct QRScannerView: View {
    var onScanResult: (String) -> Void
    var onDismiss: () -> Void

    @State private var manualInput: String = ""
    @State private var isFlashOn: Bool = false
    @State private var hasPermission: Bool = true
    @State private var scannedCode: String? = nil

    public init(
        onScanResult: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onScanResult = onScanResult
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // TopBar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("Quét mã QR / Barcode")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: toggleFlash) {
                        Image(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isFlashOn ? .yellow : .white)
                            .padding(10)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                // Khung ngắm quét mã
                VStack(spacing: 16) {
                    ZStack {
                        // Khung vuông có 4 góc bo
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.appPrimaryPink, lineWidth: 3)
                            .frame(width: 250, height: 250)
                            .background(Color.black.opacity(0.2))

                        // Tia laser đỏ chuyển động
                        Rectangle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 230, height: 2)
                    }

                    Text("Hướng camera về phía mã QR hoặc Barcode trên thiết bị")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                Spacer()

                // Ô nhập mã thủ công
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Hoặc nhập mã thiết bị thủ công...", text: $manualInput)
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .foregroundColor(.black)

                        Button(action: {
                            let clean = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !clean.isEmpty {
                                onScanResult(clean)
                                onDismiss()
                            }
                        }) {
                            Text("Tìm")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.appPrimaryPink)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
            }
        }
    }

    private func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            device.unlockForConfiguration()
            isFlashOn.toggle()
        } catch {
            isFlashOn.toggle()
        }
    }
}
