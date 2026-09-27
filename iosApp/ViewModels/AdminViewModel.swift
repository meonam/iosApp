import SwiftUI

// MARK: - ADMIN VIEW MODEL (ĐỒNG BỘ 1:1 THEO ADMINVIEWMODEL.KT & SUPERADMINPORTALSCREEN TRÊN ANDROID)
@MainActor
public class AdminViewModel: ObservableObject {
    public var currentUser: User
    public var companyId: String
    public var idToken: String

    @Published public var allUsers: [User] = []
    @Published public var departments: [Department] = []
    @Published public var units: [DonVi] = []
    @Published public var regions: [KhuVuc] = []
    @Published public var deviceTypes: [String] = [
        "Laptop", "Máy tính để bàn (PC)", "Máy in laser", "Máy in nhiệt",
        "Máy quét Barcode", "Thiết bị mạng (Router/Switch)", "Màn hình (Monitor)", "Bộ lưu điện (UPS)", "Khác"
    ]

    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil

    @Published public var systemConfig: SystemConfig? = nil
    @Published public var isLoadingConfig = false
    @Published public var notifications: [AppNotification] = []
    @Published public var isLoadingNotifications = false

    public init(user: User, companyId: String, idToken: String) {
        self.currentUser = user
        self.companyId = companyId.isEmpty ? "SGCOOP" : companyId
        self.idToken = idToken
    }

    public var pendingUsers: [User] {
        allUsers.filter { $0.status.uppercased() == "PENDING" }
    }

    // MARK: - FETCH USERS (TẢI DANH SÁCH TÀI KHOẢN TỪ FIRESTORE)
    public func fetchUsers() {
        isLoading = true
        errorMessage = nil

        Task {
            let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
            let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/users?pageSize=200"
            guard let url = URL(string: urlString) else {
                self.isLoading = false
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !idToken.isEmpty {
                request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }

            // Thử subcollection theo companyId trước, nếu không có thì fallback ra root `users`
            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let documents = json["documents"] as? [[String: Any]], !documents.isEmpty {
                self.allUsers = parseUsers(from: documents)
                self.isLoading = false
                return
            }

            // Fallback load root users
            let rootUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/users?pageSize=200")!
            var rootRequest = URLRequest(url: rootUrl)
            if !idToken.isEmpty {
                rootRequest.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await URLSession.shared.data(for: rootRequest),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let documents = json["documents"] as? [[String: Any]] {
                self.allUsers = parseUsers(from: documents)
            } else {
                self.allUsers = []
                self.errorMessage = "Không thể tải danh sách tài khoản từ máy chủ."
            }
            self.isLoading = false
        }
    }

    private func parseUsers(from documents: [[String: Any]]) -> [User] {
        return documents.compactMap { doc in
            guard let name = doc["name"] as? String,
                  let fields = doc["fields"] as? [String: Any] else { return nil }
            let email = name.components(separatedBy: "/").last ?? ""
            return User(
                maNhanVien: FirestoreHelper.getString(fields["maNhanVien"] as? [String: Any]),
                email: email,
                role: FirestoreHelper.getString(fields["role"] as? [String: Any]),
                fullName: FirestoreHelper.getString(fields["fullName"] as? [String: Any]),
                phone: FirestoreHelper.getString(fields["phone"] as? [String: Any]),
                donVi: FirestoreHelper.getString(fields["donVi"] as? [String: Any]),
                companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
                departmentId: FirestoreHelper.getString(fields["departmentId"] as? [String: Any]),
                status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                avatarUrl: FirestoreHelper.getString(fields["avatarUrl"] as? [String: Any]),
                createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                mustChangePassword: FirestoreHelper.getBool(fields["mustChangePassword"] as? [String: Any]),
                maKhuVuc: FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any]),
                toNghiepVu: FirestoreHelper.getString(fields["toNghiepVu"] as? [String: Any]),
                lastActiveAt: FirestoreHelper.getInt64(fields["lastActiveAt"] as? [String: Any]),
                isOnline: FirestoreHelper.getBool(fields["isOnline"] as? [String: Any]),
                permissions: FirestoreHelper.getStringArray(fields["permissions"] as? [String: Any])
            )
        }
    }

    private func patchUserDocument(email: String, fields: [String: Any], updateMasks: [String]) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
        let maskQuery = updateMasks.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
        
