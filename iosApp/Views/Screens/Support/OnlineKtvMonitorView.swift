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
    public var role: String
    public var departmentId: String
    public var departmentName: String
    public var isSpecialist: Bool
    public var todayShiftCode: String
    public var isScheduledOff: Bool
    public var violationsThisMonth: Int
    public var isBlacklisted: Bool

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
        longitude: Double = 0,
        role: String = "",
        departmentId: String = "",
        departmentName: String = "",
        isSpecialist: Bool = false,
        todayShiftCode: String = "",
        isScheduledOff: Bool = false,
        violationsThisMonth: Int = 0,
        isBlacklisted: Bool = false
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
        self.role = role
        self.departmentId = departmentId
        self.departmentName = departmentName
        self.isSpecialist = isSpecialist
        self.todayShiftCode = todayShiftCode
        self.isScheduledOff = isScheduledOff
        self.violationsThisMonth = violationsThisMonth
        self.isBlacklisted = isBlacklisted
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var mnvDisplay: String {
        let trimmed = maNhanVien.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let cleanEmail = email.components(separatedBy: "@").first?.filter { $0.isLetter || $0.isNumber } ?? ""
        let prefix = String(cleanEmail.prefix(5)).uppercased()
        return prefix.isEmpty ? "NV" : "NV\(prefix)"
    }
}

// MARK: - KTV MAP ANNOTATION WITH DETAILED CALLOUT
class KtvMapAnnotation: NSObject, MKAnnotation {
    let ktv: KtvOnlineLocation
    var coordinate: CLLocationCoordinate2D {
        ktv.coordinate
    }
    var title: String? {
        "\(ktv.isSpecialist ? "⭐" : "🛵") \(ktv.name)"
    }
    var subtitle: String? {
        let status = ktv.isOnline ? "🟢 Trực tuyến" : "⚪ Ngoại tuyến"
        let role = ktv.isSpecialist ? "Chuyên viên" : "KTV"
        let unit = ktv.unitName.isEmpty ? "IT TẬP TRUNG" : ktv.unitName
        let phone = ktv.phone.isEmpty ? "" : " • 📞 \(ktv.phone)"
        return "\(role) • \(unit) • \(status)\(phone)"
    }

    init(ktv: KtvOnlineLocation) {
        self.ktv = ktv
        super.init()
    }

    func renderMarkerImage(isSelected: Bool) -> UIImage {
        let size: CGFloat = isSelected ? 42 : 36
        let pillHeight: CGFloat = 20
        let totalHeight: CGFloat = size + pillHeight + 4
        let totalWidth: CGFloat = 110

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let cx = totalWidth / 2.0
            let cy = size / 2.0

            let colorHex: String
            if ktv.isScheduledOff && ktv.isOnline {
                colorHex = "#F59E0B"
            } else if ktv.isScheduledOff {
                colorHex = "#94A3B8"
            } else if ktv.isOnline {
                colorHex = "#10B981"
            } else if !ktv.todayShiftCode.isEmpty {
                colorHex = "#EF4444"
            } else {
                colorHex = "#64748B"
            }
            let uiColor = UIColor(hex: colorHex)

            // 1. Drop shadow
            cgCtx.setFillColor(UIColor.black.withAlphaComponent(0.25).cgColor)
            cgCtx.fillEllipse(in: CGRect(x: cx - size/2.0 + 2, y: cy - size/2.0 + 3, width: size - 4, height: size - 4))

            // 2. Pulse / outer ring if online
            if ktv.isOnline {
                cgCtx.setFillColor(uiColor.withAlphaComponent(0.28).cgColor)
                cgCtx.fillEllipse(in: CGRect(x: cx - size/2.0, y: cy - size/2.0, width: size, height: size))
            }

            // 3. Colored badge circle
            let badgeSize: CGFloat = isSelected ? 30 : 26
            let badgeRect = CGRect(x: cx - badgeSize/2.0, y: cy - badgeSize/2.0, width: badgeSize, height: badgeSize)
            cgCtx.setFillColor(uiColor.cgColor)
            cgCtx.fillEllipse(in: badgeRect)

            // 4. White border
            cgCtx.setStrokeColor(UIColor.white.cgColor)
            cgCtx.setLineWidth(2.5)
            cgCtx.strokeEllipse(in: badgeRect)

            // 5. Draw Icon Emoji (⭐ or 🛵)
            let emoji = ktv.isSpecialist ? "⭐" : "🛵"
            let emojiFont = UIFont.systemFont(ofSize: isSelected ? 15 : 13)
            let emojiAttrs: [NSAttributedString.Key: Any] = [
                .font: emojiFont
            ]
            let emojiSize = emoji.size(withAttributes: emojiAttrs)
            let emojiRect = CGRect(
                x: cx - emojiSize.width / 2.0,
                y: cy - emojiSize.height / 2.0,
                width: emojiSize.width,
                height: emojiSize.height
            )
            emoji.draw(in: emojiRect, withAttributes: emojiAttrs)

            // 6. Name pill below
            let rawName = ktv.name
            let displayName = rawName.count > 12 ? String(rawName.prefix(10)) + "…" : rawName
            let font = UIFont.systemFont(ofSize: 9.5, weight: isSelected ? .heavy : .bold)
            let textAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(hex: "#0F172A")
            ]
            let textSize = displayName.size(withAttributes: textAttrs)
            let padX: CGFloat = 8
            let pillWidth = min(totalWidth - 4, textSize.width + padX * 2)
            let pillRect = CGRect(x: cx - pillWidth / 2.0, y: size + 2, width: pillWidth, height: pillHeight)

