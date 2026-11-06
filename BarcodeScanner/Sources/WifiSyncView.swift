import SwiftUI
import AudioToolbox

private enum ActiveWifiAlert: Identifiable {
    case resetConfirm
    case completionPrompt(fileName: String)
    case directCompleted(fileName: String, count: Int)
    case message(title: String, message: String)
    
    var id: String {
        switch self {
        case .resetConfirm: return "resetConfirm"
        case .completionPrompt(let fn): return "completionPrompt_\(fn)"
        case .directCompleted(let fn, let cnt): return "directCompleted_\(fn)_\(cnt)"
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
    @AppStorage("pref_wifi_sync_mode") private var wifiSyncMode: Int = 0 // 0: Auto theo IT PC, 1: Always Direct, 2: Always Queue
    
    // Thống kê & Trạng thái
    @State private var inventoryCount: Int = 0
    @State private var redScanCount: Int = 0
    @State private var isResetSessionChecked: Bool = false
    @State private var isScanningUid: Bool = false
    @State private var isUidTorchOn: Bool = false
    @State private var isSending: Bool = false
    @State private var isWaitingForApproval: Bool = false
    @State private var waitingMessage: String = ""
    @State private var waitingFileName: String = ""
    @State private var activeAlert: ActiveWifiAlert? = nil
    @State private var lastSentFileName: String = ""
    @State private var lastRegisteredScanId: String = "001"
    @State private var scanCheckTask: Task<Void, Never>? = nil
    
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
            let cleanUid = uidNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let formattedScan = FirebaseSyncService.formatScanId(idScan)
            idScan = formattedScan
            lastRegisteredScanId = formattedScan
            if !cleanUid.isEmpty {
                syncService.startRemoteClearMonitoring(pcUid: cleanUid)
                Task {
                    let res = await syncService.checkAndRegisterScanId(pcUid: cleanUid, scanId: formattedScan)
                    if !res.isSuccess {
                        await MainActor.run {
                            let devName = res.conflictDevice ?? "Thiết bị khác"
                            let plat = res.conflictPlatform ?? "Android/iOS"
                            activeAlert = .message(
                                title: "⚠️ Trùng mã ScanID!",
                                message: "Mã ScanID '\(formattedScan)' đang được sử dụng bởi: \(devName) (\(plat)).\n\nVui lòng chọn số khác!"
                            )
                        }
                    } else {
                        await MainActor.run {
                            lastRegisteredScanId = formattedScan
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDidClearRemotely)) { notif in
            let targetFile = (notif.userInfo?["fileName"] as? String)?.isEmpty == false
                ? (notif.userInfo!["fileName"] as! String)
                : (lastSentFileName.isEmpty ? computedFileName : lastSentFileName)
            
            _ = db.clearAll()
            refreshCounts()
            
            if isWaitingForApproval {
                isWaitingForApproval = false
                AudioServicesPlaySystemSound(1057)
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                activeAlert = .completionPrompt(fileName: targetFile)
            }
        }
        .sheet(isPresented: $isScanningUid) {
            uidScannerSheet
        }
        .overlay {
            if isWaitingForApproval {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        
                        Text("Đang chờ tiếp nhận...")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(waitingMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal)
                    }
                    .padding(24)
                    .frame(maxWidth: 320)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                    )
                    .padding(.horizontal, 24)
                }
                .transition(.opacity)
            }
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
            case .completionPrompt(let fileName):
                return Alert(
                    title: Text("🎉 HOÀN TẤT BIÊN BẢN!"),
                    message: Text("IT đã tiếp nhận và xóa dữ liệu đã đổ xong \(fileName)\n\n👉 Mời bạn đến bàn IT nhận biên bản kiểm kê và đi quét quầy tiếp theo"),
                    dismissButton: .default(Text("Bắt đầu quầy tiếp theo")) {
                        advanceToNextCount()
                    }
                )
            case .directCompleted(let fileName, let count):
                return Alert(
                    title: Text("🎉 TRUYỀN DỮ LIỆU THÀNH CÔNG!"),
                    message: Text("Đã truyền trực tiếp sang máy tính IT (Chế độ Direct - Không chờ duyệt).\n\n• Tệp: \(fileName)\n• Số lượng: \(count) mã\n\n👉 Dữ liệu trên máy đã được dọn sạch an toàn. Bạn có thể bắt đầu quầy tiếp theo!"),
                    dismissButton: .default(Text("Bắt đầu quầy tiếp theo")) {
                        advanceToNextCount()
                    }
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
                    .onChange(of: idScan) { newScan in
                        updateRedScanCount()
                        let cleanUid = uidNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                        let cleanScan = newScan.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        scanCheckTask?.cancel()
                        
                        guard !cleanUid.isEmpty, !cleanScan.isEmpty else { return }
                        
                        scanCheckTask = Task {
                            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
                            guard !Task.isCancelled else { return }
                            
                            let formattedTarget = FirebaseSyncService.formatScanId(cleanScan)
                            if formattedTarget == lastRegisteredScanId {
                                await MainActor.run {
                                    if idScan != formattedTarget {
                                        idScan = formattedTarget
                                    }
                                }
                                return
                            }
                            
                            let res = await syncService.checkAndRegisterScanId(pcUid: cleanUid, scanId: formattedTarget)
                            guard !Task.isCancelled else { return }
                            
                            await MainActor.run {
                                if !res.isSuccess {
                                    let devName = res.conflictDevice ?? "Thiết bị khác"
                                    let plat = res.conflictPlatform ?? "Android/iOS"
                                    activeAlert = .message(
                                        title: "⚠️ Trùng mã ScanID!",
                                        message: "Mã ScanID '\(formattedTarget)' đang được sử dụng bởi: \(devName) (\(plat)).\n\nVui lòng chọn số khác!"
                                    )
                                    // Hoàn tác về mã hợp lệ gần nhất
                                    idScan = lastRegisteredScanId
                                } else {
                                    let oldId = lastRegisteredScanId
                                    lastRegisteredScanId = formattedTarget
                                    idScan = formattedTarget
                                    
                                    if !oldId.isEmpty && oldId != formattedTarget {
                                        Task {
                                            await syncService.releaseScanId(pcUid: cleanUid, scanId: oldId)
                                        }
                                    }
                                }
                            }
                        }
                    }
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
                        let oldUid = uidNumber
                        uidNumber = clean
                        AudioServicesPlaySystemSound(1057)
                        syncService.startRemoteClearMonitoring(pcUid: clean)
                        isScanningUid = false
                        
                        // Kiểm tra xung đột ScanID trên UID vừa quét
                        Task {
                            let res = await syncService.checkAndRegisterScanId(pcUid: clean, scanId: idScan)
                            if !res.isSuccess {
                                await MainActor.run {
                                    let devName = res.conflictDevice ?? "Thiết bị khác"
                                    let plat = res.conflictPlatform ?? "Android/iOS"
                                    let fScan = FirebaseSyncService.formatScanId(idScan)
                                    activeAlert = .message(
                                        title: "⚠️ Trùng mã ScanID!",
                                        message: "Mã ScanID '\(fScan)' trên máy tính '\(clean)' đang được sử dụng bởi thiết bị khác: \(devName) (\(plat)).\n\nVui lòng đổi mã ScanID khác để tránh ghi đè dữ liệu!"
                                    )
                                }
                            } else {
                                await MainActor.run {
                                    lastRegisteredScanId = FirebaseSyncService.formatScanId(idScan)
                                }
                                if !oldUid.isEmpty && oldUid != clean {
                                    await syncService.releaseScanId(pcUid: oldUid, scanId: idScan)
                                }
                            }
                        }
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
    
    private func advanceToNextCount() {
        let prefix = filePrefix
        let scan = formattedScanId
        let key = "red_scan_count_\(scan)_\(prefix)"
        let current = UserDefaults.standard.integer(forKey: key)
        let nextCount = (current == 0 ? 1 : current) + 1
        UserDefaults.standard.set(nextCount, forKey: key)
        updateRedScanCount()
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
        waitingFileName = fileName
        
        // Tạo nội dung file chuẩn Android: NAME:<fileName>\n<barcode>,<qty>\n...
        var rawContent = "NAME:\(fileName)\n"
        for item in allItems {
            rawContent += "\(item.barcode),\(item.formattedQuantity)\n"
        }
        let contentToSend = rawContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            do {
                // Kiểm tra xung đột ScanID trước khi gửi dữ liệu
                let checkRes = await syncService.checkAndRegisterScanId(pcUid: cleanUid, scanId: formattedScanId)
                if !checkRes.isSuccess {
                    await MainActor.run {
                        isSending = false
                        let devName = checkRes.conflictDevice ?? "Thiết bị khác"
                        let plat = checkRes.conflictPlatform ?? "Android/iOS"
                        activeAlert = .message(
                            title: "⚠️ Không thể gửi dữ liệu!",
                            message: "Mã ScanID '\(formattedScanId)' đang bị trùng với thiết bị khác (\(devName) - \(plat)) trên máy tính này. Vui lòng đổi mã ScanID trước khi gửi dữ liệu!"
                        )
                    }
                    return
                }

                // Kiểm tra kết nối PC trên Firebase & lấy thông tin cấu hình SyncMode
                let pcConfig = try await syncService.getPcConfig(pcUid: cleanUid)
                if !pcConfig.isOnline || !pcConfig.isInternetEnabled {
                    await MainActor.run {
                        isSending = false
                        activeAlert = .message(
                            title: "PC chưa sẵn sàng",
                            message: "Máy tính có mã UID '\(cleanUid)' hiện chưa mở hoặc chưa tích chọn 'Nhận qua Internet' trên phần mềm PC."
                        )
                    }
                    return
                }
                
                // Xác định chế độ Direct hay Queue
                let isDirectMode: Bool
                if wifiSyncMode == 1 {
                    isDirectMode = true
                } else if wifiSyncMode == 2 {
                    isDirectMode = false
                } else {
                    isDirectMode = (pcConfig.syncMode.uppercased() == "DIRECT" || pcConfig.autoAccept)
                }
                
                // Mở khoá chờ tiếp nhận (không cho đóng giữa chừng)
                await MainActor.run {
                    isSending = false
                    isWaitingForApproval = true
                    if isDirectMode {
                        waitingMessage = "Tệp: \(fileName) (\(allItems.count) mã)\nChế độ TRỰC TIẾP (Direct) - Đang nạp vào máy tính PC..."
                    } else {
                        waitingMessage = "Tệp: \(fileName) (\(allItems.count) mã)\nĐã gửi dữ liệu sang PC, đang chờ IT xếp vào hàng đợi & xử lý..."
                    }
                }
                
                // Gửi dữ liệu kiểm kê lên Firebase RTDB & chờ tiếp nhận
                let sendSuccess = try await syncService.sendInventoryData(
                    pcUid: cleanUid,
                    fileName: fileName,
                    content: contentToSend,
                    employeeId: formattedScanId,
                    totalRecords: allItems.count,
                    isDirectMode: isDirectMode,
                    onStatusChange: { status, queuePos in
                        Task { @MainActor in
                            if status == "QUEUED" {
                                waitingMessage = "Tệp: \(fileName) (\(allItems.count) mã)\n\nHàng đợi: Vị trí #\(queuePos) - Đang chờ IT bấm tiếp nhận..."
                            } else if status == "PROCESSING" {
                                waitingMessage = "Tệp: \(fileName) (\(allItems.count) mã)\n\nĐang tiếp nhận và xử lý...\nIT đang in biên bản và kiểm tra dữ liệu..."
                            }
                        }
                    }
                )
                
                await MainActor.run {
                    isWaitingForApproval = false
                    if sendSuccess {
                        // Tự động xoá dữ liệu trên máy điện thoại khi dữ liệu đã được nạp/xác nhận
                        _ = db.clearAll()
                        refreshCounts()
                        
                        AudioServicesPlaySystemSound(1057) // Beep
                        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                        
                        // Hiển thị dialog thông báo phù hợp chế độ
                        if isDirectMode {
                            activeAlert = .directCompleted(fileName: fileName, count: allItems.count)
                        } else {
                            activeAlert = .completionPrompt(fileName: fileName)
                        }
                    } else {
                        activeAlert = .message(
                            title: "Hết thời gian chờ",
                            message: "Hết thời gian chờ phản hồi từ IT (Dữ liệu được giữ nguyên)"
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    isWaitingForApproval = false
                    activeAlert = .message(
                        title: "Lỗi kết nối",
                        message: "Lỗi: \(error.localizedDescription)"
                    )
                }
            }
        }
    }
}
