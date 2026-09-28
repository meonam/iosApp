import SwiftUI
import MapKit
import CoreLocation

// MARK: - ANNOTATION MODELS FOR MAPKIT
enum CustomPinType {
    case destination
    case mainTech
    case coTech
    case startPoint
}

class CustomMapPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let pinType: CustomPinType
    let isSpecialist: Bool
    let isGpsLost: Bool

    init(
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String?,
        pinType: CustomPinType,
        isSpecialist: Bool = false,
        isGpsLost: Bool = false
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.pinType = pinType
        self.isSpecialist = isSpecialist
        self.isGpsLost = isGpsLost
    }
}

// MARK: - DEVICE LOCATION PROVIDER (LẤY GPS THỰC TẾ CỦA KTV TRÁNH NHẢY VỀ TỌA ĐỘ MẶC ĐỊNH)
class DeviceLocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var lastLocation: CLLocationCoordinate2D? = nil

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            DispatchQueue.main.async {
                self.lastLocation = loc.coordinate
            }
        }
    }
}

// MARK: - NATIVE MAPKIT VIEW WITH ROUTE & CUSTOM PINS (ĐỒNG BỘ 1:1 ANDROID LIVETRACKINGMAP)
struct LiveTrackingMKMapView: UIViewRepresentable {
    var techCoord: CLLocationCoordinate2D?
    var destCoord: CLLocationCoordinate2D?
    var startCoord: CLLocationCoordinate2D?
    var destName: String
    var techName: String
    var isSpecialist: Bool
    var isEnRoute: Bool
    var isGpsLost: Bool
    var roadCoordinates: [[Double]]
    var collaboratorTrackings: [String: TicketTracking]
    var arrivalRadiusMeters: Double
    @Binding var recenterTrigger: Int
    @Binding var fitBoundsTrigger: Int
    @Binding var zoomTrigger: Int // +1 for zoom in, -1 for zoom out

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.mapType = .standard
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // 1. Cập nhật các Annotations
        uiView.removeAnnotations(uiView.annotations)
        var annotationsToAdd: [MKAnnotation] = []

        // Điểm đến
        if let dest = destCoord, dest.latitude != 0, dest.longitude != 0 {
            let destPin = CustomMapPin(
                coordinate: dest,
                title: destName.isEmpty ? "Điểm hỗ trợ" : destName,
                subtitle: "Điểm đến",
                pinType: .destination
            )
            annotationsToAdd.append(destPin)
        }

        // Điểm xuất phát (Start Point A)
        if let start = startCoord, start.latitude != 0, start.longitude != 0 {
            let startPin = CustomMapPin(
                coordinate: start,
                title: "Điểm xuất phát",
                subtitle: "Khởi hành",
                pinType: .startPoint
            )
            annotationsToAdd.append(startPin)
        }

        // KTV / Chuyên viên chính
        if let tech = techCoord, tech.latitude != 0, tech.longitude != 0 {
            let roleTitle = isSpecialist ? "Chuyên viên" : "KTV"
            let techPin = CustomMapPin(
                coordinate: tech,
                title: techName.isEmpty ? roleTitle : techName,
                subtitle: isEnRoute ? "Đang di chuyển" : "Vị trí",
                pinType: .mainTech,
                isSpecialist: isSpecialist,
                isGpsLost: isGpsLost
            )
            annotationsToAdd.append(techPin)
        }

        // KTV / Chuyên viên Phối Hợp (Collaborators)
        for (_, coTracking) in collaboratorTrackings {
            if coTracking.currentLat != 0 && coTracking.currentLng != 0 {
                let coPin = CustomMapPin(
                    coordinate: CLLocationCoordinate2D(latitude: coTracking.currentLat, longitude: coTracking.currentLng),
                    title: coTracking.technicianName.isEmpty ? "Phối hợp" : coTracking.technicianName,
                    subtitle: coTracking.status == "ARRIVED" ? "Đã đến nơi" : "Đang phối hợp",
                    pinType: .coTech,
                    isGpsLost: coTracking.isGpsLost
                )
                annotationsToAdd.append(coPin)
            }
        }

        uiView.addAnnotations(annotationsToAdd)

        // 2. Cập nhật Overlays (Bán kính đến nơi + Tuyến đường thực tế OSRM)
        uiView.removeOverlays(uiView.overlays)

        // Vùng tròn bán kính xác nhận đến nơi
        if let dest = destCoord, dest.latitude != 0, dest.longitude != 0 {
            let circle = MKCircle(center: dest, radius: arrivalRadiusMeters)
            uiView.addOverlay(circle, level: .aboveRoads)
        }

        // Tuyến đường KTV / Chuyên viên chính
        if roadCoordinates.count >= 2 {
            var coords = roadCoordinates.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
            let polyline = MKPolyline(coordinates: &coords, count: coords.count)
            polyline.title = "MainRoute"
            uiView.addOverlay(polyline, level: .aboveRoads)
        } else if let tech = techCoord, let dest = destCoord,
                  tech.latitude != 0, tech.longitude != 0,
                  dest.latitude != 0, dest.longitude != 0 {
            var coords = [tech, dest]
            let polyline = MKPolyline(coordinates: &coords, count: 2)
            polyline.title = "MainRoute"
            uiView.addOverlay(polyline, level: .aboveRoads)
        }

