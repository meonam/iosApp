import SwiftUI
import UIKit

// MARK: - MÀN HÌNH PHÂN CA TRỰC KTV (ĐỒNG BỘ 1:1 THEO SHIFTSCHEDULESCREEN.KT TRÊN ANDROID)
public struct ShiftScheduleView: View {
    @ObservedObject var viewModel: ShiftViewModel
    var onBack: () -> Void

    // Dialog & Sheet States
    @State private var selectedCell: (employeeId: String, employeeName: String, dayKey: String, dayTitle: String, currentCode: String)? = nil
    @State private var showingEditSheet: Bool = false
    @State private var showingAddKtvSheet: Bool = false
    @State private var showingQuickAssignSheet: Bool = false
    @State private var showingConfirmCopyAlert: Bool = false
    @State private var ktvToDelete: ShiftEntry? = nil
    @State private var showingShareSheet: Bool = false
    @State private var shareText: String = ""

    // Quick Assign States
    @State private var quickAssignTargetId: String = "ALL" // "ALL" or employeeId
    @State private var quickAssignShiftCode: String = "S"
    @State private var quickAssignSelectedDays: Set<String> = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    // Add KTV States
    @State private var newMnv: String = ""
    @State private var newName: String = ""
    @State private var newKhuVuc: String = ""

    struct DaySelectionItem: Identifiable, Hashable {
        let key: String
        let name: String
        var id: String { key }
    }

    private let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    private let dayNames = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
    private let dayItems: [DaySelectionItem] = [
        DaySelectionItem(key: "mon", name: "T2"),
        DaySelectionItem(key: "tue", name: "T3"),
        DaySelectionItem(key: "wed", name: "T4"),
        DaySelectionItem(key: "thu", name: "T5"),
        DaySelectionItem(key: "fri", name: "T6"),
        DaySelectionItem(key: "sat", name: "T7"),
        DaySelectionItem(key: "sun", name: "CN")
    ]

