import SwiftUI

struct AttendanceReportView: View {
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var viewModel: AttendanceViewModel
    
    @State private var selectedDate = Date()
    @State private var selectedDept = "Tất cả"
    @State private var selectedUser = "Tất cả"
    
    init(authVM: AuthViewModel) {
        self.authVM = authVM
        _viewModel = StateObject(wrappedValue: AttendanceViewModel(authViewModel: authVM))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    // TopBar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        HStack {
                            Text("Báo Cáo Điểm Danh")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding()
                        .background(Color.appPrimary)
                    }
                    
                    if viewModel.isLoadingHistory {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                        Spacer()
                    } else if !authVM.user.isAdmin && !authVM.user.isSuperAdmin && authVM.user.role != "MANAGER" {
                        Spacer()
                        Text("Bạn không có quyền xem báo cáo này.")
                            .foregroundColor(.gray)
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                HStack {
                                    Picker("Phòng ban", selection: $selectedDept) {
                                        Text("Tất cả").tag("Tất cả")
                                        ForEach(Array(Set(viewModel.attendanceHistory.map { $0.donVi ?? "Khác" })), id: \.self) { dept in
                                            Text(dept).tag(dept)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    
                                    Spacer()
                                    
                                    Picker("Nhân viên", selection: $selectedUser) {
                                        Text("Tất cả").tag("Tất cả")
                                        ForEach(Array(Set(filteredByDept.map { $0.userName ?? "Unknown" })), id: \.self) { user in
                                            Text(user).tag(user)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                }
                                .padding(.horizontal)
                                .padding(.top, 16)
                                
                                ForEach(groupedAttendance.keys.sorted(), id: \.self) { userName in
                                    let records = groupedAttendance[userName] ?? []
                                    let lateCount = records.filter { $0.checkInStatus == "LATE" }.count
                                    let totalDays = records.count
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(userName)
                                            .font(.headline)
                                        HStack {
                                            Text("Tổng ngày: \(totalDays)")
                                            Spacer()
                                            Text("Đi trễ: \(lateCount)")
                                                .foregroundColor(.red)
                                        }
                                        .font(.subheadline)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.fetchAllAttendanceHistory(month: selectedDate)
        }
    }
    
    private var filteredByDept: [AttendanceRecord] {
        if selectedDept == "Tất cả" { return viewModel.attendanceHistory }
        return viewModel.attendanceHistory.filter { ($0.donVi ?? "Khác") == selectedDept }
    }
    
    private var filteredRecords: [AttendanceRecord] {
        if selectedUser == "Tất cả" { return filteredByDept }
        return filteredByDept.filter { ($0.userName ?? "") == selectedUser }
    }
    
    private var groupedAttendance: [String: [AttendanceRecord]] {
        Dictionary(grouping: filteredRecords, by: { $0.userName ?? "Unknown" })
    }
}