        // Tuyến đường của KTV / Chuyên viên phối hợp
        for (_, coTracking) in collaboratorTrackings {
            let coCoords = coTracking.routeCoordinates
            if coCoords.count >= 2 {
                var coords = coCoords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
                let polyline = MKPolyline(coordinates: &coords, count: coords.count)
                polyline.title = "CoTechRoute"
                uiView.addOverlay(polyline, level: .aboveRoads)
            }
        }

        // 3. Xử lý các Trigger nút bấm
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            if let tech = techCoord, tech.latitude != 0, tech.longitude != 0 {
                let region = MKCoordinateRegion(center: tech, latitudinalMeters: 800, longitudinalMeters: 800)
                uiView.setRegion(region, animated: true)
            }
        }

        if context.coordinator.lastFitBoundsTrigger != fitBoundsTrigger {
            context.coordinator.lastFitBoundsTrigger = fitBoundsTrigger
            if !annotationsToAdd.isEmpty {
                uiView.showAnnotations(annotationsToAdd, animated: true)
            }
        }

        if context.coordinator.lastZoomTrigger != zoomTrigger {
            let diff = zoomTrigger - context.coordinator.lastZoomTrigger
            context.coordinator.lastZoomTrigger = zoomTrigger
            var region = uiView.region
            if diff > 0 {
                region.span.latitudeDelta /= 2.0
                region.span.longitudeDelta /= 2.0
            } else if diff < 0 {
                region.span.latitudeDelta = min(region.span.latitudeDelta * 2.0, 180.0)
                region.span.longitudeDelta = min(region.span.longitudeDelta * 2.0, 180.0)
            }
            uiView.setRegion(region, animated: true)
        }

        // Lần đầu mở: Tự động fit bounds
        if !context.coordinator.hasInitializedBounds && !annotationsToAdd.isEmpty {
            context.coordinator.hasInitializedBounds = true
            if annotationsToAdd.count == 1, let single = annotationsToAdd.first {
                let region = MKCoordinateRegion(center: single.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                uiView.setRegion(region, animated: false)
            } else {
                uiView.showAnnotations(annotationsToAdd, animated: false)
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LiveTrackingMKMapView
        var hasInitializedBounds = false
        var lastRecenterTrigger = 0
        var lastFitBoundsTrigger = 0
        var lastZoomTrigger = 0

        init(_ parent: LiveTrackingMKMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let customPin = annotation as? CustomMapPin else { return nil }

            let identifier: String
            switch customPin.pinType {
            case .destination: identifier = "DestPin"
            case .startPoint: identifier = "StartPin"
            case .mainTech: identifier = "MainTechPin"
            case .coTech: identifier = "CoTechPin"
            }

            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: customPin, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = customPin
            }

            view?.subviews.forEach { $0.removeFromSuperview() }

            switch customPin.pinType {
            case .destination:
                let hosting = UIHostingController(
                    rootView: VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text("📍")
                                .font(.system(size: 11))
                            Text(customPin.title ?? "Điểm đến")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#DC2626"))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#EF4444"), lineWidth: 1.5))

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: "#DC2626"))
                            .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 170, height: 52)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -26)

            case .startPoint:
                let hosting = UIHostingController(
                    rootView: ZStack {
                        Circle()
                            .fill(Color(hex: "#16A34A"))
                            .frame(width: 26, height: 26)
                            .shadow(radius: 2)
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 26, height: 26)
                        Text("A")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -15)

            case .mainTech:
                let name = customPin.title ?? (customPin.isSpecialist ? "Chuyên viên" : "KTV")
                let rolePrefix = customPin.isSpecialist ? "Chuyên viên: " : "KTV: "
                let themeHex = customPin.isGpsLost ? "#DC2626" : (customPin.isSpecialist ? "#7C3AED" : "#002A8F")
                let hosting = UIHostingController(
                    rootView: VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text(customPin.isGpsLost ? "⚠️" : "🛵")
                                .font(.system(size: 11))
                            Text("\(rolePrefix)\(name)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: themeHex))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: themeHex), lineWidth: 1.3))

                        ZStack {
                            Circle()
                                .fill(Color(hex: themeHex))
                                .frame(width: 38, height: 38)
                                .shadow(radius: 3)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 38, height: 38)
                            Image(systemName: "figure.outdoor.cycle")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 175, height: 68)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -28)

            case .coTech:
                let name = customPin.title ?? "Phối hợp"
                let themeHex = "#7C3AED"
                let hosting = UIHostingController(
                    rootView: VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text("🛵")
                                .font(.system(size: 11))
                            Text("[Phối hợp] \(name)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: themeHex))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: themeHex), lineWidth: 1.3))

                        ZStack {
                            Circle()
                                .fill(Color(hex: themeHex))
                                .frame(width: 34, height: 34)
                                .shadow(radius: 3)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 34, height: 34)
                            Image(systemName: "figure.outdoor.cycle")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 160, height: 62)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -25)
            }

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.title == "CoTechRoute" {
                    renderer.strokeColor = UIColor(red: 139/255, green: 92/255, blue: 246/255, alpha: 0.85)
                    renderer.lineWidth = 4
                    renderer.lineDashPattern = [6, 6]
                } else {
                    renderer.strokeColor = UIColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.95)
                    renderer.lineWidth = 5
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.15)
                renderer.strokeColor = UIColor(red: 16/255, green: 185/255, blue: 129/255, alpha: 0.8)
                renderer.lineWidth = 1.5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - LIVE TRACKING MAP VIEW (ĐỒNG BỘ 1:1 VỚI ANDROID LIVETRACKINGMAPDIALOG)
