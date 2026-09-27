import SwiftUI

// MARK: - LICENSE TIERS & INFOS
public enum LicenseTier: String {
    case TRIAL = "TRIAL"
    case TRIAL_VIP = "TRIAL_VIP"
    case BASIC = "BASIC"
    case PRO = "PRO"
    case PRO_PERSONAL = "PRO_PERSONAL"
    case PROFESSIONAL = "PROFESSIONAL"
    case ENTERPRISE = "ENTERPRISE"
    case FREE = "FREE"

    var displayName: String {
        switch self {
        case .TRIAL, .FREE: return "Dùng thử (Trial)"
        case .TRIAL_VIP: return "Dùng thử Full VIP"
        case .BASIC: return "Gói Cơ bản"
        case .PRO, .PRO_PERSONAL: return "Gói Nâng cao (Pro)"
        case .PROFESSIONAL: return "Gói Chuyên nghiệp"
        case .ENTERPRISE: return "Không giới hạn (Enterprise)"
        }
    }
}

public struct LicenseInfo {
    public var tier: LicenseTier = .TRIAL
    public var companyName: String = ""
    public var activationCode: String = ""
    public var activatedAt: Int64 = 0
    public var expiresAt: Int64 = 0
    public var maxDevices: Int = 5
    public var maxAssets: Int = 50
    
    var isExpired: Bool {
        return expiresAt > 0 && Int64(Date().timeIntervalSince1970 * 1000) > expiresAt
    }
}

struct TierConfig: Equatable {
    let id: String
    let name: String
    let maxDevices: Int
    let maxAssets: Int
    let monthlyPrice: Int64
    let iconName: String
}

// MARK: - VIEW MODEL
@MainActor
class PaywallLicenseViewModel: ObservableObject {
    @Published var licenseInfo = LicenseInfo()
    @Published var isActivating: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let companyId: String
    private let token: String
    
    init(companyId: String, token: String) {
        self.companyId = companyId.isEmpty ? "SGCOOP" : companyId
        self.token = token
        fetchCurrentLicense()
    }
    
    func fetchCurrentLicense() {
        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)"
            guard let url = URL(string: urlStr) else { return }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !token.isEmpty { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {
                    
                    let tierStr = FirestoreHelper.getString(fields["licenseTier"] as? [String: Any])
                    let tierEnum = LicenseTier(rawValue: tierStr) ?? .TRIAL
                    
                    self.licenseInfo = LicenseInfo(
                        tier: tierEnum,
                        companyName: self.companyId.uppercased(),
                        activationCode: "",
                        activatedAt: 0,
                        expiresAt: 0,
                        maxDevices: tierEnum == .ENTERPRISE ? 999999 : 50,
                        maxAssets: tierEnum == .ENTERPRISE ? 999999 : 500
                    )
                } else {
                    self.licenseInfo = LicenseInfo(tier: .TRIAL, companyName: "Trial", maxDevices: 5, maxAssets: 50)
                }
            } catch {
                self.licenseInfo = LicenseInfo(tier: .TRIAL, companyName: "Error", maxDevices: 5, maxAssets: 50)
            }
        }
    }
    
    func activateEnterpriseCode(code: String) {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanCode.isEmpty {
            self.errorMessage = "Vui lòng nhập Key kích hoạt!"
            return
        }
        isActivating = true
        self.errorMessage = nil
        self.successMessage = nil
        
        Task {
            let targetTier = cleanCode == "VIP" ? "TRIAL_VIP" : "ENTERPRISE"
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let expiresAt = now + (365 * 24 * 3600 * 1000) // 1 year
            
            // Lưu lên Firestore companies/{companyId}
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)?updateMask.fieldPaths=licenseTier&updateMask.fieldPaths=activationCode&updateMask.fieldPaths=activatedAt&updateMask.fieldPaths=expiresAt"
            if let url = URL(string: urlStr) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !token.isEmpty { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
                
                let body: [String: Any] = [
                    "fields": [
                        "licenseTier": ["stringValue": targetTier],
                        "activationCode": ["stringValue": cleanCode],
                        "activatedAt": ["integerValue": String(now)],
                        "expiresAt": ["integerValue": String(expiresAt)]
                    ]
                ]
                request.httpBody = try? JSONSerialization.data(withJSONObject: body)
                _ = try? await URLSession.shared.data(for: request)
            }
            
            let tierEnum = LicenseTier(rawValue: targetTier) ?? .ENTERPRISE
            self.licenseInfo = LicenseInfo(
                tier: tierEnum,
                companyName: companyId,
                activationCode: cleanCode,
                activatedAt: now,
                expiresAt: expiresAt,
                maxDevices: targetTier == "TRIAL_VIP" ? 9999 : 999999,
                maxAssets: targetTier == "TRIAL_VIP" ? 9999 : 999999
            )
            self.successMessage = cleanCode == "VIP" ? "Kích hoạt thành công gói Dùng thử Full VIP!" : "Kích hoạt thành công Key Doanh nghiệp!"
            self.isActivating = false
        }
    }
    
    func purchaseGooglePlay(planId: String) {
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.licenseInfo = LicenseInfo(tier: .PRO_PERSONAL, companyName: "Cá nhân", maxDevices: 100, maxAssets: 1000)
            self.successMessage = "Thanh toán Apple App Store thành công!"
        }
    }
}

