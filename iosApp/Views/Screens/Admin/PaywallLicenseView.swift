import SwiftUI

// MARK: - MODELS
struct LicenseTierModel: Identifiable, Equatable {
    let id: String
    let name: String
    let maxDevices: Int
    let maxAssets: Int
    let monthlyPrice: Int
    let iconName: String
}

struct LicensePlanModel: Identifiable, Equatable {
    let id: String
    let title: String
    let discount: Double
    let months: Int
    let isBestValue: Bool
}

// MARK: - MÀN HÌNH BẢN QUYỀN HỆ THỐNG DOANH NGHIỆP (ĐỒNG BỘ 1:1 THEO ANDROID PAYWALL/LICENSE)
public struct PaywallLicenseView: View {
    var onBack: () -> Void
    
    @State private var selectedTab: Int = 0 // 0: Cá nhân, 1: Doanh nghiệp
    
    // Tiers & Plans
    let tiers = [
        LicenseTierModel(id: "BASIC", name: "Gói Cơ bản (20 máy / 200 tài sản)", maxDevices: 20, maxAssets: 200, monthlyPrice: 499000, iconName: "person.fill"),
        LicenseTierModel(id: "PRO", name: "Gói Nâng cao (100 máy / 1000 tài sản)", maxDevices: 100, maxAssets: 1000, monthlyPrice: 1490000, iconName: "storefront.fill"),
        LicenseTierModel(id: "PROFESSIONAL", name: "Gói Chuyên nghiệp (200 máy / 5000 tài sản)", maxDevices: 200, maxAssets: 5000, monthlyPrice: 2990000, iconName: "building.2.fill"),
        LicenseTierModel(id: "ENTERPRISE", name: "Enterprise 👑 Không giới hạn máy & tài sản", maxDevices: 999999, maxAssets: 999999, monthlyPrice: 4990000, iconName: "globe.asia.australia.fill")
    ]
    
    let plans = [
        LicensePlanModel(id: "1_YEAR", title: "1 Năm", discount: 0.65, months: 12, isBestValue: true),
        LicensePlanModel(id: "6_MONTHS", title: "6 Tháng", discount: 0.8, months: 6, isBestValue: false),
        LicensePlanModel(id: "3_MONTHS", title: "3 Tháng", discount: 0.9, months: 3, isBestValue: false),
        LicensePlanModel(id: "1_MONTH", title: "1 Tháng", discount: 1.0, months: 1, isBestValue: false)
    ]
    
    @State private var selectedTier: LicenseTierModel
    @State private var selectedPlan: LicensePlanModel
    @State private var companyCodeInput: String = ""
    
    @State private var isActivating: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    @State private var currentLicenseTier: String = "BASIC"
    @State private var isLoadingLicense: Bool = true
    
