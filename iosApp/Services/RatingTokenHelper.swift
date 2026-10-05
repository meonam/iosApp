import Foundation
import CryptoKit

// MARK: - RATING TOKEN HELPER (ĐỒNG BỘ 1:1 VỚI ANDROID RatingTokenHelper.kt)
public struct RatingTokenHelper {
    public static let DEFAULT_RATING_BASE_URL = "https://qltb-81f4c.web.app/rate"
    public static let RATING_SALT = "qltb_secure_rating_salt_2026"

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
}
