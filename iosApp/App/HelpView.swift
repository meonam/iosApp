import SwiftUI
import SafariServices
import WebKit

// MARK: - MÀN HÌNH TRỢ GIÚP (HELP VIEW)
public struct HelpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedArticle: HelpArticle? = nil
    @State private var expandedCategories: [String: Bool] = [:]
    @State private var showFeedbackForm: Bool = false
    @State private var feedbackTitle: String = ""
    @State private var feedbackContent: String = ""
    @State private var isSendingFeedback: Bool = false
    @State private var feedbackMessage: String? = nil
    @State private var feedbackError: Bool = false
    @State private var showSafari: Bool = false
    @State private var safariURL: URL? = nil

    private let categories = HelpRepository.getHelpCategories()

    public init(authViewModel: AuthViewModel, onBack: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // TOP BAR TRÀN TAI THỎ VỚI SAFE AREA
                    VStack(spacing: 0) {
                        Color.clear.frame(height: SafeAreaHelper.top(geometry))

                        HStack(spacing: 12) {
                            Button(action: {
                                if selectedArticle != nil {
                                    selectedArticle = nil
                                } else {
                                    onBack()
                                }
                            }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                            }

                            Text(selectedArticle?.title ?? "Cẩm nang trợ giúp")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    }
                    .background(Color.appSecondaryDarkBlue)

                    // CONTENT
                    if let article = selectedArticle {
                        HelpArticleWebView(htmlContent: article.htmlContent, isDark: colorScheme == .dark)
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                // Header Card
                                HStack(spacing: 12) {
                                    Image(systemName: "book.pages")
                                        .font(.system(size: 30))
                                        .foregroundColor(Color.appSecondaryDarkBlue)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TÀI LIỆU HƯỚNG DẪN")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.appTextPrimary)
                                        Text("Chọn chuyên mục bên dưới để xem hướng dẫn chi tiết")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color.appTextSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)

                                // Categories List
                                ForEach(categories) { category in
                                    let isExpanded = expandedCategories[category.title] ?? category.defaultExpanded

                                    VStack(spacing: 0) {
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedCategories[category.title] = !isExpanded
                                            }
                                        }) {
                                            HStack(spacing: 12) {
                                                Image(systemName: category.iconName)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(Color.appSecondaryDarkBlue)
                                                    .frame(width: 24, height: 24)

                                                Text(category.title)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color.appTextPrimary)
                                                    .multilineTextAlignment(.leading)

                                                Spacer()

                                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundColor(Color.appTextSecondary)
                                            }
                                            .padding(16)
                                        }

                                        if isExpanded {
                                            Divider()
                                                .background(Color.appCardBorder)
                                                .padding(.horizontal, 16)

                                            VStack(spacing: 8) {
                                                ForEach(category.articles) { article in
                                                    Button(action: { selectedArticle = article }) {
                                                        HStack(spacing: 8) {
                                                            Text(article.title)
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(Color.dynamic(light: "#0369A1", dark: "#38BDF8"))
                                                                .multilineTextAlignment(.leading)
                                                            Spacer()
                                                            Image(systemName: "chevron.right")
                                                                .font(.system(size: 12, weight: .semibold))
                                                                .foregroundColor(Color.dynamic(light: "#0369A1", dark: "#38BDF8"))
                                                        }
                                                        .padding(.vertical, 10)
                                                        .padding(.horizontal, 12)
                                                        .background(Color.appSurfaceVariant)
                                                        .cornerRadius(8)
                                                    }
                                                }
                                            }
                                            .padding(16)
                                        }
                                    }
                                    .background(Color.appSurface)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                    .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
                                }

                                // Gửi phản hồi / Hỗ trợ
                                VStack(spacing: 10) {
                                    Button(action: {
                                        showFeedbackForm = true
                                    }) {
                                        HStack {
                                            Image(systemName: "envelope.fill")
                                                .foregroundColor(Color.appPrimaryPink)
                                            Text("Gửi phản hồi / Báo lỗi kỹ thuật")
                                                .font(.system(size: 13.5, weight: .bold))
                                                .foregroundColor(Color.appTextPrimary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.appTextSecondary)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.appSurface)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                    }

                                    Text("Phiên bản ứng dụng v1.2.0 (Build 120)")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color.appTextSecondary)
                                        .padding(.top, 4)
                                }
                                .padding(.top, 6)
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(isPresented: $showFeedbackForm) {
            feedbackSheet
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Feedback Form
    private var feedbackSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Nội dung phản hồi")) {
                    TextField("Tiêu đề", text: $feedbackTitle)
                    TextEditor(text: $feedbackContent)
                        .frame(height: 150)
                }

                if let msg = feedbackMessage {
                    Text(msg)
                        .foregroundColor(feedbackError ? .red : .green)
                        .font(.system(size: 13))
                }
            }
            .navigationTitle("Gửi Phản Hồi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        showFeedbackForm = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSendingFeedback ? "Đang gửi..." : "Gửi") {
                        sendFeedback()
                    }
                    .disabled(feedbackTitle.isEmpty || feedbackContent.isEmpty || isSendingFeedback)
                }
            }
        }
    }

    // MARK: - API Gửi Feedback
    private func sendFeedback() {
        guard !feedbackTitle.isEmpty, !feedbackContent.isEmpty else { return }

        isSendingFeedback = true
        let companyId = authViewModel.currentCompanyId
        let urlString = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/feedback"

        guard let url = URL(string: urlString) else {
            self.feedbackMessage = "Lỗi URL"
            self.feedbackError = true
            self.isSendingFeedback = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !authViewModel.currentIdToken.isEmpty {
            request.setValue("Bearer \(authViewModel.currentIdToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: Any] = [
            "fields": [
                "title": ["stringValue": feedbackTitle],
                "content": ["stringValue": feedbackContent],
                "timestamp": ["timestampValue": ISO8601DateFormatter().string(from: Date())],
                "userEmail": ["stringValue": authViewModel.currentUser?.email ?? "unknown"]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSendingFeedback = false
                if let error = error {
                    self.feedbackError = true
                    self.feedbackMessage = "Lỗi: \(error.localizedDescription)"
                    return
                }
                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    self.feedbackError = false
                    self.feedbackMessage = "Gửi phản hồi thành công!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.showFeedbackForm = false
                        self.feedbackTitle = ""
                        self.feedbackContent = ""
                        self.feedbackMessage = nil
                    }
                } else {
                    self.feedbackError = true
                    self.feedbackMessage = "Gửi thất bại. Vui lòng thử lại sau."
                }
            }
        }.resume()
    }
}

// MARK: - Safari View
fileprivate struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: UIViewControllerRepresentableContext<SafariView>) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: UIViewControllerRepresentableContext<SafariView>) {
    }
}

