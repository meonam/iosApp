import SwiftUI
import Foundation

// MARK: - MATERIAL OUTLINED TEXT FIELD (MATCHING ANDROID OUTLINEDTEXTFIELD)
struct MaterialOutlinedField: View {
    var label: String
    var leadingIconSystem: String? = nil
    var leadingIconColor: Color = .gray
    var trailingText: String? = nil
    var trailingIconSystem: String? = nil
    var trailingAction: (() -> Void)? = nil
    var keyboardType: UIKeyboardType = .default
    @Binding var text: String
    var placeholder: String = ""
    var isEnabled: Bool = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Outlined Border Container
            HStack(spacing: 8) {
                if let sys = leadingIconSystem {
                    Image(systemName: sys)
                        .font(.system(size: 15))
                        .foregroundColor(leadingIconColor)
                        .frame(width: 18)
                }

                TextField(placeholder, text: $text)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(isEnabled ? Color(hex: "#1E293B") : Color.gray)
                    .keyboardType(keyboardType)
                    .disabled(!isEnabled)

                if let trailingIcon = trailingIconSystem, let action = trailingAction {
                    Button(action: action) {
                        Image(systemName: trailingIcon)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#64748B"))
                    }
                } else if let trText = trailingText {
                    Text(trText)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(hex: "#64748B"))
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 48)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#CBD5E1"), lineWidth: 1)
            )
            .padding(.top, 7)

            // Floating Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#64748B"))
                .padding(.horizontal, 4)
                .background(Color.white)
                .padding(.leading, 10)
        }
    }
}

// MARK: - MATERIAL SUGGESTION CHIP (MATCHING ANDROID SUGGESTIONCHIP)
struct MaterialSuggestionChip: View {
    var label: String
    var isSelected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? Color(hex: "#1D4ED8") : Color(hex: "#334155"))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(isSelected ? Color(hex: "#EFF6FF") : Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color(hex: "#2563EB") : Color(hex: "#CBD5E1"), lineWidth: isSelected ? 1.2 : 0.8)
                )
        }
    }
}

