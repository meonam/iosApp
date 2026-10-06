import Foundation
import CryptoKit

// MARK: - RATING TOKEN HELPER (ĐỒNG BỘ 1:1 VỚI ANDROID RatingTokenHelper.kt)
public struct RatingTokenHelper {
    public static let DEFAULT_RATING_BASE_URL = "https://qltb-81f4c.web.app/rate"
    public static let RATING_SALT = "qltb_secure_rating_salt_2026"
    public static let DEFAULT_RESOLVE_BASE_URL = "https://qltb-81f4c.web.app/resolve"
    public static let RESOLVE_SALT = "qltb_secure_resolve_salt_2026"

    public static func generateResolveToken(companyId: String, ticketId: String, email: String) -> String {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanTicket = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload = "\(cleanComp):\(cleanTicket):\(cleanEmail):\(RESOLVE_SALT)"

        let digest = SHA256.hash(data: Data(payload.utf8))
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        return String(hexString.prefix(16))
    }

    public static func generateResolveUrl(
        baseUrl: String = DEFAULT_RESOLVE_BASE_URL,
        companyId: String,
        ticketId: String,
        email: String
    ) -> String {
        var cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBase.isEmpty { cleanBase = DEFAULT_RESOLVE_BASE_URL }
        if cleanBase.hasSuffix("/") { cleanBase = String(cleanBase.dropLast()) }

        let token = generateResolveToken(companyId: companyId, ticketId: ticketId, email: email)
        let encComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encTicket = ticketId.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return "\(cleanBase)?c=\(encComp)&t=\(encTicket)&email=\(encEmail)&token=\(encToken)"
    }

    public static func generateToken(companyId: String, ticketId: String, creatorEmail: String) -> String {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanTicket = ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let payload = "\(cleanComp):\(cleanTicket):\(cleanEmail):\(RATING_SALT)"

        let digest = SHA256.hash(data: Data(payload.utf8))
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        return String(hexString.prefix(16))
    }

    public static func generateRatingUrl(
        baseUrl: String = DEFAULT_RATING_BASE_URL,
        companyId: String,
        ticketId: String,
        creatorEmail: String,
        stars: Int = 5
    ) -> String {
        var cleanBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanBase.isEmpty { cleanBase = DEFAULT_RATING_BASE_URL }
        if cleanBase.hasSuffix("/") { cleanBase = String(cleanBase.dropLast()) }

        let token = generateToken(companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail)
        let encComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encTicket = ticketId.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encToken = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return "\(cleanBase)?c=\(encComp)&t=\(encTicket)&s=\(stars)&token=\(encToken)"
    }

