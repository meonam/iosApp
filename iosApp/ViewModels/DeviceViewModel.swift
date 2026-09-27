import SwiftUI

// MARK: - DEVICE GROUP MODE (ĐỒNG BỘ 1:1 VỚI DEVICEGROUPMODE TRÊN ANDROID)
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

// MARK: - DEVICE VIEW MODEL (ĐỒNG BỘ 1:1 VỚI DEVICEVIEWMODEL.KT)
@MainActor
public class DeviceViewModel: ObservableObject {
    public var user: User
    public var companyId: String
    public var idToken: String

    @Published public var rawDevices: [ThietBi] = []
    @Published public var deviceTypes: [DeviceType] = []
    @Published public var departments: [String] = []
    @Published public var units: [String] = []
    @Published public var unitToDeptMap: [String: String] = [:]

    // Filters & Search
    @Published public var searchQuery: String = ""
    @Published public var selectedStatusFilter: String = "ALL"
    @Published public var selectedUnitFilter: String = ""
    @Published public var selectedDeptFilter: String = ""
    @Published public var filterType: String = "ALL"
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

    public func clearSuccessMessage() {
        self.successMessage = nil
    }

    public func clearErrorMessage() {
        self.errorMessage = nil
    }

    // Filtered devices with client-side sort & filter (Role matching Android 1:1)
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

    public var groupedUnitThenDept: [String: [String: [ThietBi]]] {
        var result: [String: [String: [ThietBi]]] = [:]
        let groupedByUnit = Dictionary(grouping: filteredDevices) { (dev: ThietBi) -> String in
            dev.tenDonVi.isEmpty ? "Chưa phân đơn vị" : dev.tenDonVi
        }
        for (unit, devs) in groupedByUnit {
            result[unit] = Dictionary(grouping: devs) { (dev: ThietBi) -> String in
                (dev.phongBan ?? "").isEmpty ? "Chưa phân phòng ban" : dev.phongBan!
            }
        }
        return result
    }

    public func autoExpandAllGroups() {
        for (dept, unitMap) in groupedDeptThenUnit {
            expandedLevel1.insert(dept)
            for (unit, _) in unitMap {
                expandedLevel2.insert("\(dept)__\(unit)")
            }
        }
        for (unit, deptMap) in groupedUnitThenDept {
            expandedLevel1.insert(unit)
            for (dept, _) in deptMap {
                expandedLevel2.insert("\(unit)__\(dept)")
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

    // MARK: - FETCH DEVICES
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
            var urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices?pageSize=1000"
            if let token = nextPageToken, !isRefresh {
                urlStr += "&pageToken=\(token)"
            }

            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let documents = json["documents"] as? [[String: Any]] ?? []
                self.nextPageToken = json["nextPageToken"] as? String
                self.hasMore = self.nextPageToken != nil

                let list: [ThietBi] = documents.compactMap { (doc: [String: Any]) -> ThietBi? in
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

            } else {
                self.isLoading = false
                self.isFetchingMore = false
                self.errorMessage = "Không thể tải danh sách thiết bị"
            }
        }
    }

    // MARK: - GET DEVICE BY ID
    public func getDeviceById(_ id: String) async -> ThietBi? {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanId.isEmpty { return nil }
        if let existing = rawDevices.first(where: { $0.id.caseInsensitiveCompare(cleanId) == .orderedSame }) {
            return existing
        }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(cleanId)"
        guard let url = URL(string: urlStr) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
              httpResponse.statusCode == 200,
              let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = doc["fields"] as? [String: Any] else {
            return nil
        }

        return ThietBi(
            id: cleanId,
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

    public func checkDeviceExists(_ id: String) async -> Bool {
        return (await getDeviceById(id)) != nil
    }

    // MARK: - LOAD DEPARTMENTS AND UNITS
    public func loadDepartmentsAndUnits() {
        Task {
            // 1. Departments
            if let deptUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/departments") {
                var req = URLRequest(url: deptUrl)
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                if let (data, http) = await FirestoreHelper.executeSafeRequest(req),
                   http.statusCode == 200,
                   let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {
                    var dList: [String] = []
                    for doc in docs {
                        if let f = doc["fields"] as? [String: Any] {
                            let name = FirestoreHelper.getString(f, "departmentName")
                            let dId = FirestoreHelper.getString(f, "departmentId")
                            let effective = !name.isEmpty ? name : dId
                            if !effective.isEmpty && !dList.contains(effective) {
                                dList.append(effective)
                            }
                        }
                    }
                    self.departments = dList.sorted()
                }
            }

            // 2. Units
            if let unitUrl = URL(string: "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/units") {
                var req = URLRequest(url: unitUrl)
                req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                if let (data, http) = await FirestoreHelper.executeSafeRequest(req),
                   http.statusCode == 200,
                   let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {
                    var uList: [String] = []
                    var map: [String: String] = [:]
                    for doc in docs {
                        if let f = doc["fields"] as? [String: Any] {
                            let uName = FirestoreHelper.getString(f, "unitName").ifEmpty(FirestoreHelper.getString(f, "tenDonVi"))
                            let dept = FirestoreHelper.getString(f, "phongBan").ifEmpty(FirestoreHelper.getString(f, "departmentName"))
                            if !uName.isEmpty {
                                if !uList.contains(uName) { uList.append(uName) }
                                if !dept.isEmpty { map[uName.lowercased()] = dept }
                            }
                        }
                    }
                    self.units = uList.sorted()
                    self.unitToDeptMap = map
                }
            }
        }
    }

    // MARK: - LOAD DEVICE TYPES
    public func loadDeviceTypes() {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types"
            guard let url = URL(string: urlStr) else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

            if let (data, httpResponse) = await FirestoreHelper.executeSafeRequest(request),
               httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                let documents = json["documents"] as? [[String: Any]] ?? []
                let typesList: [DeviceType] = documents.compactMap { doc in
                    guard let namePath = doc["name"] as? String,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    let id = namePath.components(separatedBy: "/").last ?? ""
                    let name = FirestoreHelper.getString(fields, "name").ifEmpty(FirestoreHelper.getString(fields, "displayName"))
                    let phongBan = FirestoreHelper.getString(fields, "phongBan")
                    let compId = FirestoreHelper.getString(fields, "companyId")
                    return DeviceType(id: id, name: name.isEmpty ? id : name, phongBan: phongBan, companyId: compId)
                }

                if typesList.isEmpty {
                    self.setDefaultDeviceTypes()
                } else {
                    self.deviceTypes = typesList.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                }
            } else {
                self.setDefaultDeviceTypes()
            }
        }
    }

