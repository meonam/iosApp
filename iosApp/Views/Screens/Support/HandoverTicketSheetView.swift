import SwiftUI

// MARK: - HANDOVER TICKET SHEET VIEW (ĐỒNG BỘ 1:1 VỚI HANDOVERTICKETDIALOG.KT TRÊN ANDROID)
public struct HandoverTicketSheetView: View {
    let ticket: SupportTicket
    @ObservedObject var viewModel: SupportViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedTab: Int = 0 // 0: KTV, 1: HelpDesk
    @State private var selectedTechEmail: String? = nil
    @State private var reasonText: String = ""
    @State private var searchQuery: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String = ""

    private var myEmail: String {
        viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var availableTechs: [KtvOnlineLocation] {
        let cleanMy = myEmail
        return viewModel.ktvTechnicians.filter { tech in
            let em = tech.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if em.isEmpty || em == cleanMy { return false }
            if em.contains("@") && cleanMy.contains("@") && em.components(separatedBy: "@").first == cleanMy.components(separatedBy: "@").first {
                return false
            }
            // Strict filter: only KTV or Specialist, reject excluded roles
            let role = tech.role.lowercased()
            let isExcluded = role == "user" || role == "admin" || role == "superadmin" || role == "super_admin" || role == "helpdesk" || role == "hd" ||
                role.contains("admin") || role.contains("helpdesk") || role.contains("nhan vien") || role.contains("nhanvien") || role.contains("nhân viên")
            let isKtv = role == "ktv" || role == "technician" || role == "kythuat" || role == "ky_thuat" ||
                role.contains("ktv") || role.contains("technician") || role.contains("kythuat") || role.contains("kỹ thuật")
            let isSpec = tech.isSpecialist || role == "specialist" || role == "chuyenvien" || role.contains("specialist") || role.contains("chuyenvien") || role.contains("chuyên viên")
            if isExcluded || (!isKtv && !isSpec) {
                return false
            }
            return true
        }
    }

    private var filteredTechList: [KtvOnlineLocation] {
        let list = availableTechs
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return list.sorted { ($0.isOnline ? 1 : 0) > ($1.isOnline ? 1 : 0) }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return list.filter {
            $0.name.lowercased().contains(q) ||
            $0.email.lowercased().contains(q) ||
            $0.maKhuVuc.lowercased().contains(q)
        }.sorted { ($0.isOnline ? 1 : 0) > ($1.isOnline ? 1 : 0) }
    }

    private var selectedTech: KtvOnlineLocation? {
        viewModel.ktvTechnicians.first(where: { $0.email == selectedTechEmail })
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Header
                HStack(spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bàn giao ca / Chuyển ticket")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        let sub = ticket.donVi.isEmpty ? ticket.subject : ticket.donVi
                        Text(sub)
                            .font(.system(size: 11.5))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: {
                        if !isSubmitting { presentationMode.wrappedValue.dismiss() }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#4F46E5"))

                // MARK: - Tab Selector
                HStack(spacing: 4) {
                    // Tab 0
                    Button(action: {
                        selectedTab = 0
                        errorMessage = ""
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 13))
                            Text("Bàn giao KTV khác")
                                .font(.system(size: 12, weight: selectedTab == 0 ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == 0 ? Color(hex: "#4F46E5") : Color(hex: "#64748B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == 0 ? Color.white : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == 0 ? Color(hex: "#CBD5E1") : Color.clear, lineWidth: 1)
                        )
                    }

                    // Tab 1
                    Button(action: {
                        selectedTab = 1
                        errorMessage = ""
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "headphones")
                                .font(.system(size: 13))
                            Text("Chuyển về HelpDesk")
                                .font(.system(size: 12, weight: selectedTab == 1 ? .bold : .medium))
                        }
                        .foregroundColor(selectedTab == 1 ? Color(hex: "#DC2626") : Color(hex: "#64748B"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == 1 ? Color.white : Color.clear)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == 1 ? Color(hex: "#CBD5E1") : Color.clear, lineWidth: 1)
                        )
                    }
                }
                .padding(3)
                .background(Color(hex: "#F1F5F9"))
                .cornerRadius(10)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                // MARK: - Error Banner
                if !errorMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#DC2626"))
                        Text(errorMessage)
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(hex: "#B91C1C"))
                        Spacer()
                    }
                    .padding(8)
                    .background(Color(hex: "#FEF2F2"))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#FECACA"), lineWidth: 1)
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
                }

                // MARK: - Tab Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if selectedTab == 0 {
                            Text("Chọn Kỹ thuật viên tiếp nhận: *")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#334155"))

                            // Search bar
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                TextField("Tìm theo tên, email, cụm...", text: $searchQuery)
                                    .font(.system(size: 12))
                                if !searchQuery.isEmpty {
                                    Button(action: { searchQuery = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 13))
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#CBD5E1"), lineWidth: 1)
                            )

