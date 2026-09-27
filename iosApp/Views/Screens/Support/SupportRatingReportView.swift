import SwiftUI

public struct SupportRatingReportView: View {
    @ObservedObject var viewModel: SupportViewModel
    var onBack: () -> Void

    @State private var tickets: [SupportTicket] = []
    @State private var isLoading: Bool = true
    
    // Filters
    @State private var selectedMonth: Date = Date()
    @State private var selectedKtv: String = "Tất cả"
    @State private var ktvList: [String] = ["Tất cả"]
    
    // Stats models
    struct KtvStat: Identifiable {
        let id: String
        let name: String
        let totalTickets: Int
        let closedTickets: Int
        let avgRating: Double
        let slaRate: Double
    }
    
    @State private var stats: [KtvStat] = []
    @State private var systemTotalTickets: Int = 0
    @State private var systemTotalRatings: Int = 0
    @State private var systemSatisfactionRate: Double = 0.0
    @State private var systemSlaCompliance: Double = 0.0
    @State private var systemAvgRating: Double = 0.0
    
    public init(viewModel: SupportViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(8)
                            }
                            Text("Báo cáo SLA & Đánh giá")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .background(Color.appTopBarColor)

                    // Filters
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.appPrimary)
                            Text(formatMonth(selectedMonth))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        .onTapGesture {
                            // Mock month picker change logic - previous month
                            if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) {
                                selectedMonth = newDate
                                calculateStats()
                            }
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(ktvList, id: \.self) { ktv in
                                Button(ktv) {
                                    selectedKtv = ktv
                                    calculateStats()
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.appPrimary)
                                Text(selectedKtv)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(10)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appCardBorder, lineWidth: 1))
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    
                    if isLoading {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                // Tổng quan
                                HStack(spacing: 12) {
                                    statCard(title: "Điểm sao TB", value: String(format: "%.1f", systemAvgRating), icon: "star.fill", color: .orange)
                                    statCard(title: "Lượt đánh giá", value: "\(systemTotalRatings)/\(systemTotalTickets)", icon: "person.2.fill", color: .blue)
                                    statCard(title: "Tỷ lệ hài lòng", value: String(format: "%.0f%%", systemSatisfactionRate), icon: "heart.fill", color: .green)
                                }
                                
                                // SLA Overview
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("TUÂN THỦ CAM KẾT SLA")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(slaColor(systemSlaCompliance))
                                        Spacer()
                                        Text(String(format: "%.1f%%", systemSlaCompliance))
                                            .font(.system(size: 20, weight: .black))
                                            .foregroundColor(slaColor(systemSlaCompliance))
                                    }
                                    
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.appCardBorder).frame(height: 8)
                                            Capsule().fill(slaColor(systemSlaCompliance))
                                                .frame(width: max(0, geo.size.width * CGFloat(systemSlaCompliance) / 100.0), height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                                .padding(16)
                                .background(slaColor(systemSlaCompliance).opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(slaColor(systemSlaCompliance).opacity(0.3), lineWidth: 1))
                                
                                // KTV Leaderboard
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("BẢNG XẾP HẠNG KỸ THUẬT VIÊN")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.appTextSecondary)
                                    
                                    if stats.isEmpty {
                                        Text("Không có dữ liệu trong thời gian này.")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .padding(.vertical, 20)
                                    } else {
                                        ForEach(stats) { stat in
                                            ktvRow(stat)
                                            if stat.id != stats.last?.id {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                            }
                            .padding(14)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .onAppear {
                Task {
                    await fetchTickets()
                }
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(color)
                if icon == "star.fill" {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
    }
    
    private func ktvRow(_ stat: KtvStat) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.appPrimary.opacity(0.1)).frame(width: 40, height: 40)
                Text(String(stat.name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appPrimary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(stat.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.black)
                
                HStack {
                    Text("Ticket: \(stat.closedTickets)/\(stat.totalTickets)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(String(format: "SLA: %.1f%%", stat.slaRate))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(slaColor(stat.slaRate))
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                Text(String(format: "%.1f", stat.avgRating))
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.15))
            .cornerRadius(8)
        }
    }
    
    private func slaColor(_ rate: Double) -> Color {
        if rate >= 90.0 { return .green }
        else if rate >= 70.0 { return .orange }
        else { return .red }
    }
    
    private func formatMonth(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "MM/yyyy"
        return "Tháng " + df.string(from: date)
    }

    private func fetchTickets() async {
        await MainActor.run { isLoading = true }
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId):runQuery"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let queryPayload: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "support_tickets"]],
                "orderBy": [
                    ["field": ["fieldPath": "createdAt"], "direction": "DESCENDING"]
                ],
                "limit": 300
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else {
            await MainActor.run { isLoading = false }
            return
        }
        request.httpBody = bodyData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    var loaded: [SupportTicket] = []
                    var ktvs = Set<String>()
                    
                    for item in results {
                        guard let doc = item["document"] as? [String: Any],
                              let fields = doc["fields"] as? [String: Any] else { continue }
                        
                        let assignedEmail = FirestoreHelper.getString(fields["assignedToEmail"] as? [String: Any])
                        let assignedName = FirestoreHelper.getString(fields["assignedToName"] as? [String: Any])
                        let ktvName = assignedName.isEmpty ? assignedEmail : assignedName
                        if !ktvName.isEmpty { ktvs.insert(ktvName) }
                        
                        let docName = doc["name"] as? String ?? ""
                        let id = docName.components(separatedBy: "/").last ?? ""
                        
                        let t = SupportTicket(
                            id: id,
                            priority: FirestoreHelper.getString(fields["priority"] as? [String: Any]),
                            createdAt: FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any]),
                            rating: FirestoreHelper.getInt(fields["rating"] as? [String: Any]),
                            assignedToEmail: assignedEmail,
                            assignedToName: assignedName,
                            closedAt: FirestoreHelper.getInt64(fields["closedAt"] as? [String: Any]),
                            isAutoRated: FirestoreHelper.getBool(fields["isAutoRated"] as? [String: Any]),
                            isInvalid: FirestoreHelper.getBool(fields["isInvalid"] as? [String: Any])
                        )
                        loaded.append(t)
                    }
                    
                    await MainActor.run {
                        self.tickets = loaded
                        var klist = ["Tất cả"]
                        klist.append(contentsOf: ktvs.sorted())
                        self.ktvList = klist
                        self.calculateStats()
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run { isLoading = false }
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
    
    private func calculateStats() {
        let calendar = Calendar.current
        // Filter by month
        let monthTickets = tickets.filter { t in
            let date = Date(timeIntervalSince1970: TimeInterval(t.createdAt) / 1000.0)
            return calendar.isDate(date, equalTo: selectedMonth, toGranularity: .month)
        }
        
        // Filter by KTV
        let filtered = monthTickets.filter { t in
            if selectedKtv == "Tất cả" { return true }
            let name = t.assignedToName.isEmpty ? t.assignedToEmail : t.assignedToName
            return name == selectedKtv
        }
        
        systemTotalTickets = filtered.count
        
        var ratedCount = 0
        var totalRating = 0.0
        var satisfiedCount = 0
        
        var slaOnTime = 0
        var slaTotal = 0
        
        var ktvMap: [String: [SupportTicket]] = [:]
        
        for t in filtered {
            let rating = t.effectiveRating
            if rating > 0 {
                ratedCount += 1
                totalRating += Double(rating)
                if rating >= 4 { satisfiedCount += 1 }
            }
            
            if t.closedAt > t.createdAt && t.createdAt > 0 {
                slaTotal += 1
                let hours = Double(t.closedAt - t.createdAt) / (1000.0 * 60.0 * 60.0)
                let limit = (t.priority.uppercased() == "URGENT") ? 1.0 : (t.priority.uppercased() == "HIGH" ? 4.0 : 24.0)
                if hours <= limit { slaOnTime += 1 }
            }
            
            let name = t.assignedToName.isEmpty ? t.assignedToEmail : t.assignedToName
            if !name.isEmpty {
                ktvMap[name, default: []].append(t)
            }
        }
        
        systemTotalRatings = ratedCount
        systemAvgRating = ratedCount > 0 ? totalRating / Double(ratedCount) : 0.0
        systemSatisfactionRate = ratedCount > 0 ? (Double(satisfiedCount) / Double(ratedCount)) * 100.0 : 0.0
        systemSlaCompliance = slaTotal > 0 ? (Double(slaOnTime) / Double(slaTotal)) * 100.0 : 0.0
        
        var newStats: [KtvStat] = []
        for (name, kList) in ktvMap {
            var kTotalRating = 0.0
            var kRatedCount = 0
            var kSlaOnTime = 0
            var kSlaTotal = 0
            var closed = 0
            
            for t in kList {
                if t.closedAt > 0 { closed += 1 }
                let rating = t.effectiveRating
                if rating > 0 {
                    kTotalRating += Double(rating)
                    kRatedCount += 1
                }
                if t.closedAt > t.createdAt && t.createdAt > 0 {
                    kSlaTotal += 1
                    let hours = Double(t.closedAt - t.createdAt) / (1000.0 * 60.0 * 60.0)
                    let limit = (t.priority.uppercased() == "URGENT") ? 1.0 : (t.priority.uppercased() == "HIGH" ? 4.0 : 24.0)
                    if hours <= limit { kSlaOnTime += 1 }
                }
            }
            
            let avgR = kRatedCount > 0 ? kTotalRating / Double(kRatedCount) : 0.0
            let slaR = kSlaTotal > 0 ? (Double(kSlaOnTime) / Double(kSlaTotal)) * 100.0 : 0.0
            
            newStats.append(KtvStat(
                id: name, name: name, totalTickets: kList.count, closedTickets: closed, avgRating: avgR, slaRate: slaR
            ))
        }
        
        stats = newStats.sorted { $0.avgRating > $1.avgRating }
    }
}
