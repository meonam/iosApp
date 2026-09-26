import SwiftUI

// MARK: - MÀN HÌNH QUẢN LÝ TÀI KHOẢN NHÂN SỰ 3 TABS (ĐỒNG BỘ 1:1 VỚI USERMANAGEMENTSCREEN.KT TRÊN ANDROID)
public struct UserManagementView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var selectedTab: Int = 0 // 0: Danh sách, 1: Thêm mới, 2: Điều chuyển
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

    // Điều chuyển
    @State private var selectedUserForTransfer: User? = nil
    @State private var targetUnit: String = "Co.opmart Cần Thơ"
    @State private var targetDept: String = "Phòng Công nghệ thông tin"

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
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
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
                    .background(Color.appTopBarColor)

                    // 2. SEGMENTED TABS (DANH SÁCH | THÊM MỚI | ĐIỀU CHUYỂN)
                    Picker("Tab", selection: $selectedTab) {
                        Text("Danh Sách (\(viewModel.allUsers.count))").tag(0)
                        Text("Thêm Mới").tag(1)
                        Text("Điều Chuyển").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white)

                    // 3. TAB CONTENT
                    if selectedTab == 0 {
                        userListTab
                    } else if selectedTab == 1 {
                        addNewUserTab
                    } else {
                        transferUserTab
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
        }
    }

    // MARK: - TAB 1: DANH SÁCH USER
    private var userListTab: some View {
        VStack(spacing: 8) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextSecondary)
                TextField("Tìm theo tên, email, SĐT, mã NV...", text: $searchText)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextSecondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
            .padding(.horizontal, 14)

            // Role chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    roleChip(title: "Tất cả", tag: "ALL")
                    roleChip(title: "Admin", tag: "ADMIN")
                    roleChip(title: "HelpDesk", tag: "HELPDESK")
                    roleChip(title: "Kỹ thuật", tag: "TECHNICIAN")
                    roleChip(title: "Quản lý", tag: "MANAGER")
                    roleChip(title: "Nhân viên", tag: "STAFF")
                }
                .padding(.horizontal, 14)
            }

            // List
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredUsers) { u in
                        userCard(u)
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
                .foregroundColor(isSel ? .white : Color.appTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSel ? Color.appSecondaryDarkBlue : Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
        }
    }

    private func userCard(_ u: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimaryPink)
                        .frame(width: 40, height: 40)
                    Text(String(u.fullName.prefix(1)).uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(u.fullName.isEmpty ? u.email : u.fullName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text(u.email)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)

                    if !u.phone.isEmpty {
                        Text("SĐT: \(u.phone)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }

                Spacer()

                // Role badge
                Text(u.roleDisplayName)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appSecondaryDarkBlue)
                    .clipShape(Capsule())
            }

            Divider()

            HStack {
                Label(u.donVi.isEmpty ? "Văn phòng SGCOOP" : u.donVi, systemImage: "building.2")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)

                Spacer()

                Label(u.departmentId.isEmpty ? "Chưa gán phòng" : u.departmentId, systemImage: "folder")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - TAB 2: THÊM MỚI
    private var addNewUserTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("THÔNG TIN NHÂN VIÊN MỚI")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)

                formField(label: "Họ và tên *", text: $newFullName, placeholder: "Ví dụ: Nguyễn Văn A")
                formField(label: "Email công ty *", text: $newEmail, placeholder: "nguyenvana@sgcoop.com")
                formField(label: "Mã nhân viên (MNV)", text: $newMnv, placeholder: "Ví dụ: NV01234")
                formField(label: "Số điện thoại", text: $newPhone, placeholder: "0901234567")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Vai trò hệ thống")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.appTextSecondary)
                    Picker("Vai trò", selection: $newRole) {
                        Text("Nhân viên (STAFF)").tag("STAFF")
                        Text("Kỹ thuật viên (TECHNICIAN)").tag("TECHNICIAN")
                        Text("HelpDesk (HELPDESK)").tag("HELPDESK")
                        Text("Quản lý phòng (MANAGER)").tag("MANAGER")
                        Text("Quản trị viên (ADMIN)").tag("ADMIN")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
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
                        .background(Color.appPrimaryPink)
                        .cornerRadius(10)
                }
                .padding(.top, 10)
            }
            .padding(16)
        }
    }

    // MARK: - TAB 3: ĐIỀU CHUYỂN
    private var transferUserTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("ĐIỀU CHUYỂN ĐƠN VỊ & PHÒNG BAN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)

                Text("Chọn nhân viên cần điều chuyển:")
                    .font(.system(size: 13, weight: .medium))

                Picker("Nhân viên", selection: $selectedUserForTransfer) {
                    Text("-- Chọn nhân viên --").tag(nil as User?)
                    ForEach(viewModel.allUsers) { u in
                        Text("\(u.fullName.isEmpty ? u.email : u.fullName) (\(u.email))").tag(u as User?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                if let sel = selectedUserForTransfer {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Đang ở: \(sel.donVi) • \(sel.departmentId)")
                            .font(.system(size: 12))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                    .padding(8)
                    .background(Color.appSecondaryDarkBlue.opacity(0.1))
                    .cornerRadius(8)
                }

                formField(label: "Đơn vị chuyển đến", text: $targetUnit, placeholder: "Co.opmart Cần Thơ")
                formField(label: "Phòng ban chuyển đến", text: $targetDept, placeholder: "Phòng CNTT")

                Button(action: {
                    guard let sel = selectedUserForTransfer else { return }
                    viewModel.transferUser(email: sel.email, newUnit: targetUnit, newDept: targetDept)
                    selectedTab = 0
                }) {
                    Text("Xác nhận điều chuyển nhân sự")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(10)
                }
                .disabled(selectedUserForTransfer == nil)
                .padding(.top, 10)
            }
            .padding(16)
        }
    }

    private func formField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.appTextSecondary)
            TextField(placeholder, text: text)
                .font(.system(size: 13))
                .padding(10)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
        }
    }
}
