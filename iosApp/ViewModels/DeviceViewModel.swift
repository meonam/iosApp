import SwiftUI

// MARK: - DEVICE GROUP MODE (ĐỒNG BỘ 1:1 VỚI DEVICEGROUPMODE TRÊN ANDROID)
public enum DeviceGroupMode: String, CaseIterable, Identifiable {
    case deptThenUnit = "Phòng ban ➔ Đơn vị"
    case unitThenDept = "Đơn vị ➔ Phòng ban"
    case flat = "Danh sách phẳng"

    public var id: String { rawValue }
}

// MARK: - DEVICE VIEW MODEL (ĐỒNG BỘ 1:1 VỚI DEVICEVIEWMODEL.KT TRÊN ANDROID)
@MainActor
public class DeviceViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var rawDevices: [ThietBi] = []
    @Published public var searchQuery: String = ""
    @Published public var selectedStatusFilter: String = "ALL"
    @Published public var selectedUnitFilter: String = ""
    @Published public var selectedDeptFilter: String = ""
    @Published public var groupMode: DeviceGroupMode = .deptThenUnit
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil

    // Batch mode
    @Published public var isBatchModeEnabled: Bool = false
    @Published public var selectedBatchDeviceIds: Set<String> = []

    // Accordion expanded states
    @Published public var expandedLevel1: Set<String> = []
    @Published public var expandedLevel2: Set<String> = []

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
    }

    // Danh sách thiết bị sau khi lọc theo quyền người dùng & bộ lọc tìm kiếm
    public var filteredDevices: [ThietBi] {
        let isFullAccess = user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isWarehouse
        let isDeptManager = user.isManager
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Lọc theo Role / Phân quyền chuẩn
        let baseList: [ThietBi]
        if isFullAccess {
            // Admin xem toàn bộ thiết bị
            baseList = rawDevices
        } else if isDeptManager {
            let myDept = user.departmentId.lowercased()
            baseList = rawDevices.filter { dev in
                let d = (dev.phongBan ?? "").lowercased()
                return !myDept.isEmpty && (d == myDept || d.contains(myDept) || myDept.contains(d))
            }
        } else {
            // Staff chỉ xem thiết bị do mình tạo
            baseList = rawDevices.filter { dev in
                let c = (dev.createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !c.isEmpty && c == myEmail
            }
        }

        // 2. Lọc theo từ khóa tìm kiếm & Trạng thái & Đơn vị
        return baseList.filter { dev in
            let matchSearch = searchQuery.isEmpty ||
                dev.ten.localizedCaseInsensitiveContains(searchQuery) ||
                dev.id.localizedCaseInsensitiveContains(searchQuery) ||
                dev.tenDonVi.localizedCaseInsensitiveContains(searchQuery) ||
                (dev.phongBan?.localizedCaseInsensitiveContains(searchQuery) ?? false)

            let matchStatus = selectedStatusFilter == "ALL" ||
                dev.statusNormalized.caseInsensitiveCompare(selectedStatusFilter) == .orderedSame

            let matchUnit = selectedUnitFilter.isEmpty ||
                dev.tenDonVi.caseInsensitiveCompare(selectedUnitFilter) == .orderedSame

            return matchSearch && matchStatus && matchUnit
        }
    }

    // Cấu trúc phân nhóm 2 cấp: Phòng ban -> Đơn vị -> [ThietBi]
    public var groupedDeptThenUnit: [String: [String: [ThietBi]]] {
        var result: [String: [String: [ThietBi]]] = [:]
        let groupedByDept = Dictionary(grouping: filteredDevices) { (dev: ThietBi) -> String in
            (dev.phongBan ?? "").isEmpty ? "Chưa phân phòng ban" : dev.phongBan!
        }
        for (dept, devs) in groupedByDept {
            result[dept] = Dictionary(grouping: devs) { (dev: ThietBi) -> String in
                dev.tenDonVi.isEmpty ? "Chưa phân đơn vị" : dev.tenDonVi
            }
        }
        return result
    }

    // Tải danh sách thiết bị từ Firestore (Toàn bộ 13 thiết bị cho Admin)
    public func fetchDevices() {
        isLoading = true
        errorMessage = nil
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices?pageSize=100"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let documents = json["documents"] as? [[String: Any]] else {
                self.isLoading = false
                self.errorMessage = "Không thể tải danh sách thiết bị"
                return
            }

            let list: [ThietBi] = documents.compactMap { doc in
                guard let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { return nil }
                let id = name.components(separatedBy: "/").last ?? ""
                return ThietBi(
                    id: id,
                    ten: FirestoreHelper.getString(fields["ten"] as? [String: Any]),
                    tenDonVi: FirestoreHelper.getString(fields["tenDonVi"] as? [String: Any]),
                    trangThai: FirestoreHelper.getString(fields["trangThai"] as? [String: Any]),
                    createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                    role: FirestoreHelper.getString(fields["role"] as? [String: Any]),
                    loai: FirestoreHelper.getString(fields["loai"] as? [String: Any]),
                    phongBan: FirestoreHelper.getString(fields["phongBan"] as? [String: Any]),
                    moTa: FirestoreHelper.getString(fields["moTa"] as? [String: Any]),
                    createdBy: FirestoreHelper.getString(fields["createdBy"] as? [String: Any]),
                    companyId: FirestoreHelper.getString(fields["companyId"] as? [String: Any]),
                    synced: true,
                    donViMuon: FirestoreHelper.getString(fields["donViMuon"] as? [String: Any]),
                    phongBanMuon: FirestoreHelper.getString(fields["phongBanMuon"] as? [String: Any]),
                    nguoiMuon: FirestoreHelper.getString(fields["nguoiMuon"] as? [String: Any]),
                    ngayMuon: FirestoreHelper.getString(fields["ngayMuon"] as? [String: Any]),
                    ngayHenTra: FirestoreHelper.getString(fields["ngayHenTra"] as? [String: Any])
                )
            }

            self.rawDevices = list
            self.isLoading = false

            // Tự động mở rộng tất cả các nhóm khi tải xong
            self.autoExpandAllGroups()
        }
    }

    public func autoExpandAllGroups() {
        for (dept, unitMap) in groupedDeptThenUnit {
            expandedLevel1.insert(dept)
            for (unit, _) in unitMap {
                expandedLevel2.insert("\(dept)__\(unit)")
            }
        }
    }

    public func toggleLevel1(_ key: String) {
        if expandedLevel1.contains(key) {
            expandedLevel1.remove(key)
        } else {
            expandedLevel1.insert(key)
        }
    }

    public func toggleLevel2(_ key: String) {
        if expandedLevel2.contains(key) {
            expandedLevel2.remove(key)
        } else {
            expandedLevel2.insert(key)
        }
    }

    public func toggleExpandAll() {
        if expandedLevel1.isEmpty {
            autoExpandAllGroups()
        } else {
            expandedLevel1.removeAll()
            expandedLevel2.removeAll()
        }
    }

    // Cập nhật trạng thái thiết bị
    public func updateDeviceStatus(deviceId: String, newStatus: String) {
        isLoading = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(deviceId)?updateMask.fieldPaths=trangThai"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body = ["fields": ["trangThai": ["stringValue": newStatus]]]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            _ = try? await URLSession.shared.data(for: request)
            self.successMessage = "Đã cập nhật trạng thái thiết bị \(deviceId) thành \(newStatus)"
            self.fetchDevices()
        }
    }

    // Xóa thiết bị (Dành cho Admin)
    public func deleteDevice(deviceId: String) {
        guard user.isAdmin || user.isSuperAdmin else { return }
        isLoading = true
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(deviceId)"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            _ = try? await URLSession.shared.data(for: request)
            self.successMessage = "Đã xóa thiết bị \(deviceId)"
            self.fetchDevices()
        }
    }
}
