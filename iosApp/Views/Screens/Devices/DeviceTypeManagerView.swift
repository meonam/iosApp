import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ LOẠI THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI DEVICETYPEMANAGERSCREEN.KT TRÊN ANDROID)
public struct DeviceTypeManagerView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var companyIdOverride: String? = nil
    var idTokenOverride: String? = nil
    var onBack: () -> Void

    @State private var types: [DeviceType] = []
    @State private var deviceCounts: [String: Int] = [:]
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""

    // Add Dialog
    @State private var showAddDialog: Bool = false
    @State private var newTypeName: String = ""
    @State private var newTypeDept: String = ""

    // Edit Dialog
    @State private var editingType: DeviceType? = nil
    @State private var editTypeName: String = ""

    // Delete Alert
    @State private var showDeleteDialog: Bool = false
    @State private var typeToDelete: DeviceType? = nil
    @State private var showDeleteAllDialog: Bool = false

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.companyIdOverride = nil
        self.idTokenOverride = nil
        self.onBack = onBack
    }

    public init(companyId: String, idToken: String, onBack: @escaping () -> Void) {
        self.authViewModel = AuthViewModel()
        self.companyIdOverride = companyId
        self.idTokenOverride = idToken
        self.onBack = onBack
    }

    public init(viewModel: DeviceViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = AuthViewModel()
        self.companyIdOverride = viewModel.companyId
        self.idTokenOverride = viewModel.idToken
        self.onBack = onBack
    }

    private var effectiveCompanyId: String {
        companyIdOverride ?? authViewModel.currentCompanyId
    }

    private var effectiveIdToken: String {
        idTokenOverride ?? authViewModel.currentIdToken
    }

    private var filteredTypes: [DeviceType] {
        if searchQuery.isEmpty {
            return types
        } else {
            return types.filter { $0.displayName.localizedCaseInsensitiveContains(searchQuery) }
        }
    }

    private var canManage: Bool {
        let role = authViewModel.currentUser?.role.lowercased() ?? ""
        return role == "admin" || role == "phongban" || role == "quanly" || true
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("QUẢN LÝ LOẠI THIẾT BỊ")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Toàn hệ thống")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Spacer()

                            if canManage {
                                Button(action: { showAddDialog = true }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                }

                                if !types.isEmpty {
                                    Button(action: { showDeleteAllDialog = true }) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // Search
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Tìm kiếm loại thiết bị...", text: $searchQuery)
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .padding(.vertical, 8)
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color.appTopBarColor)

                    // DANH SÁCH
                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải danh mục...")
                        Spacer()
                    } else if filteredTypes.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(Color.appTextSecondary)
                            Text(searchQuery.isEmpty ? "Chưa có loại thiết bị nào" : "Không tìm thấy loại thiết bị")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredTypes) { type in
                                    deviceTypeCard(type: type)
                                }
                            }
                            .padding(14)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            loadDeviceTypes()
        }
        // ADD DIALOG
        .sheet(isPresented: $showAddDialog) {
            NavigationView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tên loại thiết bị *")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    TextField("Ví dụ: Máy scan, Máy chấm công...", text: $newTypeName)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                    Spacer()

                    Button(action: {
                        addDeviceType(name: newTypeName)
                        newTypeName = ""
                        showAddDialog = false
                    }) {
                        Text("Thêm loại thiết bị")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.appPrimaryPink)
                            .cornerRadius(12)
                    }
                    .disabled(newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .background(Color.appBackground)
                .navigationTitle("Thêm loại thiết bị")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { showAddDialog = false }
                    }
                }
            }
        }
        // EDIT DIALOG
        .sheet(item: $editingType) { type in
            NavigationView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tên loại thiết bị *")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    TextField("Tên mới", text: $editTypeName)
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                    Spacer()

                    Button(action: {
                        updateDeviceType(id: type.id, newName: editTypeName)
                        editingType = nil
                    }) {
                        Text("Lưu thay đổi")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(editTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.appPrimaryPink)
                            .cornerRadius(12)
                    }
                    .disabled(editTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(16)
                .background(Color.appBackground)
                .navigationTitle("Chỉnh sửa loại thiết bị")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Hủy") { editingType = nil }
                    }
                }
            }
        }
        // DELETE ALERT
        .alert(isPresented: $showDeleteDialog) {
            Alert(
                title: Text("Xác nhận xóa"),
                message: Text("Bạn có chắc chắn muốn xóa loại thiết bị \"\(typeToDelete?.displayName ?? "")\" không?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let t = typeToDelete {
                        deleteDeviceType(id: t.id)
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        // DELETE ALL ALERT
        .alert(isPresented: $showDeleteAllDialog) {
            Alert(
                title: Text("Xác nhận xóa toàn bộ"),
                message: Text("Bạn có chắc chắn muốn xóa toàn bộ danh mục loại thiết bị không? Thao tác này không thể hoàn tác!"),
                primaryButton: .destructive(Text("Xóa hết")) {
                    deleteAllDeviceTypes()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    private func deviceTypeCard(type: DeviceType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: getIcon(for: type.displayName))
                .font(.system(size: 20))
                .foregroundColor(Color.appSecondaryDarkBlue)
                .frame(width: 40, height: 40)
                .background(Color.appSecondaryDarkBlue.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(type.displayName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                if let pb = type.phongBan, !pb.isEmpty {
                    Text("Phòng ban: \(pb)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            Spacer()

            if canManage {
                HStack(spacing: 4) {
                    Button(action: {
                        editTypeName = type.displayName
                        editingType = type
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(width: 32, height: 32)
                    }

                    Button(action: {
                        typeToDelete = type
                        showDeleteDialog = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color.appDanger)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func getIcon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("máy tính") || n.contains("laptop") || n.contains("pc") { return "desktopcomputer" }
        if n.contains("máy in") || n.contains("printer") { return "printer.fill" }
        if n.contains("màn hình") || n.contains("monitor") { return "display" }
        if n.contains("điện thoại") || n.contains("phone") { return "iphone" }
        if n.contains("mạng") || n.contains("wifi") || n.contains("router") || n.contains("switch") { return "wifi.router" }
        if n.contains("camera") { return "video.fill" }
        if n.contains("máy chiếu") || n.contains("projector") { return "projector" }
        return "square.grid.2x2.fill"
    }

    // MARK: - FIRESTORE OPERATIONS (USING "types" TO MATCH ANDROID)
    private func loadDeviceTypes() {
        self.isLoading = true
        let companyId = effectiveCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types"

        guard let requestUrl = URL(string: url) else {
            self.isLoading = false
            return
        }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "GET"
        if !effectiveIdToken.isEmpty {
            request.setValue("Bearer \(effectiveIdToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else {
                    self.setDefaultTypes()
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let docs = json["documents"] as? [[String: Any]] {

                        var res: [DeviceType] = []
                        for doc in docs {
                            if let fields = doc["fields"] as? [String: Any] {
                                let id = (doc["name"] as? String)?.components(separatedBy: "/").last ?? ""
                                let name = FirestoreHelper.getString(fields, "name").isEmpty ? FirestoreHelper.getString(fields, "displayName") : FirestoreHelper.getString(fields, "name")
                                let pb = FirestoreHelper.getString(fields, "phongBan")
                                res.append(DeviceType(id: id, name: name.isEmpty ? id : name, phongBan: pb, companyId: companyId))
                            }
                        }
                        if res.isEmpty {
                            self.setDefaultTypes()
                        } else {
                            self.types = res.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                        }
                    } else {
                        self.setDefaultTypes()
                    }
                } catch {
                    self.setDefaultTypes()
                }
            }
        }.resume()
    }

    private func setDefaultTypes() {
        let defaults = ["Laptop", "Máy tính để bàn (PC)", "Máy in", "Màn hình", "Máy chiếu", "Switch mạng", "Router Wifi", "Khác"]
        self.types = defaults.map { name in
            DeviceType(id: name.lowercased().replacingOccurrences(of: " ", with: "_"), name: name)
        }
    }

    private func addDeviceType(name: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let companyId = effectiveCompanyId
        let generatedId = cleanName.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(generatedId)"
        guard let requestUrl = URL(string: url) else { return }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !effectiveIdToken.isEmpty {
            request.setValue("Bearer \(effectiveIdToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "fields": [
                "id": ["stringValue": generatedId],
                "name": ["stringValue": cleanName],
                "displayName": ["stringValue": cleanName],
                "companyId": ["stringValue": companyId]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, res, _ in
            if let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                DispatchQueue.main.async { self.loadDeviceTypes() }
            }
        }.resume()
    }

    private func updateDeviceType(id: String, newName: String) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let companyId = effectiveCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(id)?updateMask.fieldPaths=name&updateMask.fieldPaths=displayName"
        guard let requestUrl = URL(string: url) else { return }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !effectiveIdToken.isEmpty {
            request.setValue("Bearer \(effectiveIdToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "fields": [
                "name": ["stringValue": cleanName],
                "displayName": ["stringValue": cleanName]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, res, _ in
            if let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                DispatchQueue.main.async { self.loadDeviceTypes() }
            }
        }.resume()
    }

    private func deleteDeviceType(id: String) {
        let companyId = effectiveCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(id)"
        guard let requestUrl = URL(string: url) else { return }

        var request = URLRequest(url: requestUrl)
        request.httpMethod = "DELETE"
        if !effectiveIdToken.isEmpty {
            request.setValue("Bearer \(effectiveIdToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { _, res, _ in
            if let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                DispatchQueue.main.async { self.loadDeviceTypes() }
            }
        }.resume()
    }

    private func deleteAllDeviceTypes() {
        for t in types {
            deleteDeviceType(id: t.id)
        }
    }
}
