import SwiftUI

// MARK: - MÀN HÌNH THỐNG KÊ TÀI SẢN & SỰ CỐ (ĐỒNG BỘ 1:1 THEO THONGKESCREEN.KT TRÊN ANDROID)
public struct AssetStatisticsView: View {
    @ObservedObject var viewModel: HomeViewModel
    var onBack: () -> Void
    var onNavigateToPrint: () -> Void

    @State private var selectedStatusFilter: String = "TẤT CẢ"
    @State private var searchQuery: String = ""
    @State private var expandedUnits: Set<String> = []

    public init(
        viewModel: HomeViewModel,
        onBack: @escaping () -> Void,
        onNavigateToPrint: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onNavigateToPrint = onNavigateToPrint
    }

    // Lọc thiết bị theo trạng thái
    private var filteredDevices: [ThietBi] {
        viewModel.devices.filter { dev in
            let matchStatus: Bool
            switch selectedStatusFilter {
            case "SỬ DỤNG":
                matchStatus = dev.trangThai == "IN_USE" || dev.trangThai == "SỬ DỤNG"
            case "BẢO HÀNH":
                matchStatus = dev.trangThai == "REPAIR" || dev.trangThai == "BẢO HÀNH" || dev.trangThai == "SỬA CHỮA"
            case "CHO MƯỢN":
                matchStatus = dev.trangThai == "ON_LOAN" || dev.trangThai == "CHO MƯỢN"
            case "THANH LÝ":
                matchStatus = dev.trangThai == "LIQUIDATED" || dev.trangThai == "THANH LÝ"
            default:
                matchStatus = true
            }

            if !matchStatus { return false }

            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                let nameMatch = dev.ten.lowercased().contains(q)
                let unitMatch = dev.tenDonVi.lowercased().contains(q)
                let typeMatch = (dev.loai ?? "").lowercased().contains(q)
                return nameMatch || unitMatch || typeMatch
            }

            return true
        }
    }

    private var activeCount: Int {
        viewModel.devices.filter { $0.trangThai == "IN_USE" || $0.trangThai == "SỬ DỤNG" }.count
    }

    private var repairCount: Int {
        viewModel.devices.filter { $0.trangThai == "REPAIR" || $0.trangThai == "BẢO HÀNH" || $0.trangThai == "SỬA CHỮA" }.count
    }

    private var loanCount: Int {
        viewModel.devices.filter { $0.trangThai == "ON_LOAN" || $0.trangThai == "CHO MƯỢN" }.count
    }

    private var liquidateCount: Int {
        viewModel.devices.filter { $0.trangThai == "LIQUIDATED" || $0.trangThai == "THANH LÝ" }.count
    }

    // Nhóm theo Đơn vị
    private var groupedByUnit: [(unit: String, count: Int, devices: [ThietBi])] {
        let dict = Dictionary(grouping: filteredDevices) { dev in
            let u = dev.tenDonVi
            return u.isEmpty ? "Chưa gán đơn vị" : u
        }
        return dict.map { (unit: $0.key, count: $0.value.count, devices: $0.value) }
            .sorted { $0.count > $1.count }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar tràn tai thỏ với Safe Area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Thống kê tài sản & thiết bị")
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
                    }
                    .background(Color.appTopBarColor)

                    // Nội dung
                    ScrollView {
                        VStack(spacing: 14) {
                            // Thẻ Tổng quan màu Navy
                            totalSummaryCard

                            // Bộ lọc trạng thái (Chips)
                            filterChipsRow

                            // Ô tìm kiếm nhanh
                            searchBarView

                            // Thống kê phân bổ theo Đơn vị
                            unitBreakdownSection

                            Spacer(minLength: 40)
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - THẺ TỔNG QUAN
    private var totalSummaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TỔNG THIẾT BỊ QUẢN LÝ")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.8))

                Text("\(viewModel.totalDevicesCount) máy")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)

                Text("Đang mở: \(viewModel.openTicketsCount) sự cố kỹ thuật")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
            }

            Spacer()

            Button(action: onNavigateToPrint) {
                VStack(spacing: 4) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                    Text("In tem")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 52)
                .background(Color.appPrimaryPink)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
        }
        .padding(16)
        .background(Color.appSecondaryDarkBlue)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
    }

    // MARK: - FILTER CHIPS
    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chipButton(label: "Tất cả (\(viewModel.devices.count))", key: "TẤT CẢ")
                chipButton(label: "✅ Sử dụng (\(activeCount))", key: "SỬ DỤNG")
                chipButton(label: "🛡️ Bảo hành (\(repairCount))", key: "BẢO HÀNH")
                chipButton(label: "🤝 Cho mượn (\(loanCount))", key: "CHO MƯỢN")
                chipButton(label: "🗑️ Thanh lý (\(liquidateCount))", key: "THANH LÝ")
            }
        }
    }

    private func chipButton(label: String, key: String) -> some View {
        let isSelected = selectedStatusFilter == key
        return Button(action: {
            selectedStatusFilter = isSelected && key != "TẤT CẢ" ? "TẤT CẢ" : key
        }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : Color.appSecondaryDarkBlue)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? Color.appPrimaryPink : Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: 1))
        }
    }

    // MARK: - SEARCH BAR
    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.appTextSecondary)

            TextField("Tìm theo tên thiết bị, loại hoặc đơn vị...", text: $searchQuery)
                .font(.system(size: 13))

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.appTextSecondary)
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - PHÂN BỔ THEO ĐƠN VỊ
    private var unitBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Phân bổ theo Đơn vị (\(groupedByUnit.count))")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Spacer()
                Text("\(filteredDevices.count) thiết bị")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
            }

            VStack(spacing: 8) {
                ForEach(groupedByUnit, id: \.unit) { item in
                    let isExpanded = expandedUnits.contains(item.unit)
                    VStack(alignment: .leading, spacing: 6) {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if isExpanded {
                                    expandedUnits.remove(item.unit)
                                } else {
                                    expandedUnits.insert(item.unit)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "building.2.fill")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text(item.unit)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(item.count)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.appSecondaryDarkBlue)
                                    .cornerRadius(8)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }

                        // Thanh tỷ lệ
                        GeometryReader { geo in
                            let ratio = viewModel.totalDevicesCount > 0 ? CGFloat(item.count) / CGFloat(viewModel.totalDevicesCount) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appBackground)
                                    .frame(height: 6)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.appPrimaryPink)
                                    .frame(width: max(geo.size.width * ratio, 8), height: 6)
                            }
                        }
                        .frame(height: 6)

                        if isExpanded {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(item.devices) { dev in
                                    HStack {
                                        Text("• \(dev.ten.isEmpty ? "Thiết bị" : dev.ten)")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextPrimary)
                                        Spacer()
                                        Text(dev.trangThai)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
            }
        }
    }
}
