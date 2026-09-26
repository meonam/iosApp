import SwiftUI

struct AttendanceHistoryView: View {
    @ObservedObject var viewModel: AuthViewModel
    @StateObject private var attendanceVM: AttendanceViewModel
    
    @State private var showingMonthPicker = false
    @State private var selectedMonthIndex = 0 // 0 = current month, 1 = previous month, etc. up to 11
    
    let months: [Date] = {
        var arr: [Date] = []
        let cal = Calendar.current
        let now = Date()
        for i in 0..<12 {
            if let d = cal.date(byAdding: .month, value: -i, to: now) {
                arr.append(d)
            }
        }
        return arr
    }()
    
    init(viewModel: AuthViewModel) {
        self.viewModel = viewModel
        // Create AttendanceViewModel instance with current user
        _attendanceVM = StateObject(wrappedValue: AttendanceViewModel(
            user: viewModel.user,
            companyId: viewModel.user.companyId,
            idToken: viewModel.authToken
        ))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top Bar
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        
                        HStack {
                            Text("Nhật Ký Chấm Công Cá Nhân")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: {
                                attendanceVM.fetchAttendanceHistory(month: attendanceVM.selectedMonth)
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(Color.appPrimary)
                    }
                    .background(Color.appPrimary)
                    
                    // Month Picker & Summary
                    VStack(spacing: 12) {
                        HStack {
                            Button(action: {
                                if selectedMonthIndex < 11 {
                                    selectedMonthIndex += 1
                                    updateMonth()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.appPrimary)
                                    .padding(8)
                            }
                            
                            Spacer()
                            
                            Text(monthString(attendanceVM.selectedMonth))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.appPrimary)
                            
                            Spacer()
                            
                            Button(action: {
                                if selectedMonthIndex > 0 {
                                    selectedMonthIndex -= 1
                                    updateMonth()
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(selectedMonthIndex > 0 ? .appPrimary : .gray.opacity(0.5))
                                    .padding(8)
                            }
                            .disabled(selectedMonthIndex == 0)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                        
                        // KPI Stats
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                KpiCard(title: "Tổng Ngày Công", value: "\(attendanceVM.totalDays) ngày", icon: "calendar.badge.clock", iconColor: .blue, bgColor: Color.blue.opacity(0.1))
                                KpiCard(title: "Tỷ Lệ Đúng Giờ", value: String(format: "%.0f%%", onTimePercentage), icon: "checkmark.circle.fill", iconColor: .green, bgColor: Color.green.opacity(0.1))
                            }
                            HStack(spacing: 10) {
                                KpiCard(title: "Đi Muộn / Sớm", value: "\(attendanceVM.lateDays + attendanceVM.earlyDays) lần", icon: "exclamationmark.triangle.fill", iconColor: .orange, bgColor: Color.orange.opacity(0.1))
                                KpiCard(title: "Đúng Giờ", value: "\(attendanceVM.onTimeDays) ngày", icon: "clock.fill", iconColor: .purple, bgColor: Color.purple.opacity(0.1))
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider().padding(.vertical, 8)
                        
                        HStack {
                            Text("Chi Tiết Từng Ngày (\(attendanceVM.attendanceHistory.count) bản ghi)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.appPrimary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    .background(Color.white)
                    .padding(.bottom, 8)
                    
                    // List
                    if attendanceVM.isLoadingHistory {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appPrimary))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if attendanceVM.attendanceHistory.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Chưa có dữ liệu chấm công tháng này")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(attendanceVM.attendanceHistory, id: \.id) { record in
                                    AttendanceRecordCard(record: record)
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                        .refreshable {
                            attendanceVM.fetchAttendanceHistory(month: attendanceVM.selectedMonth)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            attendanceVM.selectedMonth = months[selectedMonthIndex]
            attendanceVM.fetchAttendanceHistory(month: attendanceVM.selectedMonth)
        }
    }
    
    private var onTimePercentage: Double {
        let total = attendanceVM.totalDays
        if total == 0 { return 100.0 }
        return Double(attendanceVM.onTimeDays) / Double(total) * 100.0
    }
    
    private func updateMonth() {
        attendanceVM.selectedMonth = months[selectedMonthIndex]
        attendanceVM.fetchAttendanceHistory(month: attendanceVM.selectedMonth)
    }
    
    private func monthString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/yyyy"
        return "Tháng \(formatter.string(from: date))"
    }
}

struct KpiCard: View {
    let title: String
    let value: String
    let icon: String
    let iconColor: Color
    let bgColor: Color
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.appPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct AttendanceRecordCard: View {
    let record: AttendanceRecord
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: Date
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                Text(formatDate(record.date))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(record.shiftDisplayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.appPrimary)
            
            // Body
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    // Check In
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 8, height: 8)
                            Text("Vào ca")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Text(formatTime(record.checkInTime))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.green)
                        
                        StatusBadge(status: record.checkInStatus, isCheckIn: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Check Out
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                            Text("Tan ca")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Text(formatTime(record.checkOutTime))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue)
                        
                        StatusBadge(status: record.checkOutStatus, isCheckIn: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Location info
                if !record.checkInAddress.isEmpty || !record.checkOutAddress.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        if !record.checkInAddress.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10))
                                    .foregroundColor(.green)
                                    .padding(.top, 2)
                                Text("Vào: \(record.checkInAddress)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                        if !record.checkOutAddress.isEmpty {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 10))
                                    .foregroundColor(.blue)
                                    .padding(.top, 2)
                                Text("Ra: \(record.checkOutAddress)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                }
                
                if !record.note.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "note.text")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                        Text(record.note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.orange)
                            .italic()
                        Spacer()
                    }
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Assume format "yyyy-MM-dd"
        let parts = dateString.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[2])/\(parts[1])/\(parts[0])"
        }
        return dateString
    }
    
    private func formatTime(_ timestamp: Int64) -> String {
        if timestamp <= 0 { return "--:--" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: String
    let isCheckIn: Bool
    
    var body: some View {
        Text(statusText)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(statusColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.1))
            .cornerRadius(4)
    }
    
    private var statusText: String {
        if isCheckIn {
            switch status {
            case "ON_TIME": return "ĐÚNG GIỜ"
            case "LATE": return "ĐI TRỄ"
            default: return status.isEmpty ? "CHƯA RÕ" : status
            }
        } else {
            switch status {
            case "NORMAL", "ON_TIME": return "ĐÚNG GIỜ"
            case "EARLY": return "VỀ SỚM"
            case "OVERTIME": return "TĂNG CA"
            default: return status.isEmpty ? "CHƯA RÕ" : status
            }
        }
    }
    
    private var statusColor: Color {
        if isCheckIn {
            switch status {
            case "ON_TIME": return .green
            case "LATE": return .red
            default: return .gray
            }
        } else {
            switch status {
            case "NORMAL", "ON_TIME": return .blue
            case "EARLY": return .orange
            case "OVERTIME": return .purple
            default: return .gray
            }
        }
    }
}
