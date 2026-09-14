import SwiftUI
import UIKit

// MARK: - MÀN HÌNH DUYỆT NHÂN VIÊN MỚI (Khớp 100% Android ApproveStaffScreen.kt)
public struct ApproveStaffFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @State private var selectedStaffForAction: PendingStaffItem? = nil
    @State private var showRejectDialog: Bool = false
    @State private var staffToReject: PendingStaffItem? = nil

    // Form Approval State
    @State private var selectedRole: String = "nhanvien"
    @State private var selectedUnit: String = "Co.opmart Cần Thơ"
    @State private var selectedDept: String = "Phòng Công nghệ thông tin"
    @State private var isProcessing: Bool = false
    @State private var alertMessage: String? = nil

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var pendingItems: [PendingStaffItem] {
        if !firebase.pendingStaffList.isEmpty {
            return firebase.pendingStaffList
        }
        // Fallback to allUsersList with PENDING status
        return firebase.allUsersList.filter { $0.status == "PENDING" }.map { u in
            PendingStaffItem(
                email: u.email,
                fullName: u.fullName,
                phone: u.phone,
                maNhanVien: u.maNhanVien,
                companyId: u.companyId,
                departmentId: u.departmentId,
                unitId: u.donVi,
                donVi: u.donVi,
                phongBan: u.departmentId,
                createdAt: u.createdAt
            )
        }
    }

    var filteredList: [PendingStaffItem] {
        pendingItems.filter { p in
            searchQuery.isEmpty ||
            p.fullName.localizedCaseInsensitiveContains(searchQuery) ||
            p.email.localizedCaseInsensitiveContains(searchQuery) ||
            p.phone.contains(searchQuery) ||
            p.donVi.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Tìm theo tên, email, SĐT, đơn vị...", text: $searchQuery)
                        .font(.system(size: 14))
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(12)

                if filteredList.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredList) { staff in
                                pendingCard(staff)
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Duyệt Nhân Viên (\(pendingItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .sheet(item: $selectedStaffForAction) { staff in
                approvalSheet(for: staff)
            }
            .alert(isPresented: $showRejectDialog) {
                Alert(
                    title: Text("Từ chối gia nhập?"),
                    message: Text("Bạn có chắc muốn từ chối yêu cầu từ \(staffToReject?.fullName ?? "nhân viên này")?"),
                    primaryButton: .destructive(Text("Từ chối")) {
                        if let staff = staffToReject {
                            executeReject(staff: staff)
                        }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
            .onAppear {
                Task {
                    await firebase.fetchPendingStaff()
                    await firebase.fetchAllUsers()
                    await firebase.fetchDepartments()
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.statusInUse.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 40))
                    .foregroundColor(.statusInUse)
            }
            Text("Không Có Yêu Cầu Chờ Duyệt")
                .font(.headline.bold())
                .foregroundColor(.appSecondaryDarkBlue)
            Text("Tất cả nhân sự đăng ký gia nhập đã được Quản trị viên phê duyệt hoàn tất.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Card Pending Staff
    @ViewBuilder
    private func pendingCard(_ staff: PendingStaffItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appSecondaryDarkBlue.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Text(staff.fullName.prefix(2).uppercased())
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.appSecondaryDarkBlue)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(staff.fullName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.appTextPrimary)
                    Text(staff.email)
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("CHỜ DUYỆT")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            Divider()

            VStack(spacing: 6) {
                if !staff.phone.isEmpty {
                    infoRow(icon: "phone.fill", label: "Điện thoại:", value: staff.phone)
                }
                if !staff.maNhanVien.isEmpty {
                    infoRow(icon: "number.square.fill", label: "Mã nhân viên:", value: staff.maNhanVien)
                }
                infoRow(icon: "building.2.fill", label: "Đơn vị đăng ký:", value: staff.donVi.isEmpty ? "Co.opmart" : staff.donVi)
                if !staff.phongBan.isEmpty {
                    infoRow(icon: "person.2.fill", label: "Phòng ban:", value: staff.phongBan)
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: {
                    staffToReject = staff
                    showRejectDialog = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text("Từ chối")
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }

                Button(action: {
                    selectedStaffForAction = staff
                    selectedUnit = staff.donVi.isEmpty ? "Co.opmart Cần Thơ" : staff.donVi
                    selectedDept = staff.phongBan.isEmpty ? "Phòng Công nghệ thông tin" : staff.phongBan
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Phê duyệt...")
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.appSecondaryDarkBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.appTextPrimary)
        }
    }

    // MARK: - Sheet Approval
    @ViewBuilder
    private func approvalSheet(for staff: PendingStaffItem) -> some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN ỨNG VIÊN")) {
                    HStack {
                        Text("Họ và tên")
                        Spacer()
                        Text(staff.fullName).bold()
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(staff.email).foregroundColor(.secondary)
                    }
                    if !staff.phone.isEmpty {
                        HStack {
                            Text("Số điện thoại")
                            Spacer()
                            Text(staff.phone)
                        }
                    }
                }

                Section(header: Text("PHÂN VAI TRÒ & PHÒNG BAN")) {
                    Picker("Vai trò hệ thống", selection: $selectedRole) {
                        Text("Nhân viên nghiệp vụ").tag("nhanvien")
                        Text("Kỹ thuật viên (KTV)").tag("ktv")
                        Text("HelpDesk").tag("helpdesk")
                        Text("Quản lý phòng ban").tag("quanly")
                        Text("Quản trị viên (Admin)").tag("admin")
                    }

                    Picker("Đơn vị Co.opmart", selection: $selectedUnit) {
                        ForEach(CoopmartDirectory.stores.prefix(30)) { s in
                            Text(s.name).tag(s.name)
                        }
                    }

                    Picker("Phòng ban", selection: $selectedDept) {
                        if firebase.departmentsList.isEmpty {
                            Text("Phòng Công nghệ thông tin").tag("Phòng Công nghệ thông tin")
                            Text("Phòng Vận hành & Kỹ thuật").tag("Phòng Vận hành & Kỹ thuật")
                            Text("Phòng Dịch vụ khách hàng").tag("Phòng Dịch vụ khách hàng")
                            Text("Ban Giám Đốc").tag("Ban Giám Đốc")
                        } else {
                            ForEach(firebase.departmentsList) { d in
                                Text(d.name).tag(d.name)
                            }
                        }
                    }
                }

                if let msg = alertMessage {
                    Section {
                        Text(msg)
                            .font(.caption.bold())
                            .foregroundColor(msg.contains("✅") ? .green : .red)
                    }
                }

                Section {
                    Button(action: {
                        executeApprove(staff: staff)
                    }) {
                        HStack {
                            Spacer()
                            if isProcessing {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Xác Nhận Phê Duyệt")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(isProcessing)
                    .foregroundColor(.white)
                    .listRowBackground(Color.appSecondaryDarkBlue)
                }
            }
            .navigationTitle("Phê Duyệt Nhân Viên")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        selectedStaffForAction = nil
                    }
                }
            }
        }
    }

    private func executeApprove(staff: PendingStaffItem) {
        isProcessing = true
        Task {
            let ok = await firebase.approveUser(
                email: staff.email,
                role: selectedRole,
                unitId: selectedUnit,
                unitName: selectedUnit,
                deptId: selectedDept
            )
            isProcessing = false
            if ok {
                alertMessage = "✅ Đã phê duyệt nhân viên [\(staff.fullName)] thành công!"
                await firebase.fetchPendingStaff()
                await firebase.fetchAllUsers()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    selectedStaffForAction = nil
                    alertMessage = nil
                }
            } else {
                alertMessage = "❌ Lỗi khi phê duyệt trên máy chủ."
            }
        }
    }

    private func executeReject(staff: PendingStaffItem) {
        Task {
            let ok = await firebase.rejectUser(email: staff.email)
            if ok {
                await firebase.fetchPendingStaff()
                await firebase.fetchAllUsers()
            }
        }
    }
}
