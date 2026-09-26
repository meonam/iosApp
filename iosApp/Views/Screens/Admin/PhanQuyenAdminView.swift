import SwiftUI

struct AdminUserInfo: Identifiable, Hashable {
    let id = UUID()
    let email: String
    var allowedRoles: [String]
}

struct RoleInfo: Identifiable, Hashable {
    let id: String
    let displayName: String
}

struct PhanQuyenAdminView: View {
    var onBack: () -> Void
    
    @State private var allAdmins: [AdminUserInfo] = []
    @State private var availableRoles: [RoleInfo] = []
    @State private var selectedAdmin: AdminUserInfo? = nil
    @State private var selectedRoles: Set<String> = []
    
    @State private var isLoading = false
    @State private var message = ""
    @State private var showMessage = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.backward")
                        .foregroundColor(.white)
                }
                Text("Phân quyền Sub-Admin")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.8)) // TopBarColor fallback
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Chọn Sub-Admin:")
                    
                    Menu {
                        ForEach(allAdmins) { admin in
                            Button(admin.email) {
                                selectedAdmin = admin
                                selectedRoles = Set(admin.allowedRoles)
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedAdmin?.email ?? "Chọn admin...")
                                .foregroundColor(selectedAdmin == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                    }
                    
                    if selectedAdmin != nil {
                        Text("Chọn quyền có thể tạo:")
                            .padding(.top, 12)
                        
                        ForEach(availableRoles) { role in
                            Toggle(isOn: Binding(
                                get: { selectedRoles.contains(role.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedRoles.insert(role.id)
                                    } else {
                                        selectedRoles.remove(role.id)
                                    }
                                }
                            )) {
                                Text(role.displayName)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: updatePermissions) {
                            Text("Cập nhật quyền")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    } else {
                        Spacer()
                    }
                }
                .padding(16)
            }
        }
        .background(Color(.systemBackground))
        .alert(isPresented: $showMessage) {
            Alert(title: Text("Thông báo"), message: Text(message), dismissButton: .default(Text("OK")))
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        // MOCK data since AdminViewModel is likely REST-based or injected differently in iOS
        // In a real scenario, use URLSession to GET from /users and /roles in Firestore via REST API
        self.allAdmins = [
            AdminUserInfo(email: "admin1@example.com", allowedRoles: ["role1"]),
            AdminUserInfo(email: "admin2@example.com", allowedRoles: ["role2", "role3"])
        ]
        self.availableRoles = [
            RoleInfo(id: "role1", displayName: "Quản lý nhân sự"),
            RoleInfo(id: "role2", displayName: "Quản lý thiết bị"),
            RoleInfo(id: "role3", displayName: "Quản lý tài chính")
        ]
        isLoading = false
    }
    
    private func updatePermissions() {
        guard let admin = selectedAdmin else { return }
        // MOCK update
        // Use URLSession to PATCH user roles via REST API
        message = "Đã cập nhật quyền cho \(admin.email)"
        showMessage = true
    }
}
