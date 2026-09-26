import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ LOẠI THIẾT BỊ
struct DeviceTypeModel: Identifiable, Hashable {
    let id: String
    var displayName: String
    var phongBan: String?
}

public struct DeviceTypeManagerView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void

    @State private var types: [DeviceTypeModel] = []
    @State private var deviceCounts: [String: Int] = [:]
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""
    
    // Add Dialog
    @State private var showAddDialog: Bool = false
    @State private var newTypeName: String = ""
    @State private var newTypeDept: String = ""
    
    // Edit Dialog
    @State private var editingType: DeviceTypeModel? = nil
    @State private var editTypeName: String = ""
    
    // Delete Alert
    @State private var showDeleteDialog: Bool = false
    @State private var typeToDelete: DeviceTypeModel? = nil
    @State private var showDeleteAllDialog: Bool = false

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }
    
    private var filteredTypes: [DeviceTypeModel] {
        if searchQuery.isEmpty {
            return types
        } else {
            return types.filter { $0.displayName.lowercased().contains(searchQuery.lowercased()) }
        }
    }
    
    private var canManage: Bool {
        let role = authViewModel.currentUser?.role.lowercased() ?? ""
        return role == "admin" || role == "phongban" || role == "quanly" || true // Defaults to true for test
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
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("QUẢN LÝ LOẠI THIẾT BỊ")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Toàn hệ thống")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.7))
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
                                            .font(.system(size: 18))
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
                                .foregroundColor(.white)
                            TextField("Tìm kiếm loại thiết bị", text: $searchQuery)
                                .foregroundColor(.white)
                                .accentColor(.white)
                                .padding(.vertical, 10)
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .background(Color.appTopBarColor) // Assuming appTopBarColor / appPrimary

                    // DANH SÁCH
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if filteredTypes.isEmpty {
                        Spacer()
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text(searchQuery.isEmpty ? "Chưa có loại thiết bị nào" : "Không tìm thấy loại thiết bị")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTypes) { type in
                                    deviceTypeCard(type: type)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            loadDeviceTypes()
        }
        
        // Add Dialog
        .alert("Thêm Loại Thiết Bị", isPresented: $showAddDialog) {
            TextField("Tên loại thiết bị", text: $newTypeName)
            Button("Hủy", role: .cancel) { newTypeName = "" }
            Button("Thêm") {
                if !newTypeName.isEmpty {
                    addDeviceType(name: newTypeName)
                    newTypeName = ""
                }
            }
        } message: {
            Text("Nhập tên loại thiết bị mới.")
        }
        
        // Delete Alert
        .alert("Xóa Loại Thiết Bị?", isPresented: $showDeleteDialog) {
            Button("Hủy", role: .cancel) { typeToDelete = nil }
            Button("Xóa", role: .destructive) {
                if let type = typeToDelete {
                    deleteDeviceType(id: type.id)
                }
            }
        } message: {
            Text("Bạn có chắc chắn muốn xóa '\(typeToDelete?.displayName ?? "")' không? Hành động này không thể hoàn tác.")
        }
        
        // Delete All Alert
        .alert("Xóa Tất Cả?", isPresented: $showDeleteAllDialog) {
            Button("Hủy", role: .cancel) { }
            Button("Xóa Tất Cả", role: .destructive) {
                // Implement delete all
            }
        } message: {
            Text("Xóa toàn bộ loại thiết bị khỏi hệ thống?")
        }
    }
    
    @ViewBuilder
    private func deviceTypeCard(type: DeviceTypeModel) -> some View {
        let isEditing = editingType?.id == type.id
        
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.appSecondaryDarkBlue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: getIcon(for: type.displayName))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
            
            if isEditing {
                VStack {
                    TextField("Tên loại", text: $editTypeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    HStack {
                        Spacer()
                        Button("Hủy") { editingType = nil }
                            .foregroundColor(.gray)
                        Button("Lưu") {
                            updateDeviceType(id: type.id, newName: editTypeName)
                            editingType = nil
                        }
                        .foregroundColor(.green)
                        .padding(.leading, 8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    
                    HStack {
                        let count = deviceCounts[type.id] ?? 0
                        Text("\(count) thiết bị")
                            .font(.system(size: 12))
                            .foregroundColor(count > 0 ? Color.appPrimaryPink : .gray)
                        if let pb = type.phongBan, !pb.isEmpty {
                            Text("•")
                                .foregroundColor(.gray)
                            Text(pb)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                
                if canManage {
                    HStack(spacing: 12) {
                        Button(action: {
                            editingType = type
                            editTypeName = type.displayName
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.gray)
                        }
                        Button(action: {
                            typeToDelete = type
                            showDeleteDialog = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "DDE2E5"), lineWidth: 1))
    }
    
    private func getIcon(for name: String) -> String {
        let n = name.lowercased()
        if n.contains("máy tính") || n.contains("laptop") || n.contains("pc") { return "desktopcomputer" }
        if n.contains("máy in") || n.contains("printer") { return "printer" }
        if n.contains("màn hình") || n.contains("monitor") { return "display" }
        if n.contains("điện thoại") || n.contains("phone") { return "iphone" }
        if n.contains("mạng") || n.contains("wifi") || n.contains("router") { return "wifi.router" }
        if n.contains("camera") { return "video" }
        return "square.grid.2x2"
    }
    
    // MARK: - API Calls
    private func loadDeviceTypes() {
        self.isLoading = true
        let companyId = authViewModel.currentCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/device_types"
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let docs = json["documents"] as? [[String: Any]] {
                        
                        var res: [DeviceTypeModel] = []
                        for doc in docs {
                            if let fields = doc["fields"] as? [String: Any] {
                                let id = (doc["name"] as? String)?.components(separatedBy: "/").last ?? ""
                                let name = FirestoreHelper.getString(fields, "displayName")
                                let pb = FirestoreHelper.getString(fields, "phongBan")
                                res.append(DeviceTypeModel(id: id, displayName: name, phongBan: pb))
                            }
                        }
                        self.types = res.sorted { $0.displayName < $1.displayName }
                    }
                } catch {}
            }
        }.resume()
    }
    
    private func addDeviceType(name: String) {
        let companyId = authViewModel.currentCompanyId
        let generatedId = name.folding(options: .diacriticInsensitive, locale: .current).replacingOccurrences(of: " ", with: "_").lowercased()
        
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/device_types?documentId=\(generatedId)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "fields": [
                "displayName": ["stringValue": name]
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
        let companyId = authViewModel.currentCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/device_types/\(id)?updateMask.fieldPaths=displayName"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body: [String: Any] = [
            "fields": [
                "displayName": ["stringValue": newName]
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
        let companyId = authViewModel.currentCompanyId
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/device_types/\(id)"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "DELETE"
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { _, res, _ in
            if let httpRes = res as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                DispatchQueue.main.async { self.loadDeviceTypes() }
            }
        }.resume()
    }
}
