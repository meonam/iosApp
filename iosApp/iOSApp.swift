import SwiftUI
import UserNotifications
import AVFoundation

@main
struct iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainContainerView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 1. Cấu hình AudioSession tối ưu cho giọng đọc âm lượng lớn, không bị ngắt quãng
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            print("[AppDelegate] AudioSession setup error: \(error)")
        }

        // 2. Đăng ký UNUserNotificationCenterDelegate & xin quyền thông báo
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Tạo Category với Action buttons đồng bộ Android: [✅ TIẾP NHẬN XỬ LÝ] và [✅ ĐÃ TIẾP NHẬN]
        let ackDispatchAction = UNNotificationAction(
            identifier: "ACK_DISPATCH",
            title: "✅ TIẾP NHẬN XỬ LÝ",
            options: [.foreground]
        )
        let dispatchCategory = UNNotificationCategory(
            identifier: "DISPATCH_ALERT",
            actions: [ackDispatchAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let ackNewTicketAction = UNNotificationAction(
            identifier: "ACK_NEW_TICKET",
            title: "✅ ĐÃ TIẾP NHẬN",
            options: [.foreground]
        )
        let newTicketCategory = UNNotificationCategory(
            identifier: "NEW_TICKET_ALERT",
            actions: [ackNewTicketAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([dispatchCategory, newTicketCategory])

        center.requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { granted, error in
            print("[AppDelegate] Notification permission granted: \(granted), error: \(String(describing: error))")
        }

        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Đăng ký nhận APNs Token cho Push Notification
    }

    // MARK: - UNUserNotificationCenterDelegate: BẮT BUỘC ĐỂ THẢ BANNER TỪ TRÊN XUỐNG KHI ĐANG MỞ APP
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge, .list])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let ticketId = userInfo["ticketId"] as? String {
            VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
        }
        completionHandler()
    }
}
