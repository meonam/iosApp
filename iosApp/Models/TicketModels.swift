import Foundation
import SwiftUI

// MARK: - ATTACHMENT ITEM
public struct AttachmentItem: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var url: String
    public var size: Int64
    public var type: String // pdf, word, excel, text, image, html, archive, other
    public var uploadedAt: Int64
    public var sha256: String
    public var scanStatus: String
    public var scanResult: String

    public init(
        id: String = UUID().uuidString,
        name: String = "",
        url: String = "",
        size: Int64 = 0,
        type: String = "other",
        uploadedAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        sha256: String = "",
        scanStatus: String = "CLEAN",
        scanResult: String = ""
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.size = size
        self.type = type
        self.uploadedAt = uploadedAt
        self.sha256 = sha256
        self.scanStatus = scanStatus
        self.scanResult = scanResult
    }
}

// MARK: - CO-TECHNICIAN (KTV PHỐI HỢP)
public struct CoTechnician: Identifiable, Codable, Hashable {
    public var id: String { email }
    public var email: String
    public var name: String
    public var phone: String
    public var role: String // ASSISTANT, SPECIALIST
    public var assignedAt: Int64
    public var assignedBy: String
    public var isAcknowledged: Bool
    public var acknowledgedAt: Int64

    public init(
        email: String = "",
        name: String = "",
        phone: String = "",
        role: String = "ASSISTANT",
        assignedAt: Int64 = 0,
        assignedBy: String = "",
        isAcknowledged: Bool = false,
        acknowledgedAt: Int64 = 0
    ) {
        self.email = email
        self.name = name
        self.phone = phone
        self.role = role
        self.assignedAt = assignedAt
        self.assignedBy = assignedBy
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
    }
}

// MARK: - HANDOVER RECORD (LỊCH SỬ BÀN GIAO)
public struct HandoverRecord: Identifiable, Codable, Hashable {
    public var id: String { handoverId.isEmpty ? UUID().uuidString : handoverId }
    public var handoverId: String
    public var fromEmail: String
    public var fromName: String
    public var toType: String // TECHNICIAN, HELPDESK
    public var toEmail: String
    public var toName: String
    public var toCluster: String
    public var reason: String
    public var timestamp: Int64

    public init(
        handoverId: String = UUID().uuidString,
        fromEmail: String = "",
        fromName: String = "",
        toType: String = "",
        toEmail: String = "",
        toName: String = "",
        toCluster: String = "",
        reason: String = "",
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.handoverId = handoverId
        self.fromEmail = fromEmail
        self.fromName = fromName
        self.toType = toType
        self.toEmail = toEmail
        self.toName = toName
        self.toCluster = toCluster
        self.reason = reason
        self.timestamp = timestamp
    }
}

// MARK: - TICKET TRACKING (TỌA ĐỘ VÀ LỘ TRÌNH KTV - ĐỒNG BỘ 1:1 ANDROID TICKETTRACKING)
public struct TicketTracking: Codable, Hashable {
    public var ticketId: String
    public var technicianEmail: String
    public var technicianName: String
    public var technicianPhone: String
    public var currentLat: Double
    public var currentLng: Double
    public var speedKmh: Float
    public var heading: Float
    public var startLat: Double
    public var startLng: Double
    public var startAddress: String
    public var startName: String
    public var destLat: Double
    public var destLng: Double
    public var destAddress: String
    public var destName: String
    public var distanceKm: Double
    public var traveledDistanceKm: Double
    public var etaMinutes: Int
    public var status: String // IDLE, EN_ROUTE, ARRIVED, COMPLETED, CANCELLED, CANCELLED_SELF_RESOLVED, CANCELLED_BY_HELPDESK
    public var lastUpdatedAt: Int64
    public var isGpsLost: Bool
    public var lastGpsLostAt: Int64
    public var isArrivedVerified: Bool
    public var cancelledBy: String
    public var cancelReason: String
    public var cancelledAt: Int64
    public var routeCoordinates: [[Double]]

