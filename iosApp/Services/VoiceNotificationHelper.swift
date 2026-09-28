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

    // MARK: - PHÁT GIỌNG ĐỌC NEURAL BTV VTV HOÀI MY (ĐỒNG BỘ 100% VỚI ANDROID)
    public func speak(text: String) {
        guard isVoiceEnabled else { return }
        let cleanText = normalizeVietnameseSpeech(text)
        guard !cleanText.isEmpty else { return }

        // Ưu tiên chuẩn giọng Nữ BTV VTV (vi-VN-HoaiMyNeural)
        EdgeTtsClient.shared.speak(text: cleanText, voice: "vi-VN-HoaiMyNeural")
    }

    public func stopAlert() {
        EdgeTtsClient.shared.stop()
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

    // MARK: - 2. ĐIỀU PHỐI KTV / CHUYÊN VIÊN (ĐỒNG BỘ 1:1 VỚI ANDROID VOICENOTIFICATIONHELPER.KT)
    public func notifyTechnicianDispatched(ticketId: String, donViName: String, subject: String, isSpecialist: Bool) {
        let cleanDonVi = donViName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hiện trường" : donViName
        let text = isSpecialist ?
            "Chuyên viên, bạn có yêu cầu hỗ trợ mới từ \(cleanDonVi)!" :
            "Bạn có yêu cầu hỗ trợ mới từ \(cleanDonVi)!"
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
        let threeMinutesAgo = now - 180_000

        let cleanEmail = currentUser.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Lần đầu mở app: Ghi nhận các vé cũ hơn 3 phút để tránh đọc dồn lịch sử xa xưa
        if isFirstFetch {
            isFirstFetch = false
            for t in tickets {
                seenTicketIds.insert(t.id)
                // Chỉ đánh dấu đã xem nếu lệnh điều phối đã cũ (> 3 phút) hoặc KTV đã tiếp nhận
                if t.assignedAt > 0 && (t.assignedAt < threeMinutesAgo || t.isAcknowledged) {
                    seenDispatches[t.id] = t.assignedAt
                }
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                if rateTime > 0 { seenRatings[t.id] = rateTime }
                if t.resolvedAt > 0 { seenResolved[t.id] = t.resolvedAt }
            }
        }

        for t in tickets {
            // Không xử lý ticket đã đóng, hủy hoặc bị từ chối
            if t.isInvalid || !t.invalidReason.isEmpty || t.status.uppercased() == "REJECTED" || t.status.uppercased() == "TU_CHOI" || t.status.uppercased() == "CLOSED" {
                continue
            }

            // 1. SỰ CỐ MỚI GỬI LÊN (Chỉ HelpDesk mới nhận)
            let isDispatched = !t.assignedTo.isEmpty || !t.assignedToEmail.isEmpty || t.assignedAt > 0 || !t.assignedDepartmentId.isEmpty
            let isCreatedAfterStart = t.createdAt >= appStartTime && t.createdAt >= threeMinutesAgo
            let isNotSelf = t.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != cleanEmail

            if !seenTicketIds.contains(t.id) {
                seenTicketIds.insert(t.id)
                if !isDispatched && isCreatedAfterStart && isNotSelf && currentUser.isHelpDesk {
                    notifyNewSupportRequest(ticketId: t.id, donViName: t.donVi, subject: t.subject, source: t.source)
                }
            }

            // 2. LỆNH ĐIỀU PHỐI CHO KTV / CHUYÊN VIÊN
            let isPrimary = t.isUserAssigned(email: cleanEmail)
            let isSpecialistMatch = (t.isSpecialistAssigned || t.assignedRole.uppercased() == "SPECIALIST") && currentUser.isSpecialist && t.assignedToEmail.isEmpty && (
                (!currentUser.toNghiepVu.isEmpty && currentUser.toNghiepVu == t.toNghiepVu) ||
                (!currentUser.departmentId.isEmpty && currentUser.departmentId == t.assignedDepartmentId) ||
                (!currentUser.departmentName.isEmpty && currentUser.departmentName == t.assignedDepartmentName)
            )
            let isClusterMatch = currentUser.isTechnician && t.assignedToEmail.isEmpty && !t.assignedCluster.isEmpty && (currentUser.maKhuVuc == t.assignedCluster)

            let isAssignedToMe = (isPrimary || isSpecialistMatch || isClusterMatch) && !t.isAcknowledged

            if isAssignedToMe && t.assignedAt > 0 {
                let lastSeenAssign = seenDispatches[t.id] ?? 0
                let isFreshDispatch = (now - t.assignedAt) <= 180_000 // Trong vòng 3 phút
                let hasNotAnnounced = lastSeenAssign == 0 || t.assignedAt > lastSeenAssign

                if isFreshDispatch && hasNotAnnounced {
                    seenDispatches[t.id] = t.assignedAt
                    let isSpecialist = t.isSpecialistAssigned || t.assignedRole.uppercased() == "SPECIALIST" || isSpecialistMatch
                    notifyTechnicianDispatched(ticketId: t.id, donViName: t.donVi, subject: t.subject, isSpecialist: isSpecialist)
                } else if lastSeenAssign == 0 {
                    seenDispatches[t.id] = t.assignedAt
                }
            }

            // 3. ĐÁNH GIÁ MỚI TỪ KHÁCH HÀNG
            if t.rating > 0 {
                let rateTime = t.feedbackAt > 0 ? t.feedbackAt : t.closedAt
                let lastSeenRate = seenRatings[t.id] ?? 0
                let isFreshRating = rateTime > lastSeenRate && (rateTime >= appStartTime || rateTime >= threeMinutesAgo)
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
                let isFreshResolved = t.resolvedAt > lastSeenRes && (t.resolvedAt >= appStartTime || t.resolvedAt >= threeMinutesAgo)
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
