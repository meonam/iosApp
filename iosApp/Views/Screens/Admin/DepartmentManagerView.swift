import SwiftUI

public struct DepartmentManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var showAddSheet: Bool = false
    @State private var showEditSheet: Bool = false
    
    // Add/Edit states
    @State private var deptName: String = ""
    @State private var deptId: String = ""
    @State private var deptType: String = "GENERAL"
    @State private var managerName: String = ""
    @State private var managerEmail: String = ""
    @State private var hotline: String = ""
    @State private var location: String = ""
    @State private var isActive: Bool = true
    
    @State private var editingDeptId: String = ""

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredDepts: [Department] {
        viewModel.departments.filter { d in
            searchQuery.isEmpty ||
            d.departmentName.localizedCaseInsensitiveContains(searchQuery) ||
            d.departmentId.localizedCaseInsensitiveContains(searchQuery) ||
            d.hotline.contains(searchQuery)
        }
    }
    
    private func getUserCount(for deptId: String) -> Int {
        return viewModel.allUsers.filter { $0.departmentId.caseInsensitiveCompare(deptId) == .orderedSame || $0.departmentId.caseInsensitiveCompare(deptId.replacingOccurrences(of: "DEPT_", with: "")) == .orderedSame }.count
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

                            Text("Quản lý phòng ban (\(viewModel.departments.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { resetForm(); showAddSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary) // Changed to appPrimary

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm phòng ban...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(12)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                        Spacer()
                    } else if filteredDepts.isEmpty {
                        Spacer()
                        Text("Không tìm thấy phòng ban nào").foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredDepts) { dept in
                                deptCard(dept)
                                    .onTapGesture {
                                        openEdit(dept)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            deleteDept(deptId: dept.id)
                                        } label: {
                                            Label("Xóa", systemImage: "trash")
                                        }
                                    }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await refreshData()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.departments.isEmpty {
                viewModel.fetchDepartments()
            }
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
        }
        .sheet(isPresented: $showAddSheet) {
            deptFormSheet(isEdit: false)
        }
        .sheet(isPresented: $showEditSheet) {
            deptFormSheet(isEdit: true)
        }
    }

    private func deptCard(_ dept: Department) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(dept.isActive ? Color.appPrimary : Color.gray)
                Text(dept.departmentName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(dept.isActive ? Color.appTextPrimary : .gray)

                Spacer()
                
                if !dept.isActive {
                    Text("Đã khóa")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            Divider()
            HStack {
                Text("Mã: \(dept.departmentId)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appSecondaryDarkBlue.opacity(0.1))
                    .cornerRadius(4)
                
                Spacer()
                
                Label("\(getUserCount(for: dept.departmentId)) NV", systemImage: "person.2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimaryPink.opacity(0.1))
                    .cornerRadius(4)
            }
            if !dept.managerName.isEmpty {
                Text("Quản lý: \(dept.managerName)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .opacity(dept.isActive ? 1.0 : 0.6)
    }

    private func deptFormSheet(isEdit: Bool) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin cơ bản")) {
                    TextField("Tên phòng ban (*)", text: $deptName)
                        .onChange(of: deptName) { newValue in
                            if !isEdit && (deptId.isEmpty || deptId.starts(with: "DEPT_")) {
                                let slug = newValue.uppercased().replacingOccurrences(of: " ", with: "_")
                                    .replacingOccurrences(of: "Đ", with: "D")
                                    .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                deptId = String(slug.prefix(20))
                                if !deptId.starts(with: "DEPT_") {
                                    deptId = "DEPT_" + deptId
                                }
                            }
                        }
                    TextField("Mã phòng ban (*)", text: $deptId)
                        .disabled(isEdit)
                    
                    Picker("Loại phòng ban", selection: $deptType) {
                        Text("Chung (GENERAL)").tag("GENERAL")
                        Text("IT / Kỹ thuật").tag("IT")
                        Text("Kho vận").tag("WAREHOUSE")
                        Text("Hỗ trợ (HELPDESK)").tag("HELPDESK")
                        Text("Đơn vị (UNIT)").tag("UNIT")
                    }
                }
                
                Section(header: Text("Người quản lý")) {
                    TextField("Tên người quản lý", text: $managerName)
                    TextField("Email người quản lý", text: $managerEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section(header: Text("Liên hệ & Vị trí")) {
                    TextField("Hotline", text: $hotline)
                        .keyboardType(.phonePad)
                    TextField("Vị trí (vd: Tầng 2)", text: $location)
                }
                
                if isEdit {
                    Section {
                        Toggle("Hoạt động", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(isEdit ? "Cập nhật phòng ban" : "Thêm phòng ban")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        showAddSheet = false
                        showEditSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        if !deptName.isEmpty && !deptId.isEmpty {
                            if isEdit {
                                updateDept()
                            } else {
                                saveNewDept()
                            }
                            showAddSheet = false
                            showEditSheet = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(Color.appPrimaryPink)
                }
            }
        }
    }
    
    private func resetForm() {
        deptName = ""
        deptId = ""
        deptType = "GENERAL"
        managerName = ""
        managerEmail = ""
        hotline = ""
        location = ""
        isActive = true
    }
    
    private func openEdit(_ dept: Department) {
        editingDeptId = dept.id
        deptName = dept.departmentName
        deptId = dept.departmentId
        deptType = dept.departmentType
        managerName = dept.managerName
        managerEmail = dept.managerEmail
        hotline = dept.hotline
        location = dept.location
        isActive = dept.isActive
        showEditSheet = true
    }

    private func refreshData() async {
        viewModel.fetchDepartments()
        viewModel.fetchUsers()
    }
    
    // REST API Helpers
    private func saveNewDept() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let did = deptId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/departments?documentId=\(did)"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let isHd = deptType == "HELPDESK"
        let isInc = deptType == "IT"
        let isWh = deptType == "WAREHOUSE"
        
        let body: [String: Any] = [
            "fields": [
                "departmentId": ["stringValue": did],
                "departmentName": ["stringValue": deptName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "departmentType": ["stringValue": deptType],
                "managerName": ["stringValue": managerName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "managerEmail": ["stringValue": managerEmail.trimmingCharacters(in: .whitespacesAndNewlines)],
                "hotline": ["stringValue": hotline.trimmingCharacters(in: .whitespacesAndNewlines)],
                "location": ["stringValue": location.trimmingCharacters(in: .whitespacesAndNewlines)],
                "isActive": ["booleanValue": true],
                "isHelpDesk": ["booleanValue": isHd],
                "isIncidentHandler": ["booleanValue": isInc],
                "isWarehouse": ["booleanValue": isWh],
                "companyId": ["stringValue": comp]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchDepartments()
        }
    }
    
    private func updateDept() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/departments/\(editingDeptId)?updateMask.fieldPaths=departmentName&updateMask.fieldPaths=departmentType&updateMask.fieldPaths=managerName&updateMask.fieldPaths=managerEmail&updateMask.fieldPaths=hotline&updateMask.fieldPaths=location&updateMask.fieldPaths=isActive&updateMask.fieldPaths=isHelpDesk&updateMask.fieldPaths=isIncidentHandler&updateMask.fieldPaths=isWarehouse"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let isHd = deptType == "HELPDESK"
        let isInc = deptType == "IT"
        let isWh = deptType == "WAREHOUSE"
        
        let body: [String: Any] = [
            "fields": [
                "departmentName": ["stringValue": deptName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "departmentType": ["stringValue": deptType],
                "managerName": ["stringValue": managerName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "managerEmail": ["stringValue": managerEmail.trimmingCharacters(in: .whitespacesAndNewlines)],
                "hotline": ["stringValue": hotline.trimmingCharacters(in: .whitespacesAndNewlines)],
                "location": ["stringValue": location.trimmingCharacters(in: .whitespacesAndNewlines)],
                "isActive": ["booleanValue": isActive],
                "isHelpDesk": ["booleanValue": isHd],
                "isIncidentHandler": ["booleanValue": isInc],
                "isWarehouse": ["booleanValue": isWh]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchDepartments()
        }
    }
    
    private func deleteDept(deptId: String) {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/departments/\(deptId)"
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchDepartments()
        }
    }
}
