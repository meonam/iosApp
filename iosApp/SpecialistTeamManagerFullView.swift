import SwiftUI
import UIKit

// MARK: - 1. SPECIALIST TEAM DATA MODEL (Khớp 100% SpecialistTeam.kt trên Android)
struct SpecialistTeamRecord: Identifiable, Hashable, Sendable {
    var id: String
    var teamId: String
    var teamName: String
    var applications: [String]
    var description: String
    var truongTo: String
    var sdtLienHe: String
    var companyId: String
    var updatedAt: Int64
}

let DEFAULT_SPECIALIST_TEAMS_IOS: [SpecialistTeamRecord] = [
    SpecialistTeamRecord(
        id: "TO_HA_TANG_BAO_MAT",
        teamId: "TO_HA_TANG_BAO_MAT",
        teamName: "HẠ TẦNG MẠNG & BẢO MẬT",
        applications: ["HẠ TẦNG & MẠNG", "AN NINH BẢO MẬT"],
        description: "Chuyên trách hệ thống mạng, bảo mật, máy chủ hạ tầng",
        truongTo: "",
        sdtLienHe: "",
        companyId: "SGCOOP",
        updatedAt: 0
    ),
    SpecialistTeamRecord(
        id: "TO_KY_THUAT_UNG_DUNG",
        teamId: "TO_KY_THUAT_UNG_DUNG",
        teamName: "KỸ THUẬT ỨNG DỤNG",
        applications: ["MMS (Kỹ thuật)", "ORACLE", "Văn phòng điện tử", "KHTV", "TOPOS"],
        description: "Hỗ trợ kỹ thuật ứng dụng lõi, POS, CSDL Oracle",
        truongTo: "",
        sdtLienHe: "",
        companyId: "SGCOOP",
        updatedAt: 0
    ),
    SpecialistTeamRecord(
        id: "TO_PHAN_TICH_NGHIEP_VU",
        teamId: "TO_PHAN_TICH_NGHIEP_VU",
        teamName: "PHÂN TÍCH NGHIỆP VỤ",
        applications: ["MMS (Nghiệp vụ)", "OMNI", "Nhập liệu tự động", "ERP MCS/Bách Hóa"],
        description: "Nghiệp vụ MMS, bán lẻ OMNI, quy trình ERP",
        truongTo: "",
        sdtLienHe: "",
        companyId: "SGCOOP",
        updatedAt: 0
    ),
    SpecialistTeamRecord(
        id: "TO_NEN_TANG_DU_LIEU",
        teamId: "TO_NEN_TANG_DU_LIEU",
        teamName: "NỀN TẢNG DỮ LIỆU",
        applications: ["TOOLS NỘI BỘ", "REPORT TOOL"],
        description: "Phân tích, báo cáo dữ liệu và công cụ nội bộ",
        truongTo: "",
        sdtLienHe: "",
        companyId: "SGCOOP",
        updatedAt: 0
    ),
    SpecialistTeamRecord(
        id: "TO_RND_CONG_NGHE",
        teamId: "TO_RND_CONG_NGHE",
        teamName: "NGHIÊN CỨU VÀ PHÁT TRIỂN CÔNG NGHỆ",
        applications: ["CHƯƠNG TRÌNH ĐẶT HÀNG OMS", "CHƯƠNG TRÌNH ĐẶT HÀNG D&F", "APP CHÀO HÀNG ONLINE"],
        description: "Ứng dụng di động, OMS, thương mại điện tử R&D",
        truongTo: "",
        sdtLienHe: "",
        companyId: "SGCOOP",
        updatedAt: 0
    )
]

