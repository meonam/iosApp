import SwiftUI

public struct ShiftScheduleView: View {
    @ObservedObject var viewModel: ShiftViewModel
    var onBack: () -> Void

    @State private var showingEditSheet = false
    @State private var selectedEmployeeId: String? = nil
    @State private var selectedDayKey: String? = nil
    @State private var selectedShiftCode: String = "HC"
    
    @State private var showingAddEmployeeSheet = false
    
    // Days of week
    private let dayKeys = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    private let dayNames = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
    private let shiftOptions = ["HC", "SHIFT_2", "NIGHT", "OFF"]
    
    public init(viewModel: ShiftViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    private func shiftColor(for code: String) -> Color {
        switch code.uppercased() {
        case "HC": return Color.blue
        case "SHIFT_2": return Color.orange
        case "NIGHT": return Color.purple
        case "OFF": return Color.gray
        default: return Color.gray.opacity(0.5)
        }
    }

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
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Phân ca tuần")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            if viewModel.user.isAdmin {
                                Button(action: {
                                    showingAddEmployeeSheet = true
                                }) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)
                    
                    // Week Navigation
                    HStack {
                        Button(action: {
                            viewModel.currentWeekOffset -= 1
                            viewModel.fetchShiftSchedule()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Tuần trước")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text(viewModel.currentWeekId)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color.appSecondaryDarkBlue)
                            
                            Button(action: {
                                viewModel.currentWeekOffset = 0
                                viewModel.fetchShiftSchedule()
                            }) {
                                Text("Tuần này")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.currentWeekOffset += 1
                            viewModel.fetchShiftSchedule()
                        }) {
                            HStack(spacing: 4) {
                                Text("Tuần sau")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    
                    // Main Content
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Đang tải dữ liệu...")
                        Spacer()
                    } else if let error = viewModel.errorMessage {
                        Spacer()
                        Text(error).foregroundColor(.red)
                        Button("Thử lại") {
                            viewModel.fetchShiftSchedule()
                        }
                        .padding()
                        Spacer()
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            VStack(alignment: .leading, spacing: 0) {
                                // Header Row
                                HStack(spacing: 0) {
                                    Text("Nhân viên")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                        .frame(width: 130, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .background(Color.appSecondaryDarkBlue.opacity(0.08))
                                        .border(Color.gray.opacity(0.2))
                                    
                                    ForEach(0..<dayKeys.count, id: \.self) { i in
                                        Text(dayNames[i])
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Color.appSecondaryDarkBlue)
                                            .frame(width: 60, alignment: .center)
                                            .padding(.vertical, 12)
                                            .background(Color.appSecondaryDarkBlue.opacity(0.08))
                                            .border(Color.gray.opacity(0.2))
                                    }
                                }
                                
                                // Data Rows
                                let entries = viewModel.currentWeekSchedule?.entries ?? []
                                let filteredEntries = viewModel.user.isAdmin ? entries : entries.filter { $0.employeeId == viewModel.user.id || $0.employeeId == "emp_\(viewModel.user.id)" || $0.employeeName == viewModel.user.fullName }
                                
                                if filteredEntries.isEmpty {
                                    Text("Chưa có dữ liệu ca làm việc tuần này")
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                                
                                ForEach(filteredEntries, id: \.employeeId) { entry in
                                    HStack(spacing: 0) {
                                        Text(entry.employeeName.isEmpty ? entry.employeeId : entry.employeeName)
                                            .font(.system(size: 12, weight: .medium))
                                            .frame(width: 130, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 10)
                                            .background(Color.white)
                                            .border(Color.gray.opacity(0.2))
                                        
                                        ForEach(dayKeys, id: \.self) { dayKey in
                                            let shiftCode = entry.days[dayKey] ?? ""
                                            
                                            Text(shiftCode.isEmpty ? "-" : shiftCode)
                                                .font(.system(size: 11, weight: .bold))
                                                .frame(width: 60, height: 40)
                                                .foregroundColor(shiftCode.isEmpty ? .gray : .white)
                                                .background(shiftCode.isEmpty ? Color.white : shiftColor(for: shiftCode))
                                                .border(Color.gray.opacity(0.2))
                                                .onTapGesture {
                                                    if viewModel.user.isAdmin {
                                                        selectedEmployeeId = entry.employeeId
                                                        selectedDayKey = dayKey
                                                        selectedShiftCode = shiftCode.isEmpty ? "HC" : shiftCode
                                                        showingEditSheet = true
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.fetchShiftSchedule()
        }
        .sheet(isPresented: $showingEditSheet) {
            VStack(spacing: 20) {
                Text("Cập nhật ca làm việc")
                    .font(.headline)
                    .padding(.top)
                
                Picker("Ca", selection: $selectedShiftCode) {
                    ForEach(shiftOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button(action: { showingEditSheet = false }) {
                        Text("Hủy")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.gray)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        if let empId = selectedEmployeeId, let dayKey = selectedDayKey {
                            viewModel.updateShiftCode(employeeId: empId, dayKey: dayKey, newCode: selectedShiftCode)
                        }
                        showingEditSheet = false
                    }) {
                        Text("Lưu")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color.appSecondaryDarkBlue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .presentationDetents([.fraction(0.35)])
        }
        .sheet(isPresented: $showingAddEmployeeSheet) {
            AddEmployeeSheet(viewModel: viewModel, isPresented: $showingAddEmployeeSheet)
        }
    }
}

// MARK: - SUBVIEW: THÊM NHÂN VIÊN VÀO LỊCH CA
struct AddEmployeeSheet: View {
    @ObservedObject var viewModel: ShiftViewModel
    @Binding var isPresented: Bool
    
    @State private var emailSearch: String = ""
    @State private var users: [[String: Any]] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Tìm theo tên hoặc email...", text: $emailSearch)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            searchUsers()
                        }
                    if !emailSearch.isEmpty {
                        Button(action: { emailSearch = ""; users = [] }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    Button("Tìm") {
                        searchUsers()
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                }
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isLoading {
                    Spacer()
                    ProgressView("Đang tìm kiếm...")
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    Text("Nhập từ khóa để tìm nhân viên trong công ty")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List(users, id: \.self.description) { userMap in
                        let email = (userMap["email"] as? [String: Any])?["stringValue"] as? String ?? ""
                        let name = (userMap["fullName"] as? [String: Any])?["stringValue"] as? String ?? ""
                        let docId = userMap["_docId"] as? String ?? ""
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(name.isEmpty ? email : name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(hex: "#0F172A"))
                                Text(email)
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button("Thêm") {
                                viewModel.addEmployee(employeeId: docId, employeeName: name.isEmpty ? email : name)
                                isPresented = false
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.appSecondaryDarkBlue)
                            .cornerRadius(8)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Thêm nhân viên vào ca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            searchUsers()
        }
    }
    
    private func searchUsers() {
        isLoading = true
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId)/users?pageSize=100"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        if !viewModel.idToken.isEmpty {
            request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let docs = json["documents"] as? [[String: Any]] else {
                    return
                }
                
                var results: [[String: Any]] = []
                let query = self.emailSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                for doc in docs {
                    if let fields = doc["fields"] as? [String: Any] {
                        let email = (fields["email"] as? [String: Any])?["stringValue"] as? String ?? ""
                        let name = (fields["fullName"] as? [String: Any])?["stringValue"] as? String ?? ""
                        
                        let matches = query.isEmpty ||
                            email.lowercased().contains(query) ||
                            name.lowercased().contains(query)
                        
                        if matches {
                            let docName = doc["name"] as? String ?? ""
                            let docId = docName.components(separatedBy: "/").last ?? ""
                            var f = fields
                            f["_docId"] = docId
                            results.append(f)
                        }
                    }
                }
                self.users = results
            }
        }.resume()
    }
}