            // Pill shadow & background
            let path = UIBezierPath(roundedRect: pillRect, cornerRadius: 5)
            cgCtx.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            path.fill()

            // Pill border
            cgCtx.setStrokeColor(isSelected ? UIColor(hex: "#002A8F").cgColor : uiColor.cgColor)
            cgCtx.setLineWidth(isSelected ? 1.5 : 0.8)
            path.stroke()

            // Pill text
            let textRect = CGRect(
                x: cx - textSize.width / 2.0,
                y: pillRect.midY - textSize.height / 2.0,
                width: textSize.width,
                height: textSize.height
            )
            displayName.draw(in: textRect, withAttributes: textAttrs)
        }
    }
}

// MARK: - GOOGLE MAPS KTV MONITOR VIEW (UIVIEWREPRESENTABLE)
struct KtvGoogleMapView: UIViewRepresentable {
    var ktvs: [KtvOnlineLocation]
    var selectedTech: KtvOnlineLocation?
    var onSelectTech: (KtvOnlineLocation) -> Void
    var fitBoundsTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.mapType = .standard

        let googleTileOverlay = GoogleMapsTileOverlay()
        mapView.addOverlay(googleTileOverlay, level: .aboveRoads)

        mapView.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009),
            span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        ), animated: false)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if !uiView.overlays.contains(where: { $0 is MKTileOverlay }) {
            let googleTileOverlay = GoogleMapsTileOverlay()
            uiView.addOverlay(googleTileOverlay, level: .aboveRoads)
        }

        uiView.removeAnnotations(uiView.annotations)
        var annotationsToAdd: [KtvMapAnnotation] = []
        for ktv in ktvs {
            if ktv.latitude != 0 && ktv.longitude != 0 {
                annotationsToAdd.append(KtvMapAnnotation(ktv: ktv))
            }
        }
        uiView.addAnnotations(annotationsToAdd)

        if context.coordinator.lastFitBoundsTrigger != fitBoundsTrigger {
            context.coordinator.lastFitBoundsTrigger = fitBoundsTrigger
            if !annotationsToAdd.isEmpty {
                uiView.showAnnotations(annotationsToAdd, animated: true)
            }
        }

        if let tech = selectedTech, tech.latitude != 0, tech.longitude != 0 {
            if context.coordinator.lastSelectedTechId != tech.id {
                context.coordinator.lastSelectedTechId = tech.id
                let region = MKCoordinateRegion(
                    center: tech.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                )
                uiView.setRegion(region, animated: true)
                if let targetAnnotation = annotationsToAdd.first(where: { $0.ktv.id == tech.id }) {
                    uiView.selectAnnotation(targetAnnotation, animated: true)
                }
            }
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KtvGoogleMapView
        var lastFitBoundsTrigger: Int = 0
        var lastSelectedTechId: String? = nil

        init(_ parent: KtvGoogleMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let ktvAnnotation = annotation as? KtvMapAnnotation else { return nil }
            let identifier = "KtvGoogleMapPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if view == nil {
                view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            let isSelected = ktvAnnotation.ktv.id == parent.selectedTech?.id
            view?.image = ktvAnnotation.renderMarkerImage(isSelected: isSelected)
            view?.centerOffset = CGPoint(x: 0, y: -(view?.image?.size.height ?? 36) / 2.0 + 10)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let ktvAnnotation = view.annotation as? KtvMapAnnotation {
                parent.onSelectTech(ktvAnnotation.ktv)
            }
        }
    }
}