    public init(
        ticketId: String = "",
        technicianEmail: String = "",
        technicianName: String = "",
        technicianPhone: String = "",
        currentLat: Double = 0.0,
        currentLng: Double = 0.0,
        speedKmh: Float = 0.0,
        heading: Float = 0.0,
        startLat: Double = 0.0,
        startLng: Double = 0.0,
        startAddress: String = "",
        startName: String = "",
        destLat: Double = 0.0,
        destLng: Double = 0.0,
        destAddress: String = "",
        destName: String = "",
        distanceKm: Double = 0.0,
        traveledDistanceKm: Double = 0.0,
        etaMinutes: Int = 0,
        status: String = "IDLE",
        lastUpdatedAt: Int64 = 0,
        isGpsLost: Bool = false,
        lastGpsLostAt: Int64 = 0,
        isArrivedVerified: Bool = false,
        cancelledBy: String = "",
        cancelReason: String = "",
        cancelledAt: Int64 = 0,
        routeCoordinates: [[Double]] = []
    ) {
        self.ticketId = ticketId
        self.technicianEmail = technicianEmail
        self.technicianName = technicianName
        self.technicianPhone = technicianPhone
        self.currentLat = currentLat
        self.currentLng = currentLng
        self.speedKmh = speedKmh
        self.heading = heading
        self.startLat = startLat
        self.startLng = startLng
        self.startAddress = startAddress
        self.startName = startName
        self.destLat = destLat
        self.destLng = destLng
        self.destAddress = destAddress
        self.destName = destName
        self.distanceKm = distanceKm
        self.traveledDistanceKm = traveledDistanceKm
        self.etaMinutes = etaMinutes
        self.status = status
        self.lastUpdatedAt = lastUpdatedAt
        self.isGpsLost = isGpsLost
        self.lastGpsLostAt = lastGpsLostAt
        self.isArrivedVerified = isArrivedVerified
        self.cancelledBy = cancelledBy
        self.cancelReason = cancelReason
        self.cancelledAt = cancelledAt
        self.routeCoordinates = routeCoordinates
    }
}

// MARK: - SUPPORT TICKET MODEL (ĐỒNG BỘ 1:1 VỚI SUPPORTMODELS.KT TRÊN ANDROID)
public struct SupportTicket: Identifiable, Codable, Hashable {
    public var id: String
    public var creatorEmail: String
    public var creatorName: String
    public var creatorPhone: String
    public var creatorUserId: String
    public var creatorLat: Double
    public var creatorLng: Double
    public var creatorAddress: String
    public var subject: String
    public var status: String // OPEN, CLOSED, RESOLVED, CANCELED
    public var category: String // HARDWARE, SOFTWARE, NETWORK, OTHER
    public var priority: String // NORMAL, HIGH, URGENT, CRITICAL
    public var assetId: String
    public var assetName: String
    public var images: [String]
    public var attachments: [AttachmentItem]
    public var createdAt: Int64
    public var lastMessage: String
    public var lastMessageAt: Int64
    public var companyId: String
    public var departmentId: String
    public var donVi: String
    public var initialMessage: String
    public var rating: Int
    public var feedback: String
    public var feedbackAt: Int64
    public var parentTicketId: String
    public var assignedTo: String
    public var assignedDepartmentId: String
    public var assignedDepartmentName: String
    public var assignedToEmail: String
    public var assignedToName: String
    public var assignedCluster: String
    public var assignedRegion: String
    public var assignedByEmail: String
    public var assignedAt: Int64
    public var dispatchNote: String
    public var handlingMethod: String // REMOTE, ONSITE
    public var handlingMethodUpdatedAt: Int64
    public var coTechnicians: [CoTechnician]
    public var tracking: TicketTracking?
    public var collaboratorTrackings: [String: TicketTracking]
    public var isAcknowledged: Bool
    public var acknowledgedAt: Int64
    public var acknowledgedBy: String
    public var acknowledgedByName: String
    public var helpdeskAcknowledgedAt: Int64
    public var helpdeskAcknowledgedBy: String
    public var resolvedAt: Int64
    public var resolvedBy: String
    public var resolvedByName: String
    public var resolutionNote: String
    public var resolvedReason: String
    public var closedAt: Int64
    public var closedByEmail: String
    public var closedByName: String
    public var ratingResponse: Int
    public var ratingResolve: Int
    public var ratingAttitude: Int
    public var ratingQuality: Int
    public var ratingRequested: Bool
    public var ratingRequestedAt: Int64
    public var ratingEmailSent: Bool
    public var ratingEmailSentAt: Int64
    public var isAutoRated: Bool
    public var reopenCount: Int
    public var isQualityPassed: Bool
    public var source: String // APP, ZALO, EMAIL
    public var externalSenderId: String
    public var externalThreadId: String
    public var externalChannelName: String
    public var isInvalid: Bool
    public var invalidReason: String
    public var previousRating: Int
    public var previousFeedback: String
    public var isObjectiveExclusion: Bool
    public var objectiveExclusionReason: String
    public var reopenedAt: Int64
    public var reopenedByEmail: String
    public var reopenedByName: String
    public var reopenReason: String
    public var handoverHistory: [HandoverRecord]
    public var assignedApplication: String
    public var assignedRole: String
    public var scope: String // UNIT, DEPARTMENT
    public var toNghiepVu: String