// MARK: - ATTENDANCE & EXPENSE REPORT VIEW (ĐỒNG BỘ 1:1 VỚI ANDROID ATTENDANCEREPORTSCREEN.KT & SCREENSHOTS)
public struct AttendanceReportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    @StateObject private var viewModel: AttendanceViewModel

    @State private var showGuideDialog: Bool = false
    @State private var showExportDialog: Bool = false
    @State private var rejectTripTarget: TravelExpenseRecord? = nil
    @State private var rejectReasonInput: String = ""
    @State private var showRejectDialog: Bool = false

    private let monthsList: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        var list: [String] = []
        let sdf = DateFormatter()
        sdf.locale = Locale(identifier: "en_US_POSIX")
        sdf.calendar = Calendar(identifier: .gregorian)
        sdf.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .current
        sdf.dateFormat = "yyyy-MM"
        var cur = Date()
        for _ in 0..<12 {
            list.append(sdf.string(from: cur))
            if let prev = cal.date(byAdding: .month, value: -1, to: cur) {
                cur = prev
            }
        }
        return list
    }()

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
        let user = authViewModel.currentUser ?? User(email: authViewModel.email, companyId: authViewModel.currentCompanyId.isEmpty ? "SGCOOP" : authViewModel.currentCompanyId)
        let compId = authViewModel.currentCompanyId.isEmpty ? (user.companyId.isEmpty ? "SGCOOP" : user.companyId) : authViewModel.currentCompanyId
        _viewModel = StateObject(wrappedValue: AttendanceViewModel(
            user: user,
            companyId: compId,
            idToken: authViewModel.currentIdToken
        ))
    }

    // Role permissions
    private var canViewAllReports: Bool {
        viewModel.canViewAllReports
    }

    private var canAccessExpenseReport: Bool {
        viewModel.canAccessExpenseReport
    }

    private var canAccessConfigTab: Bool {
        viewModel.canAccessConfigTab
    }

    // Filtered report for regular staff if cannot view all
    private var effectiveAttendanceReport: AttendanceMonthlyReport {
        if canViewAllReports {
            return viewModel.attendanceReport
        }
        let cleanEmail = viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanName = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filteredRecs = viewModel.attendanceReport.records.filter { rec in
            let rEmail = rec.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let rName = rec.userName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return rEmail == cleanEmail || rName == cleanName ||
                (!cleanEmail.isEmpty && !rEmail.isEmpty && rEmail.components(separatedBy: "@").first == cleanEmail.components(separatedBy: "@").first)
        }

        let filteredSummaries = viewModel.attendanceReport.technicianSummaries.filter { tech in
            let tEmail = tech.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tName = tech.technicianName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return tEmail == cleanEmail || tName == cleanName ||
                (!cleanEmail.isEmpty && !tEmail.isEmpty && tEmail.components(separatedBy: "@").first == cleanEmail.components(separatedBy: "@").first)
        }

        let totalDays = filteredRecs.count
        let onTimeDays = filteredRecs.filter { $0.checkInStatus == "ON_TIME" }.count
        let lateDays = filteredRecs.filter { $0.checkInStatus == "LATE" }.count
        let earlyDays = filteredRecs.filter { $0.checkOutStatus == "EARLY" }.count
        let onTimePct = totalDays > 0 ? (Double(onTimeDays) / Double(totalDays)) * 100.0 : 0.0
        let totalMins = filteredRecs.reduce(0) { $0 + $1.totalWorkMinutes }
        let totalHours = (Double(round(Double(totalMins) / 6.0)) / 10.0)

        return AttendanceMonthlyReport(
            month: viewModel.selectedReportMonth,
            totalWorkDays: Set(filteredRecs.map { $0.date }).count,
            totalRecords: totalDays,
            onTimeCount: onTimeDays,
            lateCount: lateDays,
            earlyLeaveCount: earlyDays,
            totalWorkHours: totalHours,
            onTimePercentage: onTimePct,
            records: filteredRecs,
            technicianSummaries: filteredSummaries
        )
    }

    private var effectiveExpenseReport: TravelExpenseReport {
        if canViewAllReports || canAccessExpenseReport {
            return viewModel.expenseReport
        }
        let cleanEmail = viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanName = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filteredRecs = viewModel.expenseReport.records.filter { rec in
            let expEmail = rec.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let expName = rec.technicianName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return expEmail == cleanEmail || expName == cleanName ||
                (!cleanEmail.isEmpty && !expEmail.isEmpty && expEmail.components(separatedBy: "@").first == cleanEmail.components(separatedBy: "@").first)
        }

        // Nếu lọc theo tài khoản cá nhân không có dữ liệu mà danh mục tổng có dữ liệu, hiển thị danh mục tổng
        if filteredRecs.isEmpty && !viewModel.expenseReport.records.isEmpty {
            return viewModel.expenseReport
        }

        let filteredSummaries = viewModel.expenseReport.technicianSummaries.filter { tech in
            let tEmail = tech.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tName = tech.technicianName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return tEmail == cleanEmail || tName == cleanName ||
                (!cleanEmail.isEmpty && !tEmail.isEmpty && tEmail.components(separatedBy: "@").first == cleanEmail.components(separatedBy: "@").first)
        }

        let totalAmount = filteredRecs.filter { $0.status != "REJECTED" }.reduce(0.0) { $0 + $1.totalAmount }
        let pendingAmount = filteredRecs.filter { $0.status == "PENDING" }.reduce(0.0) { $0 + $1.totalAmount }
        let approvedAmount = filteredRecs.filter { $0.status == "APPROVED" }.reduce(0.0) { $0 + $1.totalAmount }
        let paidAmount = filteredRecs.filter { $0.status == "PAID" }.reduce(0.0) { $0 + $1.totalAmount }
        let rejectedAmount = filteredRecs.filter { $0.status == "REJECTED" }.reduce(0.0) { $0 + $1.totalAmount }
        let totalKm = filteredRecs.reduce(0.0) { $0 + $1.distanceKm }

        return TravelExpenseReport(
            month: viewModel.selectedReportMonth,
            totalTrips: filteredRecs.count,
            totalDistanceKm: totalKm,
            totalExpenseAmount: totalAmount,
            pendingAmount: pendingAmount,
            approvedAmount: approvedAmount,
            paidAmount: paidAmount,
            rejectedAmount: rejectedAmount,
            records: filteredRecs,
            technicianSummaries: filteredSummaries
        )
    }

    private func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        let numStr = f.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        return "\(numStr) VNĐ"
    }

    private func formatDistanceKm(_ km: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        f.decimalSeparator = ","
        f.groupingSeparator = "."
        let s = f.string(from: NSNumber(value: km)) ?? String(format: "%.1f", km)
        return "\(s) km"
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "#F8FAFC").ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR CHUẨN ANDROID (XANH ĐẬM #002A8F)
                    topBarView(safeAreaTop: SafeAreaHelper.top(geometry))

                    // 2. TAB SELECTOR (Chấm Công, Công Tác Phí, Cấu Hình)
                    if canAccessExpenseReport {
                        tabSelectorView
                    }

                    // 3. MAIN CONTENT
                    if viewModel.isLoadingReport {
                        Spacer()
                        ProgressView("Đang tải dữ liệu báo cáo...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.appPrimary))
                        Spacer()
                    } else {
                        Group {
                            switch viewModel.selectedReportTab {
                            case 0:
                                attendanceTabView
                            case 1:
                                expenseTabView
                            case 2:
                                if canAccessConfigTab {
                                    configTabView
                                } else {
                                    restrictedConfigView
                                }
                            default:
                                attendanceTabView
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.fetchUserProfileRealtime()
            viewModel.fetchMonthlyReport()
        }
        .sheet(isPresented: $showRejectDialog) {
            if let exp = rejectTripTarget {
                rejectDialogView(exp: exp)
            }
        }
        .alert(isPresented: $showGuideDialog) {
            Alert(
                title: Text("Hướng Dẫn Báo Cáo Chấm Công 💡"),
                message: Text("• Tab 🕒 Bảng Chấm Công: Thống kê số ngày công, tỷ lệ đúng giờ và thời gian làm của KTV.\n• Tab 🚗 Quyết Toán Chi Phí: Tổng hợp km di chuyển và phụ cấp theo từng sự cố.\n• Tab ⚙️ Cấu Hình: Thiết lập khung giờ ca và định mức xăng xe / ca hỗ trợ.\n• Chọn Kỳ tháng trên thanh tiêu đề để xem các tháng khác nhau."),
                dismissButton: .default(Text("Đã hiểu"))
            )
        }
    }

    // MARK: - REJECT DIALOG VIEW
    private func rejectDialogView(exp: TravelExpenseRecord) -> some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("KTV: \(exp.technicianName) • \(exp.ticketSubject)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#002A8F"))

                    Text("Số tiền: \(formatCurrency(exp.totalAmount))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#E11D48"))
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Lý do từ chối (bắt buộc)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.gray)

                    TextEditor(text: $rejectReasonInput)
                        .frame(height: 90)
                        .padding(4)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }

                HStack(spacing: 12) {
                    Button(action: {
                        showRejectDialog = false
                        rejectTripTarget = nil
                        rejectReasonInput = ""
                    }) {
                        Text("Hủy")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(hex: "#F1F5F9"))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        let reason = rejectReasonInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !reason.isEmpty {
                            viewModel.updateTripStatus(tripId: exp.id, status: "REJECTED", rejectReason: reason)
                            showRejectDialog = false
                            rejectTripTarget = nil
                            rejectReasonInput = ""
                        }
                    }) {
                        Text("Từ chối")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(rejectReasonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color(hex: "#DC2626"))
                            .cornerRadius(8)
                    }
                    .disabled(rejectReasonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Spacer()
            }
            .padding(16)
            .navigationTitle("Từ chối duyệt công tác phí")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 1. TOP BAR (ĐỒNG BỘ 1:1 VỚI ANDROID LINES 560-634 & SCREENSHOT)
    private func topBarView(safeAreaTop: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: safeAreaTop)

            HStack(spacing: 8) {
                // Back Button
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }

                // Title & Month Dropdown
                VStack(alignment: .leading, spacing: 1) {
                    Text("Chấm Công & Chi Phí")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Menu {
                        ForEach(monthsList, id: \.self) { m in
                            Button(action: {
                                viewModel.selectedReportMonth = m
                                viewModel.fetchMonthlyReport(monthStr: m)
                            }) {
                                HStack {
                                    Text(m)
                                    if m == viewModel.selectedReportMonth {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("Kỳ: \(viewModel.selectedReportMonth)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }

                Spacer()

                // Actions: Guide, Print, Refresh
                Button(action: { showGuideDialog = true }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }
                .frame(width: 34, height: 34)

                Button(action: {
                    exportReportCsv()
                }) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .frame(width: 34, height: 34)

                Button(action: {
                    viewModel.fetchMonthlyReport()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.appTopBarColor)
    }

    // MARK: - 2. TAB SELECTOR (ĐỒNG BỘ ANDROID LINES 644-670)
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            tabButton(title: "🕒 Bảng Chấm Công", tabIndex: 0)
            tabButton(title: "🚗 Quyết Toán Chi Phí", tabIndex: 1)
            if canAccessConfigTab {
                tabButton(title: "⚙️ Cấu Hình Định Mức", tabIndex: 2)
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(hex: "#E2E8F0")),
            alignment: .bottom
        )
    }

    private func tabButton(title: String, tabIndex: Int) -> some View {
        let isSelected = viewModel.selectedReportTab == tabIndex
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedReportTab = tabIndex
            }
        }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Color.appPrimaryPink : Color(hex: "#64748B"))
                    .lineLimit(1)
                    .padding(.top, 10)

                Rectangle()
                    .frame(height: 2.5)
                    .foregroundColor(isSelected ? Color.appPrimaryPink : Color.clear)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 3. TAB 1: BÁO CÁO CHẤM CÔNG (ĐỒNG BỘ 1:1 SCREENSHOT media_1790506882715.png)
    private var attendanceTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Personal Mode Banner if not manager
                if !canViewAllReports {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2563EB"))
                        Text("Chế độ cá nhân: Đang hiển thị chấm công của \(viewModel.userName.isEmpty ? viewModel.user.email : viewModel.userName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#1D4ED8"))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                }

                // 4 KPI Cards (2x2 Grid)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        kpiCard(
                            title: "TỔNG NGÀY CÔNG",
                            value: "\(effectiveAttendanceReport.totalRecords) ngày",
                            color: Color(hex: "#2563EB")
                        )
                        kpiCard(
                            title: "TỶ LỆ ĐÚNG GIỜ",
                            value: String(format: "%.1f%%", effectiveAttendanceReport.onTimePercentage),
                            color: Color(hex: "#16A34A")
                        )
                    }
                    HStack(spacing: 8) {
                        kpiCard(
                            title: "SỐ LẦN ĐI MUỘN",
                            value: "\(effectiveAttendanceReport.lateCount) lần",
                            color: Color(hex: "#D97706")
                        )
                        kpiCard(
                            title: "TỔNG THỜI GIAN LÀM",
                            value: String(format: "%.1f giờ", effectiveAttendanceReport.totalWorkHours),
                            color: Color(hex: "#7C3AED")
                        )
                    }
                }

                // Summary By Technician Card
                VStack(alignment: .leading, spacing: 8) {
                    Text(canViewAllReports ? "👥 Tổng Hợp Theo Kỹ Thuật Viên" : "👤 Chấm Công Cá Nhân")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    Divider()
                        .padding(.horizontal, 14)

                    if effectiveAttendanceReport.technicianSummaries.isEmpty {
                        Text("Chưa có dữ liệu chấm công tháng này")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(14)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(effectiveAttendanceReport.technicianSummaries) { tech in
                                technicianRowView(tech: tech)
                                Divider()
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // Detailed Logs Section Header
                HStack {
                    Text("📋 Nhật Ký Chi Tiết (\(effectiveAttendanceReport.records.count) lượt)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                }
                .padding(.top, 4)

                // List of Records
                ForEach(effectiveAttendanceReport.records) { record in
                    recordCardView(record: record)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // KPI Card Helper
    private func kpiCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "#64748B"))
                .lineLimit(1)

            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
    }

    // Technician Row in Summary Card
    private func technicianRowView(tech: TechnicianAttendanceSummary) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tech.technicianName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .lineLimit(1)

                    if !tech.mnvDisplay.isEmpty {
                        Text("MNV: \(tech.mnvDisplay)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#1E40AF"))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#EEF2FF"))
                            .cornerRadius(4)
                    }
                }

                let dName = tech.departmentName.isEmpty ? "IT TẬP TRUNG" : tech.departmentName
                Text("\(dName) • \(tech.totalDays) ngày công (\(String(format: "%.1fh", tech.totalHours)))")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            // On-time percentage pill
            let isOnTimeGood = tech.onTimeRate >= 80.0
            Text("Đúng giờ: \(Int(round(tech.onTimeRate)))%")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isOnTimeGood ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(isOnTimeGood ? Color(hex: "#DCFCE7") : Color(hex: "#FEF3C7"))
                .cornerRadius(4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // Attendance Record Card
    private func recordCardView(record: AttendanceRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Line 1: Date, Shift, On-Time Status
            HStack(spacing: 6) {
                Text(formatDate(record.date))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                shiftBadge(shiftType: record.shiftType, displayName: record.shiftDisplayName)

                Spacer()

                let isOnTime = record.checkInStatus == "ON_TIME"
                Text(isOnTime ? "Đúng giờ" : "Đi muộn")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isOnTime ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isOnTime ? Color(hex: "#DCFCE7") : Color(hex: "#FEF3C7"))
                    .cornerRadius(4)
            }

            // Line 2: Name, MNV, Shift schedule
            HStack(spacing: 6) {
                Text(record.userName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "#0F172A"))
                    .lineLimit(1)

                if !record.mnvDisplay.isEmpty {
                    Text("MNV: \(record.mnvDisplay)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "#1E40AF"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: "#EEF2FF"))
                        .cornerRadius(4)
                }

                if !record.scheduledShiftCode.isEmpty {
                    Text(record.isUnscheduled ? "Ngoài lịch (\(record.scheduledShiftCode))" : "Lịch: \(record.scheduledShiftCode)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(record.isUnscheduled ? Color(hex: "#DC2626") : Color(hex: "#475569"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(record.isUnscheduled ? Color(hex: "#FEE2E2") : Color(hex: "#F1F5F9"))
                        .cornerRadius(4)
                } else if record.isUnscheduled {
                    Text("Ngoài lịch (Chưa xếp ca)")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: "#FEF3C7"))
                        .cornerRadius(4)
                }
            }

            // Line 3: Times
            Text("Vào ca: \(record.checkInTimeShort) • Tan ca: \(record.checkOutTimeShort)")
                .font(.system(size: 11.5))
                .foregroundColor(Color(hex: "#475569"))

            // Line 4: GPS Address
            if !record.checkInAddress.isEmpty {
                Text("📍 \(record.checkInAddress)")
                    .font(.system(size: 10.5))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
    }

    private func shiftBadge(shiftType: String, displayName: String) -> some View {
        let (bg, fg): (Color, Color) = {
            switch shiftType.uppercased() {
            case "SHIFT_1": return (Color(hex: "#FEF3C7"), Color(hex: "#B45309"))
            case "SHIFT_2": return (Color(hex: "#DBEAFE"), Color(hex: "#1D4ED8"))
            case "NIGHT", "SHIFT_3": return (Color(hex: "#EDE9FE"), Color(hex: "#6D28D9"))
            default: return (Color(hex: "#DCFCE7"), Color(hex: "#15803D"))
            }
        }()

        return Text(displayName)
            .font(.system(size: 9.5, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(bg)
            .cornerRadius(4)
    }

    private func formatDate(_ dateStr: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        if let d = inFmt.date(from: dateStr) {
            let outFmt = DateFormatter()
            outFmt.dateFormat = "dd/MM/yyyy"
            return outFmt.string(from: d)
        }
        return dateStr
    }

    // MARK: - 4. TAB 2: QUYẾT TOÁN CÔNG TÁC PHÍ (ĐỒNG BỘ 1:1 ANDROID LINES 932-1375)
    private var expenseTabView: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Personal Mode Banner if regular staff
                if !canViewAllReports {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#2563EB"))
                        Text("Chế độ cá nhân: Đang hiển thị công tác phí của \(viewModel.userName.isEmpty ? viewModel.user.email : viewModel.userName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#1D4ED8"))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                }

                // HelpDesk Read-Only Banner
                if viewModel.user.isHelpDesk && !viewModel.user.isAdmin {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#2563EB"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("👁️ Chế độ HelpDesk (Chỉ xem đối soát)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(Color(hex: "#1E40AF"))
                            Text("Xem bảng quyết toán công tác phí để đối chiếu điều phối kỹ thuật viên. Quyền duyệt/chi trả do Quản lý và Admin phụ trách.")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(hex: "#1D4ED8"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                }

                // Card Tùy Chỉnh Định Mức Chi Phí (VNĐ/KM & VNĐ/CA)
                // Card Tùy Chỉnh Định Mức Chi Phí (VNĐ/KM & VNĐ/CA - ĐỒNG BỘ 1:1 ANDROID & SCREENSHOT media_1790512385670.png)
                if canAccessConfigTab || canViewAllReports {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(hex: "#DCFCE7"))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(hex: "#16A34A"))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tùy Chỉnh Định Mức Công Tác Phí")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                let pKmVal = viewModel.travelConfig.pricePerKm > 0 ? viewModel.travelConfig.pricePerKm : (Double(viewModel.cfgPricePerKm) ?? 1500.0)
                                let tAllowVal = viewModel.travelConfig.tripBaseAllowance > 0 ? viewModel.travelConfig.tripBaseAllowance : (Double(viewModel.cfgTripBaseAllowance) ?? 50000.0)
                                Text("Đang áp dụng: \(formatCurrency(pKmVal))/km • \(formatCurrency(tAllowVal))/ca")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#2563EB"))
                            }
                            Spacer()
                        }

                        Divider().background(Color(hex: "#F1F5F9"))

                        // 2 Ô Outlined Tùy Chỉnh (Floating labels, red fuel pump & purple banknote)
                        HStack(spacing: 8) {
                            MaterialOutlinedField(
                                label: "Đơn giá xăng",
                                leadingIconSystem: "fuelpump.fill",
                                leadingIconColor: Color(hex: "#DC2626"),
                                trailingText: "đ/km",
                                keyboardType: .numberPad,
                                text: $viewModel.cfgPricePerKm,
                                placeholder: "5000",
                                isEnabled: canViewAllReports
                            )

                            MaterialOutlinedField(
                                label: "Phụ cấp mỗi ca",
                                leadingIconSystem: "banknote.fill",
                                leadingIconColor: Color(hex: "#7C3AED"),
                                trailingText: "đ/ca",
                                keyboardType: .numberPad,
                                text: $viewModel.cfgTripBaseAllowance,
                                placeholder: "50000",
                                isEnabled: canViewAllReports
                            )
                        }

                        // Gợi ý nhanh & Nút Áp dụng (Tách dòng, Full-width như Android)
                        if canViewAllReports {
                            HStack(spacing: 6) {
                                Text("Gợi ý nhanh:")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color(hex: "#64748B"))
                                MaterialSuggestionChip(label: "5.000 đ/km", isSelected: viewModel.cfgPricePerKm == "5000") { viewModel.cfgPricePerKm = "5000" }
                                MaterialSuggestionChip(label: "7.000 đ/km", isSelected: viewModel.cfgPricePerKm == "7000") { viewModel.cfgPricePerKm = "7000" }
                                MaterialSuggestionChip(label: "10.000 đ/km", isSelected: viewModel.cfgPricePerKm == "10000") { viewModel.cfgPricePerKm = "10000" }
                            }

                            Button(action: {
                                viewModel.saveTravelExpenseConfig()
                            }) {
                                HStack(spacing: 6) {
                                    if viewModel.isSavingReportConfig {
                                        ProgressView().tint(.white).scaleEffect(0.7)
                                        Text("Đang lưu định mức...")
                                            .font(.system(size: 12, weight: .bold))
                                    } else {
                                        Image(systemName: "square.and.arrow.down.fill")
                                            .font(.system(size: 13))
                                        Text("Áp Dụng Định Mức Mới")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color(hex: "#16A34A"))
                                .cornerRadius(8)
                            }
                            .disabled(viewModel.isSavingReportConfig)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }

                // 3 KPI Cards
                HStack(spacing: 8) {
                    kpiCard(
                        title: "TỔNG CHUYẾN ĐI",
                        value: "\(effectiveExpenseReport.totalTrips)",
                        color: Color(hex: "#2563EB")
                    )
                    kpiCard(
                        title: "TỔNG KM",
                        value: formatDistanceKm(effectiveExpenseReport.totalDistanceKm),
                        color: Color(hex: "#16A34A")
                    )
                    kpiCard(
                        title: "TỔNG CHI PHÍ",
                        value: formatCurrency(effectiveExpenseReport.totalExpenseAmount),
                        color: Color.appPrimaryPink
                    )
                }

                // Summary By Technician Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("🚗 Chi Phí Theo Kỹ Thuật Viên")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)

                    Divider().padding(.horizontal, 14)

                    if effectiveExpenseReport.technicianSummaries.isEmpty {
                        Text("Chưa có dữ liệu công tác phí tháng này")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(14)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(effectiveExpenseReport.technicianSummaries) { tech in
                                let techRecs = effectiveExpenseReport.records.filter { $0.technicianEmail.lowercased() == tech.technicianEmail.lowercased() }
                                let pIds = techRecs.filter { $0.status == "PENDING" }.map { $0.id }
                                let aIds = techRecs.filter { $0.status == "APPROVED" }.map { $0.id }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tech.technicianName)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(Color.appSecondaryDarkBlue)
                                            Text("\(tech.totalTrips) • \(formatDistanceKm(tech.totalDistanceKm))")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Text(formatCurrency(tech.totalAmount))
                                            .font(.system(size: 12.5, weight: .bold))
                                            .foregroundColor(Color.appPrimaryPink)
                                    }

                                    // Batch Action Buttons
                                    if viewModel.canApproveExpense && (!pIds.isEmpty || !aIds.isEmpty) {
                                        HStack(spacing: 6) {
                                            if !pIds.isEmpty {
                                                Button(action: {
                                                    viewModel.updateBatchTripStatus(tripIds: pIds, status: "APPROVED")
                                                }) {
                                                    Text("Duyệt tất cả (\(pIds.count))")
                                                        .font(.system(size: 10.5, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3.5)
                                                        .background(Color(hex: "#2563EB"))
                                                        .cornerRadius(5)
                                                }
                                            }
                                            if !aIds.isEmpty {
                                                Button(action: {
                                                    viewModel.updateBatchTripStatus(tripIds: aIds, status: "PAID")
                                                }) {
                                                    Text("Thanh toán (\(aIds.count))")
                                                        .font(.system(size: 10.5, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 3.5)
                                                        .background(Color(hex: "#10B981"))
                                                        .cornerRadius(5)
                                                }
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                Divider().padding(.horizontal, 14)
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // Detailed Expense Records List
                HStack {
                    Text("🧾 Danh Sách Chuyến Đi (\(effectiveExpenseReport.records.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                }
                .padding(.top, 4)

                ForEach(effectiveExpenseReport.records) { exp in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(formatDate(exp.date))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            statusBadge(status: exp.status)
                        }

                        if !exp.ticketSubject.isEmpty {
                            Text("Sự cố: \(exp.ticketSubject)")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Color(hex: "#0F172A"))
                        }

                        Text("KTV: \(exp.technicianName) ➔ \(exp.toDonVi.isEmpty ? "Chi nhánh" : exp.toDonVi)")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(hex: "#475569"))

                        if exp.status == "REJECTED" && !exp.rejectReason.isEmpty {
                            Text("⚠️ Lý do từ chối: \(exp.rejectReason)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: "#DC2626"))
                        }

                        HStack {
                            Text("Quãng đường: \(formatDistanceKm(exp.distanceKm))")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatCurrency(exp.totalAmount))
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }

                        // Action Buttons for Approval
                        if viewModel.canApproveExpense {
                            Divider().padding(.top, 2)
                            HStack {
                                Spacer()
                                if exp.status == "PENDING" {
                                    Button(action: { viewModel.updateTripStatus(tripId: exp.id, status: "APPROVED") }) {
                                        Text("Duyệt")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "#2563EB"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#2563EB"), lineWidth: 1))
                                    }
                                    Button(action: { viewModel.updateTripStatus(tripId: exp.id, status: "PAID") }) {
                                        Text("Chi tiền")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "#10B981"))
                                            .cornerRadius(5)
                                    }
                                    Button(action: {
                                        rejectTripTarget = exp
                                        rejectReasonInput = ""
                                        showRejectDialog = true
                                    }) {
                                        Text("Từ chối")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "#DC2626"))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#DC2626"), lineWidth: 1))
                                    }
                                } else if exp.status == "APPROVED" {
                                    Button(action: { viewModel.updateTripStatus(tripId: exp.id, status: "PAID") }) {
                                        Text("Chi tiền")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color(hex: "#10B981"))
                                            .cornerRadius(5)
                                    }
                                    Button(action: {
                                        rejectTripTarget = exp
                                        rejectReasonInput = ""
                                        showRejectDialog = true
                                    }) {
                                        Text("Từ chối")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "#DC2626"))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#DC2626"), lineWidth: 1))
                                    }
                                } else if exp.status == "REJECTED" {
                                    Button(action: { viewModel.updateTripStatus(tripId: exp.id, status: "APPROVED") }) {
                                        Text("Duyệt lại")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(Color(hex: "#2563EB"))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(hex: "#2563EB"), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func statusBadge(status: String) -> some View {
        let (bg, fg, label): (Color, Color, String) = {
            switch status.uppercased() {
            case "APPROVED": return (Color(hex: "#DBEAFE"), Color(hex: "#1E40AF"), "Đã duyệt")
            case "PAID": return (Color(hex: "#DCFCE7"), Color(hex: "#15803D"), "Đã thanh toán")
            case "REJECTED": return (Color(hex: "#FEE2E2"), Color(hex: "#DC2626"), "Từ chối")
            default: return (Color(hex: "#FEF3C7"), Color(hex: "#B45309"), "Chờ duyệt")
            }
        }()

        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(4)
    }

    // MARK: - 5. TAB 3: CẤU HÌNH ĐỊNH MỨC & GIỜ CA (ĐỒNG BỘ 1:1 VỚI ANDROID ATTENDANCEREPORTSCREEN.KT & SCREENSHOTS)
    private var configTabView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header Card: Cấu Hình Khung Giờ & Định Mức
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.appPrimaryPink.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20))
                            .foregroundColor(Color.appPrimaryPink)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cấu Hình Khung Giờ & Định Mức")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text("Giờ làm việc, mốc GPS và định mức quyết toán KTV")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#64748B"))
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // CARD 1: KHUNG GIỜ LÀM VIỆC & ĐI MUỘN (Đúng ảnh chụp media_1790512398463.png)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#EFF6FF"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#2563EB"))
                        }
                        Text("1. Khung Giờ Làm Việc & Đi Muộn")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                    Divider().background(Color(hex: "#F1F5F9"))

                    // 1.1 Ca Hành Chính (HC)
                    Text("☀️ 1.1. Ca Hành Chính (HC)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#15803D"))
                    HStack(spacing: 8) {
                        MaterialOutlinedField(
                            label: "Vào ca HC",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#15803D"),
                            text: $viewModel.cfgStandardCheckIn,
                            placeholder: "08:00"
                        )
                        MaterialOutlinedField(
                            label: "Tan ca HC",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#15803D"),
                            text: $viewModel.cfgStandardCheckOut,
                            placeholder: "17:00"
                        )
                    }

                    // 1.2 Ca 1 (Ca Sáng)
                    Text("🌅 1.2. Ca 1 (Ca Sáng)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#B45309"))
                    HStack(spacing: 8) {
                        MaterialOutlinedField(
                            label: "Vào Ca 1",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#B45309"),
                            text: $viewModel.cfgShift1CheckIn,
                            placeholder: "07:00"
                        )
                        MaterialOutlinedField(
                            label: "Tan Ca 1",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#B45309"),
                            text: $viewModel.cfgShift1CheckOut,
                            placeholder: "15:00"
                        )
                    }

                    // 1.3 Ca 2 (Ca Chiều / Tối)
                    Text("🌇 1.3. Ca 2 (Ca Chiều / Tối)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#1D4ED8"))
                    HStack(spacing: 8) {
                        MaterialOutlinedField(
                            label: "Vào Ca 2",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#1D4ED8"),
                            text: $viewModel.cfgShift2CheckIn,
                            placeholder: "14:00"
                        )
                        MaterialOutlinedField(
                            label: "Tan Ca 2",
                            leadingIconSystem: "clock.fill",
                            leadingIconColor: Color(hex: "#1D4ED8"),
                            text: $viewModel.cfgShift2CheckOut,
                            placeholder: "22:00"
                        )
                    }

                    // 1.4 Ca 3 (Ca Đêm / Trực)
                    Text("🌙 1.4. Ca 3 (Ca Đêm / Trực)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#7C3AED"))
                    HStack(spacing: 8) {
                        MaterialOutlinedField(
                            label: "Vào Ca 3",
                            leadingIconSystem: "moon.fill",
                            leadingIconColor: Color(hex: "#7C3AED"),
                            text: $viewModel.cfgNightCheckIn,
                            placeholder: "22:00"
                        )
                        MaterialOutlinedField(
                            label: "Tan Ca 3",
                            leadingIconSystem: "moon.fill",
                            leadingIconColor: Color(hex: "#7C3AED"),
                            text: $viewModel.cfgNightCheckOut,
                            placeholder: "06:00"
                        )
                    }

                    // Phút cho phép trễ
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Số phút cho phép đi muộn",
                            leadingIconSystem: "timer",
                            leadingIconColor: Color(hex: "#D97706"),
                            keyboardType: .numberPad,
                            text: $viewModel.cfgMaxLateMinutes,
                            placeholder: "15"
                        )
                        HStack(spacing: 6) {
                            MaterialSuggestionChip(label: "5p") { viewModel.cfgMaxLateMinutes = "5" }
                            MaterialSuggestionChip(label: "10p") { viewModel.cfgMaxLateMinutes = "10" }
                            MaterialSuggestionChip(label: "15p") { viewModel.cfgMaxLateMinutes = "15" }
                            MaterialSuggestionChip(label: "30p") { viewModel.cfgMaxLateMinutes = "30" }
                        }
                    }

                    // Bán kính GPS hợp lệ
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Bán kính GPS hợp lệ (Mét)",
                            leadingIconSystem: "scope",
                            leadingIconColor: Color(hex: "#7C3AED"),
                            keyboardType: .numberPad,
                            text: $viewModel.cfgGeofenceRadius,
                            placeholder: "250"
                        )
                        HStack(spacing: 6) {
                            MaterialSuggestionChip(label: "100m") { viewModel.cfgGeofenceRadius = "100" }
                            MaterialSuggestionChip(label: "250m") { viewModel.cfgGeofenceRadius = "250" }
                            MaterialSuggestionChip(label: "500m") { viewModel.cfgGeofenceRadius = "500" }
                            MaterialSuggestionChip(label: "1000m") { viewModel.cfgGeofenceRadius = "1000" }
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // CARD 2: TỌA ĐỘ MỐC CHẤM CÔNG (GEOFENCING GPS - Đúng ảnh chụp media_1790512408538.png)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#FEE2E2"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#DC2626"))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("2. Mốc Tọa Độ Chấm Công Chuẩn")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Text("Xác thực vị trí điểm danh GPS của nhân viên")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(hex: "#64748B"))
                        }
                    }
                    Divider().background(Color(hex: "#F1F5F9"))

                    // Nút Lấy vị trí GPS hiện tại
                    Button(action: {
                        viewModel.captureCurrentLocationAsAnchor()
                    }) {
                        HStack(spacing: 6) {
                            if viewModel.isGettingCurrentLocation {
                                ProgressView().tint(Color(hex: "#1D4ED8")).scaleEffect(0.8)
                                Text("Đang định vị GPS...")
                                    .font(.system(size: 12, weight: .bold))
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#2563EB"))
                                Text("📍 Lấy vị trí GPS hiện tại làm mốc")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundColor(Color(hex: "#1D4ED8"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Color(hex: "#EFF6FF"))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#93C5FD"), lineWidth: 1))
                    }
                    .disabled(viewModel.isGettingCurrentLocation)

                    // Target Address
                    MaterialOutlinedField(
                        label: "Tên / Địa chỉ điểm làm việc chuẩn",
                        leadingIconSystem: "building.2.fill",
                        leadingIconColor: Color(hex: "#2563EB"),
                        trailingIconSystem: (!viewModel.cfgTargetAddress.isEmpty || !viewModel.cfgTargetLatitude.isEmpty || !viewModel.cfgTargetLongitude.isEmpty) ? "xmark.circle.fill" : nil,
                        trailingAction: {
                            viewModel.cfgTargetAddress = ""
                            viewModel.cfgTargetLatitude = ""
                            viewModel.cfgTargetLongitude = ""
                        },
                        text: $viewModel.cfgTargetAddress,
                        placeholder: "vd: Trụ sở chính - Chi nhánh 1..."
                    )

                    // Lat & Lng Row
                    HStack(spacing: 8) {
                        MaterialOutlinedField(
                            label: "Vĩ độ (Lat)",
                            leadingIconSystem: "mappin.and.ellipse",
                            leadingIconColor: Color(hex: "#D97706"),
                            keyboardType: .decimalPad,
                            text: $viewModel.cfgTargetLatitude,
                            placeholder: "vd: 10.776889"
                        )
                        MaterialOutlinedField(
                            label: "Kinh độ (Lng)",
                            leadingIconSystem: "mappin.and.ellipse",
                            leadingIconColor: Color(hex: "#D97706"),
                            keyboardType: .decimalPad,
                            text: $viewModel.cfgTargetLongitude,
                            placeholder: "vd: 106.700806"
                        )
                    }

                    // Surface Info Box
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#64748B"))
                        Text("Để trống nếu không muốn ép buộc mốc cố định. Khi đã cài đặt mốc, nhân viên đứng ngoài bán kính quy định sẽ bị cảnh báo vi phạm check-in.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#64748B"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#F8FAFC"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // CARD 3: ĐỊNH MỨC CÔNG TÁC PHÍ & PHỤ CẤP CA (Đúng ảnh chụp media_1790512408538.png)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: "#DCFCE7"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "banknote.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#16A34A"))
                        }
                        Text("3. Định Mức Công Tác Phí & Phụ Cấp Ca")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                    Divider().background(Color(hex: "#F1F5F9"))

                    // Giá xăng
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Đơn giá xăng xe di chuyển (VNĐ / Km)",
                            leadingIconSystem: "fuelpump.fill",
                            leadingIconColor: Color(hex: "#DC2626"),
                            trailingText: "đ/km",
                            keyboardType: .numberPad,
                            text: $viewModel.cfgPricePerKm,
                            placeholder: "5000"
                        )
                        HStack(spacing: 6) {
                            MaterialSuggestionChip(label: "5.000 VNĐ/km") { viewModel.cfgPricePerKm = "5000" }
                            MaterialSuggestionChip(label: "7.000 VNĐ/km") { viewModel.cfgPricePerKm = "7000" }
                            MaterialSuggestionChip(label: "10.000 VNĐ/km") { viewModel.cfgPricePerKm = "10000" }
                            MaterialSuggestionChip(label: "12.000 VNĐ/km") { viewModel.cfgPricePerKm = "12000" }
                        }
                    }

                    // Phụ cấp ca
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Phụ cấp mỗi ca xử lý / ca đêm (VNĐ / ca)",
                            leadingIconSystem: "banknote.fill",
                            leadingIconColor: Color(hex: "#7C3AED"),
                            trailingText: "đ/ca",
                            keyboardType: .numberPad,
                            text: $viewModel.cfgTripBaseAllowance,
                            placeholder: "50000"
                        )
                        HStack(spacing: 6) {
                            MaterialSuggestionChip(label: "30.000 VNĐ/ca") { viewModel.cfgTripBaseAllowance = "30000" }
                            MaterialSuggestionChip(label: "50.000 VNĐ/ca") { viewModel.cfgTripBaseAllowance = "50000" }
                            MaterialSuggestionChip(label: "70.000 VNĐ/ca") { viewModel.cfgTripBaseAllowance = "70000" }
                            MaterialSuggestionChip(label: "100.000 VNĐ/ca") { viewModel.cfgTripBaseAllowance = "100000" }
                        }
                    }

                    // Hệ số ngoài giờ
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Hệ số ngoài giờ / ca đêm / cuối tuần",
                            leadingIconSystem: "clock.badge.checkmark",
                            leadingIconColor: Color(hex: "#2563EB"),
                            keyboardType: .decimalPad,
                            text: $viewModel.cfgOvertimeMultiplier,
                            placeholder: "0"
                        )
                        HStack(spacing: 6) {
                            MaterialSuggestionChip(label: "0 (Mặc định)") { viewModel.cfgOvertimeMultiplier = "0" }
                            MaterialSuggestionChip(label: "1.0x") { viewModel.cfgOvertimeMultiplier = "1.0" }
                            MaterialSuggestionChip(label: "1.25x") { viewModel.cfgOvertimeMultiplier = "1.25" }
                            MaterialSuggestionChip(label: "1.5x") { viewModel.cfgOvertimeMultiplier = "1.5" }
                            MaterialSuggestionChip(label: "2.0x") { viewModel.cfgOvertimeMultiplier = "2.0" }
                        }
                    }

                    // Ghi chú hệ số ngoài giờ
                    VStack(alignment: .leading, spacing: 2) {
                        Text("📌 Quy tắc nhân hệ số ngoài giờ / ca đêm:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#1D4ED8"))
                        let multVal = Double(viewModel.cfgOvertimeMultiplier) ?? 0.0
                        Text(multVal > 1.0 ? "Hệ số (\(String(format: "%.2f", multVal))x) CHỈ NHÂN VỚI PHỤ CẤP CA khi phát sinh ngoài giờ hoặc ca đêm / cuối tuần. Tiền xăng giữ nguyên theo km thực tế." : "Mặc định hệ số = 0: Không áp dụng nhân hệ số phụ cấp ngoài giờ / ca đêm. Phụ cấp ca giữ nguyên theo định mức cơ bản. Khi cần áp dụng có thể tự điều chỉnh hệ số sau (1.25x, 1.5x, 2.0x...).")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#1E40AF"))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#EFF6FF"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))

                    // Bán kính xác nhận KTV đến nơi
                    VStack(alignment: .leading, spacing: 4) {
                        MaterialOutlinedField(
                            label: "Bán kính xác nhận KTV đã đến nơi (Mét)",
                            leadingIconSystem: "location.north.line.fill",
                            leadingIconColor: Color(hex: "#10B981"),
                            trailingText: "m",
                            keyboardType: .numberPad,
                            text: $viewModel.cfgArrivalRadius,
                            placeholder: "150"
                        )
                        HStack(spacing: 6) {
                            Text("Gợi ý:")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.gray)
                            MaterialSuggestionChip(label: "50m") { viewModel.cfgArrivalRadius = "50" }
                            MaterialSuggestionChip(label: "100m") { viewModel.cfgArrivalRadius = "100" }
                            MaterialSuggestionChip(label: "150m") { viewModel.cfgArrivalRadius = "150" }
                            MaterialSuggestionChip(label: "200m") { viewModel.cfgArrivalRadius = "200" }
                            MaterialSuggestionChip(label: "300m") { viewModel.cfgArrivalRadius = "300" }
                            MaterialSuggestionChip(label: "500m") { viewModel.cfgArrivalRadius = "500" }
                        }
                    }

                    // Ghi chú cơ chế xác nhận
                    VStack(alignment: .leading, spacing: 2) {
                        Text("🎯 Cơ chế xác nhận điểm đến KTV:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#15803D"))
                        Text("Khi Kỹ thuật viên di chuyển đến gần vị trí sự cố trong phạm vi bán kính này (mặc định 150m), app sẽ tự động hiển thị nút 'Đã đến nơi' để xác nhận bắt đầu hỗ trợ và tính toán chốt công tác phí.")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(hex: "#166534"))
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#F0FDF4"))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BBF7D0"), lineWidth: 1))
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // CARD 4: MINH HỌA QUYẾT TOÁN THỰC TẾ (Đúng ảnh chụp media_1790512414585.png)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "equal.square.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#0284C7"))
                        Text("💡 Minh Họa Quyết Toán (Mô phỏng ca 10 km)")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                    }
                    Divider().background(Color(hex: "#E2E8F0"))

                    let pKm = Double(viewModel.cfgPricePerKm) ?? 5000.0
                    let tAllow = Double(viewModel.cfgTripBaseAllowance) ?? 50000.0
                    let oMulti = Double(viewModel.cfgOvertimeMultiplier) ?? 0.0
                    let sampleKm = 10.0
                    let sampleKmVal = sampleKm * pKm
                    let sampleNormalVal = sampleKmVal + tAllow
                    let isOtActive = oMulti > 1.0
                    let sampleOtAllow = isOtActive ? tAllow * oMulti : tAllow
                    let sampleOtVal = sampleKmVal + sampleOtAllow

                    // Ca trong giờ
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#D97706"))
                            Text("☀️ Ca trong giờ hành chính:")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#1E3A8A"))
                        }
                        Text("• Tiền xăng: 10 km × \(formatCurrency(pKm)) = \(formatCurrency(sampleKmVal))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#475569"))
                        Text("• Phụ cấp ca: \(formatCurrency(tAllow))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#475569"))
                        Divider().background(Color(hex: "#F1F5F9"))
                        HStack {
                            Text("Tổng tiền ca:")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(Color(hex: "#1E293B"))
                            Spacer()
                            Text(formatCurrency(sampleNormalVal))
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(Color(hex: "#2563EB"))
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))

                    // Ca ngoài giờ
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#7C3AED"))
                            let displayOtText = isOtActive ? "\(String(format: "%.2f", oMulti))x" : "Hệ số 0"
                            Text("🌙 Ca ngoài giờ / ca đêm (\(displayOtText)):")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#5B21B6"))
                        }
                        Text("• Tiền xăng: 10 km × \(formatCurrency(pKm)) = \(formatCurrency(sampleKmVal))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#475569"))
                        let otAllowText = isOtActive ?
                            "• Phụ cấp (\(String(format: "%.2f", oMulti))x): \(formatCurrency(tAllow)) × \(String(format: "%.2f", oMulti)) = \(formatCurrency(sampleOtAllow))" :
                            "• Phụ cấp (Hệ số 0 - Giữ nguyên): \(formatCurrency(sampleOtAllow))"
                        Text(otAllowText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: "#7C3AED"))
                        Divider().background(Color(hex: "#F1F5F9"))
                        HStack {
                            Text("Tổng tiền ca:")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(Color(hex: "#1E293B"))
                            Spacer()
                            Text(formatCurrency(sampleOtVal))
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(Color.appPrimaryPink)
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#DDD6FE"), lineWidth: 1))
                }
                .padding(14)
                .background(Color(hex: "#F8FAFC"))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))

                // SAVE BUTTON (PRIMARY PINK CHUẨN ANDROID - Đúng ảnh chụp media_1790512414585.png)
                Button(action: {
                    viewModel.saveTravelExpenseConfig()
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isSavingReportConfig {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                            Text("Đang lưu cấu hình...")
                                .font(.system(size: 13, weight: .bold))
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 16))
                            Text("Lưu Cấu Hình Định Mức & Giờ Ca")
                                .font(.system(size: 13.5, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isSavingReportConfig)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private var restrictedConfigView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("Chỉ Quản trị viên mới có quyền cấu hình định mức & giờ ca.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
        }
    }

    // Export CSV
    private func exportReportCsv() {
        var csv = "Ngay,Nhan Vien,MNV,Ca,Trang Thai,Vao Ca,Tan Ca,Tong Gio,Dia Chi\n"
        for r in effectiveAttendanceReport.records {
            let mnv = r.mnvDisplay
            let shift = r.shiftDisplayName
            let st = r.checkInStatus == "ON_TIME" ? "Dung gio" : "Di muon"
            csv += "\"\(r.date)\",\"\(r.userName)\",\"\(mnv)\",\"\(shift)\",\"\(st)\",\"\(r.checkInTimeShort)\",\"\(r.checkOutTimeShort)\",\"\(r.workHoursFormatted)\",\"\(r.checkInAddress)\"\n"
        }

        let av = UIActivityViewController(activityItems: [csv], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true, completion: nil)
        }
    }
}
