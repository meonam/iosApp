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
    @State private var slaResponse: String = "30"
    @State private var slaResolve: String = "240"
    
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
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

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
                    .background(Color.appTopBarColor)

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

    private func deptRoleBadge(_ dept: Department) -> some View {
        let (icon, label, colorHex): (String, String, String) = {
            if dept.isHelpDesk || dept.departmentType == "HELPDESK" {
                return ("🎧", "HelpDesk", "#0284C7")
            } else if dept.isIncidentHandler || dept.departmentType == "IT" {
                return ("🛠️", "Xử lý sự cố", "#7E22CE")
            } else if dept.isApplicationSupport {
                return ("💻", "Khối ứng dụng", "#6D28D9")
            } else if dept.isWarehouse || dept.departmentType == "WAREHOUSE" {
                return ("📦", "Kho thiết bị", "#B45309")
            } else {
                return ("🏢", "Chuyên môn", "#64748B")
            }
        }()
        let color = Color(hex: colorHex)
        return Text("\(icon) \(label)")
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }

    private func deptCard(_ dept: Department) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Dept ID chip + Dept Name + Toggle Active
            HStack(spacing: 8) {
                Text(dept.departmentId)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(dept.isActive ? Color.appSecondaryDarkBlue : Color.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(dept.isActive ? Color(hex: "#EFF6FF") : Color(hex: "#F1F5F9"))
                    .cornerRadius(6)

                Text(dept.departmentName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(dept.isActive ? Color(hex: "#0F172A") : Color.gray)
                    .lineLimit(1)

                Spacer()

                Button(action: { toggleActive(dept) }) {
                    ZStack(alignment: dept.isActive ? .trailing : .leading) {
                        Capsule()
                            .fill(dept.isActive ? Color.appPrimaryPink : Color.gray.opacity(0.3))
                            .frame(width: 38, height: 22)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 18, height: 18)
                            .padding(.horizontal, 2)
                            .shadow(radius: 1)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Badges: Loại phòng ban / Vai trò
            HStack(spacing: 6) {
                deptRoleBadge(dept)
                if !dept.isActive {
                    Text("🔒 Đã khóa")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            // Thông tin chi tiết: Trưởng phòng, Hotline, Vị trí, SLA
            let detailParts: [String] = {
                var parts: [String] = []
                if !dept.managerName.isEmpty { parts.append("👤 \(dept.managerName)") }
                if !dept.hotline.isEmpty { parts.append("📞 \(dept.hotline)") }
                if !dept.location.isEmpty { parts.append("📍 \(dept.location)") }
                if dept.isHelpDesk || dept.isIncidentHandler || dept.isApplicationSupport {
                    parts.append("⏱️ SLA: \(dept.slaResponseMinutes)p/\(max(1, dept.slaResolveMinutes / 60))h")
                }
                return parts
            }()

            if !detailParts.isEmpty {
                Text(detailParts.joined(separator: " • "))
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }

            Divider()

            // Footer: Thống kê NV & Thao tác Sửa / Xóa
            HStack(spacing: 8) {
                Text("👥 \(getUserCount(for: dept.departmentId)) NV")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "#1D4ED8"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(6)

                Spacer()

                Button(action: { openEdit(dept) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 30, height: 30)
                        .background(Color(hex: "#F1F5F9"))
                        .cornerRadius(6)
                }

                Button(action: { deleteDept(deptId: dept.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.red)
                        .frame(width: 30, height: 30)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .opacity(dept.isActive ? 1.0 : 0.65)
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

                Section(header: Text("Cấu hình SLA (Hỗ trợ kỹ thuật)")) {
                    HStack {
                        Text("SLA Phản hồi (phút):")
                        Spacer()
                        TextField("30", text: $slaResponse)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("SLA Xử lý (phút):")
                        Spacer()
                        TextField("240", text: $slaResolve)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                if isEdit {
                    Section {
                        Toggle("Hoạt động", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(isEdit ? "Cập nhật phòng ban" : "Thêm phòng ban")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Hủy") {
                        showAddSheet = false
                        showEditSheet = false
                    }
                , trailing: Button("Lưu") {
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
                    .foregroundColor(Color.appPrimaryPink))
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
        slaResponse = "30"
        slaResolve = "240"
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
        slaResponse = "\(dept.slaResponseMinutes)"
        slaResolve = "\(dept.slaResolveMinutes)"
        showEditSheet = true
    }

    private func refreshData() async {
        viewModel.fetchDepartments()
        viewModel.fetchUsers()
    }
    
    // REST API Helpers
    private func toggleActive(_ dept: Department) {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let newActive = !dept.isActive
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments/\(dept.departmentId)?updateMask.fieldPaths=isActive"
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        let body: [String: Any] = [
            "fields": [
                "isActive": ["booleanValue": newActive]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            viewModel.fetchDepartments()
        }
    }

    private func saveNewDept() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let did = deptId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments?documentId=\(did)"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let isHd = deptType == "HELPDESK"
        let isInc = deptType == "IT"
        let isWh = deptType == "WAREHOUSE"
        let respMin = Int(slaResponse) ?? 30
        let resMin = Int(slaResolve) ?? 240
        
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
                "slaResponseMinutes": ["integerValue": "\(respMin)"],
                "slaResolveMinutes": ["integerValue": "\(resMin)"],
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
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments/\(editingDeptId)?updateMask.fieldPaths=departmentName&updateMask.fieldPaths=departmentType&updateMask.fieldPaths=managerName&updateMask.fieldPaths=managerEmail&updateMask.fieldPaths=hotline&updateMask.fieldPaths=location&updateMask.fieldPaths=isActive&updateMask.fieldPaths=isHelpDesk&updateMask.fieldPaths=isIncidentHandler&updateMask.fieldPaths=isWarehouse&updateMask.fieldPaths=slaResponseMinutes&updateMask.fieldPaths=slaResolveMinutes"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let isHd = deptType == "HELPDESK"
        let isInc = deptType == "IT"
        let isWh = deptType == "WAREHOUSE"
        let respMin = Int(slaResponse) ?? 30
        let resMin = Int(slaResolve) ?? 240
        
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
                "isWarehouse": ["booleanValue": isWh],
                "slaResponseMinutes": ["integerValue": "\(respMin)"],
                "slaResolveMinutes": ["integerValue": "\(resMin)"]
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
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments/\(deptId)"
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


