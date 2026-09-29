import SwiftUI

// MARK: - MÀN HÌNH THỐNG KÊ TÀI SẢN & THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI THONGKESCREEN.KT TRÊN ANDROID)
public struct AssetStatisticsView: View {
    @ObservedObject var viewModel: HomeViewModel
    var onBack: () -> Void
    var onNavigateToPrint: () -> Void

    @State private var selectedStatusFilter: String = "TẤT CẢ"
    @State private var searchQuery: String = ""
    @State private var expandedUnits: Set<String> = []
    @State private var expandedTypes: Set<String> = []

    public init(
        viewModel: HomeViewModel,
        onBack: @escaping () -> Void,
        onNavigateToPrint: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onNavigateToPrint = onNavigateToPrint
    }

    // MARK: - LỌC THIẾT BỊ THEO PHÂN QUYỀN (ĐỒNG BỘ 1:1 THEO ANDROID THONGKESCREEN)
    private var baseDevices: [ThietBi] {
        let user = viewModel.user
        let isFullAccess = user.isSuperAdmin || user.isAdmin || user.isHelpDesk || user.isWarehouse
        let isDeptManager = user.isManager
        let cleanDept = user.departmentId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDonVi = user.donVi.trimmingCharacters(in: .whitespacesAndNewlines)
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if isFullAccess {
            // Admin, Helpdesk, Quản trị kho: Xem toàn bộ thiết bị
            return viewModel.devices
        } else if isDeptManager {
            // Quản lý phòng ban: Thống kê toàn bộ thiết bị của phòng ban mình tại các đơn vị quản lý
            return viewModel.devices.filter { dev in
                let devDept = (dev.phongBan ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let matchDept: Bool
                if !cleanDept.isEmpty && !cleanDept.caseInsensitiveCompare("all").isMatch {
                    matchDept = devDept.caseInsensitiveCompare(cleanDept) == .orderedSame ||
                               devDept.localizedCaseInsensitiveContains(cleanDept) ||
                               cleanDept.localizedCaseInsensitiveContains(devDept)
                } else {
                    matchDept = false
                }

                let matchDonVi = cleanDonVi.isEmpty ||
                                 cleanDonVi.caseInsensitiveCompare("all") == .orderedSame ||
                                 dev.tenDonVi.caseInsensitiveCompare(cleanDonVi) == .orderedSame
                return matchDept && matchDonVi
            }
        } else {
            // Nhân viên thường / KTV / Chuyên viên: Chỉ thiết bị do chính họ tạo
            return viewModel.devices.filter { dev in
                let devCreatedBy = (dev.createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !myEmail.isEmpty && devCreatedBy == myEmail
            }
        }
    }

    // MARK: - CHUẨN HÓA TRẠNG THÁI (ĐỒNG BỘ 1:1 THEO ANDROID)
    private func isStatusInUse(_ raw: String) -> Bool {
        let s = raw.lowercased()
        return s.contains("sử dụng") || s.contains("trong kho") || s.contains("sẵn sàng") ||
               s.contains("mới") || s.contains("bình thường") || s == "in_use" || s == "new" || s == "in_stock"
    }

    private func isStatusRepair(_ raw: String) -> Bool {
        let s = raw.lowercased()
        return s.contains("bảo hành") || s.contains("sửa chữa") || s.contains("sửa") ||
               s.contains("hỏng") || s.contains("xử lý") || s == "repair" || s == "broken"
    }

    private func isStatusLoan(_ raw: String) -> Bool {
        let s = raw.lowercased()
        return s.contains("mượn") || s == "on_loan" || s == "loan"
    }

    private func isStatusLiquidated(_ raw: String) -> Bool {
        let s = raw.lowercased()
        return s.contains("thanh lý") || s.contains("hủy") || s == "liquidated"
    }

    // Chỉ số tổng quan
    private var totalCount: Int { baseDevices.count }
    private var activeCount: Int { baseDevices.filter { isStatusInUse($0.trangThai) }.count }
    private var repairCount: Int { baseDevices.filter { isStatusRepair($0.trangThai) }.count }
    private var loanCount: Int { baseDevices.filter { isStatusLoan($0.trangThai) }.count }
    private var liquidateCount: Int { baseDevices.filter { isStatusLiquidated($0.trangThai) }.count }

    // Lọc theo chip trạng thái và từ khóa tìm kiếm
    private var filteredDevices: [ThietBi] {
        let statusFiltered: [ThietBi]
        switch selectedStatusFilter {
        case "SỬ DỤNG":
            statusFiltered = baseDevices.filter { isStatusInUse($0.trangThai) }
        case "BẢO HÀNH":
            statusFiltered = baseDevices.filter { isStatusRepair($0.trangThai) }
        case "CHO MƯỢN":
            statusFiltered = baseDevices.filter { isStatusLoan($0.trangThai) }
        case "THANH LÝ":
            statusFiltered = baseDevices.filter { isStatusLiquidated($0.trangThai) }
        default:
            statusFiltered = baseDevices
        }

        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return statusFiltered
        }
        return statusFiltered.filter { dev in
            dev.ten.lowercased().contains(q) ||
            dev.id.lowercased().contains(q) ||
            dev.tenDonVi.lowercased().contains(q) ||
            (dev.loai ?? "").lowercased().contains(q) ||
            (dev.phongBan ?? "").lowercased().contains(q)
        }
    }

    // Nhóm theo Đơn vị (Admin)
    private var thongKeTheoDonVi: [(donVi: String, loaiGroups: [(loai: String, count: Int, devices: [(ten: String, count: Int)])])] {
        let grouped = Dictionary(grouping: filteredDevices) { dev in
            dev.tenDonVi.isEmpty ? "Toàn Công ty" : dev.tenDonVi
        }

        return grouped.map { (donVi, devList) in
            let loaiDict = Dictionary(grouping: devList) { dev in
                let l = (dev.loai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return l.isEmpty ? "Khác / Chưa phân loại" : l
            }

            let loaiGroups = loaiDict.map { (loai, subList) in
                let nameDict = Dictionary(grouping: subList) { $0.ten }
                let nameCounts = nameDict.map { ($0.key, $0.value.count) }
                    .sorted { $0.1 > $1.1 }
                return (loai: loai, count: subList.count, devices: nameCounts)
            }.sorted { $0.count > $1.count }

            return (donVi: donVi, loaiGroups: loaiGroups)
        }.sorted { item1, item2 in
            let count1 = item1.loaiGroups.reduce(0) { $0 + $1.count }
            let count2 = item2.loaiGroups.reduce(0) { $0 + $1.count }
            return count1 > count2
        }
    }

    // Nhóm theo Loại thiết bị (Manager / Staff)
    private var thongKeTheoLoai: [(loai: String, count: Int, devices: [(ten: String, count: Int)])] {
        let loaiDict = Dictionary(grouping: filteredDevices) { dev in
            let l = (dev.loai ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return l.isEmpty ? "Khác / Chưa phân loại" : l
        }

        return loaiDict.map { (loai, subList) in
            let nameDict = Dictionary(grouping: subList) { $0.ten }
            let nameCounts = nameDict.map { ($0.key, $0.value.count) }
                .sorted { $0.1 > $1.1 }
            return (loai: loai, count: subList.count, devices: nameCounts)
        }.sorted { $0.count > $1.count }
    }

    // Phạm vi hiển thị
    private var scopeLabel: String {
        let u = viewModel.user
        if u.isSuperAdmin || u.isAdmin {
            return "Toàn công ty"
        } else if u.isHelpDesk {
            return "Phòng Helpdesk"
        } else if u.isWarehouse {
            return "Kho thiết bị"
        } else if u.isManager {
            return "Phòng: \(u.departmentId.isEmpty ? u.donVi : u.departmentId)"
        } else {
            return "Thiết bị của tôi"
        }
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

                            Text("Thống kê & Báo cáo thiết bị")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: onNavigateToPrint) {
                                Image(systemName: "printer.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.appPrimaryPink)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // Company Banner Ticker
                        CompanyBannerTickerView(
                            isActive: viewModel.isCompanyBannerActive,
                            text: viewModel.companyBannerText,
                            type: viewModel.companyBannerType
                        )
                    }
                    .background(Color.appTopBarColor)

                    // NỘI DUNG SCROLL
                    ScrollView {
                        VStack(spacing: 12) {
                            // 1. CARD CHÍNH DUY NHẤT TỔNG THỐNG KÊ (NAVY)
                            totalSummaryCard

                            // 2. THANH NHÃN LỌC TRẠNG THÁI (CHIPS)
                            filterChipsBar

                            // 3. THẺ THỐNG KÊ ĐỘNG KHI CHỌN CHIP
                            if selectedStatusFilter != "TẤT CẢ" {
                                dynamicStatusDetailCard
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            // 4. THANH TÌM KIẾM
                            searchBarView

                            // 5. PHÂN BỔ CHI TIẾT
                            if viewModel.user.isAdmin || viewModel.user.isSuperAdmin {
                                adminUnitBreakdownSection
                            } else {
                                userTypeBreakdownSection
                            }

                            Spacer(minLength: 40)
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - 1. THẺ TỔNG QUAN
    private var totalSummaryCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("TỔNG THIẾT BỊ QUẢN LÝ")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.8))

                    Text("• \(scopeLabel)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.appPrimaryPink)
                }

                Text("\(totalCount) máy")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)

                if viewModel.openTicketsCount > 0 {
                    Text("Đang xử lý: \(viewModel.openTicketsCount) sự cố kỹ thuật")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                }
            }

            Spacer()

            Button(action: onNavigateToPrint) {
                VStack(spacing: 3) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    Text("In tem")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 48, height: 48)
                .background(Color.appPrimaryPink)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
        .padding(16)
        .background(Color.appSecondaryDarkBlue)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    // MARK: - 2. THANH NHÃN LỌC TRẠNG THÁI (CHIPS)
    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipItem(title: "TẤT CẢ (\(totalCount))", key: "TẤT CẢ")
                chipItem(title: "✅ SỬ DỤNG (\(activeCount))", key: "SỬ DỤNG")
                chipItem(title: "🛡️ BẢO HÀNH (\(repairCount))", key: "BẢO HÀNH")
                chipItem(title: "🤝 CHO MƯỢN (\(loanCount))", key: "CHO MƯỢN")
                chipItem(title: "🗑️ THANH LÝ (\(liquidateCount))", key: "THANH LÝ")
            }
            .padding(.vertical, 2)
        }
    }

