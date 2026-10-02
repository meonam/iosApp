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
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 4) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }

                            Text("Danh sách thiết bị")
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
                                .frame(width: 40, height: 40)
                                .contentShape(Rectangle())
                            }

                            // Action 2: In tem QR
                            Button(action: onNavigateToPrint) {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }

                            // Action 3: Thêm mới
                            Button(action: onNavigateToAdd) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }

                            // Action 4: Hướng dẫn
                            Button(action: { showCoachMark = true }) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 17))
                                    .foregroundColor(Color(hex: "#FBBF24"))
                                    .frame(width: 40, height: 40)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)

                        // Company Banner Ticker directly under TopBar
                        CompanyBannerTickerView()
                    }
                    .background(Color.appTopBarColor)

                    // 2. SEARCH BAR & CONTROLS (CHUẨN 100% ANDROID)
                    VStack(spacing: 8) {
                        // Thanh tìm kiếm
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.appTextSecondary)

                            TextField(viewModel.isBatchModeEnabled ? "Đang chọn hàng loạt..." : "Tìm kiếm...", text: $viewModel.searchQuery)
                                .font(.system(size: 14))

                            if !viewModel.searchQuery.isEmpty {
                                Button(action: { viewModel.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }

                            Button(action: { showScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                        }
                        .padding(10)
                        .background(Color.appSurface)
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

                        // Toolbar 3 nút điều khiển chuẩn Android: Chế độ nhóm ➔ Danh sách phẳng ➔ Thu gọn/Mở tất cả
                        HStack(spacing: 8) {
                            // Option 1: Nhóm Phòng ban ➔ Đơn vị hoặc Đơn vị ➔ Phòng ban
                            let isGrouped = viewModel.groupMode != .flat
                            let groupLabel: String = {
                                if isAdmin || isManager {
                                    return viewModel.groupMode == .unitThenDept ? "Đơn vị ➔ PB" : "Phòng ban ➔ ĐV"
                                } else {
                                    return viewModel.groupMode == .unitThenDept ? "Theo Phòng ban" : "Theo Đơn vị"
                                }
                            }()

                            Button(action: {
                                withAnimation {
                                    if viewModel.groupMode == .deptThenUnit {
                                        viewModel.groupMode = .unitThenDept
                                    } else {
                                        viewModel.groupMode = .deptThenUnit
                                    }
                                    viewModel.collapseAllGroups()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: viewModel.groupMode == .unitThenDept ? "building.2.fill" : "square.grid.2x2.fill")
                                        .font(.system(size: 13))
                                    Text(groupLabel)
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isGrouped ? Color.appPrimaryPink.opacity(0.12) : Color.gray.opacity(0.1))
                                .foregroundColor(isGrouped ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isGrouped ? Color.appPrimaryPink.opacity(0.4) : Color(hex: "#DDE2E5"), lineWidth: 1)
                                )
                            }

                            // Option 2: Danh sách phẳng
                            Button(action: {
                                withAnimation {
                                    viewModel.groupMode = .flat
                                }
                            }) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(viewModel.groupMode == .flat ? Color.appPrimaryPink.opacity(0.12) : Color.gray.opacity(0.1))
                                    .foregroundColor(viewModel.groupMode == .flat ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(viewModel.groupMode == .flat ? Color.appPrimaryPink.opacity(0.4) : Color(hex: "#DDE2E5"), lineWidth: 1)
                                    )
                            }

                            Spacer()

                            // Option 3: Thu gọn / Mở tất cả (Nút viền hồng chuẩn Android)
                            if viewModel.groupMode != .flat {
                                Button(action: {
                                    withAnimation {
                                        viewModel.toggleExpandAll()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: viewModel.isAllExpanded ? "xmark" : "arrow.down.right.and.arrow.up.left")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(viewModel.isAllExpanded ? "Thu gọn" : "Mở tất cả")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.appPrimaryPink.opacity(0.08))
                                    .foregroundColor(Color.appPrimaryPink)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.appPrimaryPink.opacity(0.35), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(12)

                    // 3. DANH SÁCH THIẾT BỊ (ĐỒNG BỘ 1:1 THEO ANDROID TREE LIST)
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
                                        let isL1Expanded = viewModel.searchQuery.isEmpty ? viewModel.expandedLevel1.contains(dept) : true

                                        VStack(spacing: 6) {
                                            // Level 1 Header (Phòng Ban)
                                            level1HeaderCard(
                                                title: dept,
                                                subText: "\(totalInDept) thiết bị • \(unitMap.count) đơn vị",
                                                iconName: "square.grid.2x2.fill",
                                                badgeCount: totalL1DevicesCount(unitMap),
                                                isExpanded: isL1Expanded,
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        viewModel.toggleLevel1(dept)
                                                    }
                                                }
                                            )

                                            // Level 2 Sub-groups (Đơn vị)
                                            if isL1Expanded {
                                                ForEach(Array(unitMap.keys.sorted()), id: \.self) { unit in
                                                    let devs = unitMap[unit] ?? []
                                                    let l2Key = "\(dept)__\(unit)"
                                                    let isL2Expanded = viewModel.searchQuery.isEmpty ? viewModel.expandedLevel2.contains(l2Key) : true

                                                    VStack(spacing: 6) {
                                                        level2HeaderCard(
                                                            title: unit,
                                                            deviceCount: devs.count,
                                                            iconName: "building.2.fill",
                                                            isExpanded: isL2Expanded,
                                                            onToggle: {
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    viewModel.toggleLevel2(l2Key)
                                                                }
                                                            }
                                                        )

                                                        if isL2Expanded {
                                                            ForEach(Array(devs.enumerated()), id: \.element.id) { idx, dev in
                                                                deviceItemCard(dev, index: idx)
                                                                    .padding(.leading, 24)
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
                                        let isL1Expanded = viewModel.searchQuery.isEmpty ? viewModel.expandedLevel1.contains(unit) : true

                                        VStack(spacing: 6) {
                                            // Level 1 Header (Đơn vị)
                                            level1HeaderCard(
                                                title: unit,
                                                subText: "\(totalInUnit) thiết bị • \(deptMap.count) phòng ban",
                                                iconName: "building.2.fill",
                                                badgeCount: totalInUnit,
                                                isExpanded: isL1Expanded,
                                                onToggle: {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        viewModel.toggleLevel1(unit)
                                                    }
                                                }
                                            )

                                            if isL1Expanded {
                                                ForEach(Array(deptMap.keys.sorted()), id: \.self) { dept in
                                                    let devs = deptMap[dept] ?? []
                                                    let l2Key = "\(unit)__\(dept)"
                                                    let isL2Expanded = viewModel.searchQuery.isEmpty ? viewModel.expandedLevel2.contains(l2Key) : true

                                                    VStack(spacing: 6) {
                                                        level2HeaderCard(
                                                            title: dept,
                                                            deviceCount: devs.count,
                                                            iconName: "square.grid.2x2.fill",
                                                            isExpanded: isL2Expanded,
                                                            onToggle: {
                                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                                    viewModel.toggleLevel2(l2Key)
                                                                }
                                                            }
                                                        )

                                                        if isL2Expanded {
                                                            ForEach(Array(devs.enumerated()), id: \.element.id) { idx, dev in
                                                                deviceItemCard(dev, index: idx)
                                                                    .padding(.leading, 24)
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
                        .refreshable {
                            viewModel.fetchDevices(isRefresh: true)
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
                        .background(Color.appDarkButtonBackground)
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
            viewModel.fetchDevices(isRefresh: true)
            viewModel.loadDepartmentsAndUnits()
            viewModel.loadDeviceTypes()
        }
        // SCANNER SHEET (Tự động tra cứu thiết bị và điều hướng 1:1 Android)
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                viewModel: viewModel,
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
                onDismiss: { self.showScanner = false },
                onNavigateToDetail: { devId in
                    self.showScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.selectedDeviceForDetail = devId
                    }
                },
                onNavigateToAdd: { _ in
                    self.showScanner = false
                    self.onNavigateToAdd()
                }
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

    // MARK: - LEVEL 1 GROUP HEADER (1:1 VỚI ANDROID LEVEL1GROUPHEADER)
    private func totalL1DevicesCount(_ unitMap: [String: [ThietBi]]) -> Int {
        unitMap.values.reduce(0) { $0 + $1.count }
    }

    private func level1HeaderCard(
        title: String,
        subText: String,
        iconName: String,
        badgeCount: Int,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon hộp vuông bo góc (Đổi sang nền hồng khi mở như Android)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isExpanded ? Color.appPrimaryPink : Color.appSecondaryDarkBlue.opacity(0.1))
                        .frame(width: 38, height: 38)

                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isExpanded ? .white : Color.appSecondaryDarkBlue)
                }

                // Tiêu đề & Số lượng con
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(1)

                    Text(subText)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)
                }

                Spacer()

                // Badge số lượng (Hồng khi mở, xám khi đóng)
                Text("\(badgeCount)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isExpanded ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isExpanded ? Color.appPrimaryPink.opacity(0.15) : Color(hex: "#F1F5F9"))
                    .cornerRadius(8)

                // Chevron mũi tên
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isExpanded ? Color.appPrimaryPink : Color.gray)
                    .frame(width: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isExpanded ? Color.appPrimaryPink.opacity(0.08) : Color.appSurface)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isExpanded ? Color.appPrimaryPink.opacity(0.5) : Color.appCardBorder, lineWidth: isExpanded ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - LEVEL 2 SUB-GROUP HEADER (1:1 VỚI ANDROID LEVEL2SUBGROUPHEADER)
    private func level2HeaderCard(
        title: String,
        deviceCount: Int,
        iconName: String,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Icon tòa nhà
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isExpanded ? Color.appSecondaryDarkBlue.opacity(0.15) : Color.appCardBorder)
                        .frame(width: 28, height: 28)

                    Image(systemName: iconName)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                // Tên đơn vị / phòng ban con
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(1)

                    Text("\(deviceCount) thiết bị")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Badge số lượng nền trắng viền xám
                Text("\(deviceCount)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appSurface)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.appCardBorder, lineWidth: 1)
                    )

                // Chevron mũi tên
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .frame(width: 16)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isExpanded ? Color.appSecondaryDarkBlue.opacity(0.08) : Color(hex: "#F8FAFC"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isExpanded ? Color.appSecondaryDarkBlue.opacity(0.3) : Color(hex: "#E2E8F0"), lineWidth: 1)
            )
            .padding(.leading, 14)
        }
        .buttonStyle(PlainButtonStyle())
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
            // HÀNG 1: Tên thiết bị (trái) & Nút thao tác (phải)
            HStack(alignment: .center) {
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

                Text("\(index + 1). \(device.ten)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .lineLimit(2)

                Spacer()

                // Nút thao tác góc trên
                HStack(spacing: 4) {
                    // Lịch sử
                    Button(action: { selectedDeviceForHistory = device.id }) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(width: 32, height: 32)
                    }

                    // Đổi trạng thái (nếu không phải đang mượn và chưa thanh lý)
                    if !isBorrowedByMe && !isOnLoan {
                        Button(action: {
                            activeActionDeviceIds = [device.id]
                            showActionBottomSheet = true
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(isLiquidated ? Color.gray : Color.appPrimaryPink)
                                .frame(width: 32, height: 32)
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
                            .font(.system(size: 16))
                            .foregroundColor(isLiquidated ? Color.gray : Color.appSecondaryDarkBlue)
                            .frame(width: 32, height: 32)
                    }
                    .disabled(isLiquidated)

                    // Xóa
                    if canDeleteThis {
                        Button(action: {
                            deviceToDelete = device
                            showDeleteConfirmAlert = true
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(Color.appDanger)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
            }

            // HÀNG 2: MÃ THIẾT BỊ (BARCODE) + TRẠNG THÁI + NÚT TRẢ/THU HỒI
            HStack(spacing: 8) {
                // 1. Tag Mã thiết bị (Click để copy)
                Button(action: {
                    UIPasteboard.general.string = device.id
                    showToast("📋 Đã sao chép: \(device.id)")
                }) {
                    HStack(spacing: 5) {
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

                // 2. Badge Trạng thái (Màu sắc chuẩn 1:1 Android)
                let normStatus = device.statusNormalized
                let badgeText: String = {
                    if isBorrowedByMe {
                        return "Đang mượn tạm (của: \(device.tenDonVi))"
                    } else if isLentByMe {
                        let targetDesc = !(device.donViMuon?.isEmpty ?? true) ? device.donViMuon! : (device.nguoiMuon ?? "")
                        return "Đang cho mượn (cho: \(targetDesc))"
                    } else {
                        return normStatus
                    }
                }()

                let (badgeBg, badgeFg): (Color, Color) = {
                    let lower = normStatus.lowercased()
                    if isBorrowedByMe {
                        return (Color(hex: "#DBEAFE"), Color(hex: "#1D4ED8"))
                    } else if isLentByMe {
                        return (Color(hex: "#F3E8FF"), Color(hex: "#7E22CE"))
                    } else if lower.contains("mới") || lower.contains("moi") {
                        return (Color(hex: "#CCFBF1"), Color(hex: "#0F766E"))
                    } else if lower.contains("trong kho") || lower.contains("sẵn sàng") || lower.contains("san sang") {
                        return (Color(hex: "#DCFCE7"), Color(hex: "#15803D"))
                    } else if lower.contains("sử dụng") || lower.contains("su dung") {
                        return (Color(hex: "#DBEAFE"), Color(hex: "#1D4ED8"))
                    } else if lower.contains("mượn") || lower.contains("muon") {
                        return (Color(hex: "#F3E8FF"), Color(hex: "#7E22CE"))
                    } else if lower.contains("bảo hành") || lower.contains("sửa") || lower.contains("bao hanh") {
                        return (Color(hex: "#FFEDD5"), Color(hex: "#C2410C"))
                    } else if lower.contains("hỏng") || lower.contains("xử lý") || lower.contains("hong") {
                        return (Color(hex: "#FEE2E2"), Color(hex: "#B91C1C"))
                    } else if lower.contains("thanh lý") || lower.contains("thanh ly") {
                        return (Color(hex: "#F1F5F9"), Color(hex: "#475569"))
                    } else {
                        return (Color(hex: "#DCFCE7"), Color(hex: "#15803D"))
                    }
                }()

                Text(badgeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(badgeFg)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(badgeBg)
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

            // HÀNG 3: Đơn vị (Màu hồng chuẩn Android)
            Text("🏢 Đơn vị: \(device.tenDonVi)")
                .font(.system(size: 12))
                .foregroundColor(Color.appPrimaryPink)
                .lineLimit(1)

            // HÀNG 4: Phòng ban chuyên môn (Màu xanh đen chuẩn Android)
            if let pb = device.phongBan, !pb.isEmpty {
                Text("🏛️ Phòng ban chuyên môn: \(pb)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.8))
                    .lineLimit(1)
            }

            // HÀNG 5: Ghi chú nếu có
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
        .background(isSelectedInBatch ? Color.appPrimaryPink.opacity(0.06) : Color.appSurface)
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
                        .foregroundColor(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Mã thiết bị (Serial) *")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    TextField("Số serial", text: $editSerial)
                        .foregroundColor(Color.appTextPrimary)
                        .padding(12)
                        .background(Color.appSurface)
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
                            .background(Color.appSurface)
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
                            .foregroundColor(Color.appTextPrimary)
                            .padding(12)
                            .background(Color.appSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    }

                    // 3. NẾU CHỌN CHO MƯỢN
                    if selectedStatus == DeviceStatusConstants.statusOnLoan {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📋 Thông tin bên tiếp nhận mượn")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.dynamic(light: "#7E22CE", dark: "#D8B4FE"))

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
                                .background(Color.appSurface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                            }

                            TextField("Phòng ban mượn...", text: $phongBanMuon)
                                .foregroundColor(Color.appTextPrimary)
                                .padding(10)
                                .background(Color.appSurface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))

                            TextField("Người mượn (Tên/SĐT)...", text: $nguoiMuon)
                                .foregroundColor(Color.appTextPrimary)
                                .padding(10)
                                .background(Color.appSurface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))

                            TextField("Ngày hẹn trả (dd/MM/yyyy)...", text: $ngayHenTra)
                                .foregroundColor(Color.appTextPrimary)
                                .padding(10)
                                .background(Color.appSurface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                        }
                        .padding(12)
                        .background(Color.dynamic(light: "#F3E8FF", dark: "#3B1B54").opacity(0.6))
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
