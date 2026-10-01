import SwiftUI

// MARK: - SPECIALIST TEAM DEFINITIONS (ĐỒNG BỘ 1:1 VỚI ANDROID SPECIALISTTEAMDEFAULTS)
public let DEFAULT_SPECIALIST_TEAMS: [SpecialistTeamInfo] = SpecialistTeamDefaults.TEAMS

// MARK: - DISPATCH TICKET SHEET (ĐỒNG BỘ 1:1 VỚI ANDROID)
public struct DispatchTicketSheet: View {

    public var ticket: SupportTicket
    @ObservedObject public var viewModel: SupportViewModel
    public var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

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
        let teams = viewModel.specialistTeams.isEmpty ? SpecialistTeamDefaults.TEAMS : viewModel.specialistTeams
        return teams.first { $0.id.caseInsensitiveCompare(selectedSpecialistTeamId) == .orderedSame } ?? teams[0]
    }

    private var specialistsInTeam: [User] {
        let teamName = currentSpecialistTeam.name
        let allStaff = viewModel.allStaffList
        let matched = allStaff.filter { u in
            let uEmail = u.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isValidEmail = uEmail.contains("@") && !uEmail.hasPrefix("device_")
            if !isValidEmail { return false }
            let uDept = u.departmentId.trimmingCharacters(in: .whitespacesAndNewlines)
            let uDonVi = u.donVi.trimmingCharacters(in: .whitespacesAndNewlines)
            let uKv = u.maKhuVuc.trimmingCharacters(in: .whitespacesAndNewlines)
            let uTeam = u.toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = u.role.lowercased()
            let isSpec = r == "chuyenvien" || r == "specialist"

            return uTeam.caseInsensitiveCompare(selectedSpecialistTeamId) == .orderedSame ||
                   uKv.caseInsensitiveCompare(selectedSpecialistTeamId) == .orderedSame ||
                   uDept.caseInsensitiveCompare(selectedSpecialistTeamId) == .orderedSame ||
                   (!teamName.isEmpty && (
                       uDept.localizedCaseInsensitiveContains(teamName) ||
                       teamName.localizedCaseInsensitiveContains(uDept) ||
                       uDonVi.localizedCaseInsensitiveContains(teamName) ||
                       uKv.localizedCaseInsensitiveContains(teamName)
                   )) ||
                   (isSpec && selectedSpecialistTeamId.isEmpty)
        }

        if !matched.isEmpty { return matched }

        return allStaff.filter { u in
            let uEmail = u.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isValidEmail = uEmail.contains("@") && !uEmail.hasPrefix("device_")
            if !isValidEmail { return false }
            let uDept = u.departmentId.trimmingCharacters(in: .whitespacesAndNewlines)
            let uDonVi = u.donVi.trimmingCharacters(in: .whitespacesAndNewlines)
            let r = u.role.uppercased()

            return uDept.localizedCaseInsensitiveContains("CNTT") ||
                   uDept.localizedCaseInsensitiveContains("PCNTT") ||
                   uDonVi.localizedCaseInsensitiveContains("CNTT") ||
                   uDonVi.localizedCaseInsensitiveContains("PCNTT") ||
                   r.contains("ADMIN") ||
                   r.contains("CHUYENVIEN") ||
                   r.contains("SPECIALIST") ||
                   r.contains("STAFF")
        }
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
            ZStack {
                Color.appBackground.ignoresSafeArea()

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
                                .foregroundColor(Color.appTextPrimary)

                            TextEditor(text: $note)
                                .font(.system(size: 13.5))
                                .foregroundColor(Color.appTextPrimary)
                                .frame(height: 70)
                                .padding(6)
                                .background(colorScheme == .dark ? Color(hex: "#161F2E") : Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }

                        Spacer(minLength: 20)

                        // Bottom Action Buttons
                        bottomActionButtons
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Điều phối Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") { onDismiss() }
                        .foregroundColor(Color.appPrimaryPink)
                }
            }
            .onAppear {
                viewModel.fetchKtvTechnicians()
                viewModel.fetchStaffAndSpecialistTeams()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
                        .foregroundColor(targetRole == "TECH" ? Color.appSecondaryDarkBlue : Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(targetRole == "TECH" ? Color.appSurface : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(targetRole == "TECH" ? Color.appSecondaryDarkBlue : Color.clear, lineWidth: 1)
                )
                .shadow(color: targetRole == "TECH" ? Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05) : Color.clear, radius: 2)
            }

            Button(action: {
                withAnimation { targetRole = "SPECIALIST" }
            }) {
                HStack(spacing: 6) {
                    Text("💻")
                    Text("Chuyên viên")
                        .font(.system(size: 13, weight: targetRole == "SPECIALIST" ? .bold : .medium))
                        .foregroundColor(targetRole == "SPECIALIST" ? (colorScheme == .dark ? Color(hex: "#2DD4BF") : Color(hex: "#0D9488")) : Color.appTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(targetRole == "SPECIALIST" ? Color.appSurface : Color.clear)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(targetRole == "SPECIALIST" ? (colorScheme == .dark ? Color(hex: "#14B8A6") : Color(hex: "#99F6E4")) : Color.clear, lineWidth: 1)
                )
                .shadow(color: targetRole == "SPECIALIST" ? Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05) : Color.clear, radius: 2)
            }
        }
        .padding(3)
        .background(Color.appSurfaceVariant)
        .cornerRadius(8)
    }

    // MARK: - 2. KTV SECTION
    private var ktvSectionView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Phòng ban xử lý
            VStack(alignment: .leading, spacing: 8) {
                Text("Phòng ban xử lý:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.appPrimaryPink, lineWidth: 2)
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(Color.appPrimaryPink)
                            .frame(width: 10, height: 10)
                    }
                    Text("IT TẬP TRUNG")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
                .padding(.vertical, 4)
            }

            // Lọc kỹ thuật viên theo cụm/khu vực
            VStack(alignment: .leading, spacing: 8) {
                Text("Lọc kỹ thuật viên theo cụm/khu vực:")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(availableClusters, id: \.self) { cl in
                            let isSel = (selectedCluster == cl) || (cl == "Tất cả" && selectedCluster.isEmpty)
                            Button(action: {
                                selectedCluster = (cl == "Tất cả") ? "" : cl
                            }) {
                                Text(cl)
                                    .font(.system(size: 12.5, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? (colorScheme == .dark ? Color(hex: "#60A5FA") : Color(hex: "#1D4ED8")) : Color.appTextSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(isSel ? (colorScheme == .dark ? Color(hex: "#1E3A8A").opacity(0.4) : Color(hex: "#EFF6FF")) : Color.appSurface)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? Color.appSecondaryDarkBlue : Color.appCardBorder, lineWidth: 1)
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
                    .foregroundColor(Color.appTextPrimary)

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
                        .foregroundColor(Color.appTextSecondary)
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
                                            .stroke(isSelected ? Color.appPrimaryPink : Color.gray.opacity(0.5), lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                        if isSelected {
                                            Circle()
                                                .fill(Color.appPrimaryPink)
                                                .frame(width: 10, height: 10)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Text(tech.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(Color.appTextPrimary)

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
        let tealColor = colorScheme == .dark ? Color(hex: "#2DD4BF") : Color(hex: "#0D9488")
        let activeChipBg = colorScheme == .dark ? Color(hex: "#134E4A") : Color(hex: "#CCFBF1")
        let teams = viewModel.specialistTeams.isEmpty ? SpecialistTeamDefaults.TEAMS : viewModel.specialistTeams

        return VStack(alignment: .leading, spacing: 14) {
            // Tổ Chuyên Môn Phụ Trách
            VStack(alignment: .leading, spacing: 8) {
                Text("Tổ Chuyên Môn Phụ Trách (*):")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)

                VStack(spacing: 8) {
                    ForEach(teams) { team in
                        let isSelected = selectedSpecialistTeamId.caseInsensitiveCompare(team.id) == .orderedSame
                        Button(action: {
                            selectedSpecialistTeamId = team.id
                            selectedSpecialistEmail = ""
                            selectedSpecialistName = ""
                            if !selectedApp.isEmpty && !team.applications.contains(where: { $0.caseInsensitiveCompare(selectedApp) == .orderedSame }) {
                                selectedApp = ""
                            }
                        }) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(isSelected ? tealColor : Color.gray.opacity(0.5), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    if isSelected {
                                        Circle()
                                            .fill(tealColor)
                                            .frame(width: 10, height: 10)
                                    }
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(team.name)
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundColor(isSelected ? tealColor : Color.appTextPrimary)

                                    Text(team.applications.joined(separator: ", "))
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.appTextSecondary)
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
                    .foregroundColor(Color.appTextPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Button(action: { selectedApp = "" }) {
                            Text("Tất cả ứng dụng")
                                .font(.system(size: 12, weight: selectedApp.isEmpty ? .bold : .medium))
                                .foregroundColor(selectedApp.isEmpty ? tealColor : Color.appTextSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedApp.isEmpty ? activeChipBg : Color.appSurface)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedApp.isEmpty ? tealColor : Color.appCardBorder, lineWidth: 1)
                                    )
                        }

                        ForEach(currentSpecialistTeam.applications, id: \.self) { app in
                            let isSel = selectedApp.caseInsensitiveCompare(app) == .orderedSame
                            Button(action: {
                                if isSel {
                                    selectedApp = ""
                                } else {
                                    selectedApp = app
                                    let matchedTeam = teams.first { team in
                                        team.applications.contains { $0.caseInsensitiveCompare(app) == .orderedSame }
                                    }
                                    if let matched = matchedTeam, matched.id.caseInsensitiveCompare(selectedSpecialistTeamId) != .orderedSame {
                                        selectedSpecialistTeamId = matched.id
                                        selectedSpecialistEmail = ""
                                        selectedSpecialistName = ""
                                    }
                                }
                            }) {
                                Text(app)
                                    .font(.system(size: 12, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? tealColor : Color.appTextSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSel ? activeChipBg : Color.appSurface)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSel ? tealColor : Color.appCardBorder, lineWidth: 1)
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
                    .foregroundColor(Color.appTextPrimary)

                // Phân công chung cho cả Tổ
                Button(action: {
                    selectedSpecialistEmail = ""
                    selectedSpecialistName = ""
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(selectedSpecialistEmail.isEmpty ? tealColor : Color.gray.opacity(0.5), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            if selectedSpecialistEmail.isEmpty {
                                Circle()
                                    .fill(tealColor)
                                    .frame(width: 10, height: 10)
                            }
                        }
                        Text("👥 Phân công chung cho cả Tổ")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(tealColor)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())

                if viewModel.isLoadingStaff {
                    HStack {
                        Spacer()
                        ProgressView("Đang tải danh sách chuyên viên...")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(.vertical, 12)
                } else if specialistsInTeam.isEmpty {
                    Text("Không có chuyên viên phù hợp với tổ này")
                        .font(.system(size: 12.5))
                        .foregroundColor(Color.appTextSecondary)
                        .italic()
                        .padding(.vertical, 6)
                } else {
                    ForEach(specialistsInTeam, id: \.email) { spec in
                        let isSelected = selectedSpecialistEmail.caseInsensitiveCompare(spec.email) == .orderedSame
                        let isOnline = spec.isOnline || (spec.lastActiveAt > 0 && (Int64(Date().timeIntervalSince1970 * 1000) - spec.lastActiveAt < 15 * 60 * 1000))
                        let workload = viewModel.getActiveTicketCount(email: spec.email)

                        Button(action: {
                            selectedSpecialistEmail = spec.email
                            selectedSpecialistName = spec.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? spec.email : spec.fullName
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(isSelected ? tealColor : Color.gray.opacity(0.5), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    if isSelected {
                                        Circle()
                                            .fill(tealColor)
                                            .frame(width: 10, height: 10)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(spec.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? spec.email : spec.fullName)
                                            .font(.system(size: 13.5, weight: .semibold))
                                            .foregroundColor(Color.appTextPrimary)

                                        Circle()
                                            .fill(isOnline ? Color(hex: "#10B981") : Color.gray)
                                            .frame(width: 7, height: 7)

                                        Text(isOnline ? "Online" : "Offline")
                                            .font(.system(size: 11))
                                            .foregroundColor(isOnline ? Color(hex: "#10B981") : Color.gray)
                                    }

                                    let statusText = isOnline
                                        ? (workload == 0 ? "🟢 Đang rảnh (0 việc)" : "🔴 Bận (\(workload) việc)")
                                        : (workload == 0 ? "⚪ Ngoại tuyến" : "⚪ Ngoại tuyến (dở dang \(workload) việc)")
                                    let statusColor = isOnline
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
    }

    // MARK: - 4. BOTTOM ACTION BUTTONS
    private var bottomActionButtons: some View {
        HStack(spacing: 16) {
            Spacer()

            // Nút Hủy
            Button(action: onDismiss) {
                Text("Hủy")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
            .disabled(isSubmitting)

            // Nút Điều phối
            Button(action: handleDispatch) {
                HStack(spacing: 6) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(targetRole == "SPECIALIST" ? "⚡ Điều phối Chuyên viên" : "Điều phối")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(targetRole == "SPECIALIST" ? Color(hex: "#0D9488") : Color.appPrimaryPink)
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
            let specUser = viewModel.allStaffList.first { $0.email.caseInsensitiveCompare(selectedSpecialistEmail) == .orderedSame }
            let specName: String
            if let user = specUser, !user.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               user.fullName.lowercased() != "admin", user.fullName.lowercased() != "user" {
                specName = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            } else if !selectedSpecialistEmail.isEmpty {
                specName = selectedSpecialistEmail.components(separatedBy: "@").first ?? selectedSpecialistEmail
            } else {
                specName = ""
            }

            let effectiveTeamId: String
            if let userTeam = specUser?.toNghiepVu.trimmingCharacters(in: .whitespacesAndNewlines), !userTeam.isEmpty {
                effectiveTeamId = userTeam
            } else {
                effectiveTeamId = selectedSpecialistTeamId
            }

            let teams = viewModel.specialistTeams.isEmpty ? SpecialistTeamDefaults.TEAMS : viewModel.specialistTeams
            let effectiveTeamObj = teams.first { $0.id.caseInsensitiveCompare(effectiveTeamId) == .orderedSame } ?? currentSpecialistTeam
            let resolvedName = SpecialistTeamDefaults.resolveTeamDisplayName(effectiveTeamId)
            let effectiveTeamName = resolvedName.isEmpty ? effectiveTeamObj.name : resolvedName

            viewModel.assignTicket(
                ticketId: ticket.id,
                deptId: effectiveTeamId,
                deptName: effectiveTeamName,
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
