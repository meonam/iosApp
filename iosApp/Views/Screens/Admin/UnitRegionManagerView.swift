import SwiftUI

public struct UnitRegionManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var selectedTab: Int = 0 // 0: Đơn vị, 1: Khu vực
    @State private var searchQuery: String = ""
    
    // Add/Edit states
    @State private var showFormSheet: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingId: String = ""
    
    @State private var nameInput: String = ""
    @State private var idInput: String = ""
    @State private var regionSelection: String = ""

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredUnits: [DonVi] {
        viewModel.units.filter { u in
            searchQuery.isEmpty ||
            u.tenDonVi.localizedCaseInsensitiveContains(searchQuery) ||
            u.id.localizedCaseInsensitiveContains(searchQuery) ||
            u.maKhuVuc.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private var filteredRegions: [KhuVuc] {
        viewModel.regions.filter { r in
            searchQuery.isEmpty ||
            r.tenKhuVuc.localizedCaseInsensitiveContains(searchQuery) ||
            r.maKhuVuc.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Đơn vị & Khu vực")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { resetForm(); showFormSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    Picker("Phân hệ", selection: $selectedTab) {
                        Text("Đơn vị (\(viewModel.units.count))").tag(0)
                        Text("Khu vực (\(viewModel.regions.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                        Spacer()
                    } else {
                        List {
                            if selectedTab == 0 {
                                ForEach(filteredUnits) { unit in
                                    unitCard(unit)
                                        .onTapGesture { openEditUnit(unit) }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) { deleteUnit(id: unit.id) } label: { Label("Xóa", systemImage: "trash") }
                                        }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            } else {
                                ForEach(filteredRegions) { region in
                                    regionCard(region)
                                        .onTapGesture { openEditRegion(region) }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button(role: .destructive) { deleteRegion(id: region.maKhuVuc) } label: { Label("Xóa", systemImage: "trash") }
                                        }
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            viewModel.fetchUnitsAndRegions()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchUnitsAndRegions()
        }
        .sheet(isPresented: $showFormSheet) {
            formSheet
        }
    }

    private func unitCard(_ unit: DonVi) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.appPrimary)
                .frame(width: 40, height: 40)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.tenDonVi)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Text("Khu vực: \(unit.maKhuVuc) • Mã: \(unit.id)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func regionCard(_ reg: KhuVuc) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "map.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.appPrimary)
                .frame(width: 40, height: 40)
                .background(Color.appPrimary.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(reg.tenKhuVuc)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Text("Mã cụm/khu vực: \(reg.maKhuVuc)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private var formSheet: some View {
        NavigationView {
            Form {
                if selectedTab == 0 {
                    Section(header: Text("Thông tin đơn vị / chi nhánh")) {
                        TextField("Tên đơn vị (*)", text: $nameInput)
                            .onChange(of: nameInput) { newValue in
                                if !isEditing && idInput.isEmpty {
                                    let slug = newValue.uppercased().replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    idInput = "UNIT_" + String(slug.prefix(15))
                                }
                            }
                        TextField("Mã đơn vị (*)", text: $idInput)
                            .disabled(isEditing)
                        
                        Picker("Khu vực", selection: $regionSelection) {
                            ForEach(viewModel.regions, id: \.maKhuVuc) { r in
                                Text(r.tenKhuVuc).tag(r.maKhuVuc)
                            }
                        }
                    }
                } else {
                    Section(header: Text("Thông tin khu vực / cụm")) {
                        TextField("Tên khu vực (*)", text: $nameInput)
                            .onChange(of: nameInput) { newValue in
                                if !isEditing && idInput.isEmpty {
                                    let slug = newValue.uppercased().replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                    idInput = "KV_" + String(slug.prefix(15))
                                }
                            }
                        TextField("Mã khu vực (*)", text: $idInput)
                            .disabled(isEditing)
                    }
                }
            }
            .navigationTitle(isEditing ? (selectedTab == 0 ? "Sửa đơn vị" : "Sửa khu vực") : (selectedTab == 0 ? "Thêm đơn vị" : "Thêm khu vực"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showFormSheet = false },
                trailing: Button("Lưu") {
                        if !nameInput.isEmpty && !idInput.isEmpty {
                            if selectedTab == 0 {
                                saveUnit()
                            } else {
                                saveRegion()
                            }
                            showFormSheet = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimary)
                }
            )
            .onAppear {
                if selectedTab == 0 && regionSelection.isEmpty && !viewModel.regions.isEmpty {
                    regionSelection = viewModel.regions.first!.maKhuVuc
                }
            }
        }
    }
    
    private func resetForm() {
        isEditing = false
        editingId = ""
        nameInput = ""
        idInput = ""
        if !viewModel.regions.isEmpty {
            regionSelection = viewModel.regions.first!.maKhuVuc
        }
    }
    
    private func openEditUnit(_ unit: DonVi) {
        isEditing = true
        editingId = unit.id
        nameInput = unit.tenDonVi
        idInput = unit.id
        regionSelection = unit.maKhuVuc
        showFormSheet = true
    }
    
    private func openEditRegion(_ region: KhuVuc) {
        isEditing = true
        editingId = region.maKhuVuc
        nameInput = region.tenKhuVuc
        idInput = region.maKhuVuc
        showFormSheet = true
    }
    
    // REST API Helpers
    private func saveUnit() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let did = idInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = isEditing ? 
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/units/\(editingId)?updateMask.fieldPaths=unitName&updateMask.fieldPaths=maKhuVuc" :
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/units?documentId=\(did)"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = isEditing ? "PATCH" : "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let body: [String: Any] = [
            "fields": [
                "unitName": ["stringValue": nameInput.trimmingCharacters(in: .whitespacesAndNewlines)],
                "maKhuVuc": ["stringValue": regionSelection],
                "companyId": ["stringValue": comp]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchUnitsAndRegions()
        }
    }
    
    private func saveRegion() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let did = idInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = isEditing ? 
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/khu_vuc/\(editingId)?updateMask.fieldPaths=tenKhuVuc" :
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/khu_vuc?documentId=\(did)"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = isEditing ? "PATCH" : "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let body: [String: Any] = [
            "fields": [
                "maKhuVuc": ["stringValue": did],
                "tenKhuVuc": ["stringValue": nameInput.trimmingCharacters(in: .whitespacesAndNewlines)]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchUnitsAndRegions()
        }
    }
    
    private func deleteUnit(id: String) {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/units/\(id)"
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchUnitsAndRegions()
        }
    }
    
    private func deleteRegion(id: String) {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/khu_vuc/\(id)"
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchUnitsAndRegions()
        }
    }
}
