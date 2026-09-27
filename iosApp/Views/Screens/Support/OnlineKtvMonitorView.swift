import SwiftUI
import MapKit

// MARK: - MODEL KTV (ĐỒNG BỘ 1:1 VỚI TECHNICIANSTATUS DATA CLASS TRONG ONLINEKTVMONITORSCREEN.KT)
public struct KtvOnlineLocation: Identifiable {
    public var id: String { email.isEmpty ? UUID().uuidString : email }
    public var name: String
    public var email: String
    public var maNhanVien: String
    public var phone: String
    public var maKhuVuc: String
    public var unitName: String
    public var isOnline: Bool
    public var lastSeen: String
    public var lastActiveAt: Int64
    public var latitude: Double
    public var longitude: Double

    public init(
        name: String,
        email: String,
        maNhanVien: String = "",
        phone: String = "",
        maKhuVuc: String = "",
        unitName: String = "",
        isOnline: Bool = false,
        lastSeen: String = "Không rõ",
        lastActiveAt: Int64 = 0,
        latitude: Double = 0,
        longitude: Double = 0
    ) {
        self.name = name
        self.email = email
        self.maNhanVien = maNhanVien
        self.phone = phone
        self.maKhuVuc = maKhuVuc
        self.unitName = unitName
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.lastActiveAt = lastActiveAt
        self.latitude = latitude
        self.longitude = longitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - MÀN HÌNH GIÁM SÁT KTV TRỰC TUYẾN
public struct OnlineKtvMonitorView: View {
    @ObservedObject var supportVM: SupportViewModel
    var onBack: () -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // Real-time polling
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Filters
    @State private var selectedRegion: String = "Tất cả"
    @State private var selectedUnit: String = "Tất cả"
    @State private var selectedStatus: String = "Tất cả" // "Tất cả", "Trực tuyến", "Ngoại tuyến"

    // Bottom sheet
    @State private var selectedKtv: KtvOnlineLocation? = nil
    
    public init(supportVM: SupportViewModel, onBack: @escaping () -> Void) {
        self.supportVM = supportVM
        self.onBack = onBack
    }

    private var regions: [String] {
        let list = Set(supportVM.ktvTechnicians.map { $0.maKhuVuc }).filter { !$0.isEmpty }.sorted()
        return ["Tất cả"] + list
    }

    private var units: [String] {
        let list = Set(supportVM.ktvTechnicians.map { $0.unitName }).filter { !$0.isEmpty }.sorted()
        return ["Tất cả"] + list
    }

    private var filteredKtvs: [KtvOnlineLocation] {
        supportVM.ktvTechnicians.filter { ktv in
            let matchRegion = selectedRegion == "Tất cả" || ktv.maKhuVuc == selectedRegion
            let matchUnit = selectedUnit == "Tất cả" || ktv.unitName == selectedUnit
            let matchStatus: Bool
            if selectedStatus == "Trực tuyến" { matchStatus = ktv.isOnline }
            else if selectedStatus == "Ngoại tuyến" { matchStatus = !ktv.isOnline }
            else { matchStatus = true }
            return matchRegion && matchUnit && matchStatus
        }
    }

    private var ktvsWithLocation: [KtvOnlineLocation] {
        filteredKtvs.filter { $0.latitude != 0 && $0.longitude != 0 }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            let onlineCount = supportVM.ktvTechnicians.filter { $0.isOnline }.count
                            let totalCount = supportVM.ktvTechnicians.count
                            Text("Giám sát KTV (\(onlineCount)/\(totalCount))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { supportVM.fetchKtvTechnicians() }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. Map View
                    ZStack(alignment: .bottomTrailing) {
                        if ktvsWithLocation.isEmpty {
                            Map(coordinateRegion: $region)
                                .frame(height: 250)
                                .overlay(
                                    VStack(spacing: 6) {
                                        Image(systemName: "map")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.gray)
                                        Text("Không có toạ độ KTV trong danh sách lọc")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.gray)
                                    }
                                    .padding()
                                    .background(Color.white.opacity(0.8))
                                    .cornerRadius(8)
                                )
                        } else {
                            Map(coordinateRegion: $region, annotationItems: ktvsWithLocation) { ktv in
                                MapAnnotation(coordinate: ktv.coordinate) {
                                    Button(action: { selectedKtv = ktv }) {
                                        VStack(spacing: 2) {
                                            Image(systemName: "person.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(ktv.isOnline ? .green : .gray)
                                                .background(Circle().fill(Color.white))
                                            Text(ktv.name)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.85))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            .frame(height: 250)
                        }
                    }

                    // 3. Filters
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            filterPicker(title: "Trạng thái", selection: $selectedStatus, options: ["Tất cả", "Trực tuyến", "Ngoại tuyến"])
                            filterPicker(title: "Khu vực", selection: $selectedRegion, options: regions)
                            filterPicker(title: "Đơn vị", selection: $selectedUnit, options: units)
                        }
                        .padding(10)
                    }
                    .background(Color.white)
                    Divider()

                    // 4. KTV List
                    if supportVM.isLoadingKtvs && supportVM.ktvTechnicians.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Đang tải danh sách KTV...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else if filteredKtvs.isEmpty {
                        Spacer()
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44))
                            .foregroundColor(.gray)
                        Text("Không tìm thấy KTV nào")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredKtvs) { ktv in
                                    Button(action: { selectedKtv = ktv }) {
                                        ktvCard(ktv: ktv)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(14)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            supportVM.fetchKtvTechnicians()
        }
        .onReceive(timer) { _ in
            supportVM.fetchKtvTechnicians()
        }
        .sheet(item: $selectedKtv) { ktv in
            KtvDetailSheet(ktv: ktv, supportVM: supportVM)
        }
    }

    @ViewBuilder
    private func filterPicker(title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { selection.wrappedValue = option }) {
                    HStack {
                        Text(option)
                        if selection.wrappedValue == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(title): \(selection.wrappedValue)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.appPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.appPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appPrimary.opacity(0.1))
            .cornerRadius(16)
        }
    }

