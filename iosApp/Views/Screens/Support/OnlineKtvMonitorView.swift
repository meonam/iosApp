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

    // Toạ độ GPS nếu có (có thể bổ sung sau khi có location tracking)
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

// MARK: - MÀN HÌNH GIÁM SÁT KTV TRỰC TUYẾN (ĐỒNG BỘ 1:1 VỚI ONLINEKTVMONITORSCREEN.KT TRÊN ANDROID)
public struct OnlineKtvMonitorView: View {
    @ObservedObject var supportVM: SupportViewModel
    var onBack: () -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009),
        span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
    )

    public init(supportVM: SupportViewModel, onBack: @escaping () -> Void) {
        self.supportVM = supportVM
        self.onBack = onBack
    }

    // Lấy các KTV có toạ độ GPS hợp lệ để hiển thị trên bản đồ
    private var ktvsWithLocation: [KtvOnlineLocation] {
        supportVM.ktvTechnicians.filter { $0.latitude != 0 && $0.longitude != 0 }
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
                            Text("Giám sát KTV trực tuyến (\(onlineCount)/\(totalCount))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            // Nút refresh
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

                    // 2. BẢN ĐỒ VỊ TRÍ KTV
                    ZStack(alignment: .bottomTrailing) {
                        if ktvsWithLocation.isEmpty {
                            // Bản đồ trống khi chưa có toạ độ
                            Map(coordinateRegion: $region)
                                .frame(height: 200)
                                .overlay(
                                    VStack(spacing: 6) {
                                        Image(systemName: "map")
                                            .font(.system(size: 28))
                                            .foregroundColor(Color.appTextMuted)
                                        Text("Chưa có dữ liệu vị trí GPS KTV")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextMuted)
                                    }
                                )
                        } else {
                            Map(coordinateRegion: $region, annotationItems: ktvsWithLocation) { ktv in
                                MapAnnotation(coordinate: ktv.coordinate) {
                                    VStack(spacing: 2) {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundColor(ktv.isOnline ? Color.appSuccess : Color.gray)
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
                            .frame(height: 200)
                        }
                    }

                    // 3. THỐNG KÊ NHANH
                    HStack(spacing: 0) {
                        let onlineCount = supportVM.ktvTechnicians.filter { $0.isOnline }.count
                        let offlineCount = supportVM.ktvTechnicians.count - onlineCount

                        statChip(label: "Trực tuyến", count: onlineCount, color: Color.appSuccess)
                        Divider().frame(height: 30)
                        statChip(label: "Ngoại tuyến", count: offlineCount, color: Color.gray)
                        Divider().frame(height: 30)
                        statChip(label: "Tổng KTV", count: supportVM.ktvTechnicians.count, color: Color.appSecondaryDarkBlue)
                    }
                    .padding(.vertical, 10)
                    .background(Color.white)

                    // 4. DANH SÁCH KTV CUỘN
                    if supportVM.isLoadingKtvs {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Đang tải danh sách KTV...")
                                .font(.system(size: 13))
                                .foregroundColor(Color.appTextSecondary)
                        }
                        Spacer()
                    } else if supportVM.ktvTechnicians.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 44))
                                .foregroundColor(Color.appTextMuted)
                            Text("Không tìm thấy KTV nào")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.appTextSecondary)
                            Text("Kiểm tra lại kết nối hoặc phân quyền tài khoản")
                                .font(.system(size: 12))
                                .foregroundColor(Color.appTextMuted)
                                .multilineTextAlignment(.center)
                        }
                        .padding(24)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(supportVM.ktvTechnicians) { ktv in
                                    ktvCard(ktv: ktv)
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
    }

    // MARK: - KTV CARD
    @ViewBuilder
    private func ktvCard(ktv: KtvOnlineLocation) -> some View {
        HStack(spacing: 12) {
            // Avatar icon
            ZStack {
                Circle()
                    .fill(ktv.isOnline ? Color.appSuccess : Color.gray)
                    .frame(width: 42, height: 42)
                Image(systemName: "wrench.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(ktv.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                if !ktv.unitName.isEmpty {
                    Text(ktv.unitName)
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                HStack(spacing: 8) {
                    if !ktv.maNhanVien.isEmpty {
                        Text("MNV: \(ktv.maNhanVien)")
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextMuted)
                    }
                    if !ktv.phone.isEmpty {
                        Text(ktv.phone)
                            .font(.system(size: 10))
                            .foregroundColor(Color.appTextMuted)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(ktv.isOnline ? "TRỰC TUYẾN" : "NGOẠI TUYẾN")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(ktv.isOnline ? Color.appSuccess : Color.gray)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((ktv.isOnline ? Color.appSuccess : Color.gray).opacity(0.12))
                    .cornerRadius(6)

                Text(ktv.lastSeen)
                    .font(.system(size: 10))
                    .foregroundColor(Color.appTextMuted)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    // MARK: - STAT CHIP
    @ViewBuilder
    private func statChip(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
