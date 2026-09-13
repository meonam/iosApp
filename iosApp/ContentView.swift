import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.96, blue: 0.98)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)

                Text("QLTB SGCOOP")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text("Hệ thống Quản lý Thiết bị & Điều phối KTV")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Divider().padding(.horizontal, 40)

                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "qrcode.viewfinder", title: "Quét mã Barcode / QR", desc: "Kiểm tra và cập nhật tình trạng thiết bị")
                    FeatureRow(icon: "map.fill", title: "Giám sát & Dẫn đường", desc: "Định vị KTV và dẫn đường đến siêu thị")
                    FeatureRow(icon: "printer.fill", title: "In phiếu nhiệt", desc: "Kết nối máy in nhiệt Bluetooth ESC/POS")
                    FeatureRow(icon: "calendar.badge.clock", title: "Phân ca & Chấm công", desc: "Theo dõi ca trực và chấm công KTV")
                }
                .padding(.horizontal, 24)

                Spacer()

                Text("Phiên bản iOS 1.0.0 (Build via GitHub Actions)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.bottom, 16)
            }
            .padding(.top, 40)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(desc)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