// MARK: - MÀN HÌNH BẢN QUYỀN HỆ THỐNG DOANH NGHIỆP (ĐỒNG BỘ 1:1 THEO ANDROID PAYWALL/LICENSE)
public struct PaywallLicenseView: View {
    let companyId: String
    let token: String
    var onBack: () -> Void
    
    @StateObject private var viewModel: PaywallLicenseViewModel
    
    @State private var selectedTab: Int = 1 // 1: Mã Doanh nghiệp, 0: Gói Cá Nhân
    @State private var companyCodeInput: String = ""
    @State private var selectedPlanId: String = "pro_1_year"
    
    let tiers = [
        TierConfig(id: "BASIC", name: "Gói Cơ bản (20 máy / 200 tài sản)", maxDevices: 20, maxAssets: 200, monthlyPrice: 499000, iconName: "person.fill"),
        TierConfig(id: "PRO", name: "Gói Nâng cao (100 máy / 1.000 tài sản)", maxDevices: 100, maxAssets: 1000, monthlyPrice: 1490000, iconName: "cart.fill"),
        TierConfig(id: "PROFESSIONAL", name: "Gói Chuyên nghiệp (200 máy / 5.000 tài sản)", maxDevices: 200, maxAssets: 5000, monthlyPrice: 2990000, iconName: "building.2.fill"),
        TierConfig(id: "ENTERPRISE", name: "Enterprise 👑 Không giới hạn", maxDevices: 999999, maxAssets: 999999, monthlyPrice: 4990000, iconName: "globe.asia.australia.fill")
    ]
    @State private var selectedTier: TierConfig
    
