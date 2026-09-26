import SwiftUI

public struct SupportRatingReportView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void

    @State private var sortOption: SortOption = .rating
    @State private var dateFilter: DateFilter = .all

    enum SortOption {
        case rating
        case tickets
        case sla
    }

    enum DateFilter: String, CaseIterable {
        case thisMonth = "Tháng này"
        case thisQuarter = "Quý này"
        case all = "Tất cả"
    }

    public init(viewModel: SupportViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private var filteredStats: [SupportViewModel.KtvStat] {
        var stats = viewModel.ktvStats
        // Sorting
        switch sortOption {
        case .rating:
            stats.sort { $0.avgRating > $1.avgRating }
        case .tickets:
            stats.sort { $0.closedTickets > $1.closedTickets }
        case .sla:
            stats.sort { $0.slaComplianceRate > $1.slaComplianceRate }
        }
        return stats
    }

    private var systemSlaCompliance: Double {
        let stats = filteredStats
        let total = stats.reduce(0) { $0 + $1.totalTickets }
        if total == 0 { return 0 }
        let totalSla = stats.reduce(0.0) { $0 + ($1.slaComplianceRate * Double($1.totalTickets) / 100.0) }
        return (totalSla / Double(total)) * 100.0
    }
    
    private var systemAvgRating: Double {
        let stats = filteredStats
        let total = stats.reduce(0) { $0 + $1.closedTickets }
        if total == 0 { return 0 }
        let totalRating = stats.reduce(0.0) { $0 + ($1.avgRating * Double($1.closedTickets)) }
        return totalRating / Double(total)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Báo cáo SLA & Đánh giá KTV")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    // DATE FILTER & SORTING
                    VStack(spacing: 12) {
                        Picker("Date Filter", selection: $dateFilter) {
                            ForEach(DateFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        HStack {
                            Text("Sắp xếp:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color.appTextPrimary)
                            
                            Spacer()
                            
                            Picker("Sort", selection: $sortOption) {
                                Text("Rating").tag(SortOption.rating)
                                Text("Số ticket").tag(SortOption.tickets)
                                Text("SLA %").tag(SortOption.sla)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .font(.system(size: 13))
                        }
                    }
                    .padding(14)
                    .background(Color.white)

                    // NỘI DUNG CUỘN
                    if viewModel.isLoadingStats {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                // Tổng quan SLA toàn hệ thống
                                VStack(spacing: 8) {
                                    Text("HIỆU SUẤT ĐÁP ỨNG SLA HỆ THỐNG")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.85))

                                    Text(String(format: "%.1f%%", systemSlaCompliance))
                                        .font(.system(size: 32, weight: .black))
                                        .foregroundColor(.white)

                                    HStack {
                                        Text("⭐ TB: \(String(format: "%.1f", systemAvgRating))")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.8))
                                            
                                        Text("Tổng ticket: \(filteredStats.reduce(0) { $0 + $1.totalTickets })")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(Color.appPrimary)
                                .cornerRadius(16)

                                // Bảng xếp hạng KTV
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("BẢNG XẾP HẠNG CHẤT LƯỢNG KTV")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appTextSecondary)

                                    if filteredStats.isEmpty {
                                        Text("Chưa có dữ liệu.")
                                            .font(.system(size: 14))
                                            .foregroundColor(Color.appTextSecondary)
                                            .padding()
                                    } else {
                                        ForEach(filteredStats) { ktv in
                                            ktvRow(ktv)
                                            if ktv.id != filteredStats.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(16)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
                            }
                            .padding(14)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                Task {
                    await viewModel.fetchKtvStats()
                }
            }
        }
    }

    private func ktvRow(_ ktv: SupportViewModel.KtvStat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 38, height: 38)
                    Text(String(ktv.name.prefix(1)).uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(ktv.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    HStack(spacing: 6) {
                        Text("Đóng: \(ktv.closedTickets)")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                        Text("•")
                            .foregroundColor(Color.appTextSecondary)
                        Text(String(format: "%.1fh/ticket", ktv.avgResolutionHours))
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#F59E0B"))
                    Text(String(format: "%.1f", ktv.avgRating))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#FEF3C7"))
                .cornerRadius(8)
            }
            
            // SLA Progress Bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("SLA Compliance")
                        .font(.system(size: 10))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Text(String(format: "%.1f%%", ktv.slaComplianceRate))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(slaColor(ktv.slaComplianceRate))
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appCardBorder)
                            .frame(height: 6)
                        Capsule()
                            .fill(slaColor(ktv.slaComplianceRate))
                            .frame(width: max(0, geo.size.width * CGFloat(ktv.slaComplianceRate) / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
            .padding(.leading, 50)
        }
        .padding(.vertical, 4)
    }
    
    private func slaColor(_ rate: Double) -> Color {
        if rate >= 95.0 {
            return Color(hex: "#10B981") // Xanh
        } else if rate >= 80.0 {
            return Color(hex: "#F59E0B") // Vàng
        } else {
            return Color(hex: "#EF4444") // Đỏ
        }
    }
}

