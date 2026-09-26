import SwiftUI
import UIKit
import CoreLocation

// MARK: - KtvMonitorItem (maps from UserItem + live online data)
public struct KtvMonitorItem: Identifiable, Hashable {
    public var id: String { email }
    public var email: String
    public var name: String
    public var phone: String
    public var mnv: String
    public var donVi: String
    public var cluster: String // maKhuVuc field
    public var isOnline: Bool
    public var isReallyOnline: Bool // isOnline AND lastActive < 15 min
    public var lastActiveMinutes: Int // minutes since lastActiveAt
    public var todayShift: String
    public var activeTicketCount: Int
    public var stateDesc: String
    public var offlineViolationsCount: Int
    public var isBlacklisted: Bool
    public var lastActiveAt: Int64  // epoch ms from Firestore
}

// MARK: - MÀN HÌNH THEO DÕI KTV ONLINE THỜI GIAN THỰC
// Mirrors: OnlineKtvMonitorScreen.kt (1,174 lines)
public struct OnlineKtvMonitorFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 0   // 0 = Trạng thái, 1 = Vi phạm
    @State private var searchQuery: String = ""
    @State private var selectedCluster: String = "ALL"
    @State private var filterOnlyOnline: Bool = false
    @State private var isLoading: Bool = false
    // Live online data from Firestore users collection
    @State private var liveUserOnlineMap: [String: (isOnline: Bool, lastActiveAt: Int64)] = [:]
    @State private var refreshTimer: Timer? = nil

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    // MARK: - Build KtvMonitorItem list from allUsersList + live online map
    private var allKtvs: [KtvMonitorItem] {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let threshold: Int64 = 15 * 60 * 1000 // 15 minutes in ms

        return firebase.allUsersList.compactMap { u in
            let r = u.role.lowercased()
            // Only KTV / Technician / IT roles
            guard r.contains("ktv") || r.contains("tech") || r.contains("kỹ thuật") ||
                  r.contains("it ") || r == "it" || r.contains("nhân viên it") ||
                  r.contains("technician") else { return nil }

            let liveData = liveUserOnlineMap[u.email]
            let rawOnline = liveData?.isOnline ?? u.isOnline
            let lastActive = liveData?.lastActiveAt ?? 0
            let minAgo = lastActive > 0 ? Int((nowMs - lastActive) / 60000) : (rawOnline ? 1 : 999)
            let isReallyOnline = rawOnline && (lastActive == 0 || (nowMs - lastActive) < threshold)

            let stateDesc: String
            if !isReallyOnline {
                stateDesc = minAgo < 30 ? "Vừa offline" : "Offline"
            } else if minAgo <= 2 {
                stateDesc = "Đang hoạt động"
            } else {
                stateDesc = "Sẵn sàng"
            }

            return KtvMonitorItem(
                email: u.email,
                name: u.fullName.isEmpty ? u.email : u.fullName,
                phone: u.phone.isEmpty ? "N/A" : u.phone,
                mnv: u.maNhanVien.isEmpty ? lookupStandardKtvMnv(u.email, u.fullName) : u.maNhanVien,
                donVi: u.donVi.isEmpty ? "IT Tập trung" : u.donVi,
                cluster: u.maKhuVuc.isEmpty ? "HCM" : u.maKhuVuc,
                isOnline: rawOnline,
                isReallyOnline: isReallyOnline,
                lastActiveMinutes: max(0, minAgo),
                todayShift: "N/A",
                activeTicketCount: 0,
                stateDesc: stateDesc,
                offlineViolationsCount: 0,
                isBlacklisted: false,
                lastActiveAt: lastActive
            )
        }
    }

    var filteredKtvs: [KtvMonitorItem] {
        allKtvs.filter { k in
            let matchSearch = searchQuery.isEmpty ||
                k.name.localizedCaseInsensitiveContains(searchQuery) ||
                k.mnv.localizedCaseInsensitiveContains(searchQuery) ||
                k.donVi.localizedCaseInsensitiveContains(searchQuery)
            let matchCluster = selectedCluster == "ALL" || k.cluster == selectedCluster
            let matchOnline = !filterOnlyOnline || k.isReallyOnline
            return matchSearch && matchCluster && matchOnline
        }
    }

    // Violation list: KTVs with offline violations OR blacklisted
    var violationKtvs: [KtvMonitorItem] {
        allKtvs.filter { $0.offlineViolationsCount > 0 || $0.isBlacklisted }
            .sorted { $0.offlineViolationsCount > $1.offlineViolationsCount }
    }

    var onlineCount: Int { allKtvs.filter { $0.isReallyOnline }.count }
    var offlineCount: Int { allKtvs.filter { !$0.isReallyOnline }.count }
    var totalCount: Int { allKtvs.count }

    // Unique clusters for chips
    var allClusters: [String] {
        let cls = Set(allKtvs.map { $0.cluster }).filter { !$0.isEmpty && $0 != "ALL" }
        return cls.sorted()
    }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // KPI Header
                kpiHeader

                // Tab Selector
                tabSelector

                if isLoading && allKtvs.isEmpty {
                    Spacer()
                    ProgressView("Đang tải dữ liệu KTV...")
                        .foregroundColor(.secondary)
                    Spacer()
                } else if selectedTab == 0 {
                    // Tab 0: Online Status
                    statusTab
                } else {
                    // Tab 1: Violations
                    violationTab
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Giám Sát KTV Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { Task { await loadLiveData() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .disabled(isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .onAppear {
                Task { await loadLiveData() }
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - KPI Header
    private var kpiHeader: some View {
        HStack(spacing: 8) {
            kpiPill(title: "Tổng KTV", value: "\(totalCount)", color: .appSecondaryDarkBlue)
            kpiPill(title: "Trực tuyến", value: "\(onlineCount)", color: .statusInUse)
            kpiPill(title: "Offline", value: "\(offlineCount)", color: .gray)
            if !violationKtvs.isEmpty {
                kpiPill(title: "Vi phạm", value: "\(violationKtvs.count)", color: .appPrimaryPink)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
    }

    // MARK: - Tab Selector
    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "Trạng Thái Online", index: 0)
            tabButton(title: "Vi Phạm (\(violationKtvs.count))", index: 1)
        }
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: selectedTab == index ? .bold : .medium))
                    .foregroundColor(selectedTab == index ? .appSecondaryDarkBlue : .secondary)
                    .padding(.top, 10)
                Rectangle()
                    .fill(selectedTab == index ? Color.appSecondaryDarkBlue : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab 0: Status Tab
    private var statusTab: some View {
        VStack(spacing: 0) {
            // Search + Filter
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField("Tìm KTV, mã NV, đơn vị...", text: $searchQuery)
                            .font(.system(size: 13))
                    }
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))

                    Toggle(isOn: $filterOnlyOnline) {
                        Text("Chỉ Online")
                            .font(.caption.bold())
                            .foregroundColor(.appSecondaryDarkBlue)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .appSecondaryDarkBlue))
                    .frame(width: 120)
                }

                // Cluster Filter Chips
                if !allClusters.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            clusterChip("Tất cả", code: "ALL")
                            ForEach(allClusters, id: \.self) { cl in
                                clusterChip(cl, code: cl)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .padding(12)

            if filteredKtvs.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(filterOnlyOnline ? "Không có KTV trực tuyến" : "Không tìm thấy KTV")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredKtvs) { ktv in
                            ktvStatusCard(ktv)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Tab 1: Violations Tab
    private var violationTab: some View {
        Group {
            if violationKtvs.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.statusInUse)
                    Text("Không có vi phạm")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tất cả KTV chấp hành nghiêm túc")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(violationKtvs) { ktv in
                            ktvViolationCard(ktv)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - KTV Status Card
    @ViewBuilder
    private func ktvStatusCard(_ ktv: KtvMonitorItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar + online dot
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.appSecondaryDarkBlue.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Text(String(ktv.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.appSecondaryDarkBlue)

                    Circle()
                        .fill(ktv.isReallyOnline ? Color.statusInUse : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(ktv.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        if !ktv.mnv.isEmpty {
                            Text("(\(ktv.mnv))")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.appPrimaryPink)
                        }
                    }
                    Text(ktv.donVi)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if !ktv.cluster.isEmpty {
                        Text("Cụm: \(ktv.cluster)")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ktv.isReallyOnline ? "TRỰC TUYẾN" : "OFFLINE")
                        .font(.system(size: 9.5, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background((ktv.isReallyOnline ? Color.statusInUse : Color.gray).opacity(0.12))
                        .foregroundColor(ktv.isReallyOnline ? .statusInUse : .gray)
                        .clipShape(Capsule())

                    Text(ktv.lastActiveMinutes == 0 ? "Vừa xong" :
                         ktv.lastActiveMinutes < 60 ? "\(ktv.lastActiveMinutes)p trước" :
                         "\(ktv.lastActiveMinutes / 60)h trước")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "phone.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ktv.phone)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Spacer()

                Text(ktv.stateDesc)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stateColor(ktv.stateDesc).opacity(0.12))
                    .foregroundColor(stateColor(ktv.stateDesc))
                    .clipShape(Capsule())
            }

            // Call button
            if let phoneUrl = URL(string: "tel://\(ktv.phone.filter { $0.isNumber })"),
               !ktv.phone.isEmpty && ktv.phone != "N/A" {
                Divider()
                Link(destination: phoneUrl) {
                    HStack(spacing: 4) {
                        Image(systemName: "phone.fill")
                        Text("Gọi điện \(ktv.phone)")
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.statusInUse.opacity(0.10))
                    .foregroundColor(.statusInUse)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            ktv.isReallyOnline ? Color.statusInUse.opacity(0.3) : Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - KTV Violation Card
    @ViewBuilder
    private func ktvViolationCard(_ ktv: KtvMonitorItem) -> some View {
        HStack(spacing: 14) {
            // Red avatar
            ZStack {
                Circle()
                    .fill(Color.appPrimaryPink.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text(String(ktv.name.prefix(1)).uppercased())
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.appPrimaryPink)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ktv.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.appTextPrimary)
                Text(ktv.donVi)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    if ktv.isBlacklisted {
                        Label("Danh sách đen", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .clipShape(Capsule())
                    }
                    if ktv.offlineViolationsCount > 0 {
                        Text("Vi phạm: \(ktv.offlineViolationsCount) lần")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.appPrimaryPink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appPrimaryPink.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ktv.isReallyOnline ? "ONLINE" : "OFFLINE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(ktv.isReallyOnline ? .statusInUse : .gray)

                if let phoneUrl = URL(string: "tel://\(ktv.phone.filter { $0.isNumber })"),
                   !ktv.phone.isEmpty && ktv.phone != "N/A" {
                    Link(destination: phoneUrl) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 13))
                            .padding(8)
                            .background(Color.statusInUse.opacity(0.10))
                            .foregroundColor(.statusInUse)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appPrimaryPink.opacity(0.25), lineWidth: 1))
    }

    // MARK: - KPI Pill
    private func kpiPill(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(8)
    }

    // MARK: - Cluster Chip
    private func clusterChip(_ title: String, code: String) -> some View {
        Button(action: { selectedCluster = code }) {
            Text(title)
                .font(.system(size: 11.5, weight: selectedCluster == code ? .bold : .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selectedCluster == code ? Color.appSecondaryDarkBlue : Color.white)
                .foregroundColor(selectedCluster == code ? .white : .primary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.appCardBorder, lineWidth: 0.8))
        }
    }

    // MARK: - State Color
    private func stateColor(_ desc: String) -> Color {
        if desc.contains("xử lý") { return .appPrimaryPink }
        if desc.contains("di chuyển") { return .orange }
        if desc.contains("Sẵn sàng") || desc.contains("hoạt động") { return .statusInUse }
        return .gray
    }

    // MARK: - Load Live Online Data from Firestore users collection
    func loadLiveData() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // Refresh allUsersList if empty
        if firebase.allUsersList.isEmpty {
            await firebase.fetchAllUsers()
        }

        // Also fetch live online status from Firestore users
        // Uses companies/{companyId}/users with pageSize=200
        let urlStr = "https://firestore.googleapis.com/v1/projects/\(firebase.projectId)/databases/(default)/documents/companies/\(firebase.companyId)/users?pageSize=200"
        guard let url = URL(string: urlStr) else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(firebase.currentUserIdToken)", forHTTPHeaderField: "Authorization")

        guard let (data, res) = try? await URLSession.shared.data(for: req),
              let httpRes = res as? HTTPURLResponse, httpRes.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["documents"] as? [[String: Any]] else { return }

        var map: [String: (isOnline: Bool, lastActiveAt: Int64)] = [:]
        for d in docs {
            let docId = (d["name"] as? String ?? "").components(separatedBy: "/").last ?? ""
            let f = d["fields"] as? [String: Any] ?? [:]
            let online = (f["isOnline"] as? [String: Any])?["booleanValue"] as? Bool ?? false
            let lastActive = Int64((f["lastActiveAt"] as? [String: Any])?["integerValue"] as? String ?? "0") ?? 0
            map[docId] = (isOnline: online, lastActiveAt: lastActive)
        }

        await MainActor.run {
            self.liveUserOnlineMap = map
        }
    }
}