public struct LiveTrackingMapView: View {
    public var ticket: SupportTicket
    @ObservedObject public var viewModel: SupportViewModel
    public var onDismiss: () -> Void
    public var onSelfResolved: (() -> Void)? = nil
    public var onTechResolve: (() -> Void)? = nil

    @State private var recenterTrigger: Int = 0
    @State private var fitBoundsTrigger: Int = 0
    @State private var zoomTrigger: Int = 0

    @State private var showCancelConfirmDialog: Bool = false
    @State private var showDistanceWarningDialog: Bool = false

    @StateObject private var locationProvider = DeviceLocationProvider()

    // Lộ trình thực tế theo đường giao thông OSRM
    @State private var roadCoordinates: [[Double]] = []
    @State private var routeDistanceKm: Double = 0.0
    @State private var routeEtaMinutes: Int = 0

    // Phân giải tọa độ đơn vị / siêu thị
    @State private var resolvedDestCoordinate: CLLocationCoordinate2D? = nil
    @State private var resolvedDestName: String = ""

    // Bán kính đến nơi cho phép (chuẩn Android: 150m - 200m)
    @State private var arrivalRadiusMeters: Double = 200.0

    // Vị trí đã biết gần nhất của KTV từ technician_locations (đồng bộ 1:1 Android)
    @State private var techLastKnownCoordinate: CLLocationCoordinate2D? = nil

    // Throttle cho việc gửi GPS thời gian thực lên Firestore
    @State private var lastReportedLocation: CLLocationCoordinate2D? = nil
    @State private var lastReportedTime: Date = Date.distantPast

    @State private var mapPollTimer: Timer?

    private var currentTicket: SupportTicket {
        viewModel.tickets.first(where: { $0.id == ticket.id }) ?? ticket
    }

