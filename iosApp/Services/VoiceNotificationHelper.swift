import Foundation
import AVFoundation
import AudioToolbox
import UIKit
import UserNotifications

// MARK: - VOICE NOTIFICATION HELPER (ĐỒNG BỘ 1:1 VỚI VOICENOTIFICATIONHELPER.KT TRÊN ANDROID)
public class VoiceNotificationHelper: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = VoiceNotificationHelper()

    private let synthesizer = AVSpeechSynthesizer()
    private var vietnameseVoice: AVSpeechSynthesisVoice?

    // Thời điểm ứng dụng khởi chạy (ms) - Tránh đọc dồn thông báo cũ
    public let appStartTime: Int64 = Int64(Date().timeIntervalSince1970 * 1000)

    // Theo dõi các ticket đã phát giọng nói
    private var isFirstFetch: Bool = true
    private var seenTicketIds = Set<String>()
    private var seenDispatches: [String: Int64] = [:]
    private var seenRatings: [String: Int64] = [:]
    private var seenResolved: [String: Int64] = [:]
    private var seenHandoffs: [String: Int64] = [:]

    // Vòng lặp cảnh báo lặp lại (Repeating Alert cho Lệnh Điều Phối)
    private var alertTask: Task<Void, Never>? = nil
    public private(set) var activeAlertTicketId: String? = nil
    public private(set) var activeAlertType: String? = nil
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // Hàng đợi thông báo giọng nói tuần tự (Đồng bộ 1:1 helpdeskQueue trên Android)
    public struct NotificationQueueItem {
        let ticketId: String
        let speechText: String
        let fallbackBundledName: String?
        let type: String
    }
    private var notificationQueue: [NotificationQueueItem] = []
    private var isQueueWorkerRunning = false
    private let queueLock = NSLock()
    private var processedNotificationKeys = Set<String>()

    // MARK: - CẤU HÌNH GIỌNG NÓI & ĐIỀU KHIỂN TỪ ADMIN
    public var isVoiceEnabled: Bool {
        UserDefaults.standard.object(forKey: "key_voice_tts_enabled") as? Bool ?? true
    }

    public var isSoundEnabled: Bool {
        UserDefaults.standard.object(forKey: "key_sound_notification_enabled") as? Bool ?? true
    }

    public var voiceNotificationMode: String {
        get { UserDefaults.standard.string(forKey: "key_voice_notification_mode") ?? "REPEAT" }
        set { UserDefaults.standard.set(newValue, forKey: "key_voice_notification_mode") }
    }

    public var effectiveVoiceMode: String {
        let devEnabled = UserDefaults.standard.object(forKey: "key_dev_portal_voice_enabled") as? Bool ?? true
        if !devEnabled || !isSoundEnabled || !isVoiceEnabled { return "OFF" }
        let devMode = UserDefaults.standard.string(forKey: "key_dev_portal_voice_mode") ?? "REPEAT"
        if devMode == "OFF" { return "OFF" }
        let localMode = voiceNotificationMode
        if localMode == "OFF" { return "OFF" }
        if devMode == "ONCE" || localMode == "ONCE" { return "ONCE" }
        return "REPEAT"
    }

    private override init() {
        super.init()
        synthesizer.delegate = self

        // Tìm giọng tiếng Việt (vi-VN)
        let voices = AVSpeechSynthesisVoice.speechVoices()
        self.vietnameseVoice = voices.first(where: { $0.language == "vi-VN" }) ?? AVSpeechSynthesisVoice(language: "vi-VN")

        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        } catch {
            print("[VoiceNotificationHelper] Configure audio session error: \(error)")
        }
    }

    // MARK: - BACKGROUND TASK MANAGEMENT (GIỮ APP HOẠT ĐỘNG TRONG NỀN KHI CẢNH BÁO)
    private func beginBackgroundTask() {
        if backgroundTaskId == .invalid {
            backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "QLTB_Voice_Alert") { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    // MARK: - RUNG THIẾT BỊ MẠNH MẼ (HAPTIC & PHYSICAL VIBRATION ĐỒNG BỘ ANDROID)
    public func triggerVibration() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.prepare()
            impact.impactOccurred()
        }
    }

    // MARK: - ĐỒNG BỘ CẤU HÌNH ADMIN TỪ FIRESTORE (companies/{cid}/system_config/system_toggle_config)
    public func syncAdminConfig(companyId: String, idToken: String = "") {
        guard !companyId.isEmpty else { return }
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp)/system_config/system_toggle_config"
        guard let url = URL(string: urlStr) else { return }

        Task {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            request.timeoutInterval = 8.0

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let fields = json["fields"] as? [String: Any] {
                        let mode = FirestoreHelper.getString(fields, "voiceNotificationMode")
                        let soundEnabled = FirestoreHelper.getBool(fields["enableNotificationSound"] as? [String: Any], defaultValue: true)

                        let cleanMode = mode.isEmpty ? "REPEAT" : mode.uppercased()
                        UserDefaults.standard.set(cleanMode, forKey: "key_dev_portal_voice_mode")
                        UserDefaults.standard.set(soundEnabled, forKey: "key_dev_portal_voice_enabled")
                    }
                }
            } catch {
                print("[VoiceNotificationHelper] Sync admin config error: \(error)")
            }
        }
    }

    // MARK: - THẢ HEADS-UP BANNER TỪ ĐỈNH MÀN HÌNH XUỐNG KÈM ACTION
    public func showHeadsUpNotification(
        title: String,
        message: String,
        ticketId: String,
        actionTitle: String = "",
        actionType: String = ""
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        content.userInfo = ["ticketId": ticketId, "actionType": actionType]
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }
        if !actionType.isEmpty {
            content.categoryIdentifier = actionType == "ACK_DISPATCH" ? "DISPATCH_ALERT" : "NEW_TICKET_ALERT"
        }

        let notifId = "qltb_\(ticketId)_\(actionType)_\(Int(Date().timeIntervalSince1970))"
        let request = UNNotificationRequest(
            identifier: notifId,
            content: content,
            trigger: nil // Gửi ngay tức thì
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[VoiceNotificationHelper] Notification error: \(error)")
            }
        }
    }

    // MARK: - LÀM SẠCH VÀ CHUYỂN ĐỔI MÃ ĐƠN VỊ THÀNH TÊN SIÊU THỊ TỰ NHIÊN
    public func cleanDonViName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Hiện trường" }

        // 1. Phân giải nhanh qua CoopmartDirectory
        if let store = CoopmartDirectory.resolveLocation(trimmed) {
            var name = store.name
            name = name.replacingOccurrences(of: "(?i)^CO\\.?OPMART\\s*", with: "Coopmart ", options: .regularExpression)
            name = name.replacingOccurrences(of: "(?i)^CO\\.?OPFOOD\\s*", with: "Coopfood ", options: .regularExpression)
            name = name.replacingOccurrences(of: "(?i)^CO\\.?OPSMILE\\s*", with: "Coopsmile ", options: .regularExpression)
            name = name.replacingOccurrences(of: "(?i)^CO\\.?OPXTRA\\s*", with: "Coopxtra ", options: .regularExpression)
            return name
        }

        // 2. Dọn dẹp tiền tố mã đơn vị như "[047] - ", "047 - ", "Đơn vị: "
        var cleaned = trimmed
        cleaned = cleaned.replacingOccurrences(of: "^\\[?[0-9A-Za-z_-]+\\]?\\s*[-_:–.]\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "(?i)^(don vi|chi nhanh|st|kho|van phong)\\s*:\\s*", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        if let store2 = CoopmartDirectory.resolveLocation(cleaned) {
            var name = store2.name
            name = name.replacingOccurrences(of: "(?i)^CO\\.?OPMART\\s*", with: "Coopmart ", options: .regularExpression)
            return name
        }

        return cleaned.isEmpty ? trimmed : cleaned
    }

    // MARK: - CHUẨN HÓA NGỮ ÂM TIẾNG VIỆT (ĐỒNG BỘ 1:1 normalizeVietnameseSpeech TRÊN ANDROID)
    public func normalizeVietnameseSpeech(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var t = text

        // 1. Dọn dẹp URL, domain, đuôi email
        t = t.replacingOccurrences(of: "(?i)@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bhttps?://\\S+", with: "", options: .regularExpression)

        // 2. Hệ thống siêu thị Saigon Co.op
        t = t.replacingOccurrences(of: "(?i)\\bCo\\.?op\\s*mart\\b", with: "Cô-ốp-mát", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCoopmart\\b", with: "Cô-ốp-mát", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCo\\.?op\\s*food\\b", with: "Cô-ốp-phút", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCoopfood\\b", with: "Cô-ốp-phút", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCo\\.?op\\s*smile\\b", with: "Cô-ốp-xờ-mai", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCoopsmile\\b", with: "Cô-ốp-xờ-mai", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCo\\.?op\\s*xtra\\b", with: "Cô-ốp-ét-tra", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCoopxtra\\b", with: "Cô-ốp-ét-tra", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bFinelife\\b", with: "Phai-lai", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bSense\\s*city\\b", with: "Sen-xi-ti", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bSCA\\b", with: "Ét-xi-ê", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bHTV\\s*Co\\.?op\\b", with: "Hát Tê Vê Cô ốp", options: .regularExpression)

        // 3. Kênh và công nghệ
        t = t.replacingOccurrences(of: "(?i)\\bZalo\\b", with: "Da-lô", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bEmail\\b", with: "I-meo", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bOA\\b", with: "Doanh nghiệp", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bApp\\b", with: "Ứng dụng", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bKTV\\b", with: "Kỹ thuật viên", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCNTT\\b", with: "Công nghệ thông tin", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCĐS\\b", with: "Chuyển đổi số", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bIT\\b", with: "Ai-ti", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bSLA\\b", with: "Thời hạn cam kết", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bOT\\b", with: "Tăng ca", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCheck[- ]?in\\b", with: "Điểm danh vào ca", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCheck[- ]?out\\b", with: "Điểm danh tan ca", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTickets?\\b", with: "Phiếu yêu cầu", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bAdmin\\b", with: "Quản trị viên", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bHelpdesk\\b", with: "Bộ phận hỗ trợ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bOffline\\b", with: "Mất kết nối", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bOnline\\b", with: "Trực tuyến", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bPOS\\b", with: "Máy pốt", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCall\\b", with: "Cuộc gọi", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bHotline\\b", with: "Đường dây nóng", options: .regularExpression)

        // 4. Đơn vị hành chính
        t = t.replacingOccurrences(of: "(?i)\\bHTX\\b", with: "Hợp tác xã", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTP\\.HCM\\b", with: "Thành phố Hồ Chí Minh", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTPHCM\\b", with: "Thành phố Hồ Chí Minh", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTP\\.\\s*", with: "Thành phố ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTX\\.\\s*", with: "Thị xã ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTT\\.\\s*", with: "Thị trấn ", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCN\\b", with: "Chi nhánh", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCH\\b", with: "Cửa hàng", options: .regularExpression)

        // 5. Ký tự thừa
        t = t.replacingOccurrences(of: "[#*_\\[\\]()~`><]", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - PHÁT GIỌNG ĐỌC NEURAL BTV VTV HOÀI MY (ÂM LƯỢNG LỚN TỐI ĐA)
    public func speak(text: String, fallbackBundledName: String? = nil) {
        guard isVoiceEnabled else { return }
        let cleanText = normalizeVietnameseSpeech(text)
        guard !cleanText.isEmpty else { return }

        // Cấu hình Session đảm bảo phát qua Loa Ngoài cực đại
        configureAudioSession()

        // Ưu tiên chuẩn giọng Nữ BTV VTV (vi-VN-HoaiMyNeural) kết hợp tệp âm thanh gốc R.raw
        EdgeTtsClient.shared.speak(text: cleanText, fallbackBundledName: fallbackBundledName, voice: "vi-VN-HoaiMyNeural")
    }

    // MARK: - HÀNG ĐỢI THÔNG BÁO GIỌNG NÓI TUẦN TỰ (ĐỒNG BỘ 1:1 VỚI ANDROID)
    private func enqueueNotification(ticketId: String, speechText: String, fallbackBundledName: String?, type: String) {
        queueLock.lock()
        let dedupKey = "\(type)_\(ticketId)"
        if processedNotificationKeys.contains(dedupKey) {
            queueLock.unlock()
            return
        }
        processedNotificationKeys.insert(dedupKey)
        notificationQueue.append(NotificationQueueItem(ticketId: ticketId, speechText: speechText, fallbackBundledName: fallbackBundledName, type: type))
        queueLock.unlock()

        processNextQueueItem()
    }

    private func processNextQueueItem() {
        queueLock.lock()
        guard !isQueueWorkerRunning, !notificationQueue.isEmpty else {
            queueLock.unlock()
            return
        }
        isQueueWorkerRunning = true
        let item = notificationQueue.removeFirst()
        queueLock.unlock()

        Task { [weak self] in
            guard let self = self else { return }

            // Nếu đang có cảnh báo điều phối khẩn cấp (activeAlertTicketId != nil), nhường ưu tiên
            if self.activeAlertTicketId != nil && self.activeAlertType == "DISPATCH" {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self.queueLock.lock()
                self.isQueueWorkerRunning = false
                self.queueLock.unlock()
                self.processNextQueueItem()
                return
            }

            let mode = self.effectiveVoiceMode
            if self.isVoiceEnabled && mode != "OFF" {
                self.triggerVibration()
                let cleanSpeech = self.normalizeVietnameseSpeech(item.speechText)

                if item.type == "NEW_TICKET" {
                    if item.fallbackBundledName == "voice_new_ticket_email" {
                        // Kênh Email: Chỉ phát âm thanh mở đầu
                        await EdgeTtsClient.shared.playBundledAudioSuspend(named: "voice_new_ticket_email")
                        if mode == "REPEAT" {
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            await EdgeTtsClient.shared.playBundledAudioSuspend(named: "voice_new_ticket_email")
                        }
                    } else {
                        // CÂU 1 (LUÔN PHÁT TRƯỚC 1 LẦN): "Bạn có yêu cầu hỗ trợ mới cần tiếp nhận"
                        if let bundled = item.fallbackBundledName {
                            await EdgeTtsClient.shared.playBundledAudioSuspend(named: bundled)
                            try? await Task.sleep(nanoseconds: 400_000_000)
                        }

                        // CÂU 2 (TÊN ĐƠN VỊ CẦN HỖ TRỢ): "[Đơn vị] cần hỗ trợ" qua giọng Hoài My Neural (dự phòng fallback nếu offline)
                        await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: item.fallbackBundledName)

                        // Nếu cấu hình REPEAT: Nghỉ 800ms rồi lặp lại CÂU 2 (tên đơn vị) - KHÔNG lặp lại Câu 1 intro để tránh vấp
                        if mode == "REPEAT" {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: item.fallbackBundledName)
                        }
                    }
                } else if item.type == "TICKET_RATED" {
                    // Đánh giá: Lần 1 phát intro, Lần 2 đọc chi tiết số sao
                    if let bundled = item.fallbackBundledName {
                        await EdgeTtsClient.shared.playBundledAudioSuspend(named: bundled)
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                    await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: nil)
                } else if item.type == "TICKET_RESOLVED" {
                    // KTV Báo xử lý xong: Phát trực tiếp câu hoàn chỉnh, không lồng intro mp3
                    await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: nil)
                    if mode == "REPEAT" {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: nil)
                    }
                } else {
                    // CÂU 1: Đọc và CHỜ HOÀN TẤT
                    await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: item.fallbackBundledName)

                    // Nếu cấu hình REPEAT: Nghỉ 800ms rồi lặp lại CÂU 2 và CHỜ HOÀN TẤT
                    if mode == "REPEAT" {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        await EdgeTtsClient.shared.speakSuspend(text: cleanSpeech, fallbackBundledName: item.fallbackBundledName)
                    }
                }

                try? await Task.sleep(nanoseconds: 600_000_000)
            }

            self.queueLock.lock()
            self.isQueueWorkerRunning = false
            self.queueLock.unlock()

            self.processNextQueueItem()
        }
    }

    // MARK: - VÒNG LẶP CẢNH BÁO LẶP LẠI (CHO ĐẾN KHI TIẾP NHẬN HOẶC THEO CẤU HÌNH ADMIN)
    private func startRepeatingAlert(
        ticketId: String,
        speechText: String,
        type: String,
        fallbackBundledName: String? = "voice_dispatch_urgent",
        intervalSeconds: Double = 8.0
    ) {
        if activeAlertTicketId == ticketId && alertTask != nil {
            return
        }

        if activeAlertTicketId != nil {
            stopAlert(ticketId: activeAlertTicketId)
        }

        activeAlertTicketId = ticketId
        activeAlertType = type

        beginBackgroundTask()

        alertTask = Task { [weak self] in
            guard let self = self else { return }
            var repeatCount = 0
            let mode = self.effectiveVoiceMode
            // Cảnh báo khẩn cấp cho KTV: Lặp lại tối đa 6 lần hoặc đến khi bấm nhận, chu kỳ 8s SAU KHI nói xong
            let maxRepeats = (mode == "OFF" || !self.isVoiceEnabled) ? 0 : (mode == "ONCE" ? 1 : (type == "DISPATCH" ? 6 : 2))

            while !Task.isCancelled && self.activeAlertTicketId == ticketId && repeatCount < maxRepeats {
                repeatCount += 1

                // 1. Rung máy mạnh mẽ
                self.triggerVibration()

                // 2. Đọc giọng nói (chờ đọc xong hoàn toàn)
                if self.isVoiceEnabled && mode != "OFF" {
                    let clean = self.normalizeVietnameseSpeech(speechText)
                    await EdgeTtsClient.shared.speakSuspend(text: clean, fallbackBundledName: fallbackBundledName)
                    if mode == "REPEAT" && !Task.isCancelled && self.activeAlertTicketId == ticketId {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        await EdgeTtsClient.shared.speakSuspend(text: clean, fallbackBundledName: fallbackBundledName)
                    }
                }

                // 3. Nghỉ chu kỳ lặp lại (8 giây SAU KHI NÓI XONG)
                if repeatCount < maxRepeats && !Task.isCancelled && self.activeAlertTicketId == ticketId {
                    try? await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
                }
            }

            if self.activeAlertTicketId == ticketId {
                self.stopAlert(ticketId: ticketId)
            }
        }
    }

    public func stopAlert(ticketId: String? = nil) {
        if let tid = ticketId, let cur = activeAlertTicketId, cur != tid {
            // Không phải ticket đang cảnh báo
        } else {
            activeAlertTicketId = nil
            activeAlertType = nil
            alertTask?.cancel()
            alertTask = nil
            endBackgroundTask()
            EdgeTtsClient.shared.stop()
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
        }

        // Xóa khỏi hàng đợi thông báo
        queueLock.lock()
        if let tid = ticketId {
            notificationQueue.removeAll(where: { $0.ticketId == tid })
        } else {
            notificationQueue.removeAll()
        }
        queueLock.unlock()

        if let tid = ticketId {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
                "qltb_\(tid)_ACK_DISPATCH",
                "qltb_\(tid)_ACK_NEW_TICKET"
            ])
        }
    }

    // MARK: - 1. SỰ CỐ MỚI (Cho Admin / HelpDesk - ĐỒNG BỘ 1:1 DESKTOP & WEB & ANDROID)
    public func notifyNewSupportRequest(ticketId: String, donViName: String, subject: String = "", source: String = "APP") {
        let dv = cleanDonViName(donViName)
        let cleanSource = source.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isZalo = cleanSource == "ZALO"
        let isEmail = cleanSource == "EMAIL"

        let title = isZalo ? "💬 HỖ TRỢ ZALO MỚI!" : (isEmail ? "✉️ HỖ TRỢ EMAIL MỚI!" : "🚨 YÊU CẦU HỖ TRỢ MỚI!")
        let message = isZalo ? "📍 Zalo OA: \(dv) gửi yêu cầu" : (isEmail ? "📍 Email: \(dv) gửi yêu cầu" : "📍 \(dv) cần hỗ trợ kỹ thuật")

        // Thống nhất 100% như Desktop và Web: Không đọc mã ticket hay nội dung sự cố!
        let speechText = isZalo
            ? "Có yêu cầu hỗ trợ mới qua Da-lô từ \(dv)"
            : (isEmail ? "Có yêu cầu hỗ trợ mới qua Email từ \(dv)" : "\(dv) cần hỗ trợ")

        showHeadsUpNotification(
            title: title,
            message: message,
            ticketId: ticketId,
            actionTitle: "✅ ĐÃ TIẾP NHẬN",
            actionType: "ACK_NEW_TICKET"
        )

        let fallback = isZalo ? "voice_new_ticket_zalo" : (isEmail ? "voice_new_ticket_email" : "voice_new_ticket")
        enqueueNotification(ticketId: ticketId, speechText: speechText, fallbackBundledName: fallback, type: "NEW_TICKET")
    }

    // MARK: - 1.1 PHIẾU CHUYỂN TRẢ VỀ HELPDESK (Cho TẤT CẢ User HelpDesk)
    public func notifyHandoverToHelpDesk(ticketId: String, donViName: String, subject: String = "", reason: String = "") {
        let dv = cleanDonViName(donViName)
        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = "↩️ PHIẾU CHUYỂN TRẢ VỀ HELPDESK!"
        let message = "📍 \(dv): \(cleanReason.isEmpty ? (subject.isEmpty ? "Cần tiếp nhận lại" : subject) : cleanReason)"
        let text = "Kỹ thuật viên đã chuyển trả yêu cầu hỗ trợ từ \(dv) về HelpDesk tiếp nhận lại."

        showHeadsUpNotification(
            title: title,
            message: message,
            ticketId: ticketId,
            actionTitle: "✅ ĐÃ TIẾP NHẬN",
            actionType: "ACK_NEW_TICKET"
        )

        enqueueNotification(ticketId: ticketId, speechText: text, fallbackBundledName: "voice_new_ticket", type: "HANDOVER")
    }

    // MARK: - 2. ĐIỀU PHỐI KTV / CHUYÊN VIÊN (ĐỒNG BỘ 1:1 VỚI ANDROID & DESKTOP & WEB)
    public func notifyTechnicianDispatched(ticketId: String, donViName: String, subject: String = "", isSpecialist: Bool) {
        let cleanDonVi = cleanDonViName(donViName)
        let title = isSpecialist ? "📢 LỆNH PHÂN CÔNG CHUYÊN VIÊN!" : "📢 YÊU CẦU HỖ TRỢ MỚI!"
        let message = "📍 Đơn vị: \(cleanDonVi) (Bấm để nhận ca)"
        let text = isSpecialist ?
            "Chuyên viên, bạn có yêu cầu hỗ trợ mới từ \(cleanDonVi)! Xin vui lòng bấm tiếp nhận ca!" :
            "Bạn có yêu cầu hỗ trợ mới từ \(cleanDonVi)! Xin vui lòng bấm tiếp nhận ca!"

        showHeadsUpNotification(
            title: title,
            message: message,
            ticketId: ticketId,
            actionTitle: "✅ TIẾP NHẬN XỬ LÝ",
            actionType: "ACK_DISPATCH"
        )

        startRepeatingAlert(
            ticketId: ticketId,
            speechText: text,
            type: "DISPATCH",
            fallbackBundledName: "voice_dispatch_urgent",
            intervalSeconds: 8.0
        )
    }

    // MARK: - 3. KHÁCH HÀNG ĐÁNH GIÁ (ĐỒNG BỘ 1:1 DESKTOP & WEB & ANDROID)
    public func notifyTicketRated(ticketId: String, rating: Int, feedback: String, donViName: String) {
        let dv = cleanDonViName(donViName)
        let text = "Đơn vị \(dv) vừa đánh giá \(rating) sao"
        
        let fbSnippet = feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\nÝ kiến: \(feedback.prefix(50))"
        showHeadsUpNotification(
            title: "⭐ ĐÁNH GIÁ MỚI: \(rating)/5★",
            message: "📍 \(dv)\(fbSnippet)\n(Đã nghiệm thu đóng phiếu)",
            ticketId: ticketId,
            actionTitle: "🔍 XEM CHI TIẾT",
            actionType: "VIEW_TICKET"
        )

        enqueueNotification(ticketId: ticketId, speechText: text, fallbackBundledName: "voice_rating_received", type: "TICKET_RATED")
    }

    // MARK: - 4. KTV BÁO ĐÃ XỬ LÝ XONG SỰ CỐ / NGƯỜI YÊU CẦU TỰ XỬ LÝ (ĐỒNG BỘ 1:1 DESKTOP & WEB & ANDROID)
    public func notifyTicketResolved(ticketId: String, donViName: String, subject: String = "", techName: String, resolvedReason: String = "", isSpecialist: Bool = false) {
        let dv = cleanDonViName(donViName)
        let isSelfResolved = resolvedReason.uppercased() == "SELF_RESOLVED"
        let rawTech = techName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedTech = rawTech
            .replacingOccurrences(of: "(?i)^(KTV|Kỹ thuật viên|Chuyên viên|CV)\\s*[:-]?\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rolePrefix = isSpecialist ? "Chuyên viên" : "Kỹ thuật viên"
        let displayName = (!sanitizedTech.isEmpty && !["ktv", "kỹ thuật viên", "chuyên viên"].contains(sanitizedTech.lowercased()))
            ? "\(rolePrefix) \(sanitizedTech)"
            : rolePrefix

        let title = isSelfResolved ? "💡 NGƯỜI YÊU CẦU ĐÃ TỰ XỬ LÝ" : (isSpecialist ? "💻 CHUYÊN VIÊN ĐÃ XỬ LÝ XONG" : "🛠️ ĐÃ XỬ LÝ XONG SỰ CỐ")
        let message = isSelfResolved ? "📍 \(dv) - Người yêu cầu đã tự xử lý xong sự cố • Dừng KTV" : "📍 \(dv) - \(displayName) đã xử lý xong\n(Bấm để kiểm tra và nghiệm thu)"
        let text = isSelfResolved
            ? "Người yêu cầu tại \(dv) đã tự xử lý xong sự cố."
            : "\(displayName) đã xử lý xong sự cố tại \(dv), mời bạn đánh giá và nghiệm thu."

        showHeadsUpNotification(
            title: title,
            message: message,
            ticketId: ticketId,
            actionTitle: "🔍 NGHIỆM THU NGAY",
            actionType: "VIEW_TICKET"
        )

        enqueueNotification(ticketId: ticketId, speechText: text, fallbackBundledName: "voice_ticket_resolved", type: "TICKET_RESOLVED")
    }

    // MARK: - BỘ LỌC CHỐNG ĐỌC DỒN KHI MỞ NỀN TẢNG KHÁC (CROSS-PLATFORM DEDUPLICATION)
    public func processTicketUpdates(tickets: [SupportTicket], currentUser: User) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let fiveMinutesAgo = now - 300_000

        let cleanEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 0. Nếu vé đang cảnh báo lặp lại đã được tiếp nhận / giải quyết / đóng -> DỪNG NGAY CẢNH BÁO
        if let activeId = activeAlertTicketId,
           let currentTicket = tickets.first(where: { $0.id == activeId }) {
            if currentTicket.isAcknowledged || currentTicket.isClosed || currentTicket.isResolved {
                stopAlert(ticketId: activeId)
            }
        }

        // Lần đầu mở app: Ghi nhận tất cả các vé hiện có để tránh đọc dồn lịch sử xa xưa
        if isFirstFetch {
            isFirstFetch = false
            for t in tickets {
                seenTicketIds.insert(t.id)
                let effAssign = t.assignedAt > 0 ? (t.assignedAt < 10_000_000_000 ? t.assignedAt * 1000 : t.assignedAt) : t.createdAt
                if effAssign > 0 {
                    seenDispatches[t.id] = effAssign
                }
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                if rateTime > 0 { seenRatings[t.id] = rateTime }
                if t.resolvedAt > 0 { seenResolved[t.id] = t.resolvedAt }
                let handoffTime = t.lastMessageAt
                if handoffTime > 0 { seenHandoffs[t.id] = handoffTime }
            }
            return
        }

        for t in tickets {
            // Không xử lý ticket bị hủy hoặc bị từ chối
            if t.isInvalid || !t.invalidReason.isEmpty || t.status.uppercased() == "REJECTED" || t.status.uppercased() == "TU_CHOI" {
                continue
            }

            let effectiveDonVi = !t.donVi.isEmpty ? t.donVi : (!t.assignedDepartmentName.isEmpty ? t.assignedDepartmentName : (!t.creatorAddress.isEmpty ? t.creatorAddress : "Hiện trường"))

            // 1. SỰ CỐ MỚI GỬI LÊN (Chỉ HelpDesk và Admin mới nhận)
            let isDispatched = !t.assignedTo.isEmpty || !t.assignedToEmail.isEmpty || t.assignedAt > 0 || !t.assignedDepartmentId.isEmpty
            let isCreatedAfterStart = t.createdAt >= appStartTime && t.createdAt >= fiveMinutesAgo
            let isNotSelf = t.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != cleanEmail

            if !seenTicketIds.contains(t.id) {
                seenTicketIds.insert(t.id)
                if !isDispatched && isCreatedAfterStart && isNotSelf && (currentUser.isHelpDesk || currentUser.isAdmin) && t.status.uppercased() == "OPEN" {
                    notifyNewSupportRequest(ticketId: t.id, donViName: effectiveDonVi, subject: t.subject, source: t.source)
                }
            }

            // 1.1 VÉ ĐƯỢC KTV CHUYỂN TRẢ VỀ CHO HELPDESK TIẾP NHẬN LẠI (TẤT CẢ USER HELPDESK / ADMIN ĐỀU NHẬN)
            let isHandedOverToHelpDesk = t.lastMessage.contains("[Chuyển về HelpDesk]") || t.lastMessage.contains("chuyển trả ticket cho HelpDesk")
            if isHandedOverToHelpDesk && (currentUser.isHelpDesk || currentUser.isAdmin) {
                let lastSeenHandoff = seenHandoffs[t.id] ?? 0
                let effHandoffAt = t.lastMessageAt > 0 ? t.lastMessageAt : now
                let isFreshHandoff = (now - effHandoffAt) <= 300_000 // Trong vòng 5 phút
                if effHandoffAt > lastSeenHandoff && (isFreshHandoff || effHandoffAt >= appStartTime) {
                    seenHandoffs[t.id] = effHandoffAt
                    notifyHandoverToHelpDesk(ticketId: t.id, donViName: effectiveDonVi, subject: t.subject, reason: t.dispatchNote)
                } else if lastSeenHandoff == 0 {
                    seenHandoffs[t.id] = effHandoffAt
                }
            }

            // 2. LỆNH ĐIỀU PHỐI CHO KTV / CHUYÊN VIÊN
            // Đồng bộ 1:1 với Android: Admin, HelpDesk, Quản lý KHÔNG BAO GIỜ nhận broadcast dispatch của cụm/chuyên viên!
            let isPrimary = t.isUserAssigned(email: cleanEmail)
            let isSpecialistMatch = (t.isSpecialistAssigned || t.assignedRole.uppercased() == "SPECIALIST") && currentUser.isSpecialist && t.assignedToEmail.isEmpty && (
                (!currentUser.toNghiepVu.isEmpty && currentUser.toNghiepVu == t.toNghiepVu) ||
                (!currentUser.departmentId.isEmpty && currentUser.departmentId == t.assignedDepartmentId) ||
                (!currentUser.departmentName.isEmpty && currentUser.departmentName == t.assignedDepartmentName)
            )
            let isClusterMatch = currentUser.isTechnician && t.assignedToEmail.isEmpty && !t.assignedCluster.isEmpty && (
                currentUser.maKhuVuc == t.assignedCluster
            )

            let isFieldTech = currentUser.isTechnician || currentUser.isSpecialist
            let isAssignedToMe = !currentUser.isAdmin && !currentUser.isHelpDesk && !currentUser.isManager &&
                                (isPrimary || (isFieldTech && (isSpecialistMatch || isClusterMatch))) &&
                                !t.isAcknowledged && !t.isClosed && !t.isResolved

            let effectiveAssignedAt = t.assignedAt > 0 ? (t.assignedAt < 10_000_000_000 ? t.assignedAt * 1000 : t.assignedAt) : t.createdAt

            if isAssignedToMe && effectiveAssignedAt > 0 {
                let lastSeenAssign = seenDispatches[t.id] ?? 0
                let isFreshDispatch = (now - effectiveAssignedAt) <= 300_000 // Trong vòng 5 phút
                let hasNotAnnounced = lastSeenAssign == 0 || effectiveAssignedAt > lastSeenAssign

                if isFreshDispatch && hasNotAnnounced {
                    seenDispatches[t.id] = effectiveAssignedAt
                    let isSpecialist = t.isSpecialistAssigned || t.assignedRole.uppercased() == "SPECIALIST" || isSpecialistMatch
                    notifyTechnicianDispatched(ticketId: t.id, donViName: effectiveDonVi, subject: t.subject, isSpecialist: isSpecialist)
                } else if lastSeenAssign == 0 {
                    seenDispatches[t.id] = effectiveAssignedAt
                }
            }

            // 3. ĐÁNH GIÁ MỚI TỪ KHÁCH HÀNG
            if t.rating > 0 {
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                let lastSeenRate = seenRatings[t.id] ?? 0
                let isFreshRating = rateTime > lastSeenRate && (rateTime >= appStartTime || rateTime >= fiveMinutesAgo)
                if isFreshRating {
                    seenRatings[t.id] = rateTime
                    notifyTicketRated(ticketId: t.id, rating: t.rating, feedback: t.feedback, donViName: effectiveDonVi)
                } else if lastSeenRate == 0 {
                    seenRatings[t.id] = rateTime
                }
            }

            // 4. KTV BÁO ĐÃ XỬ LÝ XONG SỰ CỐ / NGƯỜI YÊU CẦU TỰ XỬ LÝ
            let isSelf = t.isSelfResolved || t.resolvedReason.uppercased() == "SELF_RESOLVED"
            let isResolvedCase = (t.resolvedAt > 0 && t.isResolved) || (isSelf && (t.isClosed || t.isResolved))
            let isStaffTarget = currentUser.isAdmin || currentUser.isHelpDesk || t.isUserAssigned(email: cleanEmail)
            if isResolvedCase && isStaffTarget {
                let resolvedTimestamp = t.resolvedAt > 0 ? t.resolvedAt : t.closedAt
                let lastSeenRes = seenResolved[t.id] ?? 0
                let isFreshResolved = resolvedTimestamp > lastSeenRes && (resolvedTimestamp >= appStartTime || resolvedTimestamp >= fiveMinutesAgo)
                if isFreshResolved {
                    seenResolved[t.id] = resolvedTimestamp
                    let isSpecialist = t.isSpecialistAssigned || t.assignedRole.uppercased() == "SPECIALIST"
                    notifyTicketResolved(
                        ticketId: t.id,
                        donViName: effectiveDonVi,
                        subject: t.subject,
                        techName: t.resolvedByName,
                        resolvedReason: t.resolvedReason,
                        isSpecialist: isSpecialist
                    )
                } else if lastSeenRes == 0 {
                    seenResolved[t.id] = resolvedTimestamp
                }
            }
        }
    }
}
