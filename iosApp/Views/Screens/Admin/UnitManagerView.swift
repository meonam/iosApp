import SwiftUI

// MARK: - UNIT MANAGER VIEW (ĐỒNG BỘ 1:1 THEO UNITMANAGERSCREEN.KT TRÊN ANDROID)
public struct UnitManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var newUnitName: String = ""
    @State private var newUnitId: String = ""
    @State private var newUnitRegion: String = ""
    @State private var storeSearchQuery: String = ""
    @State private var isStoreDropdownOpen: Bool = false

    // Edit state
    @State private var editingUnit: DonVi? = nil
    @State private var editUnitId: String = ""
    @State private var editName: String = ""
    @State private var editRegion: String = ""
    @State private var showEditSheet: Bool = false

    // Delete alert
    @State private var unitToDelete: DonVi? = nil
    @State private var showDeleteAlert: Bool = false

    // Collapsible add form
    @State private var isAddExpanded: Bool = true

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var isDuplicateUnitId: Bool {
        let clean = newUnitId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else { return false }
        return viewModel.units.contains { $0.id.uppercased() == clean }
    }

    private var suggestedStores: [SgcoopStore] {
        let q = storeSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        let qNorm = q.folding(options: .diacriticInsensitive, locale: .current)
        let sourceList = viewModel.suggestedStores.isEmpty ? SgcoopStores.list : viewModel.suggestedStores
        return Array(sourceList.filter { st in
            st.code.lowercased().contains(q) ||
            st.shortName.lowercased().contains(q) ||
            st.shortName.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(qNorm) ||
            st.fullName.folding(options: .diacriticInsensitive, locale: .current).lowercased().contains(qNorm)
        }.prefix(8))
    }

    private var filteredUnits: [DonVi] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.units
        }
        return viewModel.units.filter { u in
            u.tenDonVi.localizedCaseInsensitiveContains(searchQuery) ||
            u.id.localizedCaseInsensitiveContains(searchQuery) ||
            u.maKhuVuc.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Đơn vị (Chi nhánh)")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    isAddExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isAddExpanded ? "chevron.up.circle.fill" : "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }

                            Button(action: { viewModel.fetchUnitsAndRegions() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 14) {
                            // FORM THÊM MỚI (COLLAPSIBLE)
                            if isAddExpanded {
                                addUnitCard
                            }

                            // SEARCH BAR
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.gray)
                                TextField("Tìm theo tên đơn vị, mã đơn vị...", text: $searchQuery)
                                    .font(.system(size: 14))
                                if !searchQuery.isEmpty {
                                    Button(action: { searchQuery = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
                            .padding(.horizontal, 14)

                            // HEADER DANH SÁCH
                            HStack {
                                Text("DANH SÁCH ĐƠN VỊ (\(filteredUnits.count))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            // DANH SÁCH ĐƠN VỊ
                            if filteredUnits.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer().frame(height: 30)
                                    Image(systemName: "building.2")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("Không tìm thấy đơn vị nào")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(filteredUnits) { unit in
                                        unitCard(unit)
                                    }
                                }
                                .padding(.horizontal, 14)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchUnitsAndRegions()
        }
        .sheet(isPresented: $showEditSheet) {
            editUnitSheet
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Xác nhận xóa đơn vị"),
                message: Text("Bạn có chắc chắn muốn xóa đơn vị \"\(unitToDelete?.tenDonVi ?? "")\" (Mã: \(unitToDelete?.id ?? ""))?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let u = unitToDelete {
                        Task {
                            await viewModel.deleteUnit(unitId: u.id)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - ADD UNIT CARD
    private var addUnitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("➕ Thêm đơn vị mới")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
            }

            // Ô TÌM NHANH 123 SIÊU THỊ CO.OPMART
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🔍 Tìm nhanh siêu thị Co.opmart")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                    Text("123 điểm bán")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Gõ mã (151, 515...) hoặc tên (Cống Quỳnh, BRIA...)", text: $storeSearchQuery)
                        .font(.system(size: 13))
                        .onChange(of: storeSearchQuery) { val in
                            isStoreDropdownOpen = !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                    if !storeSearchQuery.isEmpty {
                        Button(action: {
                            storeSearchQuery = ""
                            isStoreDropdownOpen = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color.appSurfaceVariant)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                if isStoreDropdownOpen && !suggestedStores.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(suggestedStores) { st in
                            let inSystem = viewModel.units.contains { $0.id.uppercased() == st.code.uppercased() }
                            Button(action: {
                                newUnitId = st.code
                                newUnitName = st.fullName
                                storeSearchQuery = "\(st.code) - \(st.shortName) (\(st.fullName))"
                                isStoreDropdownOpen = false
                            }) {
                                HStack {
                                    Text(st.code)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(hex: "#E11D48"))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "#FFE4E6"))
                                        .cornerRadius(4)

                                    Text(st.shortName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appTextPrimary)

                                    Text("- \(st.fullName)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appTextSecondary)
                                        .lineLimit(1)

                                    Spacer()

                                    if inSystem {
                                        Text("Đã có")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "#D97706"))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .background(Color(hex: "#FEF3C7"))
                                            .cornerRadius(4)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }
                    }
                    .background(Color.appSurface)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Mã đơn vị")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: 151, 515, BINHTAN2...", text: $newUnitId)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(isDuplicateUnitId ? Color.red.opacity(0.08) : Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isDuplicateUnitId ? Color.red : Color.appCardBorder, lineWidth: 1))

                if isDuplicateUnitId {
                    Text("⚠️ Mã đơn vị '\(newUnitId)' đã tồn tại trong hệ thống!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.red)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Tên đơn vị / chi nhánh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: Co.opmart Cống Quỳnh", text: $newUnitName)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("🗺️ Cụm / Khu vực trực thuộc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                Menu {
                    Button("Không chỉ định (Mặc định)") {
                        newUnitRegion = ""
                    }
                    ForEach(viewModel.regions) { reg in
                        Button("🎯 Cụm: \(reg.maKhuVuc) - \(reg.tenKhuVuc)") {
                            newUnitRegion = reg.maKhuVuc
                        }
                    }
                } label: {
                    HStack {
                        Text(newUnitRegion.isEmpty ? "Chọn khu vực (tùy chọn)" : newUnitRegion)
                            .font(.system(size: 13))
                            .foregroundColor(newUnitRegion.isEmpty ? .gray : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            Button(action: {
                let name = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
                let id = newUnitId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !name.isEmpty && !id.isEmpty && !isDuplicateUnitId else { return }
                Task {
                    await viewModel.addUnit(name: name, unitId: id, region: newUnitRegion)
                    newUnitName = ""
                    newUnitId = ""
                    newUnitRegion = ""
                    storeSearchQuery = ""
                    isStoreDropdownOpen = false
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Thêm đơn vị")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background((newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newUnitId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicateUnitId) ? Color.gray.opacity(0.5) : Color.appSecondaryDarkBlue)
                .cornerRadius(10)
            }
            .disabled(newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newUnitId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicateUnitId)
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        .padding(.horizontal, 14)
    }


    // MARK: - UNIT CARD
    private func unitCard(_ unit: DonVi) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#6366F1").opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#6366F1"))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(unit.tenDonVi)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    HStack(spacing: 6) {
                        Text("Mã: \(unit.id)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#4338CA"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#EEF2FF"))
                            .cornerRadius(4)

                        if !unit.maKhuVuc.isEmpty {
                            Text("🗺️ \(unit.maKhuVuc)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#B45309"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#FEF3C7"))
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        editingUnit = unit
                        editUnitId = unit.id
                        editName = unit.tenDonVi
                        editRegion = unit.maKhuVuc
                        showEditSheet = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "#3B82F6"))
                    }

                    Button(action: {
                        unitToDelete = unit
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
    }

    // MARK: - EDIT UNIT SHEET
    private var editUnitSheet: some View {
        let cleanNewId = editUnitId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isDuplicate = !cleanNewId.isEmpty && cleanNewId != (editingUnit?.id ?? "").uppercased() && viewModel.units.contains { $0.id.uppercased() == cleanNewId }

        return NavigationView {
            Form {
                Section(header: Text("Thông tin đơn vị")) {
                    TextField("Mã đơn vị (*)", text: $editUnitId)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)

                    if isDuplicate {
                        Text("⚠️ Mã đơn vị '\(cleanNewId)' đã tồn tại trong hệ thống!")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                    } else if cleanNewId != (editingUnit?.id ?? "").uppercased() {
                        Text("💡 Đổi mã sẽ tạo đơn vị mới và đồng bộ dữ liệu liên quan.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }

                    TextField("Tên đơn vị (*)", text: $editName)

                    Picker("Cụm / Khu vực", selection: $editRegion) {
                        Text("Không chỉ định").tag("")
                        ForEach(viewModel.regions) { reg in
                            Text("\(reg.maKhuVuc) - \(reg.tenKhuVuc)").tag(reg.maKhuVuc)
                        }
                    }
                }
            }
            .navigationTitle("Sửa đơn vị")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showEditSheet = false },
                trailing: Button("Lưu") {
                    if let u = editingUnit, !cleanNewId.isEmpty, !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isDuplicate {
                        Task {
                            await viewModel.updateUnit(unitId: u.id, newUnitId: cleanNewId, name: editName, region: editRegion)
                            showEditSheet = false
                        }
                    }
                }
                .disabled(cleanNewId.isEmpty || editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicate)
                .font(.headline)
                .foregroundColor(.appPrimary)
            )
        }
    }
}