// MARK: - 2. SPECIALIST TEAM MANAGER FULL VIEW (Khớp Android SpecialistTeamManagerScreen.kt)
struct SpecialistTeamManagerFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var teams: [SpecialistTeamRecord] = []
    @State private var isLoading: Bool = false
    @State private var searchQuery: String = ""
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil

    // Add Form states
    @State private var showAddSheet: Bool = false
    @State private var addTeamName: String = ""
    @State private var addTeamId: String = ""
    @State private var addTeamApps: String = ""
    @State private var addTeamDesc: String = ""
    @State private var addTeamLeader: String = ""
    @State private var addTeamPhone: String = ""
    @State private var isSavingAdd: Bool = false

    // Edit Form states
    @State private var teamToEdit: SpecialistTeamRecord? = nil
    @State private var editTeamName: String = ""
    @State private var editTeamApps: String = ""
    @State private var editTeamDesc: String = ""
    @State private var editTeamLeader: String = ""
    @State private var editTeamPhone: String = ""
    @State private var isSavingEdit: Bool = false

    // Delete confirmation
    @State private var teamToDelete: SpecialistTeamRecord? = nil

    private let tealAccent = Color(hex: "#0D9488")
    private let tealLightBg = Color(hex: "#CCFBF1")
    private let tealBorder = Color(hex: "#99F6E4")

    private var firestoreBaseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(firebase.projectId)/databases/(default)/documents/companies/\(firebase.companyId)/specialist_teams"
    }

    var filteredTeams: [SpecialistTeamRecord] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return teams
        }
        let q = searchQuery.lowercased()
        return teams.filter {
            $0.teamName.lowercased().contains(q) ||
            $0.teamId.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.truongTo.lowercased().contains(q) ||
            $0.applications.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Co.opmart
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.8))
                            TextField("Tìm kiếm tổ nghiệp vụ, phần mềm...", text: $searchQuery)
                                .foregroundColor(.white)
                                .tint(.white)
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Color.appTopBar)

                    // Thông báo Toast thành công / lỗi
                    if let err = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                            Spacer()
                            Button(action: { errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#FEE2E2"))
                    }

                    if let succ = successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(succ)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                            Spacer()
                            Button(action: { successMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#DCFCE7"))
                    }

                    // Danh sách Tổ nghiệp vụ
                    if isLoading && teams.isEmpty {
                        Spacer()
                        ProgressView("Đang tải dữ liệu tổ nghiệp vụ...")
                            .padding()
                        Spacer()
                    } else if filteredTeams.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "briefcase.fill")
                                .font(.system(size: 44))
                                .foregroundColor(Color.appTextMuted)
                            Text("Chưa có tổ nghiệp vụ nào phù hợp")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredTeams) { team in
                                    teamCard(team)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Tổ Nghiệp Vụ Chuyên Trách")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng", action: onDismiss)
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        addTeamName = ""
                        addTeamId = ""
                        addTeamApps = ""
                        addTeamDesc = ""
                        addTeamLeader = ""
                        addTeamPhone = ""
                        showAddSheet = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                Task {
                    await loadSpecialistTeams()
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addTeamView
            }
            .sheet(item: $teamToEdit) { team in
                editTeamView(team: team)
            }
            .alert(item: $teamToDelete) { team in
                Alert(
                    title: Text("Xóa tổ nghiệp vụ"),
                    message: Text("Bạn có chắc chắn muốn xóa tổ \"\(team.teamName)\" khỏi hệ thống?"),
                    primaryButton: .destructive(Text("Xóa")) {
                        Task {
                            await deleteTeam(teamId: team.teamId)
                        }
                    },
                    secondaryButton: .cancel(Text("Hủy"))
                )
            }
        }
    }

    // MARK: - TEAM CARD VIEW
    private func teamCard(_ team: SpecialistTeamRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Name & ID Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(team.teamName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                    Text(team.teamId)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(tealAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tealLightBg)
                        .cornerRadius(4)
                }
                Spacer()

                // Action Menu
                HStack(spacing: 8) {
                    Button(action: {
                        editTeamName = team.teamName
                        editTeamApps = team.applications.joined(separator: ", ")
                        editTeamDesc = team.description
                        editTeamLeader = team.truongTo
                        editTeamPhone = team.sdtLienHe
                        teamToEdit = team
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                            .frame(width: 32, height: 32)
                            .background(Color.appSecondaryDarkBlue.opacity(0.1))
                            .clipShape(Circle())
                    }

                    Button(action: { teamToDelete = team }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }

            // Description
            if !team.description.isEmpty {
                Text(team.description)
                    .font(.system(size: 12.5))
                    .foregroundColor(Color.appTextSecondary)
                    .lineLimit(2)
            }

            // Leader & Contact
            if !team.truongTo.isEmpty || !team.sdtLienHe.isEmpty {
                HStack(spacing: 12) {
                    if !team.truongTo.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.shield.checkmark.fill")
                                .font(.system(size: 11))
                                .foregroundColor(tealAccent)
                            Text(team.truongTo)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color.appTextPrimary)
                        }
                    }
                    if !team.sdtLienHe.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                            Text(team.sdtLienHe)
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextSecondary)
                        }
                    }
                }
            }

            Divider().background(Color.appCardBorder)

            // Applications Tags
            if !team.applications.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ứng dụng / Phần mềm phụ trách:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.appTextMuted)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(team.applications, id: \.self) { app in
                                HStack(spacing: 3) {
                                    Image(systemName: "app.badge.fill")
                                        .font(.system(size: 10))
                                    Text(app)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(hex: "#EFF6FF"))
                                .foregroundColor(Color(hex: "#1D4ED8"))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#BFDBFE"), lineWidth: 1))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
    }

    // MARK: - ADD TEAM SHEET
    private var addTeamView: some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN TỔ NGHIỆP VỤ")) {
                    TextField("Tên tổ nghiệp vụ (vd: HẠ TẦNG MẠNG & BẢO MẬT)", text: $addTeamName)
                        .onChange(of: addTeamName) { val in
                            addTeamId = Self.generateTeamId(name: val)
                        }

                    HStack {
                        Text("Mã tổ:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("Mã tổ (vd: TO_HA_TANG_BAO_MAT)", text: $addTeamId)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(tealAccent)
                    }

                    TextField("Mô tả chức năng chuyên trách", text: $addTeamDesc)
                }

                Section(header: Text("ỨNG DỤNG / HỆ THỐNG PHỤ TRÁCH"), footer: Text("Nhập các ứng dụng phân cách bởi dấu phẩy, vd: SAP, MMS, TOPOS")) {
                    TextField("Danh sách ứng dụng (phân cách bằng dấu phẩy)", text: $addTeamApps)
                }

                Section(header: Text("TRƯỞNG TỔ & LIÊN HỆ")) {
                    TextField("Họ tên trưởng tổ", text: $addTeamLeader)
                    TextField("Số điện thoại liên hệ", text: $addTeamPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Thêm Tổ Nghiệp Vụ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { showAddSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        Task {
                            await saveNewTeam()
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .disabled(addTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingAdd)
                }
            }
        }
    }

    // MARK: - EDIT TEAM SHEET
    private func editTeamView(team: SpecialistTeamRecord) -> some View {
        NavigationView {
            Form {
                Section(header: Text("THÔNG TIN TỔ NGHIỆP VỤ")) {
                    TextField("Tên tổ nghiệp vụ", text: $editTeamName)
                    HStack {
                        Text("Mã tổ:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(team.teamId)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(tealAccent)
                    }
                    TextField("Mô tả chức năng", text: $editTeamDesc)
                }

                Section(header: Text("ỨNG DỤNG / HỆ THỐNG PHỤ TRÁCH"), footer: Text("Nhập các ứng dụng phân cách bởi dấu phẩy")) {
                    TextField("Danh sách ứng dụng (vd: MMS, TOPOS)", text: $editTeamApps)
                }

                Section(header: Text("TRƯỞNG TỔ & LIÊN HỆ")) {
                    TextField("Họ tên trưởng tổ", text: $editTeamLeader)
                    TextField("Số điện thoại liên hệ", text: $editTeamPhone)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle("Sửa Tổ Nghiệp Vụ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { teamToEdit = nil }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cập nhật") {
                        Task {
                            await updateTeam(teamId: team.teamId)
                        }
                    }
                    .font(.system(size: 14, weight: .bold))
                    .disabled(editTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSavingEdit)
                }
            }
        }
    }

    // MARK: - FIRESTORE OPERATIONS
    private func loadSpecialistTeams() async {
        isLoading = true
        errorMessage = nil

        let endpoint = "\(firestoreBaseURL)?pageSize=100"
        guard let url = URL(string: endpoint) else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {

                    if docs.isEmpty {
                        // Tự động khởi tạo 5 Tổ nghiệp vụ mặc định nếu Firestore chưa có dữ liệu
                        await seedDefaultTeams()
                        return
                    }

                    var parsed: [SpecialistTeamRecord] = []
                    for doc in docs {
                        let docPath = doc["name"] as? String ?? ""
                        let docId = docPath.components(separatedBy: "/").last ?? UUID().uuidString
                        let f = doc["fields"] as? [String: Any] ?? [:]

                        let tId = parseStr(f, "teamId").isEmpty ? docId : parseStr(f, "teamId")
                        let tName = parseStr(f, "teamName").isEmpty ? parseStr(f, "name") : parseStr(f, "teamName")
                        let desc = parseStr(f, "description").isEmpty ? parseStr(f, "moTa") : parseStr(f, "description")
                        let leader = parseStr(f, "truongTo")
                        let phone = parseStr(f, "sdtLienHe")
                        let apps = parseStringArray(f, "applications")

                        let record = SpecialistTeamRecord(
                            id: docId,
                            teamId: tId,
                            teamName: !tName.isEmpty ? tName : tId,
                            applications: apps,
                            description: desc,
                            truongTo: leader,
                            sdtLienHe: phone,
                            companyId: firebase.companyId,
                            updatedAt: 0
                        )
                        parsed.append(record)
                    }

                    let finalList = parsed.sorted { $0.teamName < $1.teamName }
                    await MainActor.run {
                        self.teams = finalList
                        self.isLoading = false
                    }
                    return
                }
            } else {
                // Không đọc được hoặc rỗng, dùng default local
                await MainActor.run {
                    self.teams = DEFAULT_SPECIALIST_TEAMS_IOS
                    self.isLoading = false
                }
                return
            }
        } catch {
            await MainActor.run {
                self.teams = DEFAULT_SPECIALIST_TEAMS_IOS
                self.isLoading = false
            }
        }
    }

    private func seedDefaultTeams() async {
        for team in DEFAULT_SPECIALIST_TEAMS_IOS {
            _ = await saveTeamToFirestore(
                teamId: team.teamId,
                name: team.teamName,
                apps: team.applications,
                desc: team.description,
                leader: "",
                phone: ""
            )
        }
        await MainActor.run {
            self.teams = DEFAULT_SPECIALIST_TEAMS_IOS
            self.isLoading = false
        }
    }

    private func saveNewTeam() async {
        let name = addTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        var tId = addTeamId.trimmingCharacters(in: .whitespacesAndNewlines)
        if tId.isEmpty {
            tId = Self.generateTeamId(name: name)
        }
        let apps = addTeamApps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let desc = addTeamDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        let leader = addTeamLeader.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = addTeamPhone.trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingAdd = true
        let ok = await saveTeamToFirestore(teamId: tId, name: name, apps: apps, desc: desc, leader: leader, phone: phone)
        isSavingAdd = false

        if ok {
            showAddSheet = false
            successMessage = "✅ Đã thêm tổ nghiệp vụ \(name) thành công!"
            await loadSpecialistTeams()
        } else {
            errorMessage = "Lỗi khi lưu tổ nghiệp vụ. Vui lòng thử lại!"
        }
    }

    private func updateTeam(teamId: String) async {
        let name = editTeamName.trimmingCharacters(in: .whitespacesAndNewlines)
        let apps = editTeamApps.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let desc = editTeamDesc.trimmingCharacters(in: .whitespacesAndNewlines)
        let leader = editTeamLeader.trimmingCharacters(in: .whitespacesAndNewlines)
        let phone = editTeamPhone.trimmingCharacters(in: .whitespacesAndNewlines)

        isSavingEdit = true
        let ok = await saveTeamToFirestore(teamId: teamId, name: name, apps: apps, desc: desc, leader: leader, phone: phone)
        isSavingEdit = false

        if ok {
            teamToEdit = nil
            successMessage = "✅ Đã cập nhật tổ nghiệp vụ thành công!"
            await loadSpecialistTeams()
        } else {
            errorMessage = "Lỗi khi cập nhật tổ nghiệp vụ. Vui lòng thử lại!"
        }
    }

    private func deleteTeam(teamId: String) async {
        let endpoint = "\(firestoreBaseURL)/\(teamId)"
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 204) {
                await MainActor.run {
                    self.teams.removeAll { $0.teamId == teamId }
                    self.successMessage = "✅ Đã xóa tổ nghiệp vụ khỏi hệ thống!"
                }
            } else {
                errorMessage = "Không thể xóa tổ nghiệp vụ (mã lỗi \( (response as? HTTPURLResponse)?.statusCode ?? 0 ))."
            }
        } catch {
            errorMessage = "Lỗi kết nối khi xóa tổ nghiệp vụ."
        }
    }

    private func saveTeamToFirestore(teamId: String, name: String, apps: [String], desc: String, leader: String, phone: String) async -> Bool {
        let endpoint = "\(firestoreBaseURL)/\(teamId)"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")
        request.setValue("QLTB-iOS", forHTTPHeaderField: "User-Agent")

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let appsArrayObj = apps.map { ["stringValue": $0] }

        let body: [String: Any] = [
            "fields": [
                "id": ["stringValue": teamId],
                "teamId": ["stringValue": teamId],
                "teamName": ["stringValue": name],
                "description": ["stringValue": desc],
                "moTa": ["stringValue": desc],
                "truongTo": ["stringValue": leader],
                "sdtLienHe": ["stringValue": phone],
                "companyId": ["stringValue": firebase.companyId],
                "updatedAt": ["integerValue": "\(nowMs)"],
                "applications": [
                    "arrayValue": [
                        "values": appsArrayObj
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (httpRes.statusCode == 200 || httpRes.statusCode == 201) {
                return true
            }
        } catch {}
        return false
    }

    // MARK: - HELPERS
    private static func generateTeamId(name: String) -> String {
        let clean = name.folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "Đ", with: "D")
            .replacingOccurrences(of: "đ", with: "d")
            .uppercased()
        let alphanumeric = clean.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let slug = alphanumeric.joined(separator: "_").prefix(20)
        if slug.isEmpty { return "TO_NGHIEP_VU" }
        return slug.hasPrefix("TO_") ? String(slug) : "TO_\(slug)"
    }

    private func parseStr(_ f: [String: Any], _ key: String) -> String {
        if let obj = f[key] as? [String: Any], let val = obj["stringValue"] as? String {
            return val
        }
        return ""
    }

    private func parseStringArray(_ f: [String: Any], _ key: String) -> [String] {
        if let obj = f[key] as? [String: Any],
           let arr = obj["arrayValue"] as? [String: Any],
           let vals = arr["values"] as? [[String: Any]] {
            return vals.compactMap { $0["stringValue"] as? String }
        }
        return []
    }
}
