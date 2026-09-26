import SwiftUI
import MapKit

// MARK: - MÀN HÌNH GIÁM SÁT KTV TRỰC TUYẾN (ĐỒNG BỘ 1:1 THEO ONLINEKTVMONITORSCREEN.KT TRÊN ANDROID)
public struct KtvOnlineLocation: Identifiable {
    public var id: String { email }
    public var name: String
    public var email: String
    public var latitude: Double
    public var longitude: Double
    public var unitName: String
    public var isOnline: Bool
    public var lastSeen: String

    public init(name: String, email: String, latitude: Double, longitude: Double, unitName: String, isOnline: Bool = true, lastSeen: String = "Vừa xong") {
        self.name = name
        self.email = email
        self.latitude = latitude
        self.longitude = longitude
        self.unitName = unitName
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct OnlineKtvMonitorView: View {
    var onBack: () -> Void

    @State private var ktvs: [KtvOnlineLocation] = [
        KtvOnlineLocation(name: "Nguyễn Văn Kỹ Thuật", email: "ktv01@sgcoop.com", latitude: 10.0342, longitude: 105.7876, unitName: "Co.opmart Cần Thơ", isOnline: true),
        KtvOnlineLocation(name: "Trần Minh Trí", email: "ktv02@sgcoop.com", latitude: 9.7844, longitude: 105.4711, unitName: "Co.opmart Hậu Giang", isOnline: true),
        KtvOnlineLocation(name: "Lê Hoàng Phúc", email: "ktv03@sgcoop.com", latitude: 10.7681, longitude: 106.6896, unitName: "Co.opmart Cống Quỳnh", isOnline: false, lastSeen: "15 phút trước"),
        KtvOnlineLocation(name: "Phạm Quốc Toàn", email: "ktv04@sgcoop.com", latitude: 10.7825, longitude: 106.6912, unitName: "Văn phòng SGCOOP", isOnline: true)
    ]

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10.0342, longitude: 105.7876),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )

    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
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

                            Text("Giám sát KTV trực tuyến (\(ktvs.filter { $0.isOnline }.count)/\(ktvs.count))")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    // 2. BẢN ĐỒ VỊ TRÍ KTV
                    Map(coordinateRegion: $region, annotationItems: ktvs) { ktv in
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
                    .frame(height: 260)

                    // 3. DANH SÁCH KTV CUỘN
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(ktvs) { ktv in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(ktv.isOnline ? Color.appSuccess : Color.gray)
                                            .frame(width: 38, height: 38)
                                        Image(systemName: "wrench.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(ktv.name)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(Color.appTextPrimary)

                                        Text(ktv.unitName)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.appTextSecondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text(ktv.isOnline ? "TRỰC TUYẾN" : "NGOẠI TUYẾN")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(ktv.isOnline ? Color.appSuccess : Color.gray)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
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
                        }
                        .padding(14)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}
