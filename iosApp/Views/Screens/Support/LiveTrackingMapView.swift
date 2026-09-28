import SwiftUI
import MapKit
import CoreLocation

// MARK: - ANNOTATION MODELS FOR MAPKIT
class CustomMapPin: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let isTech: Bool

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, isTech: Bool) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.isTech = isTech
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

// MARK: - NATIVE MAPKIT VIEW WITH ROUTE & CUSTOM PINS
struct LiveTrackingMKMapView: UIViewRepresentable {
    var techCoord: CLLocationCoordinate2D?
    var destCoord: CLLocationCoordinate2D?
    var destName: String
    var techName: String
    var isEnRoute: Bool
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

        if let dest = destCoord, dest.latitude != 0, dest.longitude != 0 {
            let destPin = CustomMapPin(
                coordinate: dest,
                title: destName.isEmpty ? "Điểm hỗ trợ" : destName,
                subtitle: "Điểm đến",
                isTech: false
            )
            annotationsToAdd.append(destPin)
        }

        if let tech = techCoord, tech.latitude != 0, tech.longitude != 0 {
            let techPin = CustomMapPin(
                coordinate: tech,
                title: techName.isEmpty ? "Kỹ thuật viên" : techName,
                subtitle: isEnRoute ? "Đang di chuyển" : "Vị trí KTV",
                isTech: true
            )
            annotationsToAdd.append(techPin)
        }

        uiView.addAnnotations(annotationsToAdd)

