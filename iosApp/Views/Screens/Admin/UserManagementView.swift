import SwiftUI

public struct UserManagementView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var selectedTab: Int = 0 // 0: Danh sách, 1: Thêm mới
    @State private var searchText: String = ""
    @State private var filterRole: String = "ALL"

    // Thêm mới
    @State private var newEmail: String = ""
    @State private var newFullName: String = ""
    @State private var newMnv: String = ""
    @State private var newPhone: String = ""
    @State private var newRole: String = "STAFF"
    @State private var newUnit: String = "Co.opmart Cần Thơ"
    @State private var newDept: String = "Phòng Công nghệ thông tin"

    // User Detail Sheet
    @State private var selectedUser: User? = nil

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredUsers: [User] {
        viewModel.allUsers.filter { u in
            let matchSearch = searchText.isEmpty ||
                u.fullName.localizedCaseInsensitiveContains(searchText) ||
                u.email.localizedCaseInsensitiveContains(searchText) ||
                u.phone.contains(searchText) ||
                u.maNhanVien.localizedCaseInsensitiveContains(searchText)
            let matchRole = filterRole == "ALL" || u.role.caseInsensitiveCompare(filterRole) == .orderedSame
            return matchSearch && matchRole
        }
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

                            Text("Quản lý người dùng (\(viewModel.allUsers.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { viewModel.fetchUsers() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    // TABS
                    Picker("Tab", selection: $selectedTab) {
                        Text("Danh Sách").tag(0)
                        Text("Thêm Mới").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)

                    // CONTENT
                    if selectedTab == 0 {
                        userListTab
                    } else {
                        addNewUserTab
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .sheet(item: Binding<User?>(
                get: { self.selectedUser },
                set: { self.selectedUser = $0 }
            )) { user in
                UserDetailSheet(
                    user: user,
                    viewModel: viewModel,
                    onDismiss: { self.selectedUser = nil }
                )
            }
        }
        .onAppear {
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
            viewModel.fetchDepartments()
            viewModel.fetchUnitsAndRegions()
        }
    }

    // MARK: - TAB 1: DANH SÁCH
    private var userListTab: some View {
        VStack(spacing: 8) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gray)
                TextField("Tìm theo tên, email, SĐT, mã NV...", text: $searchText)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 14)

            // Role chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    roleChip(title: "Tất cả", tag: "ALL")
                    roleChip(title: "Admin", tag: "ADMIN")
                    roleChip(title: "HelpDesk", tag: "HELPDESK")
                    roleChip(title: "Kỹ thuật", tag: "TECHNICIAN")
                    roleChip(title: "Nhân viên", tag: "STAFF")
                }
                .padding(.horizontal, 14)
            }

            // List
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredUsers) { u in
                        userCard(u)
                            .onTapGesture {
                                selectedUser = u
                            }
                    }
                }
                .padding(14)
            }
        }
    }

    private func roleChip(title: String, tag: String) -> some View {
        let isSel = filterRole == tag
        return Button(action: { filterRole = tag }) {
            Text(title)
                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? .white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSel ? Color.appPrimary : Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }

    private func userCard(_ u: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.8))
                        .frame(width: 40, height: 40)
                    Text(String(u.fullName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(u.fullName.isEmpty ? u.email : u.fullName)
                            .font(.system(size: 14, weight: .bold))
                        if u.status.uppercased() == "PENDING" {
                            Text("CHỜ DUYỆT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        } else if u.status.uppercased() == "DISABLED" {
                            Text("ĐÃ KHÓA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .cornerRadius(4)
                        }
                    }

                    Text(u.email)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    if !u.phone.isEmpty {
                        Text("SĐT: \(u.phone)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                Text(u.roleDisplayName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appPrimary)
                    .clipShape(Capsule())
            }

            Divider()

            HStack {
                Label(u.donVi.isEmpty ? "Chưa rõ" : u.donVi, systemImage: "building.2")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer()

                Label(u.departmentId.isEmpty ? "Chưa rõ" : u.departmentId, systemImage: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }

    // MARK: - TAB 2: THÊM MỚI
    private var addNewUserTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("THÔNG TIN NHÂN VIÊN MỚI")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)

                formField(label: "Họ và tên *", text: $newFullName, placeholder: "Ví dụ: Nguyễn Văn A")
                formField(label: "Email công ty *", text: $newEmail, placeholder: "nguyenvana@sgcoop.com")
                formField(label: "Mã nhân viên (MNV)", text: $newMnv, placeholder: "Ví dụ: NV01234")
                formField(label: "Số điện thoại", text: $newPhone, placeholder: "0901234567")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Vai trò hệ thống")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                    Picker("Vai trò", selection: $newRole) {
                        Text("Nhân viên (STAFF)").tag("STAFF")
                        Text("Kỹ thuật viên (TECHNICIAN)").tag("TECHNICIAN")
                        Text("HelpDesk (HELPDESK)").tag("HELPDESK")
                        Text("Quản trị viên (ADMIN)").tag("ADMIN")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }

                Button(action: {
                    let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !email.isEmpty else { return }
                    viewModel.approveUser(email: email, role: newRole, donVi: newUnit, departmentId: newDept)
                    selectedTab = 0
                }) {
                    Text("Tạo tài khoản người dùng")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.appPrimary)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .padding(10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
}

struct UserDetailSheet: View {
    let user: User
    @ObservedObject var viewModel: AdminViewModel
    var onDismiss: () -> Void

    @State private var editRole: String
    @State private var editUnit: String
    @State private var editDept: String

    init(user: User, viewModel: AdminViewModel, onDismiss: @escaping () -> Void) {
        self.user = user
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _editRole = State(initialValue: user.role.isEmpty ? "STAFF" : user.role)
        _editUnit = State(initialValue: user.donVi)
        _editDept = State(initialValue: user.departmentId)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header info
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.appPrimary)
                                .frame(width: 80, height: 80)
                            Text(String(user.fullName.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text(user.fullName.isEmpty ? user.email : user.fullName)
                            .font(.title3.bold())
                        Text(user.email)
                            .foregroundColor(.gray)
                            .font(.subheadline)
                    }
                    .padding(.top)

                    // Approval actions for pending
                    if user.status.uppercased() == "PENDING" {
                        VStack(spacing: 12) {
                            Text("Tài khoản đang chờ duyệt")
                                .font(.headline)
                                .foregroundColor(.orange)
                            HStack(spacing: 16) {
                                Button(action: {
                                    viewModel.approveUser(email: user.email, role: editRole, donVi: editUnit, departmentId: editDept)
                                    onDismiss()
                                }) {
                                    Text("Phê duyệt")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                Button(action: {
                                    viewModel.rejectUser(email: user.email)
                                    onDismiss()
                                }) {
                                    Text("Từ chối")
                                        .bold()
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }

                    // Properties
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Chỉnh sửa thông tin")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vai trò")
                                .font(.caption).foregroundColor(.gray)
                            Picker("Vai trò", selection: $editRole) {
                                Text("Nhân viên (STAFF)").tag("STAFF")
                                Text("Kỹ thuật viên (TECHNICIAN)").tag("TECHNICIAN")
                                Text("HelpDesk (HELPDESK)").tag("HELPDESK")
                                Text("Quản trị viên (ADMIN)").tag("ADMIN")
                            }
                            .pickerStyle(MenuPickerStyle())
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: editRole) { newValue in
                                if user.status.uppercased() != "PENDING" {
                                    viewModel.updateUserRole(email: user.email, newRole: newValue)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Đơn vị")
                                .font(.caption).foregroundColor(.gray)
                            HStack {
                                TextField("Đơn vị", text: $editUnit)
                                if !viewModel.units.isEmpty {
                                    Menu {
                                        ForEach(viewModel.units) { u in
                                            Button(u.tenDonVi) { editUnit = u.tenDonVi }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down.circle.fill")
                                            .foregroundColor(Color.appPrimaryPink)
                                            .padding(.trailing, 4)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phòng ban")
                                .font(.caption).foregroundColor(.gray)
                            HStack {
                                TextField("Phòng ban", text: $editDept)
                                if !viewModel.departments.isEmpty {
                                    Menu {
                                        ForEach(viewModel.departments) { d in
                                            Button(d.departmentName) { editDept = d.departmentName }
                                        }
                                    } label: {
                                        Image(systemName: "chevron.down.circle.fill")
                                            .foregroundColor(Color.appPrimaryPink)
                                            .padding(.trailing, 4)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }

                        if user.status.uppercased() != "PENDING" {
                            Button(action: {
                                viewModel.transferUser(email: user.email, newUnit: editUnit, newDept: editDept)
                            }) {
                                Text("Cập nhật Đơn vị / Phòng ban")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.appPrimary)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)

                    // Actions
                    if user.status.uppercased() != "PENDING" {
                        VStack(spacing: 12) {
                            Button(action: {
                                viewModel.resetUserPassword(email: user.email)
                            }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Yêu cầu đổi mật khẩu")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                            }

                            let isSecured = user.status.uppercased() == "DISABLED"
                            Button(action: {
                                viewModel.disableUser(email: user.email, disable: !isSecured)
                            }) {
                                HStack {
                                    Image(systemName: isSecured ? "lock.open.fill" : "lock.fill")
                                    Text(isSecured ? "Mở khóa tài khoản" : "Khóa tài khoản")
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isSecured ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                                .foregroundColor(isSecured ? .green : .red)
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .background(Color.appBackground)
            .navigationBarTitle("Chi tiết User", displayMode: .inline)
            .navigationBarItems(trailing: Button("Đóng") { onDismiss() })
        }
    }
}
