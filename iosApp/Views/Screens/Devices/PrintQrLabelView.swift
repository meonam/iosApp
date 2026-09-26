import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - MÀN HÌNH IN TEM MÃ QR / BARCODE (ĐỒNG BỘ 1:1 THEO PRINTSCREEN TRÊN ANDROID)
public struct PrintQrLabelView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var onBack: () -> Void

    @State private var selectedDevice: ThietBi? = nil
    @State private var searchQuery: String = ""
    @State private var printCopies: Int = 1
    @State private var showPrintSuccess: Bool = false

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(viewModel: DeviceViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
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
                    // TopBar tràn tai thỏ với Safe Area
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
                    .background(Color.appTopBarColor)

                // Nội dung
                ScrollView {
                    VStack(spacing: 16) {
                        // Khung xem trước tem in (Label Preview)
                        if let dev = selectedDevice ?? viewModel.rawDevices.first {
                            labelPreviewCard(for: dev)
                        } else {
                            Text("Chưa có thiết bị nào để in tem")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                                .padding(20)
                        }

                        // Danh sách chọn thiết bị in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Chọn thiết bị cần in tem:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            // Ô tìm kiếm
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.appTextSecondary)
                                TextField("Tìm thiết bị...", text: $searchQuery)
                                    .font(.system(size: 13))
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                            VStack(spacing: 8) {
                                ForEach(devicesToDisplay) { dev in
                                    let isSelected = selectedDevice?.id == dev.id || (selectedDevice == nil && dev.id == viewModel.rawDevices.first?.id)
                                    Button(action: { selectedDevice = dev }) {
                                        HStack {
                                            Image(systemName: "qrcode")
                                                .font(.system(size: 20))
                                                .foregroundColor(isSelected ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)

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

                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(Color.appPrimaryPink)
                                            }
                                        }
                                        .padding(12)
                                        .background(isSelected ? Color.appPrimaryPinkContainer.opacity(0.3) : Color.white)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(14)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.rawDevices.isEmpty {
                viewModel.fetchDevices()
            }
        }
        .alert(isPresented: $showPrintSuccess) {
            Alert(
                title: Text("Đã gửi lệnh in tem!"),
                message: Text("Tem mã QR của thiết bị đã được gửi tới máy in nhiệt."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - TEM XEM TRƯỚC
    private func labelPreviewCard(for dev: ThietBi) -> some View {
        VStack(spacing: 12) {
            Text("XEM TRƯỚC TEM NHÃN IN (50 x 30 mm)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color.appTextSecondary)

            // Tem in chuẩn
            VStack(spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SAIGON CO.OP")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        Text(dev.ten)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(2)

                        Text("Mã TB: \(dev.id)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.gray)

                        Text("Đơn vị: \(dev.tenDonVi)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Mã QR tạo tự động
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

            // Nút in tem
            Button(action: {
                showPrintSuccess = true
            }) {
                HStack {
                    Image(systemName: "printer.fill")
                    Text("In tem nhãn này")
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.appPrimaryPink)
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // Tiện ích tạo ảnh QR Code
    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
