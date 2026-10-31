import SwiftUI
import AudioToolbox
import UIKit

// MARK: - Trình hiển thị chia sẻ chuẩn iOS (UIActivityViewController)
public struct ShareSheetPresenter {
    public static func share(items: [Any]) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first,
                  let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
                return
            }
            
            var topController = rootVC
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
            
            // Cấu hình Popover cho iPad để không bao giờ bị crash hoặc mất dialog
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityVC, animated: true, completion: nil)
        }
    }
}

public struct KiemKeListView: View {
    @State private var items: [InventoryItem] = []
    @State private var totalCount: Int = 0
    @State private var barcodeText: String = ""
    @State private var quantityText: String = "1"
    
    // Camera Scanning State
    @State private var isCameraActive: Bool = false
    @State private var isTorchOn: Bool = false
    @State private var bannerMessage: String = ""
    @State private var showBanner: Bool = false
    @State private var lastScannedCode: String = ""
    @State private var lastScannedTime: Date = Date.distantPast
    
    // Checkboxes
    @State private var isNoProductsChecked: Bool = false
    @State private var isPLUChecked: Bool = false
    @State private var isQty1Checked: Bool = false
    
    // Edit Item Sheet / Alert
    @State private var editingItem: InventoryItem? = nil
    @State private var editBarcode: String = ""
    @State private var editQuantity: String = ""
    @State private var showEditDialog: Bool = false
    
    // Delete All Confirmation
    @State private var showDeleteAllAlert: Bool = false
    
    // Alert khi không có dữ liệu để xuất file
    @State private var showNoDataAlert: Bool = false
    
    private let db = DatabaseHelper.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Top
            headerSection
            
            // Camera Preview Section (Chỉ hiện khi bấm nút "Quét mã")
            if isCameraActive {
                cameraPreviewSection
            }
            
            // Floating Success Banner
            if showBanner {
                Text(bannerMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .cornerRadius(8)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Input Card
            inputCardSection
            
            // Checkboxes & Actions Row (Nút Xuất file chia sẻ + Checkboxes)
            optionsRowSection
            
            // Scan Button (Quét mã / Dừng) tương tự như Android
            scanControlButton
            
            // Table Header
            tableHeaderView
            
            // Inventory Table List
            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Chưa có dữ liệu kiểm kê")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(Array(items.reversed()), id: \.stt) { item in
                        HStack(spacing: 8) {
                            Text("\(item.stt)")
                                .font(.system(size: 13, weight: .bold))
                                .frame(width: 40, alignment: .center)
                                .foregroundColor(.primary)
                            
                            Text(item.barcode)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            
                            Text(item.formattedQuantity)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 60, alignment: .trailing)
                                .foregroundColor(.blue)
                            
                            Button(action: {
                                startEditing(item: item)
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.orange)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .frame(width: 36, alignment: .center)
                            
                            Button(action: {
                                deleteItem(item: item)
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .frame(width: 36, alignment: .center)
                        }
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidClearRemotely)) { _ in
            loadData()
            bannerMessage = "Máy tính đã xoá sạch dữ liệu kiểm kê!"
            withAnimation { showBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { showBanner = false }
            }
        }
        .sheet(isPresented: $showEditDialog) {
            editItemSheet
        }
        .alert(isPresented: $showDeleteAllAlert) {
            Alert(
                title: Text("Xác nhận xoá tất cả"),
                message: Text("Bạn có chắc chắn muốn xoá toàn bộ dữ liệu kiểm kê trong máy không? Thao tác này không thể hoàn tác."),
                primaryButton: .destructive(Text("Xoá sạch")) {
                    deleteAllData()
                },
                secondaryButton: .cancel(Text("Huỷ"))
            )
        }
        .alert(isPresented: $showNoDataAlert) {
            Alert(
                title: Text("Chưa có dữ liệu"),
                message: Text("Không có bản ghi kiểm kê nào trong máy để xuất file. Vui lòng quét mã kiểm kê trước."),
                dismissButton: .default(Text("Đóng"))
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        HStack {
            Text("KIỂM KÊ KHO")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            Text("Tổng: \(totalCount)")
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.15))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    private var cameraPreviewSection: some View {
        ZStack {
            CameraScannerView(isTorchOn: isTorchOn) { code in
                handleCameraScanned(code: code)
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.green, lineWidth: 2)
            )
            .overlay(
                Rectangle()
                    .fill(Color.red.opacity(0.85))
                    .frame(height: 2)
            )
            
            // Nút bật/tắt đèn Flash
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isTorchOn.toggle() }) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 14))
                            .foregroundColor(isTorchOn ? .yellow : .white)
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    private var inputCardSection: some View {
        VStack(spacing: 8) {
            // Barcode Row
            HStack(spacing: 8) {
                Text("Mã hàng:")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 75, alignment: .leading)
                
                TextField("Nhập hoặc quét mã...", text: $barcodeText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
                    .onSubmit {
                        addBarcodeManually()
                    }
            }
            
            // Quantity Row (Không cần nút Thêm ngay số lượng, nhấn Return để thêm)
            HStack(spacing: 8) {
                Text("Số lượng:")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 75, alignment: .leading)
                
                TextField("1", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 14))
                    .disabled(isQty1Checked)
                    .onSubmit {
                        addBarcodeManually()
                    }
            }
            
