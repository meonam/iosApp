import Foundation

// MARK: - CẤU HÌNH EMAIL DOANH NGHIỆP TRÊN IOS (ĐỒNG BỘ 1:1 VỚI ANDROID CompanyEmailConfig)
public struct CompanyEmailConfig {
    public var providerType: String = "GRAPH_API"
    public var m365TenantId: String = ""
    public var m365ClientId: String = ""
    public var m365ClientSecret: String = ""
    public var m365MailboxEmail: String = ""
    public var smtpUsername: String = ""
    public var smtpPassword: String = ""
    public var smtpHost: String = "smtp.gmail.com"
    public var smtpPort: Int = 465
    public var ratingBaseUrl: String = "https://qltb-81f4c.web.app/rate"
    public var autoSendRatingEmailOnClose: Bool = true

    public init(
        providerType: String = "GRAPH_API",
        m365TenantId: String = "",
        m365ClientId: String = "",
        m365ClientSecret: String = "",
        m365MailboxEmail: String = "",
        smtpUsername: String = "",
        smtpPassword: String = "",
        smtpHost: String = "smtp.gmail.com",
        smtpPort: Int = 465,
        ratingBaseUrl: String = "https://qltb-81f4c.web.app/rate",
        autoSendRatingEmailOnClose: Bool = true
    ) {
        self.providerType = providerType
        self.m365TenantId = m365TenantId
        self.m365ClientId = m365ClientId
        self.m365ClientSecret = m365ClientSecret
        self.m365MailboxEmail = m365MailboxEmail
        self.smtpUsername = smtpUsername
        self.smtpPassword = smtpPassword
        self.smtpHost = smtpHost
        self.smtpPort = smtpPort
        self.ratingBaseUrl = ratingBaseUrl
        self.autoSendRatingEmailOnClose = autoSendRatingEmailOnClose
    }