        // 2. Vẽ Route Polyline nếu cả 2 điểm đều có tọa độ
        uiView.removeOverlays(uiView.overlays)
        if let tech = techCoord, let dest = destCoord,
           tech.latitude != 0, tech.longitude != 0,
           dest.latitude != 0, dest.longitude != 0 {
            var coords = [tech, dest]
            let polyline = MKPolyline(coordinates: &coords, count: 2)
            uiView.addOverlay(polyline)

            // Yêu cầu Apple Maps tính lộ trình thực tế nếu khả dụng
            let req = MKDirections.Request()
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: tech))
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
            req.transportType = .automobile

            let directions = MKDirections(request: req)
            directions.calculate { response, error in
                guard let route = response?.routes.first else { return }
                DispatchQueue.main.async {
                    uiView.removeOverlays(uiView.overlays)
                    uiView.addOverlay(route.polyline, level: .aboveRoads)
                }
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
            uiView.showAnnotations(annotationsToAdd, animated: false)
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

            let identifier = customPin.isTech ? "TechPin" : "DestPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if view == nil {
                view = MKAnnotationView(annotation: customPin, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = customPin
            }

            view?.subviews.forEach { $0.removeFromSuperview() }

            if customPin.isTech {
                // KTV Marker: Nhãn nổi "🛵 Tên KTV" bên trên + Icon xe máy nền xanh tròn (chuẩn 1:1 Android)
                let name = customPin.title ?? "KTV"
                let hosting = UIHostingController(
                    rootView: VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Text("🛵")
                                .font(.system(size: 11))
                            Text(name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "#002A8F"))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#002A8F"), lineWidth: 1.2))

                        ZStack {
                            Circle()
                                .fill(Color(hex: "#002A8F"))
                                .frame(width: 36, height: 36)
                                .shadow(radius: 3)
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: 36, height: 36)
                            Image(systemName: "figure.outdoor.cycle")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 160, height: 65)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -25)
            } else {
                // Destination Marker: Ghim đỏ có tên đơn vị
                let hosting = UIHostingController(
                    rootView: VStack(spacing: 2) {
                        Text(customPin.title ?? "Điểm đến")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#DC2626"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white)
                            .cornerRadius(6)
                            .shadow(radius: 2)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(hex: "#EF4444"), lineWidth: 1.5))

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color(hex: "#DC2626"))
                            .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                    }
                )
                hosting.view.backgroundColor = .clear
                hosting.view.frame = CGRect(x: 0, y: 0, width: 140, height: 50)
                view?.frame = hosting.view.frame
                view?.addSubview(hosting.view)
                view?.centerOffset = CGPoint(x: 0, y: -25)
            }

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 14/255, green: 165/255, blue: 233/255, alpha: 0.9)
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
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

    private var myEmail: String {
        viewModel.user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isAssignedTech: Bool {
        // 1. Nếu tài khoản hiện tại là người tạo ticket, họ là người dùng cần được hỗ trợ -> Hiển thị Giám sát lộ trình
        if isCreator { return false }

        // 2. Nếu tài khoản là KTV hoặc Chuyên viên (Kỹ thuật) -> Luôn hiển thị Lộ trình xử lý kỹ thuật (Hình 2)
        let role = viewModel.user.role.uppercased()
        let isTechOrSpecialist = viewModel.user.isTechnician || viewModel.user.isSpecialist ||
                                 role.contains("KTV") || role.contains("TECHNICIAN") ||
                                 role.contains("KYTHUAT") || role.contains("SPECIALIST") ||
                                 role.contains("CHUYENVIEN") || role.contains("CHUYEN_VIEN") ||
                                 !viewModel.user.toNghiepVu.isEmpty

        if isTechOrSpecialist {
            return true
        }

        // 3. Kiểm tra nếu được phân công trực tiếp vào phiếu
        let assignedEmail = ticket.assignedToEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let assignedName = ticket.assignedTo.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myName = viewModel.user.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let isDirectlyAssigned = (assignedEmail == myEmail && !assignedEmail.isEmpty) ||
                                 (assignedName == myEmail && !assignedName.isEmpty) ||
                                 (assignedName == myName && !assignedName.isEmpty) ||
                                 ticket.isUserAssigned(email: myEmail)

        return isDirectlyAssigned
    }

    private var isCreator: Bool {
        ticket.creatorEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == myEmail
    }

    private var isHelpDeskOrAdmin: Bool {
        !isAssignedTech && (viewModel.user.isAdmin || viewModel.user.isHelpDesk || viewModel.user.role.contains("MANAGER"))
    }

    private var tracking: TicketTracking {
        ticket.tracking ?? TicketTracking(ticketId: ticket.id)
    }

    private var isEnRoute: Bool {
        tracking.status == "EN_ROUTE"
    }

    private var isArrived: Bool {
        tracking.status == "ARRIVED"
    }

    // Tọa độ Điểm đến (Đơn vị / Store)
    private var destCoordinate: CLLocationCoordinate2D {
        if ticket.creatorLat != 0 && ticket.creatorLng != 0 {
            return CLLocationCoordinate2D(latitude: ticket.creatorLat, longitude: ticket.creatorLng)
        }
        if tracking.destLat != 0 && tracking.destLng != 0 {
            return CLLocationCoordinate2D(latitude: tracking.destLat, longitude: tracking.destLng)
        }
        // Fallback default Saigon Co.op HCM
        return CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
    }

    // Tọa độ Kỹ thuật viên (Ưu tiên: 1. Firestore di chuyển -> 2. GPS thực tế thiết bị -> 3. Điểm xuất phát -> 4. Fallback)
    private var techCoordinate: CLLocationCoordinate2D {
        // 1. Tọa độ di chuyển đang lưu trên Firestore
        if tracking.currentLat != 0 && tracking.currentLng != 0 {
            return CLLocationCoordinate2D(latitude: tracking.currentLat, longitude: tracking.currentLng)
        }
        // 2. Tọa độ thực tế từ GPS của máy KTV (đặc biệt khi mới mở màn hình chưa xuất phát)
        if isAssignedTech, let devLoc = locationProvider.lastLocation, devLoc.latitude != 0, devLoc.longitude != 0 {
            return devLoc
        }
        // 3. Tọa độ điểm xuất phát đã lưu
        if tracking.startLat != 0 && tracking.startLng != 0 {
            return CLLocationCoordinate2D(latitude: tracking.startLat, longitude: tracking.startLng)
        }
        // 4. GPS thiết bị bất kỳ có sẵn
        if let devLoc = locationProvider.lastLocation, devLoc.latitude != 0, devLoc.longitude != 0 {
            return devLoc
        }
        // Fallback default
        return CLLocationCoordinate2D(latitude: 10.7626, longitude: 106.6602)
    }

    private var effectiveDistanceKm: Double {
        if tracking.distanceKm > 0.05 { return tracking.distanceKm }
        let loc1 = CLLocation(latitude: techCoordinate.latitude, longitude: techCoordinate.longitude)
        let loc2 = CLLocation(latitude: destCoordinate.latitude, longitude: destCoordinate.longitude)
        return Double(round((loc1.distance(from: loc2) / 1000.0) * 10) / 10)
    }

    private var effectiveEtaMinutes: Int {
        if tracking.etaMinutes > 0 { return tracking.etaMinutes }
        let km = effectiveDistanceKm
        return max(1, Int(km / 25.0 * 60.0))
    }

    private var targetPhone: String {
        if isAssignedTech {
            return ticket.creatorPhone
        } else {
            return tracking.technicianPhone.isEmpty ? (ticket.assignedToEmail) : tracking.technicianPhone
        }
    }

    private var displayName: String {
        if isAssignedTech {
            return ticket.creatorName.isEmpty ? (ticket.donVi.isEmpty ? ticket.creatorEmail : ticket.donVi) : ticket.creatorName
        } else {
            return ticket.assignedToName.isEmpty ? (tracking.technicianName.isEmpty ? "Kỹ thuật viên hỗ trợ" : tracking.technicianName) : ticket.assignedToName
        }
    }

    private var displaySub: String {
        if isAssignedTech {
            return ticket.donVi.isEmpty ? "Yêu cầu #\(ticket.id.suffix(6).uppercased())" : "Đơn vị: \(ticket.donVi)"
        } else {
            return "Phụ trách: \(ticket.assignedDepartmentName.isEmpty ? "Bộ phận Kỹ thuật" : ticket.assignedDepartmentName)"
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. TOP HEADER (Xanh dương đậm #002A8F)
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
                    destName: ticket.donVi.isEmpty ? ticket.subject : ticket.donVi,
                    techName: ticket.assignedToName.isEmpty ? (isAssignedTech ? (viewModel.user.fullName.isEmpty ? "KTV" : viewModel.user.fullName) : "KTV") : ticket.assignedToName,
                    isEnRoute: isEnRoute,
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
        .alert(isPresented: $showDistanceWarningDialog) {
            Alert(
                title: Text("Chưa thể xác nhận đến nơi"),
                message: Text("❌ Bạn vẫn đang cách điểm hỗ trợ \(String(format: "%.1f", effectiveDistanceKm)) km (vượt quá bán kính cho phép 200m).\n\nVui lòng di chuyển đến đúng địa chỉ để xác nhận."),
                dismissButton: .default(Text("Đã hiểu, tiếp tục di chuyển"))
            )
        }
        .alert(isPresented: $showCancelConfirmDialog) {
            Alert(
                title: Text("Xác nhận hủy chuyến"),
                message: Text("Bạn có chắc chắn muốn hủy chuyến đi của KTV \(displayName) từ xa?"),
                primaryButton: .destructive(Text("Hủy chuyến")) {
                    viewModel.cancelTrip(ticketId: ticket.id) { _ in
                        onDismiss()
                    }
                },
                secondaryButton: .cancel(Text("Quay lại"))
            )
        }
    }

    // MARK: - 1. TOP HEADER
    private var topHeaderView: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.outdoor.cycle")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(isAssignedTech ? "Lộ trình xử lý kỹ thuật" : "Giám sát lộ trình kỹ thuật viên")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Text("Ticket #\(ticket.id.suffix(8).uppercased()) • \(ticket.subject)")
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
        .background(Color(hex: "#002A8F"))
    }

    // MARK: - 2. GPS WARNING
    private var gpsLostWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "#DC2626"))
                .font(.system(size: 16))

            Text("⚠️ CẢNH BÁO: KTV đã tắt GPS trên thiết bị! Đã ghi nhận nhật ký.")
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
            return "KTV đang di chuyển • \(distText)\(etaText)"
        }
        if isArrived {
            return "✅ KTV đã đến nơi an toàn"
        }
        return "KTV đã sẵn sàng xuất phát"
    }

    // MARK: - FLOATING MAP CONTROLS
    private var floatingMapControls: some View {
        VStack(spacing: 0) {
            // Định vị KTV
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
                    .foregroundColor(Color(hex: "#002A8F"))
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
                        .fill(isAssignedTech ? Color(hex: "#00796B") : Color(hex: "#002A8F"))
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

            // ROW 2: Nút Gọi GSM, Gọi In-App, Mở Apple Maps
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

                // Nút Mở Apple Maps dẫn đường
                Button(action: {
                    let d = destCoordinate
                    if let url = URL(string: "http://maps.apple.com/?daddr=\(d.latitude),\(d.longitude)&dirflg=d") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#334155"))
                        .frame(width: 34, height: 34)
                        .background(Color(hex: "#F1F5F9"))
                        .cornerRadius(8)
                }
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

    // MARK: - KTV ACTIONS
    private var ktvActionButtons: some View {
        VStack(spacing: 8) {
            if !isEnRoute && !isArrived {
                // Nút Bắt đầu di chuyển
                Button(action: {
                    let dest = destCoordinate
                    let tech = techCoordinate
                    viewModel.startTrip(
                        ticketId: ticket.id,
                        startLat: tech.latitude,
                        startLng: tech.longitude,
                        startAddress: "Vị trí xuất phát của KTV",
                        destLat: dest.latitude,
                        destLng: dest.longitude,
                        destAddress: ticket.donVi,
                        distanceKm: effectiveDistanceKm,
                        etaMinutes: effectiveEtaMinutes
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
                    viewModel.switchToRemote(ticketId: ticket.id) { _ in
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
                // Xác nhận Đã đến nơi
                Button(action: {
                    if effectiveDistanceKm > 0.2 { // Bán kính 200m
                        showDistanceWarningDialog = true
                    } else {
                        viewModel.markArrived(ticketId: ticket.id)
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                        Text("Xác nhận Đã đến nơi (Yêu cầu <= 200m)")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#002A8F"))
                    .cornerRadius(10)
                }

                // Dừng di chuyển & Đổi sang xử lý từ xa
                Button(action: {
                    viewModel.switchToRemote(ticketId: ticket.id) { _ in
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
                        Text("🛑 Hủy chuyến đi của KTV \(displayName)")
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
            Text("📍 Điểm đến hỗ trợ: \(ticket.donVi.isEmpty ? "Tại văn phòng người gửi" : ticket.donVi) (Bán kính 200m)")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#64748B"))

            if (isEnRoute || isArrived), let selfResolve = onSelfResolved, isCreator {
                Button(action: {
                    onDismiss()
                    selfResolve()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("💡 Tôi đã tự xử lý xong (Đóng phiếu & Dừng KTV)")
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