    public static func generateResolutionEmailHtml(
        ticket: SupportTicket,
        baseUrl: String = DEFAULT_RATING_BASE_URL
    ) -> String {
        let companyId = ticket.companyId.isEmpty ? "SGCOOP" : ticket.companyId
        let ticketId = ticket.id
        let creatorEmail = !ticket.creatorEmail.isEmpty ? ticket.creatorEmail : ticket.externalSenderId
        let creatorName = !ticket.creatorName.isEmpty ? ticket.creatorName : "Quý khách"
        let technicianName = !ticket.assignedToName.isEmpty ? ticket.assignedToName : "Đội ngũ Kỹ thuật viên"
        let ticketSubject = !ticket.subject.isEmpty ? ticket.subject : "Yêu cầu hỗ trợ kỹ thuật"

        let star1Url = generateRatingUrl(baseUrl: baseUrl, companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail, stars: 1)
        let star2Url = generateRatingUrl(baseUrl: baseUrl, companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail, stars: 2)
        let star3Url = generateRatingUrl(baseUrl: baseUrl, companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail, stars: 3)
        let star4Url = generateRatingUrl(baseUrl: baseUrl, companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail, stars: 4)
        let star5Url = generateRatingUrl(baseUrl: baseUrl, companyId: companyId, ticketId: ticketId, creatorEmail: creatorEmail, stars: 5)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm - dd/MM/yyyy"
        let resolvedDateStr = ticket.resolvedAt > 0 ? dateFormatter.string(from: Date(timeIntervalSince1970: Double(ticket.resolvedAt) / 1000.0)) : dateFormatter.string(from: Date())
        let displayTicketCode = ticketId.replacingOccurrences(of: "ticket_", with: "").replacingOccurrences(of: "TK_", with: "")

        return """
        <!DOCTYPE html>
        <html lang="vi">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Nghiệm thu hỗ trợ kỹ thuật [#\(displayTicketCode)]</title>
            <style>
                body { margin: 0; padding: 0; background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
                .email-container { max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #e2e8f0; }
                .email-header { background: linear-gradient(135deg, #1B2A4A 0%, #2563EB 100%); padding: 30px 24px; text-align: center; color: #ffffff; }
                .email-header h1 { margin: 0 0 6px 0; font-size: 20px; font-weight: 800; letter-spacing: 0.5px; }
                .email-header p { margin: 0; font-size: 13px; opacity: 0.85; }
                .email-body { padding: 28px 24px; color: #1e293b; line-height: 1.6; }
                .ticket-info-table { width: 100%; border-collapse: collapse; margin: 20px 0; background: #f8fafc; border-radius: 8px; overflow: hidden; }
                .ticket-info-table td { padding: 10px 14px; font-size: 13px; border-bottom: 1px solid #e2e8f0; }
                .ticket-info-table td.label { width: 130px; color: #64748b; font-weight: 600; }
                .ticket-info-table td.value { color: #0f172a; font-weight: 600; }
                .rating-box { background: #fffbeb; border: 1px solid #fef3c7; border-radius: 10px; padding: 22px 16px; text-align: center; margin: 24px 0; }
                .rating-title { font-size: 16px; font-weight: 700; color: #92400e; margin-bottom: 6px; }
                .rating-subtitle { font-size: 13px; color: #b45309; margin-bottom: 16px; }
                .star-btn-group { display: inline-block; }
                .star-btn { display: inline-block; margin: 3px 2px; padding: 10px 12px; background: #ffffff; border: 1px solid #fde68a; border-radius: 8px; text-decoration: none; color: #b45309; font-weight: 700; font-size: 13px; box-shadow: 0 1px 2px rgba(0,0,0,0.05); }
                .star-btn:hover { background: #fef3c7; border-color: #f59e0b; }
                .star-5 { background: #fef9c3; border-color: #facc15; color: #854d0e; }
                .direct-link { font-size: 12.5px; color: #2563eb; text-decoration: underline; margin-top: 14px; display: inline-block; }
                .email-footer { background: #f1f5f9; padding: 18px 24px; text-align: center; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0; }
            </style>
        </head>
        <body>
            <div class="email-container">
                <div class="email-header">
                    <h1>IT SERVICE & ASSETS</h1>
                    <p>Dịch vụ IT & Quản lý thiết bị</p>
                </div>
                <div class="email-body">
                    <p>Kính gửi <b>\(creatorName)</b>,</p>
                    <p>Yêu cầu hỗ trợ kỹ thuật của Quý khách đã được xử lý hoàn tất. Thông tin chi tiết như sau:</p>
                    
                    <table class="ticket-info-table">
                        <tr>
                            <td class="label">Mã phiếu:</td>
                            <td class="value">#\(displayTicketCode)</td>
                        </tr>
                        <tr>
                            <td class="label">Tiêu đề:</td>
                            <td class="value">\(ticketSubject)</td>
                        </tr>
                        <tr>
                            <td class="label">KTV xử lý:</td>
                            <td class="value">\(technicianName)</td>
                        </tr>
                        <tr>
                            <td class="label">Thời gian hoàn tất:</td>
                            <td class="value">\(resolvedDateStr)</td>
                        </tr>
                    </table>

                    <div class="rating-box">
                        <div class="rating-title">⭐ Quý khách hài lòng với dịch vụ hỗ trợ?</div>
                        <div class="rating-subtitle">Xin vui lòng dành 5 giây nhấp chọn số sao bên dưới để nghiệm thu:</div>
                        <div class="star-btn-group">
                            <a href="\(star1Url)" class="star-btn" target="_blank">⭐ 1 Sao<br><span style="font-size:10px;font-weight:normal;">Rất tệ</span></a>
                            <a href="\(star2Url)" class="star-btn" target="_blank">⭐⭐ 2 Sao<br><span style="font-size:10px;font-weight:normal;">Chưa đạt</span></a>
                            <a href="\(star3Url)" class="star-btn" target="_blank">⭐⭐⭐ 3 Sao<br><span style="font-size:10px;font-weight:normal;">Bình thường</span></a>
                            <a href="\(star4Url)" class="star-btn" target="_blank">⭐⭐⭐⭐ 4 Sao<br><span style="font-size:10px;font-weight:normal;">Hài lòng</span></a>
                            <a href="\(star5Url)" class="star-btn star-5" target="_blank">⭐⭐⭐⭐⭐ 5 Sao<br><span style="font-size:10px;font-weight:bold;">Rất hài lòng</span></a>
                        </div>
                        <br>
                        <a href="\(star5Url)" class="direct-link" target="_blank">Hoặc bấm vào đây để mở trang web đánh giá chi tiết</a>
                    </div>

                    <p style="font-size: 13px; color: #64748b;">
                        Nếu sự cố chưa được khắc phục triệt để hoặc Quý khách cần hỗ trợ thêm, Quý khách chỉ cần gửi email phản hồi trực tiếp thư này.
                    </p>
                </div>
                <div class="email-footer">
                    <p style="margin: 0 0 4px 0;">© 2026 Huyền Hân .All rights reserved</p>
                    <p style="margin: 0; font-size: 11px;">IT Service & Assets - Dịch vụ IT & Quản lý thiết bị</p>
                </div>
            </div>
        </body>
        </html>
        """
    }

