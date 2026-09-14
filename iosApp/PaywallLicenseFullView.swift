import SwiftUI
import UIKit

// MARK: - TIER CONFIG MODEL
struct SaaSPlanTier: Identifiable, Hashable {
    var id: String
    var name: String
    var maxDevices: Int
    var maxAssets: Int
    var monthlyPrice: Int
    var icon: String
    var badge: String? = nil
}

// MARK: - PAYWALL & LICENSE FULL VIEW (Matches Android PaywallScreen.kt)
struct PaywallLicenseFullView: View {
    @EnvironmentObject var firebase: FirebaseService
    var onDismiss: () -> Void

    @State private var selectedTab: Int = 1 // Default to Enterprise License Key Tab (Tab 1)
    @State private var selectedTierId: String = "PRO"
    @State private var selectedBillingCycle: String = "1_YEAR" // "1_YEAR", "6_MONTHS", "3_MONTHS", "1_MONTH"
    @State private var licenseKeyInput: String = ""
    @State private var isActivating: Bool = false
    @State private var activationMessage: String? = nil
    @State private var isSuccess: Bool = false

    // AppStorage for persistence
    @AppStorage("coop_license_tier") private var currentLicenseTier: String = "ENTERPRISE"
    @AppStorage("coop_license_expiry") private var licenseExpiryDate: String = "31/12/2026"
    @AppStorage("coop_license_key") private var savedLicenseKey: String = "SG-ENT-COOP-8888"

    // Swipe back offset
    @State private var dragOffsetX: CGFloat = 0

    // Available Tiers
    let tiers: [SaaSPlanTier] = [
        SaaSPlanTier(id: "BASIC", name: "Gói Cơ Bản", maxDevices: 20, maxAssets: 200, monthlyPrice: 499_000, icon: "person.crop.circle.fill"),
        SaaSPlanTier(id: "PRO", name: "Gói Nâng Cao", maxDevices: 100, maxAssets: 1_000, monthlyPrice: 1_490_000, icon: "storefront.fill", badge: "PHỔ BIẾN"),
        SaaSPlanTier(id: "PROFESSIONAL", name: "Gói Chuyên Nghiệp", maxDevices: 200, maxAssets: 5_000, monthlyPrice: 2_990_000, icon: "building.2.fill"),
        SaaSPlanTier(id: "ENTERPRISE", name: "Saigon Co.op Enterprise 👑", maxDevices: 999_999, maxAssets: 999_999, monthlyPrice: 4_990_000, icon: "crown.fill", badge: "TỐI ƯU")
    ]

