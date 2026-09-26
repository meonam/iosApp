import SwiftUI

// MARK: - MÀN HÌNH DANH SÁCH PHIẾU HỖ TRỢ (ĐỒNG BỘ 1:1 VỚI ADMINTICKETLISTSCREEN.KT TRÊN ANDROID)
public struct SupportHubView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void
    var onSelectTicket: (SupportTicket) -> Void
    var onOpenRatingReport: () -> Void

    public init(
        viewModel: SupportViewModel,
        onBack: @escaping () -> Void,
        onSelectTicket: @escaping (SupportTicket) -> Void,
        onOpenRatingReport: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onBack = onBack
        self.onSelectTicket = onSelectTicket
        self.onOpenRatingReport = onOpenRatingReport
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Trung tâm hỗ trợ")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // Nút Báo cáo SLA / Đánh giá
                            Button(action: onOpenRatingReport) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                // 2. TABS & SEARCH
                VStack(spacing: 10) {
                    // Segmented Tabs: Đang mở, Đã đóng, Tất cả
                    HStack(spacing: 8) {
                        tabButton(title: "Đang mở", count: viewModel.openCount, tag: "OPEN", activeColor: .appPrimaryPink)
                        tabButton(title: "Đã đóng", count: viewModel.closedCount, tag: "CLOSED", activeColor: .statusLiquidated)
                        tabButton(title: "Tất cả", count: viewModel.rawTickets.count, tag: "ALL", activeColor: .appSecondaryDarkBlue)
                    }

                    // Search field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm mã phiếu, tiêu đề, người gửi, đơn vị...", text: $viewModel.searchQuery)
                            .font(.system(size: 14))
                        if !viewModel.searchQuery.isEmpty {
                            Button(action: { viewModel.searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color.appTextSecondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                }
                .padding(12)

                // 3. DANH SÁCH TICKETS
                if viewModel.isLoading {
                    ProgressView("Đang tải dữ liệu...")
                        .padding(.top, 40)
                    Spacer()
                } else if viewModel.filteredTickets.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "tray.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color.appTextSecondary)
                        Text("Không có yêu cầu hỗ trợ nào trong mục này")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.appTextSecondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.filteredTickets) { ticket in
                                Button(action: { onSelectTicket(ticket) }) {
                                    ticketCard(ticket)
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            if viewModel.rawTickets.isEmpty {
                viewModel.fetchTickets()
            }
        }
    }

    private func tabButton(title: String, count: Int, tag: String, activeColor: Color) -> some View {
        let isSelected = viewModel.filterTab == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.filterTab = tag
            }
        }) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.25) : Color.black.opacity(0.08))
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? .white : Color.appTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(isSelected ? activeColor : Color.white)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? activeColor : Color.appCardBorder, lineWidth: 1))
        }
    }

    private func ticketCard(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ticket.subject.isEmpty ? "Sự cố thiết bị" : ticket.subject)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                        .lineLimit(2)

                    Text("Mã phiếu: #\(ticket.id.prefix(8).uppercased())")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Spacer()

                // Priority Badge
                priorityBadge(ticket.priority)
            }

            HStack(spacing: 12) {
                Label(ticket.creatorName.isEmpty ? ticket.creatorEmail : ticket.creatorName, systemImage: "person.circle")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)

                if !ticket.donVi.isEmpty {
                    Label(ticket.donVi, systemImage: "building.2")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }
            }

            Divider()

            HStack {
                // Trạng thái phiếu
                HStack(spacing: 4) {
                    Circle()
                        .fill(ticket.isOpen ? Color.appWarning : Color.appSuccess)
                        .frame(width: 8, height: 8)
                    Text(ticket.isOpen ? (ticket.isAcknowledged ? "Đang xử lý" : "Chưa tiếp nhận") : "Đã giải quyết")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ticket.isOpen ? (ticket.isAcknowledged ? Color.appInfo : Color.appWarning) : Color.appSuccess)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    private func priorityBadge(_ priority: String) -> some View {
        let p = priority.uppercased()
        let color: Color
        let label: String
        switch p {
        case "URGENT":
            color = .appDanger
            label = "Khẩn cấp"
        case "HIGH":
            color = .appWarning
            label = "Ưu tiên cao"
        default:
            color = .appInfo
            label = "Bình thường"
        }

        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .cornerRadius(6)
    }
}
