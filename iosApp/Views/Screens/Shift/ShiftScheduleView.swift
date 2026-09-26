import SwiftUI

// MARK: - MÀN HÌNH LỊCH CA TUẦN (ĐỒNG BỘ 1:1 VỚI SHIFTSCHEDULESCREEN.KT TRÊN ANDROID)
public struct ShiftScheduleView: View {
    @ObservedObject var viewModel: ShiftViewModel
    var onBack: () -> Void

    @State private var selectedCell: (empId: String, dayKey: String)? = nil
    @State private var showShiftPickerSheet: Bool = false

    public init(viewModel: ShiftViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private let dayHeaders = [
        ("mon", "T2"), ("tue", "T3"), ("wed", "T4"), ("thu", "T5"),
        ("fri", "T6"), ("sat", "T7"), ("sun", "CN")
    ]

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

                            Text("Lịch phân ca tuần")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // Nút refresh
                            Button(action: { viewModel.fetchShiftSchedule() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // 2. BỘ CHỌN TUẦN
                HStack {
                    Button(action: {
                        viewModel.currentWeekOffset -= 1
                        viewModel.fetchShiftSchedule()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Tuần: \(viewModel.currentWeekId)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        Text(viewModel.currentWeekOffset == 0 ? "Tuần hiện tại" : (viewModel.currentWeekOffset > 0 ? "Tuần tới (+1)" : "Tuần trước (-1)"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.appPrimaryPink)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.currentWeekOffset += 1
                        viewModel.fetchShiftSchedule()
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                }
                .padding(12)
                .background(Color.white)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .bottom)

                // 3. BẢNG PHÂN CA MA TRẬN
                if viewModel.isLoading {
                    ProgressView("Đang tải lịch phân ca...")
                        .padding(.top, 40)
                    Spacer()
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 1) {
                            // Hàng Header các Thứ
                            HStack(spacing: 1) {
                                Text("Nhân viên")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 120, height: 38)
                                    .background(Color.appSecondaryDarkBlue)

                                ForEach(dayHeaders, id: \.0) { _, label in
                                    Text(label)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 44, height: 38)
                                        .background(Color.appSecondaryDarkBlue)
                                }
                            }

                            // Dòng lịch ca từng người
                            if let entries = viewModel.currentWeekSchedule?.entries, !entries.isEmpty {
                                ForEach(entries) { entry in
                                    HStack(spacing: 1) {
                                        // Tên KTV
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.employeeName.isEmpty ? entry.employeeId : entry.employeeName)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color.appTextPrimary)
                                                .lineLimit(1)
                                            Text(entry.employeeId)
                                                .font(.system(size: 10))
                                                .foregroundColor(Color.appTextSecondary)
                                        }
                                        .padding(.horizontal, 6)
                                        .frame(width: 120, height: 42, alignment: .leading)
                                        .background(Color.white)

                                        // Các ngày T2 -> CN
                                        ForEach(dayHeaders, id: \.0) { key, _ in
                                            let code = entry.days[key] ?? ""
                                            Button(action: {
                                                if viewModel.user.isAdmin || viewModel.user.isSuperAdmin || viewModel.user.isManager {
                                                    selectedCell = (empId: entry.employeeId, dayKey: key)
                                                    showShiftPickerSheet = true
                                                }
                                            }) {
                                                Text(code.isEmpty ? "-" : code)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(colorForShift(code))
                                                    .frame(width: 44, height: 42)
                                                    .background(bgColorForShift(code))
                                            }
                                        }
                                    }
                                }
                            } else {
                                Text("Chưa có dữ liệu phân ca cho tuần này")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.appTextSecondary)
                                    .padding(20)
                            }
                        }
                        .padding(10)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            viewModel.fetchShiftSchedule()
        }
        .actionSheet(isPresented: $showShiftPickerSheet) {
            ActionSheet(
                title: Text("Chọn ca làm việc"),
                message: Text("Cập nhật ca trực cho nhân viên"),
                buttons: ShiftCode.allCodes.map { code in
                    .default(Text("\(code) - \(ShiftCode.label(for: code))")) {
                        if let cell = selectedCell {
                            viewModel.updateShiftCode(employeeId: cell.empId, dayKey: cell.dayKey, newCode: code)
                        }
                    }
                } + [.cancel()]
            )
        }
    }

    private func colorForShift(_ code: String) -> Color {
        switch code.uppercased() {
        case ShiftCode.sang: return .statusRepair
        case ShiftCode.chieu: return .statusOnLoan
        case ShiftCode.hanhChanh: return .statusInStock
        case ShiftCode.truc: return .appPrimaryPink
        case ShiftCode.nghiCa, ShiftCode.phep: return .statusLiquidated
        default: return .appTextPrimary
        }
    }

    private func bgColorForShift(_ code: String) -> Color {
        if code.isEmpty { return Color.white }
        return colorForShift(code).opacity(0.12)
    }
}
