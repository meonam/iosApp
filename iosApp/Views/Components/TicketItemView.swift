import SwiftUI

// MARK: - 1:1 TICKET ITEM CARD VIEW (ĐỒNG BỘ 1:1 ANDROID TICKET ITEM CARD & DESKTOP)
public struct TicketItemView: View {
    let ticket: SupportTicket
    let isHidden: Bool
    let onClick: () -> Void
    let onToggleHide: () -> Void
    let onDelete: (() -> Void)?
    let onOpenTracking: (() -> Void)?

    public init(
        ticket: SupportTicket,
        isHidden: Bool = false,
        onClick: @escaping () -> Void,
        onToggleHide: @escaping () -> Void = {},
        onDelete: (() -> Void)? = nil,
        onOpenTracking: (() -> Void)? = nil
    ) {
        self.ticket = ticket
        self.isHidden = isHidden
        self.onClick = onClick
        self.onToggleHide = onToggleHide
        self.onDelete = onDelete
        self.onOpenTracking = onOpenTracking
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

    private var isDeptTicket: Bool {
        ticket.scope.uppercased() == "DEPARTMENT" ||
        ticket.source.uppercased() == "DEPARTMENT" ||
        ticket.isSpecialistAssigned ||
        ticket.assignedRole.uppercased() == "SPECIALIST" ||
        ticket.assignedDepartmentId.uppercased().hasPrefix("TO_") ||
        ticket.assignedDepartmentName.localizedCaseInsensitiveContains("ứng dụng") ||
        ticket.assignedDepartmentName.localizedCaseInsensitiveContains("nghiệp vụ")
    }

    // Stripe color (4dp left border đồng bộ 1:1 Android)
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

    private var categoryText: String {
        switch ticket.category.uppercased() {
        case "HARDWARE": return "🖥️ Phần cứng"
        case "SOFTWARE": return "💾 Phần mềm"
        case "NETWORK":  return "🌐 Mạng/Internet"
        case "PRINTER":  return "🖨️ Máy in"
        case "ACCOUNT":  return "👤 Tài khoản"
        case "OTHER":    return "➕ Khác"
        default:
            return ticket.category.isEmpty ? "💾 Phần mềm" : "💾 \(ticket.category)"
        }
    }

    private var priorityInfo: (text: String, bg: Color, fg: Color) {
        switch ticket.priority.uppercased() {
        case "URGENT":
            return ("🔴 Khẩn cấp (<1h)", Color(hex: "#FEE2E2"), Color(hex: "#DC2626"))
        case "HIGH":
            return ("🟡 Cần gấp (4h)", Color(hex: "#FEF3C7"), Color(hex: "#D97706"))
        default:
            return ("🟢 Bình thường (24h)", Color(hex: "#DCFCE7"), Color(hex: "#16A34A"))
        }
    }

    // Tổ hợp thông tin người gửi + đơn vị + phòng ban (chuẩn Android Image 3)
    private var metaInfoString: String {
        let creatorText = ticket.creatorName.isEmpty ? (ticket.creatorEmail.components(separatedBy: "@").first ?? ticket.creatorEmail) : ticket.creatorName
        let effectiveDonVi: String = {
            let cLower = ticket.creatorName.lowercased()
            if ticket.donVi.localizedCaseInsensitiveContains("Điện Biên Phủ") &&
                (cLower.contains("co.op") || cLower.contains("coop") || cLower.contains("chi nhánh") || cLower.contains("cửa hàng")) {
                return ticket.creatorName
            }
            return ticket.donVi
        }()
        var parts: [String] = []
        if !creatorText.isEmpty { parts.append(creatorText) }
        if !effectiveDonVi.isEmpty { parts.append("🏬 \(effectiveDonVi)") }
        if !ticket.departmentId.isEmpty { parts.append("🏢 \(ticket.departmentId)") }
        return parts.joined(separator: " • ")
    }

    public var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                // 1. Dải màu nhận diện mép trái 4dp chuẩn Android
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 4)

