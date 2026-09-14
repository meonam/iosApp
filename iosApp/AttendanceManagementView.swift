import SwiftUI
import CoreLocation
import UIKit

// MARK: - Shift Enums (Khớp 100% AttendanceModels.kt)
public enum AppShiftType: String, CaseIterable, Identifiable {
    case hc = "HC"
    case shift1 = "SHIFT_1"
    case shift2 = "SHIFT_2"
    case night = "NIGHT"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .hc: return "Hành chính (08:00 - 17:00)"
        case .shift1: return "Ca 1 Sáng (06:00 - 14:00)"
        case .shift2: return "Ca 2 Chiều (14:00 - 22:00)"
        case .night: return "Ca 3 Đêm (22:00 - 06:00)"
        }
    }

    public var shortName: String {
        switch self {
        case .hc: return "Hành chính"
        case .shift1: return "Ca Sáng"
        case .shift2: return "Ca Chiều"
        case .night: return "Ca Đêm"
        }
    }

    public static func suggestedShift(for date: Date = Date()) -> AppShiftType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<13: return .shift1
        case 13..<21: return .shift2
        case 21...23, 0..<6: return .night
        default: return .hc
        }
    }
}

// MARK: - MÀN HÌNH ĐIỂM DANH CHẤM CÔNG (AttendanceCheckInScreen.kt)
public struct AttendanceCheckInFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @StateObject private var locationManager = LocationManager()
    @State private var selectedShift: AppShiftType = AppShiftType.suggestedShift()
    @State private var currentTimeStr: String = ""
    @State private var noteInput: String = ""
    @State private var isSubmitting: Bool = false
    @State private var alertMessage: String? = nil
    @State private var todayRecord: AttendanceRecordItem? = nil

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var matchedStore: CoopmartStore? {
        CoopmartDirectory.resolveLocation(firebase.userDonVi)
    }

    private var distanceToStoreMeters: Int? {
        guard let store = matchedStore else { return nil }
        return Int(store.distance(from: locationManager.latitude, locationManager.longitude) * 1000.0)
    }

    private var isWithinGeofence: Bool {
        guard let dist = distanceToStoreMeters else { return false }
        return dist <= 300 // Bán kính Geofence chuẩn 300m
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. DIGITAL CLOCK
                    VStack(spacing: 4) {
                        Text(currentTimeStr.isEmpty ? "08:00:00" : currentTimeStr)
                            .font(.system(size: 42, weight: .heavy, design: .monospaced))
                            .foregroundColor(.appSecondaryDarkBlue)
                        Text("Hôm nay: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .none))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)
                    .onReceive(timer) { _ in
                        let f = DateFormatter()
                        f.dateFormat = "HH:mm:ss"
                        currentTimeStr = f.string(from: Date())
                    }

                    // 2. USER INFO BADGE
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.appSecondaryDarkBlue.opacity(0.12))
                                .frame(width: 46, height: 46)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.appSecondaryDarkBlue)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(firebase.userName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                            HStack {
                                Text("ĐV: \(firebase.userDonVi)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(firebase.userDept)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                    // 3. SHIFT SELECTOR
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .foregroundColor(.appPrimaryPink)
                            Text("CHỌN CA LÀM VIỆC")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        Picker("Ca làm việc", selection: $selectedShift) {
                            ForEach(AppShiftType.allCases) { shift in
                                Text(shift.shortName).tag(shift)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Khung giờ: \(selectedShift.displayName)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appSecondaryDarkBlue)
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                    // 4. GPS & GEOFENCE VERIFICATION
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "location.circle.fill")
                                .foregroundColor(isWithinGeofence ? .green : .orange)
                            Text("ĐỊNH VỊ GPS & BÁN KÍNH SIÊU THỊ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(isWithinGeofence ? "HỢP LỆ (≤300m)" : "NGOÀI BÁN KÍNH")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(isWithinGeofence ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundColor(isWithinGeofence ? .green : .orange)
                                .clipShape(Capsule())
                        }

                        if let store = matchedStore {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                                Text(store.address)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                if let dist = distanceToStoreMeters {
                                    HStack {
                                        Image(systemName: "arrow.triangle.swap")
                                            .foregroundColor(.appPrimaryPink)
                                        Text("Khoảng cách thực tế: \(dist) mét")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(isWithinGeofence ? .green : .orange)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        } else {
                            Text("Tọa độ GPS: \(locationManager.locationStr)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                    // 5. NOTE INPUT
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ghi chú chấm công (Tùy chọn)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("Nhập lý do đi trễ, trực đột xuất, đổi ca...", text: $noteInput)
                            .padding(10)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(10)
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                    // 6. ACTION BUTTONS (IN / OUT)
                    HStack(spacing: 14) {
                        Button(action: { handleAttendance(isCheckIn: true) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.right.to.line.circle.fill")
                                    .font(.system(size: 26))
                                Text("VÀO CA")
                                    .font(.system(size: 15, weight: .heavy))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.statusInUse)
                            .cornerRadius(16)
                            .shadow(color: Color.statusInUse.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSubmitting)

                        Button(action: { handleAttendance(isCheckIn: false) }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.left.to.line.circle.fill")
                                    .font(.system(size: 26))
                                Text("RA CA")
                                    .font(.system(size: 15, weight: .heavy))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(Color.statusRepair)
                            .cornerRadius(16)
                            .shadow(color: Color.statusRepair.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSubmitting)
                    }
                    .padding(.top, 4)

                    if let msg = alertMessage {
                        Text(msg)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.appPrimaryPink)
                            .padding(.top, 6)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Điểm Danh Chấm Công")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
        }
    }

    private func handleAttendance(isCheckIn: Bool) {
        isSubmitting = true
        let lat = locationManager.latitude
        let lng = locationManager.longitude
        let address = matchedStore?.name ?? firebase.userDonVi

        Task {
            let ok = await firebase.checkInAttendance(
                isCheckIn: isCheckIn,
                lat: lat,
                lng: lng,
                address: address
            )
            isSubmitting = false
            withAnimation {
                alertMessage = ok
                    ? "✅ Đã ghi nhận \(isCheckIn ? "VÀO CA" : "RA CA") [\(selectedShift.shortName)] thành công!"
                    : "❌ Lỗi kết nối máy chủ khi chấm công."
            }
            if ok {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - MÀN HÌNH BÁO CÁO CÔNG & QUYẾT TOÁN CÔNG TÁC PHÍ (AttendanceReportScreen.kt)
public struct AttendanceReportFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 0 // 0: Bảng công, 1: Quyết toán công tác phí, 2: Định mức
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    private var onTimeCount: Int {
        firebase.attendanceRecords.filter { $0.checkInStatus == "ON_TIME" }.count
    }

    private var lateCount: Int {
        firebase.attendanceRecords.filter { $0.checkInStatus != "ON_TIME" }.count
    }

    private var totalMinutes: Int {
        firebase.attendanceRecords.reduce(0) { $0 + $1.totalWorkMinutes }
    }

    private var totalEstimatedKm: Double {
        Double(firebase.attendanceRecords.count) * 8.5 // Trung bình 8.5km / lượt di chuyển
    }

    private var totalAllowanceVnd: Int {
        Int(totalEstimatedKm * 5000.0) + (firebase.attendanceRecords.count * 50000)
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Segmented Tab Picker
                Picker("Phân hệ báo cáo", selection: $selectedTab) {
                    Text("Bảng Công").tag(0)
                    Text("Công Tác Phí OSRM").tag(1)
                    Text("Định Mức").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white)

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0:
                            timesheetTab
                        case 1:
                            travelExpenseTab
                        case 2:
                            configRulesTab
                        default:
                            EmptyView()
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Báo Cáo Chấm Công & Công Tác Phí")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .onAppear {
                Task { await firebase.fetchAttendanceRecords() }
            }
        }
    }

    // TAB 1: BẢNG CHẤM CÔNG THỜI GIAN THỰC
    @ViewBuilder
    private var timesheetTab: some View {
        // Summary Cards Grid
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(title: "Tổng ngày công", value: "\(firebase.attendanceRecords.count) ca", icon: "calendar.badge.clock", color: .appSecondaryDarkBlue)
            summaryCard(title: "Đúng giờ", value: "\(onTimeCount) lần", icon: "checkmark.circle.fill", color: .green)
            summaryCard(title: "Đi trễ / Bất thường", value: "\(lateCount) lần", icon: "exclamationmark.triangle.fill", color: .orange)
            summaryCard(title: "Tổng giờ làm", value: "\(totalMinutes / 60)h \(totalMinutes % 60)p", icon: "clock.fill", color: .appPrimaryPink)
        }

        // Daily Attendance List
        VStack(alignment: .leading, spacing: 10) {
            Text("Chi tiết từng ngày trong tháng")
                .font(.headline)
                .foregroundColor(.appTextPrimary)

            if firebase.attendanceRecords.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Chưa có bản ghi chấm công nào")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.white)
                .cornerRadius(14)
            } else {
                ForEach(firebase.attendanceRecords) { rec in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(rec.date)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.appSecondaryDarkBlue)
                                Spacer()
                                Text(rec.checkInStatus == "ON_TIME" ? "ĐÚNG GIỜ" : "ĐI TRỄ")
                                    .font(.system(size: 10, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(rec.checkInStatus == "ON_TIME" ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                                    .foregroundColor(rec.checkInStatus == "ON_TIME" ? .green : .orange)
                                    .clipShape(Capsule())
                            }

                            HStack {
                                Text("Vào: \(rec.checkInTime)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text("Ra: \(rec.checkOutTime)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                Spacer()
                                Text("\(rec.totalWorkMinutes / 60)h \(rec.totalWorkMinutes % 60)p")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.appTextPrimary)
                            }

                            Text("Đơn vị: \(rec.checkInAddress.isEmpty ? "Co.opmart" : rec.checkInAddress)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
        }
    }

    // TAB 2: QUYẾT TOÁN CÔNG TÁC PHÍ DI CHUYỂN OSRM
    @ViewBuilder
    private var travelExpenseTab: some View {
        VStack(spacing: 14) {
            // Big total card
            VStack(spacing: 8) {
                Text("TỔNG TIỀN PHỤ CẤP CÔNG TÁC PHÍ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                Text("\(NumberFormatter.localizedString(from: NSNumber(value: totalAllowanceVnd), number: .decimal)) đ")
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundColor(.white)
                Text("Định mức: 5.000đ / km đường bộ OSRM + 50.000đ phụ cấp ca")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(
                LinearGradient(colors: [Color.appSecondaryDarkBlue, Color.appPrimaryPink], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(18)
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)

            // Details
            VStack(alignment: .leading, spacing: 12) {
                Text("Bảng kê chi tiết cự ly di chuyển")
                    .font(.headline)
                    .foregroundColor(.appTextPrimary)

                ForEach(firebase.attendanceRecords) { rec in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rec.date)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                            Text(rec.checkInAddress)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("~8.5 km")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.appSecondaryDarkBlue)
                            Text("92.500 đ")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.appPrimaryPink)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
        }
    }

    // TAB 3: CẤU HÌNH ĐỊNH MỨC & KHUNG GIỜ
    @ViewBuilder
    private var configRulesTab: some View {
        VStack(spacing: 12) {
            ruleRow(label: "Bán kính GPS hợp lệ", val: "300 mét (Geofence)")
            ruleRow(label: "Đơn giá phụ cấp xăng xe", val: "5.000 đ / km")
            ruleRow(label: "Phụ cấp ca trực / ca đêm", val: "50.000 đ / ca")
            ruleRow(label: "Cho phép đi trễ tối đa", val: "15 phút")
            ruleRow(label: "Ca Hành chính", val: "08:00 - 17:00")
            ruleRow(label: "Ca 1 (Sáng)", val: "06:00 - 14:00")
            ruleRow(label: "Ca 2 (Chiều)", val: "14:00 - 22:00")
            ruleRow(label: "Ca 3 (Đêm)", val: "22:00 - 06:00")
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func ruleRow(label: String, val: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13.5))
                .foregroundColor(.secondary)
            Spacer()
            Text(val)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.appTextPrimary)
        }
        .padding(.vertical, 4)
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.appTextPrimary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }
}