    private func setDefaultDeviceTypes() {
        let defaultNames = ["Laptop", "Máy tính để bàn (PC)", "Máy in", "Màn hình", "Máy chiếu", "Switch mạng", "Router Wifi", "Khác"]
        self.deviceTypes = defaultNames.map { name in
            DeviceType(id: name.lowercased().replacingOccurrences(of: " ", with: "_"), name: name)
        }
    }

    public func addDeviceType(name: String, phongBan: String? = nil, completion: @escaping (Result<DeviceType, Error>) -> Void) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let docId = cleanName.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(docId)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var fields: [String: Any] = [
            "id": ["stringValue": docId],
            "name": ["stringValue": cleanName],
            "companyId": ["stringValue": companyId]
        ]
        if let pb = phongBan, !pb.isEmpty {
            fields["phongBan"] = ["stringValue": pb]
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": fields])

        Task {
            if let (_, http) = await FirestoreHelper.executeSafeRequest(request),
               (200...299).contains(http.statusCode) {
                let newType = DeviceType(id: docId, name: cleanName, phongBan: phongBan, companyId: self.companyId)
                self.deviceTypes.append(newType)
                self.deviceTypes.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.successMessage = "Đã thêm loại thiết bị: \(cleanName)"
                completion(.success(newType))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lỗi thêm loại thiết bị"])))
            }
        }
    }

