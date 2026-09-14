import SwiftUI
import UIKit
import CoreLocation

public struct KtvMonitorItem: Identifiable, Hashable {
    public var id: String { email }
    public var email: String
    public var name: String
    public var phone: String
    public var mnv: String
    public var donVi: String
    public var cluster: String // HCM_1, HCM_2, HCM_3, CAN_THO...
    public var isOnline: Bool
    public var lastActiveMinutes: Int
    public var lat: Double
    public var lng: Double
    public var todayShift: String
    public var activeTicketCount: Int
    public var stateDesc: String // Sẵn sàng, Đang xử lý sự cố, Đang di chuyển
}

// MARK: - MÀN HÌNH THEO DÕI KTV ONLINE THỜI GIAN THỰC (OnlineKtvMonitorScreen.kt)
public struct OnlineKtvMonitorFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var searchQuery: String = ""
    @State private var selectedCluster: String = "ALL"
    @State private var filterOnlyOnline: Bool = false
    @State private var selectedKtvForMap: KtvMonitorItem? = nil

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    // Default Tech list matching Android DEFAULT_KTVS
    private var baseKtvList: [KtvMonitorItem] {
        var list: [KtvMonitorItem] = [
            KtvMonitorItem(email: "phucdh@sgcoop.com", name: "Dam Huu Phuc", phone: "0908123456", mnv: "26063", donVi: "IT TẬP TRUNG", cluster: "HCM_1", isOnline: true, lastActiveMinutes: 2, lat: 10.7769, lng: 106.7009, todayShift: "Sáng (06-14h)", activeTicketCount: 2, stateDesc: "Đang xử lý"),
            KtvMonitorItem(email: "huydq@sgcoop.com", name: "Dinh Quoc Huy", phone: "0908234567", mnv: "33430", donVi: "IT TẬP TRUNG", cluster: "HCM_3", isOnline: true, lastActiveMinutes: 5, lat: 10.8231, lng: 106.6297, todayShift: "Sáng (06-14h)", activeTicketCount: 1, stateDesc: "Đang di chuyển"),
            KtvMonitorItem(email: "duchna@sgcoop.com", name: "Huỳnh Nguyễn Anh Đức", phone: "0908345678", mnv: "NVDUCHN", donVi: "Co.opmart Cần Thơ", cluster: "CAN_THO", isOnline: false, lastActiveMinutes: 25, lat: 10.0352, lng: 105.7890, todayShift: "Hành chính", activeTicketCount: 0, stateDesc: "Sẵn sàng"),
            KtvMonitorItem(email: "khanh-ht@sgcoop.com", name: "Hồ Thân Khánh", phone: "0908456789", mnv: "35713", donVi: "IT Bình Dương", cluster: "HCM_BD", isOnline: true, lastActiveMinutes: 1, lat: 10.9804, lng: 106.6745, todayShift: "Sáng (06-14h)", activeTicketCount: 3, stateDesc: "Đang xử lý"),
            KtvMonitorItem(email: "linhnd@sgcoop.com", name: "Ngo Duy Linh", phone: "0908567890", mnv: "43144", donVi: "IT TẬP TRUNG", cluster: "HCM_3", isOnline: false, lastActiveMinutes: 40, lat: 10.8012, lng: 106.6521, todayShift: "Chiều (14-22h)", activeTicketCount: 0, stateDesc: "Chưa vào ca"),
            KtvMonitorItem(email: "sangnt@sgcoop.com", name: "Nguyen Thanh Sang", phone: "0908678901", mnv: "19842", donVi: "IT TẬP TRUNG", cluster: "HCM_3", isOnline: true, lastActiveMinutes: 4, lat: 10.7523, lng: 106.6612, todayShift: "Sáng (06-14h)", activeTicketCount: 1, stateDesc: "Sẵn sàng"),
            KtvMonitorItem(email: "hieunt@sgcoop.com", name: "Nguyễn Trung Hiếu", phone: "0908789012", mnv: "24979", donVi: "HelpDesk", cluster: "HCM_2", isOnline: true, lastActiveMinutes: 3, lat: 10.7891, lng: 106.6892, todayShift: "Trực 24/7", activeTicketCount: 4, stateDesc: "Đang xử lý"),
            KtvMonitorItem(email: "trinhtm@sgcoop.com", name: "Trần Minh Trình", phone: "0908890123", mnv: "8564", donVi: "IT TẬP TRUNG", cluster: "HCM_1", isOnline: true, lastActiveMinutes: 7, lat: 10.7654, lng: 106.6912, todayShift: "Hành chính", activeTicketCount: 0, stateDesc: "Sẵn sàng")
        ]

        // Merge users from Firestore
        for u in firebase.allUsersList {
            let r = u.role.lowercased()
            if (r.contains("ktv") || r.contains("tech") || r.contains("it")) && !list.contains(where: { $0.email == u.email }) {
                list.append(KtvMonitorItem(
                    email: u.email,
                    name: u.fullName,
                    phone: u.phone.isEmpty ? "0901234567" : u.phone,
                    mnv: u.maNhanVien.isEmpty ? "NV001" : u.maNhanVien,
                    donVi: u.donVi.isEmpty ? "Co.opmart" : u.donVi,
                    cluster: "HCM_1",
                    isOnline: u.isOnline,
                    lastActiveMinutes: u.isOnline ? 1 : 45,
                    lat: 10.7769,
                    lng: 106.7009,
                    todayShift: "Sáng (06-14h)",
                    activeTicketCount: 0,
                    stateDesc: u.isOnline ? "Sẵn sàng" : "Offline"
                ))
            }
        }
        return list
    }

    var filteredKtvs: [KtvMonitorItem] {
        baseKtvList.filter { k in
            let matchSearch = searchQuery.isEmpty ||
                k.name.localizedCaseInsensitiveContains(searchQuery) ||
                k.mnv.localizedCaseInsensitiveContains(searchQuery) ||
                k.donVi.localizedCaseInsensitiveContains(searchQuery)
            let matchCluster = selectedCluster == "ALL" || k.cluster == selectedCluster
            let matchOnline = !filterOnlyOnline || k.isOnline
            return matchSearch && matchCluster && matchOnline
        }
    }

    var onlineCount: Int { baseKtvList.filter { $0.isOnline }.count }
    var busyCount: Int { baseKtvList.filter { $0.stateDesc.contains("xử lý") }.count }
    var readyCount: Int { baseKtvList.filter { $0.isOnline && $0.stateDesc.contains("Sẵn sàng") }.count }

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 1. KPI Summary Header
                HStack(spacing: 10) {
                    kpiPill(title: "Tổng số KTV", value: "\(baseKtvList.count)", color: .appSecondaryDarkBlue)
                    kpiPill(title: "Trực tuyến", value: "\(onlineCount)", color: .statusInUse)
                    kpiPill(title: "Đang xử lý", value: "\(busyCount)", color: .statusRepair)
                    kpiPill(title: "Sẵn sàng", value: "\(readyCount)", color: .statusNew)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))

                // 2. Search & Cluster Filter
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Tìm KTV, mã NV, địa bàn...", text: $searchQuery)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            clusterChip("Tất cả", code: "ALL")
                            clusterChip("Cụm HCM 1", code: "HCM_1")
                            clusterChip("Cụm HCM 2", code: "HCM_2")
                            clusterChip("Cụm HCM 3", code: "HCM_3")
                            clusterChip("Bình Dương", code: "HCM_BD")
                            clusterChip("Cần Thơ", code: "CAN_THO")
                        }
                    }
                }
                .padding(12)

                // 3. KTV Card List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredKtvs) { ktv in
                            ktvCard(ktv)
                        }
                    }
                    .padding(12)
                }
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Giám Sát KTV Online")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng", action: onDismiss)
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .sheet(item: $selectedKtvForMap) { ktv in
                LiveTrackingMapView(
                    destinationName: ktv.donVi,
                    destLat: ktv.lat,
                    destLng: ktv.lng,
                    ticketCode: "GPS-\(ktv.mnv)"
                )
            }
        }
        .navigationViewStyle(.stack)
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

    // MARK: - KTV Card Item
    @ViewBuilder
    private func ktvCard(_ ktv: KtvMonitorItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Avatar with online dot
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.appSecondaryDarkBlue.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Text(ktv.name.prefix(2).uppercased())
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.appSecondaryDarkBlue)

                    Circle()
                        .fill(ktv.isOnline ? Color.statusInUse : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ktv.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.appTextPrimary)
                        Text("(\(ktv.mnv))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.appPrimaryPink)
                    }

                    Text(ktv.donVi)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ktv.isOnline ? "TRỰC TUYẾN" : "OFFLINE")
                        .font(.system(size: 9.5, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ktv.isOnline ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                        .foregroundColor(ktv.isOnline ? .green : .gray)
                        .clipShape(Capsule())

                    Text(ktv.isOnline ? "Vừa xong" : "\(ktv.lastActiveMinutes)p trước")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            HStack(spacing: 8) {
                // Shift badge
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("Ca: \(ktv.todayShift)")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // State badge
                Text(ktv.stateDesc)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stateColor(ktv.stateDesc).opacity(0.12))
                    .foregroundColor(stateColor(ktv.stateDesc))
                    .clipShape(Capsule())
            }

            Divider()

            // Action Buttons
            HStack(spacing: 10) {
                if let phoneUrl = URL(string: "tel://\(ktv.phone)") {
                    Link(destination: phoneUrl) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                            Text("Gọi")
                        }
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                }

                Button(action: {
                    selectedKtvForMap = ktv
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                        Text("Vị trí GPS")
                    }
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.appSecondaryDarkBlue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func stateColor(_ desc: String) -> Color {
        if desc.contains("xử lý") { return .appPrimaryPink }
        if desc.contains("di chuyển") { return .orange }
        if desc.contains("Sẵn sàng") { return .statusInUse }
        return .gray
    }
}
