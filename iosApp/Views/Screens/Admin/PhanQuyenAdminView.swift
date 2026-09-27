import SwiftUI

public struct AdminUserInfo: Identifiable, Hashable {
    public let id: String
    public let email: String
    public var allowedRoles: [String]

    public init(id: String = UUID().uuidString, email: String, allowedRoles: [String]) {
        self.id = id
        self.email = email
        self.allowedRoles = allowedRoles
    }
}

public struct RoleInfo: Identifiable, Hashable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct PhanQuyenAdminView: View {
    public var companyId: String
    public var token: String
    public var onBack: () -> Void

    @State private var allAdmins: [AdminUserInfo] = []
    @State private var availableRoles: [RoleInfo] = []
    @State private var selectedAdmin: AdminUserInfo? = nil
    @State private var selectedRoles: Set<String> = []

    @State private var isLoading = false
    @State private var isSaving = false
    @State private var message = ""
    @State private var showMessage = false

    public init(companyId: String = "SGCOOP", token: String = "", onBack: @escaping () -> Void = {}) {
        self.companyId = companyId.isEmpty ? "SGCOOP" : companyId
        self.token = token
        self.onBack = onBack
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
                            Text("Phân quyền Sub-Admin")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()

                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Button(action: { Task { await loadData() } }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 17))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    if isLoading && allAdmins.isEmpty {
                        Spacer()
                        ProgressView("Đang tải danh sách Admin...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 18) {
                                // Chọn Sub-Admin
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Chọn Sub-Admin:")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)

                                    if allAdmins.isEmpty {
                                        Text("Không tìm thấy tài khoản Quản trị viên nào trong hệ thống.")
                                            .font(.system(size: 13))
                                            .foregroundColor(.gray)
                                            .padding(.vertical, 8)
                                    } else {
                                        Menu {
                                            ForEach(allAdmins) { admin in
                                                Button(admin.email) {
                                                    selectedAdmin = admin
                                                    selectedRoles = Set(admin.allowedRoles)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "person.badge.shield.checkmark.fill")
                                                    .foregroundColor(Color.appPrimaryPink)
                                                Text(selectedAdmin?.email ?? "Chọn Admin...")
                                                    .foregroundColor(selectedAdmin == nil ? .gray : Color.appSecondaryDarkBlue)
                                                    .font(.system(size: 14, weight: selectedAdmin == nil ? .regular : .semibold))
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(14)
                                            .background(Color.appSurface)
                                            .cornerRadius(10)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                                        }
                                    }
                                }

                                if let admin = selectedAdmin {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Quyền có thể tạo & cấp phát:")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)

                                        VStack(spacing: 8) {
                                            ForEach(availableRoles) { role in
                                                Button(action: {
                                                    if selectedRoles.contains(role.id) {
                                                        selectedRoles.remove(role.id)
                                                    } else {
                                                        selectedRoles.insert(role.id)
                                                    }
                                                }) {
                                                    HStack {
                                                        Image(systemName: selectedRoles.contains(role.id) ? "checkmark.square.fill" : "square")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(selectedRoles.contains(role.id) ? Color.appPrimaryPink : .gray)

                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(role.displayName)
                                                                .font(.system(size: 14, weight: .medium))
                                                                .foregroundColor(Color.appSecondaryDarkBlue)
                                                            Text("Mã quyền: \(role.id)")
                                                                .font(.system(size: 11))
                                                                .foregroundColor(.gray)
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(12)
                                                    .background(Color.appSurface)
                                                    .cornerRadius(10)
                                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedRoles.contains(role.id) ? Color.appPrimaryPink.opacity(0.3) : Color.appCardBorder, lineWidth: 1))
                                                }
                                            }
                                        }

                                        Button(action: {
                                            Task { await updatePermissions() }
                                        }) {
                                            HStack {
                                                if isSaving {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                } else {
                                                    Image(systemName: "checkmark.circle.fill")
                                                    Text("Cập nhật quyền cho \(admin.email)")
                                                        .fontWeight(.bold)
                                                }
                                            }
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                            .background(Color.appPrimaryPink)
                                            .cornerRadius(10)
                                        }
                                        .disabled(isSaving)
                                        .padding(.top, 12)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert(isPresented: $showMessage) {
            Alert(title: Text("Thông báo"), message: Text(message), dismissButton: .default(Text("OK")))
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // 1. Tải danh sách vai trò khả dụng
        let defaultRoles = [
            RoleInfo(id: "ADMIN", displayName: "Quản trị viên (Admin)"),
            RoleInfo(id: "HELPDESK", displayName: "Hỗ trợ viên (HelpDesk)"),
            RoleInfo(id: "TECHNICIAN", displayName: "Kỹ thuật viên (Technician)"),
            RoleInfo(id: "STAFF", displayName: "Nhân viên (Staff)")
        ]

        var loadedRoles: [RoleInfo] = []
        let rolesUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/roles"
        if let rolesUrl = URL(string: rolesUrlStr) {
            var req = URLRequest(url: rolesUrl)
            if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            if let (data, res) = try? await URLSession.shared.data(for: req),
               let http = res as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]] {
                for doc in docs {
                    let docName = doc["name"] as? String ?? ""
                    let id = docName.components(separatedBy: "/").last ?? ""
                    if let fields = doc["fields"] as? [String: Any] {
                        let name = FirestoreHelper.getString(fields["displayName"] as? [String: Any])
                        if !id.isEmpty {
                            loadedRoles.append(RoleInfo(id: id, displayName: name.isEmpty ? id : name))
                        }
                    }
                }
            }
        }
        self.availableRoles = loadedRoles.isEmpty ? defaultRoles : loadedRoles

        // 2. Tải danh sách Admin từ công ty hoặc root users
        let comp = companyId.isEmpty ? "SGCOOP" : companyId
        let usersUrls = [
            "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/users?pageSize=200",
            "\(FirebaseConfig.firestoreBaseUrl)/users?pageSize=200"
        ]

        var adminsFound: [AdminUserInfo] = []
        for urlStr in usersUrls {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url)
            if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

            if let (data, res) = try? await URLSession.shared.data(for: req),
               let http = res as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let docs = json["documents"] as? [[String: Any]], !docs.isEmpty {

                for doc in docs {
                    let docName = doc["name"] as? String ?? ""
                    let email = docName.components(separatedBy: "/").last ?? ""
                    if let fields = doc["fields"] as? [String: Any] {
                        let role = FirestoreHelper.getString(fields["role"] as? [String: Any]).uppercased()
                        if role == "ADMIN" || role == "SUB_ADMIN" {
                            let allowed = FirestoreHelper.getStringArray(fields["allowedRoles"] as? [String: Any])
                            adminsFound.append(AdminUserInfo(id: email, email: email, allowedRoles: allowed))
                        }
                    }
                }
                if !adminsFound.isEmpty { break }
            }
        }

