import SwiftUI
import Foundation

public struct AttendanceReportView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    @StateObject private var viewModel: AttendanceViewModel
    
    @State private var selectedDate = Date()
    @State private var selectedDept = "Tất cả"
    @State private var selectedUser = "Tất cả"
    @State private var searchQuery = ""
    
    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
        if let user = authViewModel.currentUser {
            _viewModel = StateObject(wrappedValue: AttendanceViewModel(user: user, companyId: authViewModel.currentCompanyId, idToken: authViewModel.currentIdToken))
        } else {
            // Fallback for previews
            _viewModel = StateObject(wrappedValue: AttendanceViewModel(user: User(email: "", fullName: ""), companyId: "", idToken: ""))
        }
    }
    
    // Derived properties for UI
    private var isManager: Bool {
        guard let user = authViewModel.currentUser else { return false }
        return user.isAdmin || user.isSuperAdmin || user.role == "MANAGER" || user.isHelpDesk
    }
    
    private var filteredRecords: [AttendanceRecord] {
        var records = viewModel.attendanceHistory
        
        // Filter by department
        if selectedDept != "Tất cả" {
            records = records.filter { $0.donVi == selectedDept }
        }
        
        // Filter by user
        if selectedUser != "Tất cả" {
            records = records.filter { $0.userName == selectedUser }
        }
        
        // Search by name
        if !searchQuery.isEmpty {
            records = records.filter { $0.userName.lowercased().contains(searchQuery.lowercased()) }
        }
        
        return records
    }
    
    private var groupedAttendance: [String: [AttendanceRecord]] {
        Dictionary(grouping: filteredRecords, by: { $0.userName })
    }
    
    private var allDepartments: [String] {
        let depts = viewModel.attendanceHistory.map { $0.donVi }.filter { !$0.isEmpty }
        return ["Tất cả"] + Array(Set(depts)).sorted()
    }
    
    private var allUsers: [String] {
        var records = viewModel.attendanceHistory
        if selectedDept != "Tất cả" {
            records = records.filter { $0.donVi == selectedDept }
        }
        let users = records.map { $0.userName }.filter { !$0.isEmpty }
        return ["Tất cả"] + Array(Set(users)).sorted()
    }
    
    // Stats calculation
    private var totalAttendanceDays: Int {
        filteredRecords.count
    }
    
    private var onTimeCount: Int {
        filteredRecords.filter { $0.checkInStatus == "ON_TIME" }.count
    }
    
    private var lateCount: Int {
        filteredRecords.filter { $0.checkInStatus == "LATE" }.count
    }
    
    private var totalWorkHours: Double {
        filteredRecords.reduce(0.0) { total, record in
            let checkIn = record.checkInTime
            let checkOut = record.checkOutTime
            if checkIn > 0 && checkOut > checkIn {
                let ms = checkOut - checkIn
                return total + Double(ms) / (1000 * 60 * 60)
            }
            return total
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MM/yyyy"
        return df
    }()
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .padding(.trailing, 8)
                            }
                            Text("Báo Cáo Chấm Công")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: exportCSV) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.appPrimary)
                    }
                    
                    if !isManager {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: "lock.shield")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("Truy cập bị giới hạn")
                                .font(.headline)
                            Text("Báo cáo Chấm công chỉ dành cho Quản lý.\nBạn không có quyền truy cập trang này.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        Spacer()
                    } else {
                        // Filters
                        VStack(spacing: 12) {
                            // Month picker
                            HStack {
                                Button(action: { changeMonth(by: -1) }) {
                                    Image(systemName: "chevron.left")
                                        .foregroundColor(Color.appPrimary)
                                }
                                Spacer()
                                Text("Tháng \(dateFormatter.string(from: selectedDate))")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.appPrimary)
                                Spacer()
                                Button(action: { changeMonth(by: 1) }) {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Color.appPrimary)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Search and Dropdowns
                            HStack {
                                TextField("Tìm tên nhân viên...", text: $searchQuery)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal)
                            
                            HStack {
                                Picker("Phòng ban", selection: $selectedDept) {
                                    ForEach(allDepartments, id: \.self) { dept in
                                        Text(dept).tag(dept)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                
                                Picker("Nhân viên", selection: $selectedUser) {
                                    ForEach(allUsers, id: \.self) { user in
                                        Text(user).tag(user)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                        
                        ScrollView {
                            VStack(spacing: 16) {
                                // KPI Cards
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                    kpiCard(title: "TỔNG NGÀY CÔNG", value: "\(totalAttendanceDays) ngày", color: Color.blue)
                                    kpiCard(title: "SỐ LẦN ĐI TRỄ", value: "\(lateCount) lần", color: Color.orange)
                                    kpiCard(title: "SỐ LẦN ĐÚNG GIỜ", value: "\(onTimeCount) lần", color: Color.green)
                                    kpiCard(title: "TỔNG GIỜ LÀM", value: String(format: "%.1f giờ", totalWorkHours), color: Color.purple)
                                }
                                .padding(.horizontal)
                                
                                // Table Report
                                if viewModel.isLoadingHistory {
                                    ProgressView("Đang tải dữ liệu...")
                                        .padding(.top, 20)
                                } else if filteredRecords.isEmpty {
                                    Text("Chưa có dữ liệu chấm công tháng này")
                                        .foregroundColor(.gray)
                                        .padding(.top, 20)
                                } else {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Chi Tiết Theo Nhân Viên")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        ForEach(groupedAttendance.keys.sorted(), id: \.self) { userName in
                                            let records = groupedAttendance[userName] ?? []
                                            userReportRow(userName: userName, records: records)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 16)
                        }
                        .refreshable {
                            loadData()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            if isManager {
                loadData()
            }
        }
        .onChange(of: selectedDept) { _ in
            selectedUser = "Tất cả"
        }
    }
    
    private func loadData() {
        if isManager {
            viewModel.fetchAllAttendanceHistory(month: selectedDate)
        }
    }
    
    private func changeMonth(by amount: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: amount, to: selectedDate) {
            selectedDate = newDate
            loadData()
        }
    }
    
    private func kpiCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    private func userReportRow(userName: String, records: [AttendanceRecord]) -> some View {
        let lCount = records.filter { $0.checkInStatus == "LATE" }.count
        let oCount = records.filter { $0.checkInStatus == "ON_TIME" }.count
        let tHours = records.reduce(0.0) { total, record in
            let checkIn = record.checkInTime
            let checkOut = record.checkOutTime
            if checkIn > 0 && checkOut > checkIn {
                return total + Double(checkOut - checkIn) / (1000 * 60 * 60)
            }
            return total
        }
        let dept = records.first?.donVi ?? "Kỹ thuật"
        
        return DisclosureGroup {
            VStack(spacing: 0) {
                ForEach(records.sorted(by: { $0.date > $1.date }), id: \.id) { record in
                    HStack {
                        Text(record.date)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        Spacer()
                        if record.checkInStatus == "LATE" {
                            Text("Trễ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.orange)
                        } else {
                            Text("Đúng giờ")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider()
                }
            }
            .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(userName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primary)
                Text("\(dept) • \(records.count) ngày công")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                HStack(spacing: 16) {
                    Label("\(oCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("\(lCount)", systemImage: "clock.fill")
                        .foregroundColor(.orange)
                    Label(String(format: "%.1fh", tHours), systemImage: "timer")
                        .foregroundColor(.blue)
                }
                .font(.system(size: 12))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
    
    private func exportCSV() {
        var csvString = "Tên,Phòng ban,Tổng ngày,Đúng giờ,Trễ,Tổng giờ\n"
        
        let sortedUsers = groupedAttendance.keys.sorted()
        for user in sortedUsers {
            if let records = groupedAttendance[user] {
                let dept = records.first?.donVi ?? ""
                let totalDays = records.count
                let oCount = records.filter { $0.checkInStatus == "ON_TIME" }.count
                let lCount = records.filter { $0.checkInStatus == "LATE" }.count
                let tHours = records.reduce(0.0) { total, record in
                    let checkIn = record.checkInTime
                    let checkOut = record.checkOutTime
                    if checkIn > 0 && checkOut > checkIn {
                        return total + Double(checkOut - checkIn) / (1000 * 60 * 60)
                    }
                    return total
                }
                
                csvString += "\(user),\(dept),\(totalDays),\(oCount),\(lCount),\(String(format: "%.1f", tHours))\n"
            }
        }
        
        let data = csvString.data(using: .utf8)
        if let data = data {
            let filename = "BaoCaoChamCong_\(dateFormatter.string(from: selectedDate).replacingOccurrences(of: "/", with: "_")).csv"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url)
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(vc, animated: true, completion: nil)
                }
            } catch {
                print("Lỗi export CSV: \(error)")
            }
        }
    }
}
