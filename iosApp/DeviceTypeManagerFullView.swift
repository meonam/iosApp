import SwiftUI
import UIKit

// MARK: - DEVICE TYPE MODEL
struct DeviceTypeRecord: Identifiable, Hashable, Sendable {
    var id: String
    var displayName: String
    var phongBan: String? = nil
}

// MARK: - DEVICE TYPE MANAGER FULL VIEW (Matches Android DeviceTypeManagerScreen.kt)
struct DeviceTypeManagerFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @State private var deviceTypes: [DeviceTypeRecord] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    // Dialog states
    @State private var showAddDialog: Bool = false
    @State private var newTypeName: String = ""
    @State private var newTypeDept: String = ""

    // Editing states
    @State private var editingTypeId: String? = nil
    @State private var editTypeName: String = ""

    // Deletion states
    @State private var showDeleteDialog: Bool = false
    @State private var typeToDelete: DeviceTypeRecord? = nil
    @State private var showDeleteAllDialog: Bool = false

    // Swipe back offset
    @State private var dragOffsetX: CGFloat = 0

    // Permissions
    var userRole: String {
        firebase.userRole.lowercased()
    }
    var canManage: Bool {
        userRole == "admin" || userRole == "phongban" || userRole == "quanly"
    }
    var isAdmin: Bool {
        userRole == "admin"
    }

    private var firestoreBaseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(firebase.projectId)/databases/(default)/documents/companies/\(firebase.companyId)"
    }

    // Auto-generated ID
    var autoTypeId: String {
        Self.generateStandardDeviceTypeId(name: newTypeName, dept: newTypeDept)
    }

    // Device counts map
    var deviceCounts: [String: Int] {
        var map: [String: Int] = [:]
        for dev in firebase.devices {
            let cat = dev.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            map[cat, default: 0] += 1
        }
        return map
    }

    // Filtered list
    var filteredTypes: [DeviceTypeRecord] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return deviceTypes
        }
        return deviceTypes.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.id.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar in Saigon Co.op TopBar Header
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Tìm kiếm loại thiết bị...", text: $searchQuery)
                                .foregroundColor(.white)
                                .tint(.white)
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appTopBar)

                    // Message banner
                    if let msg = successMessage {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.green)
                            Spacer()
                            Button(action: { successMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.1))
                    }

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.red)
                            Spacer()
                            Button(action: { errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                    }

                    // Main List
                    if isLoading && deviceTypes.isEmpty {
                        Spacer()
                        ProgressView("Đang tải danh mục loại thiết bị...")
                            .font(.system(size: 14))
                        Spacer()
                    } else if filteredTypes.isEmpty {
                        Spacer()
                        VStack(spacing: 14) {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.4))
                            Text(searchQuery.isEmpty ? "Chưa có loại thiết bị nào" : "Không tìm thấy loại thiết bị phù hợp với \"\(searchQuery)\"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTypes) { type in
                                    deviceTypeRow(type)
                                }
                            }
                            .padding(16)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onDismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Trở lại")
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("QUẢN LÝ LOẠI THIẾT BỊ")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text(isAdmin ? "Toàn hệ thống Saigon Co.op" : "Phòng ban phụ trách")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if canManage && !deviceTypes.isEmpty {
                            Button(action: { showDeleteAllDialog = true }) {
                                Image(systemName: "trash.slash")
                                    .foregroundColor(.white)
                            }
                        }
                        if canManage {
                            Button(action: {
                                newTypeName = ""
                                newTypeDept = isAdmin ? "" : firebase.userDept
                                showAddDialog = true
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffsetX = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        onDismiss()
                    }
                    dragOffsetX = 0
                }
        )
        .onAppear {
            loadDeviceTypesFromFirestore()
        }
        // Modal thêm loại thiết bị mới
        .sheet(isPresented: $showAddDialog) {
            addDeviceTypeSheet
        }
        // Alert xóa 1 loại
        .alert(isPresented: $showDeleteDialog) {
            Alert(
                title: Text("Xác nhận xóa loại thiết bị"),
                message: Text("Bạn có chắc chắn muốn xóa loại thiết bị \"\(typeToDelete?.displayName ?? "")\" khỏi hệ thống?"),
                primaryButton: .destructive(Text("Xóa")) {
                    if let t = typeToDelete {
                        deleteDeviceType(t.id)
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        // Alert xóa tất cả
        .alert(isPresented: $showDeleteAllDialog) {
            Alert(
                title: Text("Cảnh báo xóa toàn bộ"),
                message: Text("Thao tác này sẽ xóa TẤT CẢ các danh mục loại thiết bị trong hệ thống. Hành động này không thể hoàn tác!"),
                primaryButton: .destructive(Text("Xóa tất cả")) {
                    deleteAllDeviceTypes()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - ROW ITEM
    @ViewBuilder
    private func deviceTypeRow(_ type: DeviceTypeRecord) -> some View {
        let isEditing = editingTypeId == type.id
        let count = deviceCounts[type.id.lowercased()] ?? deviceCounts[type.displayName.lowercased()] ?? 0

        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Type Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.appSecondaryDarkBlue.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: getDeviceTypeSystemIcon(type.displayName))
                        .font(.system(size: 20))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                if isEditing && canManage {
                    // Inline edit view
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Tên loại thiết bị", text: $editTypeName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14, weight: .medium))

                        HStack {
                            Spacer()
                            Button("Hủy") {
                                editingTypeId = nil
                            }
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)

                            Button("Lưu") {
                                updateDeviceType(id: type.id, newName: editTypeName)
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.green)
                        }
                    }
                } else {
                    // Normal display view
                    VStack(alignment: .leading, spacing: 4) {
                        Text(type.displayName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)

                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(count > 0 ? Color.appPrimaryPink : Color.gray.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text("\(count) thiết bị")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(count > 0 ? Color.appPrimaryPink : Color.gray)
                            }

                            if let pb = type.phongBan, !pb.isEmpty {
                                Text("•")
                                    .foregroundColor(.gray.opacity(0.5))
                                Text(pb)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.65))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    if canManage {
                        HStack(spacing: 8) {
                            Button(action: {
                                editingTypeId = type.id
                                editTypeName = type.displayName
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.appSecondaryDarkBlue.opacity(0.6))
                            }

                            Button(action: {
                                typeToDelete = type
                                showDeleteDialog = true
                            }) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color.red.opacity(0.7))
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }

    // MARK: - ADD DEVICE TYPE SHEET
    private var addDeviceTypeSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN LOẠI THIẾT BỊ")) {
                    TextField("Tên loại (VD: Máy in hóa đơn, POS, Laptop)", text: $newTypeName)
                        .font(.system(size: 14))

                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(Color.appPrimaryPink)
                            .font(.system(size: 13))
                        Text("Mã loại:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                        Text(autoTypeId.isEmpty ? "(Tự động sinh)" : autoTypeId)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                }

                if isAdmin {
                    Section(header: Text("PHÒNG BAN QUẢN LÝ")) {
                        Picker("Phòng ban", selection: $newTypeDept) {
                            Text("(Tất cả / Chung)").tag("")
                            ForEach(firebase.departmentsList) { dept in
                                Text("\(dept.name) [\(dept.id)]").tag(dept.name)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Thêm loại thiết bị mới")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddDialog = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Thêm") {
                        if !newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            addDeviceTypeToFirestore(name: newTypeName, dept: newTypeDept, customId: autoTypeId)
                            showAddDialog = false
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .disabled(newTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }

    // MARK: - FIRESTORE REST ENGINE ACTIONS
    private func loadDeviceTypesFromFirestore() {
        isLoading = true
        errorMessage = nil

        let urlStr = "\(firestoreBaseURL)/device_types"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !firebase.currentUserIdToken.isEmpty {
            request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Lỗi kết nối Firestore: \(error.localizedDescription)"
                    self.loadFallbackDefaultTypes()
                    return
                }

                guard let data = data else {
                    self.loadFallbackDefaultTypes()
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let docs = json["documents"] as? [[String: Any]] {
                        var list: [DeviceTypeRecord] = []
                        for doc in docs {
                            if let name = doc["name"] as? String,
                               let fields = doc["fields"] as? [String: Any] {
                                let docId = name.components(separatedBy: "/").last ?? ""
                                let displayName = (fields["name"] as? [String: Any])?["stringValue"] as? String ??
                                                  (fields["displayName"] as? [String: Any])?["stringValue"] as? String ?? docId
                                let pb = (fields["phongBan"] as? [String: Any])?["stringValue"] as? String
                                list.append(DeviceTypeRecord(id: docId, displayName: displayName, phongBan: pb))
                            }
                        }

                        if list.isEmpty {
                            self.loadFallbackDefaultTypes()
                        } else {
                            self.deviceTypes = list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                        }
                    } else {
                        self.loadFallbackDefaultTypes()
                    }
                } catch {
                    self.loadFallbackDefaultTypes()
                }
            }
        }.resume()
    }

    private func loadFallbackDefaultTypes() {
        if !deviceTypes.isEmpty { return }
        // Pre-populate with standard Co.opmart categories
        let defaults: [(String, String)] = [
            ("MAY_BAN_HANG_POS", "Máy bán hàng POS"),
            ("MAY_QUET_MA_VACH", "Máy quét mã vạch"),
            ("MAY_IN_BILL_NHIET", "Máy in hóa đơn nhiệt"),
            ("THIET_BI_MANG_WIFI", "Thiết bị mạng WiFi"),
            ("BO_LUU_DIEN_UPS", "Bộ lưu điện UPS"),
            ("MAY_VI_TINH_PC", "Máy vi tính PC"),
            ("LAPTOP", "Máy tính xách tay Laptop"),
            ("CAMERA_AN_NINH", "Camera giám sát an ninh")
        ]
        self.deviceTypes = defaults.map { DeviceTypeRecord(id: $0.0, displayName: $0.1, phongBan: nil) }
    }

    private func addDeviceTypeToFirestore(name: String, dept: String, customId: String) {
        let docId = customId.isEmpty ? Self.generateStandardDeviceTypeId(name: name, dept: dept) : customId
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let urlStr = "\(firestoreBaseURL)/device_types?documentId=\(docId)"
        guard let url = URL(string: urlStr) else { return }

        var fields: [String: Any] = [
            "id": ["stringValue": docId],
            "name": ["stringValue": trimmedName]
        ]
        if !dept.isEmpty {
            fields["phongBan"] = ["stringValue": dept]
        }

        let body: [String: Any] = ["fields": fields]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !firebase.currentUserIdToken.isEmpty {
            request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch { return }

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                self.successMessage = "Đã thêm loại thiết bị: \(trimmedName)"
                self.loadDeviceTypesFromFirestore()
            }
        }.resume()
    }

    private func updateDeviceType(id: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }

        let urlStr = "\(firestoreBaseURL)/device_types/\(id)?updateMask.fieldPaths=name"
        guard let url = URL(string: urlStr) else { return }

        let body: [String: Any] = [
            "fields": [
                "name": ["stringValue": trimmed]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !firebase.currentUserIdToken.isEmpty {
            request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch { return }

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                self.editingTypeId = nil
                self.successMessage = "Đã cập nhật: \(trimmed)"
                self.loadDeviceTypesFromFirestore()
            }
        }.resume()
    }

    private func deleteDeviceType(_ id: String) {
        let urlStr = "\(firestoreBaseURL)/device_types/\(id)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !firebase.currentUserIdToken.isEmpty {
            request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                self.successMessage = "Đã xóa loại thiết bị"
                self.loadDeviceTypesFromFirestore()
            }
        }.resume()
    }

    private func deleteAllDeviceTypes() {
        for t in deviceTypes {
            deleteDeviceType(t.id)
        }
        deviceTypes.removeAll()
        successMessage = "Đã xóa toàn bộ danh mục loại thiết bị"
    }

    // Helper: generate standard ID
    static func generateStandardDeviceTypeId(name: String, dept: String = "") -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "" }

        let unaccented = trimmed.folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")

        let cleanName = unaccented.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()

        let cleanDept = dept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()

        return cleanDept.isEmpty ? cleanName : "\(cleanName)_\(cleanDept)"
    }

    // Helper: System icons
    private func getDeviceTypeSystemIcon(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("máy tính") || n.contains("laptop") || n.contains("pc") {
            return "desktopcomputer"
        } else if n.contains("máy in") || n.contains("printer") || n.contains("bill") {
            return "printer.fill"
        } else if n.contains("màn hình") || n.contains("monitor") {
            return "display"
        } else if n.contains("điện thoại") || n.contains("phone") {
            return "iphone"
        } else if n.contains("mạng") || n.contains("wifi") || n.contains("router") {
            return "wifi"
        } else if n.contains("camera") {
            return "video.fill"
        } else if n.contains("pos") || n.contains("bán hàng") {
            return "computermouse.fill"
        } else if n.contains("quét") || n.contains("barcode") || n.contains("mã vạch") {
            return "barcode.viewfinder"
        } else if n.contains("ups") || n.contains("lưu điện") || n.contains("pin") {
            return "bolt.batteryblock.fill"
        }
        return "square.grid.2x2"
    }
}
