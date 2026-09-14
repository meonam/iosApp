import SwiftUI
import UIKit

// MARK: - ASSET STATISTICS FULL VIEW (Matches Android ThongkeScreen.kt)
struct AssetStatisticsFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    // Filter states
    @State private var selectedStatusFilter: String = "TẤT CẢ" // "TẤT CẢ", "SỬ DỤNG", "BẢO HÀNH", "CHO MƯỢN", "THANH LÝ"
    @State private var searchQuery: String = ""
    @State private var selectedTab: Int = 0 // 0: Theo Siêu thị / Đơn vị, 1: Theo Loại thiết bị
    @State private var expandedKeys: Set<String> = []

    // Print sheet
    @State private var showPrintSheet: Bool = false

    // Swipe back offset
    @State private var dragOffsetX: CGFloat = 0

    // Base devices filtered by role & permissions
    var baseDevices: [DeviceItem] {
        let role = firebase.userRole.lowercased()
        let userDept = firebase.userDept.trimmingCharacters(in: .whitespacesAndNewlines)
        let userUnit = firebase.userDonVi.trimmingCharacters(in: .whitespacesAndNewlines)

        if role == "admin" {
            return firebase.devices
        } else if role == "phongban" || role == "quanly" {
            return firebase.devices.filter { dev in
                let devDept = dev.department
                let matchDept = !userDept.isEmpty && (devDept.localizedCaseInsensitiveContains(userDept) || userDept.localizedCaseInsensitiveContains(devDept))
                let matchUnit = userUnit.isEmpty || userUnit.lowercased() == "all" || dev.unit.localizedCaseInsensitiveContains(userUnit)
                return matchDept && matchUnit
            }
        } else {
            return firebase.devices.filter { dev in
                let matchDept = dev.department.localizedCaseInsensitiveContains(userDept)
                let matchUnit = userUnit.isEmpty || userUnit.lowercased() == "all" || dev.unit.localizedCaseInsensitiveContains(userUnit)
                return matchDept && matchUnit
            }
        }
    }

    // Status counts
    var totalCount: Int { baseDevices.count }
    var activeCount: Int {
        baseDevices.filter {
            let s = $0.status.lowercased()
            return s.contains("sử dụng") || s.contains("trong kho") || s.contains("sẵn sàng") || s.contains("bình thường") || s.contains("đang dùng")
        }.count
    }
    var repairCount: Int {
        baseDevices.filter {
            let s = $0.status.lowercased()
            return s.contains("bảo hành") || s.contains("sửa chữa") || s.contains("hỏng") || s.contains("xử lý")
        }.count
    }
    var loanCount: Int {
        baseDevices.filter {
            let s = $0.status.lowercased()
            return s.contains("mượn")
        }.count
    }
    var liquidateCount: Int {
        baseDevices.filter {
            let s = $0.status.lowercased()
            return s.contains("thanh lý") || s.contains("hủy")
        }.count
    }

    // Devices filtered by status & search
    var filteredDevices: [DeviceItem] {
        let statusFiltered: [DeviceItem]
        switch selectedStatusFilter {
        case "SỬ DỤNG":
            statusFiltered = baseDevices.filter {
                let s = $0.status.lowercased()
                return s.contains("sử dụng") || s.contains("trong kho") || s.contains("sẵn sàng") || s.contains("bình thường") || s.contains("đang dùng")
            }
        case "BẢO HÀNH":
            statusFiltered = baseDevices.filter {
                let s = $0.status.lowercased()
                return s.contains("bảo hành") || s.contains("sửa chữa") || s.contains("hỏng") || s.contains("xử lý")
            }
        case "CHO MƯỢN":
            statusFiltered = baseDevices.filter { $0.status.lowercased().contains("mượn") }
        case "THANH LÝ":
            statusFiltered = baseDevices.filter {
                let s = $0.status.lowercased()
                return s.contains("thanh lý") || s.contains("hủy")
            }
        default:
            statusFiltered = baseDevices
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return statusFiltered }
        return statusFiltered.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.id.localizedCaseInsensitiveContains(q) ||
            $0.category.localizedCaseInsensitiveContains(q) ||
            $0.unit.localizedCaseInsensitiveContains(q) ||
            $0.department.localizedCaseInsensitiveContains(q)
        }
    }

    // Breakdown by Unit / Co.opmart
    var breakdownByUnit: [(unit: String, devices: [DeviceItem])] {
        let grouped = Dictionary(grouping: filteredDevices) { dev in
            dev.unit.isEmpty ? "Toàn Công ty" : dev.unit
        }
        return grouped.map { (unit: $0.key, devices: $0.value) }
            .sorted { $0.devices.count > $1.devices.count }
    }

    // Breakdown by Device Type
    var breakdownByType: [(type: String, devices: [DeviceItem])] {
        let grouped = Dictionary(grouping: filteredDevices) { dev in
            dev.category.isEmpty ? "Chưa phân loại" : dev.category
        }
        return grouped.map { (type: $0.key, devices: $0.value) }
            .sorted { $0.devices.count > $1.devices.count }
    }

    // Financial calculations
    var estimatedTotalCost: Double {
        // Average value estimation per device type if not set
        filteredDevices.reduce(0.0) { sum, dev in
            let cat = dev.category.lowercased()
            let val: Double
            if cat.contains("pos") { val = 18_000_000 }
            else if cat.contains("laptop") { val = 15_000_000 }
            else if cat.contains("pc") || cat.contains("máy tính") { val = 12_000_000 }
            else if cat.contains("in") || cat.contains("printer") { val = 4_500_000 }
            else if cat.contains("quét") || cat.contains("scanner") { val = 2_500_000 }
            else if cat.contains("ups") { val = 1_800_000 }
            else { val = 3_000_000 }
            return sum + val
        }
    }

    var estimatedDepreciatedValue: Double {
        // 60% average remaining value
        estimatedTotalCost * 0.58
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar Header
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Tìm siêu thị, loại máy, mã tài sản...", text: $searchQuery)
                                .foregroundColor(.white)
                                .tint(.white)
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.appTopBar)

                    ScrollView {
                        VStack(spacing: 14) {
                            // 1. HERO TOTAL CARD
                            heroTotalCard

                            // 2. STATUS CHIPS HORIZONTAL ROW
                            statusFilterChipsBar

                            // 3. DYNAMIC STATUS DETAIL CARD
                            if selectedStatusFilter != "TẤT CẢ" {
                                dynamicStatusCard
                            }

                            // 4. FINANCIAL SUMMARY CARD
                            financialSummaryCard

                            // 5. BREAKDOWN VIEW SELECTOR TABS
                            tabSelectorBar

                            // 6. DETAILED ACCORDION LIST
                            if selectedTab == 0 {
                                unitBreakdownList
                            } else {
                                typeBreakdownList
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(14)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onDismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Trở lại")
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("THỐNG KÊ TÀI SẢN THIẾT BỊ")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showPrintSheet = true }) {
                        Image(systemName: "printer.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffsetX = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        onDismiss()
                    }
                    dragOffsetX = 0
                }
        )
        .sheet(isPresented: $showPrintSheet) {
            PrintScreenView(onDismiss: { showPrintSheet = false })
        }
    }

    // MARK: - 1. HERO TOTAL CARD
    private var heroTotalCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TỔNG THIẾT BỊ HỆ THỐNG QUẢN LÝ")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(totalCount)")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                    Text("thiết bị")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }

                Text(firebase.userRole.lowercased() == "admin" ? "Phạm vi: Toàn chuỗi siêu thị Saigon Co.op" : "Phạm vi: Đơn vị / Phòng ban được phân quyền")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer()

            Button(action: { showPrintSheet = true }) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimaryPink)
                        .frame(width: 44, height: 44)
                    Image(systemName: "printer.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .background(Color.appSecondaryDarkBlue)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - 2. STATUS CHIPS BAR
    private var statusFilterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                statusChip(key: "TẤT CẢ", title: "Tất cả (\(totalCount))", color: Color.appSecondaryDarkBlue)
                statusChip(key: "SỬ DỤNG", title: "✅ Sử dụng (\(activeCount))", color: Color(hex: "#16A34A"))
                statusChip(key: "BẢO HÀNH", title: "🛡️ Bảo hành (\(repairCount))", color: Color(hex: "#EA580C"))
                statusChip(key: "CHO MƯỢN", title: "🤝 Cho mượn (\(loanCount))", color: Color(hex: "#2563EB"))
                statusChip(key: "THANH LÝ", title: "🗑️ Thanh lý (\(liquidateCount))", color: Color(hex: "#DC2626"))
            }
            .padding(.vertical, 2)
        }
    }

    private func statusChip(key: String, title: String, color: Color) -> some View {
        let isSel = selectedStatusFilter == key
        return Button(action: {
            withAnimation(.spring()) {
                selectedStatusFilter = isSel && key != "TẤT CẢ" ? "TẤT CẢ" : key
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSel ? .bold : .medium))
                .foregroundColor(isSel ? .white : Color.appSecondaryDarkBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSel ? Color.appPrimaryPink : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSel ? Color.appPrimaryPink : Color(hex: "#E2E8F0"), lineWidth: 1)
                )
        }
    }

    // MARK: - 3. DYNAMIC STATUS DETAIL CARD
    private var dynamicStatusCard: some View {
        let (title, count, color, icon, desc) = getStatusDetails()
        let percent = totalCount > 0 ? (count * 100 / totalCount) : 0

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
                HStack(spacing: 6) {
                    Text("\(count) máy")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("(\(percent)% tổng hệ thống)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.06))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func getStatusDetails() -> (title: String, count: Int, color: Color, icon: String, desc: String) {
        switch selectedStatusFilter {
        case "SỬ DỤNG":
            return ("THIẾT BỊ HOẠT ĐỘNG TỐT", activeCount, Color(hex: "#16A34A"), "checkmark.circle.fill", "Máy móc đang vận hành ổn định phục vụ bán hàng và nghiệp vụ.")
        case "BẢO HÀNH":
            return ("THIẾT BỊ ĐANG SỬA CHỮA / BẢO HÀNH", repairCount, Color(hex: "#EA580C"), "wrench.and.screwdriver.fill", "Đang chờ KTV xử lý hoặc bảo hành tại hãng.")
        case "CHO MƯỢN":
            return ("THIẾT BỊ ĐIỀU ĐỘNG CHO MƯỢN", loanCount, Color(hex: "#2563EB"), "arrow.left.arrow.right", "Được luân chuyển tạm thời giữa các chi nhánh hoặc bộ phận.")
        default:
            return ("THIẾT BỊ ĐÃ THANH LÝ / HỦY", liquidateCount, Color(hex: "#DC2626"), "trash.fill", "Tài sản hết khấu hao, hư hỏng nặng hoặc đã làm thủ tục hủy.")
        }
    }

    // MARK: - 4. FINANCIAL SUMMARY CARD
    private var financialSummaryCard: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(Color.appPrimaryPink)
                Text("ƯỚC TÍNH GIÁ TRỊ TÀI SẢN & KHẤU HAO")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
            }

            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tổng nguyên giá")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(formatCurrency(estimatedTotalCost))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Giá trị còn lại (Ước tính 58%)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(formatCurrency(estimatedDepreciatedValue))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#16A34A"))
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
        )
    }

    // MARK: - 5. TAB SELECTOR BAR
    private var tabSelectorBar: some View {
        HStack(spacing: 0) {
            Button(action: { selectedTab = 0 }) {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                    Text("Theo Siêu Thị Co.opmart (\(breakdownByUnit.count))")
                }
                .font(.system(size: 12, weight: selectedTab == 0 ? .bold : .medium))
                .foregroundColor(selectedTab == 0 ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == 0 ? Color.appPrimaryPink.opacity(0.08) : Color.clear)
            }

            Divider().frame(height: 20)

            Button(action: { selectedTab = 1 }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Theo Loại Thiết Bị (\(breakdownByType.count))")
                }
                .font(.system(size: 12, weight: selectedTab == 1 ? .bold : .medium))
                .foregroundColor(selectedTab == 1 ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == 1 ? Color.appPrimaryPink.opacity(0.08) : Color.clear)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
        )
    }

    // MARK: - 6A. BREAKDOWN BY UNIT LIST
    private var unitBreakdownList: some View {
        LazyVStack(spacing: 10) {
            ForEach(breakdownByUnit, id: \.unit) { item in
                let isExpanded = expandedKeys.contains(item.unit)
                let pct = totalCount > 0 ? Double(item.devices.count) / Double(totalCount) : 0.0

                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring()) {
                            if isExpanded { expandedKeys.remove(item.unit) }
                            else { expandedKeys.insert(item.unit) }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "storefront.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .font(.system(size: 14))
                                Text(item.unit)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.devices.count) máy")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                            }

                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(hex: "#F1F5F9")).frame(height: 6)
                                    Capsule().fill(Color.appSecondaryDarkBlue).frame(width: geo.size.width * CGFloat(pct), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(14)
                    }

                    if isExpanded {
                        Divider()

                        // Sub breakdown by category
                        let subGrouped = Dictionary(grouping: item.devices) { $0.category.isEmpty ? "Khác" : $0.category }
                        VStack(spacing: 6) {
                            ForEach(subGrouped.sorted(by: { $0.value.count > $1.value.count }), id: \.key) { sub in
                                HStack {
                                    Text(sub.key)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Spacer()
                                    Text("\(sub.value.count) cái")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(hex: "#F8FAFC"))
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - 6B. BREAKDOWN BY TYPE LIST
    private var typeBreakdownList: some View {
        LazyVStack(spacing: 10) {
            ForEach(breakdownByType, id: \.type) { item in
                let isExpanded = expandedKeys.contains(item.type)
                let pct = totalCount > 0 ? Double(item.devices.count) / Double(totalCount) : 0.0

                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.spring()) {
                            if isExpanded { expandedKeys.remove(item.type) }
                            else { expandedKeys.insert(item.type) }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "macbook.and.iphone")
                                    .foregroundColor(Color.appPrimaryPink)
                                    .font(.system(size: 14))
                                Text(item.type)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.devices.count) máy (\(Int(pct * 100))%)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                            }

                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(hex: "#F1F5F9")).frame(height: 6)
                                    Capsule().fill(Color.appPrimaryPink).frame(width: geo.size.width * CGFloat(pct), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(14)
                    }

                    if isExpanded {
                        Divider()

                        VStack(spacing: 6) {
                            ForEach(item.devices.prefix(15)) { dev in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(dev.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                        Text("ID: \(dev.id) • \(dev.unit)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Text(dev.status)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(dev.status.contains("hành") || dev.status.contains("sửa") ? .orange : (dev.status.contains("thanh lý") ? .red : .green))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.white)
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }

                            if item.devices.count > 15 {
                                Text("+ Thêm \(item.devices.count - 15) thiết bị khác...")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 4)
                            }
                        }
                        .padding(.vertical, 8)
                        .background(Color(hex: "#F8FAFC"))
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
                )
            }
        }
    }

    // Helper: Currency formatting
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(formatted) đ"
    }
}