                // 2. Nội dung phân tầng chuẩn Android Image 3
                VStack(alignment: .leading, spacing: 5) {
                    // ── TẦNG 1: Meta Header (Avatar nhỏ + Người gửi • Đơn vị + Giờ + Nút Ẩn/Hiện) ──
                    HStack(spacing: 5) {
                        Circle()
                            .fill(isOpen ? Color.appPrimaryPink.opacity(0.12) : Color.appSurfaceVariant)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(isOpen ? Color.appPrimaryPink : Color.appTextSecondary)
                            )

                        Text(metaInfoString.isEmpty ? "Người yêu cầu" : metaInfoString)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isOpen ? Color.appTextSecondary : Color.appTextMuted)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Giờ gửi (DD/MM HH:mm hoặc HH:mm)
                        let timeMs = ticket.lastMessageAt > 0 ? ticket.lastMessageAt : ticket.createdAt
                        Text(formatDateTime(timeMs))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color.appTextMuted)

                        if let del = onDelete {
                            Button(action: del) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#EF4444"))
                                    .frame(width: 20, height: 20)
                            }
                        }

                        Button(action: onToggleHide) {
                            Image(systemName: isHidden ? "eye" : "eye.slash")
                                .font(.system(size: 11))
                                .foregroundColor(isHidden ? Color(hex: "#10B981") : Color.appTextMuted)
                                .frame(width: 20, height: 20)
                        }
                    }

                    // ── TẦNG 2: Hero Title chiếm trọn chiều ngang, chữ đậm #002A8F (hoặc sáng trong Dark mode) ──
                    HStack(spacing: 5) {
                        if !ticket.ticketCode.isEmpty {
                            Text("#\(ticket.ticketCode)")
                                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                .foregroundColor(Color.appTextSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.appSurfaceVariant)
                                .cornerRadius(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.appCardBorder, lineWidth: 0.8)
                                )
                        }
                        Text(ticket.subject.isEmpty ? "Yêu cầu hỗ trợ & xử lý sự cố" : ticket.subject)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isOpen ? Color.appSecondaryDarkBlue : Color.appTextPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // ── TẦNG 3: Badges Row 1 (Trạng thái, Phân công KTV/Chuyên viên, NEW / Mở lại / Báo xong) ──
                    HStack(spacing: 4.5) {
                        // 1. Status Badge
                        badgeItem(
                            text: isClosed ? "ĐÃ ĐÓNG" : "ĐANG MỞ",
                            bgColor: isClosed ? Color.appSurfaceVariant : Color(hex: "#DCFCE7"),
                            textColor: isClosed ? Color.appTextSecondary : Color(hex: "#15803D")
                        )

                        // 2. Assignment Badge
                        let hasTech = !ticket.assignedToName.isEmpty || !ticket.assignedToEmail.isEmpty
                        if hasTech {
                            let isSpec = ticket.isSpecialistAssigned
                            let techName = ticket.assignedToName.isEmpty ? (ticket.assignedToEmail.components(separatedBy: "@").first ?? "") : ticket.assignedToName
                            badgeItem(
                                text: isSpec ? "💻 Chuyên viên: \(techName)" : "👤 KTV: \(techName)",
                                bgColor: isSpec ? Color(hex: "#FAF5FF") : Color(hex: "#EFF6FF"),
                                textColor: isSpec ? Color(hex: "#7E22CE") : Color(hex: "#1D4ED8"),
                                borderColor: isSpec ? Color(hex: "#DDD6FE") : Color(hex: "#BFDBFE")
                            )
                        } else if isOpen {
                            badgeItem(
                                text: "⚡ Chưa điều phối",
                                bgColor: Color(hex: "#FEF2F2"),
                                textColor: Color(hex: "#DC2626"),
                                borderColor: Color(hex: "#FECACA")
                            )
                        }

                        // 3. Special Badge (Reopened / Resolved / NEW)
                        if isReopenedActive {
                            badgeItem(
                                text: "🔄 MỞ LẠI (\(ticket.reopenCount)/2)",
                                bgColor: Color(hex: "#FEF3C7"),
                                textColor: Color(hex: "#B45309"),
                                borderColor: Color(hex: "#FDE68A")
                            )
                        } else if isResolved {
                            badgeItem(
                                text: ticket.isSpecialistAssigned ? "💻 CHUYÊN VIÊN ĐÃ XỬ LÝ" : "🛠️ KTV ĐÃ XỬ LÝ",
                                bgColor: Color(hex: "#DCFCE7"),
                                textColor: Color(hex: "#15803D"),
                                borderColor: Color(hex: "#86EFAC")
                            )
                        } else if isOpen && !ticket.isAcknowledged && ticket.assignedToEmail.isEmpty {
                            HStack(spacing: 2.5) {
                                Circle().fill(Color(hex: "#EF4444")).frame(width: 3.5, height: 3.5)
                                Text("NEW")
                                    .font(.system(size: 8.5, weight: .heavy))
                                    .foregroundColor(Color(hex: "#DC2626"))
                            }
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#FEE2E2"))
                            .cornerRadius(4)
                        }

                        Spacer(minLength: 0)
                    }

                    // ── TẦNG 4: Badges Row 2 (Kênh, Loại sự cố, Mức ưu tiên SLA, Giám sát lộ trình) ──
                    HStack(spacing: 4.5) {
                        // Channel Badge
                        if isDeptTicket {
                            badgeItem(
                                text: "🏢 Phòng ban",
                                bgColor: Color(hex: "#0D9488").opacity(0.12),
                                textColor: Color(hex: "#0D9488"),
                                borderColor: Color(hex: "#0D9488").opacity(0.35)
                            )
                        } else if ticket.source.uppercased() == "EMAIL" || ticket.externalSenderId.contains("@") {
                            badgeItem(
                                text: "✉️ Email",
                                bgColor: Color(hex: "#EA4335").opacity(0.12),
                                textColor: Color(hex: "#EA4335"),
                                borderColor: Color(hex: "#EA4335").opacity(0.35)
                            )
                        } else {
                            badgeItem(
                                text: "📱 App",
                                bgColor: Color(hex: "#F0FDFA"),
                                textColor: Color(hex: "#0F766E"),
                                borderColor: Color(hex: "#99F6E4")
                            )
                        }

                        // Category Chip
                        badgeItem(
                            text: categoryText,
                            bgColor: isOpen ? Color(hex: "#E0F2FE") : Color.appSurfaceVariant,
                            textColor: isOpen ? Color(hex: "#0369A1") : Color.appTextSecondary
                        )

                        // Priority Chip
                        badgeItem(
                            text: priorityInfo.text,
                            bgColor: isOpen ? priorityInfo.bg : Color.appSurfaceVariant,
                            textColor: isOpen ? priorityInfo.fg : Color.appTextSecondary
                        )

                        // Tracking badge (nếu KTV đang di chuyển)
                        if let tracking = ticket.tracking, tracking.status == "EN_ROUTE" {
                            let dist = tracking.distanceKm
                            let eta = tracking.etaMinutes
                            let textDisplay: String = {
                                if dist > 0.05 && eta > 0 {
                                    return "🛵 Đang đến (\(String(format: "%.1f", dist))km • ~\(eta)p)"
                                } else if dist > 0.05 {
                                    return "🛵 Đang đến (\(String(format: "%.1f", dist))km)"
                                } else if eta > 0 {
                                    return "🛵 Đang đến (~\(eta)p)"
                                } else {
                                    return "🛵 Đang di chuyển"
                                }
                            }()
                            if let openTrack = onOpenTracking {
                                Button(action: openTrack) {
                                    HStack(spacing: 3) {
                                        Text(textDisplay)
                                            .font(.system(size: 9.5, weight: .bold))
                                        Image(systemName: "map.fill")
                                            .font(.system(size: 8))
                                    }
                                    .foregroundColor(Color(hex: "#047857"))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "#DCFCE7"))
                                    .cornerRadius(4)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(hex: "#10B981"), lineWidth: 0.8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                badgeItem(
                                    text: textDisplay,
                                    bgColor: Color(hex: "#DCFCE7"),
                                    textColor: Color(hex: "#047857"),
                                    borderColor: Color(hex: "#10B981")
                                )
                            }
                        } else if let tracking = ticket.tracking, tracking.status == "ARRIVED" {
                            badgeItem(
                                text: "📍 Đã đến nơi",
                                bgColor: Color(hex: "#E0F2FE"),
                                textColor: Color(hex: "#0369A1"),
                                borderColor: Color(hex: "#0284C7")
                            )
                        }

                        Spacer(minLength: 0)
                    }

                    // ── TẦNG 5: Footer Message Preview (11.5sp) chuẩn Android Image 3 ──
                    let previewMsg = ticket.lastMessage.isEmpty ? ticket.initialMessage : ticket.lastMessage
                    if !previewMsg.isEmpty {
                        Text("💬 \(previewMsg)")
                            .font(.system(size: 11.5))
                            .foregroundColor(isOpen ? Color.appTextSecondary : Color.appTextMuted)
                            .lineLimit(1)
                            .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
            }
            .background(isOpen ? Color.appSurface : Color.appSurfaceVariant)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOpen ? Color.appCardBorder : Color.appDivider, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isOpen ? 0.04 : 0.01), radius: 2, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func badgeItem(text: String, bgColor: Color, textColor: Color, borderColor: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
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

    private func formatDateTime(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM HH:mm"
        return f.string(from: date)
    }
}
