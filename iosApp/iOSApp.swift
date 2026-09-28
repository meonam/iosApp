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

        // 3. Đăng ký APNs để nhận push thực sự từ server (đồng bộ FCM trên Android)
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - BACKGROUND FETCH (iOS tự gọi để fetch data định kỳ khi app ở nền)
    func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Trigger fetch tickets ngay khi iOS cho phép background fetch
        NotificationCenter.default.post(name: Notification.Name("QLTB_BackgroundFetch"), object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            completionHandler(.newData)
        }
    }

    // MARK: - APNs TOKEN UPLOAD LÊN FIRESTORE (để server push về thiết bị này qua FCM)
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenStr = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[AppDelegate] APNs token: \(tokenStr)")

        // Lưu local để dùng khi upload
        UserDefaults.standard.set(tokenStr, forKey: "apns_device_token")

        // Upload token lên Firestore cho field apnsToken của user document
        uploadApnsToken(tokenStr)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] APNs registration failed: \(error)")
    }

    // MARK: - SILENT PUSH NHẬN TỪ SERVER (content-available: 1) → TRIGGER FETCH NGAY LẬP TỨC
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Server gửi silent push báo có ticket mới → fetch ngay, không đợi timer
        print("[AppDelegate] Silent push received: \(userInfo)")
        NotificationCenter.default.post(name: Notification.Name("QLTB_BackgroundFetch"), object: nil)

        // Nếu có ticketId trong payload thì stop alert cũ nếu cần
        if let ticketId = userInfo["ticketId"] as? String, !ticketId.isEmpty {
            DispatchQueue.main.async {
                VoiceNotificationHelper.shared.stopAlert(ticketId: ticketId)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            completionHandler(.newData)
        }
    }

    // MARK: - UPLOAD APNs TOKEN LÊN FIRESTORE
    private func uploadApnsToken(_ token: String) {
        guard let email = UserDefaults.standard.string(forKey: "saved_auth_email"),
              !email.isEmpty,
              let companyId = UserDefaults.standard.string(forKey: "saved_auth_company_id"),
              !companyId.isEmpty else { return }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let encodedEmail = cleanEmail.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cleanEmail

        // PATCH apnsToken vào document user trong Firestore
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/users/\(encodedEmail)?updateMask.fieldPaths=apnsToken&updateMask.fieldPaths=platform"
        guard let url = URL(string: urlStr) else { return }

        let body: [String: Any] = [
            "fields": [
                "apnsToken": ["stringValue": token],
                "platform": ["stringValue": "iOS"]
            ]
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 10

        if let idToken = UserDefaults.standard.string(forKey: "saved_auth_token"), !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { _, resp, err in
            if let httpResp = resp as? HTTPURLResponse {
                print("[AppDelegate] APNs token upload: \(httpResp.statusCode)")
            } else if let err = err {
                print("[AppDelegate] APNs token upload error: \(err)")
            }
        }.resume()
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

