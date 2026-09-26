import SwiftUI

// MARK: - HOME VIEW MODEL (ĐỒNG BỘ 1:1 VỚI HOMESCREEN.KT TRÊN ANDROID)
@MainActor
public class HomeViewModel: ObservableObject {
    @Published public var user: User
    @Published public var companyId: String
    @Published public var idToken: String

    @Published public var devices: [ThietBi] = []
    @Published public var totalDevicesCount: Int = 0
    @Published public var openTicketsCount: Int = 0
    @Published public var pendingStaffCount: Int = 0
    @Published public var unreadNotificationCount: Int = 0
    @Published public var isLoading: Bool = false

    // Modal đổi mật khẩu
    @Published public var showChangePasswordModal: Bool = false
    @Published public var showOverflowMenu: Bool = false

    public init(user: User, companyId: String, idToken: String) {
        self.user = user
        self.companyId = companyId
        self.idToken = idToken
    }

    // Tải dữ liệu Trang chủ chuẩn 1:1 theo HomeScreen.kt
    public func loadDashboardData() {
        isLoading = true
        Task {
            await fetchDevices()
            await fetchOpenTickets()
            await fetchPendingStaff()
            self.isLoading = false
        }
    }

    // 1. Tải thiết bị: Nếu Admin tải toàn bộ 13 thiết bị, nếu Staff chỉ đếm thiết bị của mình
    private func fetchDevices() async {
        let isFullAccess = user.isAdmin || user.isSuperAdmin || user.isHelpDesk || user.isWarehouse
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/devices?pageSize=100"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return
        }

        let parsedDevices: [ThietBi] = documents.compactMap { doc in
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

        self.devices = parsedDevices

        if isFullAccess {
            // Admin thấy đủ toàn bộ 13 thiết bị
            self.totalDevicesCount = parsedDevices.count
        } else {
            // Staff chỉ đếm thiết bị của mình
            let myEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            self.totalDevicesCount = parsedDevices.filter {
                ($0.createdBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail
            }.count
        }
    }

    // 2. Tải số lượng Ticket đang mở
    private func fetchOpenTickets() async {
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/tickets?pageSize=100"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return
        }

        let openCount = documents.filter { doc in
            guard let fields = doc["fields"] as? [String: Any] else { return false }
            let status = FirestoreHelper.getString(fields["status"] as? [String: Any]).uppercased()
            return status != "CLOSED"
        }.count

        self.openTicketsCount = openCount
    }

    // 3. Tải nhân viên chờ duyệt (Dành cho Admin)
    private func fetchPendingStaff() async {
        guard user.isAdmin || user.isSuperAdmin else { return }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/pending_staff?pageSize=50"
        guard let url = URL(string: urlStr) else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let documents = json["documents"] as? [[String: Any]] else {
            return
        }

        self.pendingStaffCount = documents.count
    }
}
