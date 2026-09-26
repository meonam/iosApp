import SwiftUI

struct AttendanceHistoryItem: Identifiable {
    let id: String
    var checkInTime: Int64
    var checkOutTime: Int64
    var status: String
    var workDuration: Int
}

public struct AttendanceHistoryView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    
    @State private var records: [AttendanceHistoryItem] = []
    @State private var isLoading = false
    @State private var isListView = true
    
    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appPrimary)
                    
                    // Summary Stats
                    summaryStats
                        .padding()
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải...")
                        Spacer()
                    } else if records.isEmpty {
                        Spacer()
                        Text("Không có dữ liệu chấm công.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        List {
                            ForEach(records) { record in
                                recordRow(record)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await fetchHistoryAsync()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            fetchHistory()
        }
    }
    
    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            Spacer()
            Text("Lịch sử chấm công")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: { isListView.toggle() }) {
                Image(systemName: isListView ? "calendar" : "list.bullet")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    private var summaryStats: some View {
        let total = records.count
        let onTime = records.filter { $0.status == "on_time" }.count
        let late = records.filter { $0.status == "late" }.count
        
        return HStack {
            VStack {
                Text("\(total)")
                    .font(.title3).bold()
                Text("Tổng ngày")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            VStack {
                Text("\(onTime)")
                    .font(.title3).bold().foregroundColor(.green)
                Text("Đúng giờ")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            VStack {
                Text("\(late)")
                    .font(.title3).bold().foregroundColor(.orange)
                Text("Trễ")
                    .font(.caption).foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    private func recordRow(_ record: AttendanceRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDateOnly(record.checkInTime))
                    .font(.headline)
                HStack {
                    Image(systemName: "arrow.down.right.circle")
                        .foregroundColor(.green)
                    Text(formatTimeOnly(record.checkInTime))
                    Spacer()
                    Image(systemName: "arrow.up.right.circle")
                        .foregroundColor(.red)
                    Text(record.checkOutTime > 0 ? formatTimeOnly(record.checkOutTime) : "--:--")
                }
                .font(.subheadline)
                .foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(record.checkInStatus == "ON_TIME" ? "Đúng giờ" : (record.checkInStatus == "LATE" ? "Trễ" : "Vắng"))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((record.checkInStatus == "ON_TIME" ? Color.green : Color.orange).opacity(0.2))
                    .foregroundColor(record.checkInStatus == "ON_TIME" ? .green : .orange)
                    .cornerRadius(8)
                
                if record.workDuration > 0 {
                    Text("\(record.workDuration / 60)h \(record.workDuration % 60)m")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    
    private func fetchHistory() {
        Task { await fetchHistoryAsync() }
    }
    
    private func fetchHistoryAsync() async {
        let companyId = authViewModel.currentUser?.companyId ?? ""
        let token = authViewModel.currentIdToken ?? ""
        let userId = authViewModel.currentUser?.id ?? ""
        guard !companyId.isEmpty, !token.isEmpty, !userId.isEmpty else { return }
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/attendance"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        DispatchQueue.main.async { isLoading = true }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let docs = json["documents"] as? [[String: Any]] {
                    var loaded: [AttendanceHistoryItem] = []
                    for doc in docs {
                        if let fields = doc["fields"] as? [String: Any] {
                            let uId = FirestoreHelper.getString(fields["userId"] as? [String: Any])
                            if uId == userId {
                                let docName = doc["name"] as? String ?? ""
                                let docId = docName.components(separatedBy: "/").last ?? ""
                                let rec = AttendanceHistoryItem(
                                    id: docId,
                                    checkInTime: FirestoreHelper.getInt64(fields["checkInTime"] as? [String: Any]),
                                    checkOutTime: FirestoreHelper.getInt64(fields["checkOutTime"] as? [String: Any]),
                                    status: FirestoreHelper.getString(fields["status"] as? [String: Any]),
                                    workDuration: FirestoreHelper.getInt(fields["workDuration"] as? [String: Any])
                                )
                                loaded.append(rec)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.records = loaded.sorted { $0.checkInTime > $1.checkInTime }
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.records = []
                        self.isLoading = false
                    }
                }
            } else {
                DispatchQueue.main.async { self.isLoading = false }
            }
        } catch {
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    private func formatDateOnly(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
    
    private func formatTimeOnly(_ ms: Int64) -> String {
        guard ms > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
