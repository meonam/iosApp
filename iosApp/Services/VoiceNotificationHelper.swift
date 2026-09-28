import Foundation
import AVFoundation

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

    private var isVoiceEnabled: Bool {
        UserDefaults.standard.object(forKey: "key_voice_tts_enabled") as? Bool ?? true
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
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        } catch {
            print("[VoiceNotificationHelper] Configure audio session error: \(error)")
        }
    }

    // MARK: - CHUẨN HÓA NGỮ ÂM TIẾNG VIỆT (ĐỒNG BỘ 1:1 normalizeVietnameseSpeech TRÊN ANDROID)
    public func normalizeVietnameseSpeech(_ text: String) -> String {
        guard !text.isEmpty else { return "" }
        var t = text

        // Xóa URL, domain, đuôi email
        t = t.replacingOccurrences(of: "@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)

        // Hệ thống siêu thị Saigon Co.op
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

        // Kênh và công nghệ
        t = t.replacingOccurrences(of: "(?i)\\bZalo\\b", with: "Da-lô", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bEmail\\b", with: "I-meo", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bApp\\b", with: "Ứng dụng", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bKTV\\b", with: "Kỹ thuật viên", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bCNTT\\b", with: "Công nghệ thông tin", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bIT\\b", with: "Ai-ti", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bSLA\\b", with: "Thời hạn cam kết", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?i)\\bTickets?\\b", with: "Phiếu yêu cầu", options: .regularExpression)

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func speak(text: String) {
        guard isVoiceEnabled else { return }
        let cleanText = normalizeVietnameseSpeech(text)
        guard !cleanText.isEmpty else { return }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[VoiceNotificationHelper] Set active audio session error: \(error)")
        }

        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = self.vietnameseVoice
        utterance.rate = 0.50 // Tốc độ vừa phải, tự nhiên
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    public func stopAlert() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - 1. SỰ CỐ MỚI (Cho Admin / HelpDesk)
    public func notifyNewSupportRequest(ticketId: String, donViName: String, subject: String, source: String = "APP") {
        let dv = donViName.isEmpty ? "điểm bán" : donViName
        let sj = subject.isEmpty ? "Hỗ trợ kỹ thuật" : subject
        let text = "Có sự cố mới từ đơn vị \(dv). Yêu cầu hỗ trợ: \(sj)"
        speak(text: text)
    }

    // MARK: - 2. ĐIỀU PHỐI KTV / CHUYÊN VIÊN
    public func notifyTechnicianDispatched(ticketId: String, donViName: String, subject: String, isSpecialist: Bool) {
        let prefix = isSpecialist ? "Lệnh điều phối chuyên viên" : "Lệnh điều phối kỹ thuật viên"
        let dv = donViName.isEmpty ? "điểm bán" : donViName
        let sj = subject.isEmpty ? "Hỗ trợ sự cố" : subject
        let text = "\(prefix). Hỗ trợ đơn vị \(dv). Sự cố: \(sj)"
        speak(text: text)
    }

    // MARK: - 3. KHÁCH HÀNG ĐÁNH GIÁ (SAO & PHẢN HỒI)
    public func notifyTicketRated(ticketId: String, rating: Int, feedback: String, donViName: String) {
        let dv = donViName.isEmpty ? "điểm bán" : donViName
        let text = "Khách hàng vừa đánh giá \(rating) sao cho sự cố tại đơn vị \(dv)"
        speak(text: text)
    }

    // MARK: - 4. KTV BÁO ĐÃ XỬ LÝ XONG SỰ CỐ
    public func notifyTicketResolved(ticketId: String, donViName: String, subject: String, techName: String) {
        let dv = donViName.isEmpty ? "điểm bán" : donViName
        let name = techName.isEmpty ? "Kỹ thuật viên" : techName
        let text = "Kỹ thuật viên \(name) báo đã xử lý xong sự cố cho đơn vị \(dv)"
        speak(text: text)
    }

    // MARK: - BỘ LỌC CHỐNG ĐỌC DỒN KHI MỞ NỀN TẢNG KHÁC (CROSS-PLATFORM DEDUPLICATION)
    public func processTicketUpdates(tickets: [SupportTicket], currentUser: User) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let twoMinutesAgo = now - 120_000

        // Lần đầu mở app: Ghi nhận trạng thái hiện tại, KHÔNG đọc dồn bất kỳ thông báo cũ nào
        if isFirstFetch {
            isFirstFetch = false
            for t in tickets {
                seenTicketIds.insert(t.id)
                if t.assignedAt > 0 { seenDispatches[t.id] = t.assignedAt }
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                if rateTime > 0 { seenRatings[t.id] = rateTime }
                if t.resolvedAt > 0 { seenResolved[t.id] = t.resolvedAt }
            }
            return
        }

        let cleanEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for t in tickets {
            // Không xử lý ticket đã đóng, hủy hoặc bị từ chối
            if t.isInvalid || !t.invalidReason.isEmpty || t.status.uppercased() == "REJECTED" || t.status.uppercased() == "TU_CHOI" || t.status.uppercased() == "CLOSED" {
                continue
            }

            // 1. SỰ CỐ MỚI GỬI LÊN
            let isDispatched = !t.assignedTo.isEmpty || !t.assignedToEmail.isEmpty || t.assignedAt > 0 || !t.assignedDepartmentId.isEmpty
            let isCreatedAfterStart = t.createdAt >= appStartTime && t.createdAt >= twoMinutesAgo
            let isNotSelf = t.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != cleanEmail

            if !seenTicketIds.contains(t.id) {
                seenTicketIds.insert(t.id)
                // NẾU ĐÃ ĐIỀU PHỐI RỒI TRÊN NỀN TẢNG KHÁC -> KHÔNG ĐƯỢC ĐỌC "SỰ CỐ MỚI"
                // CHỈ HelpDesk mới nhận giọng đọc vé mới tạo (Chuyên viên, KTV, Quản lý, Admin không nhận):
                if !isDispatched && isCreatedAfterStart && isNotSelf && currentUser.isHelpDesk {
                    notifyNewSupportRequest(ticketId: t.id, donViName: t.donVi, subject: t.subject, source: t.source)
                }
            }

            // 2. LỆNH ĐIỀU PHỐI CHO KTV / CHUYÊN VIÊN
            if t.isUserAssigned(email: cleanEmail) && !t.isAcknowledged && t.assignedAt > 0 {
                let lastSeenAssign = seenDispatches[t.id] ?? 0
                let isFreshDispatch = t.assignedAt > lastSeenAssign && t.assignedAt >= appStartTime && t.assignedAt >= twoMinutesAgo
                let isNotAssigner = t.assignedByEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != cleanEmail

                if isFreshDispatch && isNotAssigner {
                    seenDispatches[t.id] = t.assignedAt
                    notifyTechnicianDispatched(ticketId: t.id, donViName: t.donVi, subject: t.subject, isSpecialist: t.isSpecialistAssigned)
                } else if lastSeenAssign == 0 {
                    seenDispatches[t.id] = t.assignedAt
                }
            }

            // 3. ĐÁNH GIÁ MỚI TỪ KHÁCH HÀNG
            if t.rating > 0 {
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                let lastSeenRate = seenRatings[t.id] ?? 0
                let isFreshRating = rateTime > lastSeenRate && rateTime >= appStartTime && rateTime >= twoMinutesAgo
                if isFreshRating {
                    seenRatings[t.id] = rateTime
                    notifyTicketRated(ticketId: t.id, rating: t.rating, feedback: t.feedback, donViName: t.donVi)
                } else if lastSeenRate == 0 {
                    seenRatings[t.id] = rateTime
                }
            }

            // 4. KTV BÁO ĐÃ XỬ LÝ XONG SỰ CỐ
            if t.resolvedAt > 0 && t.isResolved && (currentUser.isAdmin || currentUser.isHelpDesk) {
                let lastSeenRes = seenResolved[t.id] ?? 0
                let isFreshResolved = t.resolvedAt > lastSeenRes && t.resolvedAt >= appStartTime && t.resolvedAt >= twoMinutesAgo
                if isFreshResolved {
                    seenResolved[t.id] = t.resolvedAt
                    notifyTicketResolved(ticketId: t.id, donViName: t.donVi, subject: t.subject, techName: t.resolvedByName)
                } else if lastSeenRes == 0 {
                    seenResolved[t.id] = t.resolvedAt
                }
            }
        }
    }
}
