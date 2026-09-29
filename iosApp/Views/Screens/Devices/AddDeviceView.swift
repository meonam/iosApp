import SwiftUI

// MARK: - MÀN HÌNH THÊM THIẾT BỊ MỚI (ĐỒNG BỘ 1:1 VỚI ADDDEVICESCREEN.KT)
public struct AddDeviceView: View {
    @ObservedObject var viewModel: DeviceViewModel
    var initialDeviceId: String = ""
    var onBack: () -> Void
    var onNavigateToTypeManager: (() -> Void)? = nil
    var onSuccess: ((String) -> Void)? = nil

    @State private var id: String = ""
    @State private var ten: String = ""
    @State private var selectedLoaiThietBi: String = ""
    @State private var selectedStatus: String = DeviceStatusConstants.statusInStock

    // Loan details (Đang cho mượn)
    @State private var donViMuon: String = ""
    @State private var phongBanMuon: String = ""
    @State private var nguoiMuon: String = ""
    @State private var ngayHenTra: String = ""

    // Debounced ID validation
    @State private var isIdExisting: Bool = false
    @State private var isIdChecked: Bool = false
    @State private var checkTask: Task<Void, Never>? = nil

    // Scanner
    @State private var showScanner: Bool = false

    // State
    @State private var isSubmitting: Bool = false
    @State private var localMessage: String? = nil
    @State private var isSuccessMessage: Bool = false

    // Navigation to Type Manager
    @State private var showTypeManager: Bool = false
    @State private var showTypePickerSheet: Bool = false
    @State private var typeSearchText: String = ""

