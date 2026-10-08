import SwiftUI
import Combine

public struct SuperAdminPortalView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    
    @StateObject private var viewModel = SuperAdminViewModel()
    @State private var selectedTab = 0
    
    let tabs = ["Tổng quan", "Công ty", "Doanh thu SaaS", "Tài khoản", "Cấu hình"]
    
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
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        
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
                            SaaSBillingTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(2)
                            AccountsTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(3)
                            ConfigTab(viewModel: viewModel, token: authViewModel.currentIdToken)
                                .tag(4)
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

// MARK: - SaaS Seat Billing Tab & Audit
struct SaaSBillingTab: View {
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    
    @State private var selectedAuditStats: CompanyBillingStats? = nil
    @State private var editingPriceCompany: SACompany? = nil
    
    private var totalBillable: Int {
        viewModel.companyBillingMap.values.reduce(0) { $0 + $1.billableUsers }
    }
    private var totalFreeAdmins: Int {
        viewModel.companyBillingMap.values.reduce(0) { $0 + $1.adminUsers }
    }
    private var totalMrr: Int64 {
        viewModel.companyBillingMap.values.reduce(0) { $0 + $1.monthlyRevenue }
    }
    private var totalArr: Int64 {
        totalMrr * 12
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Banner Chính Sách SaaS
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text("Chính Sách SaaS Tính Phí Theo User Thực Tế")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#15803D"))
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.loadCompanyBillingStats(token: token)
                        }) {
                            HStack(spacing: 4) {
                                if viewModel.isLoadingBilling {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Quét User Cloud")
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#16A34A"))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(viewModel.isLoadingBilling)
                    }
                    
                    Text("• Người dùng tính phí (Seats): Chỉ tính các tài khoản thực tế đang hoạt động (không bị khóa/vô hiệu hóa).\n• Miễn phí 100% (0đ): Toàn bộ tài khoản Giám đốc, Quản trị viên (ADMIN, QUANTRI, SUPERADMIN) không tính phí.\n• Đơn giá linh hoạt: Mặc định 250.000 đ/user/tháng, cấu hình riêng cho từng khách hàng.")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#166534"))
                        .lineSpacing(3)
                }
                .padding()
                .background(Color(hex: "#F0FDF4"))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#BBF7D0"), lineWidth: 1)
                )
                
                // 4 Thẻ KPI
                HStack(spacing: 10) {
                    StatCard(title: "DOANH THU THÁNG (MRR)", value: formatCurrency(totalMrr), color: .green)
                    StatCard(title: "DOANH THU NĂM (ARR)", value: formatCurrency(totalArr), color: .blue)
                }
                HStack(spacing: 10) {
                    StatCard(title: "USER TÍNH PHÍ (SEATS)", value: "\(totalBillable)", color: .purple)
                    StatCard(title: "ADMIN MIỄN PHÍ (0đ)", value: "\(totalFreeAdmins)", color: .orange)
                }
                
                // Tiêu đề danh sách
                HStack {
                    Text("DANH SÁCH KHÁCH HÀNG & THU PHÍ SEATS")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#334155"))
                    Spacer()
                }
                .padding(.top, 4)
                
                if viewModel.companies.isEmpty {
                    Text("Chưa có công ty nào.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.companies) { comp in
                            let stats = viewModel.companyBillingMap[comp.id]
                            let billableCount = stats?.billableUsers ?? 0
                            let totalUserCount = stats?.totalUsers ?? 0
                            let freeAdmins = stats?.adminUsers ?? 0
                            let effPrice = comp.pricePerUserMonthly > 0 ? comp.pricePerUserMonthly : 250000
                            let monthlyRev = stats?.monthlyRevenue ?? (Int64(billableCount) * effPrice)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(comp.companyName)
                                            .font(.headline)
                                            .foregroundColor(Color(hex: "#1E293B"))
                                        Text("Mã: \(comp.id)")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    
                                    Button(action: {
                                        if let s = stats {
                                            selectedAuditStats = s
                                        } else {
                                            selectedAuditStats = CompanyBillingStats(
                                                companyId: comp.id,
                                                companyName: comp.companyName,
                                                totalUsers: totalUserCount,
                                                adminUsers: freeAdmins,
                                                billableUsers: billableCount,
                                                pricePerUser: effPrice,
                                                monthlyRevenue: monthlyRev,
                                                usersList: []
                                            )
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "person.2.fill")
                                                .font(.caption)
                                            Text("Soi User")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: "#EEF2FF"))
                                        .foregroundColor(Color(hex: "#4F46E5"))
                                        .cornerRadius(8)
                                    }
                                }
                                
                                Divider()
                                
                                // Stats Row
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("User tính phí")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        HStack(spacing: 2) {
                                            Text("\(billableCount)")
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                            Text(" / \(totalUserCount) user")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .center, spacing: 2) {
                                        Text("Admin miễn phí")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text("\(freeAdmins) (0đ)")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("Thành tiền/tháng")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        Text(formatCurrency(monthlyRev))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    }
                                }
                                
                                // Price Edit Bar
                                HStack {
                                    HStack(spacing: 4) {
                                        Text("Đơn giá:")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        Text("\(formatCurrency(effPrice))/user/tháng")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(Color(hex: "#334155"))
                                    }
                                    Spacer()
                                    Button(action: {
                                        editingPriceCompany = comp
                                    }) {
                                        HStack(spacing: 2) {
                                            Image(systemName: "pencil")
                                                .font(.caption2)
                                            Text("Sửa giá")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(8)
                                .background(Color(hex: "#F8FAFC"))
                                .cornerRadius(8)
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(item: $editingPriceCompany) { comp in
            SABillingEditPriceSheet(
                company: comp,
                viewModel: viewModel,
                token: token,
                isPresented: Binding(
                    get: { editingPriceCompany != nil },
                    set: { if !$0 { editingPriceCompany = nil } }
                )
            )
        }
        .sheet(item: $selectedAuditStats) { stats in
            CompanyUserAuditSheet(
                stats: stats,
                isPresented: Binding(
                    get: { selectedAuditStats != nil },
                    set: { if !$0 { selectedAuditStats = nil } }
                )
            )
        }
        .onAppear {
            if viewModel.companyBillingMap.isEmpty && !viewModel.companies.isEmpty {
                viewModel.loadCompanyBillingStats(token: token)
            }
        }
    }
    
    private func formatCurrency(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return "\(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") đ"
    }
}