                            if viewModel.isLoadingKtvs {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else if filteredTechList.isEmpty {
                                HStack {
                                    Spacer()
                                    Text("Không tìm thấy KTV nào khả dụng")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#94A3B8"))
                                        .padding(.vertical, 20)
                                    Spacer()
                                }
                            } else {
                                LazyVStack(spacing: 6) {
                                    ForEach(filteredTechList, id: \.email) { tech in
                                        let isSelected = selectedTechEmail == tech.email
                                        Button(action: {
                                            selectedTechEmail = tech.email
                                            errorMessage = ""
                                        }) {
                                            HStack(spacing: 10) {
                                                // Avatar Initial
                                                ZStack {
                                                    Circle()
                                                        .fill(isSelected ? Color(hex: "#4F46E5") : Color(hex: "#E2E8F0"))
                                                        .frame(width: 32, height: 32)
                                                    Text(tech.name.prefix(1).uppercased())
                                                        .font(.system(size: 13, weight: .bold))
                                                        .foregroundColor(isSelected ? .white : Color(hex: "#475569"))
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 6) {
                                                        Text(tech.name)
                                                            .font(.system(size: 12.5, weight: .bold))
                                                            .foregroundColor(isSelected ? Color(hex: "#312E81") : Color(hex: "#1E293B"))

                                                        if tech.isOnline {
                                                            Circle()
                                                                .fill(Color(hex: "#10B981"))
                                                                .frame(width: 7, height: 7)
                                                        }
                                                    }

                                                    HStack(spacing: 6) {
                                                        Text(tech.email)
                                                            .font(.system(size: 11))
                                                            .foregroundColor(Color(hex: "#64748B"))

                                                        if tech.isSpecialist {
                                                            Text("Chuyên viên")
                                                                .font(.system(size: 9.5, weight: .semibold))
                                                                .foregroundColor(Color(hex: "#7E22CE"))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 1.5)
                                                                .background(Color(hex: "#F3E8FF"))
                                                                .cornerRadius(4)
                                                        } else {
                                                            Text(tech.maKhuVuc.isEmpty ? "Kỹ thuật viên" : "KTV • Cụm \(tech.maKhuVuc)")
                                                                .font(.system(size: 9.5, weight: .semibold))
                                                                .foregroundColor(Color(hex: "#3730A3"))
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 1.5)
                                                                .background(Color(hex: "#E0E7FF"))
                                                                .cornerRadius(4)
                                                        }
                                                    }
                                                }

                                                Spacer()

                                                if isSelected {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(Color(hex: "#4F46E5"))
                                                        .font(.system(size: 18))
                                                }
                                            }
                                            .padding(10)
                                            .background(isSelected ? Color(hex: "#EEF2FF") : Color.white)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(isSelected ? Color(hex: "#818CF8") : Color(hex: "#E2E8F0"), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        } else {
                            // Chuyển về HelpDesk Info
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#D97706"))
                                    Text("Chuyển trả yêu cầu về HelpDesk")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color(hex: "#92400E"))
                                }

                                Text("Yêu cầu sẽ được đưa về trạng thái chờ điều phối (OPEN) và hủy gán KTV hiện tại. HelpDesk sẽ nhận được thông báo để tiếp nhận lại và phân công người xử lý phù hợp.")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Color(hex: "#78350F"))
                                    .lineSpacing(3)
                            }
                            .padding(12)
                            .background(Color(hex: "#FFFBEB"))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(hex: "#FDE68A"), lineWidth: 1)
                            )
                        }

                        // Mandatory Reason Field
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lý do bàn giao (* Bắt buộc - KTV tự nhập):")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(hex: "#334155"))

                            TextField(
                                selectedTab == 0
                                    ? "Ví dụ: Hết ca trực chiều, bàn giao KTV tiếp tục hỗ trợ..."
                                    : "Ví dụ: Lỗi phần mềm ERP vượt quá thẩm quyền KTV, chuyển về HelpDesk...",
                                text: $reasonText
                            )
                            .font(.system(size: 12))
                            .padding(10)
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#CBD5E1"), lineWidth: 1)
                            )

                            Text("* Lý do sẽ được thông báo ngay trong ô chat sự cố và lưu vào lịch sử bàn giao.")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#64748B"))
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                // MARK: - Action Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        if !isSubmitting { presentationMode.wrappedValue.dismiss() }
                    }) {
                        Text("Hủy")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(Color(hex: "#475569"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(hex: "#CBD5E1"), lineWidth: 1)
                            )
                    }
                    .disabled(isSubmitting)

                    Button(action: {
                        let cleanReason = reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if cleanReason.isEmpty {
                            errorMessage = "Vui lòng nhập lý do bàn giao (bắt buộc do KTV tự nhập)."
                            return
                        }
                        if selectedTab == 0 && selectedTech == nil {
                            errorMessage = "Vui lòng chọn Kỹ thuật viên nhận bàn giao."
                            return
                        }

                        isSubmitting = true
                        errorMessage = ""

                        let toType = selectedTab == 0 ? "TECHNICIAN" : "HELPDESK"
                        viewModel.handoverTicket(
                            ticketId: ticket.id,
                            toType: toType,
                            targetTechEmail: selectedTab == 0 ? selectedTech?.email ?? "" : "",
                            targetTechName: selectedTab == 0 ? selectedTech?.name ?? "" : "",
                            targetCluster: selectedTab == 0 ? selectedTech?.maKhuVuc ?? "" : "",
                            targetDeptId: selectedTab == 0 ? selectedTech?.departmentId ?? "" : "",
                            targetDeptName: selectedTab == 0 ? selectedTech?.departmentName ?? "" : "",
                            reason: cleanReason
                        ) { success in
                            isSubmitting = false
                            if success {
                                presentationMode.wrappedValue.dismiss()
                            } else {
                                errorMessage = "Lỗi khi bàn giao ca. Vui lòng thử lại!"
                            }
                        }
                    }) {
                        HStack(spacing: 6) {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(selectedTab == 0 ? "Xác nhận bàn giao" : "Xác nhận chuyển")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == 0 ? Color(hex: "#4F46E5") : Color(hex: "#DC2626"))
                        .cornerRadius(8)
                    }
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white)
                .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#E2E8F0")), alignment: .top)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            if viewModel.ktvTechnicians.isEmpty {
                viewModel.fetchKtvTechnicians()
            }
        }
    }
}