    private func chipItem(title: String, key: String) -> some View {
        let isSelected = selectedStatusFilter == key
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedStatusFilter = isSelected && key != "TẤT CẢ" ? "TẤT CẢ" : key
            }
        }) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : Color.appSecondaryDarkBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.appPrimaryPink : Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
        }
    }

    // MARK: - 3. THẺ THỐNG KÊ ĐỘNG
    private var dynamicStatusDetailCard: some View {
        let (title, count, percent, color, iconName, desc) = getDynamicStatusInfo()

        return HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)

                Text("\(count) máy (\(percent)% tổng hệ thống)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                withAnimation {
                    selectedStatusFilter = "TẤT CẢ"
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.system(size: 18))
            }
        }
        .padding(14)
        .background(color.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.25), lineWidth: 1))
    }

    private func getDynamicStatusInfo() -> (title: String, count: Int, percent: Int, color: Color, icon: String, desc: String) {
        let pct = totalCount > 0 ? (activeCount * 100 / totalCount) : 0
        switch selectedStatusFilter {
        case "SỬ DỤNG":
            return ("THIẾT BỊ ĐANG HOẠT ĐỘNG", activeCount, pct, Color(hex: "#2E7D32"), "checkmark.circle.fill", "Bao gồm máy trong kho, sẵn sàng và đang vận hành")
        case "BẢO HÀNH":
            let p = totalCount > 0 ? (repairCount * 100 / totalCount) : 0
            return ("THIẾT BỊ SỬA CHỮA / BẢO HÀNH", repairCount, p, Color(hex: "#E65100"), "wrench.and.screwdriver.fill", "Máy gặp sự cố, đang gửi bảo hành hoặc chờ xử lý")
        case "CHO MƯỢN":
            let p = totalCount > 0 ? (loanCount * 100 / totalCount) : 0
            return ("THIẾT BỊ ĐANG CHO MƯỢN", loanCount, p, Color(hex: "#1565C0"), "person.2.fill", "Thiết bị điều động hỗ trợ các đơn vị/phòng ban khác")
        default:
            let p = totalCount > 0 ? (liquidateCount * 100 / totalCount) : 0
            return ("THIẾT BỊ ĐÃ THANH LÝ", liquidateCount, p, Color(hex: "#C62828"), "trash.fill", "Thiết bị hỏng hoàn toàn đã thanh lý hoặc hủy")
        }
    }

    // MARK: - 4. THANH TÌM KIẾM
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.appSecondaryDarkBlue)
                .font(.system(size: 14))

            TextField("Tìm tên thiết bị, loại, đơn vị...", text: $searchQuery)
                .font(.system(size: 13))

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - 5A. PHÂN BỔ THEO ĐƠN VỊ (ADMIN)
    private var adminUnitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PHÂN BỔ THEO ĐƠN VỊ (\(thongKeTheoDonVi.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("\(filteredDevices.count) máy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appPrimaryPink)
            }

            if thongKeTheoDonVi.isEmpty {
                emptyState
            } else {
                ForEach(thongKeTheoDonVi, id: \.donVi) { unitItem in
                    let isExpanded = expandedUnits.contains(unitItem.donVi)
                    let unitTotal = unitItem.loaiGroups.reduce(0) { $0 + $1.count }

                    VStack(alignment: .leading, spacing: 0) {
                        // Header Đơn vị
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded {
                                    expandedUnits.remove(unitItem.donVi)
                                } else {
                                    expandedUnits.insert(unitItem.donVi)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .font(.system(size: 15))

                                Text(unitItem.donVi)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                Spacer()

                                Text("\(unitTotal)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.appPrimaryPink.opacity(0.12))
                                    .cornerRadius(8)

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.white)
                        }

                        // Danh sách loại thiết bị con
                        if isExpanded {
                            Divider().background(Color.appCardBorder)
                            VStack(spacing: 8) {
                                ForEach(unitItem.loaiGroups, id: \.loai) { loaiItem in
                                    let typeKey = "\(unitItem.donVi)_\(loaiItem.loai)"
                                    let isTypeExpanded = expandedTypes.contains(typeKey)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Button(action: {
                                            withAnimation {
                                                if isTypeExpanded {
                                                    expandedTypes.remove(typeKey)
                                                } else {
                                                    expandedTypes.insert(typeKey)
                                                }
                                            }
                                        }) {
                                            HStack {
                                                Text("📦 \(loaiItem.loai) (\(loaiItem.count) cái)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(isTypeExpanded ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)

                                                Spacer()

                                                Image(systemName: isTypeExpanded ? "minus" : "plus")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(.gray)
                                            }
                                        }

                                        if isTypeExpanded {
                                            ForEach(loaiItem.devices, id: \.ten) { devItem in
                                                VStack(alignment: .leading, spacing: 3) {
                                                    HStack {
                                                        Text(devItem.ten)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Color.appTextPrimary)
                                                        Spacer()
                                                        Text("\(devItem.count) cái")
                                                            .font(.system(size: 11, weight: .bold))
                                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                                    }
                                                    // Progress bar
                                                    GeometryReader { pGeom in
                                                        let pct = unitTotal > 0 ? CGFloat(devItem.count) / CGFloat(unitTotal) : 0
                                                        ZStack(alignment: .leading) {
                                                            RoundedRectangle(cornerRadius: 3)
                                                                .fill(Color.gray.opacity(0.15))
                                                                .frame(height: 4)
                                                            RoundedRectangle(cornerRadius: 3)
                                                                .fill(Color.appPrimaryPink)
                                                                .frame(width: max(4, pGeom.size.width * pct), height: 4)
                                                        }
                                                    }
                                                    .frame(height: 4)
                                                }
                                                .padding(.leading, 12)
                                                .padding(.vertical, 2)
                                            }
                                        }
                                    }
                                    .padding(8)
                                    .background(isTypeExpanded ? Color.gray.opacity(0.04) : Color.clear)
                                    .cornerRadius(8)
                                }
                            }
                            .padding(10)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
        }
    }

    // MARK: - 5B. PHÂN BỔ THEO LOẠI THIẾT BỊ (MANAGER / STAFF)
    private var userTypeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PHÂN BỔ THEO LOẠI THIẾT BỊ (\(thongKeTheoLoai.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("\(filteredDevices.count) máy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appPrimaryPink)
            }

            if thongKeTheoLoai.isEmpty {
                emptyState
            } else {
                ForEach(thongKeTheoLoai, id: \.loai) { loaiItem in
                    let isExpanded = expandedTypes.contains(loaiItem.loai)

                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded {
                                    expandedTypes.remove(loaiItem.loai)
                                } else {
                                    expandedTypes.insert(loaiItem.loai)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "cube.box.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                    .font(.system(size: 15))

                                Text(loaiItem.loai)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                Spacer()

                                Text("\(loaiItem.count)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.appPrimaryPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.appPrimaryPink.opacity(0.12))
                                    .cornerRadius(8)

                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .background(Color.white)
                        }

                        if isExpanded {
                            Divider().background(Color.appCardBorder)
                            VStack(spacing: 8) {
                                ForEach(loaiItem.devices, id: \.ten) { devItem in
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(devItem.ten)
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.appTextPrimary)
                                            Spacer()
                                            Text("\(devItem.count) cái")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(Color.appSecondaryDarkBlue)
                                        }

                                        GeometryReader { pGeom in
                                            let pct = loaiItem.count > 0 ? CGFloat(devItem.count) / CGFloat(loaiItem.count) : 0
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.gray.opacity(0.15))
                                                    .frame(height: 4)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.appPrimaryPink)
                                                    .frame(width: max(4, pGeom.size.width * pct), height: 4)
                                            }
                                        }
                                        .frame(height: 4)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding(10)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.fill")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.5))
            Text("Không có thiết bị nào phù hợp với dữ liệu lọc")
                .font(.system(size: 13))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
}

private extension ComparisonResult {
    var isMatch: Bool {
        return self == .orderedSame
    }
}
