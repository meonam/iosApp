import SwiftUI
import Combine

public struct SuperAdminPortalView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    
    @StateObject private var viewModel = SuperAdminViewModel()
    @State private var selectedTab = 0
    
    let tabs = ["Tổng quan", "Công ty", "Tài khoản", "Cấu hình"]
    
    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
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
                        
                        HStack {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text("Quản Trị Nền Tảng (Super Admin)")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("ROOT")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .foregroundColor(.black)
                                        .cornerRadius(4)
                                }
                                Text("Trung tâm chỉ huy & quản trị vĩ mô toàn hệ thống")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.loadData(token: authViewModel.currentIdToken)
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .background(Color.appPrimary)
                    }
                    .background(Color.appPrimary)
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Đang tải trung tâm chỉ huy...")
                        Spacer()
                    } else if !viewModel.isSuperAdmin {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.red)
                            Text("Từ Chối Truy Cập")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Tài khoản hiện tại không nằm trong danh sách Quản trị viên Nền tảng (Super Admin).")
                                .font(.subheadline)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Button("Quay lại", action: onBack)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        Spacer()
                    } else {
                        // Tabs
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(0..<tabs.count, id: \.self) { index in
                                    Button(action: { selectedTab = index }) {
                                        Text(tabs[index])
                                            .font(.subheadline)
                                            .fontWeight(selectedTab == index ? .bold : .regular)
                                            .foregroundColor(selectedTab == index ? .orange : .white)
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        .background(Color(hex: "#1E1B4B"))
                        
                        // Content
                        TabView(selection: $selectedTab) {
                            OverviewTab(viewModel: viewModel)
                                .tag(0)
                            CompaniesTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(1)
                            AccountsTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(2)
                            ConfigTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(3)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            viewModel.checkSuperAdmin(email: authViewModel.currentUser?.email ?? "", token: authViewModel.currentIdToken)
        }
    }
}

// MARK: - Tabs

struct OverviewTab: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    StatCard(title: "Tổng Đơn Vị", value: "\(viewModel.companies.count)", color: .blue)
                    StatCard(title: "Hoạt Động", value: "\(viewModel.companies.filter { !$0.isMaintenance }.count)", color: .green)
                }
                HStack {
                    StatCard(title: "Tổng User", value: "\(viewModel.totalUsers)", color: .orange)
                    StatCard(title: "Tổng Thiết Bị", value: "\(viewModel.totalDevices)", color: .purple)
                }
            }
            .padding()
        }
    }
}

struct CompaniesTab: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    @State private var showingCreate = false
    @State private var showingCompanyDetails: SACompany?
    
    var body: some View {
        VStack {
            HStack {
                Text("Danh sách Công ty")
                    .font(.headline)
                Spacer()
                Button(action: { showingCreate = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.appPrimary)
                        .font(.title2)
                }
            }
            .padding()
            
            List {
                ForEach(viewModel.companies) { company in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(company.companyName)
                                .font(.headline)
                            Spacer()
                            if company.isMaintenance {
                                Text("Bảo trì")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(4)
                            }
                        }
                        Text("ID: \(company.id)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("Gói: \(company.licenseTier) | \(company.maxDevices) Thiết bị")
                            .font(.caption)
                        
                        HStack {
                            Button("Chi tiết") {
                                showingCompanyDetails = company
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(.blue)
                            
                            Spacer()
                            
                            Button(company.isMaintenance ? "Mở khóa" : "Bảo trì") {
                                viewModel.toggleMaintenance(companyId: company.id, isMaintenance: !company.isMaintenance, token: token)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(company.isMaintenance ? .green : .red)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(PlainListStyle())
        }
        .sheet(isPresented: $showingCreate) {
            SACreateCompanyView(viewModel: viewModel, token: token, isPresented: $showingCreate)
        }
        .sheet(item: $showingCompanyDetails) { company in
            SACompanyDetailsView(company: company, viewModel: viewModel, token: token)
        }
    }
}

struct AccountsTab: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    
    var body: some View {
        VStack {
            Text("Quản lý tài khoản Super Admin")
                .font(.headline)
                .padding()
            
            List {
                ForEach(viewModel.superAdmins, id: \.self) { email in
                    Text(email)
                }
            }
        }
    }
}

struct ConfigTab: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    
    var body: some View {
        VStack {
            Text("Cấu hình hệ thống")
                .font(.headline)
                .padding()
            // Placeholder for global config
            Spacer()
        }
    }
}

// MARK: - Components & Sub-views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SACreateCompanyView: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var taxCode = ""
    @State private var email = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin công ty")) {
                    TextField("Tên công ty", text: $name)
                    TextField("Mã số thuế", text: $taxCode)
                    TextField("Email liên hệ", text: $email)
                }
                
                Button("Tạo Công ty") {
                    viewModel.createCompany(name: name, taxCode: taxCode, email: email, token: token)
                    isPresented = false
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle("Tạo Công ty Mới")
            .navigationBarItems(trailing: Button("Đóng") { isPresented = false })
        }
    }
}

struct SACompanyDetailsView: View {
    let company: SACompany
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    @Environment(\.presentationMode) var presentationMode
    