    private var myEmail: String {
        viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isSpecialist: Bool {
        currentTicket.isSpecialistAssigned || currentTicket.assignedRole.uppercased() == "SPECIALIST" || viewModel.user.isSpecialist
    }

    private var rolePrefix: String {
        isSpecialist ? "Chuyên viên" : "KTV"
    }

    private var fullRoleTitle: String {
        isSpecialist ? "Chuyên viên kỹ thuật" : "Kỹ thuật viên"
    }

    private var isCoTechUser: Bool {
        currentTicket.coTechnicians.contains { $0.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail } ||
        currentTicket.collaboratorTrackings.values.contains { $0.technicianEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail }
    }

    private var isAssignedTech: Bool {
        if isCreator { return false }
        if isCoTechUser { return true }

        let cleanMyEmail = myEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanMyEmail.isEmpty else { return false }

        return currentTicket.isUserAssigned(email: cleanMyEmail)
    }

    private var isCreator: Bool {
        let cEmail = currentTicket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cUser = currentTicket.creatorUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myId = viewModel.user.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return (!myEmail.isEmpty && cEmail == myEmail) || (!myId.isEmpty && cUser == myId)
    }

    private var isHelpDeskOrAdmin: Bool {
        !isAssignedTech && (viewModel.user.isAdmin || viewModel.user.isHelpDesk || viewModel.user.role.contains("MANAGER"))
    }

    private var tracking: TicketTracking {
        currentTicket.tracking ?? TicketTracking(ticketId: currentTicket.id)
    }

    private var isEnRoute: Bool {
        tracking.status == "EN_ROUTE" || currentTicket.collaboratorTrackings.values.contains { $0.status == "EN_ROUTE" }
    }

    private var isArrived: Bool {
        tracking.status == "ARRIVED"
    }

    // Tọa độ Điểm đến (Đồng bộ 1:1 Android: Ưu tiên 1. Đã phân giải -> 2. CoopmartDirectory theo donVi -> 3. CoopmartDirectory theo creatorAddress -> 4. creatorLat -> 5. destLat -> 6. Fallback)
    private var destCoordinate: CLLocationCoordinate2D {
        if let resolved = resolvedDestCoordinate {
            return resolved
        }
        if let store = CoopmartDirectory.resolveLocation(currentTicket.donVi) {
            return CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
        }
        if let store = CoopmartDirectory.resolveLocation(currentTicket.creatorAddress) {
            return CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
        }
        if currentTicket.creatorLat != 0 && currentTicket.creatorLng != 0 {
            return CLLocationCoordinate2D(latitude: currentTicket.creatorLat, longitude: currentTicket.creatorLng)
        }
        if tracking.destLat != 0 && tracking.destLng != 0 {
            return CLLocationCoordinate2D(latitude: tracking.destLat, longitude: tracking.destLng)
        }
        return CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
    }

    private var effectiveDestName: String {
        if !resolvedDestName.isEmpty { return resolvedDestName }
        if let store = CoopmartDirectory.resolveLocation(currentTicket.donVi) {
            return store.name
        }
        if let store = CoopmartDirectory.resolveLocation(currentTicket.creatorAddress) {
            return store.name
        }
        if !currentTicket.donVi.isEmpty { return currentTicket.donVi }
        if !tracking.destAddress.isEmpty { return tracking.destAddress }
        if !currentTicket.creatorAddress.isEmpty { return currentTicket.creatorAddress }
        return "Điểm hỗ trợ"
    }

    // Tọa độ KTV / Chuyên viên (Đồng bộ 1:1 Android: Luôn đảm bảo có tọa độ để vẽ trọn vẹn lộ trình đường đi)
    private var techCoordinate: CLLocationCoordinate2D? {
        if isAssignedTech {
            // Nếu người xem CHÍNH LÀ KTV/Chuyên viên phụ trách:
            if let devLoc = locationProvider.lastLocation, devLoc.latitude != 0, devLoc.longitude != 0 {
                return devLoc
            }
            if tracking.currentLat != 0 && tracking.currentLng != 0 {
                return CLLocationCoordinate2D(latitude: tracking.currentLat, longitude: tracking.currentLng)
            }
            if tracking.startLat != 0 && tracking.startLng != 0 {
                return CLLocationCoordinate2D(latitude: tracking.startLat, longitude: tracking.startLng)
            }
            if let last = techLastKnownCoordinate {
                return last
            }
            return CLLocationCoordinate2D(latitude: 10.764412, longitude: 106.693425)
        } else {
            // Nếu người xem là Khách hàng (Người gửi hỗ trợ) hoặc HelpDesk / Admin:
            if tracking.currentLat != 0 && tracking.currentLng != 0 {
                return CLLocationCoordinate2D(latitude: tracking.currentLat, longitude: tracking.currentLng)
            }
            if tracking.startLat != 0 && tracking.startLng != 0 {
                return CLLocationCoordinate2D(latitude: tracking.startLat, longitude: tracking.startLng)
            }
            if let last = techLastKnownCoordinate {
                return last
            }
            // Fallback điểm xuất phát KTV: Trụ sở chính Saigon Co.op / Phòng CNTT (199-205 Nguyễn Thái Học, Q1)
            return CLLocationCoordinate2D(latitude: 10.764412, longitude: 106.693425)
        }
    }

    private var startCoordinate: CLLocationCoordinate2D? {
        if tracking.startLat != 0 && tracking.startLng != 0 {
            return CLLocationCoordinate2D(latitude: tracking.startLat, longitude: tracking.startLng)
        }
        return nil
    }

    private var effectiveDistanceKm: Double {
        if routeDistanceKm > 0.05 { return routeDistanceKm }
        if tracking.distanceKm > 0.05 { return tracking.distanceKm }
        guard let tech = techCoordinate else { return 0.0 }
        let loc1 = CLLocation(latitude: tech.latitude, longitude: tech.longitude)
        let loc2 = CLLocation(latitude: destCoordinate.latitude, longitude: destCoordinate.longitude)
        return Double(round((loc1.distance(from: loc2) / 1000.0) * 10) / 10)
    }

    private var effectiveEtaMinutes: Int {
        if routeEtaMinutes > 0 { return routeEtaMinutes }
        if tracking.etaMinutes > 0 { return tracking.etaMinutes }
        let km = effectiveDistanceKm
        if km <= 0.0 { return 0 }
        return max(1, Int(km / 25.0 * 60.0))
    }

    private var targetPhone: String {
        if isAssignedTech {
            return currentTicket.creatorPhone
        } else {
            return tracking.technicianPhone.isEmpty ? (currentTicket.assignedToEmail) : tracking.technicianPhone
        }
    }

    private var displayName: String {
        if isAssignedTech {
            return currentTicket.creatorName.isEmpty ? (currentTicket.donVi.isEmpty ? currentTicket.creatorEmail : currentTicket.donVi) : currentTicket.creatorName
        } else {
            return currentTicket.assignedToName.isEmpty ? (tracking.technicianName.isEmpty ? "\(fullRoleTitle) hỗ trợ" : tracking.technicianName) : currentTicket.assignedToName
        }
    }

    private var displaySub: String {
        if isAssignedTech {
            return currentTicket.donVi.isEmpty ? "Yêu cầu #TK-\(currentTicket.id.prefix(8).uppercased())" : "Đơn vị: \(currentTicket.donVi)"
        } else {
            return "Phụ trách: \(currentTicket.assignedDepartmentName.isEmpty ? (isSpecialist ? "Tổ nghiệp vụ / Chuyên viên" : "Bộ phận Kỹ thuật") : currentTicket.assignedDepartmentName)"
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. TOP HEADER (Xanh dương đậm #002A8F hoặc Tím #6B21A8 nếu Chuyên viên)
            topHeaderView

            // 2. CẢNH BÁO MẤT GPS NẾU CÓ
            if tracking.isGpsLost {
                gpsLostWarningBanner
            }

            // 3. MAP AREA VỚI FLOATING BADGES & CONTROLS
            ZStack {
                LiveTrackingMKMapView(
                    techCoord: techCoordinate,
                    destCoord: destCoordinate,
                    startCoord: startCoordinate,
                    destName: effectiveDestName,
                    techName: currentTicket.assignedToName.isEmpty ? (isAssignedTech ? (viewModel.user.fullName.isEmpty ? rolePrefix : viewModel.user.fullName) : rolePrefix) : currentTicket.assignedToName,
                    isSpecialist: isSpecialist,
                    isEnRoute: isEnRoute,
                    isGpsLost: tracking.isGpsLost,
                    roadCoordinates: roadCoordinates,
                    collaboratorTrackings: currentTicket.collaboratorTrackings,
                    arrivalRadiusMeters: arrivalRadiusMeters,
                    recenterTrigger: $recenterTrigger,
                    fitBoundsTrigger: $fitBoundsTrigger,
                    zoomTrigger: $zoomTrigger
                )
                .edgesIgnoringSafeArea(.all)

                // Floating Status Pill ở trên cùng bản đồ
                VStack {
                    floatingStatusPill
                        .padding(.top, 12)
                    Spacer()
                }

                // Floating Map Controls ở góc phải dưới
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        floatingMapControls
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }

            // 4. BOTTOM INFO CARD & ACTION BUTTONS
            bottomInfoCard
        }
        .onAppear {
            VoiceNotificationHelper.shared.stopAlert(ticketId: currentTicket.id)
            resolveDestination()
            fetchTechLastKnownLocation()
            fetchRoadRoute()
            startMapPolling()
        }
        .onDisappear {
            stopMapPolling()
        }
        .onChange(of: tracking.currentLat) { _ in
            fetchRoadRoute()
        }
        .onChange(of: resolvedDestCoordinate?.latitude) { _ in
            fetchRoadRoute()
        }
        .onReceive(locationProvider.$lastLocation) { newLoc in
            guard let loc = newLoc, isAssignedTech && isEnRoute else { return }
            let now = Date()
            let elapsed = now.timeIntervalSince(lastReportedTime)

            var shouldReport = false
            if elapsed >= 5.0 {
                if let last = lastReportedLocation {
                    let dist = CLLocation(latitude: last.latitude, longitude: last.longitude)
                        .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                    if dist >= 5.0 || elapsed >= 15.0 {
                        shouldReport = true
                    }
                } else {
                    shouldReport = true
                }
            }

            if shouldReport {
                lastReportedLocation = loc
                lastReportedTime = now

                viewModel.updateTripLocation(
                    ticketId: currentTicket.id,
                    currentLat: loc.latitude,
                    currentLng: loc.longitude,
                    distanceKm: effectiveDistanceKm,
                    etaMinutes: effectiveEtaMinutes,
                    routeCoordinates: roadCoordinates,
                    isCoTech: isCoTechUser
                )
            }
        }
        .alert(isPresented: $showDistanceWarningDialog) {
            Alert(
                title: Text("Chưa thể xác nhận đến nơi"),
                message: Text("❌ Bạn vẫn đang cách điểm hỗ trợ \(String(format: "%.1f", effectiveDistanceKm)) km (vượt quá bán kính cho phép \(Int(arrivalRadiusMeters)) mét).\n\nVui lòng di chuyển đến đúng địa chỉ để xác nhận."),
                dismissButton: .default(Text("Đã hiểu, tiếp tục di chuyển"))
            )
        }
        .alert(isPresented: $showCancelConfirmDialog) {
            Alert(
                title: Text("Xác nhận hủy chuyến"),
                message: Text("Bạn có chắc chắn muốn hủy chuyến đi của \(rolePrefix) \(displayName) từ xa?"),
                primaryButton: .destructive(Text("Hủy chuyến")) {
                    viewModel.cancelTrip(ticketId: currentTicket.id) { _ in
                        onDismiss()
                    }
                },
                secondaryButton: .cancel(Text("Quay lại"))
            )
        }
    }

    // MARK: - MAP AUTO POLLING (CẬP NHẬT TỌA ĐỘ VÀ TRẠNG THÁI REALTIME)
    private func startMapPolling() {
        stopMapPolling()
        mapPollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            viewModel.fetchTicketsSilent()
        }
    }

    private func stopMapPolling() {
        mapPollTimer?.invalidate()
        mapPollTimer = nil
    }

    // MARK: - RESOLVE DESTINATION (ĐỒNG BỘ 1:1 ANDROID: COOPMART DIRECTORY FIRST)
    private func resolveDestination() {
        let query = currentTicket.donVi.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty, let store = CoopmartDirectory.resolveLocation(query) {
            resolvedDestCoordinate = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
            resolvedDestName = store.name
            fetchRoadRoute()
            return
        }

        let addr = currentTicket.creatorAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty, let store = CoopmartDirectory.resolveLocation(addr) {
            resolvedDestCoordinate = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
            resolvedDestName = store.name
            fetchRoadRoute()
            return
        }

        if currentTicket.creatorLat != 0 && currentTicket.creatorLng != 0 {
            resolvedDestCoordinate = CLLocationCoordinate2D(latitude: currentTicket.creatorLat, longitude: currentTicket.creatorLng)
            resolvedDestName = currentTicket.donVi.isEmpty ? currentTicket.subject : currentTicket.donVi
            fetchRoadRoute()
            return
        }

        if tracking.destLat != 0 && tracking.destLng != 0 {
            resolvedDestCoordinate = CLLocationCoordinate2D(latitude: tracking.destLat, longitude: tracking.destLng)
            resolvedDestName = tracking.destAddress.isEmpty ? currentTicket.donVi : tracking.destAddress
            fetchRoadRoute()
            return
        }

        let geocodeQuery = !query.isEmpty ? query : addr
        if !geocodeQuery.isEmpty {
            Task {
                if let geo = await OsrmRoutingHelper.shared.geocodeAddress(geocodeQuery) {
                    await MainActor.run {
                        self.resolvedDestCoordinate = CLLocationCoordinate2D(latitude: geo.lat, longitude: geo.lng)
                        self.resolvedDestName = geocodeQuery
                        self.fetchRoadRoute()
                    }
                }
            }
        }
    }

    // MARK: - TẢI VỊ TRÍ GẦN NHẤT CỦA KTV TỪ TECHNICIAN_LOCATIONS (ĐỒNG BỘ 1:1 ANDROID)
    private func fetchTechLastKnownLocation() {
        let techEmail = currentTicket.assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !techEmail.isEmpty, !viewModel.companyId.isEmpty else { return }
        let cleanEmail = techEmail.lowercased().replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_")
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId)/technician_locations/\(cleanEmail)"
        guard let url = URL(string: urlStr) else { return }

        Task {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !viewModel.idToken.isEmpty {
                request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
            }
            request.timeoutInterval = 6.0
            if let (data, resp) = try? await URLSession.shared.data(for: request),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any] {
                let lat = FirestoreHelper.getDouble(fields["lat"] as? [String: Any])
                let lng = FirestoreHelper.getDouble(fields["lng"] as? [String: Any])
                if lat != 0 && lng != 0 {
                    await MainActor.run {
                        self.techLastKnownCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                        self.fetchRoadRoute()
                    }
                }
            }
        }
    }

    // MARK: - FETCH ROAD ROUTE VIA OSRM / GOOGLE
    private func fetchRoadRoute() {
        let dest = destCoordinate
        guard let tech = techCoordinate, tech.latitude != 0, tech.longitude != 0, dest.latitude != 0, dest.longitude != 0 else { return }

        if !tracking.routeCoordinates.isEmpty && tracking.routeCoordinates.count >= 2 {
            self.roadCoordinates = tracking.routeCoordinates
        }

        Task {
            if let result = await OsrmRoutingHelper.shared.fetchRoute(
                startLat: tech.latitude,
                startLng: tech.longitude,
                destLat: dest.latitude,
                destLng: dest.longitude
            ) {
                await MainActor.run {
                    if !result.coordinates.isEmpty {
                        self.roadCoordinates = result.coordinates
                    }
                    self.routeDistanceKm = result.distanceKm
                    self.routeEtaMinutes = result.durationMinutes
                }
            }
        }
    }

    // MARK: - 1. TOP HEADER
    private var topHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.outdoor.cycle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(isAssignedTech ? (isSpecialist ? "Lộ trình chuyên viên xử lý" : "Lộ trình xử lý kỹ thuật") : (isSpecialist ? "Giám sát lộ trình chuyên viên" : "Giám sát lộ trình kỹ thuật viên"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text("Ticket #TK-\(currentTicket.id.prefix(8).uppercased()) • \(currentTicket.subject)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isSpecialist ? Color(hex: "#4C1D95") : Color(hex: "#002A8F"))
    }

    // MARK: - 2. GPS WARNING
    private var gpsLostWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "#DC2626"))
                .font(.system(size: 16))

            Text("⚠️ CẢNH BÁO: \(rolePrefix) đã tắt GPS trên thiết bị! Đã ghi nhận nhật ký.")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(Color(hex: "#B91C1C"))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(hex: "#FEE2E2"))
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color(hex: "#EF4444")), alignment: .bottom)
    }

    // MARK: - FLOATING STATUS PILL
    private var floatingStatusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tracking.isGpsLost ? Color(hex: "#EF4444") : (isEnRoute ? Color(hex: "#10B981") : Color(hex: "#F59E0B")))
                .frame(width: 10, height: 10)

            Text(statusMessage)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Color(hex: "#0F172A"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    private var statusMessage: String {
        if tracking.isGpsLost {
            return "MẤT TÍN HIỆU GPS • Vui lòng bật lại GPS"
        }
        if isEnRoute {
            let distText = effectiveDistanceKm > 0 ? "Còn \(String(format: "%.1f", effectiveDistanceKm)) km" : "Đang tính..."
            let etaText = effectiveEtaMinutes > 0 ? " (khoảng \(effectiveEtaMinutes) phút)" : ""
            return "\(rolePrefix) đang di chuyển • \(distText)\(etaText)"
        }
        if isArrived {
            return "✅ \(rolePrefix) đã đến nơi an toàn"
        }
        return "\(rolePrefix) đã sẵn sàng xuất phát"
    }

    // MARK: - FLOATING MAP CONTROLS
    private var floatingMapControls: some View {
        VStack(spacing: 0) {
            // Định vị KTV / Chuyên viên
            Button(action: { recenterTrigger += 1 }) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#EA580C"))
                    .frame(width: 36, height: 36)
            }

            Divider().frame(width: 28)

            // Zoom in
            Button(action: { zoomTrigger += 1 }) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#334155"))
                    .frame(width: 36, height: 36)
            }

            Divider().frame(width: 28)

            // Zoom out
            Button(action: { zoomTrigger -= 1 }) {
                Image(systemName: "minus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(hex: "#334155"))
                    .frame(width: 36, height: 36)
            }

            Divider().frame(width: 28)

            // Fit bounds
            Button(action: { fitBoundsTrigger += 1 }) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(isSpecialist ? Color(hex: "#7C3AED") : Color(hex: "#002A8F"))
                    .frame(width: 36, height: 36)
            }
        }
        .background(Color.white.opacity(0.95))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }

    // MARK: - 4. BOTTOM INFO CARD & ACTIONS
    private var bottomInfoCard: some View {
        VStack(spacing: 12) {
            // ROW 1: Avatar + Thông tin
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isAssignedTech ? (isSpecialist ? Color(hex: "#7C3AED") : Color(hex: "#00796B")) : Color(hex: "#002A8F"))
                        .frame(width: 44, height: 44)

                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#0F172A"))
                        .lineLimit(1)

                    Text(displaySub)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray)
                        .lineLimit(1)

                    if !targetPhone.isEmpty {
                        Text("📞 \(targetPhone)")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(hex: "#0284C7"))
                    }
                }

                Spacer()
            }

            // ROW 2: Nút Gọi GSM, Gọi In-App, Mở Bản đồ dẫn đường
            HStack(spacing: 8) {
                Spacer()

                // Nút Gọi In-App (WebRTC)
                let callTargetEmail = isAssignedTech ? ticket.creatorEmail : (ticket.assignedToEmail.isEmpty ? tracking.technicianEmail : ticket.assignedToEmail)
                if !callTargetEmail.isEmpty {
                    Button(action: {
                        WebRtcCallManager.shared.startCall(
                            targetEmail: callTargetEmail,
                            targetName: displayName,
                            callerName: viewModel.user.fullName,
                            callerEmail: viewModel.user.email
                        )
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 12))
                            Text("Gọi In-App")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: "#0284C7"))
                        .cornerRadius(8)
                    }
                }

                // Nút Gọi GSM thường
                if !targetPhone.isEmpty {
                    Button(action: {
                        let clean = targetPhone.replacingOccurrences(of: " ", with: "")
                        if let url = URL(string: "tel:\(clean)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.circle.fill")
                                .font(.system(size: 13))
                            Text("Gọi")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(hex: "#16A34A"))
                        .cornerRadius(8)
                    }
                }

                // Nút Mở Google Maps / Apple Maps dẫn đường
                Button(action: {
                    let d = destCoordinate
                    let lat = d.latitude
                    let lng = d.longitude
                    if let googleUrl = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving"),
                       UIApplication.shared.canOpenURL(googleUrl) {
                        UIApplication.shared.open(googleUrl)
                    } else if let appleUrl = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d") {
                        UIApplication.shared.open(appleUrl)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 13))
                        Text("Dẫn đường")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#334155"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#F1F5F9"))
                    .cornerRadius(8)
                }
            }

            // ROW 2.5: Danh sách KTV / Chuyên Viên Phối Hợp (chuẩn 1:1 Android)
            if !currentTicket.coTechnicians.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#7C3AED"))
                        Text("KTV / Chuyên Viên Phối Hợp (\(currentTicket.coTechnicians.count)):")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(hex: "#6B21A8"))
                    }

                    ForEach(currentTicket.coTechnicians) { co in
                        let sKey = co.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            .replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
                        let cTrack = currentTicket.collaboratorTrackings[sKey]
                        let statusText: String = {
                            if cTrack?.status == "ARRIVED" { return "✅ Đã đến" }
                            if cTrack?.status == "EN_ROUTE" {
                                let d = cTrack?.distanceKm ?? 0
                                return d > 0 ? "🛵 Đang đến (\(String(format: "%.1f", d))km)" : "🛵 Đang di chuyển"
                            }
                            return "⚪ Sẵn sàng"
                        }()

                        HStack(spacing: 6) {
                            Text("• \(co.name.isEmpty ? co.email : co.name) [\(co.role.isEmpty ? "Phối hợp" : co.role)] • \(statusText)")
                                .font(.system(size: 11.5))
                                .foregroundColor(Color(hex: "#4C1D95"))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer()

                            if !co.email.isEmpty {
                                Button(action: {
                                    WebRtcCallManager.shared.startCall(
                                        targetEmail: co.email,
                                        targetName: co.name.isEmpty ? co.email : co.name,
                                        callerName: viewModel.user.fullName,
                                        callerEmail: viewModel.user.email
                                    )
                                }) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color(hex: "#0284C7"))
                                        .clipShape(Circle())
                                }
                            }

                            if !co.phone.isEmpty {
                                Button(action: {
                                    let clean = co.phone.replacingOccurrences(of: " ", with: "")
                                    if let url = URL(string: "tel:\(clean)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "phone.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(hex: "#16A34A"))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(10)
                .background(Color(hex: "#FAF5FF"))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#E9D5FF"), lineWidth: 1))
            }

            Divider()

            // ROW 3: Các nút hành động đặc thù theo vai trò
            if isAssignedTech {
                ktvActionButtons
            } else if isHelpDeskOrAdmin {
                adminActionButtons
            } else {
                creatorActionButtons
            }
        }
        .padding(16)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -2)
    }

    // MARK: - KTV / SPECIALIST ACTIONS
    private var ktvActionButtons: some View {
        VStack(spacing: 8) {
            if !isEnRoute && !isArrived {
                // Nút Bắt đầu di chuyển
                Button(action: {
                    let dest = destCoordinate
                    guard let tech = techCoordinate else { return }
                    viewModel.startTrip(
                        ticketId: currentTicket.id,
                        startLat: tech.latitude,
                        startLng: tech.longitude,
                        startAddress: "Vị trí xuất phát của \(rolePrefix)",
                        destLat: dest.latitude,
                        destLng: dest.longitude,
                        destAddress: effectiveDestName,
                        distanceKm: effectiveDistanceKm,
                        etaMinutes: effectiveEtaMinutes,
                        isSpecialist: isSpecialist,
                        isCoTech: isCoTechUser,
                        routeCoordinates: roadCoordinates
                    )
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.system(size: 16, weight: .bold))
                        Text("Bắt đầu di chuyển tới điểm hỗ trợ")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#10B981"))
                    .cornerRadius(10)
                }

                // Nút Xử lý từ xa
                Button(action: {
                    viewModel.switchToRemote(ticketId: currentTicket.id, isSpecialist: isSpecialist) { _ in
                        onDismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "desktopcomputer")
                        Text("💻 Xử lý từ xa (Không cần di chuyển)")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#1D4ED8"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#93C5FD"), lineWidth: 1))
                }
            } else if isEnRoute {
                // Nút Mở Google Maps / Apple Maps Dẫn đường có giọng nói
                Button(action: {
                    let d = destCoordinate
                    let lat = d.latitude
                    let lng = d.longitude
                    if let googleUrl = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving"),
                       UIApplication.shared.canOpenURL(googleUrl) {
                        UIApplication.shared.open(googleUrl)
                    } else if let appleUrl = URL(string: "http://maps.apple.com/?daddr=\(lat),\(lng)&dirflg=d") {
                        UIApplication.shared.open(appleUrl)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.system(size: 15))
                        Text("🧭 Mở Dẫn Đường Bản Đồ (Giọng nói & Giao thông)")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color(hex: "#16A34A"))
                    .cornerRadius(10)
                }

                // Xác nhận Đã đến nơi
                Button(action: {
                    if effectiveDistanceKm > (arrivalRadiusMeters / 1000.0) {
                        showDistanceWarningDialog = true
                    } else {
                        viewModel.markArrived(ticketId: currentTicket.id, isSpecialist: isSpecialist, isCoTech: isCoTechUser)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Xác nhận Đã đến nơi (Yêu cầu <= \(Int(arrivalRadiusMeters))m)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isSpecialist ? Color(hex: "#6B21A8") : Color(hex: "#002A8F"))
                    .cornerRadius(10)
                }

                // Dừng di chuyển & Đổi sang xử lý từ xa
                Button(action: {
                    viewModel.switchToRemote(ticketId: currentTicket.id, isSpecialist: isSpecialist) { _ in
                        onDismiss()
                    }
                }) {
                    Text("💻 Dừng di chuyển & Đổi sang xử lý từ xa")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(Color(hex: "#1D4ED8"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#93C5FD"), lineWidth: 1))
                }

                if let techResolve = onTechResolve {
                    Button(action: {
                        onDismiss()
                        techResolve()
                    }) {
                        Text("✓ Báo cáo xử lý xong sự cố")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(Color(hex: "#15803D"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#86EFAC"), lineWidth: 1))
                    }
                }
            } else if isArrived {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#16A34A"))
                    Text("Đã xác thực vị trí đến nơi thành công")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#16A34A"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "#DCFCE7"))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#10B981"), lineWidth: 1))

                if let techResolve = onTechResolve {
                    Button(action: {
                        onDismiss()
                        techResolve()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                            Text("🛠️ Báo cáo đã xử lý xong sự cố tại chỗ")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#16A34A"))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }

    // MARK: - ADMIN ACTIONS
    private var adminActionButtons: some View {
        VStack(spacing: 8) {
            if isEnRoute || isArrived {
                Button(action: { showCancelConfirmDialog = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.octagon.fill")
                        Text("🛑 Hủy chuyến đi của \(rolePrefix) \(displayName)")
                            .font(.system(size: 12.5, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#DC2626"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#FCA5A5"), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - CREATOR (USER) ACTIONS
    private var creatorActionButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📍 Điểm đến hỗ trợ: \(effectiveDestName) (Bán kính \(Int(arrivalRadiusMeters))m)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#64748B"))

            if (isEnRoute || isArrived), let selfResolve = onSelfResolved, isCreator {
                Button(action: {
                    onDismiss()
                    selfResolve()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("💡 Tôi đã tự xử lý xong (Đóng phiếu & Dừng \(rolePrefix))")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#B45309"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#FDE68A"), lineWidth: 1))
                }
            }
        }
    }
}
