import SwiftUI
import UIKit

// MARK: - MÀN HÌNH QUẢN LÝ ĐƠN VỊ & KHU VỰC (UnitManagerScreen.kt & RegionManagerScreen.kt)
public struct UnitRegionManagerFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 0 // 0: Đơn vị (Siêu thị), 1: Khu vực
    @State private var searchQuery: String = ""

    // Sheet / Form states for Unit
    @State private var showAddUnitSheet: Bool = false
    @State private var editingUnit: UnitItem? = nil
    @State private var unitNameInput: String = ""
    @State private var unitIdInput: String = ""
    @State private var unitAddressInput: String = ""
    @State private var unitPhoneInput: String = ""
    @State private var unitRegionInput: String = "TP. Hồ Chí Minh"
    @State private var unitToDelete: UnitItem? = nil
    @State private var showDeleteUnitDialog: Bool = false

    // Sheet / Form states for Region
    @State private var showAddRegionSheet: Bool = false
    @State private var editingRegion: RegionItem? = nil
    @State private var regionNameInput: String = ""
    @State private var regionCodeInput: String = ""
    @State private var regionLeaderInput: String = ""
    @State private var regionPhoneInput: String = ""
    @State private var regionToDelete: RegionItem? = nil
    @State private var showDeleteRegionDialog: Bool = false

    public init(onDismiss: @escaping () -> Void, initialTab: Int = 0) {
        self.onDismiss = onDismiss
        self._selectedTab = State(initialValue: initialTab)
    }

    // Default regions of Saigon Co.op
    private var defaultRegions: [RegionItem] {
        [
            RegionItem(id: "r1", name: "Cụm TP. Hồ Chí Minh 1 (Trung tâm)", code: "HCM_1", description: "Quận 1, 3, 5, 10, Bình Thạnh", leader: "Trần Minh Trình", phone: "0908890123"),
            RegionItem(id: "r2", name: "Cụm TP. Hồ Chí Minh 2 (Tây & Nam)", code: "HCM_2", description: "Quận 6, 7, 8, Bình Chánh, Nhà Bè", leader: "Huỳnh Nguyễn Anh Đức", phone: "0908345678"),
            RegionItem(id: "r3", name: "Cụm TP. Hồ Chí Minh 3 (Bắc & Đông)", code: "HCM_3", description: "Thủ Đức, Gò Vấp, Quận 12, Hóc Môn", leader: "Dinh Quoc Huy", phone: "0908234567"),
            RegionItem(id: "r4", name: "Khu Vực Đông Nam Bộ & Bình Dương", code: "HCM_BD", description: "Bình Dương, Đồng Nai, Bà Rịa - Vũng Tàu", leader: "Hồ Thân Khánh", phone: "0908456789"),
            RegionItem(id: "r5", name: "Khu Vực Miền Tây Nam Bộ", code: "CAN_THO", description: "Cần Thơ, Hậu Giang, An Giang, Tiền Giang, Cà Mau", leader: "Dam Huu Phuc", phone: "0908123456"),
            RegionItem(id: "r6", name: "Khu Vực Miền Trung & Tây Nguyên", code: "MT_TN", description: "Đà Nẵng, Huế, Quy Nhơn, Nha Trang, Buôn Ma Thuột", leader: "Nguyen Thanh Sang", phone: "0908678901"),
            RegionItem(id: "r7", name: "Khu Vực Miền Bắc", code: "MIEN_BAC", description: "Hà Nội, Hải Phòng, Bắc Ninh", leader: "Phạm Hải Hà", phone: "0908901234")
        ]
    }

    private var activeUnits: [UnitItem] {
        if !firebase.unitsList.isEmpty {
            return firebase.unitsList
        }
        // Use CoopmartDirectory stores as rich initial list
        return CoopmartDirectory.stores.prefix(40).map { s in
            UnitItem(
                id: s.keyTokens.first ?? s.name,
                name: s.name,
                address: s.address,
                phone: s.phone
            )
        }
    }

    private var activeRegions: [RegionItem] {
        if !firebase.regionsList.isEmpty {
            return firebase.regionsList
        }
        return defaultRegions
    }

    var filteredUnits: [UnitItem] {
        activeUnits.filter { u in
            searchQuery.isEmpty ||
            u.name.localizedCaseInsensitiveContains(searchQuery) ||
            u.address.localizedCaseInsensitiveContains(searchQuery) ||
            u.phone.contains(searchQuery)
        }
    }

    var filteredRegions: [RegionItem] {
        activeRegions.filter { r in
            searchQuery.isEmpty ||
            r.name.localizedCaseInsensitiveContains(searchQuery) ||
            r.code.localizedCaseInsensitiveContains(searchQuery) ||
            r.leader.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. Tab Picker (Đơn vị / Khu vực)
                Picker("Danh mục", selection: $selectedTab) {
                    Text("Đơn Vị / Siêu Thị (\(activeUnits.count))").tag(0)
                    Text("Khu Vực (\(activeRegions.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)

                // 2. Search Bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField(selectedTab == 0 ? "Tìm siêu thị, địa chỉ, SĐT..." : "Tìm khu vực, mã, trưởng cụm...", text: $searchQuery)
                        .font(.system(size: 13))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                // 3. Content List
                ScrollView {
                    VStack(spacing: 12) {
                        if selectedTab == 0 {
                            unitsListSection
                        } else {
                            regionsListSection
                        }
                    }
                    .padding(12)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle(selectedTab == 0 ? "Quản Lý Đơn Vị" : "Quản Lý Khu Vực")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if selectedTab == 0 {
                            resetUnitForm()
                            showAddUnitSheet = true
                        } else {
                            resetRegionForm()
                            showAddRegionSheet = true
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Thêm mới")
                        }
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appSecondaryDarkBlue)
                }
            }
            .sheet(isPresented: $showAddUnitSheet) { unitFormSheet(isEdit: false) }
            .sheet(item: $editingUnit) { _ in unitFormSheet(isEdit: true) }
            .sheet(isPresented: $showAddRegionSheet) { regionFormSheet(isEdit: false) }
            .sheet(item: $editingRegion) { _ in regionFormSheet(isEdit: true) }
            .alert(isPresented: $showDeleteUnitDialog) {
                Alert(
                    title: Text("Xóa đơn vị?"),
                    message: Text("Bạn có chắc muốn xóa [\(unitToDelete?.name ?? "")] khỏi danh mục?"),
                    primaryButton: .destructive(Text("Xóa")) {
                        if let u = unitToDelete { executeDeleteUnit(u) }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
            .alert(isPresented: $showDeleteRegionDialog) {
                Alert(
                    title: Text("Xóa khu vực?"),
                    message: Text("Bạn có chắc muốn xóa [\(regionToDelete?.name ?? "")]?"),
                    primaryButton: .destructive(Text("Xóa")) {
                        if let r = regionToDelete { executeDeleteRegion(r) }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
            .onAppear {
                Task {
                    await firebase.fetchUnits()
                    await firebase.fetchRegions()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Units List Section
    private var unitsListSection: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredUnits) { unit in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appSecondaryDarkBlue.opacity(0.1))
                                .frame(width: 42, height: 42)
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.appSecondaryDarkBlue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(unit.name)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                            Text(unit.address)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Menu {
                            Button(action: {
                                loadUnitToForm(unit)
                                editingUnit = unit
                            }) {
                                Label("Chỉnh sửa", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                unitToDelete = unit
                                showDeleteUnitDialog = true
                            }) {
                                Label("Xóa", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !unit.phone.isEmpty {
                        Divider()
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text("Hotline: \(unit.phone)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.appSecondaryDarkBlue)
                            Spacer()
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Regions List Section
    private var regionsListSection: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredRegions) { region in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.12))
                                .frame(width: 42, height: 42)
                            Image(systemName: "map.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(region.name)
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                Text("(\(region.code))")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.appPrimaryPink)
                            }

                            if !region.description.isEmpty {
                                Text(region.description)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Menu {
                            Button(action: {
                                loadRegionToForm(region)
                                editingRegion = region
                            }) {
                                Label("Chỉnh sửa", systemImage: "pencil")
                            }

                            Button(role: .destructive, action: {
                                regionToDelete = region
                                showDeleteRegionDialog = true
                            }) {
                                Label("Xóa", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !region.leader.isEmpty {
                        Divider()
                        HStack {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.appSecondaryDarkBlue)
                            Text("Trưởng cụm: \(region.leader)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.appSecondaryDarkBlue)
                            Spacer()
                            if !region.phone.isEmpty {
                                Text(region.phone)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Unit Form Sheet
    @ViewBuilder
    private func unitFormSheet(isEdit: Bool) -> some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN ĐƠN VỊ")) {
                    TextField("Tên siêu thị / đơn vị", text: $unitNameInput)
                    TextField("Mã đơn vị (VD: CAN_THO)", text: $unitIdInput)
                        .disabled(isEdit)
                    TextField("Địa chỉ chi tiết", text: $unitAddressInput)
                    TextField("Hotline liên hệ", text: $unitPhoneInput)
                }

                Section {
                    Button(action: {
                        saveUnitAction(isEdit: isEdit)
                    }) {
                        HStack {
                            Spacer()
                            Text(isEdit ? "Cập Nhật Đơn Vị" : "Thêm Đơn Vị")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.appSecondaryDarkBlue)
                }
            }
            .navigationTitle(isEdit ? "Sửa Đơn Vị" : "Thêm Đơn Vị Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        showAddUnitSheet = false
                        editingUnit = nil
                    }
                }
            }
        }
    }

    // MARK: - Region Form Sheet
    @ViewBuilder
    private func regionFormSheet(isEdit: Bool) -> some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN KHU VỰC")) {
                    TextField("Tên khu vực (VD: Cụm Miền Tây)", text: $regionNameInput)
                    TextField("Mã khu vực (VD: CAN_THO)", text: $regionCodeInput)
                        .disabled(isEdit)
                    TextField("Trưởng khu vực phụ trách", text: $regionLeaderInput)
                    TextField("Số điện thoại liên hệ", text: $regionPhoneInput)
                }

                Section {
                    Button(action: {
                        saveRegionAction(isEdit: isEdit)
                    }) {
                        HStack {
                            Spacer()
                            Text(isEdit ? "Cập Nhật Khu Vực" : "Thêm Khu Vực")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.orange)
                }
            }
            .navigationTitle(isEdit ? "Sửa Khu Vực" : "Thêm Khu Vực Mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        showAddRegionSheet = false
                        editingRegion = nil
                    }
                }
            }
        }
    }

    private func resetUnitForm() {
        unitNameInput = ""
        unitIdInput = ""
        unitAddressInput = ""
        unitPhoneInput = ""
    }

    private func loadUnitToForm(_ u: UnitItem) {
        unitNameInput = u.name
        unitIdInput = u.id
        unitAddressInput = u.address
        unitPhoneInput = u.phone
    }

    private func resetRegionForm() {
        regionNameInput = ""
        regionCodeInput = ""
        regionLeaderInput = ""
        regionPhoneInput = ""
    }

    private func loadRegionToForm(_ r: RegionItem) {
        regionNameInput = r.name
        regionCodeInput = r.code
        regionLeaderInput = r.leader
        regionPhoneInput = r.phone
    }

    private func saveUnitAction(isEdit: Bool) {
        let cleanId = unitIdInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanName = unitNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty && !cleanName.isEmpty else { return }

        Task {
            _ = await firebase.saveUnit(id: cleanId, name: cleanName, address: unitAddressInput, phone: unitPhoneInput)
            await firebase.fetchUnits()
            showAddUnitSheet = false
            editingUnit = nil
        }
    }

    private func executeDeleteUnit(_ u: UnitItem) {
        Task {
            _ = await firebase.deleteUnit(id: u.id)
            await firebase.fetchUnits()
        }
    }

    private func saveRegionAction(isEdit: Bool) {
        let cleanCode = regionCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanName = regionNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCode.isEmpty && !cleanName.isEmpty else { return }

        Task {
            _ = await firebase.saveRegion(code: cleanCode, name: cleanName, leader: regionLeaderInput, phone: regionPhoneInput)
            await firebase.fetchRegions()
            showAddRegionSheet = false
            editingRegion = nil
        }
    }

    private func executeDeleteRegion(_ r: RegionItem) {
        Task {
            _ = await firebase.deleteRegion(id: r.id)
            await firebase.fetchRegions()
        }
    }
}