            // Ghi chú phía trên nút Delete giống Android
            Text("Nhớ xóa dữ liệu sau khi đổ xong")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.red)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
                .padding(.bottom, 2)
            
            // Nút Delete nhỏ gọn giống Android
            Button(action: {
                showDeleteAllAlert = true
            }) {
                Text("Delete")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .cornerRadius(6)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            // Tổng bản ghi
            Text("Tổng bản ghi: \(totalCount)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 12)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
    
    private var optionsRowSection: some View {
        HStack(spacing: 12) {
            // Nút Xuất file / Chia sẻ (Zalo, Mail, Tệp, Tin nhắn...) chuẩn như Android
            Button(action: handleShareData) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text("Xuất file")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            Spacer()
            
            ToggleCheck(title: "Không SP", isChecked: $isNoProductsChecked)
            ToggleCheck(title: "PLU", isChecked: $isPLUChecked)
            ToggleCheck(title: "SL = 1", isChecked: $isQty1Checked)
                .onChange(of: isQty1Checked) { newValue in
                    if newValue {
                        quantityText = "1"
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // Nút Quét mã tương tự Android (nằm ngay trên tiêu đề bảng)
    private var scanControlButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCameraActive.toggle()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCameraActive ? "xmark.circle.fill" : "camera.fill")
                    .font(.system(size: 16))
                Text(isCameraActive ? "Dừng" : "Quét mã")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(isCameraActive ? Color.orange : Color(red: 0.12, green: 0.58, blue: 0.28))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
    
    private var tableHeaderView: some View {
        HStack(spacing: 8) {
            Text("STT")
                .frame(width: 40, alignment: .center)
            Text("Mã hàng")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Số lượng")
                .frame(width: 60, alignment: .trailing)
            Text("Sửa")
                .frame(width: 36, alignment: .center)
            Text("Xoá")
                .frame(width: 36, alignment: .center)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(.white)
        .padding(.vertical, 7)
        .padding(.horizontal, 12)
        .background(Color.blue)
    }
    
    private var editItemSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin mặt hàng")) {
                    HStack {
                        Text("STT:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(editingItem?.stt ?? 0)")
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Mã vạch:")
                        TextField("Mã vạch", text: $editBarcode)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Số lượng:")
                        TextField("Số lượng", text: $editQuantity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationBarTitle("Chỉnh sửa bản ghi", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Huỷ") {
                    showEditDialog = false
                },
                trailing: Button("Lưu") {
                    saveEditedItem()
                }
                .font(.headline)
            )
        }
    }
    
    // MARK: - Actions
    
    private func loadData() {
        items = db.getAllItems()
        totalCount = db.getCount()
    }
    
    private func addBarcodeManually() {
        let trimmed = barcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let qty: Double
        if isQty1Checked {
            qty = 1.0
        } else {
            qty = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        }
        
        if db.insertItem(barcode: trimmed, quantity: qty) {
            barcodeText = ""
            if !isQty1Checked {
                quantityText = "1"
            }
            loadData()
        }
    }
    
    private func handleCameraScanned(code: String) {
        let now = Date()
        if code == lastScannedCode && now.timeIntervalSince(lastScannedTime) < 1.2 {
            return
        }
        lastScannedCode = code
        lastScannedTime = now
        
        let qty: Double
        if isQty1Checked {
            qty = 1.0
        } else {
            qty = Double(quantityText.replacingOccurrences(of: ",", with: ".")) ?? 1.0
        }
        
        if db.insertItem(barcode: code, quantity: qty) {
            bannerMessage = "Đã lưu: \(code) (SL: \(qty))"
            withAnimation {
                showBanner = true
            }
            loadData()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation {
                    showBanner = false
                }
            }
        }
    }
    
    private func startEditing(item: InventoryItem) {
        editingItem = item
        editBarcode = item.barcode
        editQuantity = item.formattedQuantity
        showEditDialog = true
    }
    
    private func saveEditedItem() {
        guard let item = editingItem else { return }
        let trimmed = editBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let qty = Double(editQuantity.replacingOccurrences(of: ",", with: ".")) ?? item.quantity
        _ = db.updateItem(stt: item.stt, barcode: trimmed, quantity: qty)
        showEditDialog = false
        loadData()
    }
    
    private func deleteItem(item: InventoryItem) {
        _ = db.deleteItem(stt: item.stt)
        loadData()
    }
    
    private func deleteAllData() {
        _ = db.clearAll()
        loadData()
    }
    
    /// Xuất file dữ liệu kiểm kê và mở hộp thoại chia sẻ hệ thống iOS (Zalo, Mail, Tệp, Tin nhắn...)
    private func handleShareData() {
        guard !items.isEmpty else {
            showNoDataAlert = true
            return
        }
        
        let content = db.exportToTextContent()
        guard !content.isEmpty else {
            showNoDataAlert = true
            return
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "KiemKe_\(timestamp).txt"
        
        // 1. Lưu file vào Documents để đồng bộ qua cáp/Files app (UIFileSharingEnabled)
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docFile = documents.appendingPathComponent("WINCE.txt")
            let docFileDated = documents.appendingPathComponent(fileName)
            try? content.write(to: docFile, atomically: true, encoding: .utf8)
            try? content.write(to: docFileDated, atomically: true, encoding: .utf8)
        }
        
        // 2. Lưu file vào Temporary để chia sẻ qua Zalo, Messenger, Mail, AirDrop, v.v.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            ShareSheetPresenter.share(items: [tempURL])
        } catch {
            print("Lỗi tạo file chia sẻ: \(error)")
        }
    }
}

// Checkbox helper view
struct ToggleCheck: View {
    let title: String
    @Binding var isChecked: Bool
    
    var body: some View {
        Button(action: {
            isChecked.toggle()
        }) {
            HStack(spacing: 4) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .foregroundColor(isChecked ? .blue : .gray)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
