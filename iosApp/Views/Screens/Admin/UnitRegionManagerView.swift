import SwiftUI

public struct UnitRegionManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var selectedTab: Int = 0 // 0: Đơn vị / Chi nhánh, 1: Khu vực / Cụm
    @State private var searchQuery: String = ""
    @State private var showAddUnitSheet: Bool = false
    @State private var newUnitName: String = ""
    @State private var newUnitRegion: String = ""

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredUnits: [DonVi] {
        viewModel.units.filter { u in
            searchQuery.isEmpty ||
            u.tenDonVi.localizedCaseInsensitiveContains(searchQuery) ||
            u.maKhuVuc.localizedCaseInsensitiveContains(searchQuery)
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

                            Button(action: { showAddUnitSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    Picker("Phân hệ", selection: $selectedTab) {
                        Text("Đơn vị / Siêu thị (\(viewModel.units.count))").tag(0)
                        Text("Cụm / Khu vực (\(viewModel.regions.count))").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm đơn vị, chi nhánh...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    List {
                        if selectedTab == 0 {
                            ForEach(filteredUnits) { unit in
                                unitCard(unit)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.deleteUnit(unitId: unit.id) }
                                        } label: {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(viewModel.regions) { region in
                                regionCard(region)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchUnitsAndRegions()
        }
        .sheet(isPresented: $showAddUnitSheet) {
            addUnitSheetView
        }
    }

    private func unitCard(_ unit: DonVi) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 20))
                .foregroundColor(Color.appSecondaryDarkBlue)
                .frame(width: 40, height: 40)
                .background(Color.appSecondaryDarkBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(unit.tenDonVi)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Text("Khu vực: \(unit.maKhuVuc)")
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
                .foregroundColor(Color.appInfo)
                .frame(width: 40, height: 40)
                .background(Color.appInfo.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(reg.tenKhuVuc)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Text("Mã cụm: \(reg.maKhuVuc)")
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

    private var addUnitSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Tên đơn vị / Chi nhánh")) {
                    TextField("Ví dụ: Co.opmart Bình Dương", text: $newUnitName)
                }

                Section(header: Text("Khu vực / Cụm")) {
                    Picker("Chọn khu vực", selection: $newUnitRegion) {
                        ForEach(viewModel.regions) { reg in
                            Text(reg.tenKhuVuc).tag(reg.maKhuVuc)
                        }
                    }
                }
            }
            .navigationTitle("Thêm đơn vị mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddUnitSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !newUnitName.isEmpty {
                            Task {
                                await viewModel.addUnit(name: newUnitName, region: newUnitRegion)
                            }
                        }
                        showAddUnitSheet = false
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimaryPink)
                }
            }
            .onAppear {
                if newUnitRegion.isEmpty && !viewModel.regions.isEmpty {
                    newUnitRegion = viewModel.regions[0].maKhuVuc
                }
            }
        }
    }
}