    public init(viewModel: ShiftViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    // Màu mã ca làm việc chuẩn 1:1 theo Android
    private func shiftColor(for code: String) -> Color {
        switch code.uppercased() {
        case "S": return Color(hex: "#1565C0")        // Sáng - Blue
        case "C": return Color(hex: "#E65100")        // Chiều - Orange
        case "HC": return Color(hex: "#00695C")       // Hành chính - Teal
        case "TR": return Color(hex: "#C62828")       // Trực - Red
        case "NC": return Color(hex: "#757575")       // Nghỉ ca - Gray
        case "P": return Color(hex: "#2E7D32")        // Phép - Green
        case "NL": return Color(hex: "#AD1457")       // Nghỉ lễ - Deep Pink
        case "NM": return Color(hex: "#00838F")       // Nghỉ mát - Cyan
        case "CT": return Color(hex: "#6A1B9A")       // Công tác - Purple
        case "H": return Color(hex: "#F9A825")        // Họp - Amber
        default: return Color(hex: "#90A4AE")
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR CHUẨN ANDROID (XANH ĐẬM #002A8F)
                    topBarView(safeAreaTop: SafeAreaHelper.top(geometry))

                    if !viewModel.canAccessSchedule {
                        restrictedAccessView
                    } else {
                        // 2. THANH ĐIỀU HƯỚNG TUẦN (WEEK NAVIGATION BAR)
                        weekNavigationBar

                        // 3. DẢI MÃ CA CHÚ THÍCH (SHIFT LEGEND ROW)
                        shiftLegendRow
                        Divider().background(Color(hex: "#E2E8F0"))

                        // 4. THANH CÔNG CỤ QUẢN LÝ CA (ACTION TOOLBAR)
                        if viewModel.canEditShift {
                            editorToolbar
                        } else {
                            readOnlyBanner
                        }

                        // 5. BẢNG PHÂN CA MA TRẬN (MAIN SCHEDULE MATRIX GRID)
                        if viewModel.isLoading && (viewModel.currentWeekSchedule?.entries.isEmpty ?? true) {
                            Spacer()
                            ProgressView("Đang tải dữ liệu phân ca...")
                                .tint(Color.appPrimaryPink)
                            Spacer()
                        } else {
                            scheduleMatrixGrid
                        }
                    }
                }

                // Toast thông báo thành công hoặc lỗi
                if let success = viewModel.successMessage {
                    toastBanner(text: success, isError: false)
                } else if let error = viewModel.errorMessage {
                    toastBanner(text: error, isError: true)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchShiftSchedule()
        }
        // Sheet sửa ca của 1 ô
        .sheet(isPresented: $showingEditSheet) {
            if let cell = selectedCell {
                editShiftCellSheet(cell: cell)
            }
        }
        // Sheet thêm KTV mới
        .sheet(isPresented: $showingAddKtvSheet) {
            addKtvSheetView
        }
        // Sheet gán ca nhanh
        .sheet(isPresented: $showingQuickAssignSheet) {
            quickAssignSheetView
        }
        // Sheet chia sẻ / xuất Excel/CSV
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(activityItems: [shareText])
        }
        // Alert xác nhận sao chép tuần trước
        .alert("Sao chép phân ca tuần trước?", isPresented: $showingConfirmCopyAlert) {
            Button("Hủy", role: .cancel) { }
            Button("Sao chép", role: .destructive) {
                Task {
                    await viewModel.copyPreviousWeekSchedule()
                }
            }
        } message: {
            Text("Toàn bộ phân ca của tuần trước sẽ được áp dụng cho tuần này. Bạn có chắc chắn muốn tiếp tục?")
        }
        // Alert xác nhận xóa KTV khỏi tuần
        .alert(item: $ktvToDelete) { entry in
            Alert(
                title: Text("Xóa nhân sự khỏi lịch tuần?"),
                message: Text("Bạn có chắc chắn muốn xóa \(entry.employeeName) (\(entry.employeeId)) khỏi bảng phân ca tuần này?"),
                primaryButton: .destructive(Text("Xóa")) {
                    viewModel.deleteEmployee(employeeId: entry.employeeId)
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }

    // MARK: - TOP BAR
    private func topBarView(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("Phân Ca Trực KTV")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Nút Lưu phân ca (chỉ hiển thị khi có quyền sửa)
                if viewModel.canEditShift {
                    Button(action: {
                        Task {
                            await viewModel.saveSchedule()
                        }
                    }) {
                        if viewModel.isSaving {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 19))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .disabled(viewModel.isSaving || viewModel.isLoading)
                } else {
                    // Badge "Chỉ xem"
                    Text("Chỉ xem")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#FEF3C7"))
                        .cornerRadius(6)
                }

                // Nút Xuất CSV / Chia sẻ
                Button(action: {
                    self.shareText = viewModel.exportCsvString()
                    self.showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - 2. WEEK NAVIGATION BAR
    private var weekNavigationBar: some View {
        HStack(spacing: 8) {
            // Nút Tuần trước
            Button(action: {
                viewModel.currentWeekOffset -= 1
                viewModel.fetchShiftSchedule()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .bold))
                    Text("Tuần trước")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color.appSecondaryDarkBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appSecondaryDarkBlue.opacity(0.4), lineWidth: 1))
            }

            Spacer()

            // Thông tin tuần hiện tại
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Tuần \(String(format: "%02d", viewModel.currentWeekNumber))")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color(hex: "#0F172A"))
                }

                if !viewModel.weekDateRangeLabel.isEmpty {
                    Text(viewModel.weekDateRangeLabel)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }
            }

            Spacer()

            // Nút Tuần sau
            Button(action: {
                viewModel.currentWeekOffset += 1
                viewModel.fetchShiftSchedule()
            }) {
                HStack(spacing: 4) {
                    Text("Tuần sau")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color.appSecondaryDarkBlue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appSecondaryDarkBlue.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: "#F8FAFC"))
        .border(Color(hex: "#E2E8F0"), width: 0.5)
    }

    // MARK: - 3. SHIFT LEGEND ROW
    private var shiftLegendRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShiftCode.allCodes, id: \.self) { code in
                    HStack(spacing: 4) {
                        Text(code)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(shiftColor(for: code))
                            .cornerRadius(4)

                        Text(ShiftCode.label(code))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#334155"))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color.white)
    }

    // MARK: - 4. EDITOR TOOLBAR
    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Nút Đồng bộ KTV
                Button(action: {
                    Task {
                        await viewModel.syncKtvUsers()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))
                        Text("Đồng Bộ KTV")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appSecondaryDarkBlue, lineWidth: 1))
                }

                // Nút Thêm KTV
                Button(action: { showingAddKtvSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("+ Thêm KTV")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(6)
                }

                // Nút Gán ca nhanh
                Button(action: { showingQuickAssignSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                        Text("⚡ Gán ca nhanh")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#D97706"))
                    .cornerRadius(6)
                }

                // Nút Sao chép tuần trước
                Button(action: { showingConfirmCopyAlert = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11.5))
                        Text("Sao chép tuần trước")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.appSecondaryDarkBlue, lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(hex: "#F1F5F9"))
    }

    private var readOnlyBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#D97706"))

            Text("Chế độ chỉ xem. Chỉ Quản trị viên (Admin) và HelpDesk mới có quyền phân ca trực.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Color(hex: "#92400E"))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(hex: "#FFFBEB"))
        .cornerRadius(6)
        .padding(8)
    }

    // MARK: - 5. SCHEDULE MATRIX GRID
    private var scheduleMatrixGrid: some View {
        let entries = viewModel.currentWeekSchedule?.entries ?? []
        let labels = viewModel.dateLabels

        return ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // HEADER ROW
                HStack(spacing: 0) {
                    headerCell("MNV", width: 72)
                    headerCell("Tên KTV", width: 145)
                    headerCell("Cụm", width: 85)

                    ForEach(0..<dayKeys.count, id: \.self) { idx in
                        let dateStr = labels.indices.contains(idx) ? labels[idx] : ""
                        headerCell("\(dayNames[idx])\n\(dateStr)", width: 68)
                    }

                    if viewModel.canEditShift {
                        headerCell("Xóa", width: 44)
                    }
                }
                .background(Color.appSecondaryDarkBlue)

                // DATA ROWS
                if entries.isEmpty {
                    Text("Chưa có nhân viên nào trong danh sách. Nhấn '+ Thêm KTV' hoặc 'Đồng Bộ KTV' để bắt đầu.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .padding(24)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.employeeId) { idx, entry in
                        let isSelf = entry.employeeName.lowercased() == viewModel.user.fullName.lowercased() ||
                                     entry.employeeId.lowercased() == viewModel.user.email.lowercased()
                        let rowBg = isSelf ? Color(hex: "#FFF9C4") : (idx % 2 == 0 ? Color.white : Color(hex: "#F8FAFC"))

                        HStack(spacing: 0) {
                            // MNV
                            Text(entry.employeeId)
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(Color(hex: "#1E293B"))
                                .frame(width: 72, height: 46, alignment: .center)
                                .border(Color(hex: "#E2E8F0"), width: 0.5)

                            // Tên KTV
                            Text(entry.employeeName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#0F172A"))
                                .lineLimit(1)
                                .frame(width: 145, height: 46, alignment: .leading)
                                .padding(.horizontal, 6)
                                .border(Color(hex: "#E2E8F0"), width: 0.5)

                            // Cụm / Khu vực
                            BoxView(width: 85, height: 46) {
                                Text(entry.maKhuVuc.isEmpty ? "Chưa gán" : "Cụm \(entry.maKhuVuc)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(entry.maKhuVuc.isEmpty ? .gray : Color(hex: "#0369A1"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(entry.maKhuVuc.isEmpty ? Color(hex: "#F1F5F9") : Color(hex: "#E0F2FE"))
                                    .cornerRadius(4)
                            }
                            .border(Color(hex: "#E2E8F0"), width: 0.5)

                            // 7 Ngày trong tuần
                            ForEach(0..<dayKeys.count, id: \.self) { dIdx in
                                let key = dayKeys[dIdx]
                                let code = entry.days[key] ?? ""

                                shiftCell(
                                    code: code,
                                    width: 68,
                                    height: 46,
                                    isEditable: viewModel.canEditShift
                                ) {
                                    if viewModel.canEditShift {
                                        let title = "\(dayNames[dIdx]) (\(labels.indices.contains(dIdx) ? labels[dIdx] : ""))"
                                        self.selectedCell = (entry.employeeId, entry.employeeName, key, title, code)
                                        self.showingEditSheet = true
                                    }
                                }
                                .border(Color(hex: "#E2E8F0"), width: 0.5)
                            }

                            // Nút xóa (chỉ Admin)
                            if viewModel.canEditShift {
                                BoxView(width: 44, height: 46) {
                                    Button(action: {
                                        self.ktvToDelete = entry
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(hex: "#EF4444"))
                                    }
                                }
                                .border(Color(hex: "#E2E8F0"), width: 0.5)
                            }
                        }
                        .background(rowBg)
                    }
                }
            }
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .frame(width: width, height: 44, alignment: .center)
            .border(Color.white.opacity(0.2), width: 0.5)
    }

    private func shiftCell(code: String, width: CGFloat, height: CGFloat, isEditable: Bool, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            ZStack {
                if code.isEmpty {
                    Text("-")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#94A3B8"))
                } else {
                    Text(code)
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(shiftColor(for: code))
                        .cornerRadius(6)
                }
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
        }
        .disabled(!isEditable)
    }

    // MARK: - SHEET: SỬA CA LÀM VIỆC CỦA 1 Ô
    private func editShiftCellSheet(cell: (employeeId: String, employeeName: String, dayKey: String, dayTitle: String, currentCode: String)) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Chọn Ca Trực")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("\(cell.employeeName) • \(cell.dayTitle)")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: { showingEditSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            Divider()

            // Nút Xóa ca ngày này
            Button(action: {
                viewModel.updateShiftCode(employeeId: cell.employeeId, dayKey: cell.dayKey, newCode: "")
                showingEditSheet = false
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("— Xóa phân ca ngày này —")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
            }
            .padding(.horizontal, 20)

            // Danh sách các mã ca chuẩn
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(ShiftCode.allCodes, id: \.self) { code in
                        let isSelected = code == cell.currentCode
                        Button(action: {
                            viewModel.updateShiftCode(employeeId: cell.employeeId, dayKey: cell.dayKey, newCode: code)
                            showingEditSheet = false
                        }) {
                            HStack(spacing: 12) {
                                Text(code)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 32)
                                    .background(shiftColor(for: code))
                                    .cornerRadius(6)

                                Text(ShiftCode.label(code))
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? Color.appSecondaryDarkBlue : Color(hex: "#1E293B"))

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(isSelected ? Color(hex: "#EFF6FF") : Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.appSecondaryDarkBlue : Color(hex: "#E2E8F0"), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - SHEET: THÊM KTV MỚI
    private var addKtvSheetView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Thêm Kỹ Thuật Viên")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Button(action: { showingAddKtvSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mã nhân viên (MNV):")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("VD: 26063 hoặc NV01", text: $newMnv)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Họ và tên KTV:")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("VD: Nguyễn Văn A", text: $newName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cụm / Khu vực phụ trách:")
                        .font(.system(size: 13, weight: .semibold))
                    TextField("VD: HCM_1 hoặc BD", text: $newKhuVuc)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Spacer()

                Button(action: {
                    viewModel.addEmployee(employeeId: newMnv, employeeName: newName, maKhuVuc: newKhuVuc)
                    newMnv = ""
                    newName = ""
                    newKhuVuc = ""
                    showingAddKtvSheet = false
                }) {
                    Text("Thêm Vào Phân Ca")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(newName.isEmpty ? Color.gray : Color.appSecondaryDarkBlue)
                        .cornerRadius(10)
                }
                .disabled(newName.isEmpty)
            }
            .padding(20)
        }
    }

