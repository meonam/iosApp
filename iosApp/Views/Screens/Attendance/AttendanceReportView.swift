import SwiftUI
import Foundation

// MARK: - ATTENDANCE & EXPENSE REPORT VIEW (ĐỒNG BỘ 1:1 VỚI ANDROID ATTENDANCEREPORTSCREEN.KT & SCREENSHOT media_1790506882715.png)
public struct AttendanceReportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    @StateObject private var viewModel: AttendanceViewModel

    @State private var showGuideDialog: Bool = false
    @State private var showExportDialog: Bool = false

    private let monthsList: [String] = {
        var cal = Calendar(identifier: .gregorian)
        var list: [String] = []
        let sdf = DateFormatter()
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
        if let user = authViewModel.currentUser {
            _viewModel = StateObject(wrappedValue: AttendanceViewModel(
                user: user,
                companyId: authViewModel.currentCompanyId,
                idToken: authViewModel.currentIdToken
            ))
        } else {
            _viewModel = StateObject(wrappedValue: AttendanceViewModel(
                user: User(email: "", fullName: ""),
                companyId: "",
                idToken: ""
            ))
        }
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
        if canViewAllReports {
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

        let filteredSummaries = viewModel.expenseReport.technicianSummaries.filter { tech in
            let tEmail = tech.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let tName = tech.technicianName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return tEmail == cleanEmail || tName == cleanName ||
                (!cleanEmail.isEmpty && !tEmail.isEmpty && tEmail.components(separatedBy: "@").first == cleanEmail.components(separatedBy: "@").first)
        }

        let totalAmount = filteredRecs.reduce(0.0) { $0 + $1.totalAmount }
        let paidAmount = filteredRecs.filter { $0.status == "PAID" }.reduce(0.0) { $0 + $1.totalAmount }
        let pendingAmount = totalAmount - paidAmount
        let totalKm = filteredRecs.reduce(0.0) { $0 + $1.distanceKm }

        return TravelExpenseReport(
            month: viewModel.selectedReportMonth,
            totalTrips: filteredRecs.count,
            totalDistanceKm: totalKm,
            totalExpenseAmount: totalAmount,
            pendingAmount: pendingAmount,
            approvedAmount: filteredRecs.filter { $0.status == "APPROVED" }.reduce(0.0) { $0 + $1.totalAmount },
            paidAmount: paidAmount,
            rejectedAmount: filteredRecs.filter { $0.status == "REJECTED" }.reduce(0.0) { $0 + $1.totalAmount },
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
            viewModel.fetchMonthlyReport()
        }
        .alert(isPresented: $showGuideDialog) {
            Alert(
                title: Text("Hướng Dẫn Báo Cáo Chấm Công 💡"),
                message: Text("• Tab 🕒 Bảng Chấm Công: Thống kê số ngày công, tỷ lệ đúng giờ và thời gian làm của KTV.\n• Tab 🚗 Quyết Toán Chi Phí: Tổng hợp km di chuyển và phụ cấp theo từng sự cố.\n• Tab ⚙️ Cấu Hình: Thiết lập khung giờ ca và định mức xăng xe / ca hỗ trợ.\n• Chọn Kỳ tháng trên thanh tiêu đề để xem các tháng khác nhau."),
                dismissButton: .default(Text("Đã hiểu"))
            )
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
                    .foregroundColor(isSelected ? Color.appPrimary : Color(hex: "#64748B"))
                    .lineLimit(1)
                    .padding(.top, 10)

                Rectangle()
                    .frame(height: 2.5)
                    .foregroundColor(isSelected ? Color.appPrimary : Color.clear)
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

    // MARK: - 4. TAB 2: QUYẾT TOÁN CÔNG TÁC PHÍ
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

                // 3 KPI Cards
                HStack(spacing: 8) {
                    kpiCard(
                        title: "TỔNG CHUYẾN ĐI",
                        value: "\(effectiveExpenseReport.totalTrips)",
                        color: Color(hex: "#2563EB")
                    )
                    kpiCard(
                        title: "TỔNG KM",
                        value: String(format: "%.1f km", effectiveExpenseReport.totalDistanceKm),
                        color: Color(hex: "#16A34A")
                    )
                    kpiCard(
                        title: "TỔNG CHI PHÍ",
                        value: formatCurrency(effectiveExpenseReport.totalExpenseAmount),
                        color: Color.appPrimary
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
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tech.technicianName)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                        Text("\(tech.totalTrips) chuyến • \(String(format: "%.1f km", tech.totalDistanceKm))")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(formatCurrency(tech.totalAmount))
                                        .font(.system(size: 12.5, weight: .bold))
                                        .foregroundColor(Color.appPrimary)
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
                    Text("📋 Danh Sách Chuyến Đi (\(effectiveExpenseReport.records.count))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Spacer()
                }
                .padding(.top, 4)

                ForEach(effectiveExpenseReport.records) { exp in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(formatDate(exp.date))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()
                            statusBadge(status: exp.status)
                        }

                        Text(exp.technicianName)
                            .font(.system(size: 13, weight: .semibold))

                        Text("Tuyến: \(exp.fromDonVi.isEmpty ? "Kho" : exp.fromDonVi) ➔ \(exp.toDonVi.isEmpty ? "Chi nhánh" : exp.toDonVi)")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(hex: "#475569"))

                        HStack {
                            Text("\(String(format: "%.1f km", exp.distanceKm))")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatCurrency(exp.totalAmount))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.appPrimary)
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
            case "PAID": return (Color(hex: "#DCFCE7"), Color(hex: "#15803D"), "Đã chi trả")
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

    // MARK: - 5. TAB 3: CẤU HÌNH ĐỊNH MỨC & GIỜ CA (DÀNH CHO ADMIN)
    private var configTabView: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Header Card
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(Color.appPrimary)
                        .frame(width: 40, height: 40)
                        .background(Color.appPrimary.opacity(0.12))
                        .cornerRadius(10)

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

                // Card 1: Khung Giờ
                VStack(alignment: .leading, spacing: 10) {
                    Text("⏰ Khung Giờ Làm Việc")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Divider()

                    configField(label: "Ca Hành Chính (Vào - Tan)", value1: $viewModel.cfgStandardCheckIn, value2: $viewModel.cfgStandardCheckOut)
                    configField(label: "Ca 1 Sáng (Vào - Tan)", value1: $viewModel.cfgShift1CheckIn, value2: $viewModel.cfgShift1CheckOut)
                    configField(label: "Ca 2 Chiều (Vào - Tan)", value1: $viewModel.cfgShift2CheckIn, value2: $viewModel.cfgShift2CheckOut)
                    configField(label: "Ca 3 Đêm (Vào - Tan)", value1: $viewModel.cfgNightCheckIn, value2: $viewModel.cfgNightCheckOut)

                    HStack {
                        Text("Cho phép đi muộn (phút)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        TextField("15", text: $viewModel.cfgMaxLateMinutes)
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // Card 2: Định Mức Chi Phí
                VStack(alignment: .leading, spacing: 10) {
                    Text("⛽ Định Mức Xăng Xe & Phụ Cấp")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)

                    Divider()

                    HStack {
                        Text("Đơn giá xăng (VNĐ/km)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        TextField("5000", text: $viewModel.cfgPricePerKm)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    HStack {
                        Text("Phụ cấp mỗi ca (VNĐ/ca)")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        TextField("50000", text: $viewModel.cfgTripBaseAllowance)
                            .keyboardType(.numberPad)
                            .frame(width: 100)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))

                // Save Button
                Button(action: {
                    viewModel.saveTravelExpenseConfig()
                }) {
                    HStack {
                        if viewModel.isSavingReportConfig {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                            Text("Lưu Cấu Hình Định Mức")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isSavingReportConfig)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func configField(label: String, value1: Binding<String>, value2: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            TextField("08:00", text: value1)
                .frame(width: 55)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Text("-")
            TextField("17:00", text: value2)
                .frame(width: 55)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
