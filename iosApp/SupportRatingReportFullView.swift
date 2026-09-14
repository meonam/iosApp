import SwiftUI
import UIKit

struct SupportRatingDetailItem: Identifiable, Hashable {
    var id: String
    var ticketCode: String
    var ticketTitle: String
    var storeName: String
    var technicianName: String
    var ratingStars: Int // 1 to 5
    var feedbackComment: String
    var createdAt: String
    var isSlaMet: Bool
}

struct KtvLeaderboardItem: Identifiable, Hashable {
    var id: String { name }
    var name: String
    var mnv: String
    var unit: String
    var totalSolved: Int
    var fiveStarCount: Int
    var averageStars: Double
    var slaRate: Int // %
}

// MARK: - MÀN HÌNH BÁO CÁO ĐÁNH GIÁ CHẤT LƯỢNG CSAT & SLA (SupportRatingReportScreen.kt)
struct SupportRatingReportFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 0 // 0: Chi tiết đánh giá, 1: Bảng xếp hạng thi đua KTV
    @State private var timeFilter: String = "ALL" // ALL, MONTH, WEEK, TODAY
    @State private var searchQuery: String = ""

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    // Default CSAT reviews matching Saigon Co.op support tickets
    private var sampleReviews: [SupportRatingDetailItem] {
        [
            SupportRatingDetailItem(id: "rv1", ticketCode: "SC-9821", ticketTitle: "Lỗi máy in bill POS quầy thu ngân 03", storeName: "Co.opmart Cần Thơ", technicianName: "Dam Huu Phuc", ratingStars: 5, feedbackComment: "KTV hỗ trợ rất nhanh, thay cáp và in thử hoạt động hoàn hảo!", createdAt: "12/09/2026", isSlaMet: true),
            SupportRatingDetailItem(id: "rv2", ticketCode: "SC-9818", ticketTitle: "Mất kết nối switch mạng tầng trệt", storeName: "Co.opmart Thốt Nốt", technicianName: "Dinh Quoc Huy", ratingStars: 5, feedbackComment: "Xử lý chuyên nghiệp, thông mạng kịp giờ mở cửa bán hàng.", createdAt: "11/09/2026", isSlaMet: true),
            SupportRatingDetailItem(id: "rv3", ticketCode: "SC-9805", ticketTitle: "Cân điện tử rau củ không in tem barcode", storeName: "Co.opmart Vị Thanh", technicianName: "Huỳnh Nguyễn Anh Đức", ratingStars: 4, feedbackComment: "Khắc phục tốt, KTV hướng dẫn nhân viên vệ sinh mắt đọc tem.", createdAt: "10/09/2026", isSlaMet: true),
            SupportRatingDetailItem(id: "rv4", ticketCode: "SC-9799", ticketTitle: "Máy tính thu ngân treo màn hình xanh", storeName: "Co.opmart Bến Tre", technicianName: "Hồ Thân Khánh", ratingStars: 5, feedbackComment: "Thay RAM và khôi phục dữ liệu ca bán hàng cực kỳ an toàn.", createdAt: "09/09/2026", isSlaMet: true),
            SupportRatingDetailItem(id: "rv5", ticketCode: "SC-9782", ticketTitle: "Máy quét mã vạch không nhận QR Momo/VNPay", storeName: "Co.opmart Sa Đéc", technicianName: "Ngo Duy Linh", ratingStars: 4, feedbackComment: "Cập nhật firmware máy quét thành công.", createdAt: "08/09/2026", isSlaMet: false),
            SupportRatingDetailItem(id: "rv6", ticketCode: "SC-9770", ticketTitle: "Lỗi kết nối camera an ninh kho đông lạnh", storeName: "Co.opmart Cà Mau", technicianName: "Nguyen Thanh Sang", ratingStars: 5, feedbackComment: "KTV nhiệt tình, đi đường xa nhưng đến đúng hẹn.", createdAt: "07/09/2026", isSlaMet: true)
        ]
    }

    private var sampleLeaderboard: [KtvLeaderboardItem] {
        [
            KtvLeaderboardItem(name: "Dam Huu Phuc", mnv: "26063", unit: "IT TẬP TRUNG", totalSolved: 48, fiveStarCount: 44, averageStars: 4.92, slaRate: 98),
            KtvLeaderboardItem(name: "Dinh Quoc Huy", mnv: "33430", unit: "IT TẬP TRUNG", totalSolved: 42, fiveStarCount: 38, averageStars: 4.88, slaRate: 96),
            KtvLeaderboardItem(name: "Hồ Thân Khánh", mnv: "35713", unit: "IT Bình Dương", totalSolved: 39, fiveStarCount: 35, averageStars: 4.85, slaRate: 95),
            KtvLeaderboardItem(name: "Huỳnh Nguyễn Anh Đức", mnv: "NVDUCHN", unit: "Co.opmart Cần Thơ", totalSolved: 36, fiveStarCount: 32, averageStars: 4.82, slaRate: 94),
            KtvLeaderboardItem(name: "Nguyen Thanh Sang", mnv: "19842", unit: "IT TẬP TRUNG", totalSolved: 33, fiveStarCount: 29, averageStars: 4.79, slaRate: 92),
            KtvLeaderboardItem(name: "Ngo Duy Linh", mnv: "43144", unit: "IT TẬP TRUNG", totalSolved: 28, fiveStarCount: 23, averageStars: 4.71, slaRate: 90)
        ]
    }

    var filteredReviews: [SupportRatingDetailItem] {
        sampleReviews.filter { r in
            searchQuery.isEmpty ||
            r.ticketCode.localizedCaseInsensitiveContains(searchQuery) ||
            r.storeName.localizedCaseInsensitiveContains(searchQuery) ||
            r.technicianName.localizedCaseInsensitiveContains(searchQuery) ||
            r.feedbackComment.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var averageScore: Double {
        let scores = sampleReviews.map { Double($0.ratingStars) }
        return scores.isEmpty ? 5.0 : scores.reduce(0, +) / Double(scores.count)
    }

    var satisfactionPercent: Int {
        let count = sampleReviews.count
        if count == 0 { return 100 }
        let happy = sampleReviews.filter { $0.ratingStars >= 4 }.count
        let ratio = Double(happy) / Double(count)
        return Int(ratio * 100.0)
    }

    var slaMetPercent: Int {
        let count = sampleReviews.count
        if count == 0 { return 100 }
        let met = sampleReviews.filter { $0.isSlaMet }.count
        let ratio = Double(met) / Double(count)
        return Int(ratio * 100.0)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. KPI Top Summary Cards
                kpiHeaderSection

                // 2. Tab Picker (2 Phân Hệ)
                Picker("Chế độ xem", selection: $selectedTab) {
                    Text("Đánh Giá Chi Tiết").tag(0)
                    Text("Bảng Xếp Hạng KTV").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white)

                // 3. Search & Filters
                if selectedTab == 0 {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Tìm mã sự cố, siêu thị, KTV, phản hồi...", text: $searchQuery)
                            .font(.system(size: 13))
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }

                // 4. Tab Content
                ScrollView {
                    VStack(spacing: 12) {
                        if selectedTab == 0 {
                            reviewsListTab
                        } else {
                            leaderboardTab
                        }
                    }
                    .padding(12)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Đánh Giá Chất Lượng CSAT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - KPI Header Section
    private var kpiHeaderSection: some View {
        HStack(spacing: 8) {
            kpiCard(title: "Điểm Sao TB", value: String(format: "%.1f ⭐", averageScore), sub: "\(sampleReviews.count) lượt chấm", color: .orange)
            kpiCard(title: "Hài Lòng", value: "\(satisfactionPercent)%", sub: "Đánh giá 4-5★", color: .statusInUse)
            kpiCard(title: "Đạt SLA", value: "\(slaMetPercent)%", sub: "Xử lý đúng hạn", color: .appSecondaryDarkBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func kpiCard(title: String, value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.appTextPrimary)
            Text(sub)
                .font(.system(size: 9.5))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - Tab 0: Reviews List
    private var reviewsListTab: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredReviews) { item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(item.ticketCode)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.appPrimaryPink)

                        Spacer()

                        // Stars row
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= item.ratingStars ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                            }
                        }

                        Text(item.createdAt)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                    }

                    Text(item.ticketTitle)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.appTextPrimary)

                    Text("\"\(item.feedbackComment)\"")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(6)

                    Divider()

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(item.storeName)
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.appSecondaryDarkBlue)
                            Text("KTV: \(item.technicianName)")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.appSecondaryDarkBlue)
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Tab 1: Leaderboard
    private var leaderboardTab: some View {
        LazyVStack(spacing: 10) {
            ForEach(Array(sampleLeaderboard.enumerated()), id: \.element.id) { index, ktv in
                HStack(spacing: 12) {
                    // Rank badge
                    ZStack {
                        Circle()
                            .fill(rankColor(index))
                            .frame(width: 32, height: 32)
                        Text("\(index + 1)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(ktv.name)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(.appTextPrimary)
                            Text("(\(ktv.mnv))")
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.appPrimaryPink)
                        }

                        Text(ktv.unit)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text(String(format: "%.2f", ktv.averageStars))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                        }

                        Text("\(ktv.totalSolved) ca • \(ktv.slaRate)% SLA")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 0: return Color(hex: "#FFD700") // Gold
        case 1: return Color(hex: "#C0C0C0") // Silver
        case 2: return Color(hex: "#CD7F32") // Bronze
        default: return Color.appSecondaryDarkBlue
        }
    }
}
