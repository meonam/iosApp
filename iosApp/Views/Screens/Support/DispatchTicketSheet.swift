import SwiftUI

// MARK: - SPECIALIST TEAM DEFINITIONS (ĐỒNG BỘ 1:1 VỚI ANDROID SPECIALISTTEAMDEFAULTS)
public struct SpecialistTeamInfo: Identifiable, Hashable {
    public var id: String
    public var name: String
    public var applications: [String]

    public init(id: String, name: String, applications: [String]) {
        self.id = id
        self.name = name
        self.applications = applications
    }
}

public let DEFAULT_SPECIALIST_TEAMS: [SpecialistTeamInfo] = [
    SpecialistTeamInfo(
        id: "TO_HA_TANG_BAO_MAT",
        name: "Tổ Hạ Tầng Mạng & Bảo Mật",
        applications: ["HẠ TẦNG & MẠNG", "AN NINH BẢO MẬT"]
    ),
    SpecialistTeamInfo(
        id: "TO_KY_THUAT_UNG_DUNG",
        name: "Tổ Kỹ Thuật Ứng Dụng",
        applications: ["MMS (Kỹ thuật)", "ORACLE", "Văn phòng điện tử", "KHTV", "TOPOS"]
    ),
    SpecialistTeamInfo(
        id: "TO_PHAN_TICH_NGHIEP_VU",
        name: "Tổ Phân Tích Nghiệp Vụ",
        applications: ["MMS (Nghiệp vụ)", "OMNI", "Nhập liệu tự động", "ERP MCS/Bách Hóa"]
    ),
    SpecialistTeamInfo(
        id: "TO_NEN_TANG_DU_LIEU",
        name: "Tổ Nền Tảng Dữ Liệu",
        applications: ["TOOLS NỘI BỘ", "REPORT TOOL"]
    ),
    SpecialistTeamInfo(
        id: "TO_RND_CONG_NGHE",
        name: "Tổ Nghiên Cứu & Phát Triển Công Nghệ",
        applications: ["CHƯƠNG TRÌNH ĐẶT HÀNG OMS", "CHƯƠNG TRÌNH ĐẶT HÀNG D&F", "APP CHÀO HÀNG ONLINE"]
    )
]