    public init(
        id: String = "",
        creatorEmail: String = "",
        creatorName: String = "",
        creatorPhone: String = "",
        creatorUserId: String = "",
        creatorLat: Double = 0.0,
        creatorLng: Double = 0.0,
        creatorAddress: String = "",
        subject: String = "",
        status: String = "OPEN",
        category: String = "HARDWARE",
        priority: String = "NORMAL",
        assetId: String = "",
        assetName: String = "",
        images: [String] = [],
        attachments: [AttachmentItem] = [],
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        lastMessage: String = "",
        lastMessageAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        companyId: String = "",
        departmentId: String = "",
        donVi: String = "",
        initialMessage: String = "",
        rating: Int = 0,
        feedback: String = "",
        feedbackAt: Int64 = 0,
        parentTicketId: String = "",
        assignedTo: String = "",
        assignedDepartmentId: String = "",
        assignedDepartmentName: String = "",
        assignedToEmail: String = "",
        assignedToName: String = "",
        assignedCluster: String = "",
        assignedRegion: String = "",
        assignedByEmail: String = "",
        assignedAt: Int64 = 0,
        dispatchNote: String = "",
        handlingMethod: String = "",
        handlingMethodUpdatedAt: Int64 = 0,
        coTechnicians: [CoTechnician] = [],
        tracking: TicketTracking? = nil,
        collaboratorTrackings: [String: TicketTracking] = [:],
        isAcknowledged: Bool = false,
        acknowledgedAt: Int64 = 0,
        acknowledgedBy: String = "",
        acknowledgedByName: String = "",
        helpdeskAcknowledgedAt: Int64 = 0,
        helpdeskAcknowledgedBy: String = "",
        resolvedAt: Int64 = 0,
        resolvedBy: String = "",
        resolvedByName: String = "",
        resolutionNote: String = "",
        resolvedReason: String = "",
        closedAt: Int64 = 0,
        closedByEmail: String = "",
        closedByName: String = "",
        ratingResponse: Int = 0,
        ratingResolve: Int = 0,
        ratingAttitude: Int = 0,
        ratingQuality: Int = 0,
        ratingRequested: Bool = false,
        ratingRequestedAt: Int64 = 0,
        ratingEmailSent: Bool = false,
        ratingEmailSentAt: Int64 = 0,
        isAutoRated: Bool = false,
        reopenCount: Int = 0,
        isQualityPassed: Bool = true,
        source: String = "APP",
        externalSenderId: String = "",
        externalThreadId: String = "",
        externalChannelName: String = "",
        isInvalid: Bool = false,
        invalidReason: String = "",
        previousRating: Int = 0,
        previousFeedback: String = "",
        isObjectiveExclusion: Bool = false,
        objectiveExclusionReason: String = "",
        reopenedAt: Int64 = 0,
        reopenedByEmail: String = "",
        reopenedByName: String = "",
        reopenReason: String = "",
        handoverHistory: [HandoverRecord] = [],
        assignedApplication: String = "",
        assignedRole: String = "TECH",
        scope: String = "UNIT",
        toNghiepVu: String = ""
    ) {
        self.id = id
        self.creatorEmail = creatorEmail
        self.creatorName = creatorName
        self.creatorPhone = creatorPhone
        self.creatorUserId = creatorUserId
        self.creatorLat = creatorLat
        self.creatorLng = creatorLng
        self.creatorAddress = creatorAddress
        self.subject = subject
        self.status = status
        self.category = category
        self.priority = priority
        self.assetId = assetId
        self.assetName = assetName
        self.images = images
        self.attachments = attachments
        self.createdAt = createdAt
        self.lastMessage = lastMessage
        self.lastMessageAt = lastMessageAt
        self.companyId = companyId
        self.departmentId = departmentId
        self.donVi = donVi
        self.initialMessage = initialMessage
        self.rating = rating
        self.feedback = feedback
        self.feedbackAt = feedbackAt
        self.parentTicketId = parentTicketId
        self.assignedTo = assignedTo
        self.assignedDepartmentId = assignedDepartmentId
        self.assignedDepartmentName = assignedDepartmentName
        self.assignedToEmail = assignedToEmail
        self.assignedToName = assignedToName
        self.assignedCluster = assignedCluster
        self.assignedRegion = assignedRegion
        self.assignedByEmail = assignedByEmail
        self.assignedAt = assignedAt
        self.dispatchNote = dispatchNote
        self.handlingMethod = handlingMethod
        self.handlingMethodUpdatedAt = handlingMethodUpdatedAt
        self.coTechnicians = coTechnicians
        self.tracking = tracking
        self.collaboratorTrackings = collaboratorTrackings
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
        self.acknowledgedBy = acknowledgedBy
        self.acknowledgedByName = acknowledgedByName
        self.helpdeskAcknowledgedAt = helpdeskAcknowledgedAt
        self.helpdeskAcknowledgedBy = helpdeskAcknowledgedBy
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.resolvedByName = resolvedByName
        self.resolutionNote = resolutionNote
        self.resolvedReason = resolvedReason
        self.closedAt = closedAt
        self.closedByEmail = closedByEmail
        self.closedByName = closedByName
        self.ratingResponse = ratingResponse
        self.ratingResolve = ratingResolve
        self.ratingAttitude = ratingAttitude
        self.ratingQuality = ratingQuality
        self.ratingRequested = ratingRequested
        self.ratingRequestedAt = ratingRequestedAt
        self.ratingEmailSent = ratingEmailSent
        self.ratingEmailSentAt = ratingEmailSentAt
        self.isAutoRated = isAutoRated
        self.reopenCount = reopenCount
        self.isQualityPassed = isQualityPassed
        self.source = source
        self.externalSenderId = externalSenderId
        self.externalThreadId = externalThreadId
        self.externalChannelName = externalChannelName
        self.isInvalid = isInvalid
        self.invalidReason = invalidReason
        self.previousRating = previousRating
        self.previousFeedback = previousFeedback
        self.isObjectiveExclusion = isObjectiveExclusion
        self.objectiveExclusionReason = objectiveExclusionReason
        self.reopenedAt = reopenedAt
        self.reopenedByEmail = reopenedByEmail
        self.reopenedByName = reopenedByName
        self.reopenReason = reopenReason
        self.handoverHistory = handoverHistory
        self.assignedApplication = assignedApplication
        self.assignedRole = assignedRole
        self.scope = scope
        self.toNghiepVu = toNghiepVu
    }

