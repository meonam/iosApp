import SwiftUI

// MARK: - MÀN HÌNH DUYỆT NHÂN VIÊN MỚI (ĐỒNG BỘ 1:1 THEO APPROVESTAFFSCREEN.KT TRÊN ANDROID)
public struct ApproveStaffView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var staffToApprove: User? = nil
    @State private var selectedRole: String = "STAFF"
    @State private var selectedUnit: String = ""
    @State private var selectedDept: String = ""
    @State private var showApprovalSheet: Bool = false
    @State private var showRejectAlert: Bool = false
    @State private var staffToReject: User? = nil

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var pendingList: [User] {
        viewModel.pendingUsers.filter { u in
            searchQuery.isEmpty ||
            u.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            u.email.localizedCaseInsensitiveContains(searchQuery) ||
            u.phone.contains(searchQuery) ||
            u.donVi.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Duyệt nhân viên mới (\(viewModel.pendingUsers.count))")
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

                    // 2. SEARCH BAR
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm theo tên, email, SĐT, đơn vị...", text: $searchQuery)
                            .font(.system(size: 14))
                            .foregroundColor(Color.appTextPrimary)
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.appSurface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(12)

                    // 3. DANH SÁCH CHỜ DUYỆT
                    if pendingList.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Color.appSuccess)
                            Text("Không có nhân viên nào đang chờ duyệt!")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("Tất cả tài khoản đăng ký mới đã được xử lý xong.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(pendingList) { staff in
                                    pendingCard(staff)
                                }
                            }
                            .padding(12)
                        }
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
        .sheet(isPresented: $showApprovalSheet) {
            approvalSheetView
        }
        .alert(isPresented: $showRejectAlert) {
            Alert(
                title: Text("Từ chối phê duyệt"),
                message: Text("Bạn có chắc chắn muốn từ chối tài khoản \(staffToReject?.email ?? "")?"),
                primaryButton: .destructive(Text("Từ chối")) {
                    if let s = staffToReject {
                        viewModel.rejectUser(email: s.email)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func pendingCard(_ staff: User) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(staff.fullName.isEmpty ? staff.email : staff.fullName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text(staff.email)
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)

                    if !staff.phone.isEmpty {
                        Text("SĐT: \(staff.phone)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }

                Spacer()

                Text("CHỜ DUYỆT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appPrimaryPink.opacity(0.12))
                    .cornerRadius(6)
            }

            Divider()

            HStack {
                Button(action: {
                    staffToReject = staff
                    showRejectAlert = true
                }) {
                    Text("Từ chối")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appDanger)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.appDanger.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                Button(action: {
                    staffToApprove = staff
                    selectedUnit = staff.donVi.isEmpty ? (viewModel.units.first?.tenDonVi ?? "") : staff.donVi
                    selectedDept = staff.departmentId.isEmpty ? (viewModel.departments.first?.departmentName ?? "") : staff.departmentId
                    showApprovalSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Phê duyệt")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.appSuccess)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private var approvalSheetView: some View {
        NavigationView {
            Form {
                Section(header: Text("Tài khoản phê duyệt")) {
                    Text(staffToApprove?.fullName ?? "")
                        .font(.headline)
                    Text(staffToApprove?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Phân quyền vai trò")) {
                    Picker("Vai trò", selection: $selectedRole) {
                        Text("Nhân viên đơn vị (STAFF)").tag("STAFF")
                        Text("Nhân viên phòng ban (DEPT_STAFF)").tag("DEPT_STAFF")
                        Text("Kỹ thuật viên (TECHNICIAN)").tag("TECHNICIAN")
                        Text("HelpDesk (HELPDESK)").tag("HELPDESK")
                        Text("Quản lý phòng (MANAGER)").tag("MANAGER")
                        Text("Quản trị viên (ADMIN)").tag("ADMIN")
                    }
                }

                Section(header: Text("Đơn vị")) {
                    if !viewModel.units.isEmpty {
                        Picker("Chọn Đơn vị", selection: $selectedUnit) {
                            Text("-- Chọn đơn vị --").tag("")
                            ForEach(viewModel.units) { u in
                                Text(u.tenDonVi).tag(u.tenDonVi)
                            }
                        }
                    }
                    TextField("Hoặc nhập tên Đơn vị...", text: $selectedUnit)
                }

                Section(header: Text("Phòng ban")) {
                    if !viewModel.departments.isEmpty {
                        Picker("Chọn Phòng ban", selection: $selectedDept) {
                            Text("-- Chọn phòng ban --").tag("")
                            ForEach(viewModel.departments) { d in
                                Text(d.departmentName).tag(d.departmentName)
                            }
                        }
                    }
                    TextField("Hoặc nhập tên Phòng ban...", text: $selectedDept)
                }
            }
            .navigationTitle("Xác nhận phê duyệt")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Hủy") { showApprovalSheet = false }
                , trailing: Button("Duyệt") {
                        if let s = staffToApprove {
                            viewModel.approveUser(email: s.email, role: selectedRole, donVi: selectedUnit, departmentId: selectedDept)
                        }
                        showApprovalSheet = false
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimaryPink))
        }
    }
}