    @ViewBuilder
    private func ktvCard(ktv: KtvOnlineLocation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ktv.isOnline ? Color.green : Color.gray)
                    .frame(width: 42, height: 42)
                Image(systemName: "wrench.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(ktv.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                if !ktv.unitName.isEmpty {
                    Text(ktv.unitName)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                HStack(spacing: 8) {
                    if !ktv.maNhanVien.isEmpty {
                        Text("MNV: \(ktv.maNhanVien)")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    if !ktv.maKhuVuc.isEmpty {
                        Text("KV: \(ktv.maKhuVuc)")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(ktv.isOnline ? "TRỰC TUYẾN" : "NGOẠI TUYẾN")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(ktv.isOnline ? .green : .gray)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((ktv.isOnline ? Color.green : Color.gray).opacity(0.12))
                    .cornerRadius(6)
                Text(ktv.lastSeen)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - KTV Detail Sheet
struct KtvDetailSheet: View {
    let ktv: KtvOnlineLocation
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var supportVM: SupportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header handle
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            HStack {
                ZStack {
                    Circle()
                        .fill(ktv.isOnline ? Color.green : Color.gray)
                        .frame(width: 60, height: 60)
                    Image(systemName: "person.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                .padding(.trailing, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(ktv.name)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(ktv.isOnline ? "Đang trực tuyến" : "Ngoại tuyến (\(ktv.lastSeen))")
                        .font(.system(size: 14))
                        .foregroundColor(ktv.isOnline ? .green : .gray)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            Divider()

            VStack(spacing: 16) {
                detailRow(icon: "creditcard", title: "Mã nhân viên", value: ktv.maNhanVien.isEmpty ? "Chưa cập nhật" : ktv.maNhanVien)
                detailRow(icon: "envelope", title: "Email", value: ktv.email)
                detailRow(icon: "phone", title: "Số điện thoại", value: ktv.phone.isEmpty ? "Chưa cập nhật" : ktv.phone)
                detailRow(icon: "building.2", title: "Đơn vị", value: ktv.unitName.isEmpty ? "Chưa cập nhật" : ktv.unitName)
                detailRow(icon: "mappin.and.ellipse", title: "Khu vực", value: ktv.maKhuVuc.isEmpty ? "Chưa cập nhật" : ktv.maKhuVuc)
            }
            .padding(24)

            Spacer()

            HStack(spacing: 16) {
                Button(action: { callKtv() }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Gọi điện")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ktv.phone.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(12)
                }
                .disabled(ktv.phone.isEmpty)

                Button(action: { routeToKtv() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Chỉ đường")
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background((ktv.latitude == 0 && ktv.longitude == 0) ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .disabled(ktv.latitude == 0 && ktv.longitude == 0)
            }
            .padding(24)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
        }
    }
    
    private func callKtv() {
        if let url = URL(string: "tel://\(ktv.phone)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func routeToKtv() {
        let urlStr = "maps://?daddr=\(ktv.latitude),\(ktv.longitude)"
        if let url = URL(string: urlStr), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}