    public var isRejected: Bool {
        isInvalid || !invalidReason.isEmpty || status.uppercased() == "REJECTED" || status.uppercased() == "TU_CHOI"
    }

    public var isOpen: Bool {
        !isRejected && status.uppercased() != "CLOSED" && closedAt <= 0
    }

    public var isClosed: Bool {
        !isRejected && (status.uppercased() == "CLOSED" || closedAt > 0)
    }

    public var isReopenedActive: Bool {
        !isRejected && !isClosed && (reopenCount > 0 || reopenedAt > 0) &&
        status.uppercased() != "RESOLVED" &&
        !(reopenedAt > 0 && resolvedAt > reopenedAt)
    }

    public var isResolved: Bool {
        !isRejected && !isClosed && !isReopenedActive && (
            status.uppercased() == "RESOLVED" ||
            (reopenCount == 0 && reopenedAt <= 0 && resolvedAt > 0) ||
            (reopenedAt > 0 && resolvedAt > reopenedAt)
        )
    }

    public var isAutoRateEligible: Bool {
        if isRejected || isInvalid || !invalidReason.isEmpty || status.uppercased() == "CANCELED" { return false }
        if rating >= 1 && rating <= 5 { return false }
        let isDone = status.uppercased() == "CLOSED" || resolvedAt > 0 || ratingRequested || ratingEmailSent
        if !isDone { return false }
        let finishTime = ratingRequestedAt > 0 ? ratingRequestedAt : (ratingEmailSentAt > 0 ? ratingEmailSentAt : (resolvedAt > 0 ? resolvedAt : (closedAt > 0 ? closedAt : (lastMessageAt > 0 ? lastMessageAt : 0))))
        if finishTime <= 0 { return false }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let elapsed = now - finishTime
        return elapsed >= (24 * 3600 * 1000) && isQualityPassed && reopenCount == 0
    }

