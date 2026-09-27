import SwiftUI

// MARK: - USER MANAGEMENT VIEW (ĐỒNG BỘ 1:1 THEO USERMANAGEMENTSCREEN.KT TRÊN ANDROID)
public struct UserManagementView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    // 4 Tabs: 0: Thêm User mới, 1: Danh sách User, 2: Phân quyền, 3: Đặt lại mật khẩu
    @State private var selectedTab: Int = 1

    // Tab 1: Danh sách User
    @State private var searchText: String = ""
    @State private var filterStatus: String = "ALL" // ALL, ACTIVE, PENDING, DISABLED
    @State private var userToDelete: User? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var lockTargetUser: User? = nil
    @State private var lockReasonInput: String = ""
    @State private var unlockTargetUser: User? = nil

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
            let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchSearch = q.isEmpty ||
                u.fullName.localizedCaseInsensitiveContains(q) ||
                u.email.localizedCaseInsensitiveContains(q) ||
                u.phone.contains(q) ||
                u.maNhanVien.localizedCaseInsensitiveContains(q) ||
                u.donVi.localizedCaseInsensitiveContains(q) ||
                u.departmentId.localizedCaseInsensitiveContains(q)

            let matchStatus: Bool
            let st = u.status.uppercased()
            if filterStatus == "ALL" {
                matchStatus = true
            } else if filterStatus == "ACTIVE" {
                matchStatus = st == "ACTIVE" || st == "APPROVED"
            } else if filterStatus == "PENDING" {
                matchStatus = st == "PENDING"
            } else if filterStatus == "DISABLED" {
                matchStatus = st == "DISABLED" || st == "LOCKED"
            } else {
                matchStatus = true
            }

            return matchSearch && matchStatus
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR (ĐỒNG BỘ 1:1 THEO ANDROID TOPAPPBAR)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 6) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý người dùng")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // 4 actions switching tabs
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
                            }) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(selectedTab == 0 ? Color.appPrimaryPink : .white.opacity(0.65))
                                    .frame(width: 32, height: 32)
                            }

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 1 }
                            }) {
                                Image(systemName: "person.3.fill")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(selectedTab == 1 ? Color.appPrimaryPink : .white.opacity(0.65))
                                    .frame(width: 32, height: 32)
                            }

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 2 }
                            }) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(selectedTab == 2 ? Color.appPrimaryPink : .white.opacity(0.65))
                                    .frame(width: 32, height: 32)
                            }

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 3 }
                            }) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(selectedTab == 3 ? Color.appPrimaryPink : .white.opacity(0.65))
                                    .frame(width: 32, height: 32)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

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

                // DIALOG KHÓA TÀI KHOẢN (ĐỒNG BỘ 1:1 ANDROID)
                if let target = lockTargetUser {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Color(hex: "#DC2626"))
                                Text("Vô hiệu hóa tài khoản")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#DC2626"))
                            }

                            Text("Bạn có chắc chắn muốn vô hiệu hóa tài khoản của \(target.fullName.isEmpty ? target.email : target.fullName) (\(target.email))?")
                                .font(.system(size: 13.5))
                                .foregroundColor(Color.appSecondaryDarkBlue)

                            Text("⚠️ Người dùng này sẽ bị đẩy ra khỏi ứng dụng ngay lập tức trên mọi thiết bị và không thể đăng nhập cho đến khi được mở khóa.")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#991B1B"))
                                .padding(8)
                                .background(Color(hex: "#FEF2F2"))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lý do vô hiệu hóa (tùy chọn)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                TextField("vd: Nghỉ việc, Tạm đình chỉ, Vi phạm...", text: $lockReasonInput)
                                    .font(.system(size: 13))
                                    .padding(9)
                                    .background(Color(hex: "#F8FAFC"))
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                            }

                            HStack(spacing: 10) {
                                Button("Hủy") {
                                    lockTargetUser = nil
                                    lockReasonInput = ""
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Color(hex: "#F1F5F9"))
                                .cornerRadius(8)

                                Button("Khóa tài khoản") {
                                    let email = target.email
                                    let reason = lockReasonInput.trimmingCharacters(in: .whitespacesAndNewlines)
                                    viewModel.disableUser(email: email, disable: true, reason: reason)
                                    lockTargetUser = nil
                                    lockReasonInput = ""
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(Color(hex: "#DC2626"))
                                .cornerRadius(8)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(radius: 10)
                        .padding(.horizontal, 24)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchAllDataIfNeeded()
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
        .alert(item: $unlockTargetUser) { target in
            Alert(
                title: Text("Mở khóa tài khoản"),
                message: Text("Bạn có chắc chắn muốn mở khóa cho tài khoản \"\(target.fullName.isEmpty ? target.email : target.fullName)\"?"),
                primaryButton: .default(Text("Mở khóa")) {
                    viewModel.disableUser(email: target.email, disable: false)
                },
                secondaryButton: .cancel(Text("Hủy"))
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

    // MARK: - TAB 1: DANH SÁCH USER (ĐỒNG BỘ 1:1 THEO ANDROID)
    private var userListTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 1. BANNER THÊM USER MỚI
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = 0 }
                }) {
                    HStack(spacing: 6) {
                        Text("Thêm User mới? Chọn")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.appTopBarColor)
                        .cornerRadius(6)

                        Text("trên thanh tiêu đề")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryDarkBlue.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())

                // 2. SEARCH BAR
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    TextField("Tìm kiếm...", text: $searchText)
                        .font(.system(size: 14))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))

                // 3. HORIZONTAL SCROLL STATUS FILTER CHIPS
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        let allCount = viewModel.allUsers.count
                        let activeCount = viewModel.allUsers.filter { $0.status.uppercased() == "ACTIVE" || $0.status.uppercased() == "APPROVED" }.count
                        let pendingCount = viewModel.allUsers.filter { $0.status.uppercased() == "PENDING" }.count
                        let disabledCount = viewModel.allUsers.filter { $0.status.uppercased() == "DISABLED" || $0.status.uppercased() == "LOCKED" }.count

                        statusFilterChip(
                            title: "Tất cả (\(allCount))",
                            isSelected: filterStatus == "ALL",
                            selectedBg: Color(hex: "#EEF2FF"),
                            selectedText: Color(hex: "#1D4ED8"),
                            selectedBorder: Color(hex: "#C7D2FE")
                        ) {
                            filterStatus = "ALL"
                        }

                        statusFilterChip(
                            title: "● Hoạt động (\(activeCount))",
                            isSelected: filterStatus == "ACTIVE",
                            selectedBg: Color(hex: "#16A34A"),
                            selectedText: .white,
                            selectedBorder: Color(hex: "#16A34A")
                        ) {
                            filterStatus = "ACTIVE"
                        }

                        statusFilterChip(
                            title: "⏳ Chờ (\(pendingCount))",
                            isSelected: filterStatus == "PENDING",
                            selectedBg: Color(hex: "#D97706"),
                            selectedText: .white,
                            selectedBorder: Color(hex: "#D97706")
                        ) {
                            filterStatus = "PENDING"
                        }

                        statusFilterChip(
                            title: "🔒 Khóa (\(disabledCount))",
                            isSelected: filterStatus == "DISABLED",
                            selectedBg: Color(hex: "#DC2626"),
                            selectedText: .white,
                            selectedBorder: Color(hex: "#DC2626")
                        ) {
                            filterStatus = "DISABLED"
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.trailing, 14)
                }

                // 4. SECTION HEADER
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Danh sách người dùng (\(filteredUsers.count))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }
                .padding(.top, 4)

                // 5. USER LIST OR EMPTY STATE
                if filteredUsers.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 30)
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Không tìm thấy người dùng phù hợp")
                            .font(.system(size: 13.5))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredUsers) { u in
                            userListItemCard(u)
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    private func statusFilterChip(
        title: String,
        isSelected: Bool,
        selectedBg: Color,
        selectedText: Color,
        selectedBorder: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? selectedText : Color(hex: "#475569"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? selectedBg : Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? selectedBorder : Color(hex: "#CBD5E1"), lineWidth: 1)
                )
        }
    }

    private func userListItemCard(_ u: User) -> some View {
        let isLocked = u.status.uppercased() == "DISABLED" || u.status.uppercased() == "LOCKED"
        let isPending = u.status.uppercased() == "PENDING"
        let isSpecialist = u.isSpecialist || !u.toNghiepVu.isEmpty || u.maKhuVuc.hasPrefix("TO_") || u.departmentId.uppercased().hasPrefix("TO_") || u.departmentId.uppercased().contains("NGHIỆP VỤ") || u.departmentId.uppercased().contains("ỨNG DỤNG")
        let roleLower = u.role.lowercased()
        let isTargetAdmin = roleLower == "admin" || u.isAdmin

        return VStack(alignment: .leading, spacing: 10) {
            // HÀNG 1 (TOP): AVATAR + TÊN + MNV + STATUS PILL (TRÀN TOÀN BỘ CHIỀU RỘNG THẺ)
            HStack(alignment: .center, spacing: 10) {
                // Avatar (Circle avatar 42x42)
                ZStack {
                    Circle()
                        .fill(Color.appSecondaryDarkBlue.opacity(0.1))
                        .frame(width: 42, height: 42)

                    let initial = (u.fullName.isEmpty ? String(u.email.prefix(1)) : String(u.fullName.prefix(1))).uppercased()
                    Text(initial)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(u.fullName.isEmpty ? u.email : u.fullName)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .lineLimit(1)

                        // MNV Badge
                        Text("MNV: \(u.mnvDisplay)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#1D4ED8"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#EFF6FF"))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }

                    // HÀNG 2: VAI TRÒ BADGE + TỔ/CỤM BADGE
                    HStack(spacing: 6) {
                        userRoleBadge(u, isSpecialist: isSpecialist)

                        if isSpecialist || !u.toNghiepVu.isEmpty || !u.maKhuVuc.isEmpty {
                            if isSpecialist {
                                let teamCode = u.toNghiepVu.isEmpty ? u.maKhuVuc : u.toNghiepVu
                                let teamName = viewModel.specialistTeams.first(where: { $0.teamId == teamCode })?.teamName ?? teamCode
                                Text("💻 Tổ: \(teamName)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#7E22CE"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#F3E8FF"))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#D8B4FE"), lineWidth: 1))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            } else if !u.maKhuVuc.isEmpty {
                                Text("Cụm: \(u.maKhuVuc)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#1D4ED8"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#EFF6FF"))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                    }
                }

                Spacer(minLength: 4)

                // Nhãn Trạng thái Tài khoản (Status Pill ở góc trên bên phải)
                if isLocked {
                    Text("🔒 Đã khóa")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: "#DC2626"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#FEF2F2"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#FECACA"), lineWidth: 1))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else if isPending {
                    Text("⏳ Chờ duyệt")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: "#D97706"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#FFFBEB"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text("● Hoạt động")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: "#16A34A"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#F0FDF4"))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#BBF7D0"), lineWidth: 1))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }

            // HÀNG 3: THÔNG TIN CHI TIẾT (EMAIL, SĐT, PHÒNG BAN, ĐƠN VỊ) - TRÀN 100% CHIỀU RỘNG
            VStack(alignment: .leading, spacing: 3) {
                Text("📧 \(u.email)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)

                if !u.phone.isEmpty {
                    Text("📞 SĐT: \(u.phone)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appPrimaryPink)
                        .lineLimit(1)
                }

                let displayDept = u.departmentId.isEmpty ? "Chưa gán" : u.departmentId
                Text("🏛️ Phòng ban: \(displayDept)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .lineLimit(1)

                let uDonVi = u.donVi
                let displayUnit = uDonVi.isEmpty ? (u.isAdmin ? "Tất cả đơn vị (SGCOOP)" : "Chưa gán") : uDonVi
                Text("🏢 Đơn vị: \(displayUnit)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .lineLimit(1)

                if isLocked && !u.disabledReason.isEmpty {
                    Text("⚠️ Lý do khóa: \(u.disabledReason)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#DC2626"))
                        .lineLimit(2)
                }
            }
            .padding(.leading, 2)

            // HÀNG 4: THANH PHÂN CÁCH & NÚT THAO TÁC NẰM DƯỚI (PHÂN QUYỀN, KHÓA/MỞ KHÓA)
            Divider()
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                Spacer()

                // Phân quyền
                Button(action: {
                    selectUserForPermission(u)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = 2
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 11))
                        Text("Phân quyền")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appPrimaryPink, lineWidth: 1))
                }
                .buttonStyle(BorderlessButtonStyle())

                // Khóa / Mở khóa
                if !isTargetAdmin {
                    if isLocked {
                        Button(action: {
                            unlockTargetUser = u
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 11))
                                Text("Mở khóa")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#16A34A"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#16A34A"), lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    } else {
                        Button(action: {
                            lockTargetUser = u
                            lockReasonInput = ""
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 11))
                                Text("Khóa")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#DC2626"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#DC2626"), lineWidth: 1))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#DDE2E5"), lineWidth: 1))
    }

    private func userRoleBadge(_ u: User, isSpecialist: Bool) -> some View {
        let roleLower = u.role.lowercased()
        let bg: Color
        let fg: Color
        let text: String

        if roleLower == "admin" || u.isAdmin {
            bg = Color.appPrimaryPink.opacity(0.12)
            fg = Color.appPrimaryPink
            text = "Quản trị viên (Admin)"
        } else if roleLower == "helpdesk" || u.isHelpDesk {
            bg = Color(hex: "#E0F2FE")
            fg = Color(hex: "#0369A1")
            text = "Phòng Helpdesk"
        } else if roleLower == "kythuat" || roleLower == "technician" || roleLower == "ktv" || (u.isTechnician && !isSpecialist) {
            bg = Color(hex: "#DCFCE7")
            fg = Color(hex: "#15803D")
            text = "Kỹ thuật viên"
        } else if isSpecialist {
            bg = Color(hex: "#F3E8FF")
            fg = Color(hex: "#7E22CE")
            text = "Chuyên viên nghiệp vụ"
        } else if roleLower == "phongban" || roleLower == "quanly" || u.isManager {
            bg = Color.appSecondaryDarkBlue.opacity(0.12)
            fg = Color.appSecondaryDarkBlue
            text = "Quản lý phòng ban"
        } else {
            bg = Color.gray.opacity(0.12)
            fg = Color.gray
            text = "Nhân viên"
        }

        return Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(bg)
            .cornerRadius(6)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
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