// MARK: - MÀN HÌNH GIÁM SÁT KTV TRỰC TUYẾN (ĐỒNG BỘ 1:1 VỚI ANDROID ONLINEKTVMONITORSCREEN.KT)
public struct OnlineKtvMonitorView: View {
    @ObservedObject var supportVM: SupportViewModel
    var onBack: () -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    @State private var hasCenteredMapInitially = false
    @State private var fitBoundsTrigger: Int = 0

    // Real-time polling 30s
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // Tabs: 0: Trực tuyến, 1: Vi phạm / Blacklist
    @State private var selectedTab: Int = 0

    // Search & Filter state
    @State private var searchQuery: String = ""
    @State private var selectedCluster: String = "TẤT CẢ"
    @State private var selectedStatusFilter: String = "ALL"
    @State private var isMapVisible: Bool = true

    // Selection
    @State private var selectedKtv: KtvOnlineLocation? = nil
    @State private var selectedTechForMap: KtvOnlineLocation? = nil

    public init(supportVM: SupportViewModel, onBack: @escaping () -> Void) {
        self.supportVM = supportVM
        self.onBack = onBack
    }

    // MARK: - COMPUTED PROPERTIES
    private var onlineCount: Int {
        supportVM.ktvTechnicians.filter { $0.isOnline }.count
    }

    private var totalCount: Int {
        supportVM.ktvTechnicians.count
    }

    private var violationList: [KtvOnlineLocation] {
        supportVM.ktvTechnicians.filter { ($0.violationsThisMonth > 0 || $0.isBlacklisted) && !$0.isScheduledOff }
    }

    private var clusters: [String] {
        var set = Set<String>()
        for k in supportVM.ktvTechnicians {
            let kv = k.maKhuVuc.trimmingCharacters(in: .whitespacesAndNewlines)
            set.insert(kv.isEmpty ? "Khác" : kv)
        }
        return ["TẤT CẢ"] + set.sorted()
    }

    private var filteredList: [KtvOnlineLocation] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return supportVM.ktvTechnicians.filter { t in
            let matchSearch = q.isEmpty ||
                t.name.lowercased().contains(q) ||
                t.email.lowercased().contains(q) ||
                t.mnvDisplay.lowercased().contains(q) ||
                t.phone.lowercased().contains(q)

            let matchCluster: Bool
            if selectedCluster == "TẤT CẢ" {
                matchCluster = true
            } else if selectedCluster == "Khác" {
                matchCluster = t.maKhuVuc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else {
                matchCluster = t.maKhuVuc.caseInsensitiveCompare(selectedCluster) == .orderedSame
            }

            let matchStatus: Bool
            switch selectedStatusFilter {
            case "ONLINE":
                matchStatus = t.isOnline
            case "OFFLINE":
                matchStatus = !t.isOnline && !t.isScheduledOff
            case "ON_SHIFT":
                matchStatus = !t.isScheduledOff && !t.todayShiftCode.isEmpty
            case "SHIFT_S":
                matchStatus = t.todayShiftCode.uppercased() == "S"
            case "SHIFT_C":
                matchStatus = t.todayShiftCode.uppercased() == "C"
            case "OFF_DUTY":
                matchStatus = t.isScheduledOff
            case "VIOLATION":
                matchStatus = (t.violationsThisMonth > 0 || t.isBlacklisted) && !t.isScheduledOff
            default:
                matchStatus = true
            }

            return matchSearch && matchCluster && matchStatus
        }
    }

    private var ktvsWithLocation: [KtvOnlineLocation] {
        filteredList.filter { $0.latitude != 0 && $0.longitude != 0 }
    }

