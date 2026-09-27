import SwiftUI
import CoreLocation

// MARK: - ATTENDANCE CHECK-IN VIEW (ĐỒNG BỘ 1:1 VỚI ATTENDANCECHECKINSCREEN.KT TRÊN ANDROID)
public struct AttendanceCheckInView: View {
    @ObservedObject public var viewModel: AttendanceViewModel
    public var onBack: () -> Void
    public var onNavigateToHistory: (() -> Void)? = nil
    public var onNavigateToReport: (() -> Void)? = nil

    @State private var showGuideDialog = false

    public init(
        viewModel: AttendanceViewModel,
        onBack: @escaping () -> Void,
        onNavigateToHistory: (() -> Void)? = nil,
        onNavigateToReport: (() -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onNavigateToHistory = onNavigateToHistory
        self.onNavigateToReport = onNavigateToReport
    }

    // Role-based Access (Đồng bộ Android lines 706-722)
    private var roleLower: String { viewModel.userRole.lowercased() }
    private var isAdmin: Bool { roleLower == "admin" || viewModel.user.isAdmin || viewModel.user.isSuperAdmin }
    private var isHelpDesk: Bool { roleLower.contains("helpdesk") || viewModel.user.isHelpDesk }
    private var isIncidentDept: Bool {
        let dept = viewModel.userDeptId.uppercased()
        let donVi = viewModel.userDonVi.uppercased()
        let role = roleLower
        return dept.contains("XỬ LÝ") || dept.contains("SỰ CỐ") || dept.contains("KỸ THUẬT") ||
               dept.contains("IT") || dept.contains("BẢO TRÌ") ||
               donVi.contains("KỸ THUẬT") ||
               role.contains("kythuat") || role.contains("tech") || role.contains("support") || role.contains("ktv")
    }

    private var canAccessAttendance: Bool { isAdmin || isHelpDesk || isIncidentDept || true }
    private var canAccessReport: Bool { isAdmin || isHelpDesk || isIncidentDept }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(hex: "#F8FAFC").ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR CHUẨN ANDROID (Xanh Đậm #002A8F)
                    topBarView(safeAreaTop: geometry.safeAreaInsets.top)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "#F40266"))
                            .scaleEffect(1.2)
                        Spacer()
                    } else if !canAccessAttendance {
                        restrictedAccessView
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                // 1. ĐỒNG HỒ ĐIỆN TỬ & THÔNG TIN NHÂN VIÊN
                                clockAndEmployeeCard

                                // 2. CHỌN CA LÀM VIỆC & LỊCH PHÂN CA
                                shiftSelectionCard

                                // 3. CẶP THẺ CHECK-IN / CHECK-OUT
                                actionCardsView

                                // 4. THẺ TỔNG KẾT CA HÔM NAY (KHI ĐÃ CHECK-OUT)
                                if let rec = viewModel.todayRecord, rec.isCheckedOut {
                                    shiftSummaryCard(record: rec)
                                }

                                // 5. GHI CHÚ ĐIỂM DANH
                                noteInputField

                                // 6. NÚT MỞ MÀN HÌNH LỊCH SỬ CHẤM CÔNG
                                historyNavigationCard

                                // 7. NÚT MỞ BÁO CÁO CÔNG TÁC PHÍ & KPI (CHO ADMIN / HELPDESK)
                                if canAccessReport {
                                    reportNavigationCard
                                }

                                Spacer(minLength: 32)
                            }
                            .padding(16)
                        }
                        .refreshable {
                            viewModel.loadInitialData()
                            viewModel.refreshLocation()
                        }
                    }
                }

                // GEOFENCE BLOCKING ALERT DIALOG (ĐỒNG BỘ ANDROID lines 1956-2007)
                if viewModel.showGeofenceAlert {
                    geofenceAlertDialog
                }

                // HƯỚNG DẪN DIALOG
                if showGuideDialog {
                    guideDialog
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.loadInitialData()
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

                Text("Điểm Danh Chấm Công")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Nút Hướng dẫn
                Button(action: { showGuideDialog = true }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "#FBBF24"))
                }
                .frame(width: 36, height: 36)

                // Nút Lịch sử
                if let navHistory = onNavigateToHistory {
                    Button(action: navHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                    }
                    .frame(width: 36, height: 36)
                }

                // Nút Báo cáo
                if canAccessReport, let navReport = onNavigateToReport {
                    Button(action: navReport) {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#FDE68A"))
                    }
                    .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
        }
        .background(Color(hex: "#002A8F"))
    }

    // MARK: - 1. CLOCK & EMPLOYEE CARD (XANH ĐẬM #002A8F)
    private var clockAndEmployeeCard: some View {
        VStack(spacing: 10) {
            // Đồng hồ số lớn & Ngày tháng + Nút GPS
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    Text(viewModel.currentTimeString.isEmpty ? "08:00:00" : viewModel.currentTimeString)
                        .font(.system(size: 36, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(2)

                    Text(viewModel.currentDateString.isEmpty ? "Hôm nay" : viewModel.currentDateString)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#FDE68A"))
                }
                .frame(maxWidth: .infinity)

                // Nút GPS Hồng Rực Rỡ (PrimaryPink #F40266)
                Button(action: {
                    viewModel.refreshLocation()
                    viewModel.fetchTravelExpenseConfig()
                    viewModel.fetchTodayAttendance()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#F40266"))
                            .frame(width: 38, height: 38)
                            .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)

                        if viewModel.isLocating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }

            // Thông tin nhân viên (Nền kính mờ Color.white.opacity(0.18))
            HStack(spacing: 10) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 36)

                    let displayName = viewModel.userName.isEmpty ? viewModel.user.email : viewModel.userName
                    let initials = displayName.components(separatedBy: " ")
                        .compactMap { $0.first }
                        .suffix(2)
                        .map { String($0) }
                        .joined()

                    Text(initials.isEmpty ? "NV" : initials)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.userName.isEmpty ? viewModel.user.email : viewModel.userName)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if !viewModel.userMnv.isEmpty {
                            Text("MNV: \(viewModel.userMnv)")
                                .font(.system(size: 10.5, weight: .black))
                                .foregroundColor(Color(hex: "#78350F"))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color(hex: "#FDE68A"))
                                .cornerRadius(4)
                        }
                    }

                    let roleDisplay: String = {
                        switch viewModel.userRole.lowercased() {
                        case "admin": return "Quản trị viên (Admin)"
                        case "phongban", "quanly": return "Quản lý phòng ban"
                        case "helpdesk": return "HelpDesk"
                        case "kythuat", "technician": return "Kỹ thuật viên"
                        default: return "Nhân viên"
                        }
                    }()

                    Text(roleDisplay)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#FDE68A"))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.18))
            .cornerRadius(10)

            // Hàng Phòng ban & Đơn vị
            HStack(spacing: 8) {
                // Phòng ban (Xanh dương nhạt)
                HStack {
                    let dText = viewModel.userDeptName.isEmpty ? (viewModel.userDeptId.isEmpty ? "Phòng ban" : viewModel.userDeptId) : viewModel.userDeptName
                    Text("🏛️ \(dText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#E0F2FE"))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#38BDF8").opacity(0.25))
                .cornerRadius(6)

                // Đơn vị (Hồng thương hiệu)
                HStack {
                    let uText = viewModel.userDonVi.isEmpty ? "Đơn vị" : viewModel.userDonVi
                    Text("🏬 \(uText)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .background(Color(hex: "#F40266").opacity(0.85))
                .cornerRadius(6)
            }

            // Vị trí GPS hiện tại
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 14))
                        .foregroundColor((viewModel.distanceToWorkMeters != nil && !viewModel.isWithinGeofence) ? Color(hex: "#EF4444") : Color(hex: "#38BDF8"))

                    Text(viewModel.currentAddress)
                        .font(.system(size: 11.5))
                        .foregroundColor(Color.white.opacity(0.95))
                        .lineLimit(2)

                    Spacer()
                }

                if let dist = viewModel.distanceToWorkMeters {
                    Divider().background(Color.white.opacity(0.15))
                    let maxR = viewModel.travelConfig.geofenceRadiusMeters
                    if viewModel.isWithinGeofence {
                        Text("✅ Trong bán kính hợp lệ (\(Int(dist))m / \(Int(maxR))m)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#4ADE80"))
                    } else {
                        Text("⛔ Ngoài bán kính cho phép (\(Int(dist))m > \(Int(maxR))m)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#F87171"))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.22))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(hex: "#002A8F"))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
    }

    // MARK: - 2. SHIFT SELECTION CARD
    private var shiftSelectionCard: some View {
        VStack(spacing: 10) {
            let (activeInTime, activeOutTime): (String, String) = {
                switch viewModel.selectedShiftType {
                case "SHIFT_1": return (viewModel.travelConfig.shift1CheckInTime, viewModel.travelConfig.shift1CheckOutTime)
                case "SHIFT_2": return (viewModel.travelConfig.shift2CheckInTime, viewModel.travelConfig.shift2CheckOutTime)
                case "NIGHT", "SHIFT_3": return (viewModel.travelConfig.nightCheckInTime, viewModel.travelConfig.nightCheckOutTime)
                default: return (viewModel.travelConfig.standardCheckInTime, viewModel.travelConfig.standardCheckOutTime)
                }
            }()

            let activeShortName: String = {
                switch viewModel.selectedShiftType {
                case "SHIFT_1": return "Ca 1"
                case "SHIFT_2": return "Ca 2"
                case "NIGHT", "SHIFT_3": return "Ca 3"
                default: return "Hành chính"
                }
            }()

            // Banner Lịch Phân Ca Hôm Nay
            if !viewModel.scheduledShiftCode.isEmpty {
                if viewModel.isScheduledOffDay {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#D97706"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lịch phân ca hôm nay: \(viewModel.scheduledShiftLabel) (Mã: \(viewModel.scheduledShiftCode))")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#92400E"))

                            Text("Hôm nay là ngày nghỉ theo kế hoạch. Nếu bạn được điều động tăng ca / trực đột xuất, vui lòng chọn ca bên dưới để điểm danh.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#78350F"))
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "#FEF3C7"))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#F59E0B"), lineWidth: 1))
                    .cornerRadius(8)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#2563EB"))

                        Text("📅 Phân ca hôm nay: \(viewModel.scheduledShiftLabel) (Mã: \(viewModel.scheduledShiftCode)) — Đã tự chọn ca")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(Color(hex: "#1D4ED8"))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: "#EFF6FF"))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#93C5FD"), lineWidth: 1))
                    .cornerRadius(8)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#0284C7"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("💡 Chưa có lịch phân ca hôm nay")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#0F172A"))

                        Text("Hệ thống đã tự động gợi ý ca theo giờ thực tế. Bạn có thể chọn lại ca bên dưới và bấm Điểm danh bình thường.")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#475569"))
                    }
                }
                .padding(10)
                .background(Color(hex: "#F8FAFC"))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
                .cornerRadius(8)
            }

            // Tiêu đề & Giờ ca đang chọn
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: shiftIconName(viewModel.selectedShiftType))
                        .foregroundColor(shiftColor(viewModel.selectedShiftType))
                        .font(.system(size: 14))

                    Text("Chọn ca làm việc:")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))
                }

                Spacer()

                Text("\(activeShortName): \(activeInTime) - \(activeOutTime)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(shiftColor(viewModel.selectedShiftType))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(shiftBadgeBg(viewModel.selectedShiftType))
                    .cornerRadius(6)
            }

            // Lưới 4 Ca (2 Hàng x 2 Cột)
            let shiftOptions: [(id: String, title: String, time: String, activeColor: Color)] = [
                ("HC", "☀️ Hành chính", "\(viewModel.travelConfig.standardCheckInTime) - \(viewModel.travelConfig.standardCheckOutTime)", Color(hex: "#059669")),
                ("SHIFT_1", "🌅 Ca 1 (Sáng)", "\(viewModel.travelConfig.shift1CheckInTime) - \(viewModel.travelConfig.shift1CheckOutTime)", Color(hex: "#D97706")),
                ("SHIFT_2", "🌇 Ca 2 (Chiều)", "\(viewModel.travelConfig.shift2CheckInTime) - \(viewModel.travelConfig.shift2CheckOutTime)", Color(hex: "#2563EB")),
                ("NIGHT", "🌙 Ca 3 (Đêm)", "\(viewModel.travelConfig.nightCheckInTime) - \(viewModel.travelConfig.nightCheckOutTime)", Color(hex: "#7C3AED"))
            ]

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    shiftButtonView(item: shiftOptions[0])
                    shiftButtonView(item: shiftOptions[1])
                }
                HStack(spacing: 8) {
                    shiftButtonView(item: shiftOptions[2])
                    shiftButtonView(item: shiftOptions[3])
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
    }

    private func shiftButtonView(item: (id: String, title: String, time: String, activeColor: Color)) -> some View {
        let isSelected = viewModel.selectedShiftType == item.id || (item.id == "HC" && viewModel.selectedShiftType == "DAY")
        return Button(action: {
            viewModel.selectedShiftType = item.id
            viewModel.fetchTodayAttendance()
        }) {
            VStack(spacing: 2) {
                Text(item.title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(isSelected ? .white : Color(hex: "#334155"))

                Text(item.time)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Color.white.opacity(0.9) : Color(hex: "#64748B"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(isSelected ? item.activeColor : Color(hex: "#F8FAFC"))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? item.activeColor : Color(hex: "#E2E8F0"), lineWidth: 1)
            )
        }
    }

    // MARK: - 3. ACTION CARDS (CHECK-IN / CHECK-OUT)
    private var actionCardsView: some View {
        let isCheckedIn = viewModel.todayRecord?.isCheckedIn == true
        let isCheckedOut = viewModel.todayRecord?.isCheckedOut == true
        let shiftLabel: String = {
            switch viewModel.selectedShiftType {
            case "SHIFT_1": return "CA 1"
            case "SHIFT_2": return "CA 2"
            case "NIGHT", "SHIFT_3": return "CA 3"
            default: return "HC"
            }
        }()

        return HStack(spacing: 10) {
            // Thẻ CHECK-IN
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isCheckedIn ? Color(hex: "#16A34A") : (viewModel.selectedShiftType == "NIGHT" ? Color(hex: "#7C3AED").opacity(0.15) : Color(hex: "#F40266").opacity(0.12)))
                        .frame(width: 42, height: 42)

                    Image(systemName: viewModel.selectedShiftType == "NIGHT" ? "moon.stars.fill" : "arrow.right.to.line")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isCheckedIn ? .white : (viewModel.selectedShiftType == "NIGHT" ? Color(hex: "#7C3AED") : Color(hex: "#F40266")))
                }

                Text("VÀO CA (\(shiftLabel))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#002A8F"))
                    .multilineTextAlignment(.center)

                Text(isCheckedIn ? viewModel.todayRecord!.checkInTimeFormatted : "--:--")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(isCheckedIn ? Color(hex: "#15803D") : .gray)

                if isCheckedIn {
                    let onTime = viewModel.todayRecord?.checkInStatus == "ON_TIME"
                    Text(onTime ? "✅ Đúng giờ" : "⚠️ Đi muộn")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(onTime ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(onTime ? Color(hex: "#BBF7D0") : Color(hex: "#FDE68A"))
                        .cornerRadius(4)
                } else {
                    Button(action: {
                        viewModel.performCheckIn()
                    }) {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Text("Check-in")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(viewModel.selectedShiftType == "NIGHT" ? Color(hex: "#7C3AED") : Color(hex: "#10B981"))
                    .cornerRadius(8)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isCheckedIn ? Color(hex: "#DCFCE7") : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCheckedIn ? Color(hex: "#16A34A") : Color(hex: "#CBD5E1"), lineWidth: 1.5)
            )

            // Thẻ CHECK-OUT
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isCheckedOut ? Color(hex: "#2563EB") : Color(hex: "#002A8F").opacity(0.1))
                        .frame(width: 42, height: 42)

                    Image(systemName: "arrow.right.from.line")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(isCheckedOut ? .white : Color(hex: "#002A8F"))
                }

                Text("TAN CA (\(shiftLabel))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#002A8F"))
                    .multilineTextAlignment(.center)

                Text(isCheckedOut ? viewModel.todayRecord!.checkOutTimeFormatted : "--:--")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(isCheckedOut ? Color(hex: "#1D4ED8") : .gray)

                if isCheckedOut {
                    let early = viewModel.todayRecord?.checkOutStatus == "EARLY"
                    Text("⏱️ \(viewModel.todayRecord!.workHoursFormatted)")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(early ? Color(hex: "#B45309") : Color(hex: "#1D4ED8"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#DBEAFE"))
                        .cornerRadius(4)
                } else {
                    Button(action: {
                        viewModel.performCheckOut()
                    }) {
                        if viewModel.isSubmitting {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Text("Check-out")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color(hex: "#2563EB"))
                    .cornerRadius(8)
                    .disabled(viewModel.isSubmitting || !isCheckedIn)
                    .opacity(isCheckedIn ? 1.0 : 0.5)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(isCheckedOut ? Color(hex: "#EFF6FF") : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCheckedOut ? Color(hex: "#2563EB") : Color(hex: "#CBD5E1"), lineWidth: 1.5)
            )
        }
    }

    // MARK: - 4. SHIFT SUMMARY CARD
    private func shiftSummaryCard(record: AttendanceRecord) -> some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(Color(hex: "#2563EB"))
                        .font(.system(size: 16))

                    Text(record.isNightShift ? "Hoàn tất ca đêm" : "Hoàn tất ca ngày")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))

                    Text(record.isNightShift ? "🌙 Ca đêm" : "☀️ Ca ngày")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(record.isNightShift ? Color(hex: "#7C3AED") : Color(hex: "#2563EB"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(record.isNightShift ? Color(hex: "#EDE9FE") : Color(hex: "#EFF6FF"))
                        .cornerRadius(4)
                }

                Spacer()

                let (tagText, tagColor, tagBg): (String, Color, Color) = {
                    switch record.checkOutStatus {
                    case "EARLY": return ("⚠️ Về sớm", Color(hex: "#B45309"), Color(hex: "#FEF3C7"))
                    case "OVERTIME": return ("🔥 Tăng ca (OT)", Color(hex: "#C2410C"), Color(hex: "#FFEDD5"))
                    default: return ("✅ Hoàn thành", Color(hex: "#15803D"), Color(hex: "#DCFCE7"))
                    }
                }()

                Text(tagText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tagColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tagBg)
                    .cornerRadius(6)
            }

            Divider().background(Color(hex: "#DBEAFE"))

            HStack {
                Text("🟢 Vào: \(record.checkInTimeShort)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#15803D"))
                Spacer()
                Text("🔴 Ra: \(record.checkOutTimeShort)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#1D4ED8"))
                Spacer()
                Text("⏱️ Tổng: \(record.workHoursFormatted)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#0F172A"))
            }

            if !record.checkOutAddress.isEmpty {
                Text("📍 \(record.checkOutAddress)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#64748B"))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(Color(hex: "#EFF6FF"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#93C5FD"), lineWidth: 1.5))
    }

    // MARK: - 5. NOTE INPUT
    private var noteInputField: some View {
        HStack {
            Image(systemName: "square.and.pencil")
                .foregroundColor(Color(hex: "#94A3B8"))

            TextField("Ghi chú ca làm việc (vd: Đi công tác, sửa máy...)", text: $viewModel.noteInput)
                .font(.system(size: 13))
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#CBD5E1"), lineWidth: 1))
    }

    // MARK: - 6. HISTORY NAVIGATION CARD
    private var historyNavigationCard: some View {
        Button(action: {
            onNavigateToHistory?()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#EFF6FF"))
                        .frame(width: 42, height: 42)

                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#2563EB"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lịch Sử Điểm Danh Chấm Công")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))
                        .lineLimit(1)

                    Text("Đã ghi nhận \(viewModel.totalMonthDays) ngày công tháng này")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#64748B"))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("Xem chi tiết")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#F40266"))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#F40266"))
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }

    // MARK: - 7. REPORT NAVIGATION CARD
    private var reportNavigationCard: some View {
        Button(action: {
            onNavigateToReport?()
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#FEF3C7"))
                        .frame(width: 42, height: 42)

                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#D97706"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Báo Cáo Chấm Công & Chi Phí")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))
                        .lineLimit(1)

                    Text("Bảng tổng hợp KTV & quyết toán")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#64748B"))
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 2) {
                    Text("Báo cáo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#D97706"))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(hex: "#D97706"))
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#E2E8F0"), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }

    // MARK: - GEOFENCE ALERT DIALOG (ĐỒNG BỘ ANDROID lines 1956-2007)
    private var geofenceAlertDialog: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 38))
                    .foregroundColor(Color(hex: "#DC2626"))

                Text(viewModel.geofenceAlertTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(hex: "#002A8F"))
                    .multilineTextAlignment(.center)

                Text(viewModel.geofenceAlertMessage)
                    .font(.system(size: 13.5))
                    .foregroundColor(Color(hex: "#334155"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.showGeofenceAlert = false
                    }) {
                        Text("Đóng")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#64748B"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#F1F5F9"))
                            .cornerRadius(8)
                    }

                    Button(action: {
                        viewModel.showGeofenceAlert = false
                        viewModel.refreshLocation()
                    }) {
                        Text("Cập nhật lại GPS")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color(hex: "#F40266"))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 28)
            .shadow(radius: 10)
        }
    }

    // MARK: - GUIDE DIALOG
    private var guideDialog: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("💡 Hướng Dẫn Điểm Danh Chấm Công")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(hex: "#002A8F"))
                    Spacer()
                    Button(action: { showGuideDialog = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    guideRow(step: "1", title: "Cập nhật tọa độ GPS", desc: "Hệ thống tự động kiểm tra khoảng cách đến nơi làm việc quy định.")
                    guideRow(step: "2", title: "Kiểm tra ca làm việc", desc: "Ca làm việc được tự động điền theo Lịch Phân Ca tuần hoặc gợi ý theo giờ thực tế.")
                    guideRow(step: "3", title: "Check-in khi vào ca", desc: "Bấm 'Check-in' để lưu mốc giờ bắt đầu và vị trí.")
                    guideRow(step: "4", title: "Check-out khi tan ca", desc: "Bấm 'Check-out' để chốt giờ tan ca và tính toán tổng số giờ làm việc thực tế.")
                }

                Button(action: { showGuideDialog = false }) {
                    Text("Đã hiểu")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(Color(hex: "#002A8F"))
                        .cornerRadius(8)
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .padding(.horizontal, 24)
        }
    }

    private func guideRow(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(Color(hex: "#002A8F")).frame(width: 22, height: 22)
                Text(step).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(Color(hex: "#0F172A"))
                Text(desc).font(.system(size: 12)).foregroundColor(Color(hex: "#64748B"))
            }
        }
    }

    // MARK: - RESTRICTED ACCESS VIEW
    private var restrictedAccessView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#94A3B8"))

            Text("Phân Hệ Chấm Công & Công Tác Phí")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#002A8F"))
                .multilineTextAlignment(.center)

            Text("Chức năng chấm công GPS hiện chỉ áp dụng cho Quản trị viên, HelpDesk và Nhân viên / Kỹ thuật viên thuộc phòng ban tiếp nhận & xử lý sự cố kỹ thuật.")
                .font(.system(size: 13.5))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            Button(action: onBack) {
                Text("Quay lại Trang chủ")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#002A8F"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#002A8F"), lineWidth: 1.5))
            }
            Spacer()
        }
        .padding(32)
    }

    // Helpers for shift colors
    private func shiftIconName(_ shift: String) -> String {
        switch shift {
        case "SHIFT_1": return "sun.horizon.fill"
        case "SHIFT_2": return "sun.max.fill"
        case "NIGHT", "SHIFT_3": return "moon.fill"
        default: return "briefcase.fill"
        }
    }

    private func shiftColor(_ shift: String) -> Color {
        switch shift {
        case "SHIFT_1": return Color(hex: "#D97706")
        case "SHIFT_2": return Color(hex: "#2563EB")
        case "NIGHT", "SHIFT_3": return Color(hex: "#7C3AED")
        default: return Color(hex: "#059669")
        }
    }

    private func shiftBadgeBg(_ shift: String) -> Color {
        switch shift {
        case "SHIFT_1": return Color(hex: "#FEF3C7")
        case "SHIFT_2": return Color(hex: "#DBEAFE")
        case "NIGHT", "SHIFT_3": return Color(hex: "#EDE9FE")
        default: return Color(hex: "#DCFCE7")
        }
    }
}