import SwiftUI

// MARK: - REGION MANAGER VIEW (ĐỒNG BỘ 1:1 THEO REGIONMANAGERSCREEN.KT TRÊN ANDROID)
public struct RegionManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var isAddExpanded: Bool = true

    // Add state
    @State private var newRegionName: String = ""
    @State private var newRegionId: String = ""
    @State private var newRegionLeader: String = ""
    @State private var newRegionPhone: String = ""
    @State private var newRegionDesc: String = ""

    // Edit state
    @State private var editingRegion: KhuVuc? = nil
    @State private var editName: String = ""
    @State private var editLeader: String = ""
    @State private var editPhone: String = ""
    @State private var editDesc: String = ""
    @State private var showEditSheet: Bool = false

    // Delete alert
    @State private var regionToDelete: KhuVuc? = nil
    @State private var showDeleteAlert: Bool = false

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredRegions: [KhuVuc] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viewModel.regions
        }
        return viewModel.regions.filter { r in
            r.tenKhuVuc.localizedCaseInsensitiveContains(searchQuery) ||
            r.maKhuVuc.localizedCaseInsensitiveContains(searchQuery) ||
            r.nguoiPhuTrach.localizedCaseInsensitiveContains(searchQuery) ||
            r.sdtLienHe.localizedCaseInsensitiveContains(searchQuery) ||
            r.moTa.localizedCaseInsensitiveContains(searchQuery)
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

                            Text("Quản lý Khu Vực / Vùng")
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
                                addRegionCard
                            }

                            // SEARCH BAR
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(Color.appTextSecondary)
                                TextField("Tìm theo tên khu vực, mã, người phụ trách...", text: $searchQuery)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.appTextPrimary)
                                if !searchQuery.isEmpty {
                                    Button(action: { searchQuery = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.appSurface)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                            .padding(.horizontal, 14)

                            // HEADER DANH SÁCH
                            HStack {
                                Text("DANH SÁCH KHU VỰC (\(filteredRegions.count))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                            // DANH SÁCH KHU VỰC
                            if filteredRegions.isEmpty {
                                VStack(spacing: 12) {
                                    Spacer().frame(height: 30)
                                    Image(systemName: "map.circle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                    Text("Không tìm thấy khu vực nào")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(filteredRegions) { region in
                                        regionCard(region)
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
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
        }
        .sheet(isPresented: $showEditSheet) {
            editRegionSheet
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Xác nhận xóa khu vực"),
                message: Text("Bạn có chắc chắn muốn xóa khu vực \"\(regionToDelete?.tenKhuVuc ?? "")\" (Mã: \(regionToDelete?.maKhuVuc ?? ""))?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let r = regionToDelete {
                        Task {
                            await viewModel.deleteRegion(maKhuVuc: r.maKhuVuc)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - ADD REGION CARD
    private var addRegionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("➕ Thêm khu vực / vùng mới")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Tên khu vực / vùng")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: Khu vực Miền Tây, Cụm TP.HCM...", text: $newRegionName)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextPrimary)
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                    .onChange(of: newRegionName) { val in
                        if newRegionId.isEmpty || newRegionId.hasPrefix("KV_") {
                            let slug = val.uppercased().folding(options: .diacriticInsensitive, locale: .current)
                                .replacingOccurrences(of: " ", with: "_")
                                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            newRegionId = "KV_" + String(slug.prefix(10))
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 2) {
                    Text("Mã khu vực")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    Text("*").foregroundColor(.red).font(.system(size: 12, weight: .bold))
                }
                TextField("Ví dụ: KV_MT, HCM_01...", text: $newRegionId)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextPrimary)
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Người phụ trách")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    HStack {
                        TextField("Họ tên", text: $newRegionLeader)
                            .font(.system(size: 13))
                            .foregroundColor(Color.appTextPrimary)
                        if !viewModel.allUsers.isEmpty {
                            Menu {
                                ForEach(viewModel.allUsers) { u in
                                    Button("\(u.fullName) (\(u.email))") {
                                        newRegionLeader = u.fullName
                                        if !u.phone.isEmpty { newRegionPhone = u.phone }
                                    }
                                }
                            } label: {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("SĐT liên hệ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.appTextSecondary)
                    TextField("090...", text: $newRegionPhone)
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextPrimary)
                        .keyboardType(.phonePad)
                        .padding(10)
                        .background(Color.appSurfaceVariant)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mô tả / Ghi chú")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.appTextSecondary)
                TextField("Phạm vi quản lý...", text: $newRegionDesc)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextPrimary)
                    .padding(10)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
            }

            Button(action: {
                let name = newRegionName.trimmingCharacters(in: .whitespacesAndNewlines)
                let ma = newRegionId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard !name.isEmpty && !ma.isEmpty else { return }
                Task {
                    let r = KhuVuc(
                        maKhuVuc: ma,
                        tenKhuVuc: name,
                        moTa: newRegionDesc.trimmingCharacters(in: .whitespacesAndNewlines),
                        nguoiPhuTrach: newRegionLeader.trimmingCharacters(in: .whitespacesAndNewlines),
                        sdtLienHe: newRegionPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    await viewModel.addRegion(region: r)
                    newRegionName = ""
                    newRegionId = ""
                    newRegionLeader = ""
                    newRegionPhone = ""
                    newRegionDesc = ""
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Thêm khu vực")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(newRegionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.appDarkButtonBackground)
                .cornerRadius(10)
            }
            .disabled(newRegionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        .padding(.horizontal, 14)
    }

    // MARK: - REGION CARD
    private func regionCard(_ region: KhuVuc) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#F59E0B").opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "map.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#F59E0B"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(region.tenKhuVuc)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        Text(region.maKhuVuc)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Color(hex: "#B45309"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FEF3C7"))
                            .cornerRadius(4)
                    }

                    if !region.nguoiPhuTrach.isEmpty || !region.sdtLienHe.isEmpty {
                        HStack(spacing: 8) {
                            if !region.nguoiPhuTrach.isEmpty {
                                Label(region.nguoiPhuTrach, systemImage: "person.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.gray)
                            }
                            if !region.sdtLienHe.isEmpty {
                                Label(region.sdtLienHe, systemImage: "phone.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.green)
                            }
                        }
                    }

                    if !region.moTa.isEmpty {
                        Text(region.moTa)
                            .font(.system(size: 11.5))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: {
                        editingRegion = region
                        editName = region.tenKhuVuc
                        editLeader = region.nguoiPhuTrach
                        editPhone = region.sdtLienHe
                        editDesc = region.moTa
                        showEditSheet = true
                    }) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "#3B82F6"))
                    }

                    Button(action: {
                        regionToDelete = region
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
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - EDIT REGION SHEET
    private var editRegionSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin khu vực")) {
                    HStack {
                        Text("Mã khu vực:")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(editingRegion?.maKhuVuc ?? "")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                    }

                    TextField("Tên khu vực (*)", text: $editName)
                    TextField("Người phụ trách", text: $editLeader)
                    TextField("Số điện thoại liên hệ", text: $editPhone)
                        .keyboardType(.phonePad)
                    TextField("Mô tả / Ghi chú", text: $editDesc)
                }
            }
            .navigationTitle("Sửa khu vực")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showEditSheet = false },
                trailing: Button("Lưu") {
                    if let r = editingRegion, !editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Task {
                            let updated = KhuVuc(
                                maKhuVuc: r.maKhuVuc,
                                tenKhuVuc: editName.trimmingCharacters(in: .whitespacesAndNewlines),
                                moTa: editDesc.trimmingCharacters(in: .whitespacesAndNewlines),
                                nguoiPhuTrach: editLeader.trimmingCharacters(in: .whitespacesAndNewlines),
                                sdtLienHe: editPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                            await viewModel.updateRegion(region: updated)
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