    // MARK: - SHEET: GÁN CA NHANH (QUICK ASSIGN)
    private var quickAssignSheetView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("⚡ Gán Ca Nhanh Hàng Loạt")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Button(action: { showingQuickAssignSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Chọn nhân viên
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Áp dụng cho nhân viên:")
                            .font(.system(size: 13, weight: .semibold))

                        Picker("Nhân viên", selection: $quickAssignTargetId) {
                            Text("Tất cả nhân viên").tag("ALL")
                            ForEach(viewModel.currentWeekSchedule?.entries ?? [], id: \.employeeId) { e in
                                Text("\(e.employeeName) (\(e.employeeId))").tag(e.employeeId)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                    }

                    // Chọn mã ca
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mã ca làm việc:")
                            .font(.system(size: 13, weight: .semibold))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(ShiftCode.allCodes, id: \.self) { code in
                                    let isSel = quickAssignShiftCode == code
                                    Button(action: { quickAssignShiftCode = code }) {
                                        VStack(spacing: 2) {
                                            Text(code)
                                                .font(.system(size: 13, weight: .black))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(shiftColor(for: code))
                                                .cornerRadius(4)
                                            Text(ShiftCode.label(code))
                                                .font(.system(size: 10))
                                                .foregroundColor(isSel ? Color.appSecondaryDarkBlue : .gray)
                                        }
                                        .padding(6)
                                        .background(isSel ? Color(hex: "#EFF6FF") : Color.white)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSel ? Color.appSecondaryDarkBlue : Color(hex: "#E2E8F0"), lineWidth: 1.5))
                                    }
                                }
                            }
                        }
                    }

                    // Chọn ngày áp dụng
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Các ngày trong tuần:")
                            .font(.system(size: 13, weight: .semibold))

                        HStack(spacing: 8) {
                            ForEach(dayItems) { day in
                                dayToggleButton(day: day)
                            }
                        }
                    }

                    Button(action: {
                        let target = quickAssignTargetId == "ALL" ? nil : quickAssignTargetId
                        viewModel.quickAssign(
                            targetEmployeeId: target,
                            shiftCode: quickAssignShiftCode,
                            days: Array(quickAssignSelectedDays)
                        )
                        showingQuickAssignSheet = false
                    }) {
                        Text("Áp Dụng Phân Ca")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#D97706"))
                            .cornerRadius(10)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func dayToggleButton(day: DaySelectionItem) -> some View {
        let isSel = quickAssignSelectedDays.contains(day.key)
        Button(action: {
            if isSel {
                quickAssignSelectedDays.remove(day.key)
            } else {
                quickAssignSelectedDays.insert(day.key)
            }
        }) {
            Text(day.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSel ? .white : Color(hex: "#475569"))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(isSel ? Color.appSecondaryDarkBlue : Color(hex: "#F1F5F9"))
                .cornerRadius(8)
        }
    }

    // MARK: - RESTRICTED ACCESS VIEW
    private var restrictedAccessView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 54))
                .foregroundColor(Color(hex: "#EF4444"))

            Text("Truy Cập Bị Giới Hạn")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#1E293B"))

            Text("Chức năng Lịch trực & Phân ca kỹ thuật chỉ dành cho Kỹ thuật viên, Chuyên viên và Ban quản lý. Người dùng thông thường không có quyền truy cập.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onBack) {
                Text("Quay lại")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    // MARK: - TOAST BANNER
    private func toastBanner(text: String, isError: Bool) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(.white)
                Text(text)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isError ? Color.red : Color(hex: "#10B981"))
            .cornerRadius(8)
            .shadow(radius: 4)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                viewModel.successMessage = nil
                viewModel.errorMessage = nil
            }
        }
    }
}

// Helper container
private struct BoxView<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let content: () -> Content

    init(width: CGFloat, height: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.width = width
        self.height = height
        self.content = content
    }

    var body: some View {
        ZStack {
            content()
        }
        .frame(width: width, height: height)
    }
}

// Share Sheet Helper
private struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
