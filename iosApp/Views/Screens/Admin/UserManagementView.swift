import SwiftUI

// MARK: - USER MANAGEMENT VIEW (ĐỒNG BỘ 1:1 THEO USERMANAGEMENTSCREEN.KT TRÊN ANDROID)
public struct UserManagementView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    // 4 Tabs: 0: Thêm User mới, 1: Danh sách User, 2: Phân quyền, 3: Đặt lại mật khẩu
    @State private var selectedTab: Int = 1

    // Tab 1: Danh sách User
    @State private var searchText: String = ""
    @State private var filterRole: String = "ALL"
    @State private var filterStatus: String = "ALL" // ALL, ACTIVE, LOCKED
    @State private var userToDelete: User? = nil
    @State private var showDeleteAlert: Bool = false

    // Tab 0: Thêm User mới
    @State private var addFullName: String = ""
    @State private var addEmail: String = ""
    @State private var addMnv: String = ""
    @State private var addPhone: String = ""
    @State private var addPassword: String = ""
    @State private var isAddPasswordVisible: Bool = false
    @State private var addRole: String = "STAFF"
    @State private var addUnitName: String = ""
    @State private var addUnitId: String = ""
    @State private var addDeptName: String = ""
    @State private var addKhuVuc: String = ""
    @State private var addToNghiepVu: String = ""

    // Tab 2: Phân quyền
    @State private var permSelectedUser: User? = nil
    @State private var permUserSearch: String = ""
    @State private var permShowUserPicker: Bool = false
    @State private var permFullName: String = ""
    @State private var permMnv: String = ""
    @State private var permPhone: String = ""
    @State private var permRole: String = "STAFF"
    @State private var permUnitName: String = ""
    @State private var permUnitId: String = ""
    @State private var permDeptName: String = ""
    @State private var permKhuVuc: String = ""
    @State private var permToNghiepVu: String = ""
    @State private var isSavingPerm: Bool = false
    @State private var permToastMessage: String? = nil

    // Tab 3: Đặt lại mật khẩu
    @State private var resetSelectedUser: User? = nil
    @State private var resetUserSearch: String = ""
    @State private var resetShowUserPicker: Bool = false
    @State private var resetEmailInput: String = ""
    @State private var resetPasswordInput: String = ""
    @State private var isResetPasswordVisible: Bool = false
    @State private var isResetting: Bool = false
    @State private var lastResetPasswordSuccess: String = ""
    @State private var resetToastMessage: String? = nil

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    // Lọc danh sách User ở Tab 1
    private var filteredUsers: [User] {
        viewModel.allUsers.filter { u in
            let matchSearch = searchText.isEmpty ||
                u.fullName.localizedCaseInsensitiveContains(searchText) ||
                u.email.localizedCaseInsensitiveContains(searchText) ||
                u.phone.contains(searchText) ||
                u.maNhanVien.localizedCaseInsensitiveContains(searchText)

            let matchRole: Bool
            if filterRole == "ALL" {
                matchRole = true
            } else {
                matchRole = u.role.caseInsensitiveCompare(filterRole) == .orderedSame
            }

            let matchStatus: Bool
            if filterStatus == "ALL" {
                matchStatus = true
            } else if filterStatus == "ACTIVE" {
                matchStatus = u.status.uppercased() == "ACTIVE"
            } else if filterStatus == "LOCKED" {
                matchStatus = u.status.uppercased() == "DISABLED" || u.status.uppercased() == "LOCKED"
            } else {
                matchStatus = true
            }

            return matchSearch && matchRole && matchStatus
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

                            Text("Quản lý người dùng (\(viewModel.allUsers.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                viewModel.fetchUsers()
                                viewModel.fetchDepartments()
                                viewModel.fetchUnitsAndRegions()
                                Task { await viewModel.fetchSpecialistTeams() }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 17))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 4 TABS SEGMENTED BAR (ĐỒNG BỘ 1:1 THEO ANDROID)
                    tabNavigationBar

                    // TAB CONTENT
                    if selectedTab == 0 {
                        addUserTab
                    } else if selectedTab == 1 {
                        userListTab
                    } else if selectedTab == 2 {
                        permissionTab
                    } else {
                        resetPasswordTab
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
            viewModel.fetchDepartments()
            viewModel.fetchUnitsAndRegions()
            Task {
                await viewModel.fetchSpecialistTeams()
            }
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Xác nhận xóa tài khoản"),
                message: Text("Bạn có chắc chắn muốn xóa tài khoản \"\(userToDelete?.email ?? "")\"? Hành động này không thể hoàn tác."),
                primaryButton: .destructive(Text("Xóa")) {
                    if let u = userToDelete {
                        Task {
                            await viewModel.deleteUser(email: u.email)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - 4 TABS NAVIGATION BAR
    private var tabNavigationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                tabButton(title: "Thêm mới", icon: "person.badge.plus", tag: 0)
                tabButton(title: "Danh sách (\(viewModel.allUsers.count))", icon: "person.3.fill", tag: 1)
                tabButton(title: "Phân quyền", icon: "shield.checkered", tag: 2)
                tabButton(title: "Đặt lại MK", icon: "key.fill", tag: 3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        let isSel = selectedTab == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tag
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: isSel ? .bold : .medium))
                Text(title)
                    .font(.system(size: 12.5, weight: isSel ? .bold : .medium))
            }
            .foregroundColor(isSel ? .white : Color.appSecondaryDarkBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSel ? Color.appSecondaryDarkBlue : Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSel ? Color.appSecondaryDarkBlue : Color(hex: "#CBD5E1"), lineWidth: 1)
            )
        }
    }

    // MARK: - TAB 0: THÊM USER MỚI
    private var addUserTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("TẠO TÀI KHOẢN NGƯỜI DÙNG MỚI")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Nhập thông tin nhân sự để cấp tài khoản vào hệ thống.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 4)

                // Họ và tên
                formField(label: "Họ và tên *", text: $addFullName, placeholder: "Ví dụ: Nguyễn Văn A")

                // Email
                formField(label: "Email công ty *", text: $addEmail, placeholder: "nguyenvana@sgcoop.vn")

                // Mã nhân viên
                formField(label: "Mã nhân viên (MNV) *", text: $addMnv, placeholder: "Ví dụ: NV01234")

                // Số điện thoại
                formField(label: "Số điện thoại liên hệ *", text: $addPhone, placeholder: "0901234567")

                // Mật khẩu khởi tạo
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mật khẩu khởi tạo *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Spacer()
                        Button(action: {
                            addPassword = generateRandomPassword(length: 8)
                            isAddPasswordVisible = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "wand.and.stars")
                                Text("Tạo ngẫu nhiên 🎲")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appPrimaryPink)
                        }
                    }

                    HStack {
                        if isAddPasswordVisible {
                            TextField("Nhập mật khẩu", text: $addPassword)
                                .font(.system(size: 13))
                        } else {
                            SecureField("Nhập mật khẩu", text: $addPassword)
                                .font(.system(size: 13))
                        }

                        Button(action: { isAddPasswordVisible.toggle() }) {
                            Image(systemName: isAddPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                }

                // Vai trò hệ thống
                VStack(alignment: .leading, spacing: 6) {
                    Text("Vai trò hệ thống *")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Menu {
                        Button("Quản trị viên (ADMIN)") { addRole = "ADMIN" }
                        Button("Helpdesk (HELPDESK)") { addRole = "HELPDESK" }
                        Button("Trưởng / Phó phòng (PHONGBAN)") { addRole = "PHONGBAN" }
                        Button("Kỹ thuật viên (TECHNICIAN)") { addRole = "TECHNICIAN" }
                        Button("Chuyên viên nghiệp vụ (CHUYENVIEN)") { addRole = "CHUYENVIEN" }
                        Button("Nhân viên (STAFF)") { addRole = "STAFF" }
                    } label: {
                        HStack {
                            Text(roleDisplayName(addRole))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }

                // Đơn vị / Chi nhánh
                VStack(alignment: .leading, spacing: 6) {
                    Text("Đơn vị / Chi nhánh trực thuộc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Menu {
                        Button("Không chọn (Mặc định)") {
                            addUnitName = ""
                            addUnitId = ""
                        }
                        ForEach(viewModel.units) { u in
                            Button(u.tenDonVi) {
                                addUnitName = u.tenDonVi
                                addUnitId = u.id
                            }
                        }
                    } label: {
                        HStack {
                            Text(addUnitName.isEmpty ? "Chọn đơn vị / siêu thị" : addUnitName)
                                .font(.system(size: 13))
                                .foregroundColor(addUnitName.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }

                // Phòng ban
                VStack(alignment: .leading, spacing: 6) {
                    Text("Phòng ban")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Menu {
                        Button("Không chọn") { addDeptName = "" }
                        ForEach(viewModel.departments) { d in
                            Button(d.departmentName) { addDeptName = d.departmentName }
                        }
                    } label: {
                        HStack {
                            Text(addDeptName.isEmpty ? "Chọn phòng ban" : addDeptName)
                                .font(.system(size: 13))
                                .foregroundColor(addDeptName.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }

                // Cụm / Khu vực
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cụm / Khu vực (tùy chọn)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Menu {
                        Button("Không chọn") { addKhuVuc = "" }
                        ForEach(viewModel.regions) { r in
                            Button("\(r.maKhuVuc) - \(r.tenKhuVuc)") { addKhuVuc = r.maKhuVuc }
                        }
                    } label: {
                        HStack {
                            Text(addKhuVuc.isEmpty ? "Chọn cụm / khu vực" : addKhuVuc)
                                .font(.system(size: 13))
                                .foregroundColor(addKhuVuc.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }

                // Tổ nghiệp vụ
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tổ nghiệp vụ phụ trách (KTV / Chuyên viên)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Menu {
                        Button("Không thuộc tổ nghiệp vụ") { addToNghiepVu = "" }
                        ForEach(viewModel.specialistTeams) { t in
                            Button("\(t.teamName) (\(t.teamId))") { addToNghiepVu = t.teamId }
                        }
                    } label: {
                        HStack {
                            Text(addToNghiepVu.isEmpty ? "Chọn tổ nghiệp vụ" : addToNghiepVu)
                                .font(.system(size: 13))
                                .foregroundColor(addToNghiepVu.isEmpty ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }

                // Nút Tạo User
                Button(action: {
                    let email = addEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let name = addFullName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let mnv = addMnv.trimmingCharacters(in: .whitespacesAndNewlines)
                    let phone = addPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                    let pwd = addPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !email.isEmpty, !name.isEmpty else { return }

                    Task {
                        await viewModel.createUser(
                            email: email,
                            fullName: name,
                            mnv: mnv,
                            phone: phone,
                            role: addRole,
                            unitId: addUnitId,
                            unitName: addUnitName,
                            deptId: addDeptName,
                            khuVuc: addKhuVuc,
                            toNghiepVu: addToNghiepVu,
                            password: pwd.isEmpty ? "123456" : pwd
                        )
                        // Reset form & chuyển sang tab danh sách
                        addEmail = ""
                        addFullName = ""
                        addMnv = ""
                        addPhone = ""
                        addPassword = ""
                        selectedTab = 1
                    }
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Tạo tài khoản người dùng")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(addEmail.isEmpty || addFullName.isEmpty ? Color.gray.opacity(0.5) : Color.appSecondaryDarkBlue)
                    .cornerRadius(10)
                }
                .disabled(addEmail.isEmpty || addFullName.isEmpty)
                .padding(.top, 10)
            }
            .padding(16)
        }
    }

    // MARK: - TAB 1: DANH SÁCH USER
    private var userListTab: some View {
        VStack(spacing: 8) {
            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gray)
                TextField("Tìm theo tên, email, SĐT, mã NV...", text: $searchText)
                    .font(.system(size: 13.5))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.gray)
                    }
                }
            }
            .padding(9)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.top, 8)

            // Role chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    roleChip(title: "Tất cả", tag: "ALL")
                    roleChip(title: "Admin", tag: "ADMIN")
                    roleChip(title: "Helpdesk", tag: "HELPDESK")
                    roleChip(title: "Trưởng phòng", tag: "PHONGBAN")
                    roleChip(title: "Kỹ thuật", tag: "TECHNICIAN")
                    roleChip(title: "Chuyên viên", tag: "CHUYENVIEN")
                    roleChip(title: "Nhân viên", tag: "STAFF")
                }
                .padding(.horizontal, 14)
            }

            // Status filter chips
            HStack(spacing: 8) {
                statusChip(title: "Toàn bộ (\(viewModel.allUsers.count))", tag: "ALL")
                statusChip(title: "Hoạt động", tag: "ACTIVE")
                statusChip(title: "Đã khóa", tag: "LOCKED")
                Spacer()
            }
            .padding(.horizontal, 14)

            // User list
            if filteredUsers.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 40)
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("Không tìm thấy người dùng phù hợp")
                        .font(.system(size: 13.5))
                        .foregroundColor(.gray)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredUsers) { u in
                            userListItemCard(u)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func roleChip(title: String, tag: String) -> some View {
        let isSel = filterRole == tag
        return Button(action: { filterRole = tag }) {
            Text(title)
                .font(.system(size: 11.5, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? .white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSel ? Color.appSecondaryDarkBlue : Color.white)
                .cornerRadius(7)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
        }
    }

    private func statusChip(title: String, tag: String) -> some View {
        let isSel = filterStatus == tag
        return Button(action: { filterStatus = tag }) {
            Text(title)
                .font(.system(size: 11, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? Color.appSecondaryDarkBlue : .gray)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSel ? Color.appSecondaryDarkBlue.opacity(0.1) : Color.clear)
                .cornerRadius(6)
        }
    }

    private func userListItemCard(_ u: User) -> some View {
        let isLocked = u.status.uppercased() == "DISABLED" || u.status.uppercased() == "LOCKED"
        let isPending = u.status.uppercased() == "PENDING"

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isLocked ? Color.red.opacity(0.8) : Color.appSecondaryDarkBlue)
                        .frame(width: 42, height: 42)
                    Text((u.fullName.isEmpty ? String(u.email.prefix(1)) : String(u.fullName.prefix(1))).uppercased())
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(u.fullName.isEmpty ? u.email : u.fullName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        if isPending {
                            Text("CHỜ DUYỆT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(4)
                        } else if isLocked {
                            Text("ĐÃ KHÓA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }

                    Text(u.email)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    HStack(spacing: 8) {
                        if !u.phone.isEmpty {
                            Label(u.phone, systemImage: "phone.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        if !u.maNhanVien.isEmpty {
                            Label(u.maNhanVien, systemImage: "person.text.rectangle")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                }

                Spacer()

                // Role Badge
                Text(roleDisplayName(u.role))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appSecondaryDarkBlue.opacity(0.1))
                    .cornerRadius(6)
            }

            // Don vi & Phong ban
            if !u.donVi.isEmpty || !u.departmentId.isEmpty {
                HStack(spacing: 12) {
                    if !u.donVi.isEmpty {
                        Label(u.donVi, systemImage: "building.2")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    if !u.departmentId.isEmpty {
                        Label(u.departmentId, systemImage: "folder")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }

            Divider()

            // Quick Action Buttons (Phân quyền, Khóa/Mở, Xóa)
            HStack(spacing: 8) {
                // Button 1: Phân quyền -> Chuyển sang Tab 2 với User này
                Button(action: {
                    selectUserForPermission(u)
                    selectedTab = 2
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered")
                        Text("Phân quyền")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.appSecondaryDarkBlue.opacity(0.08))
                    .cornerRadius(6)
                }

                // Button 2: Đặt lại MK -> Chuyển sang Tab 3 với User này
                Button(action: {
                    selectUserForResetPassword(u)
                    selectedTab = 3
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "key.fill")
                        Text("Đặt lại MK")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(Color.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }

                Spacer()

                // Button 3: Khóa / Mở khóa
                Button(action: {
                    viewModel.disableUser(email: u.email, disable: !isLocked)
                }) {
                    Image(systemName: isLocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(isLocked ? .green : .orange)
                        .padding(6)
                        .background((isLocked ? Color.green : Color.orange).opacity(0.1))
                        .clipShape(Circle())
                }

                // Button 4: Xóa
                Button(action: {
                    userToDelete = u
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
    }

    // MARK: - TAB 2: PHÂN QUYỀN (1:1 VỚI ANDROID PHÂN QUYỀN USER)
    private var permissionTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Card: Chọn User
                VStack(alignment: .leading, spacing: 8) {
                    Text("🛡️ PHÂN QUYỀN & THIẾT LẬP TÀI KHOẢN")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Chọn tài khoản để điều chỉnh vai trò, phòng ban, đơn vị và phân quyền hệ thống.")
                        .font(.system(size: 11.5))
                        .foregroundColor(.gray)

                    // Searchable User Selector
                    Menu {
                        ForEach(viewModel.allUsers) { u in
                            Button("\(u.fullName.isEmpty ? u.email : u.fullName) (\(u.email))") {
                                selectUserForPermission(u)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text(permSelectedUser == nil ? "Nhấn để chọn người dùng..." : "\(permSelectedUser?.fullName ?? "") (\(permSelectedUser?.email ?? ""))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(permSelectedUser == nil ? .gray : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color(hex: "#F8FAFC"))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))

                // Detail Form for Selected User
                if let user = permSelectedUser {
                    VStack(alignment: .leading, spacing: 14) {
                        // User Header
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appSecondaryDarkBlue.opacity(0.12))
                                    .frame(width: 48, height: 48)
                                Text(String(user.fullName.prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.fullName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text(user.email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        Divider()

                        // 1. Họ và tên
                        formField(label: "Họ và tên", text: $permFullName, placeholder: "Nhập họ tên")

                        // 2. Mã nhân viên
                        formField(label: "Mã nhân viên (MNV - Bắt buộc)", text: $permMnv, placeholder: "Nhập mã NV")

                        // 3. Số điện thoại
                        formField(label: "Số điện thoại liên hệ (Bắt buộc)", text: $permPhone, placeholder: "090...")

                        // 4. Vai trò hệ thống
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Vai trò hệ thống")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Menu {
                                Button("Quản trị viên (ADMIN)") { permRole = "ADMIN" }
                                Button("Helpdesk (HELPDESK)") { permRole = "HELPDESK" }
                                Button("Trưởng / Phó phòng (PHONGBAN)") { permRole = "PHONGBAN" }
                                Button("Kỹ thuật viên (TECHNICIAN)") { permRole = "TECHNICIAN" }
                                Button("Chuyên viên nghiệp vụ (CHUYENVIEN)") { permRole = "CHUYENVIEN" }
                                Button("Nhân viên (STAFF)") { permRole = "STAFF" }
                            } label: {
                                HStack {
                                    Text(roleDisplayName(permRole))
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }
                        }

                        // 5. Đơn vị / Chi nhánh
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Đơn vị / Chi nhánh trực thuộc")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Menu {
                                Button("Không chỉ định") {
                                    permUnitName = ""
                                    permUnitId = ""
                                }
                                ForEach(viewModel.units) { u in
                                    Button(u.tenDonVi) {
                                        permUnitName = u.tenDonVi
                                        permUnitId = u.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(permUnitName.isEmpty ? "Chọn đơn vị / siêu thị" : permUnitName)
                                        .font(.system(size: 13))
                                        .foregroundColor(permUnitName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }
                        }

                        // 6. Phòng ban
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Phòng ban")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Menu {
                                Button("Không chỉ định") { permDeptName = "" }
                                ForEach(viewModel.departments) { d in
                                    Button(d.departmentName) { permDeptName = d.departmentName }
                                }
                            } label: {
                                HStack {
                                    Text(permDeptName.isEmpty ? "Chọn phòng ban" : permDeptName)
                                        .font(.system(size: 13))
                                        .foregroundColor(permDeptName.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }
                        }

                        // 7. Cụm / Khu vực
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cụm / Khu vực")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Menu {
                                Button("Không chỉ định") { permKhuVuc = "" }
                                ForEach(viewModel.regions) { r in
                                    Button("\(r.maKhuVuc) - \(r.tenKhuVuc)") { permKhuVuc = r.maKhuVuc }
                                }
                            } label: {
                                HStack {
                                    Text(permKhuVuc.isEmpty ? "Chọn cụm / khu vực" : permKhuVuc)
                                        .font(.system(size: 13))
                                        .foregroundColor(permKhuVuc.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }
                        }

                        // 8. Tổ nghiệp vụ
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tổ nghiệp vụ phụ trách (KTV / Chuyên viên)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Menu {
                                Button("Không thuộc tổ nghiệp vụ") { permToNghiepVu = "" }
                                ForEach(viewModel.specialistTeams) { t in
                                    Button("\(t.teamName) (\(t.teamId))") { permToNghiepVu = t.teamId }
                                }
                            } label: {
                                HStack {
                                    Text(permToNghiepVu.isEmpty ? "Chọn tổ nghiệp vụ" : permToNghiepVu)
                                        .font(.system(size: 13))
                                        .foregroundColor(permToNghiepVu.isEmpty ? .gray : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                .padding(10)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }
                        }

                        // Toast thông báo
                        if let msg = permToastMessage {
                            Text(msg)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Nút Lưu Phân Quyền
                        Button(action: {
                            savePermissions()
                        }) {
                            HStack {
                                if isSavingPerm {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Lưu quyền hạn & Cập nhật")
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.appSecondaryDarkBlue)
                            .cornerRadius(10)
                        }
                        .disabled(isSavingPerm)

                        // Nút Xóa User
                        Button(action: {
                            userToDelete = user
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Xóa tài khoản này")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
                } else {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 30)
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Vui lòng chọn tài khoản ở trên để bắt đầu phân quyền.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding(16)
        }
    }

    private func selectUserForPermission(_ u: User) {
        permSelectedUser = u
        permFullName = u.fullName
        permMnv = u.maNhanVien
        permPhone = u.phone
        permRole = u.role.isEmpty ? "STAFF" : u.role.uppercased()
        permUnitName = u.donVi
        permUnitId = u.unitId
        permDeptName = u.departmentId
        permKhuVuc = u.maKhuVuc
        permToNghiepVu = u.toNghiepVu
        permToastMessage = nil
    }

    private func savePermissions() {
        guard let u = permSelectedUser else { return }
        isSavingPerm = true
        Task {
            let success = await viewModel.saveUserPermissions(
                email: u.email,
                role: permRole,
                departmentId: permDeptName,
                unitId: permUnitId,
                donVi: permUnitName,
                fullName: permFullName,
                phone: permPhone,
                maKhuVuc: permKhuVuc,
                maNhanVien: permMnv,
                permissions: u.permissions,
                toNghiepVu: permToNghiepVu
            )
            isSavingPerm = false
            if success {
                permToastMessage = "✅ Đã lưu phân quyền cho \(u.email) thành công!"
            }
        }
    }

    // MARK: - TAB 3: ĐẶT LẠI MẬT KHẨU (1:1 VỚI ANDROID RESET PASSWORD)
    private var resetPasswordTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("🔑 Đặt lại mật khẩu người dùng")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }

                    Text("Chọn tài khoản hoặc nhập email người dùng và mật khẩu mới để đặt lại trực tiếp.")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)

                    // Chọn User dropdown
                    Menu {
                        ForEach(viewModel.allUsers) { u in
                            Button("\(u.fullName.isEmpty ? u.email : u.fullName) (\(u.email))") {
                                selectUserForResetPassword(u)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text(resetSelectedUser == nil ? "Chọn người dùng cần đặt lại mật khẩu..." : "\(resetSelectedUser?.fullName ?? "") (\(resetSelectedUser?.email ?? ""))")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(resetSelectedUser == nil ? .gray : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        .padding(10)
                        .background(Color(hex: "#F8FAFC"))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }

                    // Email input
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email tài khoản xác nhận *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        TextField("email@sgcoop.vn", text: $resetEmailInput)
                            .font(.system(size: 13))
                            .padding(10)
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }

                    // Mật khẩu mới
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Mật khẩu mới *")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            Button(action: {
                                resetPasswordInput = generateRandomPassword(length: 8)
                                isResetPasswordVisible = true
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "wand.and.stars")
                                    Text("Tạo ngẫu nhiên 🎲")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                            }
                        }

                        HStack {
                            if isResetPasswordVisible {
                                TextField("Nhập mật khẩu mới (ít nhất 6 ký tự)", text: $resetPasswordInput)
                                    .font(.system(size: 13))
                            } else {
                                SecureField("Nhập mật khẩu mới (ít nhất 6 ký tự)", text: $resetPasswordInput)
                                    .font(.system(size: 13))
                            }

                            Button(action: { isResetPasswordVisible.toggle() }) {
                                Image(systemName: isResetPasswordVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(10)
                        .background(Color(hex: "#F8FAFC"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }

                    // Nút Đặt lại Mật Khẩu
                    Button(action: {
                        let cleanEmail = resetEmailInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let cleanPwd = resetPasswordInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanEmail.isEmpty, cleanPwd.count >= 6 else { return }

                        isResetting = true
                        Task {
                            let success = await viewModel.resetUserPassword(email: cleanEmail, newPassword: cleanPwd)
                            isResetting = false
                            if success {
                                lastResetPasswordSuccess = cleanPwd
                                resetToastMessage = "✅ Đặt lại mật khẩu thành công!"
                            }
                        }
                    }) {
                        HStack {
                            if isResetting {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "lock.rotation")
                                Text("Đặt lại mật khẩu")
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(resetEmailInput.isEmpty || resetPasswordInput.count < 6 ? Color.gray.opacity(0.5) : Color.appSecondaryDarkBlue)
                        .cornerRadius(10)
                    }
                    .disabled(resetEmailInput.isEmpty || resetPasswordInput.count < 6 || isResetting)

                    // Hiển thị kết quả thành công & Copy
                    if !lastResetPasswordSuccess.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Mật khẩu mới đã tạo:")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                    Text(lastResetPasswordSuccess)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                                Spacer()
                                Button(action: {
                                    UIPasteboard.general.string = lastResetPasswordSuccess
                                    resetToastMessage = "📋 Đã sao chép mật khẩu vào Clipboard!"
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc.fill")
                                        Text("Sao chép")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.appSecondaryDarkBlue)
                                    .cornerRadius(6)
                                }
                            }

                            if let toast = resetToastMessage {
                                Text(toast)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(12)
                        .background(Color(hex: "#F0FDF4"))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#BBF7D0"), lineWidth: 1))
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
            }
            .padding(16)
        }
    }

    private func selectUserForResetPassword(_ u: User) {
        resetSelectedUser = u
        resetEmailInput = u.email
        resetPasswordInput = generateRandomPassword(length: 8)
        isResetPasswordVisible = true
        lastResetPasswordSuccess = ""
        resetToastMessage = nil
    }

    // MARK: - HELPERS
    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.appSecondaryDarkBlue)
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .padding(10)
                .background(Color(hex: "#F8FAFC"))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
        }
    }

    private func roleDisplayName(_ role: String) -> String {
        switch role.uppercased() {
        case "ADMIN": return "Quản trị viên (ADMIN)"
        case "HELPDESK": return "Helpdesk (HELPDESK)"
        case "PHONGBAN", "QUANLY": return "Trưởng / Phó phòng (PHONGBAN)"
        case "TECHNICIAN", "KYTHUAT": return "Kỹ thuật viên (TECHNICIAN)"
        case "CHUYENVIEN": return "Chuyên viên nghiệp vụ (CHUYENVIEN)"
        default: return "Nhân viên (STAFF)"
        }
    }

    private func generateRandomPassword(length: Int = 8) -> String {
        let chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
