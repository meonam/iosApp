import SwiftUI
import UIKit

// MARK: - MÀN HÌNH THÊM THIẾT BỊ MỚI CHUYÊN SÂU (Khớp 100% Android AddDeviceScreen.kt)
public struct AddDeviceFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    // Device Form State
    @State private var code: String = ""
    @State private var name: String = ""
    @State private var category: String = "POS"
    @State private var brand: String = "Bixolon"
    @State private var model: String = ""
    @State private var serialNumber: String = ""
    @State private var status: String = "Mới"
    @State private var selectedUnit: String = "Co.opmart Cần Thơ"
    @State private var department: String = "Quầy thu ngân 01"
    @State private var priceStr: String = "12500000"
    @State private var warrantyMonths: Int = 24
    @State private var note: String = ""

    // Media & Cloudinary Image Upload
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker: Bool = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var uploadedImageUrl: String = ""
    @State private var isUploadingImage: Bool = false

    // Scanner
    @State private var showScannerModal: Bool = false
    @State private var isScanningForCode: Bool = true // true = code, false = serial

    // Submission State
    @State private var isSubmitting: Bool = false
    @State private var alertMessage: String? = nil

    let categories = [
        "POS", "Máy in bill", "Máy quét mã vạch", "Cân điện tử",
        "Máy tính quầy", "Switch mạng", "Server", "Bộ lưu điện UPS", "Router Wifi", "Thiết bị khác"
    ]

    let brands = ["Bixolon", "HP", "Dell", "Zebra", "Honeywell", "Datalogic", "Sunmi", "Casio", "Cisco", "TP-Link", "Khác"]
    let statusOptions = ["Mới", "Đang sử dụng", "Sửa chữa", "Hỏng"]

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationView {
            Form {
                // Section 1: Thông tin định danh & Quét mã
                Section(header: Text("ĐỊNH DANH THIẾT BỊ")) {
                    HStack {
                        TextField("Mã thiết bị (VD: POS-01-CT)", text: $code)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .autocapitalization(.allCharacters)

                        Button(action: {
                            isScanningForCode = true
                            showScannerModal = true
                        }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(.appSecondaryDarkBlue)
                        }
                    }

                    TextField("Tên thiết bị (VD: Máy in hóa đơn SRP-330II)", text: $name)

                    HStack {
                        TextField("Số Serial (SN)", text: $serialNumber)
                            .font(.system(size: 13, design: .monospaced))

                        Button(action: {
                            isScanningForCode = false
                            showScannerModal = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 20))
                                .foregroundColor(.appSecondaryDarkBlue)
                        }
                    }
                }

                // Section 2: Chủng loại & Xuất xứ
                Section(header: Text("CHỦNG LOẠI & THÔNG SỐ KỸ THUẬT")) {
                    Picker("Loại thiết bị", selection: $category) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    Picker("Hãng sản xuất", selection: $brand) {
                        ForEach(brands, id: \.self) { b in
                            Text(b).tag(b)
                        }
                    }

                    TextField("Model / Ký hiệu (VD: SRP-330II COPES)", text: $model)

                    Picker("Trạng thái", selection: $status) {
                        ForEach(statusOptions, id: \.self) { st in
                            Text(st).tag(st)
                        }
                    }

                    Stepper("Bảo hành: \(warrantyMonths) tháng", value: $warrantyMonths, in: 0...60, step: 6)

                    TextField("Nguyên giá (VNĐ)", text: $priceStr)
                        .keyboardType(.numberPad)
                }

                // Section 3: Đơn vị & Vị trí quầy
                Section(header: Text("ĐƠN VỊ & VỊ TRÍ LẮP ĐẶT")) {
                    Picker("Đơn vị Co.opmart", selection: $selectedUnit) {
                        ForEach(CoopmartDirectory.stores.prefix(35)) { s in
                            Text(s.name).tag(s.name)
                        }
                    }

                    TextField("Phòng ban / Vị trí quầy (VD: Quầy thu ngân 01)", text: $department)
                    TextField("Ghi chú thêm", text: $note)
                }

                // Section 4: Ảnh chụp thiết bị (Cloudinary CDN)
                Section(header: Text("HÌNH ẢNH THIẾT BỊ (CLOUDINARY CDN)")) {
                    VStack(alignment: .leading, spacing: 10) {
                        if let img = selectedImage {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 160)
                                    .clipped()
                                    .cornerRadius(10)

                                if isUploadingImage {
                                    Color.black.opacity(0.4)
                                        .frame(height: 160)
                                        .cornerRadius(10)
                                    ProgressView("Đang tải lên CDN...")
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .foregroundColor(.white)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            Button(action: {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    imageSourceType = .camera
                                } else {
                                    imageSourceType = .photoLibrary
                                }
                                showImagePicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                    Text("Chụp ảnh")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appSecondaryDarkBlue.opacity(0.1))
                                .foregroundColor(.appSecondaryDarkBlue)
                                .cornerRadius(8)
                            }

                            Button(action: {
                                imageSourceType = .photoLibrary
                                showImagePicker = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo.fill")
                                    Text("Thư viện")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(UIColor.tertiarySystemFill))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }

                            if !uploadedImageUrl.isEmpty {
                                Spacer()
                                Text("Đã tải CDN")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Status message
                if let msg = alertMessage {
                    Section {
                        Text(msg)
                            .font(.caption.bold())
                            .foregroundColor(msg.contains("✅") ? .green : .red)
                    }
                }

                // Section 5: Nút lưu
                Section {
                    Button(action: saveDeviceAction) {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Lưu Thiết Bị Vào Hệ Thống")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isSubmitting)
                    .foregroundColor(.white)
                    .listRowBackground(Color.appPrimaryPink)
                }
            }
            .navigationTitle("Thêm Thiết Bị Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy", action: onDismiss)
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerWrapper(image: $selectedImage, sourceType: imageSourceType) { img in
                    uploadImageToCloudinary(img)
                }
            }
            .sheet(isPresented: $showScannerModal) {
                mockScannerSheet
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Mock Barcode Scanner Sheet
    private var mockScannerSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.appPrimaryPink, lineWidth: 3)
                        .frame(width: 240, height: 240)
                    Image(systemName: isScanningForCode ? "qrcode" : "barcode")
                        .font(.system(size: 100))
                        .foregroundColor(.appSecondaryDarkBlue.opacity(0.6))
                }
                Text("Hướng camera về mã vạch hoặc mã QR của thiết bị")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: {
                    let simulatedCode = isScanningForCode ? "DEV-\(Int.random(in: 1000...9999))" : "SN-\(UUID().uuidString.prefix(8).uppercased())"
                    if isScanningForCode {
                        code = simulatedCode
                    } else {
                        serialNumber = simulatedCode
                    }
                    showScannerModal = false
                }) {
                    Text("Mô phỏng quét mã thành công")
                        .font(.caption.bold())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.appSecondaryDarkBlue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
            }
            .navigationTitle(isScanningForCode ? "Quét Mã Thiết Bị" : "Quét Số Serial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showScannerModal = false }
                }
            }
        }
    }

    // MARK: - Image Upload
    private func uploadImageToCloudinary(_ img: UIImage) {
        guard let data = img.jpegData(compressionQuality: 0.75) else { return }
        isUploadingImage = true
        Task {
            if let url = await CloudinaryService.uploadImage(img, folder: "devices") {
                uploadedImageUrl = url
                alertMessage = "✅ Đã tải ảnh lên CDN thành công!"
            }
            isUploadingImage = false
        }
    }

    // MARK: - Save Device Action
    private func saveDeviceAction() {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCode.isEmpty else {
            alertMessage = "❌ Vui lòng nhập hoặc quét Mã thiết bị!"
            return
        }
        guard !cleanName.isEmpty else {
            alertMessage = "❌ Vui lòng nhập Tên thiết bị!"
            return
        }

        isSubmitting = true
        Task {
            let ok = await firebase.addDevice(
                code: cleanCode,
                name: cleanName,
                category: category,
                status: status,
                unit: selectedUnit,
                department: department,
                serialNumber: serialNumber,
                price: priceStr,
                warranty: warrantyMonths,
                imageUrl: uploadedImageUrl
            )
            isSubmitting = false
            if ok {
                alertMessage = "✅ Đã thêm thiết bị [\(cleanName)] thành công!"
                await firebase.loadDevices()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    onDismiss()
                }
            } else {
                alertMessage = "❌ Lỗi khi lưu thiết bị vào máy chủ."
            }
        }
    }
}

// Helper wrapper for UIImagePickerController
struct ImagePickerWrapper: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerWrapper
        init(_ parent: ImagePickerWrapper) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.image = img
                parent.onImagePicked(img)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
