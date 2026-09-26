import SwiftUI
import UIKit

// MARK: - Shift Code Enums & Colors (Khớp 100% Android ShiftCode.kt)
public enum KtvShiftCode: String, CaseIterable, Identifiable {
    case sang = "S"           // Sáng
    case chieu = "C"          // Chiều
    case hanhChanh = "HC"     // Hành chính
    case truc = "TR"          // Trực 24/7
    case congTac = "CT"       // Công tác
    case nghiCa = "NC"        // Nghỉ ca
    case phep = "P"           // Nghỉ phép
    case hop = "H"            // Họp
    case nghiMat = "NM"       // Nghỉ mát (Android: NM)
    case nghiLe = "NL"        // Nghỉ lễ (Android: NL)

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .sang: return "Sáng (06-14h)"
        case .chieu: return "Chiều (14-22h)"
        case .hanhChanh: return "Hành chính"
        case .nghiCa: return "Nghỉ ca"
        case .phep: return "Nghỉ phép"
        case .congTac: return "Công tác"
        case .truc: return "Trực 24/7"
        case .hop: return "Họp"
        case .nghiMat: return "Nghỉ mát"
        case .nghiLe: return "Nghỉ lễ"
        }
    }

    public var shortName: String {
        switch self {
        case .sang: return "S"
        case .chieu: return "C"
        case .hanhChanh: return "HC"
        case .nghiCa: return "NC"
        case .phep: return "P"
        case .congTac: return "CT"
        case .truc: return "TR"
        case .hop: return "H"
        case .nghiMat: return "NM"
        case .nghiLe: return "NL"
        }
    }

    public var color: Color {
        switch self {
        case .sang: return Color(hex: "#1565C0")       // Blue
        case .chieu: return Color(hex: "#E65100")      // Orange
        case .hanhChanh: return Color(hex: "#00695C")  // Teal
        case .nghiCa: return Color(hex: "#757575")     // Gray
        case .phep: return Color(hex: "#2E7D32")       // Green
        case .congTac: return Color(hex: "#6A1B9A")    // Purple
        case .truc: return Color(hex: "#C62828")       // Red
        case .hop: return Color(hex: "#F9A825")        // Amber
        case .nghiMat: return Color(hex: "#00838F")    // Cyan (rest/vacation)
        case .nghiLe: return Color(hex: "#558B2F")     // Light green (holiday)
        }
    }
}

public struct KtvScheduleEntry: Identifiable {
    public var id: String { email }
    public var email: String
    public var name: String
    public var mnv: String
    public var donVi: String
    public var shifts: [String: String] // ["mon": "SANG", "tue": "CHIEU", ...]
}

