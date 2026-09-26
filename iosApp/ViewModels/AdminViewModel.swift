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
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/users?pageSize=200"
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
            let rootUrl = URL(string: "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/users?pageSize=200")!
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
                // Mock danh sách mẫu nếu offline/chưa có mạng
                self.allUsers = [
                    User(maNhanVien: "NV001", email: "admin@sgcoop.com", role: "ADMIN", fullName: "Quản trị viên Hệ thống", donVi: "Văn phòng SGCOOP", departmentId: "Phòng CNTT", status: "ACTIVE"),
                    User(maNhanVien: "NV002", email: "ktv01@sgcoop.com", role: "TECHNICIAN", fullName: "Nguyễn Văn Kỹ Thuật", donVi: "Co.opmart Cần Thơ", departmentId: "Tổ Kỹ thuật", status: "ACTIVE"),
                    User(maNhanVien: "NV003", email: "helpdesk@sgcoop.com", role: "HELPDESK", fullName: "Trần Thị Hỗ Trợ", donVi: "Văn phòng SGCOOP", departmentId: "Trung tâm Hỗ trợ IT", status: "ACTIVE"),
                    User(maNhanVien: "NV004", email: "staff_new@sgcoop.com", role: "STAFF", fullName: "Lê Văn Đăng Ký", donVi: "Co.opmart Hậu Giang", departmentId: "Bộ phận Thu ngân", status: "PENDING")
                ]
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
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/users/\(encodedEmail)?updateMask.fieldPaths=status&updateMask.fieldPaths=role&updateMask.fieldPaths=donVi&updateMask.fieldPaths=departmentId"
            
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": patchFields])
                _ = try? await URLSession.shared.data(for: request)
            }

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
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/users/\(encodedEmail)?updateMask.fieldPaths=status"
            
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": patchFields])
                _ = try? await URLSession.shared.data(for: request)
            }

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
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/users/\(encodedEmail)?updateMask.fieldPaths=donVi&updateMask.fieldPaths=departmentId"
            
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": patchFields])
                _ = try? await URLSession.shared.data(for: request)
            }

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
            let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/users/\(encodedEmail)?updateMask.fieldPaths=role"
            
            if let url = URL(string: urlString) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !idToken.isEmpty { request.addValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization") }
                request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": patchFields])
                _ = try? await URLSession.shared.data(for: request)
            }

            if let idx = allUsers.firstIndex(where: { $0.email.caseInsensitiveCompare(email) == .orderedSame }) {
                allUsers[idx].role = newRole
            }
            self.isLoading = false
            self.successMessage = "✅ Đã cập nhật vai trò thành \(newRole)"
        }
    }

    // MARK: - FETCH DEPARTMENTS
    public func fetchDepartments() {
        Task {
            let comp = self.companyId.isEmpty ? "SGCOOP" : self.companyId
            let urlString = "https://firestore.googleapis.com/v1/projects/qltb-f89fa/databases/(default)/documents/companies/\(comp)/departments?pageSize=100"
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
                // Dữ liệu mẫu mặc định
                self.departments = [
                    Department(departmentId: "cntt", companyId: comp, departmentName: "Phòng Công nghệ thông tin", departmentType: "IT", isHelpDesk: true, isIncidentHandler: true, hotline: "19001234"),
                    Department(departmentId: "thungan", companyId: comp, departmentName: "Bộ phận Thu ngân & POS", departmentType: "UNIT", hotline: "028383838"),
                    Department(departmentId: "kho", companyId: comp, departmentName: "Bộ phận Kho vận & Logistics", departmentType: "WAREHOUSE"),
                    Department(departmentId: "hcns", companyId: comp, departmentName: "Phòng Hành chính Nhân sự", departmentType: "GENERAL")
                ]
            }
        }
    }

    // MARK: - FETCH UNITS & REGIONS
    public func fetchUnitsAndRegions() {
        self.units = [
            DonVi(id: "sg_cantho", tenDonVi: "Co.opmart Cần Thơ", maKhuVuc: "KV_MIENTAY"),
            DonVi(id: "sg_haugiang", tenDonVi: "Co.opmart Hậu Giang", maKhuVuc: "KV_MIENTAY"),
            DonVi(id: "sg_congquynh", tenDonVi: "Co.opmart Cống Quỳnh", maKhuVuc: "KV_TPHCM"),
            DonVi(id: "sg_nguyendinhchieu", tenDonVi: "Co.opmart Nguyễn Đình Chiểu", maKhuVuc: "KV_TPHCM"),
            DonVi(id: "sg_vanphong", tenDonVi: "Văn phòng Saigon Co.op", maKhuVuc: "KV_TPHCM")
        ]
        self.regions = [
            KhuVuc(maKhuVuc: "KV_TPHCM", tenKhuVuc: "Khu vực TP. Hồ Chí Minh"),
            KhuVuc(maKhuVuc: "KV_MIENTAY", tenKhuVuc: "Khu vực Miền Tây Nam Bộ"),
            KhuVuc(maKhuVuc: "KV_MIENDONG", tenKhuVuc: "Khu vực Miền Đông Nam Bộ"),
            KhuVuc(maKhuVuc: "KV_MIENTRUNG", tenKhuVuc: "Khu vực Miền Trung & Tây Nguyên")
        ]
    }
}
