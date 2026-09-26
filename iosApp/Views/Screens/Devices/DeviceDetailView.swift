import SwiftUI
import CoreImage.CIFilterBuiltins

public struct DeviceDetailView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var deviceId: String
    var onBack: () -> Void

    @State private var device: ThietBi?
    @State private var showDeleteConfirmAlert = false
    @State private var isLoading = false
    
    // CoreImage context for QR code
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
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
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
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView("Đang tải dữ liệu...")
                                    .padding(.top, 40)
                            } else if let dev = device {
                                // QR Code Section
                                VStack(spacing: 8) {
                                    if let qrImage = generateQRCode(from: dev.id) {
                                        Image(uiImage: qrImage)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 150, height: 150)
                                            .background(Color.white)
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    }
                                    Text(dev.id)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)
                                }
                                .padding(.top, 20)
                                
                                // Details Section
                                VStack(spacing: 0) {
                                    detailRow(label: "Tên thiết bị", value: dev.ten)
                                    Divider().padding(.leading, 16)
                                    detailRow(label: "Đơn vị", value: dev.tenDonVi)
                                    if let pb = dev.phongBan, !pb.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Phòng ban", value: pb)
                                    }
                                    Divider().padding(.leading, 16)
                                    
                                    HStack {
                                        Text("Trạng thái")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.appTextSecondary)
                                        Spacer()
                                        Text(dev.statusNormalized)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(dev.statusColor)
                                            .padding(.horizontal, 8)
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
                                    if let moTa = dev.moTa, !moTa.isEmpty {
                                        Divider().padding(.leading, 16)
                                        detailRow(label: "Ghi chú", value: moTa)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                                .padding(.horizontal, 16)
                                .padding(.top, 10)
                                
                                // Actions Section
                                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                                    Button(action: {
                                        showDeleteConfirmAlert = true
                                    }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Xóa thiết bị")
                                        }
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.appDanger)
                                        .cornerRadius(12)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                                }
                            } else {
                                Text("Không tìm thấy thiết bị")
                                    .foregroundColor(.red)
                                    .padding(.top, 40)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear {
            loadDeviceDetails()
        }
        .alert(isPresented: $showDeleteConfirmAlert) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có chắc chắn muốn xóa thiết bị này không?"),
                primaryButton: .destructive(Text("Xóa")) {
                    viewModel.deleteDevice(deviceId: deviceId)
                    onBack()
                },
                secondaryButton: .cancel()
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
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func loadDeviceDetails() {
        // Try finding from cached devices first
        if let cached = viewModel.rawDevices.first(where: { $0.id == deviceId }) {
            self.device = cached
            return
        }
        
        // Otherwise try fetching (REST API)
        isLoading = true
        let companyId = viewModel.user.companyId
        
        // Construct the URL Session REST API request
        guard let url = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/projects/\(FirebaseConfig.projectId)/databases/(default)/documents/companies/\(companyId)/devices/\(deviceId)") else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else {
                    return
                }
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let fields = json["fields"] as? [String: Any] {
                        
                        let thietBi = ThietBi(
                            id: self.deviceId,
                            ten: FirestoreHelper.getString(fields["ten"] as? [String: Any]),
                            tenDonVi: FirestoreHelper.getString(fields["tenDonVi"] as? [String: Any]),
                            trangThai: FirestoreHelper.getString(fields["trangThai"] as? [String: Any]),
                            createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                            loai: FirestoreHelper.getString(fields["loai"] as? [String: Any]),
                            phongBan: FirestoreHelper.getString(fields["phongBan"] as? [String: Any]),
                            moTa: FirestoreHelper.getString(fields["moTa"] as? [String: Any]),
                            createdBy: FirestoreHelper.getString(fields["createdBy"] as? [String: Any]),
                            companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
                            donViMuon: FirestoreHelper.getString(fields["donViMuon"] as? [String: Any]),
                            phongBanMuon: FirestoreHelper.getString(fields["phongBanMuon"] as? [String: Any]),
                            nguoiMuon: FirestoreHelper.getString(fields["nguoiMuon"] as? [String: Any]),
                            ngayMuon: FirestoreHelper.getString(fields["ngayMuon"] as? [String: Any]),
                            ngayHenTra: FirestoreHelper.getString(fields["ngayHenTra"] as? [String: Any])
                        )
                        self.device = thietBi
                    }
                } catch {
                    print("Error parsing device detail: \(error)")
                }
            }
        }.resume()
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            // Scale up the image
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgimg = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
}