    public var effectiveRating: Int {
        if isRejected || isInvalid || !invalidReason.isEmpty || status.uppercased() == "CANCELED" { return 0 }
        if rating >= 1 && rating <= 5 { return rating }
        if isAutoRated || isAutoRateEligible { return 5 }
        return 0
    }

    public var effectiveFeedback: String {
        if isInvalid || !invalidReason.isEmpty || status.uppercased() == "CANCELED" { return "" }
        if !feedback.isEmpty { return feedback }
        if isAutoRated || isAutoRateEligible {
            return "[Hệ thống tự động ghi nhận Rất hài lòng (5★) sau 24h hoàn tất]"
        }
        return ""
    }

    public var isEffectivelyAutoRated: Bool {
        isAutoRated || (rating <= 0 && isAutoRateEligible)
    }

    public var isSelfResolved: Bool {
        resolvedReason.uppercased() == "SELF_RESOLVED"
    }

    public var isSpecialistAssigned: Bool {
        if assignedRole.uppercased() == "TECH" { return false }
        if assignedRole.uppercased() == "SPECIALIST" { return true }
        return !assignedApplication.isEmpty ||
            assignedDepartmentId.uppercased().hasPrefix("TO_") ||
            assignedDepartmentName.localizedCaseInsensitiveContains("Ứng Dụng") ||
            assignedDepartmentName.localizedCaseInsensitiveContains("Nghiệp Vụ") ||
            assignedDepartmentName.localizedCaseInsensitiveContains("Dữ Liệu") ||
            assignedDepartmentName.localizedCaseInsensitiveContains("Hạ Tầng Mạng") ||
            assignedDepartmentName.localizedCaseInsensitiveContains("Bảo Mật")
    }

    public var assigneeTitle: String {
        isSpecialistAssigned ? "Chuyên viên" : "KTV"
    }

    public func getLegitimateImages() -> [String] {
        if images.isEmpty { return [] }
        if source.uppercased() != "EMAIL" { return images }
        let signatureKeywords = [
            "signature", "sign", "sigimg", "mysig", "chuky", "chu_ky", "chu-ky", "chữ ký",
            "logo", "icon", "facebook", "zalo", "linkedin", "twitter", "instagram", "youtube",
            "footer", "banner", "divider", "spacer", "pixel", "avatar", "hotline",
            "image001", "image002", "image003", "clip_image", "outlook-", "outlookemoji"
        ]
        return images.filter { url in
            let clean = url.lowercased().components(separatedBy: "/").last?.components(separatedBy: "?").first ?? ""
            return !signatureKeywords.contains { clean.contains($0) }
        }
    }

    public var slaTargetMinutes: Int {
        getSlaTargetMinutes()
    }

    public var isWithinQualityTrackingWindow: Bool {
        isWithinQualityTrackingWindow()
    }

