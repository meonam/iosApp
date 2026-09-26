import Foundation

// MARK: - ATTACHMENT ITEM
public struct AttachmentItem: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var url: String
    public var size: Int64
    public var type: String
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
    public var role: String
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
    public var toType: String
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

// MARK: - TICKET TRACKING (TỌA ĐỘ VÀ LỘ TRÌNH KTV)
public struct TicketTracking: Codable, Hashable {
    public var lat: Double
    public var lng: Double
    public var updatedAt: Int64
    public var step: String

    public init(lat: Double = 0.0, lng: Double = 0.0, updatedAt: Int64 = 0, step: String = "") {
        self.lat = lat
        self.lng = lng
        self.updatedAt = updatedAt
        self.step = step
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
    public var status: String // OPEN, CLOSED
    public var category: String // HARDWARE, SOFTWARE, NETWORK, OTHER
    public var priority: String // NORMAL, HIGH, URGENT
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
    public var isAcknowledged: Bool
    public var acknowledgedAt: Int64
    public var acknowledgedBy: String
    public var acknowledgedByName: String
    public var resolvedAt: Int64
    public var resolvedBy: String
    public var resolvedByName: String
    public var resolutionNote: String
    public var closedAt: Int64
    public var closedByEmail: String
    public var closedByName: String
    public var ratingResponse: Int
    public var ratingResolve: Int
    public var ratingAttitude: Int
    public var ratingQuality: Int
    public var isAutoRated: Bool
    public var reopenCount: Int
    public var isQualityPassed: Bool
    public var source: String // APP, ZALO, EMAIL
    public var isInvalid: Bool
    public var invalidReason: String

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
        isAcknowledged: Bool = false,
        acknowledgedAt: Int64 = 0,
        acknowledgedBy: String = "",
        acknowledgedByName: String = "",
        resolvedAt: Int64 = 0,
        resolvedBy: String = "",
        resolvedByName: String = "",
        resolutionNote: String = "",
        closedAt: Int64 = 0,
        closedByEmail: String = "",
        closedByName: String = "",
        ratingResponse: Int = 0,
        ratingResolve: Int = 0,
        ratingAttitude: Int = 0,
        ratingQuality: Int = 0,
        isAutoRated: Bool = false,
        reopenCount: Int = 0,
        isQualityPassed: Bool = true,
        source: String = "APP",
        isInvalid: Bool = false,
        invalidReason: String = ""
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
        self.isAcknowledged = isAcknowledged
        self.acknowledgedAt = acknowledgedAt
        self.acknowledgedBy = acknowledgedBy
        self.acknowledgedByName = acknowledgedByName
        self.resolvedAt = resolvedAt
        self.resolvedBy = resolvedBy
        self.resolvedByName = resolvedByName
        self.resolutionNote = resolutionNote
        self.closedAt = closedAt
        self.closedByEmail = closedByEmail
        self.closedByName = closedByName
        self.ratingResponse = ratingResponse
        self.ratingResolve = ratingResolve
        self.ratingAttitude = ratingAttitude
        self.ratingQuality = ratingQuality
        self.isAutoRated = isAutoRated
        self.reopenCount = reopenCount
        self.isQualityPassed = isQualityPassed
        self.source = source
        self.isInvalid = isInvalid
        self.invalidReason = invalidReason
    }

    public var isOpen: Bool {
        status.uppercased() != "CLOSED"
    }

    public var effectiveRating: Int {
        if isInvalid { return 0 }
        if rating >= 1 && rating <= 5 { return rating }
        if isAutoRated { return 5 }
        return 0
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