// MARK: - DISPATCH TICKET SHEET (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct DispatchTicketSheet: View {

    public var ticket: SupportTicket
    @ObservedObject public var viewModel: SupportViewModel
    public var onDismiss: () -> Void

    @State private var targetRole: String = "TECH" // "TECH" or "SPECIALIST"
    @State private var selectedDeptId: String = "IT_TAP_TRUNG"
    @State private var selectedDeptName: String = "IT TẬP TRUNG"
    @State private var selectedCluster: String = ""
    @State private var selectedTechEmail: String = ""
    @State private var selectedTechName: String = ""
    
    // Specialist state
    @State private var selectedSpecialistTeamId: String = "TO_KY_THUAT_UNG_DUNG"
    @State private var selectedApp: String = ""
    @State private var selectedSpecialistEmail: String = ""
    @State private var selectedSpecialistName: String = ""

    @State private var note: String = ""
    @State private var isSubmitting: Bool = false

    private let defaultClusters: [String] = ["Tất cả", "HCM_1", "HCM_2", "HCM_3", "HCM_BD", "MIENTAY"]

    public init(ticket: SupportTicket, viewModel: SupportViewModel, onDismiss: @escaping () -> Void) {
        self.ticket = ticket
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        
        let initialRole = ticket.isSpecialistAssigned ? "SPECIALIST" : "TECH"
        _targetRole = State(initialValue: initialRole)
        _selectedTechEmail = State(initialValue: ticket.assignedToEmail)
        _selectedTechName = State(initialValue: ticket.assignedToName)
        _selectedCluster = State(initialValue: ticket.assignedCluster)
        _selectedApp = State(initialValue: ticket.assignedApplication)
        _selectedSpecialistEmail = State(initialValue: ticket.isSpecialistAssigned ? ticket.assignedToEmail : "")
        _selectedSpecialistName = State(initialValue: ticket.isSpecialistAssigned ? ticket.assignedToName : "")
        if ticket.isSpecialistAssigned && !ticket.assignedDepartmentId.isEmpty {
            _selectedSpecialistTeamId = State(initialValue: ticket.assignedDepartmentId)
        }
    }

    private var availableClusters: [String] {
        var clusters = defaultClusters
        for ktv in viewModel.ktvTechnicians {
            let k = ktv.maKhuVuc.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty && !clusters.contains(k) {
                clusters.append(k)
            }
        }
        return clusters
    }

    private var currentSpecialistTeam: SpecialistTeamInfo {
        DEFAULT_SPECIALIST_TEAMS.first { $0.id == selectedSpecialistTeamId } ?? DEFAULT_SPECIALIST_TEAMS[0]
    }

    private var filteredTechs: [KtvOnlineLocation] {
        let all = viewModel.ktvTechnicians
        if selectedCluster.isEmpty || selectedCluster == "Tất cả" {
            return all
        }
        return all.filter { $0.maKhuVuc.localizedCaseInsensitiveContains(selectedCluster) }
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. TABS SWITCHER: KTV Địa bàn vs Chuyên viên
                    switcherTabs

                    if targetRole == "TECH" {
                        ktvSectionView
                    } else {
                        specialistSectionView
                    }

                    // Ghi chú điều phối
                    VStack(alignment: .leading, spacing: 6) {
                        Text(targetRole == "SPECIALIST" ? "Ghi chú cho Chuyên viên (tùy chọn):" : "Ghi chú điều phối (tùy chọn):")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#334155"))

                        TextEditor(text: $note)
                            .frame(height: 70)
                            .padding(6)
                            .background(Color(hex: "#F8FAFC"))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    }

                    Spacer(minLength: 20)

                    // Bottom Action Buttons (Đồng bộ nút Hủy và Điều phối Hồng #E11D48)
                    bottomActionButtons
                }
                .padding(16)
            }
            .navigationTitle("Điều phối Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { onDismiss() }
                        .foregroundColor(Color.gray)
                }
            }
            .onAppear {
                viewModel.fetchKtvTechnicians()
            }
        }
    }

    // MARK: - 1. SWITCHER TABS (KTV ĐỊA BÀN vs CHUYÊN VIÊN)
    private var switcherTabs: some View {
        HStack(spacing: 6) {
            Button(action: {
                withAnimation { targetRole = "TECH" }
            }) {
                HStack(spacing: 6) {
                    Text("🛵")
                    Text("KTV Địa bàn")
                        .font(.system(size: 13, weight: targetRole == "TECH" ? .bold : .medium))
                        .foregroundColor(targetRole == "TECH" ? Color(hex: "#1D4ED8") : Color(hex: "#64748B"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(targetRole == "TECH" ? Color.white : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(targetRole == "TECH" ? Color(hex: "#93C5FD") : Color.clear, lineWidth: 1)
                )
                .shadow(color: targetRole == "TECH" ? Color.black.opacity(0.05) : Color.clear, radius: 2)
            }

            Button(action: {
                withAnimation { targetRole = "SPECIALIST" }
            }) {
                HStack(spacing: 6) {
                    Text("💻")
                    Text("Chuyên viên")
                        .font(.system(size: 13, weight: targetRole == "SPECIALIST" ? .bold : .medium))
                        .foregroundColor(targetRole == "SPECIALIST" ? Color(hex: "#0D9488") : Color(hex: "#64748B"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(targetRole == "SPECIALIST" ? Color.white : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(targetRole == "SPECIALIST" ? Color(hex: "#99F6E4") : Color.clear, lineWidth: 1)
                )
                .shadow(color: targetRole == "SPECIALIST" ? Color.black.opacity(0.05) : Color.clear, radius: 2)
            }
        }
        .padding(3)
        .background(Color(hex: "#F1F5F9"))
        .cornerRadius(8)
    }

    // MARK: - 2. KTV SECTION
    private var ktvSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Phòng ban xử lý
            VStack(alignment: .leading, spacing: 8) {
                Text("Phòng ban xử lý:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#E11D48"), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(Color(hex: "#E11D48"))
                            .frame(width: 10, height: 10)
                    }
                    Text("IT TẬP TRUNG")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#1E293B"))
                }
                .padding(.vertical, 4)
            }

            // Lọc kỹ thuật viên theo cụm/khu vực
            VStack(alignment: .leading, spacing: 8) {
                Text("Lọc kỹ thuật viên theo cụm/khu vực:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableClusters, id: \.self) { cl in
                            let isSel = (selectedCluster == cl) || (cl == "Tất cả" && selectedCluster.isEmpty)
                            Button(action: {
                                selectedCluster = (cl == "Tất cả") ? "" : cl
                            }) {
                                Text(cl)
                                    .font(.system(size: 12.5, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? Color(hex: "#1D4ED8") : Color(hex: "#475569"))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(isSel ? Color(hex: "#EFF6FF") : Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? Color(hex: "#3B82F6") : Color(hex: "#E2E8F0"), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }

            // Danh sách Kỹ thuật viên
            VStack(alignment: .leading, spacing: 8) {
                Text("Kỹ thuật viên:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                if viewModel.isLoadingKtvs {
                    HStack {
                        Spacer()
                        ProgressView("Đang tải danh sách KTV...")
                        Spacer()
                    }
                    .padding(.vertical, 16)
                } else if filteredTechs.isEmpty {
                    Text("Không có KTV phù hợp với cụm đã chọn")
                        .font(.system(size: 13))
                        .foregroundColor(Color.gray)
                        .italic()
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredTechs) { tech in
                            let isSelected = selectedTechEmail == tech.email
                            let workload = viewModel.getActiveTicketCount(email: tech.email)

                            Button(action: {
                                selectedTechEmail = tech.email
                                selectedTechName = tech.name
                            }) {
                                HStack(spacing: 12) {
                                    // Custom Radio
                                    ZStack {
                                        Circle()
                                            .stroke(isSelected ? Color(hex: "#E11D48") : Color.gray.opacity(0.5), lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                        if isSelected {
                                            Circle()
                                                .fill(Color(hex: "#E11D48"))
                                                .frame(width: 10, height: 10)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(tech.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color(hex: "#0F172A"))

                                            Circle()
                                                .fill(tech.isOnline ? Color(hex: "#10B981") : Color.gray)
                                                .frame(width: 7, height: 7)

                                            Text(tech.isOnline ? "Online" : "Offline")
                                                .font(.system(size: 11.5, weight: .medium))
                                                .foregroundColor(tech.isOnline ? Color(hex: "#10B981") : Color.gray)
                                        }

                                        let statusText = tech.isOnline
                                            ? (workload == 0 ? "🟢 Đang rảnh (0 việc)" : "🔴 Bận (\(workload) việc)")
                                            : (workload == 0 ? "⚪ Ngoại tuyến" : "⚪ Ngoại tuyến (\(workload) việc)")
                                        let statusColor = tech.isOnline
                                            ? (workload == 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                            : Color.gray

                                        Text(statusText)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(statusColor)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. SPECIALIST SECTION
    private var specialistSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tổ Chuyên Môn Phụ Trách
            VStack(alignment: .leading, spacing: 8) {
                Text("Tổ Chuyên Môn Phụ Trách (*):")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                VStack(spacing: 8) {
                    ForEach(DEFAULT_SPECIALIST_TEAMS) { team in
                        let isSelected = selectedSpecialistTeamId == team.id
                        Button(action: {
                            selectedSpecialistTeamId = team.id
                            selectedSpecialistEmail = ""
                            selectedSpecialistName = ""
                            if !team.applications.contains(selectedApp) {
                                selectedApp = ""
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(isSelected ? Color(hex: "#0D9488") : Color.gray.opacity(0.5), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    if isSelected {
                                        Circle()
                                            .fill(Color(hex: "#0D9488"))
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.name)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundColor(isSelected ? Color(hex: "#0D9488") : Color(hex: "#0F172A"))

                                    Text(team.applications.joined(separator: ", "))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.gray)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Ứng Dụng Nghiệp Vụ / Hệ Thống
            VStack(alignment: .leading, spacing: 8) {
                Text("Ứng Dụng Nghiệp Vụ / Hệ Thống:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button(action: { selectedApp = "" }) {
                            Text("Tất cả ứng dụng")
                                .font(.system(size: 12, weight: selectedApp.isEmpty ? .bold : .medium))
                                .foregroundColor(selectedApp.isEmpty ? Color(hex: "#0D9488") : Color(hex: "#475569"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedApp.isEmpty ? Color(hex: "#CCFBF1") : Color.white)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedApp.isEmpty ? Color(hex: "#0D9488") : Color(hex: "#E2E8F0"), lineWidth: 1)
                                )
                        }

                        ForEach(currentSpecialistTeam.applications, id: \.self) { app in
                            let isSel = selectedApp == app
                            Button(action: { selectedApp = isSel ? "" : app }) {
                                Text(app)
                                    .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? Color(hex: "#0D9488") : Color(hex: "#475569"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSel ? Color(hex: "#CCFBF1") : Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? Color(hex: "#0D9488") : Color(hex: "#E2E8F0"), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }

            // Chuyên Viên Phụ Trách
            VStack(alignment: .leading, spacing: 8) {
                Text("Chuyên Viên Phụ Trách:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color(hex: "#1E293B"))

                // Phân công chung cho cả Tổ
                Button(action: {
                    selectedSpecialistEmail = ""
                    selectedSpecialistName = ""
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(selectedSpecialistEmail.isEmpty ? Color(hex: "#0D9488") : Color.gray.opacity(0.5), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            if selectedSpecialistEmail.isEmpty {
                                Circle()
                                    .fill(Color(hex: "#0D9488"))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        Text("👥 Phân công chung cho cả Tổ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#0D9488"))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())

                // List specialists
                ForEach(viewModel.ktvTechnicians) { spec in
                    let isSelected = selectedSpecialistEmail == spec.email
                    let workload = viewModel.getActiveTicketCount(email: spec.email)

                    Button(action: {
                        selectedSpecialistEmail = spec.email
                        selectedSpecialistName = spec.name
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? Color(hex: "#0D9488") : Color.gray.opacity(0.5), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                if isSelected {
                                    Circle()
                                        .fill(Color(hex: "#0D9488"))
                                        .frame(width: 10, height: 10)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(spec.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(Color(hex: "#0F172A"))

                                    Circle()
                                        .fill(spec.isOnline ? Color(hex: "#10B981") : Color.gray)
                                        .frame(width: 7, height: 7)

                                    Text(spec.isOnline ? "Online" : "Offline")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(spec.isOnline ? Color(hex: "#10B981") : Color.gray)
                                }

                                let statusText = spec.isOnline
                                    ? (workload == 0 ? "🟢 Đang rảnh (0 việc)" : "🔴 Bận (\(workload) việc)")
                                    : (workload == 0 ? "⚪ Ngoại tuyến" : "⚪ Ngoại tuyến (\(workload) việc)")
                                let statusColor = spec.isOnline
                                    ? (workload == 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    : Color.gray

                                Text(statusText)
                                    .font(.system(size: 11.5))
                                    .foregroundColor(statusColor)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - 4. BOTTOM ACTION BUTTONS
    private var bottomActionButtons: some View {
        HStack(spacing: 16) {
            Spacer()

            // Nút Hủy (Chữ hồng #E11D48)
            Button(action: onDismiss) {
                Text("Hủy")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#E11D48"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .disabled(isSubmitting)

            // Nút Điều phối (Pill button hồng đậm #E11D48)
            Button(action: handleDispatch) {
                HStack(spacing: 6) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(targetRole == "SPECIALIST" ? "Điều phối" : "Điều phối")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(hex: "#E11D48"))
                .clipShape(Capsule())
            }
            .disabled(isSubmitting)
        }
        .padding(.top, 8)
    }

    // MARK: - DISPATCH LOGIC
    private func handleDispatch() {
        isSubmitting = true
        if targetRole == "SPECIALIST" {
            let specName = selectedSpecialistName.isEmpty ? (selectedSpecialistEmail.isEmpty ? "" : selectedSpecialistEmail) : selectedSpecialistName
            viewModel.assignTicket(
                ticketId: ticket.id,
                deptId: selectedSpecialistTeamId,
                deptName: currentSpecialistTeam.name,
                techEmail: selectedSpecialistEmail,
                techName: specName,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                assignedCluster: "",
                assignedRegion: "",
                assignedApplication: selectedApp,
                assignedRole: "SPECIALIST"
            ) { success in
                isSubmitting = false
                if success {
                    onDismiss()
                }
            }
        } else {
            let techName = selectedTechName.isEmpty ? selectedTechEmail : selectedTechName
            viewModel.assignTicket(
                ticketId: ticket.id,
                deptId: selectedDeptId,
                deptName: selectedDeptName,
                techEmail: selectedTechEmail,
                techName: techName,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                assignedCluster: selectedCluster,
                assignedRegion: selectedCluster,
                assignedApplication: "",
                assignedRole: "TECH"
            ) { success in
                isSubmitting = false
                if success {
                    onDismiss()
                }
            }
        }
    }
}