    public init(
        viewModel: DeviceViewModel,
        initialDeviceId: String = "",
        onBack: @escaping () -> Void,
        onNavigateToTypeManager: (() -> Void)? = nil,
        onSuccess: ((String) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.initialDeviceId = initialDeviceId
        self.onBack = onBack
        self.onNavigateToTypeManager = onNavigateToTypeManager
        self.onSuccess = onSuccess
    }

    public init(
        viewModel: DeviceViewModel,
        onDismiss: @escaping () -> Void,
        onSuccess: ((String) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.initialDeviceId = ""
        self.onBack = onDismiss
        self.onNavigateToTypeManager = nil
        self.onSuccess = onSuccess
    }

    private var userDonVi: String {
        let u = viewModel.user.unitId.trimmingCharacters(in: .whitespacesAndNewlines)
        return u.isEmpty ? "PCNTT" : u
    }

    private var userPhongBan: String {
        let p = viewModel.user.departmentId.trimmingCharacters(in: .whitespacesAndNewlines)
        return p.isEmpty ? "PCNTT" : p
    }

    private var canManageType: Bool {
        let role = viewModel.user.role.lowercased()
        return role == "admin" || role == "phongban" || role == "quanly"
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

                            Text("Thêm thiết bị mới")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            entryFormCard()

                            if let msg = localMessage {
                                Text(msg)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(isSuccessMessage ? Color(hex: "#16A34A") : Color.appPrimaryPink)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if id.isEmpty && !initialDeviceId.isEmpty {
                id = initialDeviceId
            }
            viewModel.loadDeviceTypes()
            viewModel.loadDepartmentsAndUnits()
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScanResult: { scannedCode in
                    self.id = scannedCode
                    self.showScanner = false
                    self.triggerIdCheck(scannedCode)
                },
                onDismiss: {
                    self.showScanner = false
                }
            )
        }
        .sheet(isPresented: $showTypeManager) {
            DeviceTypeManagerView(
                viewModel: viewModel,
                onBack: {
                    showTypeManager = false
                    viewModel.loadDeviceTypes()
                }
            )
        }
        .sheet(isPresented: $showTypePickerSheet) {
            typePickerSheetView
        }
    }

    // MARK: - TYPE PICKER BOTTOM SHEET
    private var typePickerSheetView: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color.appTextSecondary)
                    TextField("Tìm kiếm loại thiết bị...", text: $typeSearchText)
                        .font(.system(size: 14))
                    if !typeSearchText.isEmpty {
                        Button(action: { typeSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                List {
                    Button(action: {
                        selectedLoaiThietBi = ""
                        showTypePickerSheet = false
                    }) {
                        HStack {
                            Text("Chưa chọn / Để trống")
                                .font(.system(size: 14, weight: selectedLoaiThietBi.isEmpty ? .bold : .regular))
                                .foregroundColor(selectedLoaiThietBi.isEmpty ? Color.appPrimaryPink : Color.appTextSecondary)
                            Spacer()
                            if selectedLoaiThietBi.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                        }
                    }

                    let filteredTypes = viewModel.deviceTypes.filter { t in
                        typeSearchText.isEmpty || t.displayName.localizedCaseInsensitiveContains(typeSearchText)
                    }

                    ForEach(filteredTypes) { t in
                        Button(action: {
                            selectedLoaiThietBi = t.id
                            showTypePickerSheet = false
                        }) {
                            HStack {
                                Text(t.displayName)
                                    .font(.system(size: 14, weight: (selectedLoaiThietBi == t.id || selectedLoaiThietBi == t.name) ? .bold : .regular))
                                    .foregroundColor((selectedLoaiThietBi == t.id || selectedLoaiThietBi == t.name) ? Color.appPrimaryPink : Color.appTextPrimary)
                                Spacer()
                                if selectedLoaiThietBi == t.id || selectedLoaiThietBi == t.name {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.appPrimaryPink)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Chọn loại thiết bị")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if canManageType {
                        Button(action: {
                            showTypePickerSheet = false
                            if let onNav = onNavigateToTypeManager {
                                onNav()
                            } else {
                                showTypeManager = true
                            }
                        }) {
                            Text("+ Thêm loại")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        showTypePickerSheet = false
                    }
                    .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }

    // MARK: - FORM CARD
    @ViewBuilder
    private func entryFormCard() -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. SERIAL TEXTFIELD
            VStack(alignment: .leading, spacing: 4) {
                Text("Số serial / Mã tài sản *")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                HStack {
                    Image(systemName: "qrcode")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)

                    TextField("Nhập mã thiết bị (Serial)...", text: $id)
                        .font(.system(size: 14))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: id) { newVal in
                            triggerIdCheck(newVal)
                        }

                    Button(action: { showScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 18))
                            .foregroundColor(Color.appPrimaryPink)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                // Validation Status Indicator
                if !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isIdChecked {
                    if isIdExisting {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Mã thiết bị đã tồn tại trong hệ thống!")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color.appDanger)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Mã thiết bị hợp lệ (chưa tồn tại)")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "#16A34A"))
                        .padding(.leading, 4)
                        .padding(.top, 2)
                    }
                }
            }

            // 2. DEVICE NAME
            VStack(alignment: .leading, spacing: 4) {
                Text("Tên thiết bị *")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .frame(width: 20)

                    TextField("Ví dụ: Dell Latitude 5420, Màn hình Dell...", text: $ten)
                        .font(.system(size: 14))
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
            }

            // 3. DEVICE TYPE
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Loại thiết bị")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Spacer()

                    if canManageType {
                        Button(action: {
                            if let onNav = onNavigateToTypeManager {
                                onNav()
                            } else {
                                showTypeManager = true
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 11))
                                Text("Quản lý loại")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                }

                Button(action: { showTypePickerSheet = true }) {
                    HStack {
                        let currentDisplay = viewModel.deviceTypes.first(where: { $0.id == selectedLoaiThietBi || $0.name == selectedLoaiThietBi })?.displayName ?? (selectedLoaiThietBi.isEmpty ? "Chọn loại thiết bị..." : selectedLoaiThietBi)
                        Text(currentDisplay)
                            .font(.system(size: 14))
                            .foregroundColor(selectedLoaiThietBi.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            // 4. DEVICE STATUS DROPDOWN
            VStack(alignment: .leading, spacing: 4) {
                Text("Trạng thái thiết bị")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Menu {
                    ForEach(DeviceStatusConstants.allStatuses, id: \.self) { st in
                        Button(action: { selectedStatus = st }) {
                            Text(st)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedStatus)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(DeviceStatusConstants.color(for: selectedStatus))

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color.appTextSecondary)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }

            // 5. LOAN SECTION IF STATUS IS ON_LOAN
            if selectedStatus == DeviceStatusConstants.statusOnLoan {
                VStack(alignment: .leading, spacing: 10) {
                    Text("📋 Thông tin bên tiếp nhận mượn")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#7E22CE"))

                    // Đơn vị mượn
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Đơn vị mượn *")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#7E22CE"))

                        Menu {
                            ForEach(viewModel.units, id: \.self) { u in
                                Button(u) {
                                    donViMuon = u
                                    if let autoDept = viewModel.unitToDeptMap[u.lowercased()], !autoDept.isEmpty {
                                        phongBanMuon = autoDept
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(donViMuon.isEmpty ? "Chọn đơn vị mượn..." : donViMuon)
                                    .font(.system(size: 14))
                                    .foregroundColor(donViMuon.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                        }
                    }

                    // Phòng ban mượn
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phòng ban mượn")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#7E22CE"))

                        TextField("Nhập hoặc tự động gán phòng ban mượn...", text: $phongBanMuon)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))

                        if !donViMuon.isEmpty && !phongBanMuon.isEmpty {
                            Text("✓ Tự động gán theo phòng ban quản lý đơn vị")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#16A34A"))
                        }
                    }

                    // Người mượn
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Người mượn (Tên/SĐT)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#7E22CE"))

                        TextField("Nhập tên hoặc số điện thoại người mượn...", text: $nguoiMuon)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                    }

                    // Ngày hẹn trả
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ngày hẹn trả (dd/MM/yyyy)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#7E22CE"))

                        TextField("Ví dụ: 30/12/2026", text: $ngayHenTra)
                            .font(.system(size: 14))
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#C084FC"), lineWidth: 1))
                    }
                }
                .padding(12)
                .background(Color(hex: "#F3E8FF").opacity(0.6))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#C084FC"), lineWidth: 1))
            }

            Divider().padding(.vertical, 4)

            // 6. READ-ONLY UNIT & DEPARTMENT
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(Color.appPrimaryPink)
                    .font(.system(size: 16))
                Text("Đơn vị: ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
                Text(userDonVi)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
            }

            HStack {
                Image(systemName: "building.2.crop.circle.fill")
                    .foregroundColor(Color.appPrimaryPink)
                    .font(.system(size: 16))
                Text("Phòng quản lý: ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.appTextSecondary)
                Text(userPhongBan)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
            }

            // 7. SAVE BUTTON
            Button(action: saveDevice) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "square.and.arrow.down.fill")
                        Text("Lưu thiết bị")
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isIdExisting ? Color.gray : Color.appPrimaryPink)
                .cornerRadius(12)
            }
            .disabled(isSubmitting || isIdExisting)
            .padding(.top, 6)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - LOGIC
    private func triggerIdCheck(_ val: String) {
        checkTask?.cancel()
        let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            isIdExisting = false
            isIdChecked = false
            return
        }

        isIdExisting = false
        isIdChecked = false

        checkTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if Task.isCancelled { return }
            let exists = await viewModel.checkDeviceExists(trimmed)
            if !Task.isCancelled {
                self.isIdExisting = exists
                self.isIdChecked = true
            }
        }
    }

    private func saveDevice() {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTen = ten.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanId.isEmpty else {
            localMessage = "Vui lòng nhập Số serial / Mã tài sản!"
            isSuccessMessage = false
            return
        }
        guard !cleanTen.isEmpty else {
            localMessage = "Vui lòng nhập Tên thiết bị!"
            isSuccessMessage = false
            return
        }

        isSubmitting = true
        localMessage = nil

        viewModel.addDevice(
            id: cleanId,
            ten: cleanTen,
            donVi: userDonVi,
            phongBan: userPhongBan,
            loai: selectedLoaiThietBi,
            customStatus: selectedStatus,
            donViMuon: donViMuon.isEmpty ? nil : donViMuon,
            phongBanMuon: phongBanMuon.isEmpty ? nil : phongBanMuon,
            nguoiMuon: nguoiMuon.isEmpty ? nil : nguoiMuon,
            ngayHenTra: ngayHenTra.isEmpty ? nil : ngayHenTra
        ) { result in
            self.isSubmitting = false
            switch result {
            case .success(let savedId):
                self.localMessage = "Đã thêm thiết bị thành công"
                self.isSuccessMessage = true
                self.id = ""
                self.ten = ""
                self.donViMuon = ""
                self.phongBanMuon = ""
                self.nguoiMuon = ""
                self.ngayHenTra = ""
                self.selectedStatus = DeviceStatusConstants.statusInStock
                self.selectedLoaiThietBi = ""
                self.isIdChecked = false
                self.isIdExisting = false
                self.onSuccess?(savedId)
            case .failure(let err):
                self.localMessage = "Lỗi thêm thiết bị: \(err.localizedDescription)"
                self.isSuccessMessage = false
            }
        }
    }
}
