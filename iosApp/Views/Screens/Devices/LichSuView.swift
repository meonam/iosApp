import SwiftUI

// MARK: - MÀN HÌNH NHẬT KÝ THIẾT BỊ (ĐỒNG BỘ 1:1 VỚI LICHSUTHIETBISCREEN.KT TRÊN ANDROID)
public struct LichSuView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var companyIdOverride: String? = nil
    var idTokenOverride: String? = nil
    var thietBiId: String
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var tenThietBi: String = ""
    @State private var lichSuList: [LichSuThietBi] = []
    @State private var isNewestFirst: Bool = true
    @State private var isLoading: Bool = false
    @State private var showScanner: Bool = false

    public init(authViewModel: AuthViewModel, thietBiId: String, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.companyIdOverride = nil
        self.idTokenOverride = nil
        self.thietBiId = thietBiId
        self.onBack = onBack
        _searchQuery = State(initialValue: thietBiId)
    }

    public init(companyId: String, idToken: String, thietBiId: String, onBack: @escaping () -> Void) {
        self.authViewModel = AuthViewModel()
        self.companyIdOverride = companyId
        self.idTokenOverride = idToken
        self.thietBiId = thietBiId
        self.onBack = onBack
        _searchQuery = State(initialValue: thietBiId)
    }

    private var effectiveCompanyId: String {
        companyIdOverride ?? authViewModel.currentCompanyId
    }

    private var effectiveIdToken: String {
        idTokenOverride ?? authViewModel.currentIdToken
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Nhật Ký Thiết Bị")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.appTopBarColor)

                    VStack(spacing: 12) {
                        // Search Bar with scanner button
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Color.appTextSecondary)
                            TextField("Mã thiết bị", text: $searchQuery)
                                .font(.system(size: 14))
                                .onSubmit {
                                    fetchLichSu(thietBiId: searchQuery)
                                }
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Color.appTextSecondary)
                                }
                            }
                            Button(action: { showScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color.appPrimaryPink)
                            }
                        }
                        .padding(10)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appCardBorder, lineWidth: 1))

                        if !tenThietBi.isEmpty {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text("Lịch sử thiết bị: \(tenThietBi) (\(searchQuery))")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.appSecondaryDarkBlue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Sắp xếp
                        HStack {
                            Text("DÒNG THỜI GIAN")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            Spacer()

                            Menu {
                                Button("Mới nhất trước") {
                                    isNewestFirst = true
                                    sortList()
                                }
                                Button("Cũ nhất trước") {
                                    isNewestFirst = false
                                    sortList()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(isNewestFirst ? "Mới nhất" : "Cũ nhất")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSecondaryDarkBlue, lineWidth: 1))
                            }
                        }

                        // List
                        if isLoading {
                            Spacer()
                            ProgressView("Đang tải nhật ký...")
                            Spacer()
                        } else if lichSuList.isEmpty {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.appTextSecondary)
                                Text("Chưa có dữ liệu nhật ký")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.appTextSecondary)
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 10) {
                                    ForEach(lichSuList) { item in
                                        timelineCard(item)
                                    }
                                }
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    .padding(14)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            fetchLichSu(thietBiId: thietBiId)
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView(
                onScanResult: { scannedCode in
                    self.searchQuery = scannedCode
                    self.showScanner = false
                    self.fetchLichSu(thietBiId: scannedCode)
                },
                onDismiss: { self.showScanner = false }
            )
        }
    }

    private func timelineCard(_ item: LichSuThietBi) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("📅 \(item.ngay.isEmpty ? "Ghi nhận" : item.ngay)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                Spacer()
                Text(item.hanhDong)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.appSecondaryDarkBlue.opacity(0.1))
                    .cornerRadius(6)
            }

            if !item.thietBiId.isEmpty {
                Text("🏷️ Mã TB: \(item.thietBiId)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
            }

            if !item.donVi.isEmpty {
                Text("🏢 Đơn vị: \(item.donVi)")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appTextSecondary)
            }

            if !item.moTa.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 11))
                        .foregroundColor(Color.dynamic(light: "#E65100", dark: "#FDBA74"))
                    Text(item.moTa)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.dynamic(light: "#E65100", dark: "#FDBA74"))
                }
                .padding(8)
                .background(Color.dynamic(light: "#FFF3E0", dark: "#3D2403"))
                .cornerRadius(8)
            }

            if !item.nguoiThucHien.isEmpty {
                Text("👤 Thực hiện: \(item.nguoiThucHien)")
                    .font(.system(size: 11))
                    .foregroundColor(Color.appTextSecondary)
            }
        }
        .padding(12)
        .background(Color.appSurface)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }

    private func sortList() {
        if isNewestFirst {
            lichSuList.sort { $0.timestamp > $1.timestamp }
        } else {
            lichSuList.sort { $0.timestamp < $1.timestamp }
        }
    }

    private func fetchLichSu(thietBiId: String) {
        self.isLoading = true
        let companyId = effectiveCompanyId

        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/history?pageSize=300"
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !effectiveIdToken.isEmpty {
            request.setValue("Bearer \(effectiveIdToken)", forHTTPHeaderField: "Authorization")
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else { return }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let documents = json["documents"] as? [[String: Any]] {

                        var results: [LichSuThietBi] = []
                        let targetId = thietBiId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                        for doc in documents {
                            if let fields = doc["fields"] as? [String: Any] {
                                let docThietBiId = {
                                    let id1 = FirestoreHelper.getString(fields["thietBiId"] as? [String: Any])
                                    if !id1.isEmpty { return id1 }
                                    return FirestoreHelper.getString(fields["deviceId"] as? [String: Any])
                                }()

                                let matchesTarget = targetId.isEmpty ||
                                    docThietBiId.lowercased().contains(targetId) ||
                                    targetId.contains(docThietBiId.lowercased())

                                if matchesTarget {
                                    let id = (doc["name"] as? String)?.components(separatedBy: "/").last ?? UUID().uuidString
                                    let ngay = {
                                        let n1 = FirestoreHelper.getString(fields["ngayBaoHanh"] as? [String: Any])
                                        if !n1.isEmpty { return n1 }
                                        let n2 = FirestoreHelper.getString(fields["ngay"] as? [String: Any])
                                        if !n2.isEmpty { return n2 }
                                        return FirestoreHelper.getString(fields["date"] as? [String: Any])
                                    }()
                                    let hanhDong = {
                                        let h1 = FirestoreHelper.getString(fields["hanhDong"] as? [String: Any])
                                        if !h1.isEmpty { return h1 }
                                        let h2 = FirestoreHelper.getString(fields["action"] as? [String: Any])
                                        return !h2.isEmpty ? h2 : "BẢO HÀNH"
                                    }()
                                    let donVi = {
                                        let d1 = FirestoreHelper.getString(fields["donVi"] as? [String: Any])
                                        if !d1.isEmpty { return d1 }
                                        return FirestoreHelper.getString(fields["department"] as? [String: Any])
                                    }()
                                    let moTa = {
                                        let m1 = FirestoreHelper.getString(fields["moTa"] as? [String: Any])
                                        if !m1.isEmpty { return m1 }
                                        return FirestoreHelper.getString(fields["note"] as? [String: Any])
                                    }()
                                    let nguoiThucHien = {
                                        let r1 = FirestoreHelper.getString(fields["role"] as? [String: Any])
                                        let p1 = FirestoreHelper.getString(fields["performedBy"] as? [String: Any])
                                        if !r1.isEmpty && !p1.isEmpty { return "\(p1) (\(r1))" }
                                        if !p1.isEmpty { return p1 }
                                        return r1
                                    }()
                                    let created = FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any])
                                    let timestamp = created > 0 ? Double(created) : FirestoreHelper.getDouble(fields["timestamp"] as? [String: Any])
                                    let name = {
                                        let name1 = FirestoreHelper.getString(fields["tenThietBi"] as? [String: Any])
                                        if !name1.isEmpty { return name1 }
                                        return FirestoreHelper.getString(fields["deviceName"] as? [String: Any])
                                    }()

                                    if !name.isEmpty && self.tenThietBi.isEmpty {
                                        self.tenThietBi = name
                                    }

                                    results.append(LichSuThietBi(
                                        id: id,
                                        thietBiId: docThietBiId,
                                        tenThietBi: name,
                                        hanhDong: hanhDong,
                                        ngay: ngay,
                                        nguoiThucHien: nguoiThucHien,
                                        moTa: moTa,
                                        donVi: donVi,
                                        timestamp: timestamp
                                    ))
                                }
                            }
                        }

                        self.lichSuList = results
                        self.sortList()
                    }
                } catch {
                    print("Error parsing JSON: \(error)")
                }
            }
        }.resume()
    }
}