        let urls = [
            "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/users/\(encodedEmail)?\(maskQuery)",
            "\(FirebaseConfig.firestoreBaseUrl)/users/\(encodedEmail)?\(maskQuery)"
        ]
        
        for urlStr in urls {
            guard let url = URL(string: urlStr) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
            request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": fields])
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // MARK: - APPROVE USER (DUYỆT NHÂN VIÊN MỚI)
    public func approveUser(email: String, role: String, donVi: String, departmentId: String) {
        isLoading = true
        Task {
            let patchFields: [String: Any] = [
                "status": FirestoreHelper.valueToFirestore("ACTIVE"),
                "role": FirestoreHelper.valueToFirestore(role),
                "donVi": FirestoreHelper.valueToFirestore(donVi),
                "departmentId": FirestoreHelper.valueToFirestore(departmentId)
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["status", "role", "donVi", "departmentId"])

            // Cập nhật local state ngay lập tức
            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].status = "ACTIVE"
                allUsers[idx].role = role
                allUsers[idx].donVi = donVi
                allUsers[idx].departmentId = departmentId
            }
            self.isLoading = false
            self.successMessage = "✅ Đã phê duyệt nhân viên: \(email)"
        }
    }

    // MARK: - REJECT USER (TỪ CHỐI NHÂN VIÊN)
    public func rejectUser(email: String) {
        isLoading = true
        Task {
            let patchFields: [String: Any] = [
                "status": FirestoreHelper.valueToFirestore("REJECTED")
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["status"])

            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].status = "REJECTED"
            }
            self.isLoading = false
            self.successMessage = "Đã từ chối tài khoản: \(email)"
        }
    }

    // MARK: - TRANSFER USER (ĐIỀU CHUYỂN PHÒNG BAN / ĐƠN VỊ)
    public func transferUser(email: String, newUnit: String, newDept: String) {
        isLoading = true
        Task {
            let patchFields: [String: Any] = [
                "donVi": FirestoreHelper.valueToFirestore(newUnit),
                "departmentId": FirestoreHelper.valueToFirestore(newDept)
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["donVi", "departmentId"])

            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].donVi = newUnit
                allUsers[idx].departmentId = newDept
            }
            self.isLoading = false
            self.successMessage = "✅ Đã điều chuyển nhân viên sang \(newUnit) - \(newDept)"
        }
    }

    // MARK: - UPDATE ROLE (PHÂN QUYỀN VAI TRÒ)
    public func updateUserRole(email: String, newRole: String) {
        isLoading = true
        Task {
            let patchFields: [String: Any] = [
                "role": FirestoreHelper.valueToFirestore(newRole)
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["role"])

            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].role = newRole
            }
            self.isLoading = false
            self.successMessage = "✅ Đã cập nhật vai trò thành \(newRole)"
        }
    }

    // MARK: - DISABLE / ENABLE USER
    public func disableUser(email: String, disable: Bool) {
        isLoading = true
        Task {
            let newStatus = disable ? "DISABLED" : "ACTIVE"
            let patchFields: [String: Any] = [
                "status": FirestoreHelper.valueToFirestore(newStatus)
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["status"])

            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].status = newStatus
            }
            self.isLoading = false
            self.successMessage = disable ? "Đã khóa tài khoản: \(email)" : "Đã mở khóa tài khoản: \(email)"
        }
    }

    // MARK: - RESET PASSWORD
    public func resetUserPassword(email: String) {
        isLoading = true
        Task {
            let patchFields: [String: Any] = [
                "mustChangePassword": FirestoreHelper.valueToFirestore(true)
            ]
            await patchUserDocument(email: email, fields: patchFields, updateMasks: ["mustChangePassword"])

            self.isLoading = false
            self.successMessage = "Đã yêu cầu đổi mật khẩu cho: \(email)"
        }
    }

    // MARK: - FETCH DEPARTMENTS
    public func fetchDepartments() {
        Task {
            let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
            let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments?pageSize=100"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let documents = json["documents"] as? [[String: Any]] {
                self.departments = documents.compactMap { doc in
                    guard let name = doc["name"] as? String,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    return Department(
                        departmentId: id,
                        companyId: comp,
                        departmentName: FirestoreHelper.getString(fields["departmentName"] as? [String: Any]),
                        departmentType: FirestoreHelper.getString(fields["departmentType"] as? [String: Any]),
                        isHelpDesk: FirestoreHelper.getBool(fields["isHelpDesk"] as? [String: Any]),
                        isIncidentHandler: FirestoreHelper.getBool(fields["isIncidentHandler"] as? [String: Any]),
                        isWarehouse: FirestoreHelper.getBool(fields["isWarehouse"] as? [String: Any]),
                        isApplicationSupport: FirestoreHelper.getBool(fields["isApplicationSupport"] as? [String: Any]),
                        managerEmail: FirestoreHelper.getString(fields["managerEmail"] as? [String: Any]),
                        managerName: FirestoreHelper.getString(fields["managerName"] as? [String: Any]),
                        hotline: FirestoreHelper.getString(fields["hotline"] as? [String: Any]),
                        location: FirestoreHelper.getString(fields["location"] as? [String: Any]),
                        assignedRegionId: FirestoreHelper.getString(fields["assignedRegionId"] as? [String: Any]),
                        slaResponseMinutes: FirestoreHelper.getInt(fields["slaResponseMinutes"] as? [String: Any]),
                        slaResolveMinutes: FirestoreHelper.getInt(fields["slaResolveMinutes"] as? [String: Any]),
                        isActive: FirestoreHelper.getBool(fields["isActive"] as? [String: Any]),
                        parentDepartmentId: FirestoreHelper.getString(fields["parentDepartmentId"] as? [String: Any]),
                        colorHex: FirestoreHelper.getString(fields["colorHex"] as? [String: Any]),
                        khuVucPhuTrach: FirestoreHelper.getStringArray(fields["khuVucPhuTrach"] as? [String: Any])
                    )
                }
            } else {
                self.departments = []
            }
        }
    }

    // MARK: - FETCH UNITS & REGIONS
    public func fetchUnitsAndRegions() {
        isLoading = true
        Task {
            let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
            let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/units?pageSize=100"
            guard let url = URL(string: urlString) else { return }

            var request = URLRequest(url: url)
            if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let documents = json["documents"] as? [[String: Any]] {
                self.units = documents.compactMap { doc in
                    guard let name = doc["name"] as? String,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    return DonVi(
                        id: id,
                        tenDonVi: FirestoreHelper.getString(fields["unitName"] as? [String: Any]).isEmpty ? FirestoreHelper.getString(fields["name"] as? [String: Any]) : FirestoreHelper.getString(fields["unitName"] as? [String: Any]),
                        maKhuVuc: FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any])
                    )
                }
            } else {
                self.units = []
            }
            
            // Regions
            let regUrlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/khu_vuc?pageSize=100"
            if let regUrl = URL(string: regUrlString) {
                var regRequest = URLRequest(url: regUrl)
                if !idToken.isEmpty { regRequest.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

                if let (data, response) = try? await URLSession.shared.data(for: regRequest),
                   let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = json["documents"] as? [[String: Any]] {
                    self.regions = documents.compactMap { doc in
                        guard let name = doc["name"] as? String,
                              let fields = doc["fields"] as? [String: Any] else { return nil }
                        let id = name.components(separatedBy: "/").last ?? ""
                        return KhuVuc(
                            maKhuVuc: FirestoreHelper.getString(fields["maKhuVuc"] as? [String: Any]),
                            tenKhuVuc: FirestoreHelper.getString(fields["tenKhuVuc"] as? [String: Any])
                        )
                    }
                }
            }
            self.isLoading = false
        }
    }

    // MARK: - CRUD SPECIALIST TEAMS
    @Published public var specialistTeams: [SpecialistTeam] = []

    public func fetchSpecialistTeams() async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/specialist_teams?pageSize=100"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let documents = json["documents"] as? [[String: Any]] {
            let teams = documents.compactMap { doc -> SpecialistTeam? in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""
                return SpecialistTeam(
                    id: id,
                    teamId: FirestoreHelper.getString(fields["teamId"] as? [String: Any]),
                    teamName: FirestoreHelper.getString(fields["teamName"] as? [String: Any]),
                    applications: FirestoreHelper.getStringArray(fields["applications"] as? [String: Any]),
                    description: FirestoreHelper.getString(fields["description"] as? [String: Any]),
                    moTa: FirestoreHelper.getString(fields["moTa"] as? [String: Any]),
                    truongTo: FirestoreHelper.getString(fields["truongTo"] as? [String: Any]),
                    sdtLienHe: FirestoreHelper.getString(fields["sdtLienHe"] as? [String: Any]),
                    companyId: comp,
                    updatedAt: FirestoreHelper.getInt64(fields["updatedAt"] as? [String: Any])
                )
            }
            DispatchQueue.main.async {
                self.specialistTeams = teams
            }
        }
    }

    public func addSpecialistTeam(name: String, description: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let teamId = "TO_" + name.uppercased().replacingOccurrences(of: " ", with: "_").prefix(10)
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/specialist_teams?documentId=\(teamId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        let body: [String: Any] = [
            "fields": [
                "id": ["stringValue": teamId],
                "teamId": ["stringValue": teamId],
                "teamName": ["stringValue": name],
                "description": ["stringValue": description],
                "moTa": ["stringValue": description],
                "companyId": ["stringValue": comp]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            await fetchSpecialistTeams()
        }
    }

    public func deleteSpecialistTeam(teamId: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/specialist_teams/\(teamId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            await fetchSpecialistTeams()
        }
    }

    // MARK: - DEPARTMENTS CRUD
    public func addDepartment(name: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let deptId = "DEPT_" + name.uppercased().replacingOccurrences(of: " ", with: "_").prefix(10)
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments?documentId=\(deptId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        let body: [String: Any] = [
            "fields": [
                "departmentName": ["stringValue": name],
                "departmentType": ["stringValue": "GENERAL"],
                "isActive": ["booleanValue": true],
                "companyId": ["stringValue": comp]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            fetchDepartments()
        }
    }

    public func deleteDepartment(deptId: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/departments/\(deptId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            fetchDepartments()
        }
    }

    // MARK: - UNITS CRUD
    public func addUnit(name: String, region: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let unitId = "UNIT_" + name.uppercased().replacingOccurrences(of: " ", with: "_").prefix(10)
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/units?documentId=\(unitId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        let body: [String: Any] = [
            "fields": [
                "unitName": ["stringValue": name],
                "maKhuVuc": ["stringValue": region],
                "companyId": ["stringValue": comp]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            fetchUnitsAndRegions()
        }
    }

    public func deleteUnit(unitId: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/units/\(unitId)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }

        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            fetchUnitsAndRegions()
        }
    }

    // MARK: - SYSTEM SETTINGS
    public func fetchSystemConfig() async {
        isLoadingConfig = true
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/system_config/general"
        guard let url = URL(string: urlString) else {
            self.isLoadingConfig = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                self.systemConfig = SystemConfig(
                    companyName: FirestoreHelper.getString(fields["companyName"] as? [String: Any]),
                    gpsRadiusMeters: FirestoreHelper.getInt(fields["gpsRadiusMeters"] as? [String: Any]),
                    slaUrgentHours: FirestoreHelper.getInt(fields["slaUrgentHours"] as? [String: Any]),
                    slaHighHours: FirestoreHelper.getInt(fields["slaHighHours"] as? [String: Any]),
                    slaNormalHours: FirestoreHelper.getInt(fields["slaNormalHours"] as? [String: Any]),
                    allowRemoteCheckin: FirestoreHelper.getBool(fields["allowRemoteCheckin"] as? [String: Any])
                )
            } else {
                // Default if not found
                self.systemConfig = SystemConfig(companyName: "Công ty mặc định", gpsRadiusMeters: 150, slaUrgentHours: 2, slaHighHours: 4, slaNormalHours: 8, allowRemoteCheckin: false)
            }
        } catch {
            print("Error fetching config: \(error)")
        }
        self.isLoadingConfig = false
    }

    public func saveSystemConfig(companyName: String, gpsRadius: Int, slaUrgentHours: Int, slaNormalHours: Int) async {
        isLoadingConfig = true
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/system_config/general?updateMask.fieldPaths=companyName&updateMask.fieldPaths=gpsRadiusMeters&updateMask.fieldPaths=slaUrgentHours&updateMask.fieldPaths=slaNormalHours"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        
        let body: [String: Any] = [
            "fields": [
                "companyName": ["stringValue": companyName],
                "gpsRadiusMeters": ["integerValue": String(gpsRadius)],
                "slaUrgentHours": ["integerValue": String(slaUrgentHours)],
                "slaNormalHours": ["integerValue": String(slaNormalHours)]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let _ = try await URLSession.shared.data(for: request)
            if self.systemConfig != nil {
                self.systemConfig?.companyName = companyName
                self.systemConfig?.gpsRadiusMeters = gpsRadius
                self.systemConfig?.slaUrgentHours = slaUrgentHours
                self.systemConfig?.slaNormalHours = slaNormalHours
            }
            self.successMessage = "Lưu cấu hình thành công"
        } catch {
            print("Error saving config: \(error)")
        }
        self.isLoadingConfig = false
    }

    // MARK: - SYSTEM NOTIFICATIONS
    public func fetchNotifications() async {
        isLoadingNotifications = true
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/notifications?pageSize=10" // simplify, should ideally orderBy
        guard let url = URL(string: urlString) else {
            self.isLoadingNotifications = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let documents = json["documents"] as? [[String: Any]] {
                self.notifications = documents.compactMap { doc in
                    guard let name = doc["name"] as? String,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    let title = FirestoreHelper.getString(fields["title"] as? [String: Any])
                    let body = FirestoreHelper.getString(fields["body"] as? [String: Any])
                    let targetRole = FirestoreHelper.getString(fields["targetRole"] as? [String: Any])
                    let createdAt = FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any])
                    let createdByEmail = FirestoreHelper.getString(fields["createdByEmail"] as? [String: Any])
                    return AppNotification(id: id, title: title, body: body, targetRole: targetRole, createdAt: Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0), createdByEmail: createdByEmail)
                }
                // Sort by date descending
                self.notifications.sort { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("Error fetching notifications: \(error)")
        }
        self.isLoadingNotifications = false
    }

    public func sendNotification(title: String, body: String, targetRole: String?) async {
        isLoadingNotifications = true
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/notifications"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let docBody: [String: Any] = [
            "fields": [
                "title": ["stringValue": title],
                "body": ["stringValue": body],
                "targetRole": ["stringValue": targetRole ?? "ALL"],
                "createdAt": ["integerValue": String(now)],
                "createdByEmail": ["stringValue": self.currentUser.email]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: docBody)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let name = json["name"] as? String {
                let id = name.components(separatedBy: "/").last ?? ""
                let newNotif = AppNotification(id: id, title: title, body: body, targetRole: targetRole ?? "ALL", createdAt: Date(), createdByEmail: self.currentUser.email)
                self.notifications.insert(newNotif, at: 0)
                self.successMessage = "Đã gửi thông báo"
            }
        } catch {
            print("Error sending notification: \(error)")
        }
        self.isLoadingNotifications = false
    }

    public func deleteNotification(notifId: String) async {
        let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(comp)/notifications/\(notifId)"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        if !idToken.isEmpty { request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
        
        do {
            let _ = try await URLSession.shared.data(for: request)
            self.notifications.removeAll { $0.id == notifId }
            self.successMessage = "Đã xóa thông báo"
        } catch {
            print("Error deleting notification: \(error)")
        }
    }
}

public struct SystemConfig {
    public var companyName: String
    public var gpsRadiusMeters: Int
    public var slaUrgentHours: Int
    public var slaHighHours: Int
    public var slaNormalHours: Int
    public var allowRemoteCheckin: Bool

    public init(companyName: String, gpsRadiusMeters: Int, slaUrgentHours: Int, slaHighHours: Int, slaNormalHours: Int, allowRemoteCheckin: Bool) {
        self.companyName = companyName
        self.gpsRadiusMeters = gpsRadiusMeters
        self.slaUrgentHours = slaUrgentHours
        self.slaHighHours = slaHighHours
        self.slaNormalHours = slaNormalHours
        self.allowRemoteCheckin = allowRemoteCheckin
    }
}

public struct AppNotification: Identifiable {
    public var id: String
    public var title: String
    public var body: String
    public var targetRole: String
    public var createdAt: Date
    public var createdByEmail: String

    public init(id: String, title: String, body: String, targetRole: String, createdAt: Date, createdByEmail: String) {
        self.id = id
        self.title = title
        self.body = body
        self.targetRole = targetRole
        self.createdAt = createdAt
        self.createdByEmail = createdByEmail
    }
}

