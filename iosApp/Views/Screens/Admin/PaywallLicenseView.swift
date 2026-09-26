import SwiftUI

// MARK: - MÀN HÌNH BẢN QUYỀN HỆ THỐNG DOANH NGHIỆP (ĐỒNG BỘ 1:1 THEO ANDROID PAYWALL/LICENSE)
public struct PaywallLicenseView: View {
    var onBack: () -> Void

    public init(onBack: @escaping () -> Void) {
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

                            Text("Bản quyền & Gói dịch vụ")
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
                        VStack(spacing: 16) {
                            // Card Gói hiện tại
                            VStack(spacing: 10) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color(hex: "#F59E0B"))

                                Text("GÓI DOANH NGHIỆP CAO CẤP")
                                    .font(.system(size: 16, weight: .black))
                                    .foregroundColor(Color.appTextPrimary)

                                Text("Saigon Co.op - Mã DN: SGCOOP")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Trạng thái giấy phép:")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextSecondary)
                                        Text("Hạn sử dụng:")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextSecondary)
                                        Text("Số lượng thiết bị tối đa:")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Kích hoạt vĩnh viễn")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color.appSuccess)
                                        Text("31/12/2030")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color.appTextPrimary)
                                        Text("Không giới hạn (Unlimited)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color.appPrimaryPink)
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))

                            // Tính năng mở khóa
                            VStack(alignment: .leading, spacing: 12) {
                                Text("TÍNH NĂNG ĐÃ KÍCH HOẠT")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color.appTextSecondary)

                                featureRow(title: "Quản lý thiết bị đa tầng (Phòng ban ➔ Đơn vị)")
                                featureRow(title: "Hệ thống phiếu hỗ trợ kỹ thuật trực tiếp (Ticket Chat)")
                                featureRow(title: "Chấm công GPS & Phân ca làm việc KTV tự động")
                                featureRow(title: "In tem nhãn QR Code / Barcode máy in nhiệt ESC/POS")
                                featureRow(title: "Giám sát trực tuyến vị trí kỹ thuật viên hiện trường")
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

    private func featureRow(title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color.appSuccess)
                .font(.system(size: 14))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.appTextPrimary)
            Spacer()
        }
    }
}
