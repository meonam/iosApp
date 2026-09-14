import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

public enum BarcodeQrGenerator {
    private static let context = CIContext()

    // MARK: - Tạo Mã QR (Native CoreImage CIQRCodeGenerator)
    public static func generateQRCode(from string: String, size: CGFloat = 300) -> UIImage? {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up crisply without blurring
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    // MARK: - Tạo Mã Vạch Code 128 (Native CoreImage CICode128BarcodeGenerator)
    public static func generateBarcode(from string: String, width: CGFloat = 400, height: CGFloat = 120) -> UIImage? {
        guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(7.0, forKey: "inputQuietSpace")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = width / outputImage.extent.size.width
        let scaleY = height / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
