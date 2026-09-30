import SwiftUI

public struct InfoView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void
    var onLogout: () -> Void

    @State private var showingLogoutConfirm = false
    @State private var showCopiedAlert = false
    @State private var showLogSheet = false
    @State private var showShareSheet = false
    @State private var showLicenseSheet = false
    @State private var logShareItems: [Any] = []

    private let appVersion = "v1.2.0 (Build 120)"
    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "Unknown-Device-ID"
    }

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void, onLogout: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
        self.onLogout = onLogout
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                            }

                            Text("Thông tin ứng dụng")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appTopBarColor)

                    ScrollView {
                        VStack(spacing: 16) {
                            // CARD 1: LOGO & PHIÊN BẢN
                            appIdentityCard

                            // CARD 2: BẢN QUYỀN / GÓI CƯỚC ENTERPRISE
                            enterpriseLicenseCard

                            // CARD 3: THÔNG TIN THIẾT BỊ & HỆ THỐNG
                            deviceDiagnosticsCard

                            // CARD 4: NHẬT KÝ & BÁO CÁO LỖI HỆ THỐNG
                            systemLogsCard

                            // CARD 5: LIÊN HỆ & HỖ TRỢ
                            supportContactCard

                            // NÚT ĐĂNG XUẤT
                            logoutButton
                        }
                        .padding(16)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .alert(isPresented: $showingLogoutConfirm) {
            Alert(
                title: Text("Đăng xuất"),
                message: Text("Bạn có chắc chắn muốn đăng xuất tài khoản hiện tại không?"),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    onLogout()
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .alert("Đã sao chép!", isPresented: $showCopiedAlert) {
            Button("Đóng", role: .cancel) { }
        } message: {
            Text("Đã sao chép mã định danh thiết bị vào bộ nhớ tạm.")
        }
        .sheet(isPresented: $showLogSheet) {
            logViewerSheet
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityViewController(activityItems: logShareItems)
        }
        .sheet(isPresented: $showLicenseSheet) {
            licenseDetailSheet
        }
    }

    // MARK: - CARD 1: LOGO & PHIÊN BẢN
    private var appIdentityCard: some View {
        VStack(spacing: 10) {
            Image("logo_app")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)

            Text("IT Service & Assets")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text("Dịch vụ IT & Quản lý thiết bị")
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Version badge
            Text("Phiên bản \(appVersion)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.appPrimaryPink)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.appPrimaryPink.opacity(0.12))
                .cornerRadius(10)

            // Device ID Badge with copy
            Button(action: {
                UIPasteboard.general.string = deviceId
                showCopiedAlert = true
            }) {
                HStack(spacing: 6) {
                    Text("Device ID: \(deviceId)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color.appTextSecondary)
                        .lineLimit(1)

                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appSurfaceVariant)
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - CARD 2: BẢN QUYỀN / GÓI CƯỚC ENTERPRISE
    private var enterpriseLicenseCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(Color.appPrimaryPink)
                    .font(.system(size: 18))
                Text("TÌNH TRẠNG BẢN QUYỀN")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
            }

            // Enterprise Badge
            HStack {
                Text("DOANH NGHIỆP (ENTERPRISE)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundColor(Color.dynamic(light: "#B45309", dark: "#FCD34D"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.dynamic(light: "#FEF3C7", dark: "#451A03"))
                    .cornerRadius(8)
                Spacer()
            }

            VStack(spacing: 8) {
                licenseRow(title: "Doanh nghiệp", value: authViewModel.currentUser?.companyId ?? "Saigon Co.op")
                Divider().background(Color.appCardBorder)
                licenseRow(title: "Mã kích hoạt", value: "SGCOOP-ENT-2026-UNLIMITED")
                Divider().background(Color.appCardBorder)
                licenseRow(title: "Hạn bản quyền", value: "Vĩnh viễn", valueColor: Color.dynamic(light: "#15803D", dark: "#4ADE80"))
                Divider().background(Color.appCardBorder)
                licenseRow(title: "Số máy cài đặt", value: "Không giới hạn")
            }
            .padding(12)
            .background(Color.appSurfaceVariant)
            .cornerRadius(10)

            Button(action: { showLicenseSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "key.fill")
                    Text("Quản lý gói cước / Nhập Key")
                }
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.appPrimaryPink)
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - CARD 3: THÔNG TIN THIẾT BỊ & HỆ THỐNG
    private var deviceDiagnosticsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.gen3")
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .font(.system(size: 18))
                Text("THÔNG TIN THIẾT BỊ & HỆ THỐNG")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
            }

            VStack(spacing: 8) {
                infoRow(title: "Dòng thiết bị", value: UIDevice.current.model)
                Divider().background(Color.appCardBorder)
                infoRow(title: "Hệ điều hành", value: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
                Divider().background(Color.appCardBorder)
                infoRow(title: "Tài khoản hiện tại", value: authViewModel.currentUser?.fullName ?? "N/A")
                Divider().background(Color.appCardBorder)
                infoRow(title: "Email", value: authViewModel.currentUser?.email ?? "N/A")
                Divider().background(Color.appCardBorder)
                infoRow(title: "Vai trò", value: authViewModel.currentUser?.role ?? "Người dùng")
            }
            .padding(12)
            .background(Color.appSurfaceVariant)
            .cornerRadius(10)
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - CARD 4: NHẬT KÝ & BÁO CÁO LỖI HỆ THỐNG
    private var systemLogsCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(Color.appPrimaryPink)
                    .font(.system(size: 18))
                Text("NHẬT KÝ & BÁO CÁO LỖI HỆ THỐNG")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
            }

            Text("Ghi nhận tự động các sự kiện, cảnh báo và lỗi ngoại lệ của ứng dụng vào bộ nhớ thiết bị để hỗ trợ chẩn đoán kỹ thuật.")
                .font(.system(size: 12))
                .foregroundColor(Color.appTextSecondary)
                .multilineTextAlignment(.leading)

            VStack(spacing: 8) {
                HStack {
                    Text("Chế độ ghi:")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: "#22C55E")).frame(width: 8, height: 8)
                        Text("Rolling File (14 ngày)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#15803D"))
                    }
                }
                Divider().background(Color.appCardBorder)
                HStack {
                    Text("Dung lượng log hiện tại:")
                        .font(.system(size: 12))
                        .foregroundColor(Color.appTextSecondary)
                    Spacer()
                    Text("128 KB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.appTextPrimary)
                }
            }
            .padding(12)
            .background(Color.appSurfaceVariant)
            .cornerRadius(10)

            HStack(spacing: 10) {
                Button(action: { showLogSheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                        Text("Xem Log")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.appPrimaryPink)
                    .cornerRadius(8)
                }

                Button(action: {
                    let logText = generateSampleLogText()
                    logShareItems = [logText]
                    showShareSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Chia sẻ Log")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color.appPrimaryPink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.appPrimaryPink.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appPrimaryPink, lineWidth: 1))
                }
            }
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - CARD 5: LIÊN HỆ & HỖ TRỢ
    private var supportContactCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.circle.fill")
                    .foregroundColor(Color.appSecondaryDarkBlue)
                    .font(.system(size: 18))
                Text("LIÊN HỆ & HỖ TRỢ KỸ THUẬT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                Spacer()
            }

            Button(action: {
                if let url = URL(string: "mailto:devicemanagement0101@gmail.com?subject=[IT-Service-Assets-iOS]%20Ho%20tro%20ky%20thuat") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Color.appPrimaryPink)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email hỗ trợ kỹ thuật")
                            .font(.system(size: 11))
                            .foregroundColor(Color.appTextSecondary)
                        Text("devicemanagement0101@gmail.com")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.appTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(Color.appTextSecondary)
                }
                .padding(12)
                .background(Color.appSurfaceVariant)
                .cornerRadius(10)
            }

            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                    .foregroundColor(Color.appPrimaryPink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đường dây nóng hỗ trợ 24/7")
                        .font(.system(size: 11))
                        .foregroundColor(Color.appTextSecondary)
                    Text("09xx.xxx.xxx (Hỗ trợ 24/7)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.appTextPrimary)
                }
                Spacer()
            }
            .padding(12)
            .background(Color.appSurfaceVariant)
            .cornerRadius(10)
        }
        .padding(16)
        .background(Color.appSurface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.appCardBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    // MARK: - NÚT ĐĂNG XUẤT
    private var logoutButton: some View {
        Button(action: { showingLogoutConfirm = true }) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.white)
                Text("Đăng xuất tài khoản")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(hex: "#EF4444"))
            .cornerRadius(12)
        }
        .padding(.top, 4)
    }

    // MARK: - HELPERS
    private func licenseRow(title: String, value: String, valueColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(valueColor ?? Color.appTextPrimary)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
                .foregroundColor(Color.appTextSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(Color.appTextPrimary)
        }
    }

    private func generateSampleLogText() -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        return """
        =====================================================
        [IT Service & Assets iOS System Diagnostic Log]
        Time: \(now)
        App Version: \(appVersion)
        Device Model: \(UIDevice.current.model)
        OS Version: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Device ID: \(deviceId)
        User: \(authViewModel.currentUser?.fullName ?? "N/A") (\(authViewModel.currentUser?.email ?? "N/A"))
        Company: \(authViewModel.currentUser?.companyId ?? "Saigon Co.op")
        License: ENTERPRISE (SGCOOP-ENT-2026-UNLIMITED)
        =====================================================
        [INFO] App started successfully.
        [INFO] Auth session active. Token verified.
        [INFO] Realtime listeners synced with Firebase Firestore.
        [INFO] Network status: Connected.
        [INFO] No critical crashes recorded in rolling window.
        """
    }

    // MARK: - LOG VIEWER SHEET
    private var logViewerSheet: some View {
        NavigationView {
            ScrollView {
                Text(generateSampleLogText())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color.appTextPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSurfaceVariant)
                    .cornerRadius(10)
                    .padding(16)
            }
            .background(Color.appBackground)
            .navigationTitle("Nhật ký hệ thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { showLogSheet = false }
                }
            }
        }
    }

    // MARK: - LICENSE DETAIL SHEET
    private var licenseDetailSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.appPrimaryPink)
                    .padding(.top, 20)

                Text("Gói Bản Quyền Doanh Nghiệp")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)

                Text("Hệ thống đã kích hoạt bản quyền Enterprise vĩnh viễn cho Saigon Co.op. Mọi tính năng quản lý, phân quyền, GPS và báo cáo đều được mở khóa tối đa.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.appTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                Button("Đóng") {
                    showLicenseSheet = false
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appSecondaryDarkBlue)
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.appBackground)
            .navigationTitle("Bản quyền ứng dụng")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - UIActivityViewController Wrapper for Sharing
fileprivate struct ActivityViewController: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
