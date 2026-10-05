import SwiftUI

// MARK: - DEPARTMENT MANAGER VIEW (ĐỒNG BỘ 1:1 THEO ANDROID DEPARTMENTMANAGERSCREEN.KT)
public struct DepartmentManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var showEditDialog: Bool = false
    @State private var isEditingExisting: Bool = false

    // Form states (matching Android)
    @State private var editDeptId: String = ""
    @State private var editDeptName: String = ""
    @State private var editDeptType: String = "GENERAL"
    @State private var editDeptSlaEnabled: Bool = false
    @State private var editDeptSlaResponse: String = "30"
    @State private var editDeptSlaResolve: String = "240"
    @State private var editManagerName: String = ""
    @State private var editManagerEmail: String = ""
    @State private var editHotline: String = ""
    @State private var editLocation: String = ""
    @State private var editIsActive: Bool = true
    @State private var isSaving: Bool = false

    // Delete confirmation
    @State private var deptToDelete: Department? = nil
    @State private var showDeleteConfirm: Bool = false

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredDepts: [Department] {
        viewModel.departments.filter { d in
            searchQuery.isEmpty ||
            d.departmentName.localizedCaseInsensitiveContains(searchQuery) ||
            d.departmentId.localizedCaseInsensitiveContains(searchQuery) ||
            d.hotline.contains(searchQuery) ||
            d.managerName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private func getMemberCount(for dept: Department) -> Int {
        let dKey = dept.departmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dNameKey = dept.departmentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let count = viewModel.userCountByDept[dKey], count > 0 { return count }
        if let count = viewModel.userCountByDept[dNameKey], count > 0 { return count }
        let cleanDKey = dKey.replacingOccurrences(of: "dept_", with: "")
        return viewModel.allUsers.filter { user in
            let uDept = user.departmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !uDept.isEmpty && (
                uDept == dKey ||
                uDept == dNameKey ||
                uDept == cleanDKey ||
                dNameKey.contains(uDept) ||
                uDept.contains(dNameKey)
            )
        }.count
    }

    private func getDeviceCount(for dept: Department) -> Int {
        let dKey = dept.departmentId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let dNameKey = dept.departmentName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let count = viewModel.deviceCountByDept[dKey], count > 0 { return count }
        if let count = viewModel.deviceCountByDept[dNameKey], count > 0 { return count }
        return 0
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR (Đồng bộ Android: Nền xanh đậm, Tiêu đề, nút back, nút icon cụm & thêm)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Phòng ban")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { openAdd() }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    // SEARCH BAR VÀ NÚT "+ THÊM" (Đồng bộ 1:1 Android)
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color(hex: "#64748B"))
                                .font(.system(size: 15))
                            TextField("Tìm kiếm phòng ban...", text: $searchQuery)
                                .font(.system(size: 14))
                                .foregroundColor(Color.appTextPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                        Button(action: { openAdd() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Thêm")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                    // TIÊU ĐỀ DANH SÁCH PHÒNG BAN (X)
                    HStack {
                        Text("Danh sách phòng ban (\(filteredDepts.count))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)

                    // NỘI DUNG DANH SÁCH PHÒNG BAN
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimaryPink))
                        Spacer()
                    } else if filteredDepts.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "building.2.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Không tìm thấy phòng ban nào")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredDepts) { dept in
                                    deptCardView(dept)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .refreshable {
                            await refreshData()
                        }
                    }
                }

                // DIALOG CHỈNH SỬA / THÊM PHÒNG BAN (Đồng bộ 1:1 Android)
                if showEditDialog {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            if !isSaving { showEditDialog = false }
                        }

                    deptEditDialog
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                        .padding(.horizontal, 20)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.departments.isEmpty {
                viewModel.fetchDepartments()
            }
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
        }
        .alert(isPresented: $showDeleteConfirm) {
            Alert(
                title: Text("Xác nhận xóa phòng ban"),
                message: Text("Bạn có chắc chắn muốn xóa phòng ban \"\(deptToDelete?.departmentName ?? "")\"? Hành động này không thể hoàn tác."),
                primaryButton: .destructive(Text("Xóa")) {
                    if let d = deptToDelete {
                        Task {
                            await viewModel.deleteDepartment(deptId: d.departmentId)
                        }
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - THẺ PHÒNG BAN (DEPARTMENT CARD - ĐỒNG BỘ 1:1 ANDROID)
    private func deptCardView(_ dept: Department) -> some View {
        let memberCount = getMemberCount(for: dept)
        let deviceCount = getDeviceCount(for: dept)

        return VStack(alignment: .leading, spacing: 7) {
            // Hàng 1: Mã PB + Tên phòng ban + Switch Bật/Tắt trạng thái
            HStack(spacing: 8) {
                Text(dept.departmentId)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(dept.isActive ? Color.appSecondaryDarkBlue : Color.gray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(dept.isActive ? Color(hex: "#EFF6FF") : Color(hex: "#F1F5F9"))
                    .cornerRadius(6)

                Text(dept.departmentName)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(dept.isActive ? Color.appTextPrimary : Color.gray)
                    .lineLimit(1)

                Spacer()

                // Switch Bật/Tắt đồng bộ Android
                Toggle("", isOn: Binding(
                    get: { dept.isActive },
                    set: { _ in
                        Task {
                            await viewModel.toggleDepartmentActive(dept)
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: Color.appPrimaryPink))
            }

            // Hàng 2: Badges Phân loại nghiệp vụ (1:1 Android)
            HStack(spacing: 6) {
                deptTypeBadge(dept)
                if !dept.isActive {
                    Text("🔒 Đã khóa")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#DC2626"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#FEE2E2"))
                        .cornerRadius(4)
                }
            }

            // Hàng 3: Chi tiết Trưởng phòng, Hotline, Vị trí, SLA
            let detailParts: [String] = {
                var list: [String] = []
                if !dept.managerName.isEmpty { list.append("👤 \(dept.managerName)") }
                if !dept.hotline.isEmpty { list.append("📞 \(dept.hotline)") }
                if !dept.location.isEmpty { list.append("📍 \(dept.location)") }
                if dept.isHelpDesk || dept.departmentType == "HELPDESK" || dept.departmentName.localizedCaseInsensitiveContains("helpdesk") {
                    list.append("🎧 SLA Hệ thống (P1)")
                } else if dept.isIncidentHandler || dept.isApplicationSupport || dept.departmentType == "IT" {
                    let resH = max(0, dept.slaResolveMinutes / 60)
                    list.append("⏱ SLA: \(dept.slaResponseMinutes)p/\(resH)h")
                }
                return list
            }()

            if !detailParts.isEmpty {
                Text(detailParts.joined(separator: " • "))
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.gray)
                    .lineLimit(1)
            }

            Divider()
                .padding(.vertical, 1)

            // Hàng 4: Thống kê số NV & Thiết bị + Nút Sửa / Xóa
            HStack(spacing: 8) {
                // Badge Nhân viên: 👥 X NV
                HStack(spacing: 4) {
                    Text("👥")
                        .font(.system(size: 11))
                    Text("\(memberCount) NV")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#1D4ED8"))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "#EFF6FF"))
                .cornerRadius(6)

                // Badge Thiết bị: 💻 X Thiết bị
                HStack(spacing: 4) {
                    Text("💻")
                        .font(.system(size: 11))
                    Text("\(deviceCount) Thiết bị")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#15803D"))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: "#F0FDF4"))
                .cornerRadius(6)

                Spacer()

                // Nút Sửa
                Button(action: { openEdit(dept) }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }

                // Nút Xóa
                Button(action: {
                    deptToDelete = dept
                    showDeleteConfirm = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color.red)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(12)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .opacity(dept.isActive ? 1.0 : 0.7)
    }

    private func deptTypeBadge(_ dept: Department) -> some View {
        let (icon, label, colorHex, bgHex): (String, String, String, String) = {
            let t = dept.departmentType.uppercased()
            if dept.isHelpDesk || t == "HELPDESK" {
                return ("🎧", "Tổng đài tiếp nhận HelpDesk", "#0284C7", "#E0F2FE")
            } else if dept.isIncidentHandler || t == "IT" || t == "INCIDENT_HANDLER" {
                return ("🛠️", "Kỹ thuật & Xử lý sự cố", "#7E22CE", "#F3E8FF")
            } else if dept.isApplicationSupport || t == "APPLICATION_SUPPORT" {
                return ("💻", "Khối ứng dụng", "#6D28D9", "#EDE9FE")
            } else if dept.isWarehouse || t == "WAREHOUSE" {
                return ("📦", "Kho thiết bị", "#B45309", "#FEF3C7")
            } else {
                return ("🏢", "Phòng ban chuyên môn", "#64748B", "#F1F5F9")
            }
        }()

        return HStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 10.5))
            Text(label)
                .font(.system(size: 10.5, weight: .bold))
        }
        .foregroundColor(Color(hex: colorHex))
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color(hex: bgHex))
        .cornerRadius(4)
    }

    // MARK: - POPUP DIALOG CHỈNH SỬA / THÊM PHÒNG BAN (ĐỒNG BỘ 1:1 ANDROID DIALOG)
    private var deptEditDialog: some View {
        VStack(spacing: 12) {
            // Tiêu đề
            HStack {
                Text(isEditingExisting ? "Chỉnh sửa phòng ban" : "Thêm phòng ban mới")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
            }
            .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    // Hàng 1: Mã PB * và Tên phòng ban * (Đặt cạnh nhau 1:1 Android)
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 2) {
                                Text("Mã PB")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.appTextPrimary)
                                Text("*")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            TextField("Mã PB", text: $editDeptId)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                                .disabled(isEditingExisting)
                                .padding(8)
                                .background(isEditingExisting ? Color.appSurfaceVariant : Color.appSurface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 2) {
                                Text("Tên phòng ban")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color.appTextPrimary)
                                Text("*")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            TextField("Tên phòng ban", text: $editDeptName)
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextPrimary)
                                .padding(8)
                                .background(Color.appSurfaceVariant)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Hàng 2: Phân loại nghiệp vụ * -> Loại phòng ban (Dropdown)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 2) {
                            Text("🏷️ Phân loại nghiệp vụ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                            Text("*")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }

                        Menu {
                            Button("🎧 Tổng đài tiếp nhận HelpDesk") { editDeptType = "HELPDESK" }
                            Button("🛠️ Kỹ thuật & Xử lý sự cố") { editDeptType = "IT" }
                            Button("💻 Khối ứng dụng") { editDeptType = "APPLICATION_SUPPORT" }
                            Button("📦 Kho thiết bị") { editDeptType = "WAREHOUSE" }
                            Button("🏢 Phòng ban chuyên môn") { editDeptType = "GENERAL" }
                        } label: {
                            HStack {
                                Text(displayTypeName(for: editDeptType))
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.appTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(9)
                            .background(Color.appSurfaceVariant)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }

                    // Hàng 3: Khung SLA nếu là loại Kỹ thuật/HelpDesk/Ứng dụng
                    let isTechRole = editDeptType == "HELPDESK" || editDeptType == "IT" || editDeptType == "APPLICATION_SUPPORT"
                    let isHelpDeskType = editDeptType == "HELPDESK" || editDeptName.localizedCaseInsensitiveContains("helpdesk")
                    if isTechRole {
                        if isHelpDeskType {
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 4) {
                                        Text("🎧")
                                            .font(.system(size: 13))
                                        Text("SLA Tiếp nhận & Điều phối HelpDesk (P1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                    }
                                    Text("Áp dụng theo Cài đặt Admin (Ca kíp, GPS & SLA). Quản lý tập trung tại Cài đặt hệ thống.")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Text("⚙️ Cấu hình Hệ thống")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#166534"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#DCFCE7"))
                                    .cornerRadius(4)
                            }
                            .padding(10)
                            .background(Color(hex: "#EFF6FF"))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Button(action: { editDeptSlaEnabled.toggle() }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: editDeptSlaEnabled ? "checkmark.square.fill" : "square")
                                            .font(.system(size: 16))
                                            .foregroundColor(editDeptSlaEnabled ? Color.appPrimaryPink : .gray)

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("⏱️ Cam kết thời gian xử lý (SLA)")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(Color.appTextPrimary)
                                            Text(editDeptSlaEnabled ? "Đo lường thời gian tiếp nhận & xử lý sự cố" : "Đang tắt (phù hợp nội bộ, không áp KPI)")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                if editDeptSlaEnabled {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Tiếp nhận (phút)")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.gray)
                                            TextField("30", text: $editDeptSlaResponse)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appTextPrimary)
                                                .padding(6)
                                                .background(Color.appSurfaceVariant)
                                                .cornerRadius(6)
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appCardBorder, lineWidth: 1))
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Xử lý (phút)")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.gray)
                                            TextField("240", text: $editDeptSlaResolve)
                                                .keyboardType(.numberPad)
                                                .font(.system(size: 13))
                                                .foregroundColor(Color.appTextPrimary)
                                                .padding(6)
                                                .background(Color.appSurfaceVariant)
                                                .cornerRadius(6)
                                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appCardBorder, lineWidth: 1))
                                        }
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(10)
                            .background(Color.appSurfaceVariant)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }

                    // Hàng 4: Trưởng phòng / Phụ trách Dropdown
                    VStack(alignment: .leading, spacing: 4) {
                        Text("👤 Trưởng phòng / Phụ trách")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Color.appTextPrimary)

                        Menu {
                            Button("(Chưa chỉ định trưởng phòng)") {
                                editManagerEmail = ""
                                editManagerName = ""
                            }
                            Divider()
                            ForEach(viewModel.allUsers) { u in
                                Button("\(u.fullName.isEmpty ? u.email : u.fullName) (\(u.email))") {
                                    editManagerEmail = u.email
                                    editManagerName = u.fullName.isEmpty ? u.email : u.fullName
                                }
                            }
                        } label: {
                            HStack {
                                Text(editManagerName.isEmpty ? "(Chưa chỉ định trưởng phòng)" : "\(editManagerName) (\(editManagerEmail))")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(editManagerName.isEmpty ? .gray : Color.appTextPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(9)
                            .background(Color.appSurfaceVariant)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }

                    // Hàng 5: Hotline & Vị trí (Đặt cạnh nhau 1:1 Android)
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📞 Hotline")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                            TextField("101, 090...", text: $editHotline)
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextPrimary)
                                .padding(8)
                                .background(Color.appSurfaceVariant)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("📍 Vị trí")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                            TextField("Tầng 2, Nhà A", text: $editLocation)
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextPrimary)
                                .padding(8)
                                .background(Color.appSurfaceVariant)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Hàng 6: Switch trạng thái hoạt động (Khung xanh lá 1:1 Android)
                    HStack(alignment: .center, spacing: 10) {
                        Toggle("", isOn: $editIsActive)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color.appPrimaryPink))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(editIsActive ? "🟢 Đang hoạt động" : "🔒 Tạm khóa nhận việc")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(editIsActive ? Color.green : Color.gray)
                            Text(editIsActive ? "Được phân bổ sự cố bình thường" : "Tạm ngưng điều phối sự cố mới")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.gray)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(editIsActive ? Color.green.opacity(0.15) : Color.appSurfaceVariant)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(editIsActive ? Color.green.opacity(0.4) : Color.appCardBorder, lineWidth: 1))
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 420)

            // HÀNG NÚT: HỦY VÀ LƯU THAY ĐỔI (1:1 ANDROID)
            HStack(spacing: 12) {
                Button(action: { showEditDialog = false }) {
                    Text("Hủy")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appPrimaryPink)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                }

                Spacer()

                Button(action: { saveDepartmentChanges() }) {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(width: 80, height: 20)
                    } else {
                        Text(isEditingExisting ? "Lưu thay đổi" : "Tạo phòng ban")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(20)
                    }
                }
                .disabled(isSaving || editDeptId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editDeptName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 4)
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
    }

    private func displayTypeName(for type: String) -> String {
        switch type.uppercased() {
        case "HELPDESK": return "🎧 Tổng đài tiếp nhận HelpDesk"
        case "IT", "INCIDENT_HANDLER": return "🛠️ Kỹ thuật & Xử lý sự cố"
        case "APPLICATION_SUPPORT": return "💻 Khối ứng dụng"
        case "WAREHOUSE": return "📦 Kho thiết bị"
        default: return "🏢 Phòng ban chuyên môn"
        }
    }

    private func openAdd() {
        isEditingExisting = false
        editDeptId = ""
        editDeptName = ""
        editDeptType = "GENERAL"
        editDeptSlaEnabled = false
        editDeptSlaResponse = "30"
        editDeptSlaResolve = "240"
        editManagerName = ""
        editManagerEmail = ""
        editHotline = ""
        editLocation = ""
        editIsActive = true
        showEditDialog = true
    }

    private func openEdit(_ dept: Department) {
        isEditingExisting = true
        editDeptId = dept.departmentId
        editDeptName = dept.departmentName
        editDeptType = dept.departmentType.isEmpty ? "GENERAL" : dept.departmentType
        let hasSla = dept.slaResponseMinutes > 0 || dept.slaResolveMinutes > 0
        editDeptSlaEnabled = hasSla
        editDeptSlaResponse = hasSla ? "\(dept.slaResponseMinutes)" : "30"
        editDeptSlaResolve = hasSla ? "\(dept.slaResolveMinutes)" : "240"
        editManagerName = dept.managerName
        editManagerEmail = dept.managerEmail
        editHotline = dept.hotline
        editLocation = dept.location
        editIsActive = dept.isActive
        showEditDialog = true
    }

    private func saveDepartmentChanges() {
        let cleanId = editDeptId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanName = editDeptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty, !cleanName.isEmpty else { return }

        let isHd = editDeptType == "HELPDESK"
        let isInc = editDeptType == "IT" || editDeptType == "INCIDENT_HANDLER"
        let isApp = editDeptType == "APPLICATION_SUPPORT"
        let isWh = editDeptType == "WAREHOUSE"
        let isTech = isHd || isInc || isApp

        let slaResp = (isTech && editDeptSlaEnabled) ? (Int(editDeptSlaResponse) ?? 30) : 0
        let slaRes = (isTech && editDeptSlaEnabled && !isHd && !cleanName.localizedCaseInsensitiveContains("helpdesk")) ? (Int(editDeptSlaResolve) ?? 240) : 0

        let dept = Department(
            departmentId: cleanId,
            companyId: viewModel.companyId,
            departmentName: cleanName,
            departmentType: editDeptType,
            isHelpDesk: isHd,
            isIncidentHandler: isInc,
            isWarehouse: isWh,
            isApplicationSupport: isApp,
            managerEmail: editManagerEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            managerName: editManagerName.trimmingCharacters(in: .whitespacesAndNewlines),
            hotline: editHotline.trimmingCharacters(in: .whitespacesAndNewlines),
            location: editLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedRegionId: "",
            slaResponseMinutes: slaResp,
            slaResolveMinutes: slaRes,
            isActive: editIsActive,
            parentDepartmentId: "",
            colorHex: isHd ? "#0284C7" : (isInc ? "#7E22CE" : (isApp ? "#6D28D9" : (isWh ? "#B45309" : "#64748B"))),
            khuVucPhuTrach: []
        )

        isSaving = true
        Task {
            _ = await viewModel.saveDepartment(dept, isEdit: isEditingExisting)
            await MainActor.run {
                isSaving = false
                showEditDialog = false
            }
        }
    }

    private func refreshData() async {
        viewModel.fetchDepartments()
        viewModel.fetchUsers()
    }
}