// MARK: - MÀN HÌNH LỊCH TRỰC & PHÂN CA KTV (Khớp 100% Android ShiftScheduleScreen.kt)
public struct ShiftScheduleFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var weekOffset: Int = 0 // 0 = tuần hiện tại, -1 = tuần trước, +1 = tuần sau
    @State private var selectedUnitFilter: String = "ALL"
    @State private var searchQuery: String = ""

    // State chọn ca trực để đổi
    @State private var editingCell: (ktvEmail: String, dayKey: String, ktvName: String, currentShift: String)? = nil
    @State private var localScheduleData: [String: [String: String]] = [:] // email -> [dayKey: shiftCode]
    @State private var isLoading: Bool = false
    @State private var saveSuccessToast: Bool = false

    let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    let dayHeaders = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    private var canEditShift: Bool {
        firebase.isAdmin || firebase.isHelpDesk
    }

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    // Danh sách KTV (kết hợp allUsersList với role KTV + KTV mặc định của Saigon Co.op)
    private var ktvList: [KtvScheduleEntry] {
        var baseList: [KtvScheduleEntry] = [
            KtvScheduleEntry(email: "phucdh@sgcoop.com", name: "Dam Huu Phuc", mnv: "26063", donVi: "IT TẬP TRUNG", shifts: [:]),
            KtvScheduleEntry(email: "huydq@sgcoop.com", name: "Dinh Quoc Huy", mnv: "33430", donVi: "IT TẬP TRUNG", shifts: [:]),
            KtvScheduleEntry(email: "linhnd@sgcoop.com", name: "Ngo Duy Linh", mnv: "43144", donVi: "IT TẬP TRUNG", shifts: [:]),
            KtvScheduleEntry(email: "duchna@sgcoop.com", name: "Huỳnh Nguyễn Anh Đức", mnv: "NVDUCHN", donVi: "Co.opmart Cần Thơ", shifts: [:]),
            KtvScheduleEntry(email: "khanh-ht@sgcoop.com", name: "Hồ Thân Khánh", mnv: "35713", donVi: "IT Bình Dương", shifts: [:]),
            KtvScheduleEntry(email: "sangnt@sgcoop.com", name: "Nguyen Thanh Sang", mnv: "19842", donVi: "IT TẬP TRUNG", shifts: [:]),
            KtvScheduleEntry(email: "hieunt@sgcoop.com", name: "Nguyễn Trung Hiếu", mnv: "24979", donVi: "HelpDesk", shifts: [:])
        ]

        // Merge users from firebase.allUsersList
        for u in firebase.allUsersList {
            let r = u.role.lowercased()
            if r.contains("ktv") || r.contains("it") || r.contains("tech") || r.contains("helpdesk") {
                if !baseList.contains(where: { $0.email == u.email }) {
                    baseList.append(KtvScheduleEntry(
                        email: u.email,
                        name: u.fullName,
                        mnv: u.maNhanVien.isEmpty ? "NV\(u.email.prefix(4).uppercased())" : u.maNhanVien,
                        donVi: u.donVi.isEmpty ? "Co.opmart" : u.donVi,
                        shifts: [:]
                    ))
                }
            }
        }

        // Apply local schedule overrides
        return baseList.map { item in
            var mapped = item
            if let customShifts = localScheduleData[item.email] {
                mapped.shifts = customShifts
            } else {
                // Default shift patterns
                mapped.shifts = [
                    "mon": "SANG", "tue": "SANG", "wed": "CHIEU",
                    "thu": "CHIEU", "fri": "HANH_CHANH", "sat": "TRUC", "sun": "NGHI_CA"
                ]
            }
            return mapped
        }
    }

    var filteredKtvs: [KtvScheduleEntry] {
        ktvList.filter { k in
            let matchSearch = searchQuery.isEmpty ||
                k.name.localizedCaseInsensitiveContains(searchQuery) ||
                k.mnv.localizedCaseInsensitiveContains(searchQuery) ||
                k.donVi.localizedCaseInsensitiveContains(searchQuery)
            let matchUnit = selectedUnitFilter == "ALL" || k.donVi.localizedCaseInsensitiveContains(selectedUnitFilter)
            return matchSearch && matchUnit
        }
    }

    var weekTitle: String {
        let cal = Calendar.current
        var comp = DateComponents()
        comp.weekOfYear = weekOffset
        let targetDate = cal.date(byAdding: comp, to: Date()) ?? Date()
        let weekNum = cal.component(.weekOfYear, from: targetDate)
        let year = cal.component(.year, from: targetDate)
        return "Tuần \(weekNum), Năm \(year)"
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. Week Selector Bar
                HStack {
                    Button(action: { weekOffset -= 1; loadWeekData() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Tuần trước")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.appSecondaryDarkBlue)
                        .cornerRadius(8)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(weekTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.appSecondaryDarkBlue)
                        Text(weekDateRangeString())
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { weekOffset += 1; loadWeekData() }) {
                        HStack(spacing: 4) {
                            Text("Tuần sau")
                            Image(systemName: "chevron.right")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.appSecondaryDarkBlue)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))

                // 2. Search & Unit Filter
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Tìm KTV, mã NV, địa bàn...", text: $searchQuery)
                            .font(.system(size: 13))
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                    Menu {
                        Button("Tất cả đơn vị") { selectedUnitFilter = "ALL" }
                        Button("IT TẬP TRUNG") { selectedUnitFilter = "IT TẬP TRUNG" }
                        Button("Cần Thơ") { selectedUnitFilter = "Cần Thơ" }
                        Button("Bình Dương") { selectedUnitFilter = "Bình Dương" }
                        Button("HelpDesk") { selectedUnitFilter = "HelpDesk" }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedUnitFilter == "ALL" ? "Đơn vị" : selectedUnitFilter)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.appSecondaryDarkBlue.opacity(0.1))
                        .foregroundColor(.appSecondaryDarkBlue)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // 3. Matrix Table
                scheduleMatrixTable

                // 4. Legend Bar
                shiftLegendBar
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Lịch Trực & Phân Ca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .sheet(item: Binding(
                get: { editingCell.map { ShiftEditTarget(ktvEmail: $0.ktvEmail, dayKey: $0.dayKey, ktvName: $0.ktvName, currentShift: $0.currentShift) } },
                set: { if $0 == nil { editingCell = nil } }
            )) { target in
                shiftPickerSheet(for: target)
            }
            .onAppear {
                loadWeekData()
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Schedule Matrix Table
    private var scheduleMatrixTable: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Table Header
                HStack(spacing: 0) {
                    Text("KỸ THUẬT VIÊN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 140, alignment: .leading)
                        .padding(.leading, 8)

                    ForEach(0..<7, id: \.self) { idx in
                        Text(dayHeaders[idx])
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 52, alignment: .center)
                    }
                }
                .padding(.vertical, 10)
                .background(Color.appSecondaryDarkBlue)

                // Table Rows
                ForEach(filteredKtvs) { ktv in
                    HStack(spacing: 0) {
                        // KTV Info Column
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ktv.name)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(ktv.mnv)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(.appPrimaryPink)
                                Text("• \(ktv.donVi)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .frame(width: 140, alignment: .leading)
                        .padding(.leading, 8)
                        .padding(.vertical, 8)

                        // 7 Day Cells
                        ForEach(0..<7, id: \.self) { dayIdx in
                            let dKey = dayKeys[dayIdx]
                            let shiftRaw = ktv.shifts[dKey] ?? "HANH_CHANH"
                            let shift = KtvShiftCode(rawValue: shiftRaw) ?? .hanhChanh

                            Button(action: {
                                if canEditShift {
                                    editingCell = (ktvEmail: ktv.email, dayKey: dKey, ktvName: ktv.name, currentShift: shiftRaw)
                                }
                            }) {
                                ZStack(alignment: .topTrailing) {
                                    Text(shift.shortName)
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 46, height: 28)
                                        .background(shift.color)
                                        .cornerRadius(6)
                                    if !canEditShift {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 7))
                                            .foregroundColor(.white.opacity(0.75))
                                            .padding(2)
                                    }
                                }
                            }
                            .frame(width: 52, alignment: .center)
                        }
                    }
                    .background(Color.white)
                    Divider()
                }
            }
        }
    }

    // MARK: - Shift Legend Bar
    private var shiftLegendBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(KtvShiftCode.allCases) { sc in
                    HStack(spacing: 4) {
                        Circle().fill(sc.color).frame(width: 8, height: 8)
                        Text(sc.shortName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.appCardBorder), alignment: .top)
    }

    // MARK: - Shift Picker Sheet
    @ViewBuilder
    private func shiftPickerSheet(for target: ShiftEditTarget) -> some View {
        NavigationView {
            List {
                Section(header: Text("KỸ THUẬT VIÊN & NGÀY TRỰC")) {
                    Text(target.ktvName).font(.headline.bold())
                    Text("Ngày: \(target.dayKey.uppercased()) trong tuần")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("CHỌN CA TRỰC MỚI")) {
                    ForEach(KtvShiftCode.allCases) { code in
                        Button(action: {
                            updateShift(email: target.ktvEmail, dayKey: target.dayKey, newShift: code.rawValue)
                            editingCell = nil
                        }) {
                            HStack(spacing: 12) {
                                Circle().fill(code.color).frame(width: 14, height: 14)
                                Text(code.label)
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                if target.currentShift == code.rawValue {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.appPrimaryPink)
                                        .font(.headline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Đổi Ca Trực")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { editingCell = nil }
                }
            }
        }
    }

    private func updateShift(email: String, dayKey: String, newShift: String) {
        var current = localScheduleData[email] ?? [:]
        current[dayKey] = newShift
        localScheduleData[email] = current

        Task {
            let weekId = isoWeekId(offset: weekOffset)
            _ = await firebase.saveShiftSchedule(weekId: weekId, ktvEmail: email, dayKey: dayKey, shiftCode: newShift)
        }
    }

    private func loadWeekData() {
        Task {
            let weekId = isoWeekId(offset: weekOffset)
            let data = await firebase.fetchShiftSchedules(weekId: weekId)
            if !data.isEmpty {
                localScheduleData = data
            }
        }
    }

    private func weekDateRangeString() -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let target = cal.date(byAdding: .weekOfYear, value: weekOffset, to: Date()) ?? Date()
        let weekday = cal.component(.weekday, from: target)
        let daysToMonday = (weekday == 1 ? -6 : 2 - weekday)
        guard let monday = cal.date(byAdding: .day, value: daysToMonday, to: target),
              let sunday = cal.date(byAdding: .day, value: 6, to: monday) else { return "" }
        let df = DateFormatter()
        df.dateFormat = "dd/MM"
        return "\(df.string(from: monday)) - \(df.string(from: sunday))"
    }

    private func isoWeekId(offset: Int) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let target = cal.date(byAdding: .weekOfYear, value: offset, to: Date()) ?? Date()
        let week = cal.component(.weekOfYear, from: target)
        let year = cal.component(.yearForWeekOfYear, from: target)
        return String(format: "%04d-W%02d", year, week)
    }
}

// Identifiable helper for Sheet
struct ShiftEditTarget: Identifiable {
    var id: String { "\(ktvEmail)_\(dayKey)" }
    let ktvEmail: String
    let dayKey: String
    let ktvName: String
    let currentShift: String
}
