import SwiftUI

// MARK: - MÀN HÌNH THÊM THIẾT BỊ MỚI (ĐỒNG BỘ 1:1 THEO ANDROID ADD_DEVICE)
public struct AddDeviceView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var onDismiss: () -> Void
    var onSuccess: () -> Void

    @State private var ten: String = ""
    @State private var loai: String = "Laptop"
    @State private var tenDonVi: String = "Văn phòng Tổng Công ty"
    @State private var phongBan: String = "Phòng CNTT"
    @State private var trangThai: String = "IN_USE"
    @State private var moTa: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    private let deviceTypes = [
        "Laptop", "Máy tính để bàn (PC)", "Máy in laser", "Máy in nhiệt",
        "Máy quét Barcode", "Thiết bị mạng (Router/Switch)", "Màn hình (Monitor)", "Khác"
    ]

    private let statusOptions = [
        ("IN_USE", "Đang sử dụng"),
        ("IN_STOCK", "Trong kho (Sẵn sàng)"),
        ("REPAIR", "Đang sửa chữa / Bảo hành"),
        ("ON_LOAN", "Đang cho mượn")
    ]

    public init(
        viewModel: DeviceViewModel,
        onDismiss: @escaping () -> Void,
        onSuccess: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        self.onSuccess = onSuccess
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Tên thiết bị
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tên thiết bị *")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            TextField("Ví dụ: Dell Latitude 5420 i7 / 16GB", text: $ten)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Loại thiết bị
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phân loại thiết bị")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            Picker("Loại", selection: $loai) {
                                ForEach(deviceTypes, id: \.self) { t in
                                    Text(t).tag(t)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Đơn vị
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Đơn vị sở hữu")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            TextField("Đơn vị / Chi nhánh", text: $tenDonVi)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Phòng ban
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phòng ban quản lý")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            TextField("Ví dụ: Phòng CNTT, Kho, Kế toán", text: $phongBan)
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        // Trạng thái
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Trạng thái thiết bị")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            Picker("Trạng thái", selection: $trangThai) {
                                ForEach(statusOptions, id: \.0) { opt in
                                    Text(opt.1).tag(opt.0)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }

                        // Mô tả chi tiết
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Mô tả / Thông số kỹ thuật")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)

                            TextEditor(text: $moTa)
                                .frame(height: 80)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }

                        // Nút thêm thiết bị
                        Button(action: submitDevice) {
                            HStack {
                                if isSubmitting {
                                    ProgressView().colorInvert()
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Lưu thiết bị")
                                }
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(12)
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Thêm thiết bị mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                }
            }
        }
    }

    private func submitDevice() {
        let cleanTen = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTen.isEmpty else {
            errorMessage = "Vui lòng nhập tên thiết bị!"
            return
        }

        isSubmitting = true
        errorMessage = nil

        let newDev = ThietBi(
            id: UUID().uuidString,
            ten: cleanTen,
            tenDonVi: tenDonVi,
            trangThai: trangThai,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000),
            role: "STAFF",
            loai: loai,
            phongBan: phongBan,
            moTa: moTa,
            createdBy: viewModel.user.email,
            companyId: viewModel.companyId
        )

        Task {
            do {
                try await viewModel.createDevice(device: newDev)
                self.isSubmitting = false
                self.onSuccess()
                self.onDismiss()
            } catch {
                self.isSubmitting = false
                self.errorMessage = "Lỗi: \(error.localizedDescription)"
            }
        }
    }
}
