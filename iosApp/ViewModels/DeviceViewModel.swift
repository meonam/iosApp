import SwiftUI

// MARK: - DEVICE GROUP MODE
public enum DeviceGroupMode: String, CaseIterable, Identifiable {
    case deptThenUnit = "Phòng ban ➔ Đơn vị"
    case unitThenDept = "Đơn vị ➔ Phòng ban"
    case flat = "Danh sách phẳng"

    public var id: String { rawValue }
}

public enum DeviceSortOption: String, CaseIterable, Identifiable {
    case newest = "Mới nhất"
    case oldest = "Cũ nhất"
    case aToZ = "A-Z"
    
    public var id: String { rawValue }
}

// MARK: - DEVICE VIEW MODEL
@MainActor
public class DeviceViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var rawDevices: [ThietBi] = []
    
    // Filters & Search
    @Published public var searchQuery: String = ""
    @Published public var selectedStatusFilter: String = "ALL"
    @Published public var selectedUnitFilter: String = ""
    @Published public var selectedDeptFilter: String = ""
    @Published public var filterType: String = "ALL" // Device type filter
    @Published public var sortOption: DeviceSortOption = .newest
    
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
    
    // Pagination
    @Published public var pageSize: Int = 20
    @Published public var currentPage: Int = 1
    @Published public var isFetchingMore: Bool = false
    public var nextPageToken: String? = nil
    public var hasMore: Bool = true

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
    }

    // Filtered devices with client-side sort & filter
    public var filteredDevices: [ThietBi] {
        let isFullAccess = user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isWarehouse
        let isDeptManager = user.isManager
        let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Role filter
        let baseList: [ThietBi]
        if isFullAccess {
            baseList = rawDevices
        } else if isDeptManager {
            let myDept = user.departmentId.lowercased()
            baseList = rawDevices.filter { dev in
                let d = (dev.phongBan ?? "").lowercased()
                return !myDept.isEmpty && (d == myDept || d.contains(myDept) || myDept.contains(d))
            }
        } else {
            baseList = rawDevices.filter { dev in
                let c = (dev.createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !c.isEmpty && c == myEmail
            }
        }

        // 2. Search & Filters
        var filtered = baseList.filter { dev in
            let matchSearch = searchQuery.isEmpty ||
                dev.ten.localizedCaseInsensitiveContains(searchQuery) ||
                dev.id.localizedCaseInsensitiveContains(searchQuery) ||
                dev.tenDonVi.localizedCaseInsensitiveContains(searchQuery) ||
                (dev.phongBan?.localizedCaseInsensitiveContains(searchQuery) ?? false) ||
                (dev.moTa?.localizedCaseInsensitiveContains(searchQuery) ?? false)

            let matchStatus = selectedStatusFilter == "ALL" ||
                dev.statusNormalized.caseInsensitiveCompare(selectedStatusFilter) == .orderedSame
                
            let matchType = filterType == "ALL" ||
                (dev.loai ?? "").caseInsensitiveCompare(filterType) == .orderedSame

            let matchUnit = selectedUnitFilter.isEmpty ||
                dev.tenDonVi.caseInsensitiveCompare(selectedUnitFilter) == .orderedSame
                
            let matchDept = selectedDeptFilter.isEmpty ||
                (dev.phongBan ?? "").caseInsensitiveCompare(selectedDeptFilter) == .orderedSame

            return matchSearch && matchStatus && matchUnit && matchType && matchDept
        }
        
        // 3. Sort
        filtered.sort { a, b in
            switch sortOption {
            case .newest:
                return a.createdAt > b.createdAt
            case .oldest:
                return a.createdAt < b.createdAt
            case .aToZ:
                return a.ten.localizedCaseInsensitiveCompare(b.ten) == .orderedAscending
            }
        }
        
        return filtered
    }
    
    // Paginated client-side for UI display if needed
    public var paginatedDevices: [ThietBi] {
        let count = min(currentPage * pageSize, filteredDevices.count)
        return Array(filteredDevices.prefix(count))
    }
    
    public func loadMore() {
        if paginatedDevices.count < filteredDevices.count {
            currentPage += 1
        }
    }

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

    public func fetchDevices(isRefresh: Bool = true) {
        if isRefresh {
            isLoading = true
            currentPage = 1
            nextPageToken = nil
        } else {
            if !hasMore { return }
            isFetchingMore = true
        }
        errorMessage = nil
        
        Task {
            // Using pageSize 1000 for full client-side filter capability or use token
            var urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices?pageSize=1000"
            if let token = nextPageToken, !isRefresh {
                urlStr += "&pageToken=\(token)"
            }
            
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.isLoading = false
                    self.isFetchingMore = false
                    self.errorMessage = "Không thể tải danh sách thiết bị"
                    return
                }

                let documents = json["documents"] as? [[String: Any]] ?? []
                self.nextPageToken = json["nextPageToken"] as? String
                self.hasMore = self.nextPageToken != nil
                
                let list: [ThietBi] = documents.compactMap { doc in
                    guard let name = doc["name"] as? String,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    let id = name.components(separatedBy: "/").last ?? ""
                    return ThietBi(
                        id: id,
                        ten: FirestoreHelper.getString(fields, "ten"),
                        tenDonVi: FirestoreHelper.getString(fields, "tenDonVi"),
                        trangThai: FirestoreHelper.getString(fields, "trangThai"),
                        createdAt: FirestoreHelper.getInt64(fields, "createdAt"),
                        role: FirestoreHelper.getString(fields, "role"),
                        loai: FirestoreHelper.getString(fields, "loai"),
                        phongBan: FirestoreHelper.getString(fields, "phongBan"),
                        moTa: FirestoreHelper.getString(fields, "moTa"),
                        createdBy: FirestoreHelper.getString(fields, "createdBy"),
                        companyId: FirestoreHelper.getString(fields, "companyId"),
                        synced: true,
                        donViMuon: FirestoreHelper.getString(fields, "donViMuon"),
                        phongBanMuon: FirestoreHelper.getString(fields, "phongBanMuon"),
                        nguoiMuon: FirestoreHelper.getString(fields, "nguoiMuon"),
                        ngayMuon: FirestoreHelper.getString(fields, "ngayMuon"),
                        ngayHenTra: FirestoreHelper.getString(fields, "ngayHenTra")
                    )
                }

                if isRefresh {
                    self.rawDevices = list
                } else {
                    self.rawDevices.append(contentsOf: list)
                }
                
                self.isLoading = false
                self.isFetchingMore = false
                self.autoExpandAllGroups()
                
            } catch {
                self.isLoading = false
                self.isFetchingMore = false
                self.errorMessage = error.localizedDescription
            }
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
