import SwiftUI

public struct SpecialistTeamManagerView: View {
    @ObservedObject var viewModel: AdminViewModel
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var showFormSheet: Bool = false
    @State private var isEditing: Bool = false
    @State private var editingId: String = ""
    
    // Form states
    @State private var teamName: String = ""
    @State private var teamId: String = ""
    @State private var teamApps: String = ""
    @State private var teamDesc: String = ""
    @State private var leaderName: String = ""
    @State private var phone: String = ""

    public init(viewModel: AdminViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }
    
    private var filteredTeams: [SpecialistTeam] {
        viewModel.specialistTeams.filter { t in
            searchQuery.isEmpty ||
            t.teamName.localizedCaseInsensitiveContains(searchQuery) ||
            t.teamId.localizedCaseInsensitiveContains(searchQuery) ||
            t.description.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    private func getMemberCount(for teamId: String) -> Int {
        return viewModel.allUsers.filter { $0.toNghiepVu.caseInsensitiveCompare(teamId) == .orderedSame || $0.departmentId.caseInsensitiveCompare(teamId) == .orderedSame }.count
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Quản lý Tổ nghiệp vụ (\(viewModel.specialistTeams.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: { resetForm(); showFormSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color.appTextSecondary)
                        TextField("Tìm kiếm tổ, mã tổ, ứng dụng...", text: $searchQuery)
                            .font(.system(size: 14))
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))
                    .padding(12)

                    if filteredTeams.isEmpty {
                        Spacer()
                        Text("Không có tổ nghiệp vụ nào").foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredTeams, id: \.id) { team in
                                teamCard(team)
                                    .onTapGesture { openEdit(team) }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) { deleteTeam(id: team.id) } label: { Label("Xóa", systemImage: "trash") }
                                    }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            await viewModel.fetchSpecialistTeams()
                            viewModel.fetchUsers()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            Task {
                await viewModel.fetchSpecialistTeams()
            }
            if viewModel.allUsers.isEmpty {
                viewModel.fetchUsers()
            }
        }
        .sheet(isPresented: $showFormSheet) {
            formSheet
        }
    }

    private func teamCard(_ team: SpecialistTeam) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 20))
                    .foregroundColor(Color.appPrimary)
                    .frame(width: 42, height: 42)
                    .background(Color.appPrimary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(team.teamName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)

                    Text("Trưởng tổ: \(team.truongTo.isEmpty ? "Chưa có" : team.truongTo)")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                Text("\(getMemberCount(for: team.teamId)) NV")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.appPrimaryPink.opacity(0.12))
                    .cornerRadius(6)
            }
            
            HStack {
                Text(team.teamId)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(4)
                
                if !team.sdtLienHe.isEmpty {
                    Text("📞 \(team.sdtLienHe)")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                }
            }

            let desc = team.description.isEmpty ? team.moTa : team.description
            if !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
                    .lineSpacing(2)
            }
            
            if !team.applications.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(team.applications, id: \.self) { app in
                            Text(app)
                                .font(.system(size: 10))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.teal.opacity(0.1))
                                .foregroundColor(.teal)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
    
    private var formSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin tổ nghiệp vụ")) {
                    TextField("Tên tổ (*)", text: $teamName)
                        .onChange(of: teamName) { newValue in
                            if !isEditing && (teamId.isEmpty || teamId.starts(with: "TO_")) {
                                let slug = newValue.uppercased().replacingOccurrences(of: " ", with: "_").filter { $0.isLetter || $0.isNumber || $0 == "_" }
                                teamId = "TO_" + String(slug.prefix(15))
                            }
                        }
                    TextField("Mã tổ (*)", text: $teamId)
                        .disabled(isEditing)
                }
                
                Section(header: Text("Trách nhiệm & Quản lý")) {
                    TextField("Ứng dụng hỗ trợ (cách nhau bởi dấu phẩy)", text: $teamApps)
                    TextField("Mô tả / Phạm vi hỗ trợ", text: $teamDesc)
                    TextField("Trưởng tổ (Họ tên)", text: $leaderName)
                    TextField("SĐT liên hệ", text: $phone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(isEditing ? "Cập nhật tổ nghiệp vụ" : "Thêm tổ nghiệp vụ")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") { showFormSheet = false },
                trailing: Button("Lưu") {
                        if !teamName.isEmpty && !teamId.isEmpty {
                            saveTeam()
                            showFormSheet = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimary)
            )
        }
    }
    
    private func resetForm() {
        isEditing = false
        editingId = ""
        teamName = ""
        teamId = ""
        teamApps = ""
        teamDesc = ""
        leaderName = ""
        phone = ""
    }
    
    private func openEdit(_ team: SpecialistTeam) {
        isEditing = true
        editingId = team.id
        teamName = team.teamName
        teamId = team.teamId
        teamApps = team.applications.joined(separator: ", ")
        teamDesc = team.description.isEmpty ? team.moTa : team.description
        leaderName = team.truongTo
        phone = team.sdtLienHe
        showFormSheet = true
    }
    
    // REST API Helpers
    private func saveTeam() {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let did = teamId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let urlStr = isEditing ? 
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/specialist_teams/\(editingId)?updateMask.fieldPaths=teamName&updateMask.fieldPaths=applications&updateMask.fieldPaths=description&updateMask.fieldPaths=moTa&updateMask.fieldPaths=truongTo&updateMask.fieldPaths=sdtLienHe" :
            "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/specialist_teams?documentId=\(did)"
        
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = isEditing ? "PATCH" : "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        
        let appsArray = teamApps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var appsFields: [[String: Any]] = []
        for app in appsArray {
            appsFields.append(["stringValue": app])
        }
        
        let body: [String: Any] = [
            "fields": [
                "teamId": ["stringValue": did],
                "teamName": ["stringValue": teamName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "applications": ["arrayValue": ["values": appsFields]],
                "description": ["stringValue": teamDesc.trimmingCharacters(in: .whitespacesAndNewlines)],
                "moTa": ["stringValue": teamDesc.trimmingCharacters(in: .whitespacesAndNewlines)],
                "truongTo": ["stringValue": leaderName.trimmingCharacters(in: .whitespacesAndNewlines)],
                "sdtLienHe": ["stringValue": phone.trimmingCharacters(in: .whitespacesAndNewlines)],
                "companyId": ["stringValue": comp],
                "updatedAt": ["integerValue": String(Int64(Date().timeIntervalSince1970 * 1000))]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            await viewModel.fetchSpecialistTeams()
        }
    }
    
    private func deleteTeam(id: String) {
        let comp = viewModel.companyId.isEmpty ? "SGCOOP" : viewModel.companyId
        let urlStr = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/specialist_teams/\(id)"
        guard let url = URL(string: urlStr) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !viewModel.idToken.isEmpty { request.addValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization") }
        Task {
            let _ = try? await URLSession.shared.data(for: request)
            await viewModel.fetchSpecialistTeams()
        }
    }
}
