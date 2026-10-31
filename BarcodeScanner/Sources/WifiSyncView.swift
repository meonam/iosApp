import SwiftUI
import AudioToolbox

private enum ActiveWifiAlert: Identifiable {
    case resetConfirm
    case clearPrompt(fileName: String)
    case message(title: String, message: String)
    
    var id: String {
        switch self {
        case .resetConfirm: return "resetConfirm"
        case .clearPrompt(let fn): return "clearPrompt_\(fn)"
        case .message(let title, _): return "msg_\(title)"
        }
    }
}

public struct WifiSyncView: View {
    // region UI State
    @AppStorage("uid_number") private var uidNumber: String = ""
    @AppStorage("selected_mode") private var selectedMode: Int = 0 // 0: KHO (k), 1: QUẦY (q), 2: TUỲ CHỌN (c)
    @AppStorage("id_scan") private var idScan: String = "001"
    @AppStorage("id_dem") private var idDem: String = "001"
    @AppStorage("id_so_phieu") private var idSoPhieu: String = "001"
    @AppStorage("custom_file_name") private var customFileName: String = ""
    
    // Thống kê & Trạng thái
    @State private var inventoryCount: Int = 0
    @State private var redScanCount: Int = 0
    @State private var isResetSessionChecked: Bool = false
    @State private var isScanningUid: Bool = false
    @State private var isUidTorchOn: Bool = false
    @State private var isSending: Bool = false
    @State private var activeAlert: ActiveWifiAlert? = nil
    @State private var lastSentFileName: String = ""
    
    private let db = DatabaseHelper.shared
    private let syncService = FirebaseSyncService.shared
    
    public init() {}
    
    // MARK: - Computed Properties
    
    private var filePrefix: String {
        switch selectedMode {
        case 0: return "k"
        case 1: return "q"
        default: return "c"
        }
    }
    