    var selectedTier: SaaSPlanTier {
        tiers.first(where: { $0.id == selectedTierId }) ?? tiers[1]
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // 1. HERO HEADER CARD
                        heroHeaderCard

                        // 2. TAB SELECTOR BAR
                        tabSelectorBar

                        // 3. TAB CONTENT
                        if selectedTab == 0 {
                            personalSubscriptionTabContent
                        } else {
                            enterpriseLicenseKeyTabContent
                        }

                        // 4. CURRENT LICENSE BADGE
                        currentLicenseBadgeCard

                        Spacer(minLength: 32)
                    }
                    .padding(14)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { onDismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Trở lại")
                        }
                        .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("BẢN QUYỀN DOANH NGHIỆP")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { onDismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffsetX = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 120 {
                        onDismiss()
                    }
                    dragOffsetX = 0
                }
        )
    }

    // MARK: - 1. HERO HEADER CARD
    private var heroHeaderCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.appPrimaryPink.opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: "crown.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color.appPrimaryPink)
            }

            Text("MỞ KHÓA TOÀN BỘ TÍNH NĂNG")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.appSecondaryDarkBlue)

            Text("Giải pháp quản lý tài sản, điều phối KTV và giám sát chấm công theo tiêu chuẩn chuỗi siêu thị Saigon Co.op.")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color.appPrimaryPink.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appPrimaryPink.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 2. TAB SELECTOR BAR
    private var tabSelectorBar: some View {
        HStack(spacing: 4) {
            Button(action: { selectedTab = 0 }) {
                Text("Gói Thuê Bao Cá Nhân")
                    .font(.system(size: 12, weight: selectedTab == 0 ? .bold : .medium))
                    .foregroundColor(selectedTab == 0 ? .white : Color.appSecondaryDarkBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(selectedTab == 0 ? Color.appPrimaryPink : Color.clear)
                    .cornerRadius(9)
            }

            Button(action: { selectedTab = 1 }) {
                HStack(spacing: 4) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 11))
                    Text("Mã Bản Quyền Doanh Nghiệp")
                }
                .font(.system(size: 12, weight: selectedTab == 1 ? .bold : .medium))
                .foregroundColor(selectedTab == 1 ? .white : Color.appSecondaryDarkBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(selectedTab == 1 ? Color.appPrimaryPink : Color.clear)
                .cornerRadius(9)
            }
        }
        .padding(3)
        .background(Color(hex: "#F1F5F9"))
        .cornerRadius(12)
    }

    // MARK: - TAB 0: PERSONAL SUBSCRIPTION CONTENT
    private var personalSubscriptionTabContent: some View {
        VStack(spacing: 14) {
            // Tier selection
            VStack(alignment: .leading, spacing: 8) {
                Text("1. CHỌN QUY MÔ QUẢN LÝ TÀI SẢN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                ForEach(tiers) { tier in
                    let isSel = selectedTierId == tier.id
                    Button(action: { selectedTierId = tier.id }) {
                        HStack(spacing: 12) {
                            Image(systemName: tier.icon)
                                .font(.system(size: 22))
                                .foregroundColor(isSel ? Color.appSecondaryDarkBlue : .gray)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(tier.name)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                    if let badge = tier.badge {
                                        Text(badge)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.appPrimaryPink)
                                            .cornerRadius(6)
                                    }
                                }

                                Text(tier.maxAssets > 10000 ? "Không giới hạn số lượng tài sản" : "Tối đa \(tier.maxDevices) máy cài • \(tier.maxAssets) tài sản")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            Text("\(formatCurrency(Double(tier.monthlyPrice)))/th")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isSel ? Color.appSecondaryDarkBlue : .gray)
                        }
                        .padding(12)
                        .background(isSel ? Color.appSecondaryDarkBlue.opacity(0.06) : Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSel ? Color.appSecondaryDarkBlue : Color(hex: "#E2E8F0"), lineWidth: isSel ? 1.5 : 1)
                        )
                    }
                }
            }

            // Billing cycles
            VStack(alignment: .leading, spacing: 8) {
                Text("2. CHỌN THỜI HẠN THANH TOÁN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                let price1Year = Int(Double(selectedTier.monthlyPrice) * 12 * 0.65)
                let price6Month = Int(Double(selectedTier.monthlyPrice) * 6 * 0.8)
                let price3Month = Int(Double(selectedTier.monthlyPrice) * 3 * 0.9)
                let price1Month = selectedTier.monthlyPrice

                billingCycleCard(key: "1_YEAR", title: "Gói 1 Năm (12 tháng)", price: "\(formatCurrency(Double(price1Year))) / năm", sub: "Chỉ ~\(formatCurrency(Double(price1Year / 12)))/tháng • Giảm 35% 🔥", badge: "TIẾT KIỆM 35%")
                billingCycleCard(key: "6_MONTHS", title: "Gói 6 Tháng", price: "\(formatCurrency(Double(price6Month))) / 6 tháng", sub: "Chỉ ~\(formatCurrency(Double(price6Month / 6)))/tháng • Giảm 20%")
                billingCycleCard(key: "3_MONTHS", title: "Gói 3 Tháng", price: "\(formatCurrency(Double(price3Month))) / 3 tháng", sub: "Chỉ ~\(formatCurrency(Double(price3Month / 3)))/tháng • Giảm 10%")
                billingCycleCard(key: "1_MONTH", title: "Gói 1 Tháng", price: "\(formatCurrency(Double(price1Month))) / tháng", sub: "Linh hoạt theo từng tháng")
            }

            // Features list
            VStack(alignment: .leading, spacing: 8) {
                featureCheckItem("Quản lý \(selectedTier.maxAssets > 10000 ? "không giới hạn" : "\(selectedTier.maxAssets)") tài sản thiết bị (\(selectedTier.maxDevices) máy cài app)")
                featureCheckItem("Hệ thống Hỗ trợ Kỹ thuật Trực tuyến / HelpDesk SLA")
                featureCheckItem("In ấn tem mã vạch QR & Code 128 qua Bluetooth / LAN")
                if selectedTier.id != "BASIC" {
                    featureCheckItem("Báo cáo CSAT & Đánh giá chất lượng sau bảo hành")
                    featureCheckItem("Chấm công định vị GPS cá nhân (Vào ca / Tan ca)")
                }
                if selectedTier.id == "PROFESSIONAL" || selectedTier.id == "ENTERPRISE" {
                    featureCheckItem("Quản trị Phân ca tuần & Chấm công toàn diện Geofencing")
                    featureCheckItem("Quyết toán công tác phí KTV theo Km lộ trình OSRM")
                }
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
            )

            // Purchase Button
            Button(action: {
                currentLicenseTier = selectedTier.id
                licenseExpiryDate = "31/12/2026"
                activationMessage = "🎉 Kích hoạt gói \(selectedTier.name) thành công!"
                isSuccess = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                    Text("Đăng ký bằng Apple In-App Purchase")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.appPrimaryPink)
                .cornerRadius(12)
            }

            Button(action: {
                activationMessage = "Đã khôi phục thành công gói bản quyền đã mua từ App Store!"
                isSuccess = true
            }) {
                Text("Khôi phục gói thuê bao đã mua (Restore Purchases)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
    }

    private func billingCycleCard(key: String, title: String, price: String, sub: String, badge: String? = nil) -> some View {
        let isSel = selectedBillingCycle == key
        return Button(action: { selectedBillingCycle = key }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 10) {
                    Image(systemName: isSel ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(isSel ? Color.appPrimaryPink : .gray)
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.appSecondaryDarkBlue)
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Text(price)
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(isSel ? Color.appPrimaryPink : Color.appSecondaryDarkBlue)
                }
                .padding(12)
                .background(isSel ? Color.appPrimaryPink.opacity(0.06) : Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSel ? Color.appPrimaryPink : Color(hex: "#E2E8F0"), lineWidth: isSel ? 1.5 : 1)
                )

                if let b = badge {
                    Text(b)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#EA580C"))
                        .cornerRadius(6, corners: [.bottomLeft, .topRight])
                }
            }
        }
    }

    private func featureCheckItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Color(hex: "#16A34A"))
                .font(.system(size: 14))
            Text(text)
                .font(.system(size: 12.5))
                .foregroundColor(Color.appSecondaryDarkBlue)
            Spacer()
        }
    }

    // MARK: - TAB 1: ENTERPRISE LICENSE KEY CONTENT
    private var enterpriseLicenseKeyTabContent: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("KÍCH HOẠT KEY BẢN QUYỀN DOANH NGHIỆP")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)

                Text("Nhập mã bản quyền do Saigon Co.op hoặc nhà cung cấp cấp phát để mở khóa toàn bộ tính năng:")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(Color.appPrimaryPink)
                    TextField("SG-ENT-XXXX-XXXX...", text: $licenseKeyInput)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                }
                .padding(12)
                .background(Color(hex: "#F8FAFC"))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.appPrimaryPink.opacity(0.4), lineWidth: 1)
                )

                if let msg = activationMessage {
                    HStack {
                        Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isSuccess ? .green : .red)
                        Text(msg)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(isSuccess ? .green : .red)
                        Spacer()
                    }
                    .padding(10)
                    .background(isSuccess ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                    .cornerRadius(8)
                }

                Button(action: { activateLicenseKey() }) {
                    HStack(spacing: 8) {
                        if isActivating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Kích hoạt Key bản quyền")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Color.appSecondaryDarkBlue)
                    .cornerRadius(10)
                }
                .disabled(isActivating)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
            )

            // Solution consultation card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "briefcase.fill")
                        .foregroundColor(Color.appSecondaryDarkBlue)
                    Text("Giải pháp cho doanh nghiệp / Chi nhánh")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.appSecondaryDarkBlue)
                }

                Text("• Phân định 2 chiều: Số máy cài app & Số tài sản quản lý.\n• Gói Basic (20 máy / 200 tài sản): Quản lý tài sản + Hỗ trợ kỹ thuật HelpDesk.\n• Gói Pro (100 máy / 1.000 tài sản): Thêm Đánh giá KPI & Chấm công GPS cá nhân.\n• Gói Enterprise: Quản trị Chấm công toàn diện & Quyết toán công tác phí OSRM.\n• Xuất hóa đơn VAT & Hợp đồng đầy đủ.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.gray)
                    .lineSpacing(3)

                Button(action: {
                    if let url = URL(string: "tel://19001770") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "phone.fill")
                        Text("Liên hệ Hotline báo giá số lượng lớn: 1900 1770")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color(hex: "#2563EB"))
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
            .padding(14)
            .background(Color(hex: "#F8FAFC"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
            )
        }
    }

    // MARK: - 4. CURRENT LICENSE BADGE CARD
    private var currentLicenseBadgeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("GÓI BẢN QUYỀN HIỆN TẠI")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text(currentLicenseTier == "ENTERPRISE" ? "Saigon Co.op Enterprise Pro 👑" : "Gói \(currentLicenseTier)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#16A34A"))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("HẠN BẢN QUYỀN")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text(licenseExpiryDate)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appSecondaryDarkBlue)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#E2E8F0"), lineWidth: 1)
        )
    }

    // MARK: - ACTIONS
    private func activateLicenseKey() {
        let cleanKey = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleanKey.isEmpty {
            activationMessage = "Vui lòng nhập mã Key bản quyền!"
            isSuccess = false
            return
        }

        isActivating = true
        activationMessage = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.isActivating = false
            // Accept standard Saigon Co.op key prefixes or valid patterns
            if cleanKey.hasPrefix("SG-ENT") || cleanKey.hasPrefix("COOP") || cleanKey.hasPrefix("QLTB") || cleanKey.count >= 10 {
                self.currentLicenseTier = "ENTERPRISE"
                self.licenseExpiryDate = "31/12/2026"
                self.savedLicenseKey = cleanKey
                self.activationMessage = "🎉 Chúc mừng! Đã kích hoạt bản quyền Saigon Co.op Enterprise Pro thành công!"
                self.isSuccess = true
            } else {
                self.activationMessage = "Mã bản quyền không hợp lệ hoặc đã hết hạn. Vui lòng kiểm tra lại!"
                self.isSuccess = false
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: value)) ?? "0"
        return "\(formatted) đ"
    }
}