    public var isConfigured: Bool {
        if providerType.caseInsensitiveCompare("GRAPH_API") == .orderedSame {
            return !m365TenantId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !m365ClientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !m365ClientSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !m365MailboxEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return !smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !smtpPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public static func fromFirestore(_ fields: [String: Any]) -> CompanyEmailConfig {
        let provider = FirestoreHelper.getString(fields["providerType"] as? [String: Any])
        let tenant = FirestoreHelper.getString(fields["m365TenantId"] as? [String: Any])
        let client = FirestoreHelper.getString(fields["m365ClientId"] as? [String: Any])
        let secret = FirestoreHelper.getString(fields["m365ClientSecret"] as? [String: Any])
        let mailbox = FirestoreHelper.getString(fields["m365MailboxEmail"] as? [String: Any])
        let sUser = FirestoreHelper.getString(fields["smtpUsername"] as? [String: Any])
        let sPass = FirestoreHelper.getString(fields["smtpPassword"] as? [String: Any])
        let sHost = FirestoreHelper.getString(fields["smtpHost"] as? [String: Any])
        let sPort = FirestoreHelper.getInt(fields["smtpPort"] as? [String: Any])
        let rUrl = FirestoreHelper.getString(fields["ratingBaseUrl"] as? [String: Any])
        let autoSend = FirestoreHelper.getBool(fields["autoSendRatingEmailOnClose"] as? [String: Any], defaultValue: true)

        return CompanyEmailConfig(
            providerType: provider.isEmpty ? "GRAPH_API" : provider,
            m365TenantId: tenant,
            m365ClientId: client,
            m365ClientSecret: secret,
            m365MailboxEmail: mailbox,
            smtpUsername: sUser,
            smtpPassword: sPass,
            smtpHost: sHost.isEmpty ? "smtp.gmail.com" : sHost,
            smtpPort: sPort > 0 ? sPort : 465,
            ratingBaseUrl: rUrl.isEmpty ? "https://qltb-81f4c.web.app/rate" : rUrl,
            autoSendRatingEmailOnClose: autoSend
        )
    }
}

// MARK: - DỊCH VỤ GỬI EMAIL TRÊN IOS (ĐỒNG BỘ 1:1 VỚI ANDROID AndroidEmailSender.kt)
public struct IosEmailSender {
    public static func sendResolutionRatingEmail(
        ticket: SupportTicket,
        config: CompanyEmailConfig
    ) async -> Result<Bool, Error> {
        let recipientEmail = (!ticket.creatorEmail.isEmpty ? ticket.creatorEmail : ticket.externalSenderId)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !recipientEmail.isEmpty, recipientEmail.contains("@") else {
            return .failure(NSError(domain: "IosEmailSender", code: 400, userInfo: [NSLocalizedDescriptionKey: "Email người nhận không hợp lệ (\(recipientEmail))"]))
        }

        guard config.isConfigured else {
            return .failure(NSError(domain: "IosEmailSender", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa cấu hình Email Microsoft 365 hoặc SMTP cho doanh nghiệp."]))
        }

        let baseUrl = config.ratingBaseUrl.isEmpty ? RatingTokenHelper.DEFAULT_RATING_BASE_URL : config.ratingBaseUrl
        let htmlBody = RatingTokenHelper.generateResolutionEmailHtml(ticket: ticket, baseUrl: baseUrl)
        let displayTicketId = ticket.id.replacingOccurrences(of: "ticket_", with: "").replacingOccurrences(of: "TK_", with: "")
        let subject = "[#\(displayTicketId)] Hoàn tất hỗ trợ kỹ thuật: \(!ticket.subject.isEmpty ? ticket.subject : "Sự cố thiết bị")"

        if config.providerType.caseInsensitiveCompare("GRAPH_API") == .orderedSame {
            return await sendViaGraphApi(config: config, recipientEmail: recipientEmail, subject: subject, htmlBody: htmlBody)
        } else {
            // Trường hợp Graph API fallback hoặc thông báo
            return await sendViaGraphApi(config: config, recipientEmail: recipientEmail, subject: subject, htmlBody: htmlBody)
        }
    }

    public static func sendDispatchNotificationEmail(
        ticket: SupportTicket,
        config: CompanyEmailConfig,
        targetEmail: String,
        targetName: String,
        isSpecialist: Bool,
        dispatchNote: String = "",
        helpdeskName: String = "Helpdesk"
    ) async -> Result<Bool, Error> {
        let recipientEmail = targetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipientEmail.isEmpty, recipientEmail.contains("@") else {
            return .failure(NSError(domain: "IosEmailSender", code: 400, userInfo: [NSLocalizedDescriptionKey: "Email người nhận không hợp lệ (\(recipientEmail))"]))
        }

        guard config.isConfigured else {
            return .failure(NSError(domain: "IosEmailSender", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa cấu hình Email Microsoft 365 hoặc SMTP cho doanh nghiệp."]))
        }

        let htmlBody = RatingTokenHelper.generateDispatchEmailHtml(
            ticket: ticket,
            recipientEmail: recipientEmail,
            recipientName: targetName,
            isSpecialist: isSpecialist,
            dispatchNote: dispatchNote
        )

        let displayTicketCode = !ticket.ticketCode.isEmpty ? ticket.ticketCode : ticket.id.replacingOccurrences(of: "ticket_", with: "").replacingOccurrences(of: "TK_", with: "")
        let titleAction = isSpecialist ? "Chuyển giao chuyên viên" : "Điều phối xử lý"
        let subject = "[#\(displayTicketCode)] \(titleAction): \(!ticket.subject.isEmpty ? ticket.subject : "Yêu cầu hỗ trợ kỹ thuật")"

        return await sendViaGraphApi(config: config, recipientEmail: recipientEmail, subject: subject, htmlBody: htmlBody)
    }

    private static func sendViaGraphApi(
        config: CompanyEmailConfig,
        recipientEmail: String,
        subject: String,
        htmlBody: String
    ) async -> Result<Bool, Error> {
        let tenantId = config.m365TenantId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientId = config.m365ClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = config.m365ClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let mailboxEmail = config.m365MailboxEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !tenantId.isEmpty, !clientId.isEmpty, !clientSecret.isEmpty, !mailboxEmail.isEmpty else {
            return .failure(NSError(domain: "IosEmailSender", code: 400, userInfo: [NSLocalizedDescriptionKey: "Thiếu thông tin kết nối Microsoft 365"]))
        }

        do {
            // 1. Lấy OAuth 2.0 Access Token
            guard let tokenUrl = URL(string: "https://login.microsoftonline.com/\(tenantId)/oauth2/v2.0/token") else {
                return .failure(NSError(domain: "IosEmailSender", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL Microsoft OAuth không hợp lệ"]))
            }

            var tokenReq = URLRequest(url: tokenUrl)
            tokenReq.httpMethod = "POST"
            tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let formParams = [
                "client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "client_secret=\(clientSecret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "scope=\("https://graph.microsoft.com/.default".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                "grant_type=client_credentials"
            ].joined(separator: "&")

            tokenReq.httpBody = formParams.data(using: .utf8)

            let (tokenData, tokenResp) = try await URLSession.shared.data(for: tokenReq)
            guard let httpResp = tokenResp as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                let errBody = String(data: tokenData, encoding: .utf8) ?? ""
                return .failure(NSError(domain: "IosEmailSender", code: 401, userInfo: [NSLocalizedDescriptionKey: "Xác thực Microsoft 365 thất bại: \(errBody)"]))
            }

            guard let json = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
                  let accessToken = json["access_token"] as? String, !accessToken.isEmpty else {
                return .failure(NSError(domain: "IosEmailSender", code: 401, userInfo: [NSLocalizedDescriptionKey: "Không nhận được Access Token từ Microsoft"]))
            }

            // 2. Gửi mail qua Microsoft Graph API: POST /v1.0/users/{mailbox}/sendMail
            guard let sendUrl = URL(string: "https://graph.microsoft.com/v1.0/users/\(mailboxEmail)/sendMail") else {
                return .failure(NSError(domain: "IosEmailSender", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL sendMail không hợp lệ"]))
            }

            var sendReq = URLRequest(url: sendUrl)
            sendReq.httpMethod = "POST"
            sendReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            sendReq.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

            let payload: [String: Any] = [
                "message": [
                    "subject": subject,
                    "body": [
                        "contentType": "HTML",
                        "content": htmlBody
                    ],
                    "toRecipients": [
                        [
                            "emailAddress": [
                                "address": recipientEmail
                            ]
                        ]
                    ]
                ],
                "saveToSentItems": true
            ]

            sendReq.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (sendData, sendResp) = try await URLSession.shared.data(for: sendReq)
            if let httpSendResp = sendResp as? HTTPURLResponse, (200...299).contains(httpSendResp.statusCode) {
                return .success(true)
            } else {
                let errStr = String(data: sendData, encoding: .utf8) ?? ""
                return .failure(NSError(domain: "IosEmailSender", code: 500, userInfo: [NSLocalizedDescriptionKey: "Lỗi gửi email Graph API: \(errStr)"]))
            }
        } catch {
            return .failure(error)
        }
    }
}
