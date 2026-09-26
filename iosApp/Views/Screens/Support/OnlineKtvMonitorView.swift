import SwiftUI
import MapKit

// MARK: - MODEL KTV
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

    public var displayCoordinate: CLLocationCoordinate2D {
        if latitude != 0 && longitude != 0 {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        // Mock coordinate based on email hash around HCMC for demonstration
        let hash = abs(email.hashValue)
        let latOffset = (Double(hash % 100) / 100.0 - 0.5) * 0.1
        let lonOffset = (Double((hash / 100) % 100) / 100.0 - 0.5) * 0.1
        return CLLocationCoordinate2D(latitude: 10.7769 + latOffset, longitude: 106.7009 + lonOffset)
    }
}

// MARK: - MÀN HÌNH GIÁM SÁT KTV TRỰC TUYẾN
public struct OnlineKtvMonitorView: View {
    @ObservedObject var supportVM: SupportViewModel
    var onBack: () -> Void

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )

    @State private var viewMode: Int = 0 // 0: Bản đồ, 1: Danh sách
    @State private var searchQuery: String = ""
    @State private var selectedRegion: String = "Tất cả"
    @State private var selectedStatus: String = "Tất cả"
    @State private var selectedUnit: String = "Tất cả"
    
    @State private var selectedKtv: KtvOnlineLocation? = nil
    @State private var showBottomSheet: Bool = false

    // Real-time polling
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    public init(supportVM: SupportViewModel, onBack: @escaping () -> Void) {
        self.supportVM = supportVM
        self.onBack = onBack
    }

    private var regions: [String] {
        var list = supportVM.ktvTechnicians.map { $0.maKhuVuc.isEmpty ? "Khác" : $0.maKhuVuc }
        list = Array(Set(list)).sorted()
        list.insert("Tất cả", at: 0)
        return list
    }

    private var units: [String] {
        var list = supportVM.ktvTechnicians.map { $0.unitName.isEmpty ? "Khác" : $0.unitName }
        list = Array(Set(list)).sorted()
        list.insert("Tất cả", at: 0)
        return list
    }

    private var filteredKtvs: [KtvOnlineLocation] {
        supportVM.ktvTechnicians.filter { ktv in
            let matchSearch = searchQuery.isEmpty || 
                ktv.name.localizedCaseInsensitiveContains(searchQuery) || 
                ktv.email.localizedCaseInsensitiveContains(searchQuery) || 
                ktv.maNhanVien.localizedCaseInsensitiveContains(searchQuery)
            
            let kv = ktv.maKhuVuc.isEmpty ? "Khác" : ktv.maKhuVuc
            let matchRegion = selectedRegion == "Tất cả" || kv == selectedRegion
            
            let un = ktv.unitName.isEmpty ? "Khác" : ktv.unitName
            let matchUnit = selectedUnit == "Tất cả" || un == selectedUnit
            
            let matchStatus: Bool
            switch selectedStatus {
            case "Online": matchStatus = ktv.isOnline
            case "Offline": matchStatus = !ktv.isOnline
            default: matchStatus = true
            }
            
            return matchSearch && matchRegion && matchUnit && matchStatus
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Giám sát KTV Online")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                let online = supportVM.ktvTechnicians.filter { $0.isOnline }.count
                                let total = supportVM.ktvTechnicians.count
                                Text("Trực tuyến: \(online)/\(total)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.green)
                            }
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
                    .background(Color.appPrimary)

                    // 2. VIEW MODE TAB (Bản đồ / Danh sách)
                    HStack(spacing: 0) {
                        Button(action: { viewMode = 0 }) {
                            Text("Bản đồ")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewMode == 0 ? Color.appPrimary : Color.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Rectangle()
                                        .fill(viewMode == 0 ? Color.appPrimary : Color.clear)
                                        .frame(height: 2)
                                        .padding(.horizontal, 20),
                                    alignment: .bottom
                                )
                        }
                        Button(action: { viewMode = 1 }) {
                            Text("Danh sách")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(viewMode == 1 ? Color.appPrimary : Color.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Rectangle()
                                        .fill(viewMode == 1 ? Color.appPrimary : Color.clear)
                                        .frame(height: 2)
                                        .padding(.horizontal, 20),
                                    alignment: .bottom
                                )
                        }
                    }
                    .background(Color.white)
                    .overlay(Divider(), alignment: .bottom)

                    // 3. FILTER & SEARCH
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Tìm tên, email, MNV...", text: $searchQuery)
                                .font(.system(size: 14))
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(8)
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterPicker(title: "Trạng thái", selection: $selectedStatus, options: ["Tất cả", "Online", "Offline"])
                                filterPicker(title: "Khu vực", selection: $selectedRegion, options: regions)
                                filterPicker(title: "Đơn vị", selection: $selectedUnit, options: units)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.white)
                    .overlay(Divider(), alignment: .bottom)

                    // 4. MAIN CONTENT
                    if supportVM.isLoadingKtvs && supportVM.ktvTechnicians.isEmpty {
                        Spacer()
                        ProgressView().scaleEffect(1.2)
                        Spacer()
                    } else if viewMode == 0 {
                        // MAP VIEW
                        ZStack(alignment: .bottom) {
                            Map(coordinateRegion: $mapRegion, annotationItems: filteredKtvs) { ktv in
                                MapAnnotation(coordinate: ktv.displayCoordinate) {
                                    Button(action: {
                                        selectedKtv = ktv
                                        showBottomSheet = true
                                    }) {
                                        VStack(spacing: 2) {
                                            Image(systemName: ktv.isOnline ? "person.crop.circle.fill" : "person.crop.circle")
                                                .font(.system(size: 28))
                                                .foregroundColor(ktv.isOnline ? .green : .gray)
                                                .background(Circle().fill(Color.white))
                                                .shadow(radius: 2)
                                            
                                            Text(ktv.name)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.black)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.85))
                                                .cornerRadius(4)
                                                .shadow(radius: 1)
                                        }
                                    }
                                }
                            }
                            
                            // Bottom Sheet
                            if showBottomSheet, let ktv = selectedKtv {
                                ktvBottomSheet(ktv: ktv)
                                    .transition(.move(edge: .bottom))
                                    .animation(.spring(), value: showBottomSheet)
                            }
                        }
                    } else {
                        // LIST VIEW
                        if filteredKtvs.isEmpty {
                            Spacer()
                            Text("Không tìm thấy KTV nào").foregroundColor(.gray)
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredKtvs) { ktv in
                                        ktvListCard(ktv: ktv)
                                            .onTapGesture {
                                                selectedKtv = ktv
                                                showBottomSheet = true
                                                viewMode = 0
                                            }
                                    }
                                }
                                .padding(12)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            supportVM.fetchKtvTechnicians()
        }
        .onReceive(timer) { _ in
            supportVM.fetchKtvTechnicians()
        }
    }

    // MARK: - COMPONENT HELPER

    @ViewBuilder
    private func filterPicker(title: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(action: { selection.wrappedValue = opt }) {
                    HStack {
                        Text(opt)
                        if selection.wrappedValue == opt {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("\(title): \(selection.wrappedValue)")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selection.wrappedValue != "Tất cả" ? Color.appPrimary.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            .foregroundColor(selection.wrappedValue != "Tất cả" ? Color.appPrimary : .primary)
            .cornerRadius(16)
        }
    }

    @ViewBuilder
    private func ktvBottomSheet(ktv: KtvOnlineLocation) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                Spacer()
            }
            
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(ktv.isOnline ? Color.green : Color.gray)
                        .frame(width: 56, height: 56)
                    Image(systemName: "wrench.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(ktv.name)
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        Text("MNV: \(ktv.maNhanVien.isEmpty ? "N/A" : ktv.maNhanVien)")
                        Text("•")
                        Text(ktv.phone.isEmpty ? "N/A" : ktv.phone)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(ktv.maKhuVuc.isEmpty ? "Không rõ" : ktv.maKhuVuc)
                        Text("•")
                        Text(ktv.unitName.isEmpty ? "Không rõ" : ktv.unitName)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color.appPrimary)
                    
                    HStack {
                        Circle()
                            .fill(ktv.isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(ktv.isOnline ? "Đang trực tuyến" : "Ngoại tuyến: \(ktv.lastSeen)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(ktv.isOnline ? .green : .gray)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                Button(action: { showBottomSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                }
            }
            .padding(20)
        }
        .background(Color.white)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.15), radius: 10, y: -2)
    }

    @ViewBuilder
    private func ktvListCard(ktv: KtvOnlineLocation) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ktv.isOnline ? Color.green : Color.gray)
                    .frame(width: 48, height: 48)
                Image(systemName: "wrench.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ktv.name)
                    .font(.system(size: 15, weight: .bold))
                
                HStack {
                    Text(ktv.unitName.isEmpty ? "Khác" : ktv.unitName)
                    Text("•")
                    Text(ktv.maKhuVuc.isEmpty ? "Khác" : ktv.maKhuVuc)
                }
                .font(.system(size: 12))
                .foregroundColor(.gray)
                
                if !ktv.phone.isEmpty {
                    Text(ktv.phone)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(ktv.isOnline ? "ONLINE" : "OFFLINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ktv.isOnline ? .green : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((ktv.isOnline ? Color.green : Color.gray).opacity(0.15))
                    .cornerRadius(8)
                
                Text(ktv.lastSeen)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
