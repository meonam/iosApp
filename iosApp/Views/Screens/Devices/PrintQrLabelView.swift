import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

// MARK: - MÀN HÌNH IN TEM NHÃN QR / BARCODE (ĐỒNG BỘ 1:1 VỚI PRINTSCREEN.KT TRÊN ANDROID)
public struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String?
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
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
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
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            // Size picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Khổ tem in:")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
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
                                    .frame(height: 46)
                                    .background(selectedDevices.isEmpty ? Color.gray : Color.appPrimaryPink)
                                    .cornerRadius(12)
                                }
                                .disabled(selectedDevices.isEmpty)

                                Button(action: shareLabels) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.appPrimaryPink)
                                        .frame(width: 46, height: 46)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink, lineWidth: 1.5))
                                }
                                .disabled(selectedDevices.isEmpty)
                            }
                            .padding(.horizontal, 14)

                            // Danh sách chọn thiết bị in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Chọn thiết bị cần in tem (\(selectedDevices.count)):")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Spacer()
                                    Button(action: {
                                        if selectedDevices.count == devicesToDisplay.count {
                                            selectedDevices.removeAll()
                                        } else {
                                            selectedDevices = Set(devicesToDisplay.map { $0.id })
                                        }
                                    }) {
                                        Text(selectedDevices.count == devicesToDisplay.count ? "Bỏ chọn tất cả" : "Chọn tất cả")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color.appPrimaryPink)
                                    }
                                }

                                // Ô tìm kiếm
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(Color.appTextSecondary)
                                    TextField("Tìm thiết bị theo tên, mã, đơn vị...", text: $searchQuery)
                                        .font(.system(size: 13))
                                    if !searchQuery.isEmpty {
                                        Button(action: { searchQuery = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(Color.appTextSecondary)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

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
                                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(isSelected ? Color.appPrimaryPink : .gray)
                                                    .font(.system(size: 20))

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(dev.ten)
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(Color.appTextPrimary)
                                                        .lineLimit(1)
                                                    Text("Mã: \(dev.id) • \(dev.tenDonVi)")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Color.appTextSecondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .padding(12)
                                            .background(isSelected ? Color.appPrimaryPink.opacity(0.06) : Color.white)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: isSelected ? 1.5 : 1))
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
                .foregroundColor(Color.appTextSecondary)

            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("HỆ THỐNG QLTB")
                            .font(.system(size: 12, weight: .black))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text(dev.ten)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                            .lineLimit(2)
                        Text("Mã TB: \(dev.id)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("Đơn vị: \(dev.tenDonVi)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
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
        switch labelSizeIndex {
        case 0: return CGSize(width: 141.7, height: 85.0)  // 50x30 mm
        case 1: return CGSize(width: 170.0, height: 113.4) // 60x40 mm
        case 2: return CGSize(width: 226.8, height: 141.7) // 80x50 mm
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
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let margin: CGFloat = 8
            let qrSize: CGFloat = size.height - margin * 2

            if let qr = generateQRCode(from: dev.id) {
                qr.draw(in: CGRect(x: size.width - margin - qrSize, y: margin, width: qrSize, height: qrSize))
            }

            let textWidth = size.width - qrSize - margin * 3
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 11), .foregroundColor: UIColor(red: 0, green: 42/255, blue: 143/255, alpha: 1)]
            "HỆ THỐNG QLTB".draw(in: CGRect(x: margin, y: y, width: textWidth, height: 15), withAttributes: titleAttrs)
            y += 15

            let nameAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.black]
            let nameRect = CGRect(x: margin, y: y, width: textWidth, height: 26)
            dev.ten.draw(in: nameRect, withAttributes: nameAttrs)
            y += 26

            let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray]
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
