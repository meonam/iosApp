import SwiftUI

// MARK: - 1:1 TICKET ITEM CARD VIEW (ĐỒNG BỘ 1:1 DESKTOP / WEB SUPPORT TICKET LIST)
public struct TicketItemView: View {
    let ticket: SupportTicket
    let isHidden: Bool
    let onClick: () -> Void
    let onToggleHide: () -> Void
    let onDelete: (() -> Void)?

    public init(
        ticket: SupportTicket,
        isHidden: Bool = false,
        onClick: @escaping () -> Void,
        onToggleHide: @escaping () -> Void = {},
        onDelete: (() -> Void)? = nil
    ) {
        self.ticket = ticket
        self.isHidden = isHidden
        self.onClick = onClick
        self.onToggleHide = onToggleHide
        self.onDelete = onDelete
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

    // Stripe color (6dp left border):
    // Open: Green (#10B981)
    // Closed: Slate (#94A3B8)
    // Reopened: Amber (#D97706)
    // Urgent: Red (#EF4444)
    private var stripeColor: Color {
        if isClosed {
            return Color(hex: "#94A3B8")
        } else if isReopenedActive {
            return Color(hex: "#D97706")
        } else if isResolved {
            return Color(hex: "#10B981")
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

    public var body: some View {
        Button(action: onClick) {
            HStack(spacing: 0) {
                // 1. Dải màu nhận diện mép trái 6dp chuẩn Desktop
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 6)

                // 2. Nội dung chi tiết các tầng
                VStack(alignment: .leading, spacing: 6) {
                    // ── TẦNG 1: Avatar + Tên + Giờ + Thùng rác (Xóa) + Ẩn/Hiện ──
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "#FFE4E6"))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#E11D48"))
                            )

                        let creatorText = ticket.creatorName.isEmpty ? (ticket.creatorEmail.components(separatedBy: "@").first ?? ticket.creatorEmail) : ticket.creatorName
                        Text(creatorText.isEmpty ? "Người yêu cầu" : creatorText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#1E293B"))
                            .lineLimit(1)

                        Spacer()

                        // Giờ gửi (11:05)
                        let timeMs = ticket.lastMessageAt > 0 ? ticket.lastMessageAt : ticket.createdAt
                        Text(formatTimeOnly(timeMs))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#94A3B8"))

                        if let del = onDelete {
                            Button(action: del) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#EF4444"))
                                    .frame(width: 22, height: 22)
                            }
                        }

                        Button(action: onToggleHide) {
                            Image(systemName: isHidden ? "eye" : "eye.slash")
                                .font(.system(size: 12))
                                .foregroundColor(isHidden ? Color(hex: "#10B981") : Color(hex: "#94A3B8"))
                                .frame(width: 22, height: 22)
                        }
                    }

                    // ── TẦNG 2: Đơn vị • Phòng ban ──
                    let unitPart = ticket.donVi.isEmpty ? creatorSublineFallback : "🏢 \(ticket.donVi)"
                    let deptPart = ticket.departmentId.isEmpty ? "🏢 Hỗ trợ khách hàng" : "🏢 \(ticket.departmentId)"
                    Text("\(unitPart) • \(deptPart)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#64748B"))
                        .lineLimit(1)

                    // ── TẦNG 3: Tiêu đề yêu cầu hỗ trợ (Chữ đậm xanh #0B2545) ──
                    Text(ticket.subject.isEmpty ? "Yêu cầu hỗ trợ & xử lý sự cố" : ticket.subject)
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(isOpen ? Color(hex: "#0B2545") : Color(hex: "#475569"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    // ── TẦNG 4: Nhãn Kênh (Email/App/Phòng ban) + NEW/Mở lại + Đang mở/Đã đóng ──
                    HStack(spacing: 5) {
                        // Channel Badge
                        if isDeptTicket {
                            badgeItem(
                                text: "🏢 Phòng ban",
                                bgColor: Color(hex: "#F0FDFA"),
                                textColor: Color(hex: "#0D9488"),
                                borderColor: Color(hex: "#99F6E4")
                            )
                        } else if ticket.source.uppercased() == "EMAIL" || ticket.externalSenderId.contains("@") {
                            badgeItem(
                                text: "✉️ Email",
                                bgColor: Color(hex: "#FFF1F2"),
                                textColor: Color(hex: "#EA4335"),
                                borderColor: Color(hex: "#FECDD3")
                            )
                        } else {
                            badgeItem(
                                text: "📱 App",
                                bgColor: Color(hex: "#F0FDFA"),
                                textColor: Color(hex: "#0F766E"),
                                borderColor: Color(hex: "#99F6E4")
                            )
                        }

                        // Special Status Badge
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
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "#E11D48")).frame(width: 4, height: 4)
                                Text("NEW")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundColor(Color(hex: "#E11D48"))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color(hex: "#FFE4E6"))
                            .cornerRadius(4)
                        }

                        // Ticket Status (Đang mở / Đã đóng)
                        badgeItem(
                            text: isClosed ? "Đã đóng" : "Đang mở",
                            bgColor: isClosed ? Color(hex: "#F1F5F9") : Color(hex: "#DCFCE7"),
                            textColor: isClosed ? Color(hex: "#64748B") : Color(hex: "#16A34A")
                        )

                        Spacer()
                    }

                    // ── TẦNG 5: Nhãn Loại sự cố (Phần mềm/Phần cứng) + Mức độ ưu tiên + KTV phụ trách ──
                    HStack(spacing: 5) {
                        // Category Chip
                        badgeItem(
                            text: categoryText,
                            bgColor: Color(hex: "#F1F5F9"),
                            textColor: Color(hex: "#334155")
                        )

                        // Priority Chip
                        badgeItem(
                            text: priorityInfo.text,
                            bgColor: isOpen ? priorityInfo.bg : Color(hex: "#F1F5F9"),
                            textColor: isOpen ? priorityInfo.fg : Color(hex: "#64748B")
                        )

                        // Assignment Badge if any
                        if !ticket.assignedToName.isEmpty || !ticket.assignedToEmail.isEmpty {
                            let techName = ticket.assignedToName.isEmpty ? (ticket.assignedToEmail.components(separatedBy: "@").first ?? "") : ticket.assignedToName
                            badgeItem(
                                text: "👤 \(techName)",
                                bgColor: Color(hex: "#EFF6FF"),
                                textColor: Color(hex: "#1D4ED8"),
                                borderColor: Color(hex: "#BFDBFE")
                            )
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .background(isOpen ? Color.white : Color(hex: "#F8FAFC"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOpen ? Color(hex: "#E2E8F0") : Color(hex: "#EEF2F6"), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isOpen ? 0.04 : 0.01), radius: 3, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var creatorSublineFallback: String {
        let name = ticket.creatorName.isEmpty ? ticket.creatorEmail.components(separatedBy: "@").first ?? "" : ticket.creatorName
        return name.isEmpty ? "🏢 Khách hàng" : "🏢 \(name)"
    }

    private func badgeItem(text: String, bgColor: Color, textColor: Color, borderColor: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
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

    private func formatTimeOnly(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
