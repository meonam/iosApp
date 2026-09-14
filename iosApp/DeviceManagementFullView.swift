import SwiftUI
import UIKit

public enum DeviceGroupMode: String, CaseIterable, Identifiable {
    case deptThenUnit = "Phòng ban -> Đơn vị"
    case unitThenDept = "Đơn vị -> Phòng ban"
    case flat = "Danh sách phẳng"

    public var id: String { rawValue }
}

// MARK: - MÀN HÌNH QUẢN LÝ THIẾT BỊ NÂNG CAO (DeviceListScreen.kt)
public struct DeviceManagementFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @State private var groupMode: DeviceGroupMode = .flat
    @State private var selectedStatusFilter: String = "ALL"
    @State private var isBatchMode: Bool = false
    @State private var selectedDeviceIds: Set<String> = []

    // Expanded accordion states
    @State private var expandedGroups: Set<String> = []

    // Sheets & Dialogs
    @State private var selectedDeviceForDetail: DeviceItem? = nil
    @State private var showPrintScreen: Bool = false
    @State private var showAddDeviceSheet: Bool = false

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    var filteredDevices: [DeviceItem] {
        firebase.devices.filter { d in
            let matchSearch = searchQuery.isEmpty ||
                d.name.localizedCaseInsensitiveContains(searchQuery) ||
                d.code.localizedCaseInsensitiveContains(searchQuery) ||
                d.serialNumber.localizedCaseInsensitiveContains(searchQuery) ||
                d.unit.localizedCaseInsensitiveContains(searchQuery) ||
                d.department.localizedCaseInsensitiveContains(searchQuery)

            let matchStatus = selectedStatusFilter == "ALL" ||
                d.status.localizedCaseInsensitiveContains(selectedStatusFilter)

            return matchSearch && matchStatus
        }
    }

    // Grouping dictionary
    var groupedByDept: [String: [DeviceItem]] {
        Dictionary(grouping: filteredDevices) { $0.department.isEmpty ? "Chưa gán phòng ban" : $0.department }
    }

    var groupedByUnit: [String: [DeviceItem]] {
        Dictionary(grouping: filteredDevices) { $0.unit.isEmpty ? "Trụ sở Co.op" : $0.unit }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header Filters & Grouping
                VStack(spacing: 8) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Tìm mã TB, tên, serial, quầy...", text: $searchQuery)
                            .font(.system(size: 14))
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(9)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                    // Grouping Picker & Batch Mode Toggle
                    HStack {
                        Picker("Chế độ xem", selection: $groupMode) {
                            ForEach(DeviceGroupMode.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(action: {
                            withAnimation {
                                isBatchMode.toggle()
                                if !isBatchMode { selectedDeviceIds.removeAll() }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isBatchMode ? "checkmark.circle.fill" : "checklist")
                                Text(isBatchMode ? "Hủy" : "Chọn")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isBatchMode ? Color.appPrimaryPink : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(isBatchMode ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }

                    // Status filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            statusFilterChip("Tất cả", tag: "ALL")
                            statusFilterChip("Mới nhập", tag: "mới")
                            statusFilterChip("Đang sử dụng", tag: "sử dụng")
                            statusFilterChip("Sửa chữa", tag: "sửa")
                            statusFilterChip("Hỏng", tag: "hỏng")
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))

                // Content List
                ScrollView {
                    VStack(spacing: 12) {
                        switch groupMode {
                        case .flat:
                            flatList
                        case .deptThenUnit:
                            deptGroupedList
                        case .unitThenDept:
                            unitGroupedList
                        }
                    }
                    .padding(12)
                }

                // Batch Actions Bar (When batch mode is on)
                if isBatchMode && !selectedDeviceIds.isEmpty {
                    HStack(spacing: 12) {
                        Text("Đã chọn: \(selectedDeviceIds.count) TB")
                            .font(.headline.bold())
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {
                            showPrintScreen = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "printer.fill")
                                Text("In tem nhãn")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .foregroundColor(.appSecondaryDarkBlue)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appSecondaryDarkBlue)
                    .transition(.move(edge: .bottom))
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Thiết Bị (\(firebase.devices.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showAddDeviceSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.appPrimaryPink)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .sheet(item: $selectedDeviceForDetail) { dev in
                DeviceDetailView(device: dev, onDismiss: { selectedDeviceForDetail = nil })
                    .environmentObject(firebase)
            }
            .sheet(isPresented: $showPrintScreen) {
                PrintScreenView(device: filteredDevices.first { selectedDeviceIds.contains($0.id) })
            }
            .sheet(isPresented: $showAddDeviceSheet) {
                AddDeviceModalView(onDismiss: { showAddDeviceSheet = false })
                    .environmentObject(firebase)
            }
            .onAppear {
                Task { await firebase.loadDevices() }
            }
        }
    }

    // LIST 1: FLAT LIST
    @ViewBuilder
    private var flatList: some View {
        ForEach(filteredDevices) { dev in
            deviceCardItem(dev)
        }
    }

    // LIST 2: DEPT GROUPED LIST
    @ViewBuilder
    private var deptGroupedList: some View {
        ForEach(Array(groupedByDept.keys.sorted()), id: \.self) { deptName in
            let items = groupedByDept[deptName] ?? []
            let isExp = expandedGroups.contains(deptName)

            VStack(spacing: 8) {
                Button(action: {
                    withAnimation {
                        if isExp { expandedGroups.remove(deptName) }
                        else { expandedGroups.insert(deptName) }
                    }
                }) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.appSecondaryDarkBlue)
                        Text(deptName)
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Text("\(items.count) TB")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Image(systemName: isExp ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if isExp {
                    VStack(spacing: 8) {
                        ForEach(items) { dev in
                            deviceCardItem(dev)
                        }
                    }
                    .padding(.leading, 8)
                }
            }
        }
    }

    // LIST 3: UNIT GROUPED LIST
    @ViewBuilder
    private var unitGroupedList: some View {
        ForEach(Array(groupedByUnit.keys.sorted()), id: \.self) { unitName in
            let items = groupedByUnit[unitName] ?? []
            let isExp = expandedGroups.contains(unitName)

            VStack(spacing: 8) {
                Button(action: {
                    withAnimation {
                        if isExp { expandedGroups.remove(unitName) }
                        else { expandedGroups.insert(unitName) }
                    }
                }) {
                    HStack {
                        Image(systemName: "storefront.fill")
                            .foregroundColor(.appPrimaryPink)
                        Text(unitName)
                            .font(.headline)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        Text("\(items.count) TB")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Image(systemName: isExp ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)

                if isExp {
                    VStack(spacing: 8) {
                        ForEach(items) { dev in
                            deviceCardItem(dev)
                        }
                    }
                    .padding(.leading, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func deviceCardItem(_ dev: DeviceItem) -> some View {
        HStack(spacing: 12) {
            if isBatchMode {
                Button(action: {
                    if selectedDeviceIds.contains(dev.id) {
                        selectedDeviceIds.remove(dev.id)
                    } else {
                        selectedDeviceIds.insert(dev.id)
                    }
                }) {
                    Image(systemName: selectedDeviceIds.contains(dev.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(selectedDeviceIds.contains(dev.id) ? .appPrimaryPink : .gray)
                }
            }

            // Device Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#EFF6FF"))
                    .frame(width: 48, height: 48)
                Image(systemName: dev.iconName.isEmpty ? "desktopcomputer" : dev.iconName)
                    .font(.system(size: 22))
                    .foregroundColor(.appSecondaryDarkBlue)
            }

            // Info
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(dev.code)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.appPrimaryPink)
                    Spacer()
                    Text(dev.status)
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor(dev.status).opacity(0.12))
                        .foregroundColor(statusColor(dev.status))
                        .clipShape(Capsule())
                }

                Text(dev.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(1)

                HStack {
                    Text(dev.unit.isEmpty ? "Co.opmart" : dev.unit)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                    Spacer()
                    if !dev.serialNumber.isEmpty {
                        Text("SN: \(dev.serialNumber)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .onTapGesture {
            if isBatchMode {
                if selectedDeviceIds.contains(dev.id) {
                    selectedDeviceIds.remove(dev.id)
                } else {
                    selectedDeviceIds.insert(dev.id)
                }
            } else {
                selectedDeviceForDetail = dev
            }
        }
    }

    private func statusFilterChip(_ label: String, tag: String) -> some View {
        Button(action: { selectedStatusFilter = tag }) {
            Text(label)
                .font(.system(size: 11.5, weight: selectedStatusFilter == tag ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedStatusFilter == tag ? Color.appSecondaryDarkBlue : Color.white)
                .foregroundColor(selectedStatusFilter == tag ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.appCardBorder, lineWidth: 0.8))
        }
    }

    private func statusColor(_ st: String) -> Color {
        let s = st.lowercased()
        if s.contains("mới") || s.contains("kho") { return Color.statusNew }
        if s.contains("dùng") || s.contains("hoạt động") { return Color.statusInUse }
        if s.contains("sửa") || s.contains("bảo hành") { return Color.statusRepair }
        return Color.statusBroken
    }
}
