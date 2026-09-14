import SwiftUI
import MapKit
import CoreLocation

// MARK: - MKMapView Representable (iOS 15.0+ Polyline & Pin Rendering)
struct LiveTrackingMKMapView: UIViewRepresentable {
    let technicianCoord: CLLocationCoordinate2D?
    let destinationCoord: CLLocationCoordinate2D
    let destinationName: String
    let routeCoords: [CLLocationCoordinate2D]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        uiView.removeAnnotations(uiView.annotations)
        uiView.removeOverlays(uiView.overlays)

        // 1. Destination pin (Siêu thị / Cửa hàng)
        let destAnnotation = MKPointAnnotation()
        destAnnotation.coordinate = destinationCoord
        destAnnotation.title = destinationName
        destAnnotation.subtitle = "Điểm đến cần hỗ trợ"
        uiView.addAnnotation(destAnnotation)

        // 2. Technician pin (nếu có tọa độ)
        if let tech = technicianCoord, tech.latitude != 0, tech.longitude != 0 {
            let techAnnotation = MKPointAnnotation()
            techAnnotation.coordinate = tech
            techAnnotation.title = "Kỹ thuật viên"
            techAnnotation.subtitle = "Đang di chuyển"
            uiView.addAnnotation(techAnnotation)
        }

        // 3. Polyline OSRM
        if routeCoords.count > 1 {
            let polyline = MKPolyline(coordinates: routeCoords, count: routeCoords.count)
            uiView.addOverlay(polyline)

            // Zoom to fit bounds
            let rect = polyline.boundingMapRect
            let paddedRect = uiView.mapRectThatFits(rect, edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 180, right: 40))
            uiView.setVisibleMapRect(paddedRect, animated: true)
        } else {
            // Zoom to destination
            let region = MKCoordinateRegion(center: destinationCoord, latitudinalMeters: 2000, longitudinalMeters: 2000)
            uiView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LiveTrackingMKMapView

        init(_ parent: LiveTrackingMKMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(Color.appPrimaryPink)
                renderer.lineWidth = 5.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            let identifier = "TrackingAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            if annotation.title == "Kỹ thuật viên" {
                view?.markerTintColor = UIColor.systemBlue
                view?.glyphImage = UIImage(systemName: "figure.walk")
            } else {
                view?.markerTintColor = UIColor(Color.appPrimaryPink)
                view?.glyphImage = UIImage(systemName: "building.2.fill")
            }
            return view
        }
    }
}

// MARK: - Full Live Tracking Dialog / View
struct LiveTrackingMapView: View {
    let ticket: SupportTicket?
    let customTicketCode: String?
    let customDestinationName: String?
    let customDestLat: Double?
    let customDestLng: Double?
    let companyId: String
    @Environment(\.dismiss) private var dismiss

