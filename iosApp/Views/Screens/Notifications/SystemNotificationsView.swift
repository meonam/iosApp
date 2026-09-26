import SwiftUI

// MARK: - MÀN HÌNH THÔNG BÁO HỆ THỐNG (ĐỒNG BỘ 1:1 THEO ANDROID SYSTEM_NOTIFICATIONS)
public struct SystemNotificationItem: Identifiable, Hashable {
    public var id: String
    public var title: String
    public var message: String
    public var senderName: String
    public var timestamp: Int64
    public var isRead: Bool
    public var type: String // INFO, WARNING, URGENT

    public init(id: String, title: String, message: String, senderName: String, timestamp: Int64, isRead: Bool = false, type: String = "INFO") {
        self.id = id
        self.title = title
        self.message = message
        self.senderName = senderName
        self.timestamp = timestamp
        self.isRead = isRead
        self.type = type
    }
}

public struct SystemNotificationsView: View {
    var onBack: () -> Void

    @State private var notifications: [SystemNotificationItem] = [
        SystemNotificationItem(
            id: "1",
            title: "Hệ thống bảo trì định kỳ",
            message: "Hệ thống máy chủ QLTB sẽ bảo trì nâng cấp hiệu năng vào lúc 23:00 tối thứ Bảy.",
            senderName: "Ban Quản trị CNTT",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000 - 3600000 * 2),
            isRead: false,
            type: "INFO"
        ),
        SystemNotificationItem(
            id: "2",
            title: "Nhắc nhở kiểm kê tài sản Quý 3",
            message: "Các đơn vị và phòng ban vui lòng hoàn tất quét mã kiểm kê thiết bị trước ngày 30 hàng tháng.",
            senderName: "Phòng Quản lý Tài sản",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000 - 3600000 * 24),
            isRead: true,
            type: "WARNING"
        ),
        SystemNotificationItem(
            id: "3",
            title: "Phiên bản ứng dụng mới v1.2.0",
            message: "Ứng dụng IT Service & Assets đã cập nhật giao diện mới đồng bộ hoàn chỉnh giữa Android và iOS.",
            senderName: "Hệ thống tự động",
            timestamp: Int64(Date().timeIntervalSince1970 * 1000 - 3600000 * 48),
            isRead: true,
            type: "INFO"
        )
    ]

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TopBar tràn tai thỏ với Safe Area
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Thông báo hệ thống")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                for i in 0..<notifications.count {
                                    notifications[i].isRead = true
                                }
                            }) {
                                Text("Đọc tất cả")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // Danh sách thông báo
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(notifications) { notif in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: notif.type == "WARNING" ? "exclamationmark.triangle.fill" : "bell.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(notif.type == "WARNING" ? Color.appWarning : Color.appSecondaryDarkBlue)
                                    .frame(width: 36, height: 36)
                                    .background(notif.type == "WARNING" ? Color.appWarning.opacity(0.12) : Color.appSecondaryDarkBlue.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(notif.title)
                                            .font(.system(size: 14, weight: notif.isRead ? .medium : .bold))
                                            .foregroundColor(Color.appTextPrimary)
                                        Spacer()
                                        if !notif.isRead {
                                            Circle()
                                                .fill(Color.appPrimaryPink)
                                                .frame(width: 8, height: 8)
                                        }
                                    }

                                    Text(notif.message)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(Color.appTextSecondary)
                                        .lineSpacing(2)

                                    HStack {
                                        Text(notif.senderName)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                        Spacer()
                                        Text("Vừa xong")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Color.appTextMuted)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }
                    .padding(14)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