    public init(onBack: @escaping () -> Void) {
        self.onBack = onBack
        _selectedTier = State(initialValue: LicenseTierModel(id: "BASIC", name: "Gói Cơ bản (20 máy / 200 tài sản)", maxDevices: 20, maxAssets: 200, monthlyPrice: 499000, iconName: "person.fill"))
        _selectedPlan = State(initialValue: LicensePlanModel(id: "1_YEAR", title: "1 Năm", discount: 0.65, months: 12, isBestValue: true))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        
                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Bản quyền & Gói dịch vụ")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appPrimary)
                    
                    // NỘI DUNG CUỘN
                    ScrollView {
                        VStack(spacing: 16) {
                            
                            // Hero Card
                            heroCard()
                            
                            // Tab Selector
                            tabSelector()
                            
                            if selectedTab == 0 {
                                personalTabContent()
                            } else {
                                enterpriseTabContent()
                            }
                            
                            // Current License Card
                            currentLicenseCard()
                            
                        }
                        .padding(16)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onAppear {
            fetchCurrentLicense()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("Đóng")))
        }
    }
    
    // MARK: - VIEWS
    private func heroCard() -> some View {
        VStack(spacing: 8) {
            Image(systemName: "star.circle.fill")
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundColor(Color.appPrimary)
                .cornerRadius(12)
            
            Text("Mở khóa toàn bộ tính năng")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appPrimary)
            
            Text("Nâng cấp để quản lý không giới hạn tài sản, nhân sự và các tính năng nâng cao.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.appPrimary.opacity(0.06))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appPrimary.opacity(0.2), lineWidth: 1))
    }
    
    private func tabSelector() -> some View {
        HStack(spacing: 4) {
            tabButton(title: "Cá nhân (Apple)", isSelected: selectedTab == 0, index: 0)
            tabButton(title: "Mã Doanh Nghiệp", isSelected: selectedTab == 1, index: 1)
        }
        .padding(4)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
    
    private func tabButton(title: String, isSelected: Bool, index: Int) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color.appPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appPrimary : Color.clear)
                .cornerRadius(10)
        }
    }
    
    private func personalTabContent() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Mua qua In-App Purchase")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                Text("Thanh toán an toàn qua Apple. Tự động gia hạn.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                // 1. Chọn Quy mô
                Text("1. Chọn quy mô quản lý tài sản")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .padding(.top, 8)
                
                VStack(spacing: 8) {
                    ForEach(tiers) { tier in
                        tierRow(tier: tier)
                    }
                }
                
                // 2. Chọn Chu kỳ
                Text("2. Chọn thời hạn thanh toán")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                    .padding(.top, 8)
                
                VStack(spacing: 8) {
                    ForEach(plans) { plan in
                        planRow(plan: plan)
                    }
                }
                
                Divider().padding(.vertical, 8)
                
                // Features
                VStack(alignment: .leading, spacing: 8) {
                    featureRow(text: "Quản lý \(selectedTier.maxAssets > 10000 ? "không giới hạn" : "tối đa \(selectedTier.maxAssets)") tài sản (\(selectedTier.maxDevices) máy cài)")
                    featureRow(text: "Hệ thống Hỗ trợ trực tuyến / HelpDesk & Chat 2 chiều")
                    if selectedTier.id != "BASIC" {
                        featureRow(text: "Đánh giá chất lượng sau sửa chữa & Báo cáo KPI KTV")
                        featureRow(text: "Điểm danh Chấm công GPS cá nhân (Vào/Ra ca)")
                    }
                    if selectedTier.id == "PROFESSIONAL" || selectedTier.id == "ENTERPRISE" {
                        featureRow(text: "Quản trị Chấm công toàn diện & Geofencing GPS")
                        featureRow(text: "Quyết toán công tác phí KTV theo Km OSRM")
                    }
                    featureRow(text: "Xuất dữ liệu & Báo cáo (Excel, PDF)")
                    featureRow(text: "In tem nhãn QR Code / Barcode máy in nhiệt")
                }
                
                Spacer().frame(height: 8)
                
                // Button Purchase
                Button(action: {
                    alertMessage = "Đang xử lý thanh toán qua Apple (Mock)..."
                    showAlert = true
                }) {
                    HStack {
                        Image(systemName: "bag.fill")
                        Text("Nâng cấp ngay (\(formatCurrency(calculatePrice(tier: selectedTier, plan: selectedPlan))))")
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.appPrimary)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    alertMessage = "Khôi phục thanh toán thành công!"
                    showAlert = true
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Khôi phục mua hàng")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1))
        }
    }
    
    private func enterpriseTabContent() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kích hoạt mã Doanh Nghiệp")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appPrimary)
            
            Text("Nhập mã kích hoạt được cung cấp bởi nhà phát hành dành riêng cho doanh nghiệp của bạn.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(Color.appPrimary)
                TextField("Nhập Key bản quyền...", text: $companyCodeInput)
                    .textInputAutocapitalization(.characters)
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appPrimary.opacity(0.5), lineWidth: 1))
            
            Button(action: activateEnterpriseCode) {
                HStack {
                    if isActivating {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Kích hoạt Key")
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimary)
                .cornerRadius(10)
            }
            .disabled(isActivating)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("💼 Giải pháp cho doanh nghiệp / Chi nhánh")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appPrimary)
                Text("• Phân định 2 chiều: Số máy cài app & Số tài sản quản lý.\n• Gói Basic (20 máy / 200 tài sản): Quản lý tài sản + Hỗ trợ kỹ thuật HelpDesk.\n• Gói Pro (100 máy / 1.000 tài sản): Thêm Đánh giá KPI & Chấm công GPS cá nhân.\n• Gói Professional & Enterprise: Mở Quản trị Chấm công toàn diện & Quyết toán công tác phí OSRM.\n• Xuất hóa đơn VAT & Hợp đồng đầy đủ.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Button(action: {
                    alertMessage = "Mở Zalo/Hotline hỗ trợ (Mock)"
                    showAlert = true
                }) {
                    HStack {
                        Image(systemName: "headphones")
                        Text("Liên hệ báo giá số lượng lớn")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
            
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
    
    private func currentLicenseCard() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Gói bản quyền hiện tại")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                if isLoadingLicense {
                    ProgressView()
                } else {
                    Text(currentLicenseTier)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(currentLicenseTier.contains("ENTERPRISE") ? .green : Color.appPrimary)
                }
            }
            Spacer()
            Image(systemName: "crown.fill")
                .font(.system(size: 32))
                .foregroundColor(.orange)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
    
    // MARK: - COMPONENTS
    
    private func tierRow(tier: LicenseTierModel) -> some View {
        let isSelected = selectedTier.id == tier.id
        return Button(action: { selectedTier = tier }) {
            HStack(spacing: 12) {
                Image(systemName: tier.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.appPrimary : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tier.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appPrimary)
                    Text(tier.maxAssets > 10000 ? "Quản lý không giới hạn" : "Tối đa \(tier.maxDevices) máy • \(tier.maxAssets) tài sản")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("\(formatCurrency(tier.monthlyPrice))/th")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(isSelected ? Color.appPrimary : .black)
            }
            .padding(12)
            .background(isSelected ? Color.appPrimary.opacity(0.05) : Color.clear)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimary : Color.gray.opacity(0.4), lineWidth: isSelected ? 2 : 1))
        }
    }
    
    private func planRow(plan: LicensePlanModel) -> some View {
        let isSelected = selectedPlan.id == plan.id
        let price = calculatePrice(tier: selectedTier, plan: plan)
        let perMonth = price / plan.months
        
        return Button(action: { selectedPlan = plan }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? Color.appPrimary : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appPrimary)
                        Text(plan.isBestValue ? "Chỉ \(formatCurrency(perMonth))/tháng • Giảm 35% 🔥" : (plan.discount < 1.0 ? "Chỉ \(formatCurrency(perMonth))/tháng • Giảm \(Int((1.0 - plan.discount)*100))%" : "Giá gốc • Linh hoạt"))
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(formatCurrency(price))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? Color.appPrimary : .black)
                }
                .padding(12)
                .background(isSelected ? Color.appPrimary.opacity(0.08) : Color.clear)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimary : Color.gray.opacity(0.35), lineWidth: isSelected ? 1.6 : 1))
                
                if plan.isBestValue {
                    Text("TIẾT KIỆM 35% 🔥")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(PaywallRoundedCorner(radius: 12, corners: [.topRight, .bottomLeft]))
                }
            }
        }
    }
    
    private func featureRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - UTILS
    private func calculatePrice(tier: LicenseTierModel, plan: LicensePlanModel) -> Int {
        return Int(Double(tier.monthlyPrice * plan.months) * plan.discount)
    }
    
    private func formatCurrency(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return (formatter.string(from: NSNumber(value: value)) ?? "\(value)") + " đ"
    }
    
    private func activateEnterpriseCode() {
        guard !companyCodeInput.isEmpty else {
            alertMessage = "Vui lòng nhập mã kích hoạt!"
            showAlert = true
            return
        }
        
        isActivating = true
        // Mock API Call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isActivating = false
            alertMessage = "Kích hoạt mã \(companyCodeInput) thành công!"
            showAlert = true
            companyCodeInput = ""
            currentLicenseTier = "ENTERPRISE CAO CẤP"
        }
    }
    
    private func fetchCurrentLicense() {
        isLoadingLicense = true
        // Mock fetch from Firestore REST API pattern as requested
        // Using `FirebaseConfig.firestoreBaseUrl + "/companies/saigoncoop/license"`
        // Simulating the fetch:
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isLoadingLicense = false
            currentLicenseTier = "GÓI CƠ BẢN"
        }
    }
}

// MARK: - CUSTOM SHAPES
struct PaywallRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