struct SABillingEditPriceSheet: View {
    let company: SACompany
    @ObservedObject var viewModel: SuperAdminViewModel
    let token: String
    @Binding var isPresented: Bool
    
    @State private var priceInput: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cấu hình đơn giá / User / Tháng")) {
                    Text("Công ty: \(company.companyName)")
                        .font(.headline)
                    Text("Mã: \(company.id)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("Đơn giá VNĐ (ví dụ 250000)", text: $priceInput)
                        .keyboardType(.numberPad)
                    
                    Text("Mặc định hệ thống là 250.000 đ/user/tháng. Đặt giá ưu đãi riêng cho khách hàng này.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Button("Lưu Đơn Giá") {
                    let cleaned = priceInput.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: "")
                    let newPrice = Int64(cleaned) ?? 250000
                    viewModel.updateCompanyPrice(companyId: company.id, newPrice: newPrice, token: token)
                    isPresented = false
                }
                .disabled(priceInput.isEmpty)
            }
            .navigationTitle("Sửa Đơn Giá SaaS")
            .navigationBarItems(trailing: Button("Đóng") { isPresented = false })
            .onAppear {
                let current = company.pricePerUserMonthly > 0 ? company.pricePerUserMonthly : 250000
                priceInput = "\(current)"
            }
        }
    }
}

struct CompanyUserAuditSheet: View {
    let stats: CompanyBillingStats
    @Binding var isPresented: Bool
    
    @State private var searchQuery: String = ""
    @State private var filterType: String = "ALL" // ALL, BILLABLE, FREE
    