    public func updateDeviceType(typeId: String, newName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let cleanName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(typeId)?updateMask.fieldPaths=name"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["fields": ["name": ["stringValue": cleanName]]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Task {
            if let (_, http) = await FirestoreHelper.executeSafeRequest(request),
               (200...299).contains(http.statusCode) {
                if let idx = self.deviceTypes.firstIndex(where: { $0.id == typeId }) {
                    self.deviceTypes[idx].name = cleanName
                }
                self.successMessage = "Đã cập nhật loại thiết bị: \(cleanName)"
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lỗi cập nhật"])))
            }
        }
    }

    public func deleteDeviceType(typeId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(typeId)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        Task {
            if let (_, http) = await FirestoreHelper.executeSafeRequest(request),
               (200...299).contains(http.statusCode) {
                self.deviceTypes.removeAll { $0.id == typeId }
                self.successMessage = "Đã xóa loại thiết bị"
                completion(.success(()))
            } else {
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Lỗi xóa"])))
            }
        }
    }

    public func deleteAllDeviceTypes(completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            for t in deviceTypes {
                let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/types/\(t.id)"
                if let url = URL(string: urlStr) {
                    var req = URLRequest(url: url)
                    req.httpMethod = "DELETE"
                    req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                    _ = await FirestoreHelper.executeSafeRequest(req)
                }
            }
            self.deviceTypes.removeAll()
            self.successMessage = "Đã xóa toàn bộ danh mục loại thiết bị"
            completion(.success(()))
        }
    }

    // MARK: - ADD DEVICE (ĐỒNG BỘ 1:1 VỚI ANDROID ADDDEVICE)
    public func addDevice(
        id: String,
        ten: String,
        donVi: String,
        phongBan: String,
        loai: String,
        customStatus: String,
        donViMuon: String? = nil,
        phongBanMuon: String? = nil,
        nguoiMuon: String? = nil,
        ngayHenTra: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let cleanId = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTen = ten.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty && !cleanTen.isEmpty else {
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Thông tin không đầy đủ"])))
            return
        }

        let effectiveStatus = DeviceStatusConstants.normalize(customStatus, phongBan: phongBan, roleOrUser: user.role)
        let isLoan = effectiveStatus == DeviceStatusConstants.statusOnLoan
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        let dateStr = dateFormatter.string(from: Date())

        var fields: [String: Any] = [
            "id": ["stringValue": cleanId],
            "ten": ["stringValue": cleanTen],
            "tenDonVi": ["stringValue": donVi],
            "phongBan": ["stringValue": phongBan],
            "loai": ["stringValue": loai.lowercased().replacingOccurrences(of: " ", with: "")],
            "trangThai": ["stringValue": effectiveStatus],
            "companyId": ["stringValue": companyId],
            "createdAt": ["integerValue": "\(now)"],
            "createdBy": ["stringValue": user.email]
        ]

        if isLoan {
            if let dv = donViMuon, !dv.isEmpty { fields["donViMuon"] = ["stringValue": dv] }
            if let pb = phongBanMuon, !pb.isEmpty { fields["phongBanMuon"] = ["stringValue": pb] }
            if let nm = nguoiMuon, !nm.isEmpty { fields["nguoiMuon"] = ["stringValue": nm] }
            if let ht = ngayHenTra, !ht.isEmpty { fields["ngayHenTra"] = ["stringValue": ht] }
            fields["ngayMuon"] = ["stringValue": dateStr]
        }

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(cleanId)"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["fields": fields]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        isLoading = true
        Task {
            let res = await FirestoreHelper.executeSafeRequest(request)
            self.isLoading = false
            if let (data, http) = res, (200...299).contains(http.statusCode) {
                self.successMessage = "Đã thêm thiết bị thành công"
                self.fetchDevices()
                completion(.success(cleanId))
            } else {
                let errMsg = res != nil ? (String(data: res!.0, encoding: .utf8) ?? "Lỗi thêm thiết bị") : "Lỗi kết nối máy chủ"
                completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: errMsg])))
            }
        }
    }

    // MARK: - STATUS TRANSITION & HISTORY LOGGING (HANDLESCANANDUPDATESTATUS 1:1)
    public func handleScanAndUpdateStatus(
        deviceId: String,
        moTaInput: String,
        donViMuon: String? = nil,
        phongBanMuon: String? = nil,
        nguoiMuon: String? = nil,
        ngayHenTra: String? = nil
    ) {
        isLoading = true
        Task {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "dd/MM/yyyy"
            let ngay = dateFmt.string(from: Date())

            let timeFmt = DateFormatter()
            timeFmt.dateFormat = "dd/MM/yyyy HH:mm"
            let timeStamp = timeFmt.string(from: Date())

            let parts = moTaInput.components(separatedBy: " - ")
            let rawStatus = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? moTaInput
            let rawNote = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let upper = rawStatus.uppercased()
            let isLoanAction = upper.contains("CHO MƯỢN") || upper.contains("MƯỢN") || rawStatus == DeviceStatusConstants.statusOnLoan
            let isReturnAction = upper.contains("ĐÃ TRẢ") || upper.contains("TRẢ THIẾT BỊ") || upper.contains("THU HỒI")

            let hanhDong: String
            if isReturnAction {
                hanhDong = "ĐÃ TRẢ"
            } else if isLoanAction {
                hanhDong = "CHO MƯỢN"
            } else if upper.contains("TRẢ BẢO HÀNH") {
                hanhDong = "TRẢ BẢO HÀNH"
            } else if upper.contains("BẢO HÀNH") || upper.contains("SỬA") {
                hanhDong = "BẢO HÀNH"
            } else if upper.contains("THANH LÝ") {
                hanhDong = "THANH LÝ"
            } else if upper.contains("HỎNG") || upper.contains("XỬ LÝ") {
                hanhDong = "BÁO HỎNG"
            } else if upper.contains("SỬ DỤNG") {
                hanhDong = "SỬ DỤNG"
            } else if upper.contains("KHO") || upper.contains("SẴN SÀNG") {
                hanhDong = "TRONG KHO"
            } else if upper.contains("MỚI") {
                hanhDong = "MỚI NHẬP"
            } else {
                hanhDong = rawStatus
            }

            let statusLabel: String
            switch hanhDong {
            case "BẢO HÀNH": statusLabel = "BẢO HÀNH"
            case "TRẢ BẢO HÀNH": statusLabel = "TRẢ BẢO HÀNH"
            case "THANH LÝ": statusLabel = "THANH LÝ"
            case "CHO MƯỢN": statusLabel = "CHO MƯỢN"
            case "ĐÃ TRẢ": statusLabel = "ĐÃ TRẢ"
            case "BÁO HỎNG": statusLabel = "BÁO HỎNG"
            case "SỬ DỤNG": statusLabel = "SỬ DỤNG"
            case "TRONG KHO": statusLabel = "TRONG KHO"
            case "MỚI NHẬP": statusLabel = "MỚI NHẬP"
            default: statusLabel = rawStatus
            }

            let finalMoTa: String
            if !rawNote.isEmpty && rawNote.caseInsensitiveCompare("Không có ghi chú") != .orderedSame {
                finalMoTa = rawNote.hasPrefix("[") ? rawNote : "[\(timeStamp)] \(rawNote)"
            } else if moTaInput.hasPrefix("[") {
                finalMoTa = moTaInput
            } else {
                finalMoTa = "[\(timeStamp)] \(statusLabel)"
            }

            // 1. Log History
            let historyUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/history"
            if let histUrl = URL(string: historyUrlStr) {
                var histReq = URLRequest(url: histUrl)
                histReq.httpMethod = "POST"
                histReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                histReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let histFields: [String: Any] = [
                    "thietBiId": ["stringValue": deviceId],
                    "ngayBaoHanh": ["stringValue": ngay],
                    "moTa": ["stringValue": finalMoTa],
                    "hanhDong": ["stringValue": isReturnAction ? "TRẢ THIẾT BỊ" : hanhDong],
                    "donVi": ["stringValue": user.unitId],
                    "role": ["stringValue": user.role],
                    "createdAt": ["integerValue": "\(now)"]
                ]
                histReq.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": histFields])
                _ = await FirestoreHelper.executeSafeRequest(histReq)
            }

            // 2. Compute New Status
            let newStatus: String
            if isLoanAction {
                newStatus = DeviceStatusConstants.statusOnLoan
            } else if isReturnAction {
                newStatus = DeviceStatusConstants.statusInStock
            } else if hanhDong == "TRẢ BẢO HÀNH" || upper.contains("ĐÃ BẢO HÀNH") {
                newStatus = DeviceStatusConstants.statusInStock
            } else if hanhDong == "BẢO HÀNH" {
                newStatus = DeviceStatusConstants.statusRepair
            } else if hanhDong == "THANH LÝ" {
                newStatus = DeviceStatusConstants.statusLiquidated
            } else if hanhDong == "BÁO HỎNG" {
                newStatus = DeviceStatusConstants.statusBroken
            } else if hanhDong == "SỬ DỤNG" {
                newStatus = DeviceStatusConstants.statusInUse
            } else if hanhDong == "TRONG KHO" {
                newStatus = DeviceStatusConstants.statusInStock
            } else if hanhDong == "MỚI NHẬP" {
                newStatus = DeviceStatusConstants.statusNew
            } else {
                newStatus = DeviceStatusConstants.normalize(rawStatus, phongBan: user.departmentId, roleOrUser: user.role)
            }

            // 3. Update Device Document
            var updateMasks: [String] = ["trangThai", "moTa", "createdAt"]
            var devFields: [String: Any] = [
                "trangThai": ["stringValue": newStatus],
                "moTa": ["stringValue": finalMoTa],
                "createdAt": ["integerValue": "\(now)"]
            ]

            if isLoanAction {
                if let dv = donViMuon, !dv.isEmpty { devFields["donViMuon"] = ["stringValue": dv]; updateMasks.append("donViMuon") }
                if let pb = phongBanMuon, !pb.isEmpty { devFields["phongBanMuon"] = ["stringValue": pb]; updateMasks.append("phongBanMuon") }
                if let nm = nguoiMuon, !nm.isEmpty { devFields["nguoiMuon"] = ["stringValue": nm]; updateMasks.append("nguoiMuon") }
                devFields["ngayMuon"] = ["stringValue": timeStamp]
                updateMasks.append("ngayMuon")
                if let ht = ngayHenTra, !ht.isEmpty { devFields["ngayHenTra"] = ["stringValue": ht]; updateMasks.append("ngayHenTra") }
            } else if isReturnAction {
                // Clear loan fields
                devFields["donViMuon"] = ["stringValue": ""]
                devFields["phongBanMuon"] = ["stringValue": ""]
                devFields["nguoiMuon"] = ["stringValue": ""]
                devFields["ngayMuon"] = ["stringValue": ""]
                devFields["ngayHenTra"] = ["stringValue": ""]
                updateMasks.append(contentsOf: ["donViMuon", "phongBanMuon", "nguoiMuon", "ngayMuon", "ngayHenTra"])
            }

            let maskQuery = updateMasks.map { "updateMask.fieldPaths=\($0)" }.joined(separator: "&")
            let devUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(deviceId)?\(maskQuery)"
            if let devUrl = URL(string: devUrlStr) {
                var devReq = URLRequest(url: devUrl)
                devReq.httpMethod = "PATCH"
                devReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                devReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                devReq.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": devFields])
                _ = await FirestoreHelper.executeSafeRequest(devReq)
            }

            self.successMessage = "Đã cập nhật trạng thái: \(newStatus) (\(finalMoTa))"
            self.isLoading = false
            self.fetchDevices()
        }
    }

    public func returnBorrowedDevice(deviceId: String) {
        handleScanAndUpdateStatus(
            deviceId: deviceId,
            moTaInput: "ĐÃ TRẢ - Thu hồi thiết bị về kho"
        )
    }

    public func updateDeviceInfo(oldId: String, newTen: String, newId: String) {
        let cleanOldId = oldId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNewId = newId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTen = newTen.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanOldId.isEmpty && !cleanNewId.isEmpty && !cleanTen.isEmpty else { return }

        isLoading = true
        Task {
            if cleanOldId == cleanNewId {
                let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(cleanOldId)?updateMask.fieldPaths=ten"
                if let url = URL(string: urlStr) {
                    var req = URLRequest(url: url)
                    req.httpMethod = "PATCH"
                    req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body = ["fields": ["ten": ["stringValue": cleanTen]]]
                    req.httpBody = try? JSONSerialization.data(withJSONObject: body)
                    _ = await FirestoreHelper.executeSafeRequest(req)
                }
            } else {
                // Fetch old doc
                if let oldDev = await getDeviceById(cleanOldId) {
                    let newUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(cleanNewId)"
                    if let newUrl = URL(string: newUrlStr) {
                        var req = URLRequest(url: newUrl)
                        req.httpMethod = "PATCH"
                        req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

                        var fields: [String: Any] = [
                            "id": ["stringValue": cleanNewId],
                            "ten": ["stringValue": cleanTen],
                            "tenDonVi": ["stringValue": oldDev.tenDonVi],
                            "trangThai": ["stringValue": oldDev.trangThai],
                            "createdAt": ["integerValue": "\(oldDev.createdAt)"],
                            "companyId": ["stringValue": companyId]
                        ]
                        if let pb = oldDev.phongBan { fields["phongBan"] = ["stringValue": pb] }
                        if let l = oldDev.loai { fields["loai"] = ["stringValue": l] }
                        if let r = oldDev.role { fields["role"] = ["stringValue": r] }
                        if let m = oldDev.moTa { fields["moTa"] = ["stringValue": m] }

                        req.httpBody = try? JSONSerialization.data(withJSONObject: ["fields": fields])
                        _ = await FirestoreHelper.executeSafeRequest(req)

                        // Delete old doc
                        let delUrlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices/\(cleanOldId)"
                        if let delUrl = URL(string: delUrlStr) {
                            var delReq = URLRequest(url: delUrl)
                            delReq.httpMethod = "DELETE"
                            delReq.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                            _ = await FirestoreHelper.executeSafeRequest(delReq)
                        }
                    }
                }
            }
            self.successMessage = "Cập nhật thiết bị thành công"
            self.isLoading = false
            self.fetchDevices()
        }
    }

    public func updateDeviceStatus(deviceId: String, newStatus: String) {
        handleScanAndUpdateStatus(deviceId: deviceId, moTaInput: "\(newStatus) - Cập nhật trạng thái")
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

            _ = await FirestoreHelper.executeSafeRequest(request)
            self.successMessage = "Đã xóa thiết bị \(deviceId)"
            self.fetchDevices()
        }
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        return self.isEmpty ? fallback : self
    }
}
