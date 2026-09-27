import SwiftUI

// MARK: - MÀN HÌNH DANH SÁCH THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI DEVICELISTSCREEN.KT TRÊN ANDROID)
public struct DeviceListView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var onBack: () -> Void
    var onNavigateToAdd: () -> Void
    var onNavigateToPrint: () -> Void

    // Navigation Sheets / Covers
    @State private var activeActionDeviceIds: [String] = []
    @State private var showActionBottomSheet: Bool = false
    @State private var selectedDeviceForDetail: String? = nil
    @State private var selectedDeviceForHistory: String? = nil
    @State private var showScanner: Bool = false
    @State private var showCoachMark: Bool = false

    // Edit Dialog State
    @State private var showEditDialog: Bool = false
    @State private var editTargetDeviceId: String = ""
    @State private var editTen: String = ""
    @State private var editSerial: String = ""

    // Delete Confirm Alert State
    @State private var showDeleteConfirmAlert: Bool = false
    @State private var deviceToDelete: ThietBi? = nil

    // Toast message
    @State private var toastMessage: String? = nil

    public init(
        viewModel: DeviceViewModel,
        onBack: @escaping () -> Void,
        onNavigateToAdd: @escaping () -> Void,
        onNavigateToPrint: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onNavigateToAdd = onNavigateToAdd
        self.onNavigateToPrint = onNavigateToPrint
    }

    private var isAdmin: Bool {
        viewModel.user.isAdmin || viewModel.user.isSuperAdmin
    }

    private var isManager: Bool {
        isAdmin || viewModel.user.isManager
    }

    private var isStaff: Bool {
        !isAdmin && !isManager
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text(isAdmin ? "Quản lý thiết bị hệ thống (\(viewModel.filteredDevices.count))" : "Danh sách thiết bị (\(viewModel.filteredDevices.count))")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            // Action 1: Chọn nhiều (Batch mode)
                            Button(action: {
                                withAnimation {
                                    viewModel.isBatchModeEnabled.toggle()
                                    if !viewModel.isBatchModeEnabled {
                                        viewModel.selectedBatchDeviceIds.removeAll()
                                    }
                                }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: viewModel.isBatchModeEnabled ? "checklist.checked" : "checklist")
                                        .font(.system(size: 18))
                                        .foregroundColor(viewModel.isBatchModeEnabled ? Color.appPrimaryPink : .white)

                                    if viewModel.isBatchModeEnabled && !viewModel.selectedBatchDeviceIds.isEmpty {
                                        Text("\(viewModel.selectedBatchDeviceIds.count)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(3)
                                            .background(Color.appPrimaryPink)
                                            .clipShape(Circle())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                            }

                            // Action 2: In tem QR
                            Button(action: onNavigateToPrint) {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                            }

                            // Action 3: Thêm mới
                            Button(action: onNavigateToAdd) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            // Action 4: Hướng dẫn
                            Button(action: { showCoachMark = true }) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(hex: "#FBBF24"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // Company Banner Ticker directly under TopBar
                        CompanyBannerTickerView()
                    }
                    .background(Color.appTopBarColor)

                    // 2. SEARCH BAR & CONTROLS
                    VStack(spacing: 8) {
                        // Thanh tìm kiếm
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.appTextSecondary)

                            TextField(viewModel.isBatchModeEnabled ? "Đang chọn hàng loạt..." : "Tìm mã thiết bị, tên, serial, phòng ban...", text: $viewModel.searchQuery)
                                .font(.system(size: 14))

                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }

                            Button(action: { showScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))

                        // Batch Mode Indicator Bar
                        if viewModel.isBatchModeEnabled {
                            HStack {
                                Image(systemName: "checklist.checked")
                                    .foregroundColor(Color.appPrimaryPink)
                                    .font(.system(size: 14))
                                Text("Đã chọn \(viewModel.selectedBatchDeviceIds.count) thiết bị")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                Spacer()
                                Button("Bỏ chọn") {
                                    viewModel.selectedBatchDeviceIds.removeAll()
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.gray)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.appPrimaryPink.opacity(0.12))
                            .cornerRadius(8)
                        }

                        // Chuyển đổi chế độ xem 2 cấp: Phòng ban ➔ Đơn vị, Đơn vị ➔ Phòng ban, Phẳng & Thu gọn/Mở tất cả
                        HStack {
                            Picker("Chế độ xem", selection: $viewModel.groupMode) {
                                ForEach(DeviceGroupMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)

                            if viewModel.groupMode != .flat {
                                Button(action: { viewModel.toggleExpandAll() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: viewModel.expandedLevel1.isEmpty ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 11))
                                        Text(viewModel.expandedLevel1.isEmpty ? "Mở hết" : "Thu gọn")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.appPrimaryPink.opacity(0.12))
                                    .foregroundColor(Color.appPrimaryPink)
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(12)

                    // 3. DANH SÁCH THIẾT BỊ
                    if viewModel.isLoading {
                        ProgressView("Đang tải dữ liệu...")
                            .padding(.top, 40)
                        Spacer()
                    } else if viewModel.filteredDevices.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(Color.appTextSecondary)
                            Text("Không tìm thấy thiết bị nào!")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                switch viewModel.groupMode {
                                case .flat:
                                    // DANH SÁCH PHẲNG
                                    ForEach(Array(viewModel.filteredDevices.enumerated()), id: \.element.id) { index, dev in
                                        deviceItemCard(dev, index: index)
                                    }
                                case .deptThenUnit:
                                    // PHÒNG BAN ➔ ĐƠN VỊ
                                    ForEach(Array(viewModel.groupedDeptThenUnit.keys.sorted()), id: \.self) { dept in
                                        let unitMap = viewModel.groupedDeptThenUnit[dept] ?? [:]
                                        let totalInDept = unitMap.values.reduce(0) { $0 + $1.count }
                                        let isL1Expanded = viewModel.expandedLevel1.contains(dept)

                                        VStack(spacing: 6) {
                                            // Level 1 Header
                                            Button(action: { viewModel.toggleLevel1(dept) }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "folder.fill")
                                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                                    Text(dept)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(Color.appTextPrimary)
                                                    Spacer()
                                                    Text("\(totalInDept) TB • \(unitMap.count) ĐV")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.appSecondaryDarkBlue.opacity(0.1))
                                                        .cornerRadius(8)
                                                    Image(systemName: isL1Expanded ? "chevron.down" : "chevron.right")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(Color.appTextSecondary)
                                                }
                                                .padding(12)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                            }

                                            // Level 2 Sub-groups
                                            if isL1Expanded {
                                                ForEach(Array(unitMap.keys.sorted()), id: \.self) { unit in
                                                    let devs = unitMap[unit] ?? []
                                                    let l2Key = "\(dept)__\(unit)"
                                                    let isL2Expanded = viewModel.expandedLevel2.contains(l2Key)

                                                    VStack(spacing: 6) {
                                                        Button(action: { viewModel.toggleLevel2(l2Key) }) {
                                                            HStack(spacing: 6) {
                                                                Image(systemName: "building.2.fill")
                                                                    .foregroundColor(Color.appInfo)
                                                                Text(unit)
                                                                    .font(.system(size: 13, weight: .semibold))
                                                                    .foregroundColor(Color.appTextPrimary)
                                                                Spacer()
                                                                Text("\(devs.count)")
                                                                    .font(.system(size: 11, weight: .bold))
                                                                    .foregroundColor(Color.appInfo)
                                                                Image(systemName: isL2Expanded ? "chevron.down" : "chevron.right")
                                                                    .font(.system(size: 11))
                                                                    .foregroundColor(Color.appTextSecondary)
                                                            }
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 8)
                                                            .background(Color.white.opacity(0.8))
                                                            .cornerRadius(8)
                                                        }
                                                        .padding(.leading, 12)

                                                        if isL2Expanded {
                                                            ForEach(Array(devs.enumerated()), id: \.element.id) { idx, dev in
                                                                deviceItemCard(dev, index: idx)
                                                                    .padding(.leading, 20)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                case .unitThenDept:
                                    // ĐƠN VỊ ➔ PHÒNG BAN
                                    ForEach(Array(viewModel.groupedUnitThenDept.keys.sorted()), id: \.self) { unit in
                                        let deptMap = viewModel.groupedUnitThenDept[unit] ?? [:]
                                        let totalInUnit = deptMap.values.reduce(0) { $0 + $1.count }
                                        let isL1Expanded = viewModel.expandedLevel1.contains(unit)

                                        VStack(spacing: 6) {
                                            Button(action: { viewModel.toggleLevel1(unit) }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "building.2.fill")
                                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                                    Text(unit)
                                                        .font(.system(size: 14, weight: .bold))
                                                        .foregroundColor(Color.appTextPrimary)
                                                    Spacer()
                                                    Text("\(totalInUnit) TB")
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.appSecondaryDarkBlue.opacity(0.1))
                                                        .cornerRadius(8)
                                                    Image(systemName: isL1Expanded ? "chevron.down" : "chevron.right")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(Color.appTextSecondary)
                                                }
                                                .padding(12)
                                                .background(Color.white)
                                                .cornerRadius(12)
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                            }

                                            if isL1Expanded {
                                                ForEach(Array(deptMap.keys.sorted()), id: \.self) { dept in
                                                    let devs = deptMap[dept] ?? []
                                                    let l2Key = "\(unit)__\(dept)"
                                                    let isL2Expanded = viewModel.expandedLevel2.contains(l2Key)

                                                    VStack(spacing: 6) {
                                                        Button(action: { viewModel.toggleLevel2(l2Key) }) {
                                                            HStack(spacing: 6) {
                                                                Image(systemName: "folder.fill")
                                                                    .foregroundColor(Color.appInfo)
                                                                Text(dept)
                                                                    .font(.system(size: 13, weight: .semibold))
                                                                    .foregroundColor(Color.appTextPrimary)
                                                                Spacer()
                                                                Text("\(devs.count)")
                                                                    .font(.system(size: 11, weight: .bold))
                                                                    .foregroundColor(Color.appInfo)
                                                                Image(systemName: isL2Expanded ? "chevron.down" : "chevron.right")
                                                                    .font(.system(size: 11))
                                                                    .foregroundColor(Color.appTextSecondary)
                                                            }
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 8)
                                                            .background(Color.white.opacity(0.8))
                                                            .cornerRadius(8)
                                                        }
                                                        .padding(.leading, 12)

                                                        if isL2Expanded {
                                                            ForEach(Array(devs.enumerated()), id: \.element.id) { idx, dev in
                                                                deviceItemCard(dev, index: idx)
                                                                    .padding(.leading, 20)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .padding(.bottom, viewModel.isBatchModeEnabled && !viewModel.selectedBatchDeviceIds.isEmpty ? 80 : 20)
                        }
                    }
                }

                // 4. FLOATING ACTION BOTTOM BAR FOR BATCH SELECTION
                if viewModel.isBatchModeEnabled && !viewModel.selectedBatchDeviceIds.isEmpty {
                    VStack {
                        HStack {
                            Text("Đã chọn \(viewModel.selectedBatchDeviceIds.count) thiết bị")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                activeActionDeviceIds = Array(viewModel.selectedBatchDeviceIds)
                                showActionBottomSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                    Text("Xử lý hàng loạt")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.appPrimaryPink)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }

                // Toast banner
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(20)
                            .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if viewModel.rawDevices.isEmpty {
                viewModel.fetchDevices()
            }
            viewModel.loadDepartmentsAndUnits()
            viewModel.loadDeviceTypes()
        }
        // SCANNER SHEET
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScanResult: { scannedCode in
                    self.showScanner = false
                    if viewModel.isBatchModeEnabled {
                        viewModel.selectedBatchDeviceIds.insert(scannedCode)
                        showToast("⚡ Đã quét chọn: \(scannedCode)")
                    } else {
                        viewModel.searchQuery = scannedCode
                        showToast("🔍 Tìm kiếm: \(scannedCode)")
                    }
                },
                onDismiss: { self.showScanner = false }
            )
        }
        // MODERN ACTION BOTTOM SHEET
        .sheet(isPresented: $showActionBottomSheet) {
            ModernActionBottomSheetView(
                deviceIds: activeActionDeviceIds,
                viewModel: viewModel,
                onDismiss: { showActionBottomSheet = false },
                onUpdateStatus: { newStatus, note, dvMuon, pbMuon, ngMuon, henTra in
                    for devId in activeActionDeviceIds {
                        viewModel.handleScanAndUpdateStatus(
                            deviceId: devId,
                            moTaInput: "\(newStatus) - \(note)",
                            donViMuon: dvMuon,
                            phongBanMuon: pbMuon,
                            nguoiMuon: ngMuon,
                            ngayHenTra: henTra
                        )
                    }
                    showActionBottomSheet = false
                    viewModel.selectedBatchDeviceIds.removeAll()
                    viewModel.isBatchModeEnabled = false
                    showToast("✅ Đã cập nhật trạng thái \(newStatus) cho \(activeActionDeviceIds.count) thiết bị!")
                }
            )
        }
        // DETAIL VIEW COVER
        .fullScreenCover(isPresented: Binding(
            get: { selectedDeviceForDetail != nil },
            set: { if !$0 { selectedDeviceForDetail = nil } }
        )) {
            if let deviceId = selectedDeviceForDetail {
                DeviceDetailView(viewModel: viewModel, deviceId: deviceId, onBack: { selectedDeviceForDetail = nil })
            }
        }
        // HISTORY VIEW COVER
        .fullScreenCover(isPresented: Binding(
            get: { selectedDeviceForHistory != nil },
            set: { if !$0 { selectedDeviceForHistory = nil } }
        )) {
            if let devId = selectedDeviceForHistory {
                LichSuView(companyId: viewModel.companyId, idToken: viewModel.idToken, thietBiId: devId, onBack: { selectedDeviceForHistory = nil })
            }
        }
        // EDIT DEVICE DIALOG
        .sheet(isPresented: $showEditDialog) {
            editDeviceSheet()
        }
        // DELETE ALERT
        .alert(isPresented: $showDeleteConfirmAlert) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có chắc chắn muốn xóa thiết bị \(deviceToDelete?.ten ?? "") (\(deviceToDelete?.id ?? "")) khỏi hệ thống?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let dev = deviceToDelete {
                        viewModel.deleteDevice(deviceId: dev.id)
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - DEVICE ITEM CARD (1:1 VỚI ANDROID DEVICEITEMCARD)
    private func deviceItemCard(_ device: ThietBi, index: Int) -> some View {
        let isSelectedInBatch = viewModel.selectedBatchDeviceIds.contains(device.id)
        let isLiquidated = device.trangThai == DeviceStatusConstants.statusLiquidated
        let myEmail = viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isOwner = !device.createdBy.isNilOrEmpty && device.createdBy!.lowercased() == myEmail
        let isBorrowedByMe = !device.donViMuon.isNilOrEmpty &&
            (device.donViMuon!.caseInsensitiveCompare(viewModel.user.unitId) == .orderedSame ||
             (!device.phongBanMuon.isNilOrEmpty && device.phongBanMuon!.caseInsensitiveCompare(viewModel.user.departmentId) == .orderedSame))
        let isLentByMe = !device.donViMuon.isNilOrEmpty && !isBorrowedByMe
        let isOnLoan = isBorrowedByMe || isLentByMe
        let canDeleteThis = !isOnLoan && (isAdmin || (isManager && (device.phongBan?.caseInsensitiveCompare(viewModel.user.departmentId) == .orderedSame)) || (isStaff && isOwner))

        return VStack(alignment: .leading, spacing: 8) {
            // HÀNG 1: Tên thiết bị & Nút thao tác
            HStack(alignment: .top) {
                if viewModel.isBatchModeEnabled {
                    Button(action: {
                        if isSelectedInBatch {
                            viewModel.selectedBatchDeviceIds.remove(device.id)
                        } else {
                            viewModel.selectedBatchDeviceIds.insert(device.id)
                        }
                    }) {
                        Image(systemName: isSelectedInBatch ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isSelectedInBatch ? Color.appPrimaryPink : Color.gray)
                    }
                    .padding(.trailing, 4)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(index + 1). \(device.ten)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(2)
                }

                Spacer()

                // Nút thao tác góc trên
                HStack(spacing: 4) {
                    // Lịch sử
                    Button(action: { selectedDeviceForHistory = device.id }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(width: 30, height: 30)
                    }

                    // Đổi trạng thái (nếu không phải đang mượn và chưa thanh lý)
                    if !isBorrowedByMe && !isOnLoan {
                        Button(action: {
                            activeActionDeviceIds = [device.id]
                            showActionBottomSheet = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 15))
                                .foregroundColor(isLiquidated ? Color.gray : Color.appPrimaryPink)
                                .frame(width: 30, height: 30)
                        }
                        .disabled(isLiquidated)
                    }

                    // Sửa (nếu có quyền)
                    Button(action: {
                        editTargetDeviceId = device.id
                        editTen = device.ten
                        editSerial = device.id
                        showEditDialog = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 15))
                            .foregroundColor(isLiquidated ? Color.gray : Color.appSecondaryDarkBlue)
                            .frame(width: 30, height: 30)
                    }
                    .disabled(isLiquidated)

                    // Xóa
                    if canDeleteThis {
                        Button(action: {
                            deviceToDelete = device
                            showDeleteConfirmAlert = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 15))
                                .foregroundColor(Color.appDanger)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
            }

            // HÀNG 2: MÃ THIẾT BỊ + TRẠNG THÁI + NÚT TRẢ/THU HỒI
            HStack(spacing: 8) {
                // 1. Tag Mã thiết bị (Click để copy)
                Button(action: {
                    UIPasteboard.general.string = device.id
                    showToast("📋 Đã sao chép: \(device.id)")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#64748B"))
                        Text(device.id)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#0F172A"))
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#94A3B8"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#F1F5F9"))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }

                // 2. Badge Trạng thái
                let badgeText: String = {
                    if isBorrowedByMe {
                        return "Đang mượn tạm (của: \(device.tenDonVi))"
                    } else if isLentByMe {
                        let targetDesc = !(device.donViMuon?.isEmpty ?? true) ? device.donViMuon! : (device.nguoiMuon ?? "")
                        return "Đang cho mượn (cho: \(targetDesc))"
                    } else {
                        return device.statusNormalized
                    }
                }()

                Text(badgeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(device.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(device.statusColor.opacity(0.12))
                    .cornerRadius(6)

                Spacer()

                // 3. Nút Trả máy / Thu hồi
                if isBorrowedByMe {
                    Button(action: { viewModel.returnBorrowedDevice(deviceId: device.id) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Trả máy")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#2563EB"))
                        .cornerRadius(6)
                    }
                } else if isLentByMe {
                    Button(action: { viewModel.returnBorrowedDevice(deviceId: device.id) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Thu hồi")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#9333EA"))
                        .cornerRadius(6)
                    }
                }
            }

            // HÀNG 3: Đơn vị & Phòng ban
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appPrimaryPink)
                Text("Đơn vị: \(device.tenDonVi)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appPrimaryPink)
                    .lineLimit(1)
            }

            if let pb = device.phongBan, !pb.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.8))
                    Text("Phòng ban: \(pb)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.8))
                        .lineLimit(1)
                }
            }

            // HÀNG 4: Ghi chú
            if let moTa = device.moTa, !moTa.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "note.text")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#E65100"))
                    Text("Ghi chú: \(moTa)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#E65100"))
                        .lineLimit(3)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FFF3E0"))
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(isSelectedInBatch ? Color.appPrimaryPink.opacity(0.06) : Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelectedInBatch ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: isSelectedInBatch ? 1.5 : 1)
        )
        .opacity(isLiquidated ? 0.5 : 1.0)
    }

    // MARK: - EDIT DEVICE SHEET
    private func editDeviceSheet() -> some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tên thiết bị *")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    TextField("Tên thiết bị", text: $editTen)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mã thiết bị (Serial) *")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    TextField("Số serial", text: $editSerial)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }

                Spacer()

                Button(action: {
                    viewModel.updateDeviceInfo(oldId: editTargetDeviceId, newTen: editTen, newId: editSerial)
                    showEditDialog = false
                    showToast("✅ Đã cập nhật thiết bị")
                }) {
                    Text("Lưu thay đổi")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(Color.appBackground)
            .navigationTitle("Chỉnh sửa thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { showEditDialog = false }
                }
            }
        }
    }

    private func showToast(_ msg: String) {
        withAnimation {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}

// MARK: - MODERN ACTION BOTTOM SHEET VIEW (1:1 VỚI MODERNACTIONBOTTOMSHEET TRÊN ANDROID)
public struct ModernActionBottomSheetView: View {
    var deviceIds: [String]
    @ObservedObject var viewModel: DeviceViewModel
    var onDismiss: () -> Void
    var onUpdateStatus: (String, String, String?, String?, String?, String?) -> Void

    @State private var selectedStatus: String = DeviceStatusConstants.statusInStock
    @State private var actionNote: String = ""

    // Loan details
    @State private var donViMuon: String = ""
    @State private var phongBanMuon: String = ""
    @State private var nguoiMuon: String = ""
    @State private var ngayHenTra: String = ""

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Áp dụng cho \(deviceIds.count) thiết bị đã chọn:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTextSecondary)

                    // 1. CHỌN TRẠNG THÁI MỚI
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Trạng thái mới *")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        Menu {
                            ForEach(DeviceStatusConstants.allStatuses, id: \.self) { st in
                                Button(st) { selectedStatus = st }
                            }
                        } label: {
                            HStack {
                                Text(selectedStatus)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DeviceStatusConstants.color(for: selectedStatus))
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }

                    // 2. GHI CHÚ
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ghi chú thao tác")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        TextField("Nhập lý do chuyển trạng thái, thông tin bổ sung...", text: $actionNote)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // 3. NẾU CHỌN CHO MƯỢN
                    if selectedStatus == DeviceStatusConstants.statusOnLoan {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📋 Thông tin bên tiếp nhận mượn")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "#7E22CE"))

                            // Đơn vị mượn
                            Menu {
                                ForEach(viewModel.units, id: \.self) { u in
                                    Button(u) {
                                        donViMuon = u
                                        if let autoDept = viewModel.unitToDeptMap[u.lowercased()], !autoDept.isEmpty {
                                            phongBanMuon = autoDept
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(donViMuon.isEmpty ? "Chọn đơn vị mượn..." : donViMuon)
                                        .font(.system(size: 14))
                                        .foregroundColor(donViMuon.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                            }

                            TextField("Phòng ban mượn...", text: $phongBanMuon)
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))

                            TextField("Người mượn (Tên/SĐT)...", text: $nguoiMuon)
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))

                            TextField("Ngày hẹn trả (dd/MM/yyyy)...", text: $ngayHenTra)
                                .padding(10)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                        }
                        .padding(12)
                        .background(Color(hex: "#F3E8FF").opacity(0.6))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                    }

                    Spacer().frame(height: 20)

                    // 4. XÁC NHẬN
                    Button(action: {
                        onUpdateStatus(
                            selectedStatus,
                            actionNote,
                            donViMuon.isEmpty ? nil : donViMuon,
                            phongBanMuon.isEmpty ? nil : phongBanMuon,
                            nguoiMuon.isEmpty ? nil : nguoiMuon,
                            ngayHenTra.isEmpty ? nil : ngayHenTra
                        )
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Xác nhận cập nhật")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Cập nhật trạng thái")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { onDismiss() }
                }
            }
        }
    }
}

private extension Optional where Wrapped == String {
    var isNilOrEmpty: Bool {
        return self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}
