import SwiftUI

// MARK: - UNIT MANAGER VIEW (ĐỒNG BỘ 1:1 THEO UNITMANAGERSCREEN.KT TRÊN ANDROID)
public struct UnitManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var newUnitName: String = ""
    @State private var newUnitId: String = ""
    @State private var newUnitRegion: String = ""

    // Edit state
    @State private var editingUnit: DonVi? = nil
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Tên đơn vị / chi nhánh")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: Co.opmart Cần Thơ", text: $newUnitName)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    .onChange(of: newUnitName) { val in
                        if newUnitId.isEmpty || newUnitId.hasPrefix("UNIT_") {
                            let slug = val.uppercased().folding(options: .diacriticInsensitive, locale: .current)
                                .replacingOccurrences(of: " ", with: "_")
                                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            newUnitId = "UNIT_" + String(slug.prefix(12))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Mã đơn vị")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: 199, CAN_THO...", text: $newUnitId)
                    .font(.system(size: 13))
                    .padding(10)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
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
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                }
            }

            Button(action: {
                let name = newUnitName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    await viewModel.addUnit(name: name, unitId: newUnitId, region: newUnitRegion)
                    newUnitName = ""
                    newUnitId = ""
                    newUnitRegion = ""
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
                .background(newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.appSecondaryDarkBlue)
                .cornerRadius(10)
            }
            .disabled(newUnitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
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
        NavigationView {
            Form {
                Section(header: Text("Thông tin đơn vị")) {
                    HStack {
                        Text("Mã đơn vị:")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(editingUnit?.id ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
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
                    if let u = editingUnit, !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Task {
                            await viewModel.updateUnit(unitId: u.id, name: editName, region: editRegion)
                            showEditSheet = false
                        }
                    }
                }
                .font(.headline)
                .foregroundColor(.appPrimary)
            )
        }
    }
}
