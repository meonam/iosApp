import SwiftUI

// LichSuThietBi model is defined in DeviceModels.swift

public struct LichSuView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var thietBiId: String
    var onBack: () -> Void

    @State private var searchQuery: String = ""
    @State private var tenThietBi: String = ""
    @State private var lichSuList: [LichSuThietBi] = []
    @State private var isNewestFirst: Bool = true
    @State private var isLoading: Bool = false

    public init(authViewModel: AuthViewModel, thietBiId: String, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.thietBiId = thietBiId
        self.onBack = onBack
        _searchQuery = State(initialValue: thietBiId)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            Text("Nhật Ký Thiết Bị")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor) // Assuming appTopBarColor is equivalent to TopBarColor or appPrimary

                    VStack(spacing: 16) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Mã thiết bị", text: $searchQuery)
                                .textFieldStyle(PlainTextFieldStyle())
                                .onSubmit {
                                    fetchLichSu(thietBiId: searchQuery)
                                }
                            Button(action: {
                                // Mở camera scan QR (mock action)
                            }) {
                                Image(systemName: "qrcode.viewfinder")
                                    .foregroundColor(Color.appPrimaryPink) // App colors
                            }
                        }
                        .padding(12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))

                        if !tenThietBi.isEmpty {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text("Lịch sử thiết bị: \(tenThietBi) (\(searchQuery))")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.appSecondaryDarkBlue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // Sắp xếp
                        HStack {
                            Text("DÒNG THỜI GIAN")
                                .font(.system(size: 14, weight: .bold))
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
                                HStack {
                                    Text(isNewestFirst ? "Mới nhất" : "Cũ nhất")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSecondaryDarkBlue, lineWidth: 1))
                            }
                        }

                        // List
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if lichSuList.isEmpty {
                            VStack {
                                Spacer()
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                                Text("Chưa có dữ liệu nhật ký")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                Spacer()
                            }
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(lichSuList) { item in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("📅 \(item.ngay.isEmpty ? "Ghi nhận" : item.ngay)")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Color.appPrimaryPink)
                                                Spacer()
                                                Text(item.hanhDong)
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                            }
                                            if !item.thietBiId.isEmpty {
                                                Text("🏷️ Mã TB: \(item.thietBiId)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color(hex: "#334155"))
                                            }
                                            if !item.donVi.isEmpty {
                                                Text("🏢 Đơn vị: \(item.donVi)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            if !item.nguoiThucHien.isEmpty {
                                                Text("👤 Thực hiện: \(item.nguoiThucHien)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            if !item.moTa.isEmpty {
                                                Text("📝 Ghi chú: \(item.moTa)")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(12)
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "DDE2E5"), lineWidth: 1))
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            fetchLichSu(thietBiId: thietBiId)
        }
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
        let companyId = authViewModel.currentCompanyId
        
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/history?pageSize=300"
        
        guard let url = URL(string: urlString) else {
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data, error == nil else {
                    return
                }
                
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
