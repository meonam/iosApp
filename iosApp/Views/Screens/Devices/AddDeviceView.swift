import SwiftUI
import CoreImage.CIFilterBuiltins

public struct AddDeviceView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var onBack: () -> Void
    var onSuccess: ((String) -> Void)?

    @State private var serialNumber: String = ""
    @State private var tenThietBi: String = ""
    @State private var loaiThietBi: String = ""
    @State private var phongBanId: String = ""
    @State private var nguoiDungId: String = ""
    @State private var trangThai: String = "ACTIVE"
    @State private var moTa: String = ""
    @State private var ngayMua: Date = Date()
    @State private var ngayHetBaoHanh: Date = Date().addingTimeInterval(365 * 24 * 3600)
    @State private var giaTriTaiSan: String = ""
    
    @State private var deviceTypes: [String] = ["Laptop", "Máy tính để bàn (PC)", "Máy in", "Màn hình", "Khác"]
    
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showQRModal: Bool = false
    @State private var generatedQRImage: UIImage? = nil

    private let statusOptions = ["ACTIVE", "MAINTENANCE", "BROKEN", "RETIRED"]

    public init(viewModel: DeviceViewModel, onBack: @escaping () -> Void, onSuccess: ((String) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onSuccess = onSuccess
    }

    public init(viewModel: DeviceViewModel, onDismiss: @escaping () -> Void, onSuccess: ((String) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onBack = onDismiss
        self.onSuccess = onSuccess
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.backward")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Text("Thêm thiết bị mới")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .frame(height: 56)
                    }
                    .background(Color.appPrimary)
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            formFields()
                            
                            if let err = errorMessage {
                                Text(err)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: submitDevice) {
                                HStack {
                                    if isSubmitting {
                                        ProgressView().colorInvert()
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Lưu thiết bị")
                                    }
                                }
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.appPrimary)
                                .cornerRadius(12)
                            }
                            .disabled(isSubmitting)
                            .padding(.top, 8)
                        }
                        .padding(16)
                    }
                }
            }
            .overlay(
                Group {
                    if showQRModal {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        qrModalView()
                    }
                }
            )
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            phongBanId = viewModel.user.departmentId
            if loaiThietBi.isEmpty, let first = deviceTypes.first {
                loaiThietBi = first
            }
        }
    }

    @ViewBuilder
    private func formFields() -> some View {
        VStack(spacing: 16) {
            inputField(title: "Số serial / Mã tài sản *", text: $serialNumber, placeholder: "Nhập mã SN hoặc Asset Tag")
            inputField(title: "Tên thiết bị *", text: $tenThietBi, placeholder: "Ví dụ: Dell Latitude 5420")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Loại thiết bị").font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
                Picker("Loại thiết bị", selection: $loaiThietBi) {
                    ForEach(deviceTypes, id: \.self) { t in Text(t).tag(t) }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            
            inputField(title: "Phòng ban quản lý", text: $phongBanId, placeholder: "Nhập ID phòng ban")
            inputField(title: "Người dùng hiện tại", text: $nguoiDungId, placeholder: "Nhập ID người dùng (Tùy chọn)")
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Trạng thái thiết bị").font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
                Picker("Trạng thái", selection: $trangThai) {
                    ForEach(statusOptions, id: \.self) { opt in Text(opt).tag(opt) }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Mô tả / Thông số kỹ thuật").font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
                TextEditor(text: $moTa)
                    .frame(height: 80).padding(8).background(Color.white).cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                DatePicker("Ngày mua", selection: $ngayMua, displayedComponents: .date)
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
                DatePicker("Ngày hết hạn BH", selection: $ngayHetBaoHanh, displayedComponents: .date)
                    .font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
            }
            .padding(12).background(Color.white).cornerRadius(10)
            
            inputField(title: "Giá trị tài sản (VNĐ)", text: $giaTriTaiSan, placeholder: "Ví dụ: 15000000")
                .keyboardType(.numberPad)
        }
    }

    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Color.appTextPrimary)
            TextField(placeholder, text: text)
                .padding(12).background(Color.white).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }

    private func submitDevice() {
        let cleanSerial = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTen = tenThietBi.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !cleanSerial.isEmpty else { errorMessage = "Vui lòng nhập Số serial!"; return }
        guard !cleanTen.isEmpty else { errorMessage = "Vui lòng nhập Tên thiết bị!"; return }

        isSubmitting = true
        errorMessage = nil

        let isoFormatter = ISO8601DateFormatter()
        
        var fields: [String: Any] = [
            "tenThietBi": ["stringValue": cleanTen],
            "ten": ["stringValue": cleanTen], // For backward compat if some fields require 'ten'
            "serialNumber": ["stringValue": cleanSerial],
            "loaiThietBi": ["stringValue": loaiThietBi],
            "phongBanId": ["stringValue": phongBanId],
            "nguoiDungId": ["stringValue": nguoiDungId],
            "trangThai": ["stringValue": trangThai],
            "mota": ["stringValue": moTa],
            "ngayMua": ["stringValue": isoFormatter.string(from: ngayMua)],
            "ngayHetBaoHanh": ["stringValue": isoFormatter.string(from: ngayHetBaoHanh)],
            "createdAt": ["integerValue": "\(Int64(Date().timeIntervalSince1970 * 1000))"],
            "companyId": ["stringValue": viewModel.companyId],
            "createdBy": ["stringValue": viewModel.user.email]
        ]
        
        if let val = Double(giaTriTaiSan) {
            fields["giaTriTaiSan"] = ["doubleValue": val]
        }

        viewModel.addDevice(documentId: cleanSerial, fields: fields) { result in
            self.isSubmitting = false
            switch result {
            case .success(_):
                self.generatedQRImage = generateQRCode(from: cleanSerial)
                self.showQRModal = true
            case .failure(let error):
                self.errorMessage = "Lỗi: \(error.localizedDescription)"
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        if let output = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaled = output.transformed(by: transform)
            if let cgimg = context.createCGImage(scaled, from: scaled.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }

    @ViewBuilder
    private func qrModalView() -> some View {
        VStack(spacing: 20) {
            Text("Thêm thiết bị thành công!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.appPrimary)
            
            if let img = generatedQRImage {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            
            Text("Serial: \(serialNumber)")
                .font(.system(size: 16, weight: .medium))
            
            Button(action: {
                showQRModal = false
                onSuccess?(serialNumber)
                onBack()
            }) {
                Text("Hoàn tất")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appPrimary)
                    .cornerRadius(12)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .padding(32)
    }
}
