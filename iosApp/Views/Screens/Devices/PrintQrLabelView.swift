import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

public struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String? // optional
    var onBack: () -> Void

    @State private var selectedDevices = Set<String>()
    @State private var searchQuery: String = ""
    @State private var labelSizeIndex: Int = 0
    let labelSizes = ["50x30 mm", "60x40 mm", "80x50 mm"]
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(viewModel: DeviceViewModel, deviceId: String? = nil, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.deviceId = deviceId
        self.onBack = onBack
    }

    private var devicesToDisplay: [ThietBi] {
        if searchQuery.isEmpty {
            return viewModel.rawDevices
        }
        return viewModel.rawDevices.filter {
            $0.ten.localizedCaseInsensitiveContains(searchQuery) ||
            $0.id.localizedCaseInsensitiveContains(searchQuery) ||
            $0.tenDonVi.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("In tem nhãn QR / Barcode")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // Size picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Khổ tem in:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appPrimary)
                                Picker("Size", selection: $labelSizeIndex) {
                                    ForEach(0..<labelSizes.count, id: \.self) { i in
                                        Text(labelSizes[i]).tag(i)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 14)

                            // Preview Card
                            if let firstSelectedId = selectedDevices.first,
                               let dev = viewModel.rawDevices.first(where: { $0.id == firstSelectedId }) {
                                labelPreviewCard(for: dev)
                            } else if let dev = viewModel.rawDevices.first {
                                labelPreviewCard(for: dev)
                            } else {
                                Text("Chưa có thiết bị nào để in tem")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .padding(20)
                            }
                            
                            // Actions
                            HStack(spacing: 12) {
                                Button(action: printLabels) {
                                    HStack {
                                        Image(systemName: "printer.fill")
                                        Text("In \(selectedDevices.count) tem")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(selectedDevices.isEmpty ? Color.gray : Color.appPrimary)
                                    .cornerRadius(10)
                                }
                                .disabled(selectedDevices.isEmpty)
                                
                                Button(action: shareLabels) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.appPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appPrimary, lineWidth: 1))
                                }
                                .disabled(selectedDevices.isEmpty)
                            }
                            .padding(.horizontal, 14)

                            // Danh sách chọn thiết bị in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Chọn thiết bị cần in tem (\(selectedDevices.count)):")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appPrimary)
                                    Spacer()
                                    Button(action: {
                                        if selectedDevices.count == devicesToDisplay.count {
                                            selectedDevices.removeAll()
                                        } else {
                                            selectedDevices = Set(devicesToDisplay.map { $0.id })
                                        }
                                    }) {
                                        Text(selectedDevices.count == devicesToDisplay.count ? "Bỏ chọn tất cả" : "Chọn tất cả")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appPrimary)
                                    }
                                }

                                // Ô tìm kiếm
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    TextField("Tìm thiết bị...", text: $searchQuery)
                                        .font(.system(size: 13))
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                                VStack(spacing: 8) {
                                    ForEach(devicesToDisplay) { dev in
                                        let isSelected = selectedDevices.contains(dev.id)
                                        Button(action: {
                                            if isSelected {
                                                selectedDevices.remove(dev.id)
                                            } else {
                                                selectedDevices.insert(dev.id)
                                            }
                                        }) {
                                            HStack {
                                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                    .foregroundColor(isSelected ? Color.appPrimary : .gray)
                                                    .font(.system(size: 20))

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(dev.ten)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(.black)
                                                        .lineLimit(1)
                                                    Text("Mã: \(dev.id) • \(dev.tenDonVi)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(isSelected ? Color.appPrimary.opacity(0.1) : Color.white)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimary : Color.gray.opacity(0.3), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 14)

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if viewModel.rawDevices.isEmpty {
                viewModel.fetchDevices()
            }
            if let devId = deviceId {
                selectedDevices.insert(devId)
            }
        }
    }

    private func labelPreviewCard(for dev: ThietBi) -> some View {
        VStack(spacing: 12) {
            Text("XEM TRƯỚC TEM NHÃN IN (\(labelSizes[labelSizeIndex]))")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)

            // Tem in chuẩn preview (SwiftUI representation)
            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAIGON CO.OP")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(Color.appPrimary)
                        Text(dev.ten)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(2)
                        Text("Mã TB: \(dev.id)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text("Đơn vị: \(dev.tenDonVi)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let qrImg = generateQRCode(from: dev.id) {
                        Image(uiImage: qrImg)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                            .border(Color.gray.opacity(0.3), width: 1)
                    }
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
    
    private func getLabelSizeInPoints() -> CGSize {
        // 1 mm ≈ 2.83465 points
        switch labelSizeIndex {
        case 0: return CGSize(width: 141.7, height: 85.0)  // 50x30
        case 1: return CGSize(width: 170.0, height: 113.4) // 60x40
        case 2: return CGSize(width: 226.8, height: 141.7) // 80x50
        default: return CGSize(width: 141.7, height: 85.0)
        }
    }
    
    private func generateImagesForSelected() -> [UIImage] {
        let size = getLabelSizeInPoints()
        var images = [UIImage]()
        
        for id in selectedDevices {
            if let dev = viewModel.rawDevices.first(where: { $0.id == id }) {
                images.append(drawLabel(dev: dev, size: size))
            }
        }
        return images
    }
    
    private func drawLabel(dev: ThietBi, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // White background
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            let margin: CGFloat = 8
            let qrSize: CGFloat = size.height - margin * 2
            
            // Draw QR
            if let qr = generateQRCode(from: dev.id) {
                qr.draw(in: CGRect(x: size.width - margin - qrSize, y: margin, width: qrSize, height: qrSize))
            }
            
            // Draw text
            let textWidth = size.width - qrSize - margin * 3
            var y: CGFloat = margin
            
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.black]
            "SAIGON CO.OP".draw(in: CGRect(x: margin, y: y, width: textWidth, height: 16), withAttributes: titleAttrs)
            y += 16
            
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor.black]
            let nameRect = CGRect(x: margin, y: y, width: textWidth, height: 28)
            dev.ten.draw(in: nameRect, withAttributes: nameAttrs)
            y += 28
            
            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]
            "Mã TB: \(dev.id)".draw(in: CGRect(x: margin, y: y, width: textWidth, height: 12), withAttributes: smallAttrs)
            y += 12
            
            "Đơn vị: \(dev.tenDonVi)".draw(in: CGRect(x: margin, y: y, width: textWidth, height: 12), withAttributes: smallAttrs)
        }
    }
    
    private func printLabels() {
        let images = generateImagesForSelected()
        if images.isEmpty { return }
        
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .photo
        printInfo.jobName = "Print QR Labels"
        
        let printInteraction = UIPrintInteractionController.shared
        printInteraction.printInfo = printInfo
        
        if images.count == 1 {
            printInteraction.printingItem = images.first
        } else {
            printInteraction.printingItems = images
        }
        
        printInteraction.present(animated: true, completionHandler: nil)
    }
    
    private func shareLabels() {
        let images = generateImagesForSelected()
        if images.isEmpty { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let activityVC = UIActivityViewController(activityItems: images, applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = window
            popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootVC.present(activityVC, animated: true, completion: nil)
    }
}