    public init(companyId: String, token: String, onBack: @escaping () -> Void) {
        self.companyId = companyId
        self.token = token
        self.onBack = onBack
        self._viewModel = StateObject(wrappedValue: PaywallLicenseViewModel(companyId: companyId, token: token))
        self._selectedTier = State(initialValue: TierConfig(id: "BASIC", name: "Gói Cơ bản (20 máy / 200 tài sản)", maxDevices: 20, maxAssets: 200, monthlyPrice: 499000, iconName: "person.fill"))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))
                        
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
                    .background(Color.appTopBarColor)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            
                            // HERO CARD
                            VStack(spacing: 8) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.appPrimaryPink)
                                
                                Text("Mở khóa toàn bộ tính năng")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                
                                Text("Nâng cấp để quản lý tài sản chuyên nghiệp và tối ưu hiệu suất công việc")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.appPrimaryPink.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appPrimaryPink.opacity(0.2), lineWidth: 1))
                            
                            // TAB SELECTOR
                            HStack(spacing: 4) {
                                tabButton(title: "Cá nhân (App Store)", index: 0)
                                tabButton(title: "Mã Doanh nghiệp", index: 1)
                            }
                            .padding(4)
                            .background(Color.appSurfaceVariant.opacity(0.5))
                            .cornerRadius(12)
                            
                            // NỘI DUNG THEO TAB
                            if selectedTab == 0 {
                                personalTabContent
                            } else {
                                enterpriseTabContent
                            }
                            
                            // CURRENT PLAN CARD
                            VStack(alignment: .leading, spacing: 4) {
                                Text("GÓI HIỆN TẠI ĐANG DÙNG")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                
                                Text(viewModel.licenseInfo.tier.displayName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(statusColor(for: viewModel.licenseInfo.tier))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appSurface)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
                            
                            Spacer().frame(height: 16)
                        }
                        .padding(14)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert(isPresented: Binding<Bool>(
            get: { viewModel.errorMessage != nil || viewModel.successMessage != nil },
            set: { _ in viewModel.errorMessage = nil; viewModel.successMessage = nil }
        )) {
            Alert(
                title: Text(viewModel.errorMessage != nil ? "Lỗi" : "Thành công"),
                message: Text(viewModel.errorMessage ?? viewModel.successMessage ?? ""),
                dismissButton: .default(Text("OK")) {
                    viewModel.errorMessage = nil
                    viewModel.successMessage = nil
                }
            )
        }
    }
    
    private func tabButton(title: String, index: Int) -> some View {
        Button(action: { selectedTab = index }) {
            Text(title)
                .font(.system(size: 13, weight: selectedTab == index ? .bold : .medium))
                .foregroundColor(selectedTab == index ? .white : Color.appSecondaryDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selectedTab == index ? Color.appPrimaryPink : Color.clear)
                .cornerRadius(10)
        }
    }
    
    private var personalTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mua trực tiếp qua App Store (Apple)")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            // 1. CHỌN SỐ LƯỢNG
            Text("1. Chọn số lượng tài sản")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)
            
            VStack(spacing: 8) {
                ForEach(tiers, id: \.id) { tier in
                    let isSelected = selectedTier.id == tier.id
                    Button(action: { selectedTier = tier }) {
                        HStack {
                            Image(systemName: tier.iconName)
                                .foregroundColor(isSelected ? Color.appSecondaryDarkBlue : .gray)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.name)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text("Tối đa \(tier.maxDevices) máy cài • \(tier.maxAssets) tài sản")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("\(formatCurrency(tier.monthlyPrice))đ")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isSelected ? Color.appSecondaryDarkBlue : .gray)
                        }
                        .padding(12)
                        .background(isSelected ? Color.appSecondaryDarkBlue.opacity(0.05) : Color.clear)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appSecondaryDarkBlue : Color.appCardBorder, lineWidth: isSelected ? 2 : 1))
                    }
                }
            }
            
            // 2. CHỌN THỜI HẠN
            Text("2. Chọn thời hạn thanh toán")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)
            
            VStack(spacing: 8) {
                let price1Year = Int64(Double(selectedTier.monthlyPrice * 12) * 0.65)
                planCard(id: "pro_1_year", title: "Gói 1 năm", price: "\(formatCurrency(price1Year))đ", subText: "Giảm 35% 🔥", isBestValue: true)
                
                let price6Months = Int64(Double(selectedTier.monthlyPrice * 6) * 0.8)
                planCard(id: "pro_6_month", title: "Gói 6 tháng", price: "\(formatCurrency(price6Months))đ", subText: "Giảm 20%")
            }
            
            Divider()
            
            featureRow("Quản lý tối đa \(selectedTier.maxAssets) tài sản")
            featureRow("Hỗ trợ kỹ thuật HelpDesk")
            featureRow("Báo cáo xuất dữ liệu Excel/PDF")
            
            Button(action: {
                viewModel.purchaseGooglePlay(planId: selectedPlanId)
            }) {
                HStack {
                    Image(systemName: "bag.fill")
                    Text("Mua qua App Store")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.appPrimaryPink)
                .cornerRadius(10)
            }
            
            Button(action: {
                // Restore purchase logic
            }) {
                Text("Khôi phục thanh toán cũ")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }
    
    private func planCard(id: String, title: String, price: String, subText: String, isBestValue: Bool = false) -> some View {
        let isSelected = selectedPlanId == id
        return Button(action: { selectedPlanId = id }) {
            ZStack(alignment: .topTrailing) {
                HStack {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSelected ? Color.appPrimaryPink : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text(subText)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(price)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(isSelected ? Color.appPrimaryPink.opacity(0.08) : Color.clear)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Color.appPrimaryPink : Color.appCardBorder, lineWidth: isSelected ? 2 : 1))
                
                if isBestValue {
                    Text("TIẾT KIỆM 35%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .cornerRadius(4, corners: [.bottomLeft, .topRight])
                }
            }
        }
    }
    
    private var enterpriseTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Kích hoạt Gói Doanh nghiệp")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)
            
            Text("Nhập mã kích hoạt được cấp bởi Super Admin hoặc đại lý uỷ quyền.")
                .font(.system(size: 13))
                .foregroundColor(.gray)
            
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(Color.appPrimaryPink)
                TextField("Nhập Key bản quyền...", text: $companyCodeInput)
                    .autocapitalization(.allCharacters)
            }
            .padding()
            .background(Color.appSurfaceVariant.opacity(0.5))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appPrimaryPink.opacity(0.5), lineWidth: 1))
            
            Button(action: {
                viewModel.activateEnterpriseCode(code: companyCodeInput)
            }) {
                HStack {
                    if viewModel.isActivating {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Kích hoạt Key bản quyền")
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.isActivating ? Color.gray : Color.appSecondaryDarkBlue)
                .cornerRadius(10)
            }
            .disabled(viewModel.isActivating)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("💼 Giải pháp cho doanh nghiệp / Chi nhánh")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
                Text("• Phân định rõ số máy cài đặt & số tài sản quản lý.\n• Gói Pro / Enterprise hỗ trợ chấm công GPS.\n• Hỗ trợ xuất hóa đơn VAT đỏ.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(12)
            .background(Color.appSurfaceVariant.opacity(0.3))
            .cornerRadius(8)
            
            Button(action: {
                // Contact logic
            }) {
                HStack {
                    Image(systemName: "phone.fill")
                    Text("Liên hệ báo giá số lượng lớn")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.appSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))
    }
    
    private func featureRow(_ text: String) -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color.appSuccess)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.black)
            Spacer()
        }
    }
    
    private func statusColor(for tier: LicenseTier) -> Color {
        switch tier {
        case .TRIAL, .FREE: return .gray
        case .TRIAL_VIP: return .orange
        case .BASIC: return .blue
        case .PRO, .PRO_PERSONAL: return .orange
        case .PROFESSIONAL: return .purple
        case .ENTERPRISE: return .green
        }
    }
    
    private func formatCurrency(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
