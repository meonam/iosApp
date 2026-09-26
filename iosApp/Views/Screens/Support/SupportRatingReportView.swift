import SwiftUI

// MARK: - MÀN HÌNH BÁO CÁO ĐÁNH GIÁ SLA & CHẤT LƯỢNG HỖ TRỢ (ĐỒNG BỘ 1:1 THEO SUPPORTRATINGREPORTSCREEN.KT TRÊN ANDROID)
public struct KtvRatingStat: Identifiable {
    public var id: String { ktvEmail }
    public var ktvName: String
    public var ktvEmail: String
    public var totalResolved: Int
    public var avgRating: Double
    public var withinSlaPercent: Int

    public init(ktvName: String, ktvEmail: String, totalResolved: Int, avgRating: Double, withinSlaPercent: Int) {
        self.ktvName = ktvName
        self.ktvEmail = ktvEmail
        self.totalResolved = totalResolved
        self.avgRating = avgRating
        self.withinSlaPercent = withinSlaPercent
    }
}

public struct SupportRatingReportView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void

    @State private var ktvStats: [KtvRatingStat] = [
        KtvRatingStat(ktvName: "Nguyễn Văn Kỹ Thuật", ktvEmail: "ktv01@sgcoop.com", totalResolved: 48, avgRating: 4.9, withinSlaPercent: 96),
        KtvRatingStat(ktvName: "Trần Minh Trí", ktvEmail: "ktv02@sgcoop.com", totalResolved: 42, avgRating: 4.8, withinSlaPercent: 93),
        KtvRatingStat(ktvName: "Lê Hoàng Phúc", ktvEmail: "ktv03@sgcoop.com", totalResolved: 35, avgRating: 4.7, withinSlaPercent: 89),
        KtvRatingStat(ktvName: "Phạm Quốc Toàn", ktvEmail: "ktv04@sgcoop.com", totalResolved: 29, avgRating: 4.6, withinSlaPercent: 91)
    ]

    public init(viewModel: SupportViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
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
                    .background(Color.appTopBarColor)

                    // 2. NỘI DUNG CUỘN
                    ScrollView {
                        VStack(spacing: 14) {
                            // Tổng quan SLA toàn hệ thống
                            VStack(spacing: 8) {
                                Text("HIỆU SUẤT ĐÁP ỨNG SLA HỆ THỐNG")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color.white.opacity(0.85))

                                Text("94.5%")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(.white)

                                Text("Đạt chỉ tiêu SLA giải quyết sự cố (< 4 giờ)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.9))
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .background(Color.appSecondaryDarkBlue)
                            .cornerRadius(16)

                            // Bảng xếp hạng KTV
                            VStack(alignment: .leading, spacing: 12) {
                                Text("BẢNG XẾP HẠNG CHẤT LƯỢNG KTV")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appTextSecondary)

                                ForEach(ktvStats) { ktv in
                                    ktvRow(ktv)
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
            .ignoresSafeArea(edges: .top)
        }
    }

    private func ktvRow(_ ktv: KtvRatingStat) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.appPrimaryPink)
                    .frame(width: 38, height: 38)
                Text(String(ktv.ktvName.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ktv.ktvName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 6) {
                    Text("Đã xử lý: \(ktv.totalResolved) sự cố")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                    Text("•")
                        .foregroundColor(Color.appTextSecondary)
                    Text("SLA: \(ktv.withinSlaPercent)%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.appSuccess)
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
        .padding(.vertical, 4)
    }
}