    @State private var technicianCoord: CLLocationCoordinate2D? = nil
    @State private var destinationCoord: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 10.764412, longitude: 106.693425)
    @State private var destinationName: String = "Điểm đến"
    @State private var routeCoords: [CLLocationCoordinate2D] = []
    @State private var distanceKm: Double = 0.0
    @State private var durationMinutes: Int = 0
    @State private var isLoadingRoute: Bool = false
    @State private var isTechnicianMoving: Bool = false

    init(ticket: SupportTicket, companyId: String = "SGCOOP") {
        self.ticket = ticket
        self.customTicketCode = ticket.id
        self.customDestinationName = ticket.unit.isEmpty ? ticket.title : ticket.unit
        self.customDestLat = nil
        self.customDestLng = nil
        self.companyId = companyId
    }

    init(destinationName: String, destLat: Double = 10.764412, destLng: Double = 106.693425, ticketCode: String = "GPS", companyId: String = "SGCOOP") {
        self.ticket = nil
        self.customTicketCode = ticketCode
        self.customDestinationName = destinationName
        self.customDestLat = destLat
        self.customDestLng = destLng
        self.companyId = companyId
    }

    public var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Background Map
                LiveTrackingMKMapView(
                    technicianCoord: technicianCoord,
                    destinationCoord: destinationCoord,
                    destinationName: destinationName,
                    routeCoords: routeCoords
                )
                .ignoresSafeArea(edges: .all)

                // Loading overlay indicator
                if isLoadingRoute {
                    VStack {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Đang tính lộ trình đường bộ OSRM...")
                                .font(.caption.bold())
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 4)
                        Spacer()
                    }
                    .padding(.top, 16)
                }

                // Bottom Control Card
                VStack(spacing: 14) {
                    // Header ticket & destination
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ticket?.title ?? customTicketCode ?? "Theo dõi vị trí")
                                .font(.headline)
                                .foregroundColor(.appTextPrimary)
                                .lineLimit(1)
                            Text("Đơn vị: \(ticket?.unit ?? customDestinationName ?? destinationName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(isTechnicianMoving ? "Đang di chuyển" : "Sẵn sàng")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(isTechnicianMoving ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .foregroundColor(isTechnicianMoving ? .green : .orange)
                                .clipShape(Capsule())
                        }
                    }

                    // Metrics: Distance & Time
                    HStack(spacing: 20) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.swap")
                                .foregroundColor(.appPrimaryPink)
                            VStack(alignment: .leading) {
                                Text("Khoảng cách")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(distanceKm > 0 ? String(format: "%.1f km", distanceKm) : "-- km")
                                    .font(.headline.bold())
                                    .foregroundColor(.appTextPrimary)
                            }
                        }

                        Divider()
                            .frame(height: 36)

                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("Thời gian ước tính")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(durationMinutes > 0 ? "\(durationMinutes) phút" : "-- phút")
                                    .font(.headline.bold())
                                    .foregroundColor(.appTextPrimary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Action Buttons
                    HStack(spacing: 12) {
                        // Open Apple Maps
                        Button(action: openAppleMaps) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("Chỉ đường")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.appSecondaryDarkBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Toggle Move state
                        Button(action: toggleMoving) {
                            HStack {
                                Image(systemName: isTechnicianMoving ? "checkmark.circle.fill" : "figure.walk")
                                Text(isTechnicianMoving ? "Đã đến nơi" : "Bắt đầu đi")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(isTechnicianMoving ? Color.green : Color.appPrimaryPink)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: -4)
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .navigationTitle("Live Tracking & Điều Phối")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .font(.headline)
                        .foregroundColor(.appPrimaryPink)
                }
            }
            .task {
                await resolveDestinationAndRoute()
            }
        }
    }

    private func resolveDestinationAndRoute() async {
        isLoadingRoute = true
        let destName = customDestinationName ?? ticket?.unit ?? ticket?.title ?? "Điểm đến"
        destinationName = destName

        // 1. Resolve store destination GPS
        if let lat = customDestLat, let lng = customDestLng, lat != 0, lng != 0 {
            destinationCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        } else if let unit = ticket?.unit, let store = CoopmartDirectory.resolveLocation(unit) {
            destinationCoord = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
        } else if let store = CoopmartDirectory.resolveLocation(destName) {
            destinationCoord = CLLocationCoordinate2D(latitude: store.lat, longitude: store.lng)
        } else if let geocoded = await OSRMRoutingService.shared.geocodeAddress(destName) {
            destinationCoord = CLLocationCoordinate2D(latitude: geocoded.lat, longitude: geocoded.lng)
        }

        // 2. Mock or get current technician location (from device GPS or office)
        let startLat = 10.764412 // Trụ sở Saigon Co.op
        let startLng = 106.693425
        technicianCoord = CLLocationCoordinate2D(latitude: startLat, longitude: startLng)

        // 3. Calculate OSRM route
        if let route = await OSRMRoutingService.shared.fetchRoute(
            startLat: startLat,
            startLng: startLng,
            destLat: destinationCoord.latitude,
            destLng: destinationCoord.longitude
        ) {
            distanceKm = route.distanceKm
            durationMinutes = route.durationMinutes
            routeCoords = route.polylineCoordinates
        }

        isLoadingRoute = false
    }

    private func openAppleMaps() {
        let urlString = "maps://?daddr=\(destinationCoord.latitude),\(destinationCoord.longitude)&dirflg=d"
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func toggleMoving() {
        withAnimation {
            isTechnicianMoving.toggle()
        }
    }
}