// MARK: - Enhanced WebView with Dark Mode Support
fileprivate struct HelpArticleWebView: UIViewRepresentable {
    let htmlContent: String
    let isDark: Bool

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let bgColorHex = isDark ? "#0F172A" : "#FFFFFF"
        let textColorHex = isDark ? "#F8FAFC" : "#0F172A"
        let subTextHex = isDark ? "#94A3B8" : "#475569"
        let h3ColorHex = isDark ? "#60A5FA" : "#002A8F"
        let h4ColorHex = isDark ? "#93C5FD" : "#0369A1"
        let cardBorderHex = isDark ? "#334155" : "#E2E8F0"
        let cardBgHex = isDark ? "#1E293B" : "#F8FAFC"

        let htmlHeader = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    min-height: 100%;
                    background-color: \(bgColorHex);
                    -webkit-text-size-adjust: 100%;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    padding: 16px 16px 80px 16px;
                    color: \(textColorHex);
                    font-size: 14px;
                    line-height: 1.6;
                    box-sizing: border-box;
                    word-break: normal;
                    overflow-wrap: break-word;
                }
                h3 {
                    color: \(h3ColorHex);
                    font-size: 16px;
                    border-bottom: 2px solid \(h3ColorHex);
                    padding-bottom: 6px;
                    margin-top: 0;
                    margin-bottom: 12px;
                }
                h4 {
                    color: \(h4ColorHex);
                    font-size: 14.5px;
                    margin-top: 14px;
                    margin-bottom: 6px;
                }
                p, li {
                    font-size: 13.5px;
                    color: \(subTextHex);
                }
                ol, ul {
                    padding-left: 20px;
                    margin-bottom: 10px;
                }
                li {
                    margin-bottom: 6px;
                }
                b, strong {
                    color: \(textColorHex);
                }
                i, em {
                    color: \(subTextHex);
                }
                .badge {
                    display: inline-block;
                    padding: 2px 7px;
                    font-size: 11px;
                    font-weight: bold;
                    border-radius: 4px;
                }
                .badge-primary { background-color: #e0f2fe; color: #0369a1; border: 1px solid #bae6fd; }
                .badge-success { background-color: #dcfce7; color: #15803d; border: 1px solid #bbf7d0; }
                .badge-danger { background-color: #fee2e2; color: #b91c1c; border: 1px solid #fecaca; }
                .badge-warning { background-color: #fef3c7; color: #b45309; border: 1px solid #fde68a; }
                .badge-purple { background-color: #f3e8ff; color: #7e22ce; border: 1px solid #e9d5ff; }
                .badge-dark { background-color: #0f172a; color: #ffffff; }
                .badge-blue { background-color: #002a8f; color: #ffffff; }
                .callout {
                    background-color: \(isDark ? "#1E3A5F" : "#F0F9FF");
                    border-left: 4px solid #0284c7;
                    padding: 10px 14px;
                    margin: 12px 0;
                    border-radius: 0 6px 6px 0;
                }
                .callout-warning {
                    background-color: \(isDark ? "#3B2D14" : "#FFFBEB");
                    border-left: 4px solid #f59e0b;
                    padding: 10px 14px;
                    margin: 12px 0;
                    border-radius: 0 6px 6px 0;
                }
                code {
                    background-color: \(isDark ? "#334155" : "#F1F5F9");
                    color: #e11d48;
                    padding: 2px 5px;
                    font-family: Menlo, Monaco, monospace;
                    font-size: 12px;
                    font-weight: bold;
                    border-radius: 4px;
                }
                div[style*="background: #ffffff"], div[style*="background:#ffffff"] {
                    background-color: \(cardBgHex) !important;
                    border-color: \(cardBorderHex) !important;
                }
                div[style*="background: #f8faff"], div[style*="background:#f8faff"] {
                    background-color: \(isDark ? "#1E293B" : "#F8FAFF") !important;
                }
                div[style*="background: #f0fdfa"], div[style*="background:#f0fdfa"] {
                    background-color: \(isDark ? "#042F2E" : "#F0FDFA") !important;
                }
                div[style*="background: #fffbeb"], div[style*="background:#fffbeb"] {
                    background-color: \(isDark ? "#451A03" : "#FFFBEB") !important;
                }
                div[style*="background: #fff1f2"], div[style*="background:#fff1f2"] {
                    background-color: \(isDark ? "#4C0519" : "#FFF1F2") !important;
                }
            </style>
        </head>
        <body>
        """
        let htmlFooter = "</body></html>"
        uiView.loadHTMLString(htmlHeader + htmlContent + htmlFooter, baseURL: nil)
    }
}


// MARK: - HELP REPOSITORY & MODELS
public struct HelpArticle: Identifiable {
    public let id: String
    public let title: String
    public let htmlContent: String

    public init(id: String, title: String, htmlContent: String) {
        self.id = id
        self.title = title
        self.htmlContent = htmlContent
    }
}

public struct HelpCategory: Identifiable {
    public var id: String { title }
    public let title: String
    public let iconName: String
    public let defaultExpanded: Bool
    public let articles: [HelpArticle]

    public init(title: String, iconName: String, defaultExpanded: Bool = false, articles: [HelpArticle]) {
        self.title = title
        self.iconName = iconName
        self.defaultExpanded = defaultExpanded
        self.articles = articles
    }
}

public class HelpRepository {
    public static func getHelpCategories() -> [HelpCategory] {
        return categoriesCache
    }

    private static let categoriesCache: [HelpCategory] = [
        HelpCategory(
            title: "0. Sơ Đồ Quy Trình Swimlane & Phân Quyền 4 Bộ Phận",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: true,
            articles: [
                HelpArticle(
                    id: "swimlane_overview",
                    title: "0.1. Sơ Đồ Phân Luồng Swimlane & Ma Trận 4 Làn Nghiệp Vụ",
                    htmlContent: #"""

                            <div style="border-left: 5px solid #002a8f; padding-left: 12px; margin-bottom: 14px;">
                                <h3 style="margin: 0; color: #002a8f; border: none; font-size: 16px; font-weight: bold;">I. SƠ ĐỒ PHÂN LUỒNG 4 LÀN NGHIỆP VỤ (SWIMLANE WORKFLOW)</h3>
                                <p style="margin: 4px 0 0 0; color: #64748b; font-size: 12px;">Quy trình vận hành đồng bộ thời gian thực (Realtime 100%) giữa App Mobile và Desktop</p>
                            </div>

                            <!-- LANE 1: ADMIN -->
                            <div style="border: 2px solid #002a8f; border-radius: 12px; margin-bottom: 14px; overflow: hidden; background: #ffffff;">
                                <div style="background: #002a8f; color: #ffffff; padding: 10px 14px;">
                                    <div style="font-weight: bold; font-size: 14px;">👑 LÀN 1: BAN GIÁM ĐỐC / SUPER ADMIN</div>
                                    <div style="font-size: 11px; color: #c7d2fe; margin-top: 2px;">Toàn Doanh Nghiệp</div>
                                </div>
                                <div style="padding: 12px 14px; background: #f8faff;">
                                    <!-- Step 1.1 -->
                                    <div style="background: #ffffff; border: 1.5px solid #bfdbfe; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #002a8f; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 1</span>
                                            <b style="display: block; color: #002a8f; font-size: 13px;">⚙️ Cấu hình Doanh nghiệp &amp; Kích hoạt License</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Nạp thông tin công ty, tải Logo xuất hiện trên các biểu mẫu A4, kích hoạt bản quyền License Key và thiết lập tiêu đề chuẩn Nghị định 30.</p>
                                    </div>
                                    <!-- Arrow -->
                                    <div style="text-align: center; color: #002a8f; font-size: 18px; margin: 4px 0;">⬇️</div>
                                    <!-- Step 1.2 -->
                                    <div style="background: #ffffff; border: 1.5px solid #bfdbfe; border-radius: 8px; padding: 10px 12px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #002a8f; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 2</span>
                                            <b style="display: block; color: #002a8f; font-size: 13px;">📊 Giám sát KPI KTV &amp; Báo cáo Đánh giá</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Theo dõi bảng xếp hạng thi đua KTV, tỉ lệ hài lòng CSKH (1-5 ⭐), bật/tắt chế độ bảo trì hệ thống toàn công ty.</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Inter-lane connector -->
                            <div style="text-align: center; margin: -6px 0 8px 0;">
                                <span style="display: inline-block; background: #f1f5f9; border: 1px solid #cbd5e1; color: #475569; font-size: 11px; font-weight: bold; padding: 3px 12px; border-radius: 20px;">
                                    ▼ Phân quyền quản lý xuống các bộ phận
                                </span>
                            </div>

                            <!-- LANE 2: MANAGER -->
                            <div style="border: 2px solid #0d9488; border-radius: 12px; margin-bottom: 14px; overflow: hidden; background: #ffffff;">
                                <div style="background: #0d9488; color: #ffffff; padding: 10px 14px;">
                                    <div style="font-weight: bold; font-size: 14px;">🏢 LÀN 2: TRƯỞNG PHÒNG (MANAGER)</div>
                                    <div style="font-size: 11px; color: #ccfbf1; margin-top: 2px;">Phòng Ban &amp; Đơn Vị</div>
                                </div>
                                <div style="padding: 12px 14px; background: #f0fdfa;">
                                    <!-- Step 2.1 -->
                                    <div style="background: #ffffff; border: 1.5px solid #99f6e4; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #0d9488; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 1</span>
                                            <b style="display: block; color: #0d9488; font-size: 13px;">👥 Phê duyệt Nhân viên &amp; Thiết lập Đơn vị</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Phê duyệt tài khoản nhân viên mới đăng ký xin vào phòng ban; tạo lập các tổ đội, trạm làm việc trực thuộc.</p>
                                    </div>
                                    <!-- Arrow -->
                                    <div style="text-align: center; color: #0d9488; font-size: 18px; margin: 4px 0;">⬇️</div>
                                    <!-- Step 2.2 -->
                                    <div style="background: #ffffff; border: 1.5px solid #99f6e4; border-radius: 8px; padding: 10px 12px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #0d9488; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 2</span>
                                            <b style="display: block; color: #0d9488; font-size: 13px;">💻 Quản lý Thiết bị Phòng ban &amp; In Tem QR</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Thêm thiết bị mới (tự động sinh mã chuẩn MT_, LT_, PR_), gán người sử dụng và in tem dán mã QR/Barcode hàng loạt.</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Inter-lane connector -->
                            <div style="text-align: center; margin: -6px 0 8px 0;">
                                <span style="display: inline-block; background: #f1f5f9; border: 1px solid #cbd5e1; color: #475569; font-size: 11px; font-weight: bold; padding: 3px 12px; border-radius: 20px;">
                                    ▼ Điều phối xử lý sự cố thiết bị
                                </span>
                            </div>

                            <!-- LANE 3: TECH / HELPDESK -->
                            <div style="border: 2px solid #d97706; border-radius: 12px; margin-bottom: 14px; overflow: hidden; background: #ffffff;">
                                <div style="background: #d97706; color: #ffffff; padding: 10px 14px;">
                                    <div style="font-weight: bold; font-size: 14px;">🛠️ LÀN 3: KỸ THUẬT VIÊN / HELPDESK</div>
                                    <div style="font-size: 11px; color: #fef3c7; margin-top: 2px;">Hiện Trường &amp; Điều Phối</div>
                                </div>
                                <div style="padding: 12px 14px; background: #fffbeb;">
                                    <!-- Step 3.1 -->
                                    <div style="background: #ffffff; border: 1.5px solid #fde68a; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #d97706; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 1</span>
                                            <b style="display: block; color: #d97706; font-size: 13px;">🚨 Nhận Thông Báo Giọng Nói &amp; Live GPS</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Nhận chuông báo + đọc to nội dung sự cố 2 lần bằng tiếng Việt; bấm 'Bắt đầu di chuyển' để hệ thống bật GPS và hiển thị lộ trình dẫn đường OSRM.</p>
                                    </div>
                                    <!-- Arrow -->
                                    <div style="text-align: center; color: #d97706; font-size: 18px; margin: 4px 0;">⬇️</div>
                                    <!-- Step 3.2 -->
                                    <div style="background: #ffffff; border: 1.5px solid #bbf7d0; border-radius: 8px; padding: 10px 12px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #16a34a; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 2</span>
                                            <b style="display: block; color: #16a34a; font-size: 13px;">✅ Sửa Chữa Hiện Trường &amp; Ghi Nhận Công Tác Phí</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Đến nơi kiểm tra khắc phục lỗi, hoàn thành phiếu; hệ thống tự động tổng hợp số km di chuyển thực tế từ GPS vào bảng thanh toán công tác phí.</p>
                                    </div>
                                </div>
                            </div>

                            <!-- Inter-lane connector -->
                            <div style="text-align: center; margin: -6px 0 8px 0;">
                                <span style="display: inline-block; background: #f1f5f9; border: 1px solid #cbd5e1; color: #475569; font-size: 11px; font-weight: bold; padding: 3px 12px; border-radius: 20px;">
                                    ▼ Sử dụng thiết bị &amp; Phản hồi chất lượng
                                </span>
                            </div>

                            <!-- LANE 4: STAFF -->
                            <div style="border: 2px solid #e11d48; border-radius: 12px; margin-bottom: 14px; overflow: hidden; background: #ffffff;">
                                <div style="background: #e11d48; color: #ffffff; padding: 10px 14px;">
                                    <div style="font-weight: bold; font-size: 14px;">👤 LÀN 4: NHÂN VIÊN SỬ DỤNG (STAFF)</div>
                                    <div style="font-size: 11px; color: #fecdd3; margin-top: 2px;">Cá Nhân &amp; Thiết Bị</div>
                                </div>
                                <div style="padding: 12px 14px; background: #fff1f2;">
                                    <!-- Step 4.1 -->
                                    <div style="background: #ffffff; border: 1.5px solid #fecdd3; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #e11d48; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 1</span>
                                            <b style="display: block; color: #e11d48; font-size: 13px;">👤 Gia Nhập &amp; Kiểm Tra Thiết Bị Bàn Giao</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Đăng ký tài khoản, chọn công ty &amp; phòng ban, theo dõi danh sách máy móc, tình trạng thiết bị cá nhân được bàn giao.</p>
                                    </div>
                                    <!-- Arrow -->
                                    <div style="text-align: center; color: #e11d48; font-size: 18px; margin: 4px 0;">⬇️</div>
                                    <!-- Step 4.2 -->
                                    <div style="background: #ffffff; border: 1.5px solid #fecdd3; border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #e11d48; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 2</span>
                                            <b style="display: block; color: #e11d48; font-size: 13px;">📸 Tạo Ticket Báo Hỏng Kèm Ảnh &amp; Chat KTV</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Chụp ảnh sự cố gửi phiếu, chat trực tuyến giải thích hiện tượng với KTV (hỗ trợ Zoom/Pan ảnh), theo dõi vị trí KTV đang di chuyển tới.</p>
                                    </div>
                                    <!-- Arrow -->
                                    <div style="text-align: center; color: #e11d48; font-size: 18px; margin: 4px 0;">⬇️</div>
                                    <!-- Step 4.3 -->
                                    <div style="background: #ffffff; border: 1.5px solid #fef08a; border-radius: 8px; padding: 10px 12px;">
                                        <div style="margin-bottom: 6px;">
                                            <span style="display: inline-block; background: #ca8a04; color: #ffffff; font-size: 10.5px; font-weight: bold; padding: 2px 7px; border-radius: 4px; margin-bottom: 4px;">BƯỚC 3</span>
                                            <b style="display: block; color: #ca8a04; font-size: 13px;">⭐ Tự Đóng Phiếu / Chấm Điểm 1 - 5 Sao</b>
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #334155; line-height: 1.45;">Nếu máy tự hoạt động lại bấm 'Tôi đã tự xử lý xong'; khi KTV hoàn thành sửa chữa, chấm điểm 1 đến 5 ⭐ đánh giá chất lượng phục vụ.</p>
                                    </div>
                                </div>
                            </div>

                            <!-- SECTION II: MA TRẬN PHÂN QUYỀN -->
                            <div style="border-left: 5px solid #002a8f; padding-left: 12px; margin: 26px 0 14px 0;">
                                <h3 style="margin: 0; color: #002a8f; border: none; font-size: 16px; font-weight: bold;">II. MA TRẬN PHÂN QUYỀN &amp; TRÁCH NHIỆM 4 BỘ PHẬN</h3>
                            </div>

                            <!-- ROLE 1 -->
                            <div style="border: 1.5px solid #cbd5e1; border-left: 5px solid #002a8f; border-radius: 8px; padding: 10px 12px; background: #ffffff; margin-bottom: 8px;">
                                <div style="margin-bottom: 4px;">
                                    <b style="color: #002a8f; font-size: 13.5px;">👑 Super Admin / Ban Giám Đốc</b>
                                    <span class="badge badge-primary" style="float: right;">App &amp; PC</span>
                                </div>
                                <div style="clear: both;"></div>
                                <div style="font-size: 11.5px; color: #64748b; margin-bottom: 4px;"><b>Phạm vi:</b> Toàn doanh nghiệp (Enterprise-wide)</div>
                                <div style="font-size: 12px; color: #334155; line-height: 1.4;">Quản trị công ty, nạp Logo, License Key, cấu hình tiêu đề NĐ 30, giám sát KPI KTV, kích hoạt chế độ bảo trì khẩn cấp.</div>
                            </div>

                            <!-- ROLE 2 -->
                            <div style="border: 1.5px solid #cbd5e1; border-left: 5px solid #0d9488; border-radius: 8px; padding: 10px 12px; background: #ffffff; margin-bottom: 8px;">
                                <div style="margin-bottom: 4px;">
                                    <b style="color: #0d9488; font-size: 13.5px;">🏢 Trưởng Phòng (Manager)</b>
                                    <span class="badge badge-success" style="float: right;">App &amp; PC</span>
                                </div>
                                <div style="clear: both;"></div>
                                <div style="font-size: 11.5px; color: #64748b; margin-bottom: 4px;"><b>Phạm vi:</b> Phòng ban &amp; Đơn vị trực thuộc</div>
                                <div style="font-size: 12px; color: #334155; line-height: 1.4;">Quản lý tài sản thiết bị bộ phận, duyệt nhân viên mới gia nhập, quản lý đơn vị/tổ đội, in tem QR/Barcode hàng loạt.</div>
                            </div>

                            <!-- ROLE 3 -->
                            <div style="border: 1.5px solid #cbd5e1; border-left: 5px solid #d97706; border-radius: 8px; padding: 10px 12px; background: #ffffff; margin-bottom: 8px;">
                                <div style="margin-bottom: 4px;">
                                    <b style="color: #d97706; font-size: 13.5px;">🛠️ Kỹ Thuật Viên (Tech / HelpDesk)</b>
                                    <span class="badge badge-warning" style="float: right;">App &amp; PC</span>
                                </div>
                                <div style="clear: both;"></div>
                                <div style="font-size: 11.5px; color: #64748b; margin-bottom: 4px;"><b>Phạm vi:</b> Phiếu sự cố điều phối &amp; Hiện trường</div>
                                <div style="font-size: 12px; color: #334155; line-height: 1.4;">Tiếp nhận ticket (chuông + giọng nói 2 lần), chat 2 chiều, bật Live GPS hiện trường, chấm công GPS &amp; tổng hợp công tác phí.</div>
                            </div>

                            <!-- ROLE 4 -->
                            <div style="border: 1.5px solid #cbd5e1; border-left: 5px solid #e11d48; border-radius: 8px; padding: 10px 12px; background: #ffffff; margin-bottom: 8px;">
                                <div style="margin-bottom: 4px;">
                                    <b style="color: #e11d48; font-size: 13.5px;">👤 Nhân Viên Sử Dụng (Staff)</b>
                                    <span class="badge badge-danger" style="float: right;">App &amp; PC</span>
                                </div>
                                <div style="clear: both;"></div>
                                <div style="font-size: 11.5px; color: #64748b; margin-bottom: 4px;"><b>Phạm vi:</b> Cá nhân &amp; Thiết bị được giao</div>
                                <div style="font-size: 12px; color: #334155; line-height: 1.4;">Xem danh sách máy được cấp phát, tạo ticket báo hỏng kèm ảnh hiện trường, theo dõi vị trí KTV, tự đóng phiếu hoặc chấm 1-5 sao.</div>
                            </div>
                        
"""#
                ),
                HelpArticle(
                    id: "swimlane_admin",
                    title: "0.2. Hướng Dẫn Nghiệp Vụ: Ban Giám Đốc & Super Admin",
                    htmlContent: #"""

                            <h3>Hướng Dẫn Nghiệp Vụ Chi Tiết - Ban Giám Đốc & Super Admin</h3>
                            <p><b>Super Admin</b> là cấp quản trị tối cao, nắm toàn quyền thiết lập hệ thống, phân quyền và giám sát toàn diện hoạt động của doanh nghiệp.</p>

                            <h4>1. Khởi tạo & Nhận diện Thương hiệu Doanh nghiệp</h4>
                            <ul>
                                <li>Vào mục <i>Cài đặt ➔ Thông tin doanh nghiệp</i>: Cập nhật Tên công ty, Hotline, Email và <b>Tải Logo thương hiệu</b>.</li>
                                <li><i>Logo đã tải sẽ tự động xuất hiện trên tất cả phiếu in ấn, biên bản và báo cáo A4.</i></li>
                            </ul>

                            <h4>2. Kích hoạt Bản quyền License Key</h4>
                            <ul>
                                <li>Tại màn hình <i>Bản quyền & Gói cước</i>, dán License Key được cấp vào ô và nhấn <b>Kích hoạt</b>.</li>
                                <li>Mở khóa không giới hạn thiết bị, mở toàn bộ tính năng HelpDesk, Live GPS và Báo cáo đánh giá KPI.</li>
                            </ul>

                            <h4>3. Cấu hình Tiêu đề Báo cáo Chuẩn Nghị định 30</h4>
                            <ul>
                                <li>Tại màn hình In ấn & Báo cáo, nhấn <b>⚙️ Cấu hình Tiêu đề</b>.</li>
                                <li>Khai báo Tên cơ quan chủ quản, Đơn vị ban hành, Quốc hiệu - Tiêu ngữ và thiết lập <b>3 cấp chữ ký số</b> (Lãnh đạo, Trưởng BP, Người lập).</li>
                            </ul>

                            <h4>4. Chế độ Bảo trì Hệ thống Realtime</h4>
                            <ul>
                                <li>Khi cần nâng cấp hoặc khóa tạm thời, bật <b>Chế độ Bảo trì</b> tại mục Cài đặt.</li>
                                <li>Toàn bộ App Mobile và Desktop của các người dùng khác sẽ tự động hiện thông báo bảo trì theo thời gian thực (chỉ Super Admin được truy cập).</li>
                            </ul>

                            <h4>5. Giám sát Báo cáo Hài lòng (KPI) & Thi đua KTV</h4>
                            <ul>
                                <li>Mở màn hình <i>Báo cáo Đánh giá Hỗ trợ</i> để xem số sao trung bình (1-5 ⭐), tỉ lệ hài lòng (%) và biểu đồ xếp hạng thi đua KTV toàn công ty.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "swimlane_manager",
                    title: "0.3. Hướng Dẫn Nghiệp Vụ: Trưởng Phòng / Quản Lý (Manager)",
                    htmlContent: #"""

                            <h3>Hướng Dẫn Nghiệp Vụ Chi Tiết - Trưởng Phòng (Manager)</h3>
                            <p><b>Trưởng phòng</b> chịu trách nhiệm quản lý toàn bộ tài sản thiết bị, nhân sự và đơn vị trực thuộc phòng ban mình phụ trách.</p>

                            <h4>1. Quản lý Danh sách Thiết bị & Chuẩn hóa Mã Loại TB</h4>
                            <ul>
                                <li>Tại mục <i>Danh sách Thiết bị</i>, bấm <b>+ Thêm thiết bị</b> để khai báo tài sản mới.</li>
                                <li>Khi nhập tên loại thiết bị, hệ thống <b>tự động tạo mã loại chuẩn hóa</b> (VD: <i>Máy tính để bàn ➔ MT_</i>, <i>Laptop ➔ LT_</i>, <i>Máy in ➔ PR_</i>).</li>
                                <li>Gán người dùng phụ trách, vị trí và đơn vị trực thuộc.</li>
                            </ul>

                            <h4>2. Phê duyệt Nhân viên Mới Xin Gia Nhập (Duyệt NV)</h4>
                            <ul>
                                <li>Khi có nhân viên mới đăng ký vào phòng ban, trên Trang chủ của Trưởng phòng sẽ xuất hiện nút <b>👥 Duyệt NV</b> kèm số lượng chờ duyệt.</li>
                                <li>Bấm vào danh sách, kiểm tra họ tên/email và bấm <b>[Phê duyệt]</b> để kích hoạt tài khoản nhân viên.</li>
                            </ul>

                            <h4>3. Quản lý Đơn vị / Chi nhánh Trực thuộc</h4>
                            <ul>
                                <li>Vào thẻ <b>Quản lý Đơn vị</b> để thêm mới, sửa đổi các tổ đội, phòng chức năng, chi nhánh làm việc thuộc phạm vi phòng ban mình.</li>
                            </ul>

                            <h4>4. In Tem QR / Barcode & Xuất Excel Kiểm Kê</h4>
                            <ul>
                                <li>Chọn các thiết bị trong danh sách ➔ Nhấn <b>In ấn & Báo cáo</b> để in tem dán mã QR/Barcode hoặc xuất báo cáo kiểm kê Excel theo kỳ.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "swimlane_tech",
                    title: "0.4. Hướng Dẫn Nghiệp Vụ: Kỹ Thuật Viên & HelpDesk (Tech)",
                    htmlContent: #"""

                            <h3>Hướng Dẫn Nghiệp Vụ Chi Tiết - Kỹ Thuật Viên & HelpDesk</h3>
                            <p><b>Kỹ thuật viên</b> phụ trách tiếp nhận yêu cầu báo hỏng, di chuyển đến hiện trường xử lý và ghi nhận công tác phí.</p>

                            <h4>1. Tiếp nhận Yêu cầu Sự cố Tức thì</h4>
                            <ul>
                                <li>Khi có nhân viên báo hỏng, KTV nhận được chuông báo kèm <b>giọng nói tiếng Việt thông báo 2 lần</b> nội dung sự cố.</li>
                                <li>Mở phiếu trong mục <i>Hỗ trợ ➔ Quản lý sự cố</i>, chat trao đổi trực tiếp với người dùng và xem ảnh lỗi phóng to sắc nét.</li>
                            </ul>

                            <h4>2. Bắt đầu Di chuyển với Live GPS Hiện Trường</h4>
                            <ul>
                                <li>Bấm nút <b>🚀 Bắt đầu di chuyển</b>: Hệ thống tự động kích hoạt định vị GPS nền, vẽ tuyến đường di chuyển thực tế (OSRM) trên bản đồ và hiển thị cho người dùng biết KTV đang tới đâu.</li>
                                <li>Khi đến nơi bấm <b>📍 Đã đến nơi</b>; sau khi sửa chữa xong bấm <b>✅ Hoàn thành</b>.</li>
                            </ul>

                            <h4>3. Chấm Công GPS Hàng Ngày, Nhắc Nhở Tan Ca &amp; Tăng Ca Ngoài Giờ (OT)</h4>
                            <ul>
                                <li>Mở màn hình <i>Chấm công</i> trên App ➔ Chọn ca làm việc (Hành chính 08h-17h, Ca 1 07h-15h, Ca 2 14h-22h, Ca 3/Đêm 22h-06h) ➔ Kiểm tra bán kính GPS hợp lệ ➔ Bấm <b>Chấm công Vào ca / Ra ca</b>.</li>
                                <li><b>Chuông &amp; Giọng nói nhắc nhở tan ca:</b> Khi chạm mốc hết ca, điện thoại phát thông báo Heads-Up, rung chuông và đọc TTS nhắc nhở KTV bấm Check-out tan ca. Bấm vào thông báo sẽ mở ngay màn hình Chấm công.</li>
                                <li><b>Phân loại Check-out thông minh:</b>
                                    <br>&bull; <i>Quên check-out (không có ticket):</i> Chốt trần giờ công theo ca chuẩn (8 tiếng), nhãn xanh <b>✅ Hoàn thành ca</b>. Sau 3.5 giờ quá ca, hệ thống tự động Auto Check-out.
                                    <br>&bull; <i>Tăng ca ngoài giờ (có ticket sự cố ngoài ca):</i> Ghi nhận đủ 100% thời gian làm việc thực tế, nhãn cam đậm <b>🔥 Tăng ca ngoài giờ (OT)</b> và tính phụ cấp ngoài giờ (hệ số x1.5 / x2.0).
                                </li>
                            </ul>

                            <h4>4. Phân Quyền Quản Lý Nhân Sự Cho Bộ Phận Helpdesk (Theo Cấu Hình Hệ Thống)</h4>
                            <ul>
                                <li>Trong mục <i>Cấu hình hệ thống (Settings)</i>, Admin có nút gạt: <b>"Cho phép Helpdesk quản lý nhân sự &amp; phân quyền vai trò"</b>.</li>
                                <li>Khi BẬT: Helpdesk được phép tạo tài khoản mới (chủ động chọn vai trò Nhân viên, KTV, Helpdesk, Quản lý phòng ban), phê duyệt tài khoản xin gia nhập, phân quyền vai trò và đặt lại mật khẩu người dùng.</li>
                                <li><b>Khóa bảo vệ tài khoản Admin (<code>🔒 Admin (Đã khóa)</code>):</b> Bảo vệ an toàn tuyệt đối cho tài khoản Admin tối cao – Helpdesk không thể gán quyền Admin, không sửa đổi, không đổi mật khẩu và không xóa được tài khoản Admin.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "swimlane_staff",
                    title: "0.5. Hướng Dẫn Nghiệp Vụ: Nhân Viên Sử Dụng Thiết Bị (Staff)",
                    htmlContent: #"""

                            <h3>Hướng Dẫn Nghiệp Vụ Chi Tiết - Nhân Viên Sử Dụng (Staff)</h3>
                            <p><b>Nhân viên</b> theo dõi các thiết bị mình được cấp phát, tạo yêu cầu hỗ trợ khi gặp trục trặc và đánh giá chất lượng phục vụ.</p>

                            <h4>1. Theo dõi Thiết bị Được Bàn Giao</h4>
                            <ul>
                                <li>Mở ứng dụng để xem danh sách máy móc, serial, cấu hình và tình trạng các thiết bị cá nhân đang quản lý.</li>
                            </ul>

                            <h4>2. Tạo Phiếu Báo Hỏng Kèm Ảnh Hiện Trường</h4>
                            <ul>
                                <li>Khi thiết bị gặp sự cố, vào mục <i>Hỗ trợ ➔ + Tạo yêu cầu</i>, chọn thiết bị, mô tả lỗi và chụp ảnh thực tế đính kèm.</li>
                            </ul>

                            <h4>3. Chat Trực Tuyến & Theo Dõi Vị Trí KTV</h4>
                            <ul>
                                <li>Nhắn tin trực tiếp với KTV xử lý trong phiếu (hỗ trợ phóng to/thu nhỏ ảnh lỗi chi tiết).</li>
                                <li>Bấm nút <b>🏍️ Theo dõi KTV</b> để xem bản đồ lộ trình KTV đang di chuyển tới phòng làm việc của bạn.</li>
                            </ul>

                            <h4>4. Tự Đóng Phiếu hoặc Chấm Điểm 1-5 Sao</h4>
                            <ul>
                                <li>Nếu máy tự hoạt động lại hoặc tự khắc phục được, bấm <b>💡 Tôi đã tự xử lý xong</b> để KTV không phải di chuyển.</li>
                                <li>Khi KTV xử lý xong, chấm điểm <b>1 đến 5 ⭐</b> kèm nhận xét để hoàn tất phiếu và nâng cao chất lượng CSKH.</li>
                            </ul>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "1. Khởi Tạo & Xác Thực Hệ Thống",
            iconName: "building.2",
            defaultExpanded: true,
            articles: [
                HelpArticle(
                    id: "admin_init",
                    title: "1.1. Đăng ký Doanh nghiệp & Tài khoản Super Admin",
                    htmlContent: #"""

                            <h3>1. Đăng Ký Doanh Nghiệp Mới & Tài Khoản Quản Trị Tối Cao</h3>
                            <p>Hệ thống QLTB hoạt động theo kiến trúc <b>Đa Doanh nghiệp (Multi-tenant)</b>, đảm bảo dữ liệu của mỗi công ty hoàn toàn độc lập và bảo mật tuyệt đối.</p>
                            
                            <h4>A. Thao tác trên Mobile App</h4>
                            <ol>
                                <li>Tại màn hình đăng nhập, bấm vào nút <span class="badge badge-primary">🏢 Doanh nghiệp mới</span> ở khung phía dưới.</li>
                                <li>Điền đầy đủ thông tin:
                                    <ul>
                                        <li><b>Tên Doanh nghiệp:</b> Tên đầy đủ của công ty/tổ chức (VD: <i>Công ty Cổ phần Công nghệ ABC</i>).</li>
                                        <li><b>Mã Doanh nghiệp:</b> Mã định danh viết liền không dấu (VD: <code>ABC_TECH</code>). <i>Mã này dùng cho nhân viên khi xin gia nhập.</i></li>
                                        <li><b>Họ tên Admin:</b> Tên người quản trị tối cao (Super Admin).</li>
                                        <li><b>Email & Mật khẩu:</b> Tài khoản đăng nhập hệ thống.</li>
                                        <li><b>Số điện thoại:</b> Số liên hệ quản trị.</li>
                                    </ul>
                                </li>
                                <li>Nhấn <b>Xác nhận Đăng ký</b> để tạo không gian làm việc và vào ngay màn hình Quản trị.</li>
                            </ol>

                            <h4>B. Thao tác trên Bản Desktop</h4>
                            <ol>
                                <li>Tại màn hình Đăng nhập, bấm nút <b>Đăng ký Doanh nghiệp mới</b>.</li>
                                <li>Nhập thông tin tương tự và xác nhận. Hệ thống tự động tạo kho dữ liệu độc lập trên Cloud Firestore.</li>
                            </ol>

                            <div class="callout">
                                <b>💡 Lưu ý quan trọng:</b> Hãy ghi nhớ và chia sẻ <code>Mã Doanh Nghiệp</code> cho toàn bộ nhân viên trong công ty để họ có thể gửi yêu cầu gia nhập vào hệ thống.
                            </div>
                            <h4>D. Cơ Chế Xác Thực &amp; Kiểm Tra Email Tồn Tại</h4>
                            <p>Hệ thống tự động kiểm tra định dạng email theo chuẩn RFC Regex và kiểm tra trùng lặp email trên Firebase Authentication và Firestore. Nếu email đã được đăng ký cho doanh nghiệp khác hoặc đang trong tiến trình xử lý, hệ thống sẽ đưa ra thông báo cảnh báo rõ ràng để ngăn chặn việc tạo tài khoản trùng lặp gây xung đột dữ liệu.</p>

                        
"""#
                ),
                HelpArticle(
                    id: "auth_login_reset",
                    title: "1.2. Đăng nhập, Đổi mật khẩu & Quên mật khẩu",
                    htmlContent: #"""

                            <h3>2. Hướng Dẫn Đăng Nhập & Bảo Mật Tài Khoản</h3>
                            <p>Mỗi nhân sự trong tổ chức được cấp phát một tài khoản duy nhất gắn liền với Email công vụ.</p>
                            
                            <h4>A. Đăng nhập lần đầu & Đổi mật khẩu bắt buộc</h4>
                            <ul>
                                <li>Khi tài khoản được Admin tạo mới hoặc reset, mật khẩu mặc định ban đầu sẽ được cấp tạm thời.</li>
                                <li>Ở lần đăng nhập đầu tiên, hệ thống sẽ <b>tự động bật hộp thoại yêu cầu đổi mật khẩu mới</b> nhằm đảm bảo an toàn tuyệt đối.</li>
                                <li>Mật khẩu mới phải có độ dài tối thiểu 6 ký tự.</li>
                            </ul>

                            <h4>B. Tính năng Quên mật khẩu</h4>
                            <ol>
                                <li>Tại màn hình đăng nhập, bấm chọn <b>Quên mật khẩu?</b>.</li>
                                <li>Nhập địa chỉ Email tài khoản đã đăng ký trong hệ thống.</li>
                                <li>Bấm <b>Gửi yêu cầu</b>: Hệ thống sẽ tự động tạo thông báo gửi trực tiếp đến Quản trị viên (Admin) và HelpDesk để hỗ trợ cấp lại mật khẩu ngay trong ứng dụng.</li>
                            </ol>
                        
"""#
                ),
                HelpArticle(
                    id: "staff_join_approve",
                    title: "1.3. Nhân viên xin gia nhập & Quy trình phê duyệt",
                    htmlContent: #"""

                            <h3>3. Quy Trình Nhân Viên Xin Gia Nhập & Admin Phê Duyệt</h3>
                            <p>Quy trình đăng ký thành viên tự động giúp mở rộng quy mô doanh nghiệp mà không cần Admin phải nhập liệu thủ công từng tài khoản.</p>

                            <h4>A. Dành cho Nhân viên xin gia nhập (Trên App hoặc Desktop)</h4>
                            <ol>
                                <li>Tại màn hình đăng nhập, bấm <span class="badge badge-success">👤 Gia nhập Doanh nghiệp</span>.</li>
                                <li>Nhập chính xác <b>Mã Doanh nghiệp</b> do công ty cung cấp.</li>
                                <li>Điền: Họ tên, Email, Mật khẩu khởi tạo, Số điện thoại và Chọn <b>Phòng ban / Đơn vị</b> công tác.</li>
                                <li>Bấm <b>Gửi yêu cầu gia nhập</b>. Màn hình sẽ chuyển sang trạng thái <span class="badge badge-warning">⏳ Chờ Quản trị viên phê duyệt</span>.</li>
                            </ol>

                            <h4>B. Dành cho Quản trị viên (Admin) Phê duyệt</h4>
                            <ol>
                                <li>Admin nhận thông báo có nhân viên mới xin tham gia.</li>
                                <li>Truy cập mục <b>Quản lý Người dùng ➔ Phê duyệt nhân viên</b>.</li>
                                <li>Kiểm tra thông tin họ tên, email, phòng ban.</li>
                                <li>Bấm <span class="badge badge-success">✓ Phê duyệt</span> (tài khoản kích hoạt ngay) hoặc <span class="badge badge-danger">✗ Từ chối</span> (nhập lý do từ chối).</li>
                            </ol>
                            <h4>D. Tự Động Kiểm Tra Email Khi Xin Gia Nhập</h4>
                            <p>Khi nhân viên nhập email để gửi yêu cầu gia nhập doanh nghiệp, hệ thống tự động kiểm tra xem email này đã tồn tại trong danh sách thành viên hoặc đang có hồ sơ chờ duyệt hay chưa để ngăn chặn việc gửi yêu cầu trùng lặp.</p>

                        
"""#
                ),
                HelpArticle(
                    id: "license_management",
                    title: "1.4. Quản lý Gói cước & Kích hoạt Bản quyền Key",
                    htmlContent: #"""

                            <h3>4. Quản Lý Gói Cước & Kích Hoạt Bản Quyền Hệ Thống</h3>
                            <p>QLTB cung cấp nhiều gói bản quyền linh hoạt phù hợp với mọi quy mô doanh nghiệp từ nhỏ đến tập đoàn lớn.</p>

                            <h4>A. Danh sách các gói bản quyền</h4>
                            <ul>
                                <li><span class="badge badge-outline">Gói Miễn Phí (Free):</span> Quản lý tối đa 50 thiết bị, tính năng cơ bản.</li>
                                <li><span class="badge badge-primary">Gói Cơ Bản (Basic):</span> Quản lý 200 thiết bị, hỗ trợ ticket sự cố & in ấn A4.</li>
                                <li><span class="badge badge-success">Gói Nâng Cao (Pro):</span> Quản lý 1,000 thiết bị, đầy đủ GPS Chấm công & Báo cáo chất lượng.</li>
                                <li><span class="badge badge-purple">Gói Doanh Nghiệp (Enterprise):</span> Quản lý 5,000 thiết bị, Live GPS Kỹ thuật viên, Bản quyền vĩnh viễn.</li>
                                <li><span class="badge badge-dark">Gói VIP Unlimited:</span> Không giới hạn thiết bị, Full quyền năng cao cấp nhất.</li>
                            </ul>

                            <h4>B. Hướng dẫn Kích hoạt License Key</h4>
                            <ol>
                                <li>Vào mục <b>Cài đặt ➔ Thông tin ứng dụng & Bản quyền</b> (trên Desktop hoặc App).</li>
                                <li>Xem mã định danh máy chủ <code>Device ID</code> / <code>Machine Code</code>.</li>
                                <li>Dán mã kích hoạt <b>License Key</b> nhận được từ nhà phát triển vào ô nhập.</li>
                                <li>Nhấn <b>Kích hoạt bản quyền</b>: Hệ thống sẽ mở khóa ngay lập tức toàn bộ tính năng và thời hạn sử dụng tương ứng.</li>
                            </ol>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "2. Cơ Cấu Tổ Chức & Phân Quyền",
            iconName: "person.2.circle",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "dept_management",
                    title: "2.1. Quản lý Phòng ban & Cờ tiếp nhận sự cố (HelpDesk)",
                    htmlContent: #"""

                            <h3>1. Quản Lý Phòng Ban & Chỉ Định Bộ Phận HelpDesk</h3>
                            <p>Thiết lập sơ đồ tổ chức phòng ban rõ ràng là nền tảng để phân luồng sự cố và quản lý tài sản chính xác.</p>

                            <h4>A. Tạo & Quản lý Phòng ban</h4>
                            <ol>
                                <li>Truy cập màn hình <b>Quản lý Danh mục ➔ Phòng ban</b>.</li>
                                <li>Bấm <b>+ Thêm Phòng ban</b>.</li>
                                <li>Nhập Tên phòng ban (VD: <i>Phòng Kỹ thuật & CNTT</i>, <i>Phòng Hành chính</i>, <i>Phòng Kế toán</i>...).</li>
                                <li>Nhập Mã phòng ban và mô tả chức năng nhiệm vụ.</li>
                            </ol>

                            <h4>B. Cờ "Phòng ban Tiếp nhận & Xử lý Sự cố" (HelpDesk Flag)</h4>
                            <ul>
                                <li>Khi bật tùy chọn <b>Phòng ban tiếp nhận sự cố</b> cho một phòng ban (VD: Phòng CNTT, Ban Bảo trì):</li>
                                <li>Toàn bộ nhân sự trong phòng ban này sẽ có quyền tiếp nhận các phiếu báo hỏng của nhân viên toàn công ty, tiến hành điều phối và phân công kỹ thuật viên xử lý.</li>
                                <li>Tên phòng ban sẽ tự động hiển thị chính xác dưới tên người hỗ trợ trên màn hình chat và báo cáo.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "role_matrix",
                    title: "2.2. Ma trận Phân quyền 5 Cấp bậc",
                    htmlContent: #"""

                            <h3>2. Ma Trận Phân Quyền & Vai Trò Trong Hệ Thống</h3>
                            <p>Hệ thống hỗ trợ 5 vai trò phân quyền chuẩn mực và an toàn:</p>

                            <table border="1" cellpadding="8" cellspacing="0" style="border-collapse: collapse; width: 100%; margin: 12px 0;">
                                <tr style="background-color: #f1f5f9;">
                                    <th style="color: #002a8f; text-align: left;">Vai trò</th>
                                    <th style="color: #002a8f; text-align: left;">Quyền hạn chính</th>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-dark">Super Admin</span></td>
                                    <td>Quyền tối cao: Cấu hình Doanh nghiệp, Bản quyền Key, Chế độ bảo trì, Sao lưu đám mây, Phân quyền toàn hệ thống.</td>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-danger">Admin</span></td>
                                    <td>Quản lý toàn bộ thiết bị, người dùng, phê duyệt thành viên, điều phối sự cố, cấu hình tiêu đề báo cáo, in ấn A4.</td>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-purple">Manager (Quản lý)</span></td>
                                    <td>Quản lý tài sản và nhân viên trong phòng ban/đơn vị phụ trách, duyệt phiếu trong bộ phận.</td>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-purple" style="background-color: #f3e8ff; color: #7e22ce;">Helpdesk (IT Support)</span></td>
                                    <td>Tiếp nhận sự cố, điều phối kỹ thuật viên, theo dõi tiến độ SLA. <i>Khi được Admin BẬT nút gạt cấu hình nhân sự:</i> Helpdesk có toàn quyền tạo nhân sự mới (chọn vai trò), duyệt thành viên, phân quyền vai trò và đặt lại mật khẩu (được bảo vệ tuyệt đối: không thể can thiệp tài khoản Admin).</td>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-warning">Kỹ thuật viên (Tech)</span></td>
                                    <td>Nhận điều phối sự cố, cập nhật lộ trình di chuyển Live GPS, sửa chữa thiết bị, nhận đánh giá sao từ người dùng.</td>
                                </tr>
                                <tr>
                                    <td><span class="badge badge-primary">Nhân viên (Staff)</span></td>
                                    <td>Xem thiết bị được bàn giao, gửi yêu cầu hỗ trợ, chat trực tuyến, tự đóng phiếu và đánh giá chất lượng phục vụ.</td>
                                </tr>
                            </table>

                            <div class="callout" style="border-left: 4px solid #002a8f; background-color: #f8faff; margin-top: 10px; padding: 8px 12px;">
                                <b style="color: #002a8f;">⚙️ Cơ Chế Phân Quyền Vận Hành Nhân Sự Cho Helpdesk (Toggle Switch):</b>
                                <p style="margin: 4px 0 0 0; font-size: 12px; color: #334155; line-height: 1.45;">
                                    Admin có thể chủ động Bật/Tắt quyền quản lý nhân sự cho Helpdesk trong Cấu hình hệ thống. Khi bật, toàn bộ các dropdown phân quyền tại Desktop đều hỗ trợ con trỏ bàn tay (<code>PointerIcon.Hand</code>) mượt mà, đồng thời gắn nhãn bảo vệ <code>🔒 Admin (Đã khóa)</code> đối với tài khoản Quản trị viên để ngăn chặn mọi thao tác sửa đổi hay xóa nhầm.
                                </p>
                            </div>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "3. Quản Lý Thiết Bị & Tài Sản",
            iconName: "laptopcomputer.and.iphone",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "device_add_manage",
                    title: "3.1. Thêm mới, Chỉnh sửa & Gán người sử dụng",
                    htmlContent: #"""

                            <h3>1. Hướng Dẫn Quản Lý Tài Sản & Thiết Bị</h3>
                            <p>Theo dõi chặt chẽ vòng đời của toàn bộ thiết bị công nghệ và tài sản trong doanh nghiệp.</p>

                            <h4>A. Thêm mới Thiết bị</h4>
                            <ol>
                                <li>Vào màn hình <b>Danh sách Thiết bị</b> ➔ Bấm <b>+ Thêm thiết bị mới</b>.</li>
                                <li>Nhập các trường thông tin:
                                    <ul>
                                        <li><b>Tên thiết bị:</b> Tên gọi rõ ràng (VD: <i>Laptop Dell XPS 15 9520</i>).</li>
                                        <li><b>Mã thiết bị / Serial:</b> Mã định danh duy nhất in trên tem hoặc số Serial của nhà sản xuất.</li>
                                        <li><b>Loại thiết bị:</b> Phân loại (Máy tính, Máy in, Máy chủ, Mạng...).</li>
                                        <li><b>Phòng ban & Đơn vị:</b> Nơi thiết bị đang được bố trí sử dụng.</li>
                                        <li><b>Người đang giữ:</b> Chọn nhân viên tiếp nhận bàn giao.</li>
                                        <li><b>Thông số kỹ thuật:</b> CPU, RAM, Ổ cứng, Cấu hình chi tiết.</li>
                                        <li><b>Ngày mua & Hạn bảo hành:</b> Để hệ thống tự động cảnh báo bảo trì.</li>
                                        <li><b>Hình ảnh thực tế:</b> Chụp hoặc tải ảnh thiết bị lên đám mây.</li>
                                    </ul>
                                </li>
                                <li>Bấm <b>Lưu thông tin</b>.</li>
                            </ol>

                            <h4>B. Quản lý Trạng thái Thiết bị</h4>
                            <ul>
                                <li><span class="badge badge-success">Đang sử dụng:</span> Thiết bị đang phục vụ công việc bình thường.</li>
                                <li><span class="badge badge-primary">Sẵn sàng cấp phát:</span> Thiết bị trong kho sẵn sàng bàn giao.</li>
                                <li><span class="badge badge-danger">Hỏng hóc / Đang báo lỗi:</span> Đang chờ xử lý sự cố.</li>
                                <li><span class="badge badge-warning">Đang bảo trì / Sửa chữa:</span> Kỹ thuật viên đang xử lý.</li>
                                <li><span class="badge badge-outline">Đã thanh lý:</span> Đã hết khấu hao và loại khỏi tài sản công ty.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "barcode_qr_scanner",
                    title: "3.2. Quét mã QR / Barcode & Cài đặt máy quét",
                    htmlContent: #"""

                            <h3>2. Tra Cứu Siêu Tốc Bằng Mã QR & Đầu Đọc Barcode</h3>
                            <p>Tính năng quét mã giúp kiểm kê và tra cứu thiết bị chỉ trong 1 giây mà không cần nhập liệu thủ công.</p>

                            <h4>A. Quét mã trên Mobile App</h4>
                            <ol>
                                <li>Bấm biểu tượng <b>Mã QR (Scanner)</b> trên thanh tìm kiếm hoặc BottomBar.</li>
                                <li>Hướng camera về phía mã QR / Barcode dán trên thiết bị.</li>
                                <li>Hệ thống tự động nhận diện và mở ngay màn hình chi tiết thiết bị, lịch sử sửa chữa và các nút thao tác nhanh.</li>
                            </ol>

                            <h4>B. Sử dụng Đầu đọc mã vạch trên Desktop</h4>
                            <ol>
                                <li>Cắm đầu đọc mã vạch USB / Bluetooth vào máy tính Desktop.</li>
                                <li>Vào mục <b>Cài đặt Máy quét</b> để cấu hình tiền tố/hậu tố nếu cần.</li>
                                <li>Tại màn hình Thiết bị hoặc Hành động nhanh, chỉ cần bấm đầu đọc vào tem tài sản, phần mềm sẽ tự động lọc đúng thiết bị ngay lập tức.</li>
                            </ol>
                        
"""#
                ),
                HelpArticle(
                    id: "device_lifecycle_flow",
                    title: "3.3. Quy trình Vòng đời Thiết bị: Cấp phát, Luân chuyển, Kiểm kê & Thanh lý",
                    htmlContent: #"""

                            <h3>3. Quản Trị Vòng Đời Toàn Diện Thiết Bị &amp; Tài Sản</h3>
                            <p>Hệ thống QLTB chuẩn hóa chu trình quản trị tài sản công nghệ thông tin từ lúc nhập kho đến khi kết thúc vòng đời thanh lý theo tiêu chuẩn quốc tế.</p>

                            <h4>A. Sơ đồ 6 Giai đoạn Vòng đời Tài sản</h4>
                            <ol>
                                <li><b>Giai đoạn 1 - Nhập kho &amp; Định danh tài sản:</b>
                                    <ul>
                                        <li>Khi mua mới, thiết bị được tạo mã tự động theo tiền tố quy chuẩn: <code>MT_</code> (Máy tính để bàn), <code>LT_</code> (Laptop), <code>PR_</code> (Máy in), <code>SV_</code> (Máy chủ), <code>NT_</code> (Thiết bị mạng), <code>SC_</code> (Máy quét).</li>
                                        <li>Ghi nhận cấu hình chi tiết (CPU, RAM, Ổ cứng, Serial nhà sản xuất), ngày mua, hạn bảo hành và ảnh chụp thực tế lên Cloudinary.</li>
                                        <li>Trạng thái: <span class="badge badge-primary">Sẵn sàng cấp phát (IN_STOCK)</span>.</li>
                                    </ul>
                                </li>
                                <li><b>Giai đoạn 2 - Cấp phát &amp; Bàn giao Thiết bị:</b>
                                    <ul>
                                        <li>Gán nhân viên và phòng ban tiếp nhận sử dụng.</li>
                                        <li>Tự động xuất <b>Biên bản Bàn giao Tài sản A4</b> chuẩn thể thức Nghị định 30, đầy đủ chữ ký bên giao và bên nhận.</li>
                                        <li>Trạng thái: <span class="badge badge-success">Đang sử dụng (ACTIVE)</span>.</li>
                                    </ul>
                                </li>
                                <li><b>Giai đoạn 3 - Vận hành, Giám sát &amp; Luân chuyển:</b>
                                    <ul>
                                        <li>Khi nhân viên thay đổi vị trí hoặc điều chuyển sang chi nhánh khác, hệ thống thực hiện nghiệp vụ Luân chuyển.</li>
                                        <li>Mọi biến động phòng ban, người giữ được lưu vết tự động vào <b>Nhật ký Luân chuyển (Audit Log)</b> thời gian thực.</li>
                                    </ul>
                                </li>
                                <li><b>Giai đoạn 4 - Bảo dưỡng, Sửa chữa &amp; Lịch sử Ticket:</b>
                                    <ul>
                                        <li>Khi thiết bị phát sinh sự cố, trạng thái tự động đổi thành <span class="badge badge-danger">Hỏng hóc (DAMAGED)</span> hoặc <span class="badge badge-warning">Đang sửa chữa (MAINTENANCE)</span>.</li>
                                        <li>Toàn bộ lịch sử hỏng hóc, thay thế linh kiện, chi phí và biên bản nghiệm thu từ Ticket đều tự động liên kết vào hồ sơ thiết bị.</li>
                                    </ul>
                                </li>
                                <li><b>Giai đoạn 5 - Kiểm kê Định kỳ bằng Quét mã QR:</b>
                                    <ul>
                                        <li>Đoàn kiểm kê dùng Mobile App quét mã QR dán trên máy để đối soát nhanh vị trí thực tế so với sổ sách quản trị.</li>
                                        <li>Tự động lập danh sách tài sản thất lạc, tài sản thừa hoặc hư hỏng cần xử lý.</li>
                                    </ul>
                                </li>
                                <li><b>Giai đoạn 6 - Thu hồi, Khấu hao &amp; Đề xuất Thanh lý:</b>
                                    <ul>
                                        <li>Thu hồi khi nhân viên nghỉ việc hoặc thiết bị hết khấu hao kỹ thuật (3-5 năm).</li>
                                        <li>Thiết bị hỏng nặng không thể khắc phục hoặc chi phí sửa &gt; 50% giá trị còn lại sẽ được lập Hội đồng thẩm định và xuất <b>Biên bản Đề xuất Thanh lý A4</b>.</li>
                                        <li>Trạng thái: <span class="badge badge-dark">Đã thanh lý (DISPOSED)</span> (Khóa vĩnh viễn dữ liệu).</li>
                                    </ul>
                                </li>
                            </ol>

                            <h4>B. Bảng Tra Cứu Trạng Thái Thiết Bị Chuẩn</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px;">Trạng Thái</td>
                                    <td style="padding:6px;">Mã Enum</td>
                                    <td style="padding:6px;">Ý Nghĩa Nghiệp Vụ</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-success">Đang sử dụng</span></td>
                                    <td style="padding:6px;"><code>ACTIVE</code></td>
                                    <td style="padding:6px;">Thiết bị đã bàn giao cho nhân viên và đang hoạt động tốt.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-primary">Sẵn sàng cấp phát</span></td>
                                    <td style="padding:6px;"><code>IN_STOCK</code></td>
                                    <td style="padding:6px;">Thiết bị nằm trong kho IT, sẵn sàng bàn giao khi có yêu cầu.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-danger">Hỏng hóc</span></td>
                                    <td style="padding:6px;"><code>DAMAGED</code></td>
                                    <td style="padding:6px;">Thiết bị gặp sự cố đang chờ kỹ thuật viên tiếp nhận xử lý.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-warning">Đang sửa chữa</span></td>
                                    <td style="padding:6px;"><code>MAINTENANCE</code></td>
                                    <td style="padding:6px;">KTV đang sửa chữa hoặc gửi bảo hành chính hãng.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-dark">Đã thanh lý</span></td>
                                    <td style="padding:6px;"><code>DISPOSED</code></td>
                                    <td style="padding:6px;">Tài sản đã hết khấu hao và loại khỏi danh mục kiểm kê.</td>
                                </tr>
                            </table>
                        
"""#
                ),
                HelpArticle(
                    id: "barcode_label_printing",
                    title: "3.4. Quản lý Tem Nhãn Mã Vạch & Tem QR Code Chuẩn Mực",
                    htmlContent: #"""

                            <h3>4. Quy Chuẩn &amp; Hướng Dẫn In Tem Nhãn Dán Tài Sản</h3>
                            <p>Mỗi thiết bị trong doanh nghiệp bắt buộc phải được dán tem định danh chứa mã QR và mã Barcode để phục vụ tra cứu và kiểm kê tức thì.</p>

                            <h4>A. Thông tin hiển thị trên Tem Chuẩn</h4>
                            <ul>
                                <li><b>Logo Doanh Nghiệp:</b> Nhận diện thương hiệu công ty.</li>
                                <li><b>Tên Thiết Bị &amp; Model:</b> Ngắn gọn, súc tích (VD: <i>PC Dell OptiPlex 7090</i>).</li>
                                <li><b>Mã Tài Sản / Serial:</b> In đậm rõ nét (VD: <code>MT_P01_0042</code>).</li>
                                <li><b>Mã QR &amp; Barcode:</b> Độ phân giải cao, hỗ trợ máy quét quang học và camera điện thoại.</li>
                                <li><b>Phòng ban &amp; Hotline IT:</b> Hỗ trợ người dùng gọi ứng cứu sự cố nhanh.</li>
                            </ul>

                            <h4>B. Các khổ tem in ấn được hỗ trợ</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px;">Loại Khổ Tem</td>
                                    <td style="padding:6px;">Kích Thước (R x C)</td>
                                    <td style="padding:6px;">Thiết Bị In Phù Hợp</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Tem Nhiệt Cuộn (Chuẩn)</b></td>
                                    <td style="padding:6px;">50mm x 30mm</td>
                                    <td style="padding:6px;">Máy in tem nhiệt chuyên dụng (Xprinter, Bixolon, Zebra).</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Tem Nhỏ (Thiết bị mini)</b></td>
                                    <td style="padding:6px;">35mm x 22mm</td>
                                    <td style="padding:6px;">Dán chuột, bàn phím, điện thoại bàn, switch mạng.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Tem Lớn (Máy chủ / Tủ rack)</b></td>
                                    <td style="padding:6px;">70mm x 40mm</td>
                                    <td style="padding:6px;">Dán máy chủ Server, máy photocopy, tủ rack viễn thông.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Giấy Decal A4 nhiều tem</b></td>
                                    <td style="padding:6px;">Khổ A4 (Tomy 145/146)</td>
                                    <td style="padding:6px;">In trực tiếp trên máy in laser văn phòng thông thường (HP, Canon).</td>
                                </tr>
                            </table>

                            <h4>C. Các bước in tem hàng loạt</h4>
                            <ol>
                                <li>Mở màn hình <b>Quản lý Thiết bị</b> ➔ Chọn nút <b>In tem tài sản</b>.</li>
                                <li>Lọc danh sách theo: <i>Phòng ban</i>, <i>Loại thiết bị</i>, hoặc tích chọn từng máy cụ thể.</li>
                                <li>Chọn mẫu tem và kích thước phù hợp.</li>
                                <li>Bấm <b>Xem trước (Print Preview)</b> để kiểm tra lề và độ sắc nét ➔ Bấm <b>In trực tiếp</b> hoặc <b>Xuất file PDF</b>.</li>
                            </ol>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "4. Tiếp Nhận & Xử Lý Sự Cố Trực Tuyến",
            iconName: "person.2.circle",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "ticket_create_flow",
                    title: "4.1. Tạo phiếu yêu cầu hỗ trợ sự cố (Ticket)",
                    htmlContent: #"""

                            <h3>1. Hướng Dẫn Tạo Phiếu Báo Hỏng & Yêu Cầu Hỗ Trợ</h3>
                            <p>Khi thiết bị gặp sự cố (không lên nguồn, lỗi mạng, máy in kẹt giấy, lỗi phần mềm...), nhân viên gửi phiếu yêu cầu để được hỗ trợ nhanh nhất.</p>

                            <h4>A. Các bước gửi yêu cầu</h4>
                            <ol>
                                <li>Nhân viên mở màn hình <b>Hỗ trợ (Support)</b> ➔ Bấm <b>+ Tạo yêu cầu mới</b>.</li>
                                <li>Chọn thiết bị gặp sự cố từ danh sách thiết bị được giao (hoặc chọn "Sự cố chung").</li>
                                <li>Chọn danh mục lỗi: <i>Phần cứng, Mạng nội bộ, Phần mềm, Máy in/Scan, Khác...</i></li>
                                <li>Chọn mức độ ưu tiên:
                                    <ul>
                                        <li><span class="badge badge-primary">Bình thường:</span> Sự cố không làm gián đoạn khẩn cấp công việc.</li>
                                        <li><span class="badge badge-warning">Gấp:</span> Ảnh hưởng trực tiếp đến tiến độ công việc trong ngày.</li>
                                        <li><span class="badge badge-danger">Khẩn cấp:</span> Tê liệt hệ thống, máy chủ, đường truyền chính.</li>
                                    </ul>
                                </li>
                                <li>Mô tả chi tiết triệu chứng lỗi và <b>đính kèm hình ảnh chụp thực tế màn hình/thiết bị lỗi</b>.</li>
                                <li>Bấm <b>Gửi yêu cầu hỗ trợ</b>.</li>
                            </ol>
                        
"""#
                ),
                HelpArticle(
                    id: "ticket_chat_zoom",
                    title: "4.2. Khung Chat Trực Tuyến & Phóng To/Thu Nhỏ Ảnh Đính Kèm",
                    htmlContent: #"""

                            <h3>2. Trò Chuyện Trực Tuyến & Xem Ảnh Chi Tiết (Zoom & Pan)</h3>
                            <p>Hệ thống chat 2 chiều thời gian thực kết nối tức thì nhân viên báo lỗi với Kỹ thuật viên và Quản trị viên.</p>

                            <h4>A. Trò chuyện và Phân biệt Phòng ban</h4>
                            <ul>
                                <li>Mọi tin nhắn gửi đi được đồng bộ tức thời qua Cloud Firestore.</li>
                                <li>Dưới tên người gửi luôn hiển thị <b>chính xác tên phòng ban công tác</b> (VD: <i>Phòng Kỹ thuật & CNTT</i>, <i>Phòng Kế toán</i>) giúp nhận diện rõ vai trò.</li>
                            </ul>

                            <h4>B. Xem ảnh đính kèm với tính năng Phóng to / Thu nhỏ (Zoom & Pan)</h4>
                            <ul>
                                <li>Bấm vào hình ảnh thumbnail trong khung chat để mở màn hình <b>Xem ảnh nâng cao</b>.</li>
                                <li><b>Trên Mobile App:</b> Dùng 2 ngón tay chụm/mở để Phóng to (Zoom In) và Thu nhỏ (Zoom Out), vuốt để di chuyển xem từng chi tiết lỗi kỹ thuật.</li>
                                <li><b>Trên Desktop:</b> Sử dụng thanh điều khiển phóng to (+), thu nhỏ (-), xoay ảnh và xem toàn màn hình sắc nét.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "self_resolved_flow",
                    title: "4.3. Tính năng 'Tôi đã tự xử lý xong' & Khóa Đánh giá",
                    htmlContent: #"""

                            <h3>3. Tự Xử Lý Xong & Đánh Giá Chất Lượng Phục Vụ</h3>
                            <p>Tối ưu hóa thời gian và nguồn lực kỹ thuật với quy trình tự đóng phiếu thông minh.</p>

                            <h4>A. Thẻ "💡 Tôi đã tự xử lý xong" (Ghim cố định)</h4>
                            <ul>
                                <li>Khi người dùng tự giải quyết được sự cố (VD: tự cắm lại cáp mạng, khởi động lại máy thành công):</li>
                                <li>Bấm nút <b>[Đóng phiếu]</b> trên thanh banner được <b>ghim cố định ngay dưới TopBar (trên App)</b> hoặc kế bên nút Đánh giá (trên Desktop).</li>
                                <li>Hệ thống sẽ đóng phiếu ngay lập tức, tự động <b>dừng lộ trình di chuyển của KTV</b> để KTV không mất công di chuyển.</li>
                            </ul>

                            <h4>B. Đánh giá chất lượng & Khóa đánh giá cố định</h4>
                            <ol>
                                <li>Người dùng chọn số sao (1 đến 5 ⭐) và viết nhận xét dịch vụ.</li>
                                <li><b>Cơ chế tạo phiếu tự động:</b> Nếu đánh giá < 3 sao, hệ thống tự động gợi ý tạo phiếu mới để cấp quản lý tiếp tục theo dõi.</li>
                                <li>Sau khi gửi, Card kết quả đánh giá sẽ được <b>ghim cố định ở chân trang với biểu tượng ổ khóa 🔒</b> thể hiện phiếu đã hoàn tất an toàn.</li>
                            </ol>
                        
"""#
                ),
                HelpArticle(
                    id: "ticket_itil_workflow",
                    title: "4.4. Quy Trình 6 Bước Hỗ Trợ Ticket & Điều Phối Sự Cố (ITIL Service Desk)",
                    htmlContent: #"""

                            <h3>4. Quy Trình 6 Bước Hỗ Trợ Ticket &amp; Điều Phối Sự Cố Chuẩn ITIL</h3>
                            <p>Quy chuẩn vận hành hỗ trợ kỹ thuật tập trung theo tiêu chuẩn ITIL Service Desk, kết hợp cảnh báo âm thanh thời gian thực, dẫn đường OSRM và khung kiểm soát chất lượng Reopen.</p>

                            <h4>A. Khung Cam Kết Thời Gian Phản Hồi &amp; Xử Lý Sự Cố (SLA Matrix)</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px;">Mức Độ Ưu Tiên</td>
                                    <td style="padding:6px;">Thời Gian Phản Hồi (SLA P1)</td>
                                    <td style="padding:6px;">Thời Gian Xử Lý Xong (SLA P2)</td>
                                    <td style="padding:6px;">Mô Tả Tiêu Biểu</td>
                                </tr>
                                <tr style="background-color:#fef2f2;">
                                    <td style="padding:6px;"><span class="badge badge-danger">CRITICAL (Khẩn cấp)</span></td>
                                    <td style="padding:6px;"><b>&le; 15 phút</b></td>
                                    <td style="padding:6px;"><b>&le; 2 giờ</b></td>
                                    <td style="padding:6px;">Sập máy chủ, đứt cáp quang chính, tê liệt hệ thống toàn đơn vị.</td>
                                </tr>
                                <tr style="background-color:#fffbeb;">
                                    <td style="padding:6px;"><span class="badge badge-warning">HIGH (Cao)</span></td>
                                    <td style="padding:6px;"><b>&le; 30 phút</b></td>
                                    <td style="padding:6px;"><b>&le; 4 giờ</b></td>
                                    <td style="padding:6px;">Hỏng thiết bị phòng giám đốc, máy in phòng kế toán ngày chốt sổ.</td>
                                </tr>
                                <tr style="background-color:#f0fdf4;">
                                    <td style="padding:6px;"><span class="badge badge-success">MEDIUM (Bình thường)</span></td>
                                    <td style="padding:6px;"><b>&le; 1 giờ</b></td>
                                    <td style="padding:6px;"><b>&le; 8 giờ</b></td>
                                    <td style="padding:6px;">Máy tính cá nhân lỗi phần mềm, virus nhẹ, yêu cầu cài đặt bổ sung.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-outline">LOW (Thấp)</span></td>
                                    <td style="padding:6px;"><b>&le; 2 giờ</b></td>
                                    <td style="padding:6px;"><b>&le; 24 giờ</b></td>
                                    <td style="padding:6px;">Yêu cầu hỗ trợ hướng dẫn sử dụng, vệ sinh máy tính định kỳ.</td>
                                </tr>
                            </table>

                            <h4>B. Hệ Thống Cảnh Báo Âm Thanh &amp; Giọng Đọc Trợ Lý Ảo Voice TTS</h4>
                            <ul>
                                <li><b>Chuông Báo Động Định Kỳ:</b> Khi có ticket mới được tạo, hệ thống kích hoạt chuông cảnh báo lặp lại mỗi <b>30 giây</b> cho đến khi có KTV bấm tiếp nhận.</li>
                                <li><b>Giọng Đọc Trợ Lý Ảo Tiếng Việt:</b> Phát tự động 2 lần: <i>"Có sự cố mới tại [Tên Phòng Ban] - Mức độ: [Khẩn cấp / Cao] - Cần hỗ trợ ngay!"</i>.</li>
                                <li><b>Phân Quyền Âm Thanh:</b> Chỉ kích hoạt âm thanh trên thiết bị của KTV thuộc đúng nhóm HelpDesk được phân công phụ trách.</li>
                            </ul>

                            <h4>C. Chi Tiết 6 Bước Quy Trình Vận Hành</h4>
                            <ol>
                                <li><b>Bước 1 - Tiếp nhận &amp; Phân loại:</b> Người dùng gửi ticket kèm ảnh chụp lỗi ➔ Hệ thống tự động phân loại mức độ ưu tiên và định tuyến HelpDesk.</li>
                                <li><b>Bước 2 - Phân công &amp; Phản hồi ban đầu:</b> Trưởng nhóm hoặc KTV bấm nhận ticket ➔ Chốt mốc thời gian tính <b>SLA P1</b> (Phản hồi ban đầu).</li>
                                <li><b>Bước 3 - Điều hướng lộ trình &amp; Dẫn đường OSRM:</b> KTV bấm <i>"Bắt đầu di chuyển"</i> ➔ Hệ thống kích hoạt GPS và dẫn đường lộ trình ngắn nhất qua bản đồ OSRM.</li>
                                <li><b>Bước 4 - Check-in Hiện trường &amp; Khắc phục:</b> Khi KTV đến trong bán kính <b>150m</b> (arrivalRadiusMeters), hệ thống tự xác nhận check-in ➔ KTV tiến hành xử lý kỹ thuật và trao đổi qua chat trực tuyến.</li>
                                <li><b>Bước 5 - Nghiệm thu Kỹ thuật &amp; Đóng Ticket:</b> Hoàn tất sửa chữa ➔ KTV chụp ảnh xác nhận và đóng ticket ➔ Hệ thống tự động sinh phiếu quyết toán công tác phí PENDING.</li>
                                <li><b>Bước 6 - Khung Theo Dõi Chất Lượng &amp; Chế Tài Reopen:</b>
                                    <ul>
                                        <li>Hệ thống kích hoạt đồng hồ theo dõi chất lượng sau khi đóng ticket:
                                            <table border="1" cellpadding="5" cellspacing="0" style="width:100%; border-collapse:collapse; margin:6px 0; font-size:11.5px;">
                                                <tr style="background:#f1f5f9;">
                                                    <td>Độ Ưu Tiên</td><td>CRITICAL</td><td>HIGH</td><td>NORMAL / MEDIUM</td><td>LOW</td>
                                                </tr>
                                                <tr style="font-weight:bold; color:#0284c7;">
                                                    <td>Khung Theo Dõi</td><td>120 giờ (5 ngày)</td><td>72 giờ (3 ngày)</td><td>48 giờ (2 ngày)</td><td>24 giờ (1 ngày)</td>
                                                </tr>
                                            </table>
                                        </li>
                                        <li><div class="callout-warning"><b>Chế tài Reopen:</b> Nếu người dùng phát hiện lỗi chưa triệt để và bấm <b>Reopen trong khung theo dõi chất lượng</b>, ticket sẽ bị đánh dấu chất lượng kém và gán hệ số quy đổi <b>P2 = 0.0 (0% thành công)</b> vào kết quả đánh giá KPI của KTV.</div></li>
                                    </ul>
                                </li>
                            </ol>
                            <h4>G. Điều Phối Thông Minh: Cảnh Báo Trạng Thái KTV &amp; Quy Tắc 24h Đóng 5 Sao</h4>
                            <ul>
                                <li><b>Giám sát trạng thái KTV thời gian thực:</b> Trên form điều phối sự cố, HelpDesk có thể quan sát trực quan trạng thái của từng KTV:
                                    <br>&bull; <span class="badge badge-success">Online</span>: KTV đang trực tuyến và sẵn sàng tiếp nhận ticket mới.
                                    <br>&bull; <span class="badge badge-warning">Bận việc</span>: KTV đang xử lý dở dang một ticket khác tại hiện trường.
                                    <br>&bull; <span class="badge badge-outline">Offline</span>: KTV đang ngoại tuyến hoặc ngoài ca trực.
                                </li>
                                <li><b>Cảnh báo khi gán KTV Bận việc hoặc Offline:</b> Nếu người điều phối chọn gán ticket cho KTV đang Bận việc hoặc Offline, hệ thống sẽ lập tức hiển thị <b>hộp thoại cảnh báo xác nhận</b>. Điều này giúp ngăn ngừa việc giao việc cho nhân sự không sẵn sàng, hạn chế tối đa nguy cơ trễ SLA phản hồi (P1) hoặc xử lý (P2).</li>
                                <li><b>Quy tắc tự động 5 sao sau 24h:</b> Khi KTV hoàn tất xử lý ticket, nếu trong vòng 24 giờ người dùng không thực hiện đánh giá và không có yêu cầu mở lại, hệ thống sẽ tự động ghi nhận mức <b>5.0 sao (Rất hài lòng)</b> để tính điểm KPI cho KTV.</li>
                            </ul>

                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "5. Giám Sát Lộ Trình Live GPS Kỹ Thuật Viên",
            iconName: "figure.outdoor.cycle",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "live_tracking_guide",
                    title: "5.1. Lộ trình Di chuyển Thời gian thực & Định tuyến OSRM",
                    htmlContent: #"""

                            <h3>1. Giám Sát Lộ Trình Kỹ Thuật Viên Thời Gian Thực</h3>
                            <p>Hệ thống tự động theo dõi và hiển thị vị trí kỹ thuật viên đang trên đường đến điểm hỗ trợ sự cố.</p>

                            <h4>A. Quy trình Kỹ thuật viên di chuyển</h4>
                            <ol>
                                <li>Kỹ thuật viên nhận phiếu điều phối ➔ Bấm <b>🚀 Bắt đầu di chuyển</b>.</li>
                                <li>Mobile App tự động kích hoạt dịch vụ GPS nền để cập nhật tọa độ liên tục lên máy chủ.</li>
                                <li>Khi đến nơi, KTV bấm <b>📍 Đã đến nơi</b> để bắt đầu thao tác kỹ thuật.</li>
                                <li>Sau khi khắc phục xong, KTV bấm <b>✅ Hoàn thành</b>.</li>
                            </ol>

                            <h4>B. Bản đồ trực quan & Tính khoảng cách OSRM</h4>
                            <ul>
                                <li>Người dùng và Admin bấm nút <b>🏍️ Theo dõi KTV</b> để mở bản đồ trực tuyến.</li>
                                <li>Hệ thống sử dụng máy chủ định tuyến OSRM để vẽ đường đi thực tế, tính toán chính xác số kilômét (km) và thời gian dự kiến đến nơi (ETA).</li>
                                <li>Số km di chuyển thực tế sẽ được tự động lưu lại làm căn cứ tính công tác phí.</li>
                            </ul>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "6. Chấm Công GPS & Công Tác Phí",
            iconName: "location.fill",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "attendance_guide",
                    title: "6.1. Điểm danh Chấm công GPS & Quản lý Công tác phí",
                    htmlContent: #"""

                            <h3>1. Chấm Công Định Vị GPS & Quản Lý Chi Phí Đi Lại</h3>
                            <p>Quản lý giờ công và chi phí công tác minh bạch, chính xác tuyệt đối.</p>

                            <h4>A. Chấm công GPS trên Mobile App</h4>
                            <ol>
                                <li>Nhân viên mở màn hình <b>Chấm công</b>.</li>
                                <li>Ứng dụng lấy vị trí GPS hiện tại và so sánh với tọa độ cơ quan/chi nhánh được cấp phép.</li>
                                <li>Nếu vị trí hợp lệ (trong bán kính cho phép, VD: 100m): Bấm <b>Chấm công Vào ca</b> hoặc <b>Chấm công Ra ca</b>.</li>
                                <li>Hệ thống lưu trữ thời gian, tọa độ, địa chỉ thực tế và ảnh xác thực.</li>
                            </ol>

                            <h4>C. Quy Chế Chấm Hết Ca, Nhắc Nhở Tan Ca &amp; Xử Lý Tăng Ca Ngoài Giờ (OT)</h4>
                            <ul>
                                <li><b>Khung giờ 4 ca làm việc chuẩn:</b>
                                    <ul>
                                        <li>☀️ <b>Hành chính (HC):</b> 08:00 – 17:00 (Nghỉ trưa 12:00 – 13:00, thời lượng: 8 tiếng làm việc).</li>
                                        <li>🌅 <b>Ca 1 - Sáng (SHIFT_1 / S):</b> 07:00 – 15:00 (Hỗ trợ mở quầy, mở cửa kinh doanh).</li>
                                        <li>🌇 <b>Ca 2 - Chiều (SHIFT_2 / C):</b> 14:00 – 22:00 (Hỗ trợ ca chiều và bàn giao đóng cửa).</li>
                                        <li>🌙 <b>Ca 3 - Đêm (NIGHT):</b> 22:00 – 06:00 sáng hôm sau (Bảo trì hệ thống, kiểm kê ban đêm).</li>
                                    </ul>
                                </li>
                                <li><b>Chuông, Rung &amp; Giọng nói nhắc nhở tan ca:</b> Khi chạm mốc kết thúc ca làm việc (và sau đó 12–15 phút nếu KTV chưa chấm hết ca), ứng dụng QLTB tự động bật thông báo đẩy Heads-Up, rung máy, phát chuông báo động và đọc giọng nói TTS tiếng Việt nhắc nhở KTV mở ứng dụng bấm Check-out tan ca. Bấm vào thông báo sẽ mở ngay màn hình Chấm công.</li>
                                <li><b>Trường hợp quên Check-out (không có ticket ngoài ca):</b> Hệ thống tự động <b>chốt trần thời gian làm việc tối đa theo ca chuẩn</b> (8 tiếng cho ca HC, ca 1, ca 2, ca 3), trạng thái <code>NORMAL</code> (nhãn xanh <b>✅ Hoàn thành ca</b>), giúp dữ liệu chấm công không bị nhảy vọt sai thực tế. Sau <b>3.5 giờ</b> kể từ giờ tan ca, nếu KTV chưa check-out và không có ticket nào đang mở, hệ thống sẽ <b>tự động Auto Check-out</b> với ghi chú <code>[Hệ thống tự động chốt do quên check-out (HH:mm)]</code> để giải phóng trạng thái điểm danh cho ca kế tiếp.</li>
                                <li><b>Trường hợp được điều phối ticket / Tăng ca ngoài giờ (OT):</b> Sau giờ ca, nếu KTV đang xử lý sự cố hoặc có ticket hoàn thành sau giờ ca, hệ thống ghi nhận <b>toàn bộ số phút làm việc thực tế</b> đến khi bấm Check-out, đánh dấu trạng thái <code>OVERTIME</code> (nhãn cam đậm <b>🔥 Tăng ca ngoài giờ (OT)</b>), đồng thời KTV được tính phụ cấp làm thêm ngoài giờ (hệ số x1.5 / x2.0 theo quy chế).</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "travel_expense_policy",
                    title: "6.2. Quy Chế & Cơ Chế Tính Toán Công Tác Phí Hiện Trường",
                    htmlContent: #"""

                            <h3>2. Quy Chế &amp; Cơ Chế Tính Toán Công Tác Phí Đi Lại</h3>
                            <p>Cơ chế tự động hóa 100% việc tính toán, thẩm định và chi trả công tác phí cho Kỹ thuật viên đi hỗ trợ hiện trường dựa trên đo đạc GPS và OSRM thời gian thực.</p>

                            <h4>A. Công Thức Tính Toán Chi Phí Chuẩn</h4>
                            <div class="callout">
                                <p style="margin:0 0 6px 0; font-size:13px; font-weight:bold; color:#0284c7;">Tổng Công Tác Phí = Tiền Xăng Xe + Phụ Cấp Chuyến Đi</p>
                                <ul style="margin:0; padding-left:18px;">
                                    <li><b>1. Tiền Xăng Xe (kmExpenseAmount):</b><br>
                                        <code>Tiền Xăng = Cự ly áp dụng (km) &times; pricePerKm</code><br>
                                        <i>(Định mức chuẩn: <b>5.000 VNĐ / km</b>, cự ly đo tự động bằng GPS thực tế hoặc OSRM)</i>.
                                    </li>
                                    <li><b>2. Phụ Cấp Chuyến Đi (tripAllowanceAmount):</b><br>
                                        <code>Phụ Cấp = tripBaseAllowance &times; overtimeMultiplier</code><br>
                                        <i>(Mức phụ cấp chuẩn: <b>50.000 VNĐ / ca</b> đi hiện trường &gt; 500m)</i>.
                                    </li>
                                    <li><b>3. Hệ Số Ngoài Giờ / Ca Đêm (overtimeMultiplier):</b><br>
                                        Ca phát sinh ngoài giờ hành chính (trước 08:00 hoặc sau 17:00) hoặc Thứ 7, Chủ Nhật được nhân hệ số <b>1.5x (75.000đ)</b> hoặc <b>2.0x (100.000đ)</b> để khích lệ tinh thần ứng cứu sự cố khẩn cấp.
                                    </li>
                                </ul>
                            </div>

                            <h4>B. Bảng Tham Số Cấu Hình Định Mức (TravelExpenseConfig)</h4>
                            <div class="callout-warning">
                                <b>Lưu ý quan trọng:</b> Toàn bộ các giá trị trong bảng định mức dưới đây (như đơn giá 5.000 VNĐ/km, phụ cấp ca 50.000 VNĐ, hệ số ngoài giờ...) chỉ mang tính chất <b>tham khảo định mức mẫu</b>. Trong thực tế vận hành, các mức định mức chi trả cụ thể sẽ được <b>áp dụng theo đúng quyết định và quy định ban hành của Ban Lãnh đạo</b> (Quản trị viên có thể tùy chỉnh linh hoạt các tham số này trong mục Cài đặt hệ thống).
                            </div>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px;">Tên Tham Số</td>
                                    <td style="padding:6px;">Giá Trị Tham Khảo</td>
                                    <td style="padding:6px;">Ý Nghĩa Áp Dụng</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><code>pricePerKm</code></td>
                                    <td style="padding:6px;"><b>5.000 VNĐ</b></td>
                                    <td style="padding:6px;">Đơn giá tiền xăng hỗ trợ trên mỗi km di chuyển bằng xe máy.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><code>tripBaseAllowance</code></td>
                                    <td style="padding:6px;"><b>50.000 VNĐ</b></td>
                                    <td style="padding:6px;">Phụ cấp cố định cho 1 ca hỗ trợ / sửa chữa tại hiện trường đơn vị.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><code>overtimeMultiplier</code></td>
                                    <td style="padding:6px;"><b>1.5x / 2.0x</b></td>
                                    <td style="padding:6px;">Hệ số nhân phụ cấp khi phát sinh ngoài giờ hoặc cuối tuần.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><code>arrivalRadiusMeters</code></td>
                                    <td style="padding:6px;"><b>150 mét</b></td>
                                    <td style="padding:6px;">Bán kính GPS xung quanh đơn vị để xác nhận KTV đã đến nơi.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><code>cancellationThreshold</code></td>
                                    <td style="padding:6px;"><b>50%</b></td>
                                    <td style="padding:6px;">Ngưỡng % quãng đường để phân loại chính sách duyệt khi hủy chuyến.</td>
                                </tr>
                            </table>

                            <h4>C. Ma Trận Xử Lý Khi Hủy Chuyến (Cancellation Policy)</h4>
                            <p>Khi sự cố tự khắc phục hoặc người dùng bấm Hủy giữa đường:</p>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px;">Trường Hợp Hủy</td>
                                    <td style="padding:6px;">Chính Sách Áp Dụng</td>
                                    <td style="padding:6px;">Quy Tắc Quyết Toán Chi Phí</td>
                                </tr>
                                <tr style="background-color:#f0fdf4;">
                                    <td style="padding:6px;"><b>Đã đi &ge; 50% cự ly</b></td>
                                    <td style="padding:6px;"><span class="badge badge-success">FULL_TRIP</span></td>
                                    <td style="padding:6px;">Quyết toán <b>TRỌN GÓI 100%</b> (100% tiền xăng + đủ 100% phụ cấp ca).</td>
                                </tr>
                                <tr style="background-color:#eff6ff;">
                                    <td style="padding:6px;"><b>Đã đi &lt; 50% cự ly</b></td>
                                    <td style="padding:6px;"><span class="badge badge-primary">HALF_TRIP (Mặc định)</span></td>
                                    <td style="padding:6px;">Quyết toán <b>1/2 chặng đường</b> (50% Km cự ly + 50% phụ cấp ca).</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Đã đi &lt; 50% (Tùy chọn)</b></td>
                                    <td style="padding:6px;"><span class="badge badge-outline">ACTUAL_KM</span></td>
                                    <td style="padding:6px;">Tính quãng đường khứ hồi đã đi rồi quay về (Km thực tế &times; 2) + 50% phụ cấp.</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><b>Đã đi &lt; 50% (Tùy chọn)</b></td>
                                    <td style="padding:6px;"><span class="badge badge-warning">FLAT_FEE</span></td>
                                    <td style="padding:6px;">Hỗ trợ cố định một khoản (Mặc định: <b>30.000 VNĐ</b>).</td>
                                </tr>
                                <tr style="background-color:#fef2f2;">
                                    <td style="padding:6px;"><b>Hủy tại chỗ (&lt; 500 mét)</b></td>
                                    <td style="padding:6px;"><span class="badge badge-danger">REJECTED</span></td>
                                    <td style="padding:6px;">Tự động <b>Từ chối (0 VNĐ)</b> do KTV thực tế chưa xuất phát.</td>
                                </tr>
                            </table>

                            <h4>D. 3 Bài Toán Case Study Minh Họa Tính Tiền Thực Tế</h4>
                            <ul>
                                <li><b>Case 1 - Ca hành chính thông thường:</b> KTV đi sửa máy in tại Chi nhánh Đông Đô (cự ly GPS 16.4 km). Tiền xăng: 16.4 &times; 5.000 = 82.000đ; Phụ cấp: 50.000đ. ➔ <b>Tổng chi phí = 132.000 VNĐ</b> (Trạng thái: PENDING ➔ APPROVED).</li>
                                <li><b>Case 2 - Ứng cứu khẩn cấp ngoài giờ (Overtime 1.5x):</b> KTV xử lý sự cố server lúc 21:30 Thứ Bảy (cự ly 22.0 km). Tiền xăng: 22.0 &times; 5.000 = 110.000đ; Phụ cấp ngoài giờ: 50.000 &times; 1.5 = 75.000đ. ➔ <b>Tổng chi phí = 185.000 VNĐ</b>.</li>
                                <li><b>Case 3 - Sự cố hủy giữa đường (40% cự ly):</b> Lộ trình chuẩn 20.0 km, KTV đã đi được 8.0 km (40% &lt; 50%) thì khách tự xử lý xong. Áp dụng chính sách HALF_TRIP: Km tính = 20.0 &times; 50% = 10.0 km (50.000đ) + Phụ cấp hủy = 50.000 &times; 50% = 25.000đ. ➔ <b>Tổng chi phí = 75.000 VNĐ</b>.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "shift_schedule_presence_guide",
                    title: "6.3. Quy Định Phân Ca, Giám Sát Hiện Diện Online & Chế Tài Blacklist",
                    htmlContent: #"""

                            <h3>3. Quy Định Phân Ca, Giám Sát Hiện Diện Online &amp; Chế Tài Blacklist</h3>
                            <p>Quy trình tổ chức phân ca trực, kiểm soát hiện diện thời gian thực và chế tài kỷ luật đảm bảo tính liên tục của dịch vụ IT hiện trường theo chuẩn Saigon Co.op.</p>

                            <h4>A. Bảng Khung Giờ Các Ca Trực Chuẩn</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px; width:15%;">Mã Ca</td>
                                    <td style="padding:6px; width:25%;">Tên Ca Trực</td>
                                    <td style="padding:6px; width:25%;">Khung Giờ Quy Định</td>
                                    <td style="padding:6px; width:35%;">Đặc Thù &amp; Ghi Chú</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-primary">HC</span></td>
                                    <td style="padding:6px;"><b>Hành chính</b></td>
                                    <td style="padding:6px;">08:00 – 17:00</td>
                                    <td style="padding:6px;">Nghỉ trưa 12:00 – 13:00 (Thời lượng: 8 tiếng làm việc)</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-success">S (SHIFT_1)</span></td>
                                    <td style="padding:6px;"><b>Ca 1 (Sáng)</b></td>
                                    <td style="padding:6px;">07:00 – 15:00</td>
                                    <td style="padding:6px;">Trực hỗ trợ mở cửa siêu thị, quầy thu ngân sáng</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-warning">C (SHIFT_2)</span></td>
                                    <td style="padding:6px;"><b>Ca 2 (Chiều)</b></td>
                                    <td style="padding:6px;">14:00 – 22:00</td>
                                    <td style="padding:6px;">Trực hỗ trợ ca chiều và bàn giao đóng cửa siêu thị</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-purple">NIGHT</span></td>
                                    <td style="padding:6px;"><b>Ca 3 (Đêm)</b></td>
                                    <td style="padding:6px;">22:00 – 06:00 (+1)</td>
                                    <td style="padding:6px;">Bảo trì hệ thống, kiểm kê định kỳ, sự cố ban đêm</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-primary">TR</span></td>
                                    <td style="padding:6px;"><b>Trực hỗ trợ / Điều động</b></td>
                                    <td style="padding:6px;">Theo lịch phân công</td>
                                    <td style="padding:6px;">Trực tăng cường xử lý sự cố, khai trương điểm bán</td>
                                </tr>
                            </table>

                            <h4>B. Quy Định Dung Sai Đi Trễ, Về Sớm &amp; Bán Kính GPS</h4>
                            <ul>
                                <li><b>Dung sai đi trễ hợp lệ:</b> Tối đa <b>15 phút</b> (<code>maxCheckInLateMinutes = 15</code>). Điểm danh sau giờ bắt đầu ca + 15 phút sẽ tự động bị gắn nhãn <span class="badge badge-warning">Đi trễ (LATE)</span>.</li>
                                <li><b>Dung sai về sớm:</b> Check-out trước thời gian kết thúc ca được ghi nhận là <span class="badge badge-warning">Về sớm (EARLY)</span>.</li>
                                <li><b>Bán kính GPS hợp lệ:</b> Chấm công thành công khi nằm trong bán kính <b>250 mét</b> xung quanh đơn vị hoặc mốc tọa độ được phân công.</li>
                            </ul>

                            <h4>C. Giải Đáp Thắc Mắc: "Đi Làm Khi Chưa Kịp Phân Ca Trên Hệ Thống"</h4>
                            <div class="callout" style="border-left: 4px solid #0f766e; background-color: #f0fdfa;">
                                <p style="margin: 0 0 6px 0; font-weight: bold; color: #0f766e; font-size: 13.5px;">
                                    ❓ Nếu ngày đó Lãnh đạo chưa kịp sắp phân ca trên hệ thống mà nhân viên vẫn đi làm bình thường thì như thế nào? Ngày giờ công có được tính không? Có ảnh hưởng KPI không? Phân ca chỉ để xem có online trong ca để cảnh báo blacklist đúng không?
                                </p>
                                <p style="margin: 0 0 6px 0; font-weight: bold; color: #115e59;">TRẢ LỜI CHI TIẾT &amp; CHÍNH XÁC 100%:</p>
                                <ol style="margin: 0; padding-left: 20px; color: #134e4a;">
                                    <li style="margin-bottom: 4px;">
                                        <b>Ngày công và giờ công vẫn được tính đúng và đủ 100%:</b> KTV mở app, chủ động chọn ca thực tế đi làm (Sáng, Chiều, Đêm, Hành chính) và bấm Check-in bình thường. Bản ghi chấm công tự động mang cờ <code>isUnscheduled = true</code> (Đi làm ngoài lịch). Toàn bộ số giờ làm việc thực tế và phụ cấp công tác phí di chuyển vẫn được ghi nhận đầy đủ khi tính lương.
                                    </li>
                                    <li style="margin-bottom: 4px;">
                                        <b>Hoàn toàn KHÔNG bị ảnh hưởng đến KPI:</b> Điểm KPI ticket đo lường độc lập theo thời gian tiếp nhận và kết quả xử lý của từng ca sự cố thực tế trong tháng, hoàn toàn không phụ thuộc vào việc ngày đó có lịch phân ca trước hay không.
                                    </li>
                                    <li style="margin-bottom: 4px;">
                                        <b>Mục đích cốt lõi của việc Phân ca trên hệ thống:</b> Phân ca là điều kiện để kích hoạt công cụ <b>Giám sát hiện diện Online (PresenceMonitor)</b>. Hệ thống chỉ giám sát và quét kiểm tra trạng thái Online đối với những KTV <i>CÓ ca trực theo lịch phân công</i>.
                                        <br>&bull; Nếu có lịch ca mà không check-in hoặc offline &gt; 15 phút không xin phép thì hệ thống mới cảnh báo và đưa vào danh sách xem xét Blacklist.
                                        <br>&bull; Ngược lại, <b>nếu ngày đó CHƯA có lịch phân ca, hệ thống KHÔNG quét kiểm tra hiện diện</b>. Do đó, KTV đi làm chấm công đột xuất hoàn toàn yên tâm <b>không bao giờ bị cảnh báo hay bị đưa vào Blacklist</b>.
                                    </li>
                                </ol>
                            </div>

                            <h4>D. Cơ Chế Giám Sát Hiện Diện Online &amp; Chế Tài Blacklist</h4>
                            <p>Công cụ Presence Monitor hoạt động tự động trên cả ứng dụng Android và máy chủ Desktop:</p>
                            <ul>
                                <li><b>Quét trạng thái hiện diện:</b> Trong suốt khung giờ ca trực đã được phân công, hệ thống định kỳ kiểm tra heartbeat online của KTV.</li>
                                <li><b>Cảnh báo vi phạm:</b> Nếu KTV tự ý Offline hoặc không có tương tác quá <b>15 phút</b> mà không gửi đơn xin phép qua hệ thống, hệ thống sẽ:
                                    <br>&bull; Phát âm thanh giọng nói cảnh báo (TTS) trên Desktop của HelpDesk/Quản lý: <i>"Cảnh báo: Kỹ thuật viên đang vắng mặt trong ca trực!"</i>
                                    <br>&bull; Gửi thông báo nhắc nhở tức thì đến điện thoại của KTV.
                                    <br>&bull; Tự động ghi nhận bản ghi vi phạm vào danh mục <code>PresenceViolation</code>.
                                </li>
                                <li><b>Tiêu chuẩn đưa vào Danh Sách Cảnh Báo (Blacklist):</b>
                                    <br>&bull; Có từ <b>5 lần vi phạm Offline</b> trong ca trực / tháng.
                                    <br>&bull; Tự ý <b>bỏ ca trực không phép từ 2 lần/tháng</b> trở lên.
                                    <br>&bull; Tỷ lệ xử lý thành công tháng P2 &lt; 50% hoặc để tồn đọng sự cố nghiêm trọng (Critical) quá 24 giờ.
                                    <br>&bull; Gian lận vị trí định vị GPS chấm công hoặc nhờ người khác can thiệp vé.
                                </li>
                                <li><b>Chế tài xử lý kỷ luật:</b> KTV nằm trong Blacklist sẽ bị hạ một bậc xếp loại thi đua tháng (ví dụ từ Loại B xuống Loại C), trừ thưởng hiệu quả công việc và lập biên bản giải trình trước Hội đồng đánh giá.</li>
                            </ul>

                            <h4>E. Quy Chế Chấm Hết Ca, Nhắc Nhở Tan Ca &amp; Tăng Ca Ngoài Giờ (OT)</h4>
                            <ul>
                                <li><b>Cơ chế nhắc nhở tan ca tự động:</b> Khi chạm mốc kết thúc ca làm việc (và sau đó 12–15 phút nếu chưa chấm hết ca), ứng dụng QLTB tự động kích hoạt <b>thông báo đẩy Heads-Up, rung máy và chuông / giọng nói TTS tiếng Việt</b> nhắc nhở KTV mở ứng dụng bấm Check-out tan ca. Bấm vào thông báo sẽ mở trực tiếp màn hình Chấm công.</li>
                                <li><b>Trường hợp quên Check-out (không có việc ngoài ca):</b> Hệ thống chốt trần thời gian làm việc tối đa theo thời lượng ca chuẩn (8 tiếng cho ca HC, ca 1, ca 2, ca 3), trạng thái <code>NORMAL</code> (nhãn xanh <b>✅ Hoàn thành ca</b>), tránh sai lệch lạm phát giờ công. Sau <b>3.5 giờ</b> kể từ lúc tan ca, nếu KTV chưa check-out và không có ticket nào đang mở, hệ thống sẽ <b>tự động Auto Check-out</b> với ghi chú <code>[Hệ thống tự động chốt do quên check-out (HH:mm)]</code> để giải phóng trạng thái điểm danh cho ca tiếp theo.</li>
                                <li><b>Trường hợp được điều phối ticket / Xử lý sự cố ngoài ca (OT):</b> Sau giờ ca, nếu KTV đang xử lý ticket hoặc có ticket hoàn thành sau giờ ca, hệ thống ghi nhận <b>toàn bộ thời gian làm việc thực tế</b> đến khi check-out, đánh dấu trạng thái <code>OVERTIME</code> (nhãn cam đậm <b>🔥 Tăng ca ngoài giờ (OT)</b>), đồng thời KTV được tính phụ cấp tăng ca ngoài giờ (hệ số x1.5 / x2.0) theo đúng quy chế.</li>
                            </ul>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "7. Báo Cáo, Thống Kê & Đánh Giá KPI IT Chuẩn Mực",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "report_print_guide",
                    title: "7.1. Báo cáo Thống kê & Xuất PDF / In A4 Chuẩn Nghị Định 30",
                    htmlContent: #"""

                            <h3>1. Báo Cáo Thống Kê & Xuất Văn Bản In Ấn Chuyên Nghiệp</h3>
                            <p>QLTB trang bị hệ thống tạo biểu mẫu báo cáo chuẩn thể thức văn bản hành chính Việt Nam (Nghị định 30/2020/NĐ-CP).</p>

                            <h4>A. Các loại báo cáo thống kê</h4>
                            <ul>
                                <li><b>Thống kê Thiết bị:</b> Cơ cấu tài sản theo phòng ban, chủng loại, tình trạng hoạt động và giá trị tài sản.</li>
                                <li><b>Báo cáo Đánh giá Hài lòng (KPI):</b> Xếp hạng KTV, điểm sao trung bình, tỉ lệ hài lòng và chi tiết phản hồi của khách hàng.</li>
                                <li><b>Báo cáo Chấm công & Chi phí:</b> Bảng tổng hợp ngày công, số lần đi hiện trường, tổng quãng đường (km) và công tác phí.</li>
                            </ul>

                            <h4>B. Cấu hình Tiêu đề Báo cáo Hành chính</h4>
                            <ol>
                                <li>Nhấn nút <b>⚙️ Cấu hình tiêu đề</b> trên màn hình In ấn/Báo cáo.</li>
                                <li>Điền: <i>Tên Cơ quan Chủ quản, Tên Đơn vị, Số hiệu văn bản, Địa danh, Quốc hiệu tiêu ngữ</i>.</li>
                                <li>Cấu hình này tự động lưu và áp dụng cho toàn bộ các biểu mẫu in ấn của công ty.</li>
                            </ol>

                            <h4>C. Xem trước & Xuất PDF / In trực tiếp / Excel</h4>
                            <ul>
                                <li><b>Xem trước (Print Preview):</b> Kiểm tra văn bản trực tiếp trên màn hình trước khi in.</li>
                                <li><b>Xuất PDF chất lượng cao:</b> Hỗ trợ khổ giấy A4 Dọc (Portrait) và A4 Ngang (Landscape).</li>
                                <li><b>Xuất Excel (.xlsx):</b> Đầy đủ dữ liệu, căn lề và định dạng chuẩn văn phòng.</li>
                            </ul>
                        
"""#
                ),
                HelpArticle(
                    id: "kpi_sla_evaluation_policy",
                    title: "7.2. Quy Chuẩn Đánh Giá 5 Chỉ Tiêu KPI IT Tập Trung (Thông Báo 161/TB-LH)",
                    htmlContent: #"""

                            <h3>2. Hướng Dẫn Chấm Điểm 5 Chỉ Tiêu KPI IT Tập Trung</h3>
                            <p>Căn cứ văn bản chính thức <b>Thông báo số 161/TB-LH ngày 21/05/2026</b> của Phòng Công nghệ Thông tin và Chuyển đổi số và <b>Phụ lục Hướng dẫn chấm điểm KPI IT Tập trung</b> của Saigon Co.op, toàn bộ nhân sự IT được đánh giá trên thang điểm 100% qua 5 chỉ tiêu cụ thể.</p>

                            <h4>A. Công Thức Tổng Điểm KPI (Thang Điểm 100%)</h4>
                            <div class="callout">
                                <p style="margin:0; font-size:13.5px; font-weight:bold; color:#002a8f;">
                                    ĐIỂM KPI TỔNG KẾT (%) = (C1 &times; 20%) + (P1 &times; 20%) + (P2 &times; 40%) + (P3 &times; 10%) + (P4 &times; 10%)
                                </p>
                            </div>

                            <h4>B. Bảng Đặc Tả 5 Chỉ Tiêu KPI IT Tập Trung Chuẩn Hóa</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0;">
                                <tr style="background-color:#f8fafc; font-weight:bold; color:#1e293b;">
                                    <td style="padding:6px; width:8%;">Mã</td>
                                    <td style="padding:6px; width:22%;">Tên Chỉ Tiêu</td>
                                    <td style="padding:6px; width:10%;">Tỷ Trọng</td>
                                    <td style="padding:6px; width:12%;">Kế Hoạch</td>
                                    <td style="padding:6px; width:24%;">Kỹ Thuật Viên (KTV)</td>
                                    <td style="padding:6px; width:24%;">Nhóm Trưởng (Leader)</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-purple">C1</span></td>
                                    <td style="padding:6px;"><b>Mức độ hài lòng CSAT</b></td>
                                    <td style="padding:6px;"><b>20%</b></td>
                                    <td style="padding:6px;">&ge; 90%</td>
                                    <td style="padding:6px;"><code>(CSAT cá nhân / 5.0) &times; 100</code><br><i>Tự động 5★ sau 24h</i></td>
                                    <td style="padding:6px;"><code>(CSAT toàn nhóm / 5.0) &times; 100</code></td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-primary">P1</span></td>
                                    <td style="padding:6px;"><b>Tỷ lệ phản hồi đúng hạn</b></td>
                                    <td style="padding:6px;"><b>20%</b></td>
                                    <td style="padding:6px;">&ge; 90%</td>
                                    <td style="padding:6px;">Phản hồi trong SLA (&le; 30 phút)<br><code>(Ticket đúng hạn / Tổng) &times; 100</code></td>
                                    <td style="padding:6px;"><code>60% cá nhân + 40% toàn nhóm</code></td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-success">P2</span></td>
                                    <td style="padding:6px;"><b>Tỷ lệ xử lý thành công</b></td>
                                    <td style="padding:6px;"><b>40%</b></td>
                                    <td style="padding:6px;">&ge; 90%</td>
                                    <td style="padding:6px;">Hệ số quy đổi (1.0 - 0.5 - 0.25 - 0.0)<br><code>(Tổng hệ số / Tổng) &times; 100</code></td>
                                    <td style="padding:6px;"><code>60% cá nhân + 40% toàn nhóm</code></td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-warning">P3</span></td>
                                    <td style="padding:6px;"><b>Đảm bảo mạng ổn định</b></td>
                                    <td style="padding:6px;"><b>10%</b></td>
                                    <td style="padding:6px;">0 sự việc</td>
                                    <td style="padding:6px;">Khởi điểm 100%, trừ 20%/lỗi cá nhân (-2.0đ tổng)</td>
                                    <td style="padding:6px;">Trừ 20% lỗi cá nhân (-2.0đ), trừ 10% lỗi nhóm (-1.0đ)</td>
                                </tr>
                                <tr>
                                    <td style="padding:6px;"><span class="badge badge-warning">P4</span></td>
                                    <td style="padding:6px;"><b>Đảm bảo vi tính ổn định</b></td>
                                    <td style="padding:6px;"><b>10%</b></td>
                                    <td style="padding:6px;">0 sự việc</td>
                                    <td style="padding:6px;">Khởi điểm 100%, trừ 20%/lỗi cá nhân (-2.0đ tổng)</td>
                                    <td style="padding:6px;">Trừ 20% lỗi cá nhân (-2.0đ), trừ 10% lỗi nhóm (-1.0đ)</td>
                                </tr>
                            </table>

                            <h4>C. Chi Tiết Các Quy Định Vàng Của Phụ Lục Chấm Điểm</h4>
                            <ul>
                                <li><b style="color:#b45309;">🌟 QUY TẮC TỰ ĐỘNG 24H ĐÓNG 5 SAO (CHỈ TIÊU C1):</b><br>
                                    <i>"Trường hợp người sử dụng không thực hiện đánh giá trong vòng 24 giờ kể từ thời điểm hoàn tất xử lý ticket và không phát sinh yêu cầu xử lý bổ sung hoặc xử lý lại, ticket sẽ được mặc định ghi nhận ở mức <b>'Rất hài lòng' (5 sao / 100%)</b> để phục vụ công tác tổng hợp và đánh giá KPI dịch vụ."</i><br>
                                    ➔ Đảm bảo quyền lợi tối đa cho KTV, không bị thiệt thòi khi người dùng bận việc quên bấm sao.
                                </li>
                                <li><b>BẢNG HỆ SỐ QUY ĐỔI KẾT QUẢ XỬ LÝ (CHỈ TIÊU P2):</b><br>
                                    &bull; <b>1.0:</b> Xử lý đúng hạn cam kết SLA và đạt chất lượng.<br>
                                    &bull; <b>0.5:</b> Đạt chất lượng &amp; Trễ hạn lần 1 (thời gian xử lý &le; 1.5 lần SLA).<br>
                                    &bull; <b>0.25:</b> Đạt chất lượng &amp; Trễ hạn lần 2 (thời gian xử lý &le; 2.5 lần SLA).<br>
                                    &bull; <b>0.0:</b> Trễ hạn lần 3 (&gt; 2.5 lần SLA) HOẶC Không đạt chất lượng (bị Reopen).<br>
                                    &bull; <b>1.0 (Miễn trừ):</b> Các trường hợp khách quan (đứt cáp ISP, chờ nhà cung cấp phần mềm, chờ linh kiện thay thế đặc thù có phê duyệt).
                                </li>
                                <li><b>THỜI GIAN THEO DÕI CHẤT LƯỢNG KHÔNG BỊ REOPEN:</b><br>
                                    <i>Critical:</i> 72 – 120 giờ; <i>High:</i> 72 giờ; <i>Medium:</i> 48 giờ; <i>Low:</i> 24 giờ.
                                </li>
                                <li><b>DANH MỤC LỖI MẠNG (P3) &amp; LỖI VI TÍNH (P4) CHỦ QUAN:</b><br>
                                    &bull; <i>Lỗi mạng (P3):</i> Mất kết nối WAN không liên hệ ISP; tự ý can thiệp sai thiết bị LAN/WAN; xử lý sai nguyên nhân sự cố; tự ý can thiệp sai dịch vụ server; không bảo trì định kỳ hệ thống mạng; không cập nhật sơ đồ mạng.<br>
                                    &bull; <i>Lỗi vi tính (P4):</i> Không tuân thủ bảo trì định kỳ PC/ngoại vi; thiết bị lỗi lặp lại nhưng không có hướng đề xuất xử lý; không tuân thủ quy trình mua sắm/cải tạo; chậm phản hồi đề xuất đơn vị; không sao lưu định kỳ HĐH/cấu hình; không kiểm tra kết quả sao lưu dữ liệu; hồ sơ thiết bị thiếu sót.
                                </li>
                            </ul>

                            <h4>D. Bài Toán Ví Dụ Minh Họa Tính Điểm Thực Tế (Case Study)</h4>
                            <div style="background-color:#f0fdf4; border:1.5px solid #16a34a; border-radius:8px; padding:10px 14px; margin:8px 0;">
                                <b style="color:#166534; font-size:13px;">Ví dụ: KTV Nguyễn Văn A xử lý 50 ticket trong tháng</b>
                                <ul style="margin:4px 0 6px 0; padding-left:18px; font-size:12px;">
                                    <li><b>Chỉ tiêu P1:</b> 48 ticket phản hồi &le; 30 phút (2 ticket trễ) ➔ Điểm P1 = (48 / 50) &times; 100 = <b>96.0%</b> (Đóng góp: 96.0% &times; 0.20 = <b>19.20đ</b>).</li>
                                    <li><b>Chỉ tiêu P2:</b> 42 ticket đúng hạn (42&times;1.0) + 4 trễ L1 (4&times;0.5=2.0) + 2 trễ L2 (2&times;0.25=0.5) + 2 bị reopen (2&times;0.0) = 44.5 ticket quy đổi ➔ Điểm P2 = (44.5 / 50) &times; 100 = <b>89.0%</b> (Đóng góp: 89.0% &times; 0.40 = <b>35.60đ</b>).</li>
                                    <li><b>Chỉ tiêu C1:</b> 30 ticket đánh giá đạt 4.80★ + 20 ticket tự động 5.0★ sau 24h ➔ CSAT TB = 4.88★ ➔ Điểm C1 = (4.88 / 5.0) &times; 100 = <b>97.6%</b> (Đóng góp: 97.6% &times; 0.20 = <b>19.52đ</b>).</li>
                                    <li><b>Chỉ tiêu P3:</b> Không có sự cố mạng chủ quan ➔ <b>100%</b> (Đóng góp: 100% &times; 0.10 = <b>10.00đ</b>).</li>
                                    <li><b>Chỉ tiêu P4:</b> 1 lỗi không kiểm tra sao lưu đơn vị ➔ Trừ 20% = <b>80%</b> (Đóng góp: 80% &times; 0.10 = <b>8.00đ</b>).</li>
                                </ul>
                                <div style="text-align:center; font-weight:bold; color:#002a8f; font-size:13px; border-top:1px dashed #86efac; padding-top:6px;">
                                    TỔNG ĐIỂM KPI = 19.20 + 35.60 + 19.52 + 10.00 + 8.00 = <span style="color:#dc2626; font-size:14px;">92.32%</span> (Quy đổi: 4.62 ⭐)
                                    <br><span class="badge badge-primary" style="font-size:11px; margin-top:3px;">XẾP LOẠI: B (HOÀN THÀNH TỐT NHIỆM VỤ)</span>
                                </div>
                            </div>

                            <h4>E. Thang Điểm Xếp Loại Thi Đua Tháng</h4>
                            <table border="1" cellpadding="6" cellspacing="0" style="width:100%; border-collapse:collapse; border:1px solid #cbd5e1; font-size:12px; margin:8px 0; text-align:center;">
                                <tr style="background-color:#f8fafc; font-weight:bold;">
                                    <td style="width:20%;">Khoảng Điểm KPI</td>
                                    <td style="width:15%;">Điểm Sao (⭐)</td>
                                    <td style="width:25%;">Xếp Loại Thi Đua</td>
                                    <td style="width:40%; text-align:left;">Chế Độ Khen Thưởng / Kỷ Luật</td>
                                </tr>
                                <tr style="background-color:#f0fdf4;">
                                    <td><b>Từ 95.0% trở lên</b></td>
                                    <td>4.75 – 5.00 ⭐</td>
                                    <td><span class="badge badge-success">LOẠI A (Xuất sắc)</span></td>
                                    <td style="text-align:left;">Hưởng 100% lương hiệu quả + thưởng thi đua tháng.</td>
                                </tr>
                                <tr>
                                    <td><b>Từ 85.0% đến 94.9%</b></td>
                                    <td>4.25 – 4.74 ⭐</td>
                                    <td><span class="badge badge-primary">LOẠI B (Hoàn thành tốt)</span></td>
                                    <td style="text-align:left;">Hưởng 100% lương hiệu quả theo quy chế.</td>
                                </tr>
                                <tr style="background-color:#fffbeb;">
                                    <td><b>Từ 70.0% đến 84.9%</b></td>
                                    <td>3.50 – 4.24 ⭐</td>
                                    <td><span class="badge badge-warning">LOẠI C (Đạt yêu cầu)</span></td>
                                    <td style="text-align:left;">Đạt yêu cầu; nhắc nhở cải thiện các ca trễ hạn.</td>
                                </tr>
                                <tr style="background-color:#fef2f2;">
                                    <td><b>Dưới 70.0%</b></td>
                                    <td>Dưới 3.50 ⭐</td>
                                    <td><span class="badge badge-danger">LOẠI D (Cần cải thiện)</span></td>
                                    <td style="text-align:left;">Chưa đạt; xem xét giảm lương hiệu quả và đào tạo lại.</td>
                                </tr>
                            </table>
                        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "8. Cài Đặt Hệ Thống, Bảo Trì & Sao Lưu",
            iconName: "gearshape.fill",
            defaultExpanded: false,
            articles: [
                HelpArticle(
                    id: "system_settings_guide",
                    title: "8.1. Thông tin Doanh nghiệp, Chế độ Bảo trì & Sao lưu Dữ liệu",
                    htmlContent: #"""

                            <h3>1. Cài Đặt Doanh Nghiệp, Chế Độ Bảo Trì & Đồng Bộ Đám Mây</h3>
                            <p>Tối ưu hóa và bảo vệ dữ liệu doanh nghiệp an toàn tuyệt đối.</p>

                            <h4>A. Thông tin Doanh nghiệp & Logo Thương hiệu</h4>
                            <ul>
                                <li>Vào <b>Cài đặt ➔ Thông tin Doanh nghiệp</b>.</li>
                                <li>Cập nhật Tên công ty, Địa chỉ trụ sở, Hotline, Email và tải lên <b>Logo chính thức</b>. Logo sẽ tự động xuất hiện trên tất cả biểu mẫu in ấn và báo cáo.</li>
                            </ul>

                            <h4>B. Chế độ Bảo trì Hệ thống (Maintenance Mode)</h4>
                            <ul>
                                <li>Khi cần nâng cấp cơ sở dữ liệu hoặc bảo trì định kỳ, Super Admin bật <b>Chế độ bảo trì</b> và nhập lời nhắn thông báo.</li>
                                <li>Toàn bộ nhân viên sẽ nhận được màn hình thông báo thân thiện và tạm dừng thao tác ghi dữ liệu.</li>
                                <li>Admin và Super Admin vẫn có toàn quyền thao tác để thực hiện kiểm thử và tắt bảo trì khi hoàn tất.</li>
                            </ul>

                            <h4>C. Cơ chế Đồng bộ Đám mây & SQLite Cục bộ</h4>
                            <ul>
                                <li>Hệ thống áp dụng kiến trúc <b>Offline-First</b> kết hợp <b>Cloud Firestore Sync</b>.</li>
                                <li>Dữ liệu được lưu trữ trên máy chủ đám mây thời gian thực, đồng thời lưu đệm trên SQLite cục bộ để đảm bảo tốc độ phản hồi tức thì và không bị gián đoạn khi mạng chập chờn.</li>
                            </ul>
                        
"""#
                )
            ]
        )
    ]
}