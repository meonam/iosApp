import SwiftUI

public struct WifiSyncView: View {
    @State private var pcUid: String = ""
    @State private var isScanningUid: Bool = false
    
    // File Options
    @State private var selectedMode: Int = 0 // 0: Auto (WINCE.txt), 1: Tuỳ chỉnh
    @State private var idScan: String = ""
    @State private var idDem: String = ""
    @State private var idSoPhieu: String = ""
    @State private var customFileName: String = ""
    
    // Checkbox Xoá dữ liệu sau khi gửi thành công
    @State private var autoClearAfterSend: Bool = true
    
    // Trạng thái gửi
    @State private var isSending: Bool = false
    @State private var statusMessage: String = "Sẵn sàng kết nối"
    @State private var statusColor: Color = .gray
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    
    // Thống kê
    @State private var totalRecords: Int = 0
    
    private let db = DatabaseHelper.shared
    private let syncService = FirebaseSyncService.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "wifi")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("GỬI DỮ LIỆU QUA WI-FI / INTERNET")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Card 1: Nhập UID máy tính PC
                VStack(alignment: .leading, spacing: 10) {
                    Text("1. KẾT NỐI MÁY TÍNH (PC)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    HStack {
                        TextField("Nhập mã UID máy tính (Ví dụ: 123456)", text: $pcUid)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        Button(action: {
                            isScanningUid = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "qrcode.viewfinder")
                                Text("Quét QR")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    Text("Mở phần mềm DATALOGIC MEMOR hoặc ASSET INVENTORY trên PC để lấy mã UID hoặc quét mã QR hiển thị trên màn hình máy tính.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Card 2: Thông tin file & Ca làm việc
                VStack(alignment: .leading, spacing: 10) {
                    Text("2. CẤU HÌNH TÊN FILE XUẤT")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Picker("Chế độ", selection: $selectedMode) {
                        Text("Mặc định (WINCE.txt)").tag(0)
                        Text("Tên tùy chỉnh").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if selectedMode == 1 {
                        HStack {
                            Text("Tên file:")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 70, alignment: .leading)
                            TextField("Ví dụ: 001.txt", text: $customFileName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ID Quét")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("01", text: $idScan)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ID Đếm")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("01", text: $idDem)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Số phiếu")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("001", text: $idSoPhieu)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13))
                        }
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                // Card 3: Thống kê & Gửi dữ liệu
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tổng số dòng kiểm kê hiện có:")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text("\(totalRecords) dòng")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $autoClearAfterSend) {
                        Text("Xoá dữ liệu trên điện thoại sau khi PC nhận thành công")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    // Trạng thái hiện tại
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(statusColor)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    // Nút Gửi dữ liệu lớn
                    Button(action: sendDataToPC) {
                        HStack(spacing: 8) {
                            if isSending {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text(isSending ? "ĐANG GỬI DỮ LIỆU..." : "GỬI DỮ LIỆU ĐẾN MÁY TÍNH")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSending || totalRecords == 0 ? Color.gray : Color.blue)
                        .cornerRadius(10)
                    }
                    .disabled(isSending || totalRecords == 0)
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
                
                Spacer(minLength: 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .onAppear {
            refreshData()
            loadSavedSettings()
        }
        .sheet(isPresented: $isScanningUid) {
            QRScannerSheet { scannedUid in
                self.pcUid = scannedUid
                self.isScanningUid = false
                saveSettings()
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("Đồng ý"))
            )
        }
    }
    
    // MARK: - Functions
    
    private func refreshData() {
        totalRecords = db.getCount()
    }
    
    private func loadSavedSettings() {
        if let savedUid = UserDefaults.standard.string(forKey: "SAVED_PC_UID") {
            pcUid = savedUid
        }
        idScan = UserDefaults.standard.string(forKey: "SAVED_ID_SCAN") ?? ""
        idDem = UserDefaults.standard.string(forKey: "SAVED_ID_DEM") ?? ""
        idSoPhieu = UserDefaults.standard.string(forKey: "SAVED_ID_SO_PHIEU") ?? ""
        customFileName = UserDefaults.standard.string(forKey: "SAVED_CUSTOM_FILENAME") ?? ""
        selectedMode = UserDefaults.standard.integer(forKey: "SAVED_MODE")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(pcUid, forKey: "SAVED_PC_UID")
        UserDefaults.standard.set(idScan, forKey: "SAVED_ID_SCAN")
        UserDefaults.standard.set(idDem, forKey: "SAVED_ID_DEM")
        UserDefaults.standard.set(idSoPhieu, forKey: "SAVED_ID_SO_PHIEU")
        UserDefaults.standard.set(customFileName, forKey: "SAVED_CUSTOM_FILENAME")
        UserDefaults.standard.set(selectedMode, forKey: "SAVED_MODE")
    }
    
    private func sendDataToPC() {
        let cleanUid = pcUid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUid.isEmpty else {
            alertTitle = "Chưa nhập UID"
            alertMessage = "Vui lòng nhập hoặc quét mã UID máy tính trước khi gửi."
            showAlert = true
            return
        }
        
        saveSettings()
        
        // Chuẩn bị nội dung gửi
        let content = db.exportToTextContent()
        guard !content.isEmpty else {
            alertTitle = "Dữ liệu trống"
            alertMessage = "Không có mặt hàng nào trong cơ sở dữ liệu kiểm kê để gửi."
            showAlert = true
            return
        }
        
        // Xác định tên file
        let finalFileName: String
        if selectedMode == 1 && !customFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var name = customFileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.lowercased().hasSuffix(".txt") {
                name += ".txt"
            }
            finalFileName = name
        } else {
            finalFileName = "WINCE.txt"
        }
        
        isSending = true
        statusMessage = "Đang kết nối đến Firebase & gửi dữ liệu..."
        statusColor = .orange
        
        Task {
            do {
                let success = try await syncService.sendInventoryData(
                    pcUid: cleanUid,
                    fileName: finalFileName,
                    content: content
                )
                
                await MainActor.run {
                    isSending = false
                    if success {
                        statusMessage = "PC đã nhận thành công lúc \(formattedTime())"
                        statusColor = .green
                        
                        if autoClearAfterSend {
                            _ = db.clearAll()
                            refreshData()
                        }
                        
                        alertTitle = "Gửi thành công!"
                        alertMessage = "Dữ liệu \(finalFileName) (\(totalRecords) dòng) đã được truyền đến máy tính PC an toàn qua mạng Internet/Wi-Fi."
                        showAlert = true
                    } else {
                        statusMessage = "Gửi thất bại hoặc máy tính PC không phản hồi"
                        statusColor = .red
                        alertTitle = "Không phản hồi"
                        alertMessage = "Không thể nhận xác nhận (ACK) từ PC. Vui lòng kiểm tra ứng dụng trên PC đã bật nhận Internet chưa."
                        showAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    statusMessage = "Lỗi kết nối mạng: \(error.localizedDescription)"
                    statusColor = .red
                    alertTitle = "Lỗi gửi dữ liệu"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// Sheet quét QR UID
struct QRScannerSheet: View {
    let onScanned: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                CameraScannerView(isTorchOn: false) { code in
                    onScanned(code)
                }
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Quét mã QR hiển thị trên phần mềm PC")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 240, height: 240)
                    
                    Spacer()
                }
            }
            .navigationBarItems(trailing: Button("Đóng") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
