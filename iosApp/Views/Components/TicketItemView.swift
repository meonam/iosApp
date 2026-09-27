import SwiftUI

// MARK: - FLOW LAYOUT HELPER FOR TAGS / BADGES (iOS 15 COMPATIBLE)
public struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    public init(spacing: CGFloat = 4, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - 1:1 TICKET ITEM CARD VIEW
public struct TicketItemView: View {
    let ticket: SupportTicket
    let isHidden: Bool
    let onClick: () -> Void
    let onToggleHide: () -> Void

    public init(
        ticket: SupportTicket,
        isHidden: Bool = false,
        onClick: @escaping () -> Void,
        onToggleHide: @escaping () -> Void = {}
    ) {
        self.ticket = ticket
        self.isHidden = isHidden
        self.onClick = onClick
        self.onToggleHide = onToggleHide
    }

    private var isClosed: Bool {
        ticket.status.uppercased() == "CLOSED" || ticket.closedAt > 0
    }

    private var isReopenedActive: Bool {
        !isClosed && (ticket.reopenCount > 0 || ticket.reopenedAt > 0) &&
        ticket.status.uppercased() != "RESOLVED" &&
        !(ticket.reopenedAt > 0 && ticket.resolvedAt > ticket.reopenedAt)
    }

    private var isResolved: Bool {
        !isClosed && !isReopenedActive && (
            ticket.status.uppercased() == "RESOLVED" ||
            (ticket.reopenCount == 0 && ticket.reopenedAt <= 0 && ticket.resolvedAt > 0) ||
            (ticket.reopenedAt > 0 && ticket.resolvedAt > ticket.reopenedAt)
        )
    }

    private var isOpen: Bool {
        !isClosed
    }

    // Stripe color:
    // Closed: Slate (#94A3B8)
    // Reopened: Dark Orange (#D97706)
    // Resolved: Amber (#F59E0B)
    // Open Priority: Urgent = Red (#EF4444), High = Orange (#F59E0B), Normal = Green (#10B981)
    private var stripeColor: Color {
        if isClosed {
            return Color(hex: "#94A3B8")
        } else if isReopenedActive {
            return Color(hex: "#D97706")
        } else if isResolved {
            return Color(hex: "#F59E0B")
        } else {
            switch ticket.priority.uppercased() {
            case "URGENT": return Color(hex: "#EF4444")
            case "HIGH":   return Color(hex: "#F59E0B")
            default:       return Color(hex: "#10B981")
            }
        }
    }

    public var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                // 1. Dải màu nhận diện mép trái (4dp Left Accent Stripe)
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 4)

                // 2. Nội dung 4 tầng
                VStack(alignment: .leading, spacing: 5) {
                    // ── TẦNG 1: Meta Header (11sp) ──
                    HStack(spacing: 6) {
                        // User Avatar
                        Circle()
                            .fill(isOpen ? Color.appPrimaryPink.opacity(0.12) : Color(hex: "#E2E8F0"))
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(isOpen ? Color.appPrimaryPink : Color(hex: "#64748B"))
                            )

                        // Creator info & Org
                        let creatorText = ticket.creatorName.isEmpty ? (ticket.creatorEmail.components(separatedBy: "@").first ?? ticket.creatorEmail) : ticket.creatorName
                        let orgItems = [
                            creatorText.isEmpty ? nil : creatorText,
                            ticket.donVi.isEmpty ? nil : "🏬 \(ticket.donVi)",
                            ticket.departmentId.isEmpty ? nil : "🏢 \(ticket.departmentId)"
                        ].compactMap { $0 }

                        Text(orgItems.joined(separator: " • "))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isOpen ? Color(hex: "#334155") : Color(hex: "#64748B"))
                            .lineLimit(1)

                        Spacer()

                        // Time
                        let timeMs = ticket.lastMessageAt > 0 ? ticket.lastMessageAt : ticket.createdAt
                        Text(formatDate(timeMs))
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#94A3B8"))

                        // Hide/Unhide icon
                        Button(action: onToggleHide) {
                            Image(systemName: isHidden ? "eye" : "eye.slash")
                                .font(.system(size: 12))
                                .foregroundColor(isHidden ? Color(hex: "#10B981") : Color(hex: "#94A3B8"))
                                .frame(width: 20, height: 20)
                        }
                    }

                    // ── TẦNG 2: Hero Title (14sp) ──
                    Text(ticket.subject.isEmpty ? "Yêu cầu hỗ trợ" : ticket.subject)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isOpen ? Color.appSecondaryDarkBlue : Color(hex: "#334155"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // ── TẦNG 3: Badges & Chips ──
                    FlowLayout(spacing: 4) {
                        // Status Badge
                        badgeView(
                            text: isClosed ? "ĐÃ ĐÓNG" : "ĐANG MỞ",
                            bgColor: isClosed ? Color(hex: "#E2E8F0") : Color(hex: "#DCFCE7"),
                            textColor: isClosed ? Color(hex: "#64748B") : Color(hex: "#15803D"),
                            bold: true
                        )

                        // Dispatch / KTV Assignment
                        let isDispatchedToCluster = !ticket.assignedCluster.isEmpty
                        let isDispatchedToDept = !ticket.assignedDepartmentName.isEmpty && ticket.assignedAt > 0
                        let hasSpecificTech = !ticket.assignedToEmail.isEmpty || !ticket.assignedToName.isEmpty
                        let isAssigned = hasSpecificTech || isDispatchedToCluster || isDispatchedToDept

                        if hasSpecificTech {
                            let isSpec = ticket.isSpecialistAssigned
                            let techName = ticket.assignedToName.isEmpty ? (ticket.assignedToEmail.components(separatedBy: "@").first ?? ticket.assignedToEmail) : ticket.assignedToName
                            let rolePrefix = isSpec ? "💻 Chuyên viên:" : "👤 KTV:"
                            let text = "\(rolePrefix) \(techName)\(ticket.isAcknowledged ? " ✓" : "")"
                            badgeView(
                                text: text,
                                bgColor: isSpec ? Color(hex: "#FAF5FF") : Color(hex: "#EFF6FF"),
                                textColor: isSpec ? Color(hex: "#7E22CE") : Color(hex: "#1D4ED8"),
                                borderColor: isSpec ? Color(hex: "#DDD6FE") : Color(hex: "#BFDBFE"),
                                bold: true
                            )
                        } else if isDispatchedToCluster {
                            badgeView(
                                text: "🎯 \(ticket.assignedCluster)\(ticket.isAcknowledged ? " ✓" : "")",
                                bgColor: Color(hex: "#EFF6FF"),
                                textColor: Color(hex: "#1D4ED8"),
                                borderColor: Color(hex: "#93C5FD"),
                                bold: true
                            )
                        } else if isDispatchedToDept {
                            badgeView(
                                text: "🏢 \(ticket.assignedDepartmentName)",
                                bgColor: Color(hex: "#F1F5F9"),
                                textColor: Color(hex: "#475569"),
                                borderColor: Color(hex: "#CBD5E1"),
                                bold: true
                            )
                        }

                        // Co-Technicians
                        if !ticket.coTechnicians.isEmpty {
                            badgeView(
                                text: "👥 +\(ticket.coTechnicians.count) KTV",
                                bgColor: Color(hex: "#F3E8FF"),
                                textColor: Color(hex: "#7C3AED"),
                                borderColor: Color(hex: "#DDD6FE"),
                                bold: true
                            )
                        }

                        // Handling Method
                        if ticket.handlingMethod == "REMOTE" {
                            badgeView(
                                text: "💻 Từ xa",
                                bgColor: Color(hex: "#EFF6FF"),
                                textColor: Color(hex: "#1D4ED8"),
                                borderColor: Color(hex: "#BFDBFE"),
                                bold: true
                            )
                        } else if ticket.handlingMethod == "ONSITE" {
                            badgeView(
                                text: "🛵 Đến nơi",
                                bgColor: Color(hex: "#FEF3C7"),
                                textColor: Color(hex: "#B45309"),
                                borderColor: Color(hex: "#FDE68A"),
                                bold: true
                            )
                        }

                        // Unassigned indicator
                        if !isAssigned && isOpen {
                            badgeView(
                                text: "⚡ Chưa điều phối",
                                bgColor: Color(hex: "#FEF2F2"),
                                textColor: Color(hex: "#DC2626"),
                                borderColor: Color(hex: "#FECACA"),
                                bold: true
                            )
                        }

                        // Reopened active badge
                        if isReopenedActive {
                            let text = ticket.reopenCount >= 2 ? "🔄 MỞ LẠI (\(ticket.reopenCount)/2 - Tối đa)" : (ticket.reopenCount == 1 ? "🔄 MỞ LẠI (1/2)" : "🔄 MỞ LẠI")
                            badgeView(
                                text: text,
                                bgColor: Color(hex: "#FFFBEB"),
                                textColor: Color(hex: "#D97706"),
                                borderColor: Color(hex: "#FDE68A"),
                                bold: true
                            )
                        } else if isResolved {
                            let text = ticket.isSpecialistAssigned ? "💻 CHUYÊN VIÊN ĐÃ XỬ LÝ" : "🛠️ KTV ĐÃ XỬ LÝ"
                            badgeView(
                                text: text,
                                bgColor: Color(hex: "#DCFCE7"),
                                textColor: Color(hex: "#15803D"),
                                borderColor: Color(hex: "#86EFAC"),
                                bold: true
                            )
                        } else if isOpen {
                            // NEW badge
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "#EF4444")).frame(width: 4, height: 4)
                                Text("NEW")
                                    .font(.system(size: 8.5, weight: .heavy))
                                    .foregroundColor(Color(hex: "#DC2626"))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FEE2E2"))
                            .cornerRadius(4)
                        }

                        // Rating badge
                        if ticket.rating > 0 {
                            badgeView(
                                text: "⭐ \(ticket.rating)/5",
                                bgColor: ticket.rating >= 3 ? Color(hex: "#FEF3C7") : Color(hex: "#FEE2E2"),
                                textColor: ticket.rating >= 3 ? Color(hex: "#B45309") : Color(hex: "#B91C1C"),
                                bold: true
                            )
                        }

                        // Omni-channel
                        if ticket.source.uppercased() == "ZALO" {
                            badgeView(
                                text: "💬 Zalo",
                                bgColor: Color(hex: "#0068FF").opacity(0.12),
                                textColor: Color(hex: "#0068FF"),
                                borderColor: Color(hex: "#0068FF").opacity(0.35),
                                bold: true
                            )
                        } else if ticket.source.uppercased() == "EMAIL" {
                            badgeView(
                                text: "✉️ Email",
                                bgColor: Color(hex: "#EA4335").opacity(0.12),
                                textColor: Color(hex: "#EA4335"),
                                borderColor: Color(hex: "#EA4335").opacity(0.35),
                                bold: true
                            )
                        }

                        // Legitimate images badge
                        let images = ticket.getLegitimateImages()
                        if !images.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 8))
                                Text("\(images.count)")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Color.appPrimaryPink)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.appPrimaryPink.opacity(0.1))
                            .cornerRadius(4)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.appPrimaryPink.opacity(0.3), lineWidth: 1))
                        }

                        // Priority chip
                        let (prioText, prioBg, prioColor): (String, Color, Color) = {
                            switch ticket.priority.uppercased() {
                            case "URGENT": return ("🔴 Khẩn cấp (<1h)", Color(hex: "#FEE2E2"), Color(hex: "#DC2626"))
                            case "HIGH":   return ("🟡 Cần gấp (4h)", Color(hex: "#FEF3C7"), Color(hex: "#D97706"))
                            default:       return ("🟢 Bình thường (24h)", Color(hex: "#DCFCE7"), Color(hex: "#16A34A"))
                            }
                        }()
                        badgeView(
                            text: prioText,
                            bgColor: isOpen ? prioBg : Color(hex: "#F1F5F9"),
                            textColor: isOpen ? prioColor : Color(hex: "#64748B"),
                            bold: true
                        )

                        // Asset chip
                        let assetName = ticket.assetName.isEmpty ? ticket.assetId : ticket.assetName
                        if !assetName.isEmpty {
                            badgeView(
                                text: "💻 \(assetName)",
                                bgColor: isOpen ? Color(hex: "#F3E8FF") : Color(hex: "#F1F5F9"),
                                textColor: isOpen ? Color(hex: "#7E22CE") : Color(hex: "#64748B"),
                                bold: true
                            )
                        }

                        // Tracking badge
                        if let tr = ticket.tracking {
                            if tr.status == "EN_ROUTE" {
                                let dist = tr.distanceKm
                                let eta = tr.etaMinutes
                                let text = dist > 0.05 && eta > 0 ? "🛵 Đang đến (\(String(format: "%.1f", dist))km • ~\(eta)p)" : (dist > 0.05 ? "🛵 Đang đến (\(String(format: "%.1f", dist))km)" : "🛵 Đang di chuyển")
                                badgeView(
                                    text: text,
                                    bgColor: Color(hex: "#DCFCE7"),
                                    textColor: Color(hex: "#047857"),
                                    borderColor: Color(hex: "#10B981"),
                                    bold: true
                                )
                            } else if tr.status == "ARRIVED" {
                                badgeView(
                                    text: "📍 Đã đến nơi",
                                    bgColor: Color(hex: "#E0F2FE"),
                                    textColor: Color(hex: "#0369A1"),
                                    borderColor: Color(hex: "#0284C7"),
                                    bold: true
                                )
                            }
                        }

                        // Phone
                        if !ticket.creatorPhone.isEmpty {
                            badgeView(
                                text: "📞 \(ticket.creatorPhone)",
                                bgColor: Color(hex: "#F1F5F9"),
                                textColor: Color(hex: "#475569")
                            )
                        }
                    }

                    // ── TẦNG 4: Footer Message Preview (11.5sp) ──
                    let previewMsg = ticket.lastMessage.isEmpty ? ticket.initialMessage : ticket.lastMessage
                    if !previewMsg.isEmpty {
                        Text("💬 \(previewMsg)")
                            .font(.system(size: 11.5))
                            .foregroundColor(isOpen ? Color(hex: "#64748B") : Color(hex: "#94A3B8"))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
            }
            .background(isOpen ? Color.white : Color(hex: "#F8FAFC"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOpen ? Color(hex: "#E2E8F0") : Color(hex: "#EEF2F6"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isOpen ? 0.04 : 0.01), radius: 3, y: 1)
            .opacity(isOpen ? 1.0 : 0.9)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func badgeView(
        text: String,
        bgColor: Color,
        textColor: Color,
        borderColor: Color? = nil,
        bold: Bool = false
    ) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: bold ? .bold : .medium))
            .foregroundColor(textColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(bgColor)
            .cornerRadius(4)
            .overlay(
                Group {
                    if let borderColor = borderColor {
                        RoundedRectangle(cornerRadius: 4).stroke(borderColor, lineWidth: 0.8)
                    }
                }
            )
    }

    private func formatDate(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: date)
    }
}