        self.allAdmins = adminsFound
        if selectedAdmin == nil, let first = adminsFound.first {
            selectedAdmin = first
            selectedRoles = Set(first.allowedRoles)
        }
    }

    private func updatePermissions() async {
        guard let admin = selectedAdmin else { return }
        isSaving = true
        defer { isSaving = false }

        let comp = companyId.isEmpty ? "SGCOOP" : companyId
        let encodedEmail = admin.email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? admin.email
        let arrayValues = selectedRoles.map { ["stringValue": $0] }

        let body: [String: Any] = [
            "fields": [
                "allowedRoles": [
                    "arrayValue": [
                        "values": arrayValues
                    ]
                ]
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        let patchUrls = [
            "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/users/\(encodedEmail)?updateMask.fieldPaths=allowedRoles",
            "\(FirebaseConfig.firestoreBaseUrl)/users/\(encodedEmail)?updateMask.fieldPaths=allowedRoles"
        ]

        var success = false
        for urlStr in patchUrls {
            guard let url = URL(string: urlStr) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "PATCH"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            req.httpBody = bodyData

            if let (_, res) = try? await URLSession.shared.data(for: req),
               let http = res as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                success = true
            }
        }

        if success {
            if let idx = allAdmins.firstIndex(where: { $0.email == admin.email }) {
                allAdmins[idx].allowedRoles = Array(selectedRoles)
                selectedAdmin = allAdmins[idx]
            }
            message = "Đã cập nhật quyền thành công cho \(admin.email)"
        } else {
            message = "Cập nhật quyền thất bại. Vui lòng kiểm tra lại kết nối mạng."
        }
        showMessage = true
    }
}