    @State private var licenseTier = ""
    @State private var maxDevices = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Thông tin")) {
                    Text("Tên: \(company.companyName)")
                    Text("ID: \(company.id)")
                    Text("Ngày tạo: \(formatDate(company.createdAt))")
                }
                
                Section(header: Text("Bản quyền")) {
                    TextField("Gói (PRO/BASIC...)", text: $licenseTier)
                    TextField("Số thiết bị tối đa", text: $maxDevices)
                        .keyboardType(.numberPad)
                    
                    Button("Cập nhật Bản quyền") {
                        let devices = Int(maxDevices) ?? company.maxDevices
                        viewModel.updateCompanyLicense(companyId: company.id, tier: licenseTier, maxDevices: devices, token: token)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Chi tiết Công ty")
            .navigationBarItems(trailing: Button("Đóng") { presentationMode.wrappedValue.dismiss() })
            .onAppear {
                licenseTier = company.licenseTier
                maxDevices = "\(company.maxDevices)"
            }
        }
    }
    
    private func formatDate(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}


// MARK: - Models & ViewModel

struct SACompany: Identifiable {
    var id: String
    var companyName: String
    var isMaintenance: Bool
    var licenseTier: String
    var maxDevices: Int
    var createdAt: Int64
}

class SuperAdminViewModel: ObservableObject {
    @Published var isSuperAdmin = false
    @Published var isLoading = false
    
    @Published var companies: [SACompany] = []
    @Published var superAdmins: [String] = []
    
    @Published var totalUsers: Int = 0
    @Published var totalDevices: Int = 0
    
    func checkSuperAdmin(email: String, token: String) {
        isLoading = true
        // Check super admin list
        let url = "\(FirebaseConfig.firestoreBaseUrl)/system_config/super_admin"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                self.isLoading = false
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any],
                   let emailsVal = fields["emails"] as? [String: Any],
                   let arrayVal = emailsVal["arrayValue"] as? [String: Any],
                   let values = arrayVal["values"] as? [[String: Any]] {
                    
                    let emails = values.compactMap { $0["stringValue"] as? String }
                    self.superAdmins = emails
                    self.isSuperAdmin = emails.contains(email) || email == "admin@qltb.com"
                    
                    if self.isSuperAdmin {
                        self.loadData(token: token)
                    }
                } else {
                    // Default fallback or error handling
                    self.isSuperAdmin = email == "admin@qltb.com"
                    if self.isSuperAdmin {
                        self.loadData(token: token)
                    }
                }
            }
        }.resume()
    }
    
    func loadData(token: String) {
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let documents = json["documents"] as? [[String: Any]] else {
                    return
                }
                
                self.companies = documents.compactMap { doc -> SACompany? in
                    guard let nameField = doc["name"] as? String,
                          let id = nameField.components(separatedBy: "/").last,
                          let fields = doc["fields"] as? [String: Any] else { return nil }
                    
                    let companyName = FirestoreHelper.getString(fields["companyName"] as? [String: Any])
                    let isMaintenance = FirestoreHelper.getBool(fields["isMaintenance"] as? [String: Any])
                    let licenseTier = FirestoreHelper.getString(fields["licenseTier"] as? [String: Any])
                    let maxDevices = FirestoreHelper.getInt(fields["maxDevices"] as? [String: Any])
                    let createdAt = FirestoreHelper.getInt64(fields["createdAt"] as? [String: Any])
                    
                    return SACompany(id: id, companyName: companyName.isEmpty ? "No Name" : companyName, isMaintenance: isMaintenance, licenseTier: licenseTier.isEmpty ? "PRO" : licenseTier, maxDevices: maxDevices == 0 ? 100 : maxDevices, createdAt: createdAt)
                }
                
                // Demo stats, in a real app you might need to query aggregation
                self.totalUsers = self.companies.count * 15
                self.totalDevices = self.companies.count * 45
            }
        }.resume()
    }
    
    func createCompany(name: String, taxCode: String, email: String, token: String) {
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "companyName": ["stringValue": name],
                "taxCode": ["stringValue": taxCode],
                "email": ["stringValue": email],
                "isMaintenance": ["booleanValue": false],
                "licenseTier": ["stringValue": "TRIAL"],
                "maxDevices": ["integerValue": "20"],
                "createdAt": ["integerValue": "\(Int64(Date().timeIntervalSince1970 * 1000))"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                DispatchQueue.main.async {
                    self.loadData(token: token)
                }
            }
        }.resume()
    }
    
    func toggleMaintenance(companyId: String, isMaintenance: Bool, token: String) {
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)?updateMask.fieldPaths=isMaintenance"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "isMaintenance": ["booleanValue": isMaintenance]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                DispatchQueue.main.async {
                    if let index = self.companies.firstIndex(where: { $0.id == companyId }) {
                        self.companies[index].isMaintenance = isMaintenance
                    }
                }
            }
        }.resume()
    }
    
    func updateCompanyLicense(companyId: String, tier: String, maxDevices: Int, token: String) {
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)?updateMask.fieldPaths=licenseTier&updateMask.fieldPaths=maxDevices"
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "licenseTier": ["stringValue": tier],
                "maxDevices": ["integerValue": "\(maxDevices)"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                DispatchQueue.main.async {
                    if let index = self.companies.firstIndex(where: { $0.id == companyId }) {
                        self.companies[index].licenseTier = tier
                        self.companies[index].maxDevices = maxDevices
                    }
                }
            }
        }.resume()
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
