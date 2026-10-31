import SwiftUI
import AudioToolbox

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
    
    // Share Sheet
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL? = nil
    
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
            
            // Checkboxes & Actions Row
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
        .sheet(isPresented: $showEditDialog) {
            editItemSheet
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareActivityView(activityItems: [url])
            }
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
                // Laser đỏ quét mã
                Rectangle()
                    .fill(Color.red.opacity(0.85))
                    .frame(height: 2)
            )
            
            // Nút bật/tắt đèn Flash ở góc
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
        HStack(spacing: 14) {
            // Nút Xuất file WINCE.txt
            Button(action: prepareShareFile) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                    Text("Xuất file")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
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
    
    private func prepareShareFile() {
        let content = db.exportToTextContent()
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documents.appendingPathComponent("WINCE.txt")
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            shareURL = fileURL
            showShareSheet = true
        } catch {
            print("Lỗi tạo file WINCE.txt: \(error)")
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

// Activity View for UIActivityViewController
struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