    var filteredUsers: [BillableUserDetail] {
        stats.usersList.filter { u in
            let matchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                u.name.localizedCaseInsensitiveContains(searchQuery) ||
                u.email.localizedCaseInsensitiveContains(searchQuery) ||
                u.role.localizedCaseInsensitiveContains(searchQuery) ||
                u.department.localizedCaseInsensitiveContains(searchQuery)
            
            let matchFilter: Bool
            switch filterType {
            case "BILLABLE": matchFilter = u.isBillable
            case "FREE": matchFilter = !u.isBillable
            default: matchFilter = true
            }
            return matchQuery && matchFilter
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Header Stats Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stats.companyName)
                            .font(.headline)
                        Text("Tổng \(stats.totalUsers) user | Tính phí: \(stats.billableUsers) | Miễn phí: \(stats.adminUsers)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Tìm theo tên, email, vai trò...", text: $searchQuery)
                        .font(.subheadline)
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(8)
                .background(Color(hex: "#F1F5F9"))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Filter Tabs
                HStack(spacing: 8) {
                    FilterButton(title: "Tất cả (\(stats.usersList.count))", isSelected: filterType == "ALL") {
                        filterType = "ALL"
                    }
                    FilterButton(title: "Tính phí (\(stats.billableUsers))", isSelected: filterType == "BILLABLE", activeColor: .green) {
                        filterType = "BILLABLE"
                    }
                    FilterButton(title: "Admin 0đ (\(stats.adminUsers))", isSelected: filterType == "FREE", activeColor: .orange) {
                        filterType = "FREE"
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // User List
                if filteredUsers.isEmpty {
                    Spacer()
                    Text("Không tìm thấy user nào phù hợp.")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                } else {
                    List {
                        ForEach(filteredUsers) { u in
                            HStack(alignment: .center, spacing: 10) {
                                Circle()
                                    .fill(u.isBillable ? Color(hex: "#DCFCE7") : Color(hex: "#FEF3C7"))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(String(u.name.prefix(1)).uppercased())
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(u.isBillable ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(u.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color(hex: "#1E293B"))
                                    Text(u.email.isEmpty ? u.id : u.email)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    if !u.department.isEmpty {
                                        Text("Phòng: \(u.department)")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(u.isBillable ? "Tính phí (\(formatCurrency(stats.pricePerUser)))" : "Miễn phí (0 đ)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(u.isBillable ? Color(hex: "#DCFCE7") : Color(hex: "#FEF3C7"))
                                        .foregroundColor(u.isBillable ? Color(hex: "#15803D") : Color(hex: "#B45309"))
                                        .cornerRadius(4)
                                    
                                    Text("Vai trò: \(u.role)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Soi Tài Khoản")
            .navigationBarItems(trailing: Button("Đóng") { isPresented = false })
        }
    }
    
    private func formatCurrency(_ amount: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return "\(formatter.string(from: NSNumber(value: amount)) ?? "\(amount)") đ"
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    var activeColor: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? activeColor : Color(hex: "#F1F5F9"))
                .foregroundColor(isSelected ? .white : Color(hex: "#475569"))
                .cornerRadius(6)
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

struct BillableUserDetail: Identifiable {
    var id: String { email }
    var email: String
    var name: String
    var role: String
    var department: String
    var isBillable: Bool
    var isActive: Bool
}

struct CompanyBillingStats: Identifiable {
    var id: String { companyId }
    var companyId: String
    var companyName: String
    var totalUsers: Int
    var adminUsers: Int
    var billableUsers: Int
    var pricePerUser: Int64
    var monthlyRevenue: Int64
    var usersList: [BillableUserDetail]
}

struct SACompany: Identifiable {
    var id: String
    var companyName: String
    var isMaintenance: Bool
    var licenseTier: String
    var maxDevices: Int
    var createdAt: Int64
    var pricePerUserMonthly: Int64 = 250000
}

class SuperAdminViewModel: ObservableObject {
    @Published var isSuperAdmin = false
    @Published var isLoading = false
    
    @Published var companies: [SACompany] = []
    @Published var superAdmins: [String] = []
    
    @Published var totalUsers: Int = 0
    @Published var totalDevices: Int = 0
    
    @Published var companyBillingMap: [String: CompanyBillingStats] = [:]
    @Published var isLoadingBilling: Bool = false
    
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
                    let rawPrice = FirestoreHelper.getInt64(fields["pricePerUserMonthly"] as? [String: Any])
                    let pricePerUserMonthly: Int64 = rawPrice > 0 ? rawPrice : 250000
                    
                    return SACompany(
                        id: id,
                        companyName: companyName.isEmpty ? "No Name" : companyName,
                        isMaintenance: isMaintenance,
                        licenseTier: licenseTier.isEmpty ? "PRO" : licenseTier,
                        maxDevices: maxDevices == 0 ? 100 : maxDevices,
                        createdAt: createdAt,
                        pricePerUserMonthly: pricePerUserMonthly
                    )
                }
                
                // Demo stats
                self.totalUsers = self.companies.count * 15
                self.totalDevices = self.companies.count * 45
                
                // Tự động tải thống kê SaaS Seat Billing
                self.loadCompanyBillingStats(token: token)
            }
        }.resume()
    }
    
    func loadCompanyBillingStats(token: String) {
        guard !companies.isEmpty else { return }
        isLoadingBilling = true
        let group = DispatchGroup()
        var newMap: [String: CompanyBillingStats] = [:]
        let lock = NSLock()
        
        for company in companies {
            group.enter()
            let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(company.id)/users?pageSize=300"
            guard let reqUrl = URL(string: url) else {
                group.leave()
                continue
            }
            var request = URLRequest(url: reqUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, _, _ in
                defer { group.leave() }
                var uList: [BillableUserDetail] = []
                let effectivePrice = company.pricePerUserMonthly > 0 ? company.pricePerUserMonthly : 250000
                
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = json["documents"] as? [[String: Any]] {
                    for doc in documents {
                        guard let fields = doc["fields"] as? [String: Any] else { continue }
                        let email = FirestoreHelper.getString(fields["email"] as? [String: Any])
                        let nameRaw = FirestoreHelper.getString(fields["name"] as? [String: Any])
                        let fullNameRaw = FirestoreHelper.getString(fields["fullName"] as? [String: Any])
                        let name = nameRaw.isEmpty ? (fullNameRaw.isEmpty ? "Chưa đặt tên" : fullNameRaw) : nameRaw
                        let role = FirestoreHelper.getString(fields["role"] as? [String: Any]).uppercased()
                        let deptRaw = FirestoreHelper.getString(fields["department"] as? [String: Any])
                        let phongBanRaw = FirestoreHelper.getString(fields["phongBan"] as? [String: Any])
                        let department = deptRaw.isEmpty ? phongBanRaw : deptRaw
                        let status = FirestoreHelper.getString(fields["status"] as? [String: Any]).uppercased()
                        let isActiveRaw = FirestoreHelper.getBool(fields["isActive"] as? [String: Any], defaultValue: true)
                        
                        let isActive = isActiveRaw && status != "LOCKED" && status != "DISABLED"
                        let isAdmin = ["ADMIN", "QUANTRI", "SUPER_ADMIN", "SUPERADMIN"].contains(role)
                        let isBillable = isActive && !isAdmin
                        
                        uList.append(BillableUserDetail(
                            email: email,
                            name: name,
                            role: role.isEmpty ? "STAFF" : role,
                            department: department,
                            isBillable: isBillable,
                            isActive: isActive
                        ))
                    }
                }
                
                let activeUsers = uList.filter { $0.isActive }
                let adminCount = activeUsers.filter { !$0.isBillable }.count
                let billableCount = activeUsers.filter { $0.isBillable }.count
                let monthlyRev = Int64(billableCount) * effectivePrice
                
                let stat = CompanyBillingStats(
                    companyId: company.id,
                    companyName: company.companyName,
                    totalUsers: activeUsers.count,
                    adminUsers: adminCount,
                    billableUsers: billableCount,
                    pricePerUser: effectivePrice,
                    monthlyRevenue: monthlyRev,
                    usersList: uList.sorted { $0.isBillable && !$1.isBillable }
                )
                
                lock.lock()
                newMap[company.id] = stat
                lock.unlock()
            }.resume()
        }
        
        group.notify(queue: .main) {
            self.companyBillingMap = newMap
            self.isLoadingBilling = false
        }
    }
    
    func updateCompanyPrice(companyId: String, newPrice: Int64, token: String) {
        let url = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)?updateMask.fieldPaths=pricePerUserMonthly"
        guard let reqUrl = URL(string: url) else { return }
        var request = URLRequest(url: reqUrl)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "fields": [
                "pricePerUserMonthly": ["integerValue": "\(newPrice)"]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                DispatchQueue.main.async {
                    if let index = self.companies.firstIndex(where: { $0.id == companyId }) {
                        self.companies[index].pricePerUserMonthly = newPrice
                    }
                    if var existing = self.companyBillingMap[companyId] {
                        existing.pricePerUser = newPrice
                        existing.monthlyRevenue = Int64(existing.billableUsers) * newPrice
                        self.companyBillingMap[companyId] = existing
                    }
                }
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
                "pricePerUserMonthly": ["integerValue": "250000"],
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