    private var formattedScanId: String {
        let clean = idScan.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "001" }
        if let num = Int(clean) { return String(format: "%03d", num) }
        return clean
    }
    
    private var formattedSoPhieu: String {
        let clean = idSoPhieu.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty { return "001" }
        if let num = Int(clean) { return String(format: "%03d", num) }
        return clean
    }
    
    private var computedFileName: String {
        if selectedMode == 2 {
            let custom = customFileName.trimmingCharacters(in: .whitespacesAndNewlines)
            if custom.isEmpty {
                return "\(formattedScanId)c\(formattedSoPhieu).txt"
            } else {
                return "\(custom).txt"
            }
        } else {
            return "\(formattedScanId)\(filePrefix)\(formattedSoPhieu).txt"
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // === MAIN CARD (Tương tự Android WifiScreen) ===
                VStack(spacing: 10) {
                    // Row 1: DEVICE UID & NÚT QUÉT UID
                    deviceUidRow
                    
                    // Row 2: CHỌN CHẾ ĐỘ (KHO, QUẦY, TUỲ CHỌN)
                    modeSelectionRow
                    
                    // Row 3: SCAN ID + COUNT ID
                    scanAndCountIdRow
                    
                    // Row 4: TÊN FILE + PHIẾU
                    fileNameAndPhieuRow
                    
                    // Row 5: TÊN FILE TUỲ CHỈNH (khi chọn TUỲ CHỌN)
                    if selectedMode == 2 {
                        customFileNameRow
                    }
                    
                    Spacer().frame(height: 4)
                    
                    // Row 6: NÚT GỬI QUA NET
                    sendButton
                    
                    // Row 7: THỐNG KÊ (BẢN GHI | ĐÃ SCAN)
                    statisticsCard
                    
                    // Row 8: RESET TRƯỚC KHI KIỂM KÊ
                    resetToggleSection
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationBarHidden(true)
        .onAppear {
            refreshCounts()
            if !uidNumber.isEmpty {
                syncService.startRemoteClearMonitoring(pcUid: uidNumber)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidClearRemotely)) { _ in
            refreshCounts()
        }
        .sheet(isPresented: $isScanningUid) {
            uidScannerSheet
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .resetConfirm:
                return Alert(
                    title: Text("Xác nhận Reset"),
                    message: Text("Bạn có chắc chắn muốn reset số phiếu và lượt quét về mặc định ban đầu không?"),
                    primaryButton: .destructive(Text("Reset")) {
                        performReset()
                    },
                    secondaryButton: .cancel(Text("Huỷ"))
                )
            case .clearPrompt(let fileName):
                return Alert(
                    title: Text("Gửi thành công!"),
                    message: Text("Máy tính đã nhận file: \(fileName)\n\nBạn có muốn xoá toàn bộ dữ liệu vừa gửi trong máy để bắt đầu đợt quét mới không?"),
                    primaryButton: .destructive(Text("Xoá dữ liệu")) {
                        _ = db.clearAll()
                        refreshCounts()
                    },
                    secondaryButton: .default(Text("Giữ lại"))
                )
            case .message(let title, let message):
                return Alert(
                    title: Text(title),
                    message: Text(message),
                    dismissButton: .default(Text("Đóng"))
                )
            }
        }
    }
    
    // MARK: - Subviews
    
    // Row 1: DEVICE UID + Nút QUÉT UID
    private var deviceUidRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("DEVICE UID")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("Nhập UID máy tính", text: $uidNumber)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onChange(of: uidNumber) { newUid in
                        if !newUid.isEmpty {
                            syncService.startRemoteClearMonitoring(pcUid: newUid)
                        }
                    }
            }
            
            Button(action: {
                isScanningUid = true
            }) {
                VStack(spacing: 2) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 16))
                    Text("QUÉT UID")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(width: 95, height: 50)
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.top, 16)
        }
    }
    
    // Row 2: 3 Radio Buttons chọn chế độ (KHO, QUẦY, TUỲ CHỌN)
    private var modeSelectionRow: some View {
        HStack(spacing: 6) {
            modeButton(title: "KHO", modeIndex: 0)
            modeButton(title: "QUẦY", modeIndex: 1)
            modeButton(title: "TUỲ CHỌN", modeIndex: 2)
        }
        .padding(.vertical, 2)
    }
    
    private func modeButton(title: String, modeIndex: Int) -> some View {
        Button(action: {
            selectedMode = modeIndex
            updateRedScanCount()
        }) {
            HStack(spacing: 6) {
                Image(systemName: selectedMode == modeIndex ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(selectedMode == modeIndex ? .blue : .gray)
                
                Text(title)
                    .font(.system(size: 12, weight: selectedMode == modeIndex ? .bold : .medium))
                    .foregroundColor(selectedMode == modeIndex ? .blue : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(selectedMode == modeIndex ? Color.blue.opacity(0.1) : Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedMode == modeIndex ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Row 3: SCAN ID + COUNT ID
    private var scanAndCountIdRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("SCAN ID")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("001", text: $idScan)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(selectedMode == 2)
                    .onChange(of: idScan) { _ in updateRedScanCount() }
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("COUNT ID")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("001", text: $idDem)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(selectedMode == 2)
            }
        }
    }
    
    // Row 4: TÊN FILE + PHIẾU
    private var fileNameAndPhieuRow: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TÊN FILE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                
                HStack(spacing: 4) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                    
                    Text(computedFileName)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 9)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("PHIẾU")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                
                TextField("001", text: $idSoPhieu)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(selectedMode == 2)
            }
        }
    }
    
    // Row 5: TÊN FILE TUỲ CHỈNH
    private var customFileNameRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TÊN FILE TUỲ CHỈNH")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.blue)
            
            TextField("Nhập tên file tuỳ chỉnh (không cần đuôi .txt)", text: $customFileName)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                )
        }
    }
    
    // Row 6: NÚT GỬI QUA NET
    private var sendButton: some View {
        Button(action: handleSendViaNet) {
            HStack(spacing: 10) {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                }
                
                Text("SEND VIA NET (KHÔNG GIỚI HẠN)")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.blue)
            .cornerRadius(12)
            .shadow(color: Color.blue.opacity(0.35), radius: 4, x: 0, y: 2)
        }
        .disabled(isSending || isResetSessionChecked)
    }
    
    // Row 7: THỐNG KÊ (BẢN GHI | ĐÃ SCAN)
    private var statisticsCard: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 2) {
                Text("\(inventoryCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)
                Text("BẢN GHI")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue.opacity(0.8))
            }
            
            Spacer()
            
            Rectangle()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 1, height: 32)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("\(redScanCount)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                Text("ĐÃ SCAN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.red.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground).opacity(0.7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Row 8: RESET TRƯỚC KHI KIỂM KÊ
    private var resetToggleSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                isResetSessionChecked.toggle()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isResetSessionChecked ? "largecircle.fill.circle" : "circle")
                        .font(.system(size: 16))
                        .foregroundColor(isResetSessionChecked ? .blue : .gray)
                    
                    Text("Reset trước khi kiểm kê")
                        .font(.system(size: 12, weight: isResetSessionChecked ? .bold : .medium))
                        .foregroundColor(isResetSessionChecked ? .blue : .secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isResetSessionChecked {
                Button(action: {
                    activeAlert = .resetConfirm
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("XÁC NHẬN RESET")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
            }
        }
        .padding(.top, 2)
    }
    
    // Sheet quét QR UID máy tính
    private var uidScannerSheet: some View {
        NavigationView {
            ZStack {
                CameraScannerView(isTorchOn: isUidTorchOn) { code in
                    let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty {
                        uidNumber = clean
                        AudioServicesPlaySystemSound(1057)
                        syncService.startRemoteClearMonitoring(pcUid: clean)
                        isScanningUid = false
                    }
                }
                .edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Hướng camera vào mã QR UID hiển thị trên màn hình máy tính PC")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .padding(.top, 16)
                    
                    Spacer()
                    
                    // Khung quét QR trung tâm
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green, lineWidth: 3)
                            .frame(width: 250, height: 250)
                        
                        Rectangle()
                            .fill(Color.red.opacity(0.85))
                            .frame(width: 240, height: 2)
                    }
                    
                    Spacer()
                    
                    Text("Hoặc nhập trực tiếp mã UID vào ô trên màn hình")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 24)
                }
            }
            .navigationBarTitle("Quét mã QR UID", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: { isUidTorchOn.toggle() }) {
                    Image(systemName: isUidTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .foregroundColor(isUidTorchOn ? .yellow : .primary)
                },
                trailing: Button("Đóng") {
                    isScanningUid = false
                }
            )
        }
    }
    
    // MARK: - Logic & Actions
    
    private func refreshCounts() {
        inventoryCount = db.getCount()
        updateRedScanCount()
    }
    
    private func updateRedScanCount() {
        let prefix = filePrefix
        let scan = formattedScanId
        let key = "red_scan_count_\(scan)_\(prefix)"
        let count = UserDefaults.standard.integer(forKey: key)
        let actualCount = count == 0 ? 1 : count
        redScanCount = actualCount - 1
        idSoPhieu = String(format: "%03d", actualCount)
    }
    
    private func performReset() {
        let prefix = filePrefix
        let scan = formattedScanId
        let key = "red_scan_count_\(scan)_\(prefix)"
        UserDefaults.standard.removeObject(forKey: key)
        
        idScan = "001"
        idSoPhieu = "001"
        redScanCount = 0
        isResetSessionChecked = false
        refreshCounts()
    }
    
    private func handleSendViaNet() {
        let cleanUid = uidNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUid.isEmpty else {
            activeAlert = .message(
                title: "Thiếu UID máy tính",
                message: "Vui lòng nhập hoặc bấm nút 'QUÉT UID' để kết nối với máy tính PC trước khi gửi."
            )
            return
        }
        
        let allItems = db.getAllItems()
        guard !allItems.isEmpty else {
            activeAlert = .message(
                title: "Chưa có dữ liệu",
                message: "Không có bản ghi kiểm kê nào trong máy để gửi. Vui lòng quét mã kiểm kê trước."
            )
            return
        }
        
        isSending = true
        let fileName = computedFileName
        lastSentFileName = fileName
        
        // Tạo nội dung file chuẩn Android: NAME:<fileName>\n<barcode>,<qty>\n...
        var rawContent = "NAME:\(fileName)\n"
        for item in allItems {
            rawContent += "\(item.barcode),\(item.formattedQuantity)\n"
        }
        let contentToSend = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                // Kiểm tra kết nối PC trên Firebase
                let pcConnected = try await syncService.checkPcConnection(pcUid: cleanUid)
                if !pcConnected {
                    await MainActor.run {
                        isSending = false
                        activeAlert = .message(
                            title: "PC chưa sẵn sàng",
                            message: "Máy tính có mã UID '\(cleanUid)' hiện chưa mở hoặc chưa tích chọn 'Nhận qua Internet' trên phần mềm PC."
                        )
                    }
                    return
                }
                
                // Gửi dữ liệu kiểm kê lên Firebase RTDB
                let sendSuccess = try await syncService.sendInventoryData(
                    pcUid: cleanUid,
                    fileName: fileName,
                    content: contentToSend,
                    employeeId: formattedScanId
                )
                
                await MainActor.run {
                    isSending = false
                    if sendSuccess {
                        // Tăng biến đếm RedScan
                        let prefix = filePrefix
                        let scan = formattedScanId
                        let key = "red_scan_count_\(scan)_\(prefix)"
                        let current = UserDefaults.standard.integer(forKey: key)
                        let nextCount = (current == 0 ? 1 : current) + 1
                        UserDefaults.standard.set(nextCount, forKey: key)
                        
                        AudioServicesPlaySystemSound(1057) // Beep
                        updateRedScanCount()
                        
                        // Hiển thị dialog hỏi xoá dữ liệu tương tự Android
                        activeAlert = .clearPrompt(fileName: fileName)
                    } else {
                        activeAlert = .message(
                            title: "Gửi thất bại",
                            message: "Không thể gửi dữ liệu tới máy tính. Vui lòng kiểm tra lại mạng Wi-Fi/Internet và thử lại."
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    activeAlert = .message(
                        title: "Lỗi kết nối",
                        message: "Lỗi: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
}