    public static func generateDispatchEmailHtml(
        ticket: SupportTicket,
        recipientEmail: String,
        recipientName: String,
        isSpecialist: Bool,
        dispatchNote: String
    ) -> String {
        let displayTicketCode = !ticket.ticketCode.isEmpty ? ticket.ticketCode : ticket.id.replacingOccurrences(of: "ticket_", with: "").replacingOccurrences(of: "TK_", with: "")
        let roleTitle = isSpecialist ? "Chuyên viên" : "Kỹ thuật viên"
        let headerTitle = isSpecialist ? "CHUYỂN GIAO PHIẾU NGHIỆP VỤ & ỨNG DỤNG" : "ĐIỀU PHỐI XỬ LÝ SỰ CỐ KỸ THUẬT"
        let headerGradient = isSpecialist ? "linear-gradient(135deg, #1E1B4B 0%, #4338CA 100%)" : "linear-gradient(135deg, #0F172A 0%, #0284C7 100%)"
        let targetBadgeText = isSpecialist ? "Khối Chuyên Viên Nghiệp Vụ" : "Kỹ Thuật Viên Địa Bàn"
        let donVi = !ticket.donVi.isEmpty ? ticket.donVi : "Chi nhánh / Phòng ban"
        let creatorName = !ticket.creatorName.isEmpty ? ticket.creatorName : "Nhân viên"
        let creatorPhone = !ticket.creatorPhone.isEmpty ? ticket.creatorPhone : "Chưa cung cấp"
        let subject = !ticket.subject.isEmpty ? ticket.subject : "Cần hỗ trợ kỹ thuật thiết bị"
        let description = !ticket.initialMessage.isEmpty ? ticket.initialMessage : (!ticket.lastMessage.isEmpty ? ticket.lastMessage : "Không có mô tả chi tiết")
        let appOrDevice = isSpecialist ? (!ticket.assignedDepartmentName.isEmpty ? ticket.assignedDepartmentName : "Nghiệp vụ / Ứng dụng chuyên môn") : (!ticket.assetName.isEmpty ? ticket.assetName : "Thiết bị tại chỗ")
        let resolveUrl = generateResolveUrl(
            companyId: !ticket.companyId.isEmpty ? ticket.companyId : "SGCOOP",
            ticketId: ticket.id,
            email: recipientEmail
        )

        let dispatchNoteHtml = !dispatchNote.isEmpty ? """
        <div style="background: #fffbeb; border: 1px solid #fef3c7; border-left: 4px solid #f59e0b; border-radius: 8px; padding: 12px 14px; margin: 16px 0;">
            <div style="font-size: 12px; font-weight: bold; color: #b45309; margin-bottom: 4px;">📌 Ghi chú điều phối từ HelpDesk:</div>
            <div style="font-size: 13px; color: #78350f;">\(dispatchNote)</div>
        </div>
        """ : ""

        return """
        <!DOCTYPE html>
        <html lang="vi">
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>[#\(displayTicketCode)] \(headerTitle)</title>
        </head>
        <body style="margin: 0; padding: 0; background-color: #f1f5f9; font-family: sans-serif;">
            <div style="max-width: 620px; margin: 24px auto; background: #ffffff; border-radius: 14px; overflow: hidden; border: 1px solid #cbd5e1;">
                <div style="background: \(headerGradient); padding: 28px 24px; text-align: center; color: #ffffff;">
                    <div style="display: inline-block; padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: bold; background: rgba(255,255,255,0.2); margin-bottom: 8px;">\(targetBadgeText)</div>
                    <h1 style="margin: 0 0 6px 0; font-size: 19px; font-weight: 800;">\(headerTitle)</h1>
                    <p style="margin: 0; font-size: 13px; opacity: 0.9;">Phiếu hỗ trợ đã được HelpDesk điều phối tới bạn</p>
                </div>
                <div style="padding: 24px; color: #1e293b; line-height: 1.6;">
                    <div style="font-size: 15px; font-weight: bold; margin-bottom: 12px;">Kính gửi \(roleTitle) \(!recipientName.isEmpty ? recipientName : "phụ trách"),</div>
                    <p style="margin: 0 0 16px 0; font-size: 13.5px; color: #334155;">Bộ phận HelpDesk đã chuyển giao một phiếu yêu cầu hỗ trợ mới cần sự tiếp nhận của bạn:</p>
                    <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; padding: 16px; margin: 16px 0;">
                        <div style="font-size: 16px; font-weight: 800; color: #0284c7; margin-bottom: 6px;">#\(displayTicketCode)</div>
                        <div style="font-size: 14px; font-weight: bold; color: #0f172a; margin-bottom: 10px;">\(subject)</div>
                        <table style="width: 100%; border-collapse: collapse; font-size: 13px;">
                            <tr><td style="padding: 6px 0; color: #64748b; width: 140px;">🏢 Đơn vị:</td><td style="color: #0f172a; font-weight: 600;">\(donVi)</td></tr>
                            <tr><td style="padding: 6px 0; color: #64748b;">👤 Người yêu cầu:</td><td style="color: #0f172a; font-weight: 600;">\(creatorName) (SĐT: \(creatorPhone))</td></tr>
                            <tr><td style="padding: 6px 0; color: #64748b;">\(isSpecialist ? "💻 Ứng dụng:" : "🔧 Thiết bị:")</td><td style="color: #0284c7; font-weight: 600;">\(appOrDevice)</td></tr>
                            <tr><td style="padding: 6px 0; color: #64748b;">📝 Chi tiết sự cố:</td><td style="color: #334155;">\(description)</td></tr>
                        </table>
                    </div>
                    \(dispatchNoteHtml)

                    <!-- NÚT 1-CLICK XÁC NHẬN ĐÃ XỬ LÝ XONG (DÀNH CHO CHUYÊN VIÊN / ĐỐI TÁC NGOÀI KHÔNG CẦN LOGIN APP) -->
                    <div style="text-align: center; margin: 28px 0 16px 0; padding: 18px 12px; background: #f0fdf4; border: 2px dashed #86efac; border-radius: 12px;">
                        <div style="font-size: 13px; font-weight: 700; color: #166534; margin-bottom: 10px;">
                            ⚡ ĐÃ XỬ LÝ KHẮC PHỤC XONG SỰ CỐ NÀY?
                        </div>
                        <a href="\(resolveUrl)" style="display: inline-block; padding: 14px 28px; background: #16a34a; color: #ffffff; text-decoration: none; font-weight: 800; font-size: 15px; border-radius: 10px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.15); margin-bottom: 6px;">
                            🟢 👉 BẤM VÀO ĐÂY ĐỂ XÁC NHẬN ĐÃ XỬ LÝ XONG
                        </a>
                        <div style="font-size: 12px; color: #475569; margin-top: 6px;">
                            (Xác nhận 1 chạm tức thì, không cần đăng nhập app, tự động chốt thời gian & ghi nhận kết quả)
                        </div>
                    </div>

                    <div style="text-align: center; margin: 12px 0 10px 0;">
                        <a href="https://qltb-81f4c.web.app/support" style="display: inline-block; padding: 10px 22px; background: #f1f5f9; color: #475569; text-decoration: none; font-weight: 600; font-size: 13px; border-radius: 8px; border: 1px solid #cbd5e1;">
                            🚀 Mở Hệ Thống để xem chi tiết / trao đổi nội bộ
                        </a>
                    </div>
                </div>
                <div style="background: #f8fafc; padding: 16px; text-align: center; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0;">
                    © 2026 Hệ Thống Tiếp Nhận & Điều Phối Hỗ Trợ Kỹ Thuật
                </div>
            </div>
        </body>
        </html>
        """
    }
}