    public func getSlaTargetMinutes(deptResolveMinutes: Int? = nil, slaConfig: SlaConfig? = nil) -> Int {
        if let d = deptResolveMinutes {
            if d == 0 { return 0 }
            if d > 0 { return d }
        }
        if let cfg = slaConfig {
            switch priority.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "CRITICAL", "URGENT", "KHANCAP": return cfg.resolveMinutesUrgent
            case "HIGH", "CAO":                   return cfg.resolveMinutesHigh
            case "LOW", "THAP":                   return cfg.resolveMinutesLow
            default:                              return cfg.resolveMinutesNormal
            }
        }
        switch priority.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "URGENT": return 60
        case "HIGH":   return 240
        default:       return 1440
        }
    }

    public func getQualityTrackingWindowHours(slaConfig: SlaConfig? = nil) -> Int64 {
        if let cfg = slaConfig {
            switch priority.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
            case "CRITICAL", "URGENT", "KHANCAP": return Int64(cfg.qualityTrackingHoursUrgent)
            case "HIGH", "CAO":                   return Int64(cfg.qualityTrackingHoursHigh)
            case "LOW", "THAP":                   return Int64(cfg.qualityTrackingHoursLow)
            default:                              return Int64(cfg.qualityTrackingHoursNormal)
            }
        }
        switch priority.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "CRITICAL", "URGENT": return 120
        case "HIGH":               return 72
        case "MEDIUM", "NORMAL":   return 48
        case "LOW":                return 24
        default:                   return 48
        }
    }

    public func isWithinQualityTrackingWindow(eventTimeMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000), slaConfig: SlaConfig? = nil) -> Bool {
        let finishTime = closedAt > 0 ? closedAt : (resolvedAt > 0 ? resolvedAt : 0)
        if finishTime <= 0 { return true }
        let windowMs = getQualityTrackingWindowHours(slaConfig: slaConfig) * 3600 * 1000
        return (eventTimeMs - finishTime) <= windowMs
    }

    public var remainingQualityTrackingHours: Int64 {
        getRemainingQualityTrackingHours()
    }

    public func getRemainingQualityTrackingHours(eventTimeMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000), slaConfig: SlaConfig? = nil) -> Int64 {
        let finishTime = closedAt > 0 ? closedAt : (resolvedAt > 0 ? resolvedAt : 0)
        if finishTime <= 0 { return getQualityTrackingWindowHours(slaConfig: slaConfig) }
        let windowMs = getQualityTrackingWindowHours(slaConfig: slaConfig) * 3600 * 1000
        let elapsedMs = eventTimeMs - finishTime
        let remainMs = max(0, windowMs - elapsedMs)
        return remainMs / (3600 * 1000)
    }

    public func getResolveDurationMinutes() -> Int64 {
        let endTime: Int64
        if resolvedAt > 0 {
            endTime = resolvedAt
        } else if closedAt > 0 {
            endTime = closedAt
        } else if feedbackAt > 0 {
            endTime = feedbackAt
        } else if status.uppercased() == "CLOSED" && lastMessageAt > 0 {
            endTime = lastMessageAt
        } else {
            endTime = Int64(Date().timeIntervalSince1970 * 1000)
        }
        let diffMs = max(0, endTime - createdAt)
        return diffMs / (60 * 1000)
    }

    public func isSlaBreached(deptResolveMinutes: Int? = nil, slaConfig: SlaConfig? = nil) -> Bool {
        if isInvalid || status.uppercased() == "CANCELED" || status.uppercased() == "REJECTED" || status.uppercased() == "TU_CHOI" {
            return false
        }
        let targetMin = getSlaTargetMinutes(deptResolveMinutes: deptResolveMinutes, slaConfig: slaConfig)
        if targetMin <= 0 { return false }
        let actualMin = getResolveDurationMinutes()
        return actualMin > Int64(targetMin)
    }

    public func isResponseSlaBreached(slaConfig: SlaConfig? = nil) -> Bool {
        if isInvalid || status.uppercased() == "CANCELED" || status.uppercased() == "REJECTED" || status.uppercased() == "TU_CHOI" {
            return false
        }
        let targetMin = slaConfig?.responseMinutesDefault ?? 30
        let respTime: Int64
        if isAcknowledged && acknowledgedAt > 0 {
            respTime = acknowledgedAt
        } else if helpdeskAcknowledgedAt > 0 {
            respTime = helpdeskAcknowledgedAt
        } else if assignedAt > 0 {
            respTime = assignedAt
        } else if let tr = tracking, tr.status.uppercased() == "ACCEPTED" && tr.lastUpdatedAt > 0 {
            respTime = tr.lastUpdatedAt
        } else {
            respTime = Int64(Date().timeIntervalSince1970 * 1000)
        }
        let diffMs = max(0, respTime - createdAt)
        let diffMinutes = diffMs / (60 * 1000)
        return diffMinutes > Int64(targetMin)
    }

    public func isUserAssigned(email: String) -> Bool {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }
        let cleanPrefix = clean.components(separatedBy: "@").first ?? clean

        let aEmail = assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aEmailPrefix = aEmail.components(separatedBy: "@").first ?? aEmail
        if !aEmail.isEmpty && (aEmail == clean || (!cleanPrefix.isEmpty && aEmailPrefix == cleanPrefix)) {
            return true
        }

        let aTo = assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let aToPrefix = aTo.components(separatedBy: "@").first ?? aTo
        if !aTo.isEmpty && (aTo == clean || (!cleanPrefix.isEmpty && aToPrefix == cleanPrefix)) {
            return true
        }

        if coTechnicians.contains(where: {
            let co = $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let coPrefix = co.components(separatedBy: "@").first ?? co
            return co == clean || (!cleanPrefix.isEmpty && coPrefix == cleanPrefix)
        }) {
            return true
        }

        if collaboratorTrackings.values.contains(where: {
            let co = $0.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let coPrefix = co.components(separatedBy: "@").first ?? co
            return co == clean || (!cleanPrefix.isEmpty && coPrefix == cleanPrefix)
        }) {
            return true
        }

        return false
    }
}

