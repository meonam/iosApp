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
                    let tierEnum = LicenseTier(rawValue: tierStr.uppercased()) ?? (tierStr.uppercased().contains("ENT") ? .ENTERPRISE : .TRIAL)
                    let code = FirestoreHelper.getString(fields["licenseCode"] as? [String: Any])
                    let rawCode = code.isEmpty ? FirestoreHelper.getString(fields["activationCode"] as? [String: Any]) : code
                    let exp1 = FirestoreHelper.getInt64(fields["licenseExpiresAt"] as? [String: Any])
                    let exp2 = FirestoreHelper.getInt64(fields["expiresAt"] as? [String: Any])
                    let effectiveExpiresAt = exp1 > 0 ? exp1 : exp2
                    let compName = FirestoreHelper.getString(fields["companyName"] as? [String: Any])
                    let maxDev = FirestoreHelper.getInt(fields["maxDevices"] as? [String: Any])
                    let maxAss = FirestoreHelper.getInt(fields["maxAssets"] as? [String: Any])

                    self.licenseInfo = LicenseInfo(
                        tier: tierEnum,
                        companyName: compName.isEmpty ? self.companyId.uppercased() : compName,
                        activationCode: rawCode.isEmpty ? (tierEnum == .ENTERPRISE ? "QLTB-ENT-F8CF2F" : "") : rawCode,
                        activatedAt: FirestoreHelper.getInt64(fields["activatedAt"] as? [String: Any]),
                        expiresAt: effectiveExpiresAt,
                        maxDevices: tierEnum == .ENTERPRISE ? 999999 : (maxDev > 0 ? maxDev : 50),
                        maxAssets: tierEnum == .ENTERPRISE ? 999999 : (maxAss > 0 ? maxAss : 500)
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

            // Lưu lên Firestore companies/{companyId} với đầy đủ các field chuẩn
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)?updateMask.fieldPaths=licenseTier&updateMask.fieldPaths=licenseCode&updateMask.fieldPaths=licenseExpiresAt&updateMask.fieldPaths=licenseUpdatedAt&updateMask.fieldPaths=activationCode&updateMask.fieldPaths=expiresAt&updateMask.fieldPaths=maxDevices&updateMask.fieldPaths=maxAssets"
            if let url = URL(string: urlStr) {
                var request = URLRequest(url: url)
                request.httpMethod = "PATCH"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                if !token.isEmpty { request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

                let body: [String: Any] = [
                    "fields": [
                        "licenseTier": ["stringValue": targetTier],
                        "licenseCode": ["stringValue": cleanCode],
                        "licenseExpiresAt": ["integerValue": String(expiresAt)],
                        "licenseUpdatedAt": ["integerValue": String(now)],
                        "activationCode": ["stringValue": cleanCode],
                        "expiresAt": ["integerValue": String(expiresAt)],
                        "maxDevices": ["integerValue": String(targetTier == "ENTERPRISE" ? 999999 : 100)],
                        "maxAssets": ["integerValue": String(targetTier == "ENTERPRISE" ? 999999 : 1000)]
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
    
    }
}

// MARK: - MÀN HÌNH BẢN QUYỀN HỆ THỐNG DOANH NGHIỆP (KHÔNG PAYWALL STORE)
public struct PaywallLicenseView: View {
    let companyId: String
    let token: String
    var onBack: () -> Void

    @StateObject private var viewModel: PaywallLicenseViewModel
    @State private var companyCodeInput: String = ""

    public init(companyId: String, token: String, onBack: @escaping () -> Void = {}) {
        self.companyId = companyId
        self.token = token
        self.onBack = onBack
        self._viewModel = StateObject(wrappedValue: PaywallLicenseViewModel(companyId: companyId, token: token))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 1. TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }

                            Text("Kích hoạt Bản quyền Doanh nghiệp")
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
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(Color.appPrimaryPink)

                                Text("Bản quyền Hệ thống IT & Tài sản")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                Text("Quản lý thiết bị, hạ tầng kỹ thuật và điều phối hỗ trợ nội bộ cho Doanh nghiệp")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.appPrimaryPink.opacity(0.06))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appPrimaryPink.opacity(0.2), lineWidth: 1))

                            // THẺ THÔNG TIN BẢN QUYỀN HIỆN TẠI
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("TRẠNG THÁI HIỆN TẠI")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(viewModel.licenseInfo.tier.displayName)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(statusColor(for: viewModel.licenseInfo.tier))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(statusColor(for: viewModel.licenseInfo.tier).opacity(0.1))
                                        .cornerRadius(6)
                                }

                                Divider().background(Color.appCardBorder)

                                infoRow(title: "Doanh nghiệp", value: viewModel.licenseInfo.companyName.isEmpty ? companyId.uppercased() : viewModel.licenseInfo.companyName)
                                infoRow(title: "Mã kích hoạt", value: viewModel.licenseInfo.activationCode.isEmpty ? "QLTB-ENT-F8CF2F" : viewModel.licenseInfo.activationCode)

                                let expText: String = {
                                    if viewModel.licenseInfo.expiresAt > 0 {
                                        let df = DateFormatter()
                                        df.dateFormat = "dd/MM/yyyy"
                                        return df.string(from: Date(timeIntervalSince1970: Double(viewModel.licenseInfo.expiresAt) / 1000.0))
                                    }
                                    return viewModel.licenseInfo.tier == .ENTERPRISE ? "Vĩnh viễn theo hợp đồng" : "Không giới hạn ngày"
                                }()
                                infoRow(title: "Thời hạn", value: expText, valueColor: Color.appSuccess)

                                let devText = viewModel.licenseInfo.tier == .ENTERPRISE ? "Không giới hạn" : "\(viewModel.licenseInfo.maxDevices) máy"
                                infoRow(title: "Hạn mức thiết bị", value: devText)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appSurface)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                            // THẺ NHẬP KEY KÍCH HOẠT
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Kích hoạt mã License Key")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)

                                Text("Nhập mã bản quyền được cung cấp bởi Quản trị viên cấp cao (Super Admin).")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)

                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundColor(Color.appPrimaryPink)
                                    TextField("Nhập mã Key (VD: QLTB-ENT-...)", text: $companyCodeInput)
                                        .autocapitalization(.allCharacters)
                                        .disableAutocorrection(true)
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
                                            Text("Xác nhận kích hoạt")
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(viewModel.isActivating ? Color.gray : Color.appDarkButtonBackground)
                                    .cornerRadius(10)
                                }
                                .disabled(viewModel.isActivating || companyCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            .padding(14)
                            .background(Color.appSurface)
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appCardBorder, lineWidth: 1))

                            // THẺ LIÊN HỆ & HỢP ĐỒNG B2B
                            VStack(alignment: .leading, spacing: 8) {
                                Text("🏢 Hợp đồng & Triển khai giải pháp")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                Text("• Hệ thống vận hành nội bộ theo chính sách bảo mật doanh nghiệp.\n• Đầy đủ tính năng: Điều phối KTV, Chấm công GPS, HelpDesk, Báo cáo công tác phí.\n• Liên hệ Quản trị viên để cấp thêm mã kích hoạt cho chi nhánh mới.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.appSurfaceVariant.opacity(0.3))
                            .cornerRadius(10)

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

    private func infoRow(title: String, value: String, valueColor: Color = Color.appTextPrimary) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(valueColor)
        }
    }

    private func statusColor(for tier: LicenseTier) -> Color {
        switch tier {
        case .TRIAL, .FREE: return .gray
        case .TRIAL_VIP: return .orange
        case .BASIC: return .blue
        case .PRO, .PRO_PERSONAL: return .blue
        case .PROFESSIONAL: return .purple
        case .ENTERPRISE: return .green
        }
    }
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
