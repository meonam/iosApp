import SwiftUI
import UIKit

// MARK: - MÀN HÌNH QUẢN LÝ NHÂN SỰ 3 TAB (Khớp 100% Android UserManagementScreen.kt)
public struct UserManagementFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 0 // 0: Danh sách, 1: Thêm nhân viên, 2: Phân quyền & Điều chuyển

    // Tab 0: Danh sách
    @State private var searchText: String = ""
    @State private var filterRole: String = "ALL"

    // Tab 1: Thêm mới
    @State private var newEmail: String = ""
    @State private var newFullName: String = ""
    @State private var newMnv: String = ""
    @State private var newPhone: String = ""
    @State private var newRole: String = "nhanvien"
    @State private var newUnit: String = "Co.opmart Cần Thơ"
    @State private var newDept: String = "Phòng Công nghệ thông tin"
    @State private var newPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var isCreatingUser: Bool = false
    @State private var creationMessage: String? = nil

    // Tab 2: Điều chuyển
    @State private var selectedUserForTransfer: UserItem? = nil
    @State private var targetUnit: String = "Co.opmart Cần Thơ"
    @State private var targetDept: String = "Phòng Công nghệ thông tin"
    @State private var isTransferring: Bool = false
    @State private var transferMessage: String? = nil

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    var filteredUsers: [UserItem] {
        firebase.allUsersList.filter { u in
            let matchSearch = searchText.isEmpty ||
                u.fullName.localizedCaseInsensitiveContains(searchText) ||
                u.email.localizedCaseInsensitiveContains(searchText) ||
                u.phone.contains(searchText) ||
                u.maNhanVien.localizedCaseInsensitiveContains(searchText)
            let matchRole = filterRole == "ALL" || u.role.localizedCaseInsensitiveContains(filterRole)
            return matchSearch && matchRole
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 3 TABS HEADER
                Picker("Phân hệ nhân sự", selection: $selectedTab) {
                    Text("Danh Sách (\(firebase.allUsersList.count))").tag(0)
                    Text("Thêm Mới").tag(1)
                    Text("Điều Chuyển").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0:
                            userListTab
                        case 1:
                            addUserTab
                        case 2:
                            transferTab
                        default:
                            EmptyView()
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Quản Lý Nhân Sự")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .onAppear {
                Task { await firebase.fetchAllUsers() }
                if newPassword.isEmpty {
                    generateSecurePassword()
                }
            }
        }
    }

    // --- TAB 0: DANH SÁCH NHÂN SỰ ---
    @ViewBuilder
    private var userListTab: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Tìm theo tên, email, SĐT, MNV...", text: $searchText)
                    .font(.system(size: 14))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

            // Filter Role Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    roleFilterChip("Tất cả", tag: "ALL")
                    roleFilterChip("Admin", tag: "admin")
                    roleFilterChip("HelpDesk", tag: "helpdesk")
                    roleFilterChip("Kỹ thuật", tag: "kythuat")
                    roleFilterChip("Chuyên viên", tag: "chuyenvien")
                    roleFilterChip("Thủ kho", tag: "warehouse")
                    roleFilterChip("Quản lý", tag: "quanly")
                    roleFilterChip("Nhân viên", tag: "nhanvien")
                }
            }

            // User Cards List
            ForEach(filteredUsers) { u in
                HStack(spacing: 12) {
                    // Avatar with online status
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(roleColor(u.role).opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(u.fullName.prefix(1).uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(roleColor(u.role))

                        Circle()
                            .fill(u.isOnline ? Color.green : Color.gray.opacity(0.6))
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(u.fullName)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                            Spacer()
                            Text(u.role.uppercased())
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(roleColor(u.role).opacity(0.12))
                                .foregroundColor(roleColor(u.role))
                                .clipShape(Capsule())
                        }

                        Text(u.email)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        if !u.toNghiepVu.isEmpty || !u.maKhuVuc.isEmpty {
                            HStack(spacing: 6) {
                                if !u.toNghiepVu.isEmpty {
                                    Text("🏷️ \(u.toNghiepVu)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "#0284C7"))
                                }
                                if !u.maKhuVuc.isEmpty {
                                    Text("📍 \(u.maKhuVuc)")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "#059669"))
                                }
                            }
                        }

                        HStack {
                            Text(u.donVi.isEmpty ? "Co.opmart" : u.donVi)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Spacer()
                            if !u.maNhanVien.isEmpty {
                                Text("MNV: \(u.maNhanVien)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            if u.status == "BLOCKED" {
                                Text("ĐÃ KHÓA")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                .contextMenu {
                    Button("Đổi quyền -> Admin") { changeRole(u.email, "admin") }
                    Button("Đổi quyền -> HelpDesk") { changeRole(u.email, "helpdesk") }
                    Button("Đổi quyền -> Kỹ thuật viên") { changeRole(u.email, "kythuat") }
                    Button("Đổi quyền -> Chuyên viên") { changeRole(u.email, "chuyenvien") }
                    Button("Đổi quyền -> Thủ kho") { changeRole(u.email, "warehouse") }
                    Button("Đổi quyền -> Quản lý phòng") { changeRole(u.email, "quanly") }
                    Button("Đổi quyền -> Nhân viên") { changeRole(u.email, "nhanvien") }
                    Divider()
                    if u.status == "BLOCKED" {
                        Button("Mở khóa tài khoản") { toggleBlock(u.email, false) }
                    } else {
                        Button("Khóa tài khoản", role: .destructive) { toggleBlock(u.email, true) }
                    }
                }
            }
        }
    }

    // --- TAB 1: THÊM NHÂN VIÊN MỚI ---
    @ViewBuilder
    private var addUserTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Thêm nhân viên mới vào hệ thống")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            Group {
                inputField(label: "Email đăng nhập (*)", placeholder: "nhanvien@saigonco-op.com.vn", text: $newEmail)
                inputField(label: "Họ và tên (*)", placeholder: "Nguyễn Văn A", text: $newFullName)
                inputField(label: "Mã nhân viên (MNV)", placeholder: "VD: 7075, 43144...", text: $newMnv)
                inputField(label: "Số điện thoại liên hệ", placeholder: "0901234567", text: $newPhone)
            }

            // Role Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Vai trò phân quyền")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                Picker("Vai trò", selection: $newRole) {
                    Text("Nhân viên").tag("nhanvien")
                    Text("Kỹ thuật viên").tag("kythuat")
                    Text("Chuyên viên nghiệp vụ").tag("chuyenvien")
                    Text("Thủ kho thiết bị").tag("warehouse")
                    Text("Quản lý phòng ban").tag("quanly")
                    Text("HelpDesk").tag("helpdesk")
                    Text("Admin").tag("admin")
                }
                .pickerStyle(.menu)
                .padding(8)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(10)
            }

            // Unit / Store Selector
            VStack(alignment: .leading, spacing: 4) {
                Text("Đơn vị / Chi nhánh Co.opmart")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("Tên đơn vị Co.opmart", text: $newUnit)
                    .padding(10)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(10)
            }

            // Password Generator
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mật khẩu khởi tạo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Tạo ngẫu nhiên 🎲") {
                        generateSecurePassword()
                    }
                    .font(.caption.bold())
                    .foregroundColor(.appPrimaryPink)
                }

                HStack {
                    if showPassword {
                        TextField("Mật khẩu", text: $newPassword)
                    } else {
                        SecureField("Mật khẩu", text: $newPassword)
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.secondary)
                    }

                    Button(action: {
                        UIPasteboard.general.string = newPassword
                        creationMessage = "Đã sao chép mật khẩu: \(newPassword)"
                    }) {
                        Image(systemName: "doc.on.doc.fill")
                            .foregroundColor(.appSecondaryDarkBlue)
                    }
                }
                .padding(10)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(10)
            }

            // Submit Button
            Button(action: submitNewUser) {
                HStack {
                    if isCreatingUser {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("LƯU & KÍCH HOẠT NHÂN VIÊN")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimaryPink)
                .cornerRadius(14)
            }
            .disabled(isCreatingUser || newEmail.isEmpty || newFullName.isEmpty)

            if let msg = creationMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.appPrimaryPink)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // --- TAB 2: ĐIỀU CHUYỂN & PHÂN QUYỀN ---
    @ViewBuilder
    private var transferTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Điều chuyển đơn vị & phòng ban")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            Text("Chọn nhân viên cần điều chuyển:")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(firebase.allUsersList) { u in
                        Button(action: {
                            selectedUserForTransfer = u
                            targetUnit = u.donVi.isEmpty ? "Co.opmart Cần Thơ" : u.donVi
                            targetDept = u.departmentId.isEmpty ? "Phòng Công nghệ thông tin" : u.departmentId
                        }) {
                            Text(u.fullName)
                                .font(.system(size: 12, weight: selectedUserForTransfer?.email == u.email ? .bold : .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedUserForTransfer?.email == u.email ? Color.appSecondaryDarkBlue : Color(UIColor.tertiarySystemFill))
                                .foregroundColor(selectedUserForTransfer?.email == u.email ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }

            if let target = selectedUserForTransfer {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Đang chọn: \(target.fullName) (\(target.email))")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appSecondaryDarkBlue)

                    inputField(label: "Đơn vị mới", placeholder: "Co.opmart...", text: $targetUnit)
                    inputField(label: "Phòng ban mới", placeholder: "Phòng...", text: $targetDept)

                    Button(action: executeTransfer) {
                        HStack {
                            if isTransferring {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("XÁC NHẬN ĐIỀU CHUYỂN")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.appSecondaryDarkBlue)
                        .cornerRadius(12)
                    }
                    .disabled(isTransferring)

                    if let msg = transferMessage {
                        Text(msg)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(14)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func roleFilterChip(_ label: String, tag: String) -> some View {
        Button(action: { filterRole = tag }) {
            Text(label)
                .font(.system(size: 12, weight: filterRole == tag ? .bold : .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(filterRole == tag ? Color.appPrimaryPink : Color(UIColor.tertiarySystemFill))
                .foregroundColor(filterRole == tag ? .white : .primary)
                .clipShape(Capsule())
        }
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .padding(10)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(10)
        }
    }

    private func generateSecurePassword() {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%"
        let pwd = String((0..<10).map { _ in chars.randomElement()! })
        newPassword = "Sg@" + pwd
    }

    private func submitNewUser() {
        isCreatingUser = true
        Task {
            let ok = await firebase.addUserByAdmin(
                email: newEmail,
                fullName: newFullName,
                mnv: newMnv,
                phone: newPhone,
                role: newRole,
                unit: newUnit,
                dept: newDept,
                password: newPassword
            )
            isCreatingUser = false
            withAnimation {
                creationMessage = ok ? "✅ Đã thêm nhân viên [\(newFullName)] thành công!" : "❌ Lỗi thêm nhân viên."
            }
            if ok {
                newEmail = ""
                newFullName = ""
                newMnv = ""
                newPhone = ""
                generateSecurePassword()
                await firebase.fetchAllUsers()
            }
        }
    }

    private func executeTransfer() {
        guard let u = selectedUserForTransfer else { return }
        isTransferring = true
        Task {
            let ok = await firebase.transferUser(email: u.email, newUnit: targetUnit, newDept: targetDept)
            isTransferring = false
            withAnimation {
                transferMessage = ok ? "✅ Đã điều chuyển \(u.fullName) sang \(targetUnit)!" : "❌ Lỗi điều chuyển."
            }
            if ok {
                await firebase.fetchAllUsers()
            }
        }
    }

    private func roleColor(_ r: String) -> Color {
        let rl = r.lowercased()
        if rl.contains("admin") { return Color.appPrimaryPink }
        if rl.contains("helpdesk") || rl == "hd" { return Color(hex: "#0284C7") }
        if rl.contains("kythuat") || rl.contains("tech") { return Color(hex: "#059669") }
        if rl.contains("chuyen") || rl.contains("specialist") { return Color(hex: "#D97706") }
        if rl.contains("kho") || rl.contains("warehouse") { return Color(hex: "#EA580C") }
        if rl.contains("quanly") || rl.contains("phong") || rl.contains("manager") { return Color(hex: "#7C3AED") }
        return Color.appSecondaryDarkBlue
    }

    private func changeRole(_ email: String, _ role: String) {
        Task { _ = await firebase.changeUserRole(email: email, newRole: role) }
    }

    private func toggleBlock(_ email: String, _ block: Bool) {
        Task { _ = await firebase.toggleUserBlock(email: email, block: block) }
    }
}