// MARK: - SUPPORT MESSAGE (CHAT REALTIME)
public struct SupportMessage: Identifiable, Codable, Hashable {
    public var id: String
    public var senderEmail: String
    public var senderName: String
    public var message: String
    public var timestamp: Int64
    public var isAdminReply: Bool
    public var donVi: String
    public var departmentId: String
    public var reactions: [String: String]
    public var avatarUrl: String
    public var isSystemMessage: Bool
    public var isInternal: Bool
    public var attachments: [AttachmentItem]

    public var text: String {
        get { message }
        set { message = newValue }
    }

    public init(
        id: String = UUID().uuidString,
        senderEmail: String = "",
        senderName: String = "",
        message: String = "",
        timestamp: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        isAdminReply: Bool = false,
        donVi: String = "",
        departmentId: String = "",
        reactions: [String: String] = [:],
        avatarUrl: String = "",
        isSystemMessage: Bool = false,
        isInternal: Bool = false,
        attachments: [AttachmentItem] = []
    ) {
        self.id = id
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.message = message
        self.timestamp = timestamp
        self.isAdminReply = isAdminReply
        self.donVi = donVi
        self.departmentId = departmentId
        self.reactions = reactions
        self.avatarUrl = avatarUrl
        self.isSystemMessage = isSystemMessage
        self.isInternal = isInternal
        self.attachments = attachments
    }
}

// MARK: - SLA CONFIG (CẤU HÌNH MA TRẬN SLA & THEO DÕI CHẤT LƯỢNG)
public struct SlaConfig: Codable, Hashable {
    public var responseMinutesDefault: Int = 30         // Thời gian phản hồi mặc định (phút)
    public var resolveMinutesUrgent: Int = 60           // Xử lý mức KHẨN CẤP / URGENT (phút)
    public var resolveMinutesHigh: Int = 240            // Xử lý mức CAO / HIGH (phút)
    public var resolveMinutesNormal: Int = 1440         // Xử lý mức BÌNH THƯỜNG / NORMAL (phút)
    public var resolveMinutesLow: Int = 2880            // Xử lý mức THẤP / LOW (phút)
    public var qualityTrackingHoursUrgent: Int = 120    // Theo dõi chất lượng Khẩn cấp (giờ)
    public var qualityTrackingHoursHigh: Int = 72       // Theo dõi chất lượng Cao (giờ)
    public var qualityTrackingHoursNormal: Int = 48     // Theo dõi chất lượng Bình thường (giờ)
    public var qualityTrackingHoursLow: Int = 24        // Theo dõi chất lượng Thấp (giờ)
    public var warningBeforeBreachMinutes: Int = 15     // Cảnh báo âm thanh trước khi trễ (phút)
    public var slaPenaltyPercentDefault: Int = 0         // % Trừ KPI khi vi phạm SLA

    public init(
        responseMinutesDefault: Int = 30,
        resolveMinutesUrgent: Int = 60,
        resolveMinutesHigh: Int = 240,
        resolveMinutesNormal: Int = 1440,
        resolveMinutesLow: Int = 2880,
        qualityTrackingHoursUrgent: Int = 120,
        qualityTrackingHoursHigh: Int = 72,
        qualityTrackingHoursNormal: Int = 48,
        qualityTrackingHoursLow: Int = 24,
        warningBeforeBreachMinutes: Int = 15,
        slaPenaltyPercentDefault: Int = 0
    ) {
        self.responseMinutesDefault = responseMinutesDefault
        self.resolveMinutesUrgent = resolveMinutesUrgent
        self.resolveMinutesHigh = resolveMinutesHigh
        self.resolveMinutesNormal = resolveMinutesNormal
        self.resolveMinutesLow = resolveMinutesLow
        self.qualityTrackingHoursUrgent = qualityTrackingHoursUrgent
        self.qualityTrackingHoursHigh = qualityTrackingHoursHigh
        self.qualityTrackingHoursNormal = qualityTrackingHoursNormal
        self.qualityTrackingHoursLow = qualityTrackingHoursLow
        self.warningBeforeBreachMinutes = warningBeforeBreachMinutes
        self.slaPenaltyPercentDefault = slaPenaltyPercentDefault
    }
}
