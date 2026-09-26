import SwiftUI

// MARK: - MÀN HÌNH DANH SÁCH THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI DEVICELISTSCREEN.KT TRÊN ANDROID)
public struct DeviceListView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var onBack: () -> Void
    var onNavigateToAdd: () -> Void
    var onNavigateToPrint: () -> Void

    @State private var selectedDeviceForStatus: ThietBi? = nil
    @State private var showStatusActionSheet: Bool = false
    @State private var showDeleteConfirmAlert: Bool = false
    @State private var deviceToDelete: ThietBi? = nil
    @State private var selectedDeviceForDetail: String? = nil

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

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
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

                            Text("Quản lý thiết bị (\(viewModel.filteredDevices.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // Nút Chọn nhiều (Batch)
                            Button(action: {
                                withAnimation {
                                    viewModel.isBatchModeEnabled.toggle()
                                    if !viewModel.isBatchModeEnabled {
                                        viewModel.selectedBatchDeviceIds.removeAll()
                                    }
                                }
                            }) {
                                Image(systemName: viewModel.isBatchModeEnabled ? "checkmark.circle.fill" : "checklist")
                                    .font(.system(size: 18))
                                    .foregroundColor(viewModel.isBatchModeEnabled ? Color.appPrimaryPink : .white)
                            }

                            // Nút In tem
                            Button(action: onNavigateToPrint) {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }

                            // Nút Thêm mới
                            Button(action: onNavigateToAdd) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // 2. SEARCH BAR & TOOLBAR
                VStack(spacing: 8) {
                    // Thanh tìm kiếm
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)

                        TextField("Tìm mã thiết bị, tên, serial, phòng ban...", text: $viewModel.searchQuery)
                            .font(.system(size: 14))

                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))

                    // Toolbar chuyển chế độ xem & Mở tất cả
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
                            if viewModel.groupMode == .flat {
                                // DANH SÁCH PHẲNG
                                ForEach(viewModel.filteredDevices) { dev in
                                    Button(action: { selectedDeviceForDetail = dev.id }) { deviceCard(dev) }.buttonStyle(PlainButtonStyle())
                                }
                            } else {
                                // DANH SÁCH ACCORDION 2 CẤP
                                ForEach(Array(viewModel.groupedDeptThenUnit.keys.sorted()), id: \.self) { dept in
                                    let unitMap = viewModel.groupedDeptThenUnit[dept] ?? [:]
                                    let totalInDept = unitMap.values.reduce(0) { $0 + $1.count }
                                    let isL1Expanded = viewModel.expandedLevel1.contains(dept)

                                    // LEVEL 1: PHÒNG BAN
                                    VStack(spacing: 6) {
                                        Button(action: { viewModel.toggleLevel1(dept) }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "folder.fill")
                                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                                Text(dept)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color.appTextPrimary)

                                                Spacer()

                                                Text("\(totalInDept) thiết bị")
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

                                        // LEVEL 2: ĐƠN VỊ
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
                                                        }
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(Color.appBackground)
                                                        .cornerRadius(8)
                                                    }
                                                    .padding(.leading, 12)

                                                    // LEVEL 3: THIẾT BỊ
                                                    if isL2Expanded {
                                                        ForEach(devs) { dev in
                                                            Button(action: { selectedDeviceForDetail = dev.id }) { deviceCard(dev) }.buttonStyle(PlainButtonStyle())
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
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    .onAppear {
            if viewModel.rawDevices.isEmpty {
                viewModel.fetchDevices()
            }
        }
        .actionSheet(isPresented: $showStatusActionSheet) {
            ActionSheet(
                title: Text("Cập nhật trạng thái thiết bị"),
                message: Text(selectedDeviceForStatus?.ten ?? ""),
                buttons: DeviceStatusConstants.allStatuses.map { st in
                    .default(Text(st)) {
                        if let dev = selectedDeviceForStatus {
                            viewModel.updateDeviceStatus(deviceId: dev.id, newStatus: st)
                        }
                    }
                } + [.cancel()]
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedDeviceForDetail != nil },
            set: { if !$0 { selectedDeviceForDetail = nil } }
        )) {
            if let deviceId = selectedDeviceForDetail {
                DeviceDetailView(viewModel: viewModel, deviceId: deviceId, onBack: { selectedDeviceForDetail = nil })
            }
        }
        .alert(isPresented: $showDeleteConfirmAlert) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có chắc chắn muốn xóa thiết bị \(deviceToDelete?.ten ?? "") khỏi hệ thống?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let dev = deviceToDelete {
                        viewModel.deleteDevice(deviceId: dev.id)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func deviceCard(_ dev: ThietBi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dev.ten)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Mã: \(dev.id)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Spacer()

                // Trạng thái chuẩn màu
                Text(dev.statusNormalized)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(dev.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(dev.statusColor.opacity(0.12))
                    .cornerRadius(8)
            }

            HStack(spacing: 12) {
                if !dev.tenDonVi.isEmpty {
                    Label(dev.tenDonVi, systemImage: "building.2")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                if let pb = dev.phongBan, !pb.isEmpty {
                    Label(pb, systemImage: "folder")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            Divider()

            HStack {
                Button(action: {
                    selectedDeviceForStatus = dev
                    showStatusActionSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Đổi trạng thái")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Spacer()

                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                    Button(action: {
                        deviceToDelete = dev
                        showDeleteConfirmAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(Color.appDanger)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
}
