import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ PHÒNG BAN (ĐỒNG BỘ 1:1 THEO DEPARTMENTMANAGERSCREEN.KT TRÊN ANDROID)
public struct DepartmentManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var showAddSheet: Bool = false
    @State private var newDeptName: String = ""
    @State private var newDeptType: String = "IT"
    @State private var newHotline: String = ""
    @State private var isHelpDesk: Bool = false
    @State private var isIncidentHandler: Bool = true

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredDepts: [Department] {
        viewModel.departments.filter { d in
            searchQuery.isEmpty ||
            d.departmentName.localizedCaseInsensitiveContains(searchQuery) ||
            d.hotline.contains(searchQuery)
        }
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

                            Text("Quản lý phòng ban (\(viewModel.departments.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { showAddSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. SEARCH
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm phòng ban, số hotline...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(12)

                    // 3. DANH SÁCH PHÒNG BAN
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredDepts) { dept in
                                deptCard(dept)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.departments.isEmpty {
                viewModel.fetchDepartments()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addDeptSheetView
        }
    }

    private func deptCard(_ dept: Department) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text(dept.departmentName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Spacer()

                if dept.isHelpDesk {
                    Text("HelpDesk")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appPrimaryPink)
                        .cornerRadius(6)
                }
            }

            Divider()

            HStack {
                if !dept.hotline.isEmpty {
                    Label("Hotline: \(dept.hotline)", systemImage: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                Text("Loại: \(dept.departmentType)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private var addDeptSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin phòng ban")) {
                    TextField("Tên phòng ban", text: $newDeptName)
                    TextField("Số điện thoại Hotline", text: $newHotline)
                }

                Section(header: Text("Cấu hình vai trò")) {
                    Toggle("Là bộ phận Tiếp nhận sự cố (HelpDesk)", isOn: $isHelpDesk)
                    Toggle("Là bộ phận Xử lý kỹ thuật", isOn: $isIncidentHandler)
                }
            }
            .navigationTitle("Thêm phòng ban mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !newDeptName.isEmpty {
                            let newD = Department(
                                departmentId: UUID().uuidString.prefix(8).lowercased(),
                                companyId: viewModel.companyId,
                                departmentName: newDeptName,
                                departmentType: newDeptType,
                                isHelpDesk: isHelpDesk,
                                isIncidentHandler: isIncidentHandler,
                                hotline: newHotline
                            )
                            viewModel.departments.append(newD)
                        }
                        showAddSheet = false
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimaryPink)
                }
            }
        }
    }
}
