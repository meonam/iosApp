import SwiftUI

public struct ShiftScheduleView: View {
    @ObservedObject var viewModel: ShiftViewModel
    var onBack: () -> Void

    @State private var showingEditSheet = false
    @State private var selectedEmployeeId: String? = nil
    @State private var selectedDayKey: String? = nil
    @State private var selectedShiftCode: String = "HC"
    
    @State private var showingAddEmployeeSheet = false
    @State private var searchEmail: String = ""
    @State private var foundUsers: [User] = [] // Assuming we have a User model, or we can just mock it for this view. Wait, actually I need to fetch users via REST API.
    
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
                                    .foregroundColor(.white)
                                    .imageScale(.large)
                            }
                            
                            Text("Phân ca tuần")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            if viewModel.user.isAdmin {
                                Button(action: {
                                    showingAddEmployeeSheet = true
                                }) {
                                    Image(systemName: "person.badge.plus")
                                        .foregroundColor(.white)
                                        .imageScale(.large)
                                }
                            }
                        }
                        .padding()
                    }
                    .background(Color.appPrimary)
                    
                    // Week Navigation
                    HStack {
                        Button(action: {
                            viewModel.currentWeekOffset -= 1
                            viewModel.fetchShiftSchedule()
                        }) {
                            Image(systemName: "chevron.left")
                            Text("Tuần trước")
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text(viewModel.currentWeekId)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            Button(action: {
                                viewModel.currentWeekOffset = 0
                                viewModel.fetchShiftSchedule()
                            }) {
                                Text("Tuần này")
                                    .font(.caption)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.currentWeekOffset += 1
                            viewModel.fetchShiftSchedule()
                        }) {
                            Text("Tuần sau")
                            Image(systemName: "chevron.right")
                        }
                    }
                    .padding()
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
                                        .frame(width: 120, alignment: .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                        .background(Color.appPrimary.opacity(0.1))
                                        .border(Color.gray.opacity(0.3))
                                    
                                    ForEach(0..<dayKeys.count, id: \.self) { i in
                                        Text(dayNames[i])
                                            .frame(width: 60, alignment: .center)
                                            .padding(.vertical, 12)
                                            .background(Color.appPrimary.opacity(0.1))
                                            .border(Color.gray.opacity(0.3))
                                    }
                                }
                                
                                // Data Rows
                                let entries = viewModel.currentWeekSchedule?.entries ?? []
                                let filteredEntries = viewModel.user.isAdmin ? entries : entries.filter { $0.employeeId == viewModel.user.id || $0.employeeId == "emp_\(viewModel.user.id)" || $0.employeeName == viewModel.user.fullName }
                                
                                if filteredEntries.isEmpty {
                                    Text("Chưa có dữ liệu ca làm việc")
                                        .padding()
                                }
                                
                                ForEach(filteredEntries, id: \.employeeId) { entry in
                                    HStack(spacing: 0) {
                                        Text(entry.employeeName)
                                            .font(.caption)
                                            .frame(width: 120, alignment: .leading)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 12)
                                            .border(Color.gray.opacity(0.3))
                                        
                                        ForEach(dayKeys, id: \.self) { dayKey in
                                            let shiftCode = entry.days[dayKey] ?? ""
                                            
                                            Text(shiftCode.isEmpty ? "-" : shiftCode)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .frame(width: 60, height: 40)
                                                .foregroundColor(.white)
                                                .background(shiftCode.isEmpty ? Color.white : shiftColor(for: shiftCode))
                                                .border(Color.gray.opacity(0.3))
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
                
                Picker("Ca", selection: $selectedShiftCode) {
                    ForEach(shiftOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                Button("Lưu") {
                    if let empId = selectedEmployeeId, let dayKey = selectedDayKey {
                        updateShiftViaPatch(employeeId: empId, dayKey: dayKey, newCode: selectedShiftCode)
                    }
                    showingEditSheet = false
                }
                .padding()
                .background(Color.appPrimary)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Hủy") {
                    showingEditSheet = false
                }
                .foregroundColor(.red)
            }
            .padding()
            .presentationDetents([.fraction(0.3)])
        }
        .sheet(isPresented: $showingAddEmployeeSheet) {
            AddEmployeeSheet(viewModel: viewModel, isPresented: $showingAddEmployeeSheet)
        }
    }
    
    private func updateShiftViaPatch(employeeId: String, dayKey: String, newCode: String) {
        // Need to use emp_ prefix if missing
        let empKey = employeeId.starts(with: "emp_") ? employeeId : "emp_\(employeeId)"
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId)/shift_schedules/\(viewModel.currentWeekId)?updateMask.fieldPaths=\(empKey).\(dayKey)"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                empKey: [
                    "mapValue": [
                        "fields": [
                            dayKey: ["stringValue": newCode]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                viewModel.fetchShiftSchedule()
            }
        }.resume()
    }
}

// Sub-view for Adding Employee to Shift Schedule
struct AddEmployeeSheet: View {
    @ObservedObject var viewModel: ShiftViewModel
    @Binding var isPresented: Bool
    
    @State private var emailSearch: String = ""
    @State private var users: [[String: Any]] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            Text("Thêm nhân viên vào ca")
                .font(.headline)
                .padding()
            
            HStack {
                TextField("Nhập email để tìm", text: $emailSearch)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Tìm") {
                    searchUsers()
                }
                .padding(.horizontal)
            }
            .padding()
            
            if isLoading {
                ProgressView()
            }
            
            List(users, id: \.self.description) { userMap in
                let email = (userMap["email"] as? [String: Any])?["stringValue"] as? String ?? ""
                let name = (userMap["fullName"] as? [String: Any])?["stringValue"] as? String ?? ""
                let docId = userMap["_docId"] as? String ?? ""
                
                HStack {
                    VStack(alignment: .leading) {
                        Text(name).font(.headline)
                        Text(email).font(.subheadline)
                    }
                    Spacer()
                    Button("Thêm") {
                        addEmployeeToSchedule(docId: docId, name: name)
                    }
                    .foregroundColor(.blue)
                }
            }
            Spacer()
        }
    }
    
    private func searchUsers() {
        guard !emailSearch.isEmpty else { return }
        isLoading = true
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId)/users"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let docs = json["documents"] as? [[String: Any]] else {
                    return
                }
                
                var results: [[String: Any]] = []
                for doc in docs {
                    if let fields = doc["fields"] as? [String: Any] {
                        let email = (fields["email"] as? [String: Any])?["stringValue"] as? String ?? ""
                        if email.lowercased().contains(self.emailSearch.lowercased()) {
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
    
    private func addEmployeeToSchedule(docId: String, name: String) {
        let empKey = "emp_\(docId)"
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.companyId)/shift_schedules/\(viewModel.currentWeekId)?updateMask.fieldPaths=\(empKey)"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(viewModel.idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                empKey: [
                    "mapValue": [
                        "fields": [
                            "name": ["stringValue": name]
                        ]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                viewModel.fetchShiftSchedule()
                isPresented = false
            }
        }.resume()
    }
}