    // MARK: - BODY
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR ĐỒNG BỘ 1:1 VỚI ANDROID
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Giám Sát Online KTV")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Trực tuyến: \(onlineCount) / \(totalCount) KTV (KTV & Chuyên viên)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color(hex: "#86EFAC"))
                            }

                            Spacer()

                            // Toggle Bản đồ
                            Button(action: {
                                withAnimation(.spring()) {
                                    isMapVisible.toggle()
                                }
                            }) {
                                Image(systemName: isMapVisible ? "map.fill" : "map")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(.trailing, 4)

                            // Nút làm mới
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

                    // 2. BẢN ĐỒ ĐỊNH VỊ TỌA ĐỘ KTV / CHUYÊN VIÊN (GOOGLE MAPS 100%)
                    if isMapVisible && selectedTab == 0 {
                        ZStack(alignment: .topLeading) {
                            KtvGoogleMapView(
                                ktvs: ktvsWithLocation,
                                selectedTech: selectedTechForMap,
                                onSelectTech: { ktv in
                                    selectedTechForMap = ktv
                                    selectedKtv = ktv
                                },
                                fitBoundsTrigger: fitBoundsTrigger
                            )
                            .frame(height: 230)

                            // Overlay: Tag định vị KTV góc trên bên trái
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: "#10B981"))
                                    .frame(width: 8, height: 8)
                                Text("Định vị: \(ktvsWithLocation.count)/\(totalCount) KTV")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(Color.appTextPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.appSurface.opacity(0.92))
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.appCardBorder, lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.12), radius: 3)
                            .padding(8)

                            // Nút zoom fit all KTVs góc trên bên phải
                            VStack {
                                HStack {
                                    Spacer()
                                    if !ktvsWithLocation.isEmpty {
                                        Button(action: fitAllTechnicians) {
                                            Image(systemName: "dot.scope")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(Color.appTextPrimary)
                                                .padding(8)
                                                .background(Color.appSurface.opacity(0.92))
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.appCardBorder, lineWidth: 1))
                                                .shadow(color: Color.black.opacity(0.18), radius: 3)
                                        }
                                    }
                                }
                                .padding(8)
                                Spacer()
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // 3. TABS: TRỰC TUYẾN VS VI PHẠM / BLACKLIST
                    HStack(spacing: 0) {
                        tabButton(title: "Trực tuyến (\(onlineCount))", tabIndex: 0, isWarning: false)
                        tabButton(title: "Vi phạm / Blacklist (\(violationList.count))", tabIndex: 1, isWarning: true)
                    }
                    .background(Color.appSurface)

                    Divider()

                    // 4. THANH TÌM KIẾM & BỘ LỌC CỤM / TRẠNG THÁI
                    filterBar

                    // 5. NỘI DUNG DANH SÁCH (TAB 0 HOẶC TAB 1)
                    if supportVM.isLoadingKtvs && supportVM.ktvTechnicians.isEmpty {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Đang tải danh sách KTV...")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .padding()
                        Spacer()
                    } else if selectedTab == 0 {
                        // TAB 0: DANH SÁCH TRỰC TUYẾN
                        if filteredList.isEmpty {
                            emptyView(message: "Không tìm thấy Kỹ thuật viên phù hợp.")
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(filteredList) { ktv in
                                        ktvStatusCard(ktv: ktv)
                                            .onTapGesture {
                                                focusOnKtv(ktv)
                                            }
                                    }
                                }
                                .padding(12)
                            }
                        }
                    } else {
                        // TAB 1: BÁO CÁO VI PHẠM & BLACKLIST
                        ScrollView {
                            VStack(spacing: 12) {
                                // Banner cảnh báo giải thích
                                violationExplanationBanner

                                if violationList.isEmpty {
                                    VStack(spacing: 10) {
                                        Text("👏")
                                            .font(.system(size: 36))
                                        Text("Chưa có KTV nào vi phạm quy định Offline trong ca.")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    ForEach(violationList) { violator in
                                        violationCard(violator: violator)
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            supportVM.fetchKtvTechnicians()
            fitAllTechnicians()
        }
        .onReceive(timer) { _ in
            supportVM.fetchKtvTechnicians()
        }
        .onChange(of: supportVM.ktvTechnicians.count) { _ in
            if !hasCenteredMapInitially && !ktvsWithLocation.isEmpty {
                fitAllTechnicians()
                hasCenteredMapInitially = true
            }
        }
        .sheet(item: $selectedKtv) { ktv in
            KtvDetailSheet(ktv: ktv, supportVM: supportVM)
        }
    }

    // MARK: - ANNOTATION VIEW TRÊN BẢN ĐỒ
    @ViewBuilder
    private func annotationView(for ktv: KtvOnlineLocation) -> some View {
        let isSelected = selectedTechForMap?.id == ktv.id
        let statusInfo = getStatusInfo(for: ktv)

        Button(action: {
            selectedTechForMap = ktv
            selectedKtv = ktv
        }) {
            VStack(spacing: 2) {
                ZStack {
                    if ktv.isOnline {
                        Circle()
                            .fill(Color(hex: "#10B981").opacity(0.25))
                            .frame(width: isSelected ? 42 : 34, height: isSelected ? 42 : 34)
                    }
                    Circle()
                        .fill(statusInfo.dot)
                        .frame(width: isSelected ? 28 : 24, height: isSelected ? 28 : 24)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(color: Color.black.opacity(0.2), radius: 2)

                    Image(systemName: ktv.isSpecialist ? "star.fill" : "wrench.fill")
                        .font(.system(size: isSelected ? 11 : 9.5, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(ktv.name)
                    .font(.system(size: 9.5, weight: isSelected ? .heavy : .bold))
                    .foregroundColor(Color(hex: "#0F172A"))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color(hex: "#002A8F") : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5))
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - FOCUS VÀ FIT ALL VÀO BẢN ĐỒ
    private func focusOnKtv(_ ktv: KtvOnlineLocation) {
        selectedTechForMap = ktv
        if !isMapVisible {
            withAnimation(.spring()) {
                isMapVisible = true
            }
        }
        if ktv.latitude != 0 && ktv.longitude != 0 {
            withAnimation(.easeInOut(duration: 0.6)) {
                region = MKCoordinateRegion(
                    center: ktv.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                )
            }
        }
    }

    private func fitAllTechnicians() {
        fitBoundsTrigger += 1
        let valid = ktvsWithLocation
        guard !valid.isEmpty else { return }

        let lats = valid.map { $0.latitude }
        let lngs = valid.map { $0.longitude }

        let minLat = lats.min() ?? 10.7769
        let maxLat = lats.max() ?? 10.7769
        let minLng = lngs.min() ?? 106.7009
        let maxLng = lngs.max() ?? 106.7009

        let centerLat = (minLat + maxLat) / 2.0
        let centerLng = (minLng + maxLng) / 2.0

        let spanLat = max((maxLat - minLat) * 1.4, 0.06)
        let spanLng = max((maxLng - minLng) * 1.4, 0.06)

        withAnimation(.easeInOut(duration: 0.6)) {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
                span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLng)
            )
        }
    }

    // MARK: - TAB BUTTON
    @ViewBuilder
    private func tabButton(title: String, tabIndex: Int, isWarning: Bool) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tabIndex
            }
        }) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    if isWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#F59E0B"))
                    } else {
                        Circle()
                            .fill(Color(hex: "#10B981"))
                            .frame(width: 8, height: 8)
                    }

                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(selectedTab == tabIndex ? Color.appPrimary : Color.appTextSecondary)
                }
                .padding(.top, 10)

                Rectangle()
                    .fill(selectedTab == tabIndex ? Color.appPrimary : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - THANH TÌM KIẾM & BỘ LỌC
    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 8) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.appTextSecondary)
                    .font(.system(size: 14))

                TextField("Tìm theo tên / MNV / email...", text: $searchQuery)
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextPrimary)

                if !searchQuery.isEmpty {
                    Button(action: { searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.appTextMuted)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.appSurface)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 0.8))

            // Cluster filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Cụm:")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)

                    ForEach(clusters, id: \.self) { cl in
                        chipButton(
                            title: cl,
                            isSelected: selectedCluster == cl,
                            onTap: { selectedCluster = cl }
                        )
                    }
                }
            }

            // Status filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Text("Trạng thái:")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(Color.appTextSecondary)

                    let statusList: [(String, String)] = [
                        ("ALL", "Tất cả"),
                        ("ONLINE", "🟢 Online"),
                        ("ON_SHIFT", "⏱️ Trong ca"),
                        ("SHIFT_S", "Ca S"),
                        ("SHIFT_C", "Ca C"),
                        ("OFF_DUTY", "⚪ Nghỉ ca"),
                        ("VIOLATION", "⚠️ Vi phạm")
                    ]

                    ForEach(statusList, id: \.0) { item in
                        chipButton(
                            title: item.1,
                            isSelected: selectedStatusFilter == item.0,
                            onTap: { selectedStatusFilter = item.0 }
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.appSurfaceVariant)
    }

    @ViewBuilder
    private func chipButton(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color.appTextPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.appPrimary : Color.appSurface)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.appPrimary : Color.appCardBorder, lineWidth: 0.8)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - KTV STATUS CARD (TAB 0)
    @ViewBuilder
    private func ktvStatusCard(ktv: KtvOnlineLocation) -> some View {
        let isSelected = selectedTechForMap?.id == ktv.id
        let isBlacklist = ktv.isBlacklisted || ktv.violationsThisMonth >= 5
        let statusInfo = getStatusInfo(for: ktv)
        let shiftInfo = getShiftInfo(for: ktv.todayShiftCode)

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                // ROW 1: Status dot, Name, Badges, Status pill
                HStack(alignment: .center, spacing: 10) {
                    // Status dot
                    ZStack {
                        Circle()
                            .fill(statusInfo.dot)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(ktv.isOnline ? Color(hex: "#D1FAE5") : Color(hex: "#E2E8F0"), lineWidth: 2)
                            .frame(width: 14, height: 14)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(ktv.name)
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundColor(Color.appTextPrimary)
                                .lineLimit(1)

                            // Role badge
                            Text(ktv.isSpecialist ? "Chuyên viên" : "KTV")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(ktv.isSpecialist ? Color.dynamic(light: "#7E22CE", dark: "#D8B4FE") : Color.dynamic(light: "#0369A1", dark: "#7DD3FC"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(ktv.isSpecialist ? Color.dynamic(light: "#F3E8FF", dark: "#3B0764") : Color.dynamic(light: "#E0F2FE", dark: "#0C4A6E"))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(ktv.isSpecialist ? Color(hex: "#D8B4FE").opacity(0.4) : Color(hex: "#BAE6FD").opacity(0.4), lineWidth: 1))

                            // Blacklist tag
                            if ktv.isBlacklisted {
                                Text("Blacklist")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: "#DC2626"))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.dynamic(light: "#FEE2E2", dark: "#450A0A"))
                                    .cornerRadius(4)
                            }
                        }

                        // MNV & Phone
                        HStack(spacing: 6) {
                            Text("MNV: \(ktv.mnvDisplay)")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(Color.dynamic(light: "#1D4ED8", dark: "#93C5FD"))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.dynamic(light: "#EFF6FF", dark: "#1E293B"))
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.dynamic(light: "#BFDBFE", dark: "#334155"), lineWidth: 0.8))

                            if !ktv.phone.isEmpty {
                                Text("• 📞 \(ktv.phone)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                        }

                        Text(ktv.email)
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status Pill
                    Text(statusInfo.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(statusInfo.fg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusInfo.bg)
                        .cornerRadius(6)
                }

                Divider()

                // ROW 2: Shift badge & Last active time
                HStack {
                    Text("📅 \(shiftInfo.desc)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(shiftInfo.fg)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(shiftInfo.bg)
                        .cornerRadius(4)

                    Spacer()

                    if ktv.isScheduledOff {
                        Text("✓ Nghỉ ca")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(Color.dynamic(light: "#16A34A", dark: "#4ADE80"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dynamic(light: "#F0FDF4", dark: "#052E16"))
                            .cornerRadius(4)
                    } else if ktv.lastActiveAt > 0 {
                        Text(ktv.isOnline ? "🟢 \(ktv.lastSeen)" : "⚪ \(ktv.lastSeen)")
                            .font(.system(size: 11))
                            .foregroundColor(ktv.isOnline ? Color.dynamic(light: "#059669", dark: "#34D399") : Color.appTextSecondary)
                    }
                }

                // ROW 3: Cluster & Unit Tags & Location pill
                HStack(spacing: 6) {
                    Text("🎯 Cụm: \(ktv.maKhuVuc.isEmpty ? "Chưa gán" : ktv.maKhuVuc)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.dynamic(light: "#0369A1", dark: "#38BDF8"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.dynamic(light: "#E0F2FE", dark: "#0C4A6E"))
                        .cornerRadius(4)

                    Text("🏢 \(ktv.unitName.isEmpty ? "IT TẬP TRUNG" : ktv.unitName)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appSurfaceVariant)
                        .cornerRadius(4)

                    Spacer()

                    if ktv.latitude != 0 && ktv.longitude != 0 {
                        Text("📍 Định vị")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.dynamic(light: "#166534", dark: "#86EFAC"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.dynamic(light: "#DCFCE7", dark: "#14532D"))
                            .cornerRadius(4)
                    }

                    // Nút xem chi tiết
                    Button(action: { selectedKtv = ktv }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15))
                            .foregroundColor(Color.appPrimaryPink)
                    }
                }
            }
            .padding(12)
            .background(Color.appSurface)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.appPrimaryPink :
                        (isBlacklist ? Color(hex: "#EF4444") :
                         (ktv.isOnline ? Color(hex: "#10B981").opacity(0.5) : Color.appCardBorder)),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        }
    }

    // MARK: - BANNER GIẢI THÍCH VI PHẠM (TAB 1)
    @ViewBuilder
    private var violationExplanationBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color.dynamic(light: "#D97706", dark: "#F59E0B"))
                .font(.system(size: 18))

            VStack(alignment: .leading, spacing: 4) {
                Text("BÁO CÁO VI PHẠM & BLACKLIST (CHỈ TRÌNH LÃNH ĐẠO)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.dynamic(light: "#92400E", dark: "#FCD34D"))

                Text("• Offline > 15 phút: Cảnh báo vắng mặt.\n• ≥ 3 lần/tháng: Đề xuất trừ KPI định kỳ.\n• ≥ 5 lần/tháng: Đưa vào danh sách Blacklist.\n• Danh sách Blacklist chỉ gửi Lãnh đạo ra quyết định, không tự động khóa tài khoản app.")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.dynamic(light: "#B45309", dark: "#FDE68A"))
                    .lineSpacing(2)
            }
        }
        .padding(12)
        .background(Color.dynamic(light: "#FEF3C7", dark: "#451A03").opacity(0.7))
        .cornerRadius(8)
    }

    // MARK: - VIOLATION CARD (TAB 1)
    @ViewBuilder
    private func violationCard(violator: KtvOnlineLocation) -> some View {
        let isBlacklist = violator.isBlacklisted || violator.violationsThisMonth >= 5

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: isBlacklist ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(isBlacklist ? Color(hex: "#E11D48") : Color(hex: "#D97706"))
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(violator.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        Text("MNV: \(violator.mnvDisplay)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.dynamic(light: "#1D4ED8", dark: "#93C5FD"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.dynamic(light: "#EFF6FF", dark: "#1E293B"))
                            .cornerRadius(4)
                    }

                    Text("🎯 Cụm: \(violator.maKhuVuc.isEmpty ? "Chưa gán" : violator.maKhuVuc) • 🏢 \(violator.unitName.isEmpty ? "IT TẬP TRUNG" : violator.unitName)" + (!violator.phone.isEmpty ? " • 📞 \(violator.phone)" : ""))
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }

                Spacer()

                Text(isBlacklist ? "ĐỀ XUẤT BLACKLIST" : "TRỪ KPI")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isBlacklist ? Color(hex: "#E11D48") : Color(hex: "#D97706"))
                    .cornerRadius(4)
            }

            Text("Email: \(violator.email)")
                .font(.system(size: 11.5))
                .foregroundColor(Color.appTextSecondary)

            Text("Số lần offline trong ca tháng này: \(violator.violationsThisMonth) lần")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isBlacklist ? Color.dynamic(light: "#BE123C", dark: "#FDA4AF") : Color.dynamic(light: "#B45309", dark: "#FCD34D"))

            Text("📌 Báo cáo gửi Lãnh đạo xem xét và ra quyết định xử lý.")
                .font(.system(size: 11))
                .foregroundColor(Color.appTextSecondary)
        }
        .padding(12)
        .background(isBlacklist ? Color.dynamic(light: "#FFF1F2", dark: "#4C0519").opacity(0.6) : Color.dynamic(light: "#FFFBEB", dark: "#451A03").opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isBlacklist ? Color.dynamic(light: "#FECDD3", dark: "#881337") : Color.dynamic(light: "#FDE68A", dark: "#78350F"), lineWidth: 1)
        )
    }

    // MARK: - EMPTY VIEW
    @ViewBuilder
    private func emptyView(message: String) -> some View {
        Spacer()
        Image(systemName: "person.2.slash")
            .font(.system(size: 44))
            .foregroundColor(.gray)
        Text(message)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gray)
            .padding()
        Spacer()
    }

    // MARK: - HELPER METHODS FOR STATUS & SHIFT
    private func getStatusInfo(for tech: KtvOnlineLocation) -> (label: String, bg: Color, fg: Color, dot: Color) {
        if tech.isScheduledOff && tech.isOnline {
            return ("⭐ TĂNG CƯỜNG", Color(hex: "#FEF3C7"), Color(hex: "#B45309"), Color(hex: "#F59E0B"))
        } else if tech.isScheduledOff {
            return ("⚪ NGHỈ CA", Color(hex: "#F1F5F9"), Color(hex: "#64748B"), Color(hex: "#94A3B8"))
        } else if tech.isOnline {
            return ("ONLINE", Color(hex: "#DCFCE7"), Color(hex: "#166534"), Color(hex: "#10B981"))
        } else if !tech.todayShiftCode.isEmpty {
            return ("🔴 VẮNG CA", Color(hex: "#FEE2E2"), Color(hex: "#B91C1C"), Color(hex: "#DC2626"))
        } else {
            return ("OFFLINE", Color(hex: "#F1F5F9"), Color(hex: "#64748B"), Color(hex: "#94A3B8"))
        }
    }

    private func getShiftInfo(for code: String) -> (desc: String, bg: Color, fg: Color) {
        switch code.uppercased() {
        case "S": return ("Ca S (06-14h)", Color(hex: "#FEF3C7"), Color(hex: "#B45309"))
        case "C": return ("Ca C (14-22h)", Color(hex: "#E0F2FE"), Color(hex: "#0284C7"))
        case "HC": return ("Ca HC (08-17h)", Color(hex: "#F3E8FF"), Color(hex: "#7E22CE"))
        case "TR": return ("Ca TRỰC", Color(hex: "#FFEDD5"), Color(hex: "#C2410C"))
        case "OFF", "NC": return ("Nghỉ Ca", Color(hex: "#F1F5F9"), Color(hex: "#64748B"))
        case "P": return ("Nghỉ Phép", Color(hex: "#FCE7F3"), Color(hex: "#BE185D"))
        case "NM": return ("Nghỉ Mát", Color(hex: "#DCFCE7"), Color(hex: "#15803D"))
        case "NL": return ("Nghỉ Lễ", Color(hex: "#FEF9C3"), Color(hex: "#854D0E"))
        case "": return ("Chưa xếp ca", Color(hex: "#F8FAFC"), Color(hex: "#94A3B8"))
        default: return ("Ca \(code)", Color(hex: "#F1F5F9"), Color(hex: "#475569"))
        }
    }
}

