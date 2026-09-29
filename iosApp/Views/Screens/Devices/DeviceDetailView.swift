import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - MÀN HÌNH CHI TIẾT THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI DEVICESCREEN.KT TRÊN ANDROID)
public struct DeviceDetailView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String
    var onBack: () -> Void

    @State private var device: ThietBi?
    @State private var showDeleteConfirmAlert = false
    @State private var showHistoryCover = false
    @State private var showCreateTicketSheet = false
    @State private var showShareSheet = false
    @State private var qrShareImage: UIImage? = nil
    @State private var isLoading = false

    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    public init(viewModel: DeviceViewModel, deviceId: String, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.deviceId = deviceId
        self.onBack = onBack
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
                            Text("Chi tiết thiết bị")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()

                            Button(action: { showHistoryCover = true }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView("Đang tải dữ liệu...")
                                    .padding(.top, 40)
                            } else if let dev = device {
                                // 1. QR Code Section
                                VStack(spacing: 8) {
                                    if let qrImage = generateQRCode(from: dev.id) {
                                        Image(uiImage: qrImage)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 140, height: 140)
                                            .background(Color.white)
                                            .cornerRadius(10)
                                            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "qrcode")
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                        Text(dev.id)
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                    }
                                }
                                .padding(.top, 16)

                                // 2. Details Card
                                VStack(spacing: 0) {
                                    detailRow(label: "Tên thiết bị", value: dev.ten)
                                    Divider().padding(.leading, 16)
                                    detailRow(label: "Đơn vị", value: dev.tenDonVi)
                                    if let pb = dev.phongBan, !pb.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Phòng ban", value: pb)
                                    }
                                    Divider().padding(.leading, 16)

                                    // Trạng thái Badge
                                    HStack {
                                        Text("Trạng thái")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text(dev.statusNormalized)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(dev.statusColor)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(dev.statusColor.opacity(0.12))
                                            .cornerRadius(8)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if let loai = dev.loai, !loai.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Loại thiết bị", value: loai)
                                    }

                                    // THÔNG TIN MƯỢN (NẾU CÓ)
                                    if let dvm = dev.donViMuon, !dvm.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Đơn vị mượn", value: dvm)
                                    }
                                    if let pbm = dev.phongBanMuon, !pbm.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Phòng ban mượn", value: pbm)
                                    }
                                    if let nm = dev.nguoiMuon, !nm.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Người mượn", value: nm)
                                    }
                                    if let nht = dev.ngayHenTra, !nht.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Ngày hẹn trả", value: nht)
                                    }
                                    if let nm = dev.ngayMuon, !nm.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Ngày mượn", value: nm)
                                    }

                                    if let moTa = dev.moTa, !moTa.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Ghi chú", value: moTa)
                                    }
                                }
                                .background(Color.appSurface)
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                                .padding(.horizontal, 16)

                                // 3. Action Buttons
                                VStack(spacing: 10) {
                                    // 🚨 BÁO HỎNG / TẠO YÊU CẦU HỖ TRỢ (ĐỒNG BỘ 100% VỚI ANDROID)
                                    Button(action: { showCreateTicketSheet = true }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                            Text("🚨 Báo hỏng / Tạo yêu cầu hỗ trợ")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 46)
                                        .background(Color.appPrimaryPink)
                                        .cornerRadius(12)
                                    }

                                    // 🖨️ IN TEM / CHIA SẺ MÃ QR
                                    Button(action: {
                                        if let qr = generateQRCode(from: dev.id) {
                                            self.qrShareImage = qr
                                            self.showShareSheet = true
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "printer.fill")
                                            Text("🖨️ In tem / Chia sẻ mã QR")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 46)
                                        .background(Color.appSecondaryDarkBlue.opacity(0.12))
                                        .cornerRadius(12)
                                    }

                                    // XEM NHẬT KÝ LỊCH SỬ
                                    Button(action: { showHistoryCover = true }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "clock.arrow.circlepath")
                                            Text("Xem nhật ký lịch sử")
                                        }
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "#475569"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 46)
                                        .background(Color(hex: "#F1F5F9"))
                                        .cornerRadius(12)
                                    }

                                    if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                                        Button(action: { showDeleteConfirmAlert = true }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "trash")
                                                Text("Xóa thiết bị")
                                            }
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 46)
                                            .background(Color.appDanger)
                                            .cornerRadius(12)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 6)

                            } else {
                                Text("Không tìm thấy thông tin thiết bị")
                                    .foregroundColor(Color.appDanger)
                                    .padding(.top, 40)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadDeviceDetails()
        }
        .sheet(isPresented: $showCreateTicketSheet) {
            if let dev = device {
                CreateTicketSheetView(
                    supportVM: SupportViewModel(user: viewModel.user, companyId: viewModel.companyId, idToken: viewModel.idToken),
                    initialAssetId: dev.id,
                    initialAssetName: dev.ten,
                    initialCategory: "HARDWARE",
                    onSuccess: {
                        showCreateTicketSheet = false
                    },
                    onCancel: {
                        showCreateTicketSheet = false
                    }
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let img = qrShareImage {
                DeviceActivityViewController(activityItems: [img, "Mã thiết bị: \(deviceId)"])
            }
        }
        .fullScreenCover(isPresented: $showHistoryCover) {
            LichSuView(companyId: viewModel.companyId, idToken: viewModel.idToken, thietBiId: deviceId, onBack: { showHistoryCover = false })
        }
        .alert(isPresented: $showDeleteConfirmAlert) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có chắc chắn muốn xóa thiết bị này khỏi hệ thống không?"),
                primaryButton: .destructive(Text("Xóa")) {
                    viewModel.deleteDevice(deviceId: deviceId)
                    onBack()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadDeviceDetails() {
        if let cached = viewModel.rawDevices.first(where: { $0.id.caseInsensitiveCompare(deviceId) == .orderedSame }) {
            self.device = cached
            return
        }

        isLoading = true
        Task {
            if let dev = await viewModel.getDeviceById(deviceId) {
                self.device = dev
            }
            self.isLoading = false
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgimg = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}

// MARK: - ActivityViewController for Sharing QR Code
struct DeviceActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<DeviceActivityViewController>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<DeviceActivityViewController>) {}
}
