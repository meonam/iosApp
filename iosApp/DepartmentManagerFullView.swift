import SwiftUI
import UIKit

// MARK: - MÀN HÌNH QUẢN LÝ PHÒNG BAN CHUYÊN SÂU (DepartmentManagerScreen.kt)
public struct DepartmentManagerFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var showAddSheet: Bool = false
    @State private var editingDepartment: DepartmentItem? = nil

    // Add / Edit Form State
    @State private var formDeptName: String = ""
    @State private var formDeptId: String = ""
    @State private var formManagerName: String = ""
    @State private var formManagerEmail: String = ""
    @State private var formHotline: String = ""
    @State private var formLocation: String = ""
    @State private var formSlaResponseMinutes: Int = 30
    @State private var formSlaResolveMinutes: Int = 240
    @State private var formIsHelpDesk: Bool = false
    @State private var formIsIncidentHandler: Bool = true
    @State private var formIsWarehouse: Bool = false
    @State private var isSaving: Bool = false
    @State private var alertMessage: String? = nil

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    var filteredDepartments: [DepartmentItem] {
        firebase.departmentsList.filter { d in
            searchText.isEmpty ||
            d.name.localizedCaseInsensitiveContains(searchText) ||
            d.managerName.localizedCaseInsensitiveContains(searchText) ||
            d.hotline.contains(searchText)
        }
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Tìm theo tên phòng ban, trưởng phòng...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(12)

                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredDepartments) { dept in
                            departmentCard(dept)
                        }
                    }
                    .padding(14)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Quản Lý Phòng Ban (\(firebase.departmentsList.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        resetForm()
                        showAddSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Thêm phòng")
                        }
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appSecondaryDarkBlue)
                }
            }
            .sheet(isPresented: $showAddSheet) {
                departmentFormSheet(isEdit: false)
            }
            .sheet(item: $editingDepartment) { _ in
                departmentFormSheet(isEdit: true)
            }
            .onAppear {
                Task { await firebase.fetchDepartments() }
            }
        }
    }

    @ViewBuilder
    private func departmentCard(_ dept: DepartmentItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dept.name)
                        .font(.system(size: 15.5, weight: .heavy))
                        .foregroundColor(.appTextPrimary)
                    if !dept.id.isEmpty {
                        Text("Mã PB: \(dept.id)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.appPrimaryPink)
                    }
                }
                Spacer()

                Button(action: {
                    editingDepartment = dept
                    loadDeptToForm(dept)
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.appSecondaryDarkBlue)
                }
            }

            Divider()

            // Info rows
            VStack(spacing: 6) {
                infoRow(icon: "person.badge.shield.checkmark.fill", label: "Trưởng phòng:", value: dept.managerName.isEmpty ? "Chưa bổ nhiệm" : dept.managerName)
                if !dept.hotline.isEmpty {
                    infoRow(icon: "phone.circle.fill", label: "Hotline:", value: dept.hotline)
                }
                if !dept.description.isEmpty {
                    infoRow(icon: "info.circle.fill", label: "Mô tả / Vị trí:", value: dept.description)
                }
            }

            // SLA Badges
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("SLA Phản hồi: 30p")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12))
                .foregroundColor(.orange)
                .clipShape(Capsule())

                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text("SLA Xử lý: 240p (4h)")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.12))
                .foregroundColor(.green)
                .clipShape(Capsule())

                Spacer()
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.appTextPrimary)
        }
    }

    @ViewBuilder
    private func departmentFormSheet(isEdit: Bool) -> some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN PHÒNG BAN (*)")) {
                    TextField("Tên phòng ban (VD: Phòng CNTT & CĐS)", text: $formDeptName)
                    TextField("Mã định danh (VD: DEPT_IT)", text: $formDeptId)
                        .disabled(isEdit)
                    TextField("Họ tên Trưởng phòng", text: $formManagerName)
                    TextField("Số điện thoại Hotline", text: $formHotline)
                        .keyboardType(.phonePad)
                    TextField("Vị trí làm việc / Mô tả", text: $formLocation)
                }

                Section(header: Text("CAM KẾT THỜI GIAN XỬ LÝ SỰ CỐ (SLA)")) {
                    Stepper(value: $formSlaResponseMinutes, in: 5...120, step: 5) {
                        HStack {
                            Text("SLA Tiếp nhận & Phản hồi:")
                            Spacer()
                            Text("\(formSlaResponseMinutes) phút")
                                .bold().foregroundColor(.orange)
                        }
                    }

                    Stepper(value: $formSlaResolveMinutes, in: 30...1440, step: 30) {
                        HStack {
                            Text("SLA Cam kết Xong (Resolve):")
                            Spacer()
                            Text("\(formSlaResolveMinutes) phút (\(formSlaResolveMinutes / 60)h)")
                                .bold().foregroundColor(.green)
                        }
                    }
                }

                Section(header: Text("PHÂN LOẠI NGHIỆP VỤ SAIGON CO.OP")) {
                    Toggle("Là đơn vị tiếp nhận sự cố (HelpDesk)", isOn: $formIsHelpDesk)
                    Toggle("Là đội kỹ thuật xử lý tại chỗ", isOn: $formIsIncidentHandler)
                    Toggle("Là kho tổng phân phối thiết bị", isOn: $formIsWarehouse)
                }

                Section {
                    Button(action: saveDepartment) {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(isEdit ? "LƯU THAY ĐỔI" : "TẠO PHÒNG BAN MỚI")
                                    .font(.headline.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 46)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(12)
                    .disabled(isSaving || formDeptName.isEmpty)
                }
            }
            .navigationTitle(isEdit ? "Sửa Phòng Ban" : "Thêm Phòng Ban")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        showAddSheet = false
                        editingDepartment = nil
                    }
                }
            }
        }
    }

    private func resetForm() {
        formDeptName = ""
        formDeptId = ""
        formManagerName = ""
        formManagerEmail = ""
        formHotline = ""
        formLocation = ""
        formSlaResponseMinutes = 30
        formSlaResolveMinutes = 240
        formIsHelpDesk = false
        formIsIncidentHandler = true
        formIsWarehouse = false
    }

    private func loadDeptToForm(_ d: DepartmentItem) {
        formDeptName = d.name
        formDeptId = d.id
        formManagerName = d.managerName
        formHotline = d.hotline
        formLocation = d.description
    }

    private func saveDepartment() {
        isSaving = true
        let cleanId = formDeptId.isEmpty ? "DEPT_\(UUID().uuidString.prefix(6).uppercased())" : formDeptId
        Task {
            let ok = await firebase.saveDepartment(
                id: cleanId,
                name: formDeptName,
                manager: formManagerName,
                hotline: formHotline,
                desc: formLocation
            )
            isSaving = false
            if ok {
                await firebase.fetchDepartments()
                showAddSheet = false
                editingDepartment = nil
            }
        }
    }
}