// MARK: - KTV DETAIL SHEET
struct KtvDetailSheet: View {
    let ktv: KtvOnlineLocation
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var supportVM: SupportViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ktv.isOnline ? Color(hex: "#10B981") : Color(hex: "#64748B"))
                        .frame(width: 58, height: 58)
                    Image(systemName: ktv.isSpecialist ? "star.fill" : "person.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(ktv.name)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color.appTextPrimary)

                        Text(ktv.isSpecialist ? "Chuyên viên" : "KTV")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(ktv.isSpecialist ? Color.dynamic(light: "#7E22CE", dark: "#D8B4FE") : Color.dynamic(light: "#0369A1", dark: "#7DD3FC"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ktv.isSpecialist ? Color.dynamic(light: "#F3E8FF", dark: "#3B0764") : Color.dynamic(light: "#E0F2FE", dark: "#0C4A6E"))
                            .cornerRadius(4)
                    }

                    Text(ktv.isOnline ? "🟢 Đang trực tuyến" : "⚪ Ngoại tuyến (\(ktv.lastSeen))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(ktv.isOnline ? Color(hex: "#10B981") : Color.appTextSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    detailRow(icon: "creditcard", title: "Mã nhân viên", value: ktv.mnvDisplay)
                    detailRow(icon: "envelope", title: "Email", value: ktv.email)
                    detailRow(icon: "phone", title: "Số điện thoại", value: ktv.phone.isEmpty ? "Chưa cập nhật" : ktv.phone)
                    detailRow(icon: "building.2", title: "Đơn vị", value: ktv.unitName.isEmpty ? "IT TẬP TRUNG" : ktv.unitName)
                    detailRow(icon: "mappin.and.ellipse", title: "Cụm / Khu vực", value: ktv.maKhuVuc.isEmpty ? "Chưa gán" : ktv.maKhuVuc)
                    detailRow(icon: "calendar", title: "Ca trực hôm nay", value: ktv.todayShiftCode.isEmpty ? "Chưa xếp ca" : "Ca \(ktv.todayShiftCode)")
                    if ktv.latitude != 0 && ktv.longitude != 0 {
                        detailRow(icon: "location.fill", title: "Tọa độ GPS", value: String(format: "%.4f, %.4f", ktv.latitude, ktv.longitude))
                    }
                    if ktv.violationsThisMonth > 0 {
                        detailRow(icon: "exclamationmark.triangle", title: "Vi phạm offline", value: "\(ktv.violationsThisMonth) lần")
                    }
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 12) {
                Button(action: { callKtv() }) {
                    HStack {
                        Image(systemName: "phone.fill")
                        Text("Gọi điện")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ktv.phone.isEmpty ? Color.gray : Color(hex: "#10B981"))
                    .cornerRadius(10)
                }
                .disabled(ktv.phone.isEmpty)

                Button(action: { routeToKtv() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Chỉ đường")
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background((ktv.latitude == 0 && ktv.longitude == 0) ? Color.gray : Color.appSecondaryDarkBlue)
                    .cornerRadius(10)
                }
                .disabled(ktv.latitude == 0 && ktv.longitude == 0)
            }
            .padding(16)
        }
        .background(Color.appSurface)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color.appTextSecondary)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 13.5))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
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
