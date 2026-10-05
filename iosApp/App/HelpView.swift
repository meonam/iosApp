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
    @State private var selectedRoleFilter: String = "ALL"

    private let allCategories = HelpRepository.getHelpCategories()

    private var normRole: String {
        let r = (authViewModel.currentUser?.role ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch r {
        case "QUANLY", "PHONGBAN": return "MANAGER"
        case "KYTHUAT", "KYTHUATVIEN": return "TECH"
        case "CHUYENVIEN": return "SPECIALIST"
        case "NHANVIEN": return "STAFF"
        default: return r
        }
    }

    private var isAdminOrHelpdesk: Bool {
        return normRole == "ADMIN" || normRole == "HELPDESK"
    }

    private var filteredCategories: [HelpCategory] {
        if isAdminOrHelpdesk {
            if selectedRoleFilter == "ALL" {
                return allCategories
            }
            return allCategories.filter { cat in
                cat.targetRoles.isEmpty || cat.targetRoles.contains(selectedRoleFilter)
            }
        } else {
            return allCategories.filter { cat in
                cat.targetRoles.isEmpty || cat.targetRoles.contains(normRole)
            }
        }
    }

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
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "book.pages")
                                            .font(.system(size: 30))
                                            .foregroundColor(Color.appSecondaryDarkBlue)

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text("TÀI LIỆU HƯỚNG DẪN")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(Color.appTextPrimary)

                                                if !normRole.isEmpty {
                                                    let roleLabel: String = {
                                                        switch normRole {
                                                        case "ADMIN": return "Quản trị viên"
                                                        case "HELPDESK": return "HelpDesk"
                                                        case "MANAGER": return "Quản lý"
                                                        case "TECH": return "Kỹ thuật viên"
                                                        case "SPECIALIST": return "Chuyên viên"
                                                        case "STAFF": return "Nhân viên"
                                                        default: return normRole
                                                        }
                                                    }()
                                                    Text(roleLabel)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(Color.appSecondaryDarkBlue)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.appSecondaryDarkBlue.opacity(0.12))
                                                        .cornerRadius(4)
                                                }
                                            }

                                            Text(isAdminOrHelpdesk
                                                ? "Hướng dẫn vận hành toàn hệ thống (bấm lọc vai trò bên dưới)"
                                                : "Hướng dẫn được tối ưu cho vai trò của bạn")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.appTextSecondary)
                                        }
                                        Spacer()
                                    }

                                    // Lọc vai trò (chỉ hiển thị cho Admin / HelpDesk)
                                    if isAdminOrHelpdesk {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                let filterOptions: [(key: String, label: String)] = [
                                                    ("ALL", "Tất cả"),
                                                    ("STAFF", "Nhân viên"),
                                                    ("TECH", "Kỹ thuật viên"),
                                                    ("SPECIALIST", "Chuyên viên"),
                                                    ("HELPDESK", "HelpDesk"),
                                                    ("MANAGER", "Quản lý")
                                                ]
                                                ForEach(filterOptions, id: \.key) { opt in
                                                    let isSelected = selectedRoleFilter == opt.key
                                                    Button(action: {
                                                        selectedRoleFilter = opt.key
                                                    }) {
                                                        Text(opt.label)
                                                            .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                                            .foregroundColor(isSelected ? .white : Color.appTextPrimary)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 5)
                                                            .background(isSelected ? Color.appSecondaryDarkBlue : Color.appSurfaceVariant)
                                                            .cornerRadius(14)
                                                    }
                                                }
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                .padding(16)
                                .background(Color.appSurface)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appCardBorder, lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)

                                // Categories List
                                ForEach(filteredCategories) { category in
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

                                    Text("Phiên bản ứng dụng v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.3") (Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "123"))")
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
    public let targetRoles: [String]
    public let articles: [HelpArticle]

    public init(title: String, iconName: String, defaultExpanded: Bool = false, targetRoles: [String] = [], articles: [HelpArticle]) {
        self.title = title
        self.iconName = iconName
        self.defaultExpanded = defaultExpanded
        self.targetRoles = targetRoles
        self.articles = articles
    }
}

public class HelpRepository {
    public static func getHelpCategories() -> [HelpCategory] {
        return categoriesCache
    }

    private static let categoriesCache: [HelpCategory] = [
        HelpCategory(
            title: "0. Tổng Quan & Ma Trận Phân Quyền",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: true,
            targetRoles: [],
            articles: [
                HelpArticle(
                    id: "overview_roles",
                    title: "0.1. Ma Trận Quyền Hạn 4 Vai Trò Chính",
                    htmlContent: #"""

          <div style="border-left:5px solid #002a8f;padding-left:10px;margin-bottom:14px">
            <h3 style="margin:0;color:#002a8f;border:none;font-size:15px;font-weight:bold;text-transform:uppercase">MA TRẬN QUYỀN HẠN THEO VAI TRÒ — HỆ THỐNG IT SERVICE & ASSETS</h3>
            <p style="margin:4px 0 0;font-size:12px;color:#64748b">Mỗi vai trò có phạm vi quyền hạn riêng biệt, rõ ràng trên cả 4 nền tảng.</p>
          </div>

          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;margin-bottom:16px">
            <tr style="background:#f1f5f9">
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:12px;color:#002a8f;text-align:left">Vai Trò</th>
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:11.5px;color:#002a8f">Tạo phiếu HT</th>
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:11.5px;color:#002a8f">Điều phối</th>
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:11.5px;color:#002a8f">Nhận & Xử lý</th>
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:11.5px;color:#002a8f">Quản lý TB</th>
              <th style="padding:8px 10px;border:1px solid #cbd5e1;font-size:11.5px;color:#002a8f">Báo cáo</th>
            </tr>
            <tr>
              <td style="padding:7px 10px;border:1px solid #e2e8f0"><span style="display:inline-block;padding:2px 7px;background:#0369a1;color:#fff;font-size:11px;font-weight:bold;border-radius:3px">🎧 HelpDesk</span></td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Điều phối</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Chỉ xem</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Giới hạn</td>
            </tr>
            <tr style="background:#f8fafc">
              <td style="padding:7px 10px;border:1px solid #e2e8f0"><span style="display:inline-block;padding:2px 7px;background:#b45309;color:#fff;font-size:11px;font-weight:bold;border-radius:3px">🛠️ KTV</span></td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:11.5px;font-weight:bold">✗ KHÔNG</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Nhận & Xử lý</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Chỉ xem</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Cá nhân</td>
            </tr>
            <tr>
              <td style="padding:7px 10px;border:1px solid #e2e8f0"><span style="display:inline-block;padding:2px 7px;background:#7e22ce;color:#fff;font-size:11px;font-weight:bold;border-radius:3px">🔬 Chuyên Viên</span></td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:11.5px;font-weight:bold">✗ KHÔNG</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Nhận & Xử lý</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Chỉ xem</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">Cá nhân</td>
            </tr>
            <tr style="background:#f8fafc">
              <td style="padding:7px 10px;border:1px solid #e2e8f0"><span style="display:inline-block;padding:2px 7px;background:#0f766e;color:#fff;font-size:11px;font-weight:bold;border-radius:3px">🏢 Quản Lý</span></td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Có</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Có</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px">✓ Phòng ban</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px">✓ Phòng ban</td>
            </tr>
            <tr>
              <td style="padding:7px 10px;border:1px solid #e2e8f0"><span style="display:inline-block;padding:2px 7px;background:#e11d48;color:#fff;font-size:11px;font-weight:bold;border-radius:3px">👤 Nhân Viên</span></td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#16a34a;font-size:12px;font-weight:bold">✓ Có</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#64748b;font-size:12px">TB cá nhân</td>
              <td style="padding:7px 10px;border:1px solid #e2e8f0;text-align:center;color:#dc2626;font-size:12px">✗</td>
            </tr>
          </table>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ Quy tắc KTV & Chuyên viên:</b> Hai vai trò này <b>TUYỆT ĐỐI KHÔNG</b> được phép tạo phiếu hỗ trợ mới. Nút "+ Tạo yêu cầu" đã bị ẩn hoàn toàn trên tất cả 4 nền tảng.</div>

          <div style="border-left:5px solid #002a8f;padding-left:10px;margin:14px 0 10px">
            <h4 style="margin:0;color:#002a8f;font-size:12.5px;font-weight:bold;text-transform:uppercase">HỖ TRỢ THEO NỀN TẢNG</h4>
          </div>
          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse">
            <tr style="background:#f1f5f9">
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:11.5px;color:#002a8f">Vai Trò</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:11.5px;color:#16a34a">Android</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:11.5px;color:#555">iOS</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:11.5px;color:#0ea5e9">Web</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:11.5px;color:#7c3aed">Desktop</th>
            </tr>
            <tr><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11.5px;font-weight:bold">HelpDesk</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓</td></tr>
            <tr style="background:#f8fafc"><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11.5px;font-weight:bold">KTV / Chuyên viên</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#d97706;text-align:center">✓ Nhận xử lý</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#d97706;text-align:center">✓ Nhận xử lý</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#d97706;text-align:center">✓ Nhận xử lý</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#d97706;text-align:center">✓ Nhận xử lý</td></tr>
            <tr><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11.5px;font-weight:bold">Quản Lý (Manager)</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Đầy đủ</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Đầy đủ</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Đầy đủ</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Đầy đủ</td></tr>
            <tr style="background:#f8fafc"><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11.5px;font-weight:bold">Nhân viên (Staff)</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Tạo & Theo dõi</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Tạo & Theo dõi</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Tạo & Theo dõi</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:11px;color:#16a34a;text-align:center">✓ Tạo & Theo dõi</td></tr>
          </table>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "1. Đăng Nhập & Bảo Mật Tài Khoản",
            iconName: "building.2",
            defaultExpanded: true,
            targetRoles: [],
            articles: [
                HelpArticle(
                    id: "auth_login",
                    title: "1.1. Đăng nhập, Đổi mật khẩu & Quên mật khẩu",
                    htmlContent: #"""

          <h3>ĐĂNG NHẬP & BẢO MẬT TÀI KHOẢN</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>A. Đăng nhập</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhập Email & Mật khẩu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tài khoản gắn với Email công vụ được Admin cấp phát.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đăng nhập lần đầu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Hệ thống tự bật hộp thoại yêu cầu <b>đổi mật khẩu mới</b> (tối thiểu 6 ký tự) để đảm bảo bảo mật.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn ứng dụng</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5"><b>Android/iOS:</b> Mở App IT Service & Assets → Nhập thông tin → Đăng nhập.<br><b>Web:</b> Truy cập trình duyệt → Nhập Email & Mật khẩu.<br><b>Desktop:</b> Mở ứng dụng → Nhập thông tin → Đăng nhập.</div></div>
  </div>

          <h4>B. Quên mật khẩu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "Quên mật khẩu"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tại màn hình đăng nhập, bấm liên kết <b>Quên mật khẩu</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhập Email đăng ký</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Hệ thống gửi link đặt lại mật khẩu vào hộp thư.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đặt mật khẩu mới</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở Email → bấm link → đặt mật khẩu mới (tối thiểu 6 ký tự).</div></div>
  </div>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📌 Lưu ý:</b> Không chia sẻ mật khẩu. Mỗi tài khoản chỉ đăng nhập đồng thời trên 1 thiết bị.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "2. Hỗ Trợ Trực Tuyến — Nhân Viên (Staff)",
            iconName: "headphones",
            defaultExpanded: false,
            targetRoles: ["STAFF", "MANAGER"],
            articles: [
                HelpArticle(
                    id: "staff_ticket_android",
                    title: "2.1. Staff: Tạo phiếu báo hỏng trên Android",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — TẠO PHIẾU BÁO HỎNG TRÊN ANDROID</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span>

          <h4>Tạo phiếu hỗ trợ</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở mục Hỗ trợ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Thanh menu dưới → bấm biểu tượng <b>🎧 Hỗ trợ</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm nút "+ Tạo yêu cầu"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút màu xanh, góc trên bên phải.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn thiết bị gặp sự cố</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tìm kiếm hoặc chọn từ danh sách thiết bị được bàn giao cá nhân.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mô tả sự cố</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn <b>Danh mục lỗi</b>, <b>Mức độ ưu tiên</b> (Thấp / Trung / Cao / Khẩn cấp), nhập mô tả chi tiết.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đính kèm ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm 📷 Camera để chụp ảnh lỗi trực tiếp hoặc chọn từ thư viện (tối đa 5 ảnh).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">6</div>
    <div><b style="color:#0f172a;font-size:12.5px">Gửi phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Gửi yêu cầu]</b>. HelpDesk/Quản lý nhận thông báo ngay lập tức.</div></div>
  </div>

          <h4>Các trạng thái phiếu</h4>
          <ul>
            <li>🟡 <b>Chờ xử lý:</b> Phiếu vừa tạo, chờ HelpDesk điều phối.</li>
            <li>🔵 <b>Đã điều phối:</b> KTV đã được giao — có thể chat trực tiếp với KTV.</li>
            <li>🟣 <b>KTV đang di chuyển:</b> Bấm <b>🏍️ Theo dõi KTV</b> để xem lộ trình trên bản đồ.</li>
            <li>🟢 <b>Hoàn thành:</b> Sự cố được khắc phục — cần đánh giá 1–5 ⭐.</li>
          </ul>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>💡 Mẹo:</b> Nếu tự khắc phục được, bấm <b>"💡 Tôi đã tự xử lý xong"</b> để đóng phiếu nhanh — KTV không cần di chuyển.</div>
        
"""#
                ),
                HelpArticle(
                    id: "staff_ticket_ios",
                    title: "2.2. Staff: Tạo phiếu báo hỏng trên iOS",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — TẠO PHIẾU BÁO HỎNG TRÊN iOS</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span>

          <h4>Tạo phiếu trên iPhone / iPad</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Tab Hỗ trợ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm tab <b>"Hỗ Trợ"</b> trên thanh điều hướng dưới cùng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm nút "+"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút <b>+</b> màu xanh ở góc trên phải.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn thiết bị & Mô tả</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn thiết bị, danh mục lỗi, mức độ ưu tiên, nhập mô tả chi tiết.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đính kèm ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm biểu tượng Camera — iOS yêu cầu cấp quyền truy cập Camera & Thư viện ảnh lần đầu.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Gửi phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Gửi]</b>. Phiếu xuất hiện ngay trong danh sách của HelpDesk.</div></div>
  </div>

          <h4>Theo dõi KTV đang di chuyển</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu đang xử lý</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Vào danh sách phiếu → bấm phiếu đang có KTV được điều phối.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "🏍️ Theo dõi KTV"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bản đồ hiện lộ trình KTV di chuyển theo thời gian thực đến phòng bạn.</div></div>
  </div>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📱 iOS:</b> Đảm bảo cho phép App IT Service & Assets truy cập <b>Vị trí</b> và <b>Thông báo đẩy</b> để nhận cập nhật trạng thái phiếu.</div>
        
"""#
                ),
                HelpArticle(
                    id: "staff_ticket_web",
                    title: "2.3. Staff: Tạo phiếu báo hỏng trên Web",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — TẠO PHIẾU BÁO HỎNG TRÊN WEB</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span>

          <h4>Tạo phiếu trên trình duyệt</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Vào mục Hỗ trợ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Menu trái → <b>Hỗ trợ → Danh sách phiếu</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "+ Tạo phiếu"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút màu xanh, góc trên bên phải.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điền form</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn thiết bị, loại sự cố, mức ưu tiên, mô tả chi tiết.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Upload ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Kéo thả ảnh vào vùng Upload hoặc bấm chọn file (JPG/PNG, tối đa 5MB/ảnh).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Gửi</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Gửi yêu cầu]</b>.</div></div>
  </div>

          <h4>Theo dõi phiếu & Chat</h4>
          <ul>
            <li>Danh sách phiếu màu sắc trực quan: 🟡 Chờ | 🔵 Xử lý | 🟢 Hoàn thành | 🔴 Hủy.</li>
            <li>Bấm vào phiếu → xem chi tiết, chat và ảnh đính kèm.</li>
            <li>Khung chat realtime — không cần refresh trang.</li>
          </ul>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>💡 Mẹo Web:</b> Dùng ô tìm kiếm và bộ lọc Trạng thái để tìm nhanh phiếu cần xem.</div>
        
"""#
                ),
                HelpArticle(
                    id: "staff_ticket_desktop",
                    title: "2.4. Staff: Tạo phiếu báo hỏng trên Desktop",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — TẠO PHIẾU BÁO HỎNG TRÊN DESKTOP</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Tạo phiếu trên Desktop Windows</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở ứng dụng Desktop</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Double-click biểu tượng IT Service & Assets trên Desktop hoặc Start Menu.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Hỗ trợ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm mục <b>Hỗ trợ</b> trên thanh menu trái.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "+ Tạo yêu cầu"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm nút màu xanh, điền form sự cố.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đính kèm ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Kéo thả ảnh hoặc bấm Browse. Hỗ trợ đọc Barcode USB khi điền mã thiết bị.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Gửi phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Gửi]</b>. Desktop hiển thị toast xác nhận thành công.</div></div>
  </div>

          <h4>Lợi thế Desktop</h4>
          <ul>
            <li>Chạy nền liên tục — nhận thông báo dù đang làm việc ở app khác.</li>
            <li>Hỗ trợ đầu đọc Barcode/QR USB để điền mã thiết bị cực nhanh.</li>
            <li>In phiếu A4 trực tiếp từ ứng dụng.</li>
          </ul>
        
"""#
                ),
                HelpArticle(
                    id: "staff_rating",
                    title: "2.5. Staff: Đánh giá & Đóng phiếu (Tất cả nền tảng)",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — ĐÁNH GIÁ & ĐÓNG PHIẾU</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>A. Tự đóng phiếu khi sự cố đã khắc phục</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu đang chờ xử lý</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Trong danh sách phiếu, bấm vào phiếu cần đóng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "💡 Tôi đã tự xử lý xong"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Phiếu chuyển trạng thái Hủy. KTV không cần di chuyển nếu chưa xuất phát.</div></div>
  </div>

          <h4>B. Đánh giá sau khi KTV hoàn thành</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhận thông báo</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khi KTV bấm Hoàn thành, bạn nhận thông báo đẩy "Phiếu của bạn đã được xử lý xong".</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở form đánh giá</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm vào thông báo hoặc mở phiếu trong danh sách.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn số sao 1–5 ⭐</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm vào số sao tương ứng mức độ hài lòng của bạn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhập nhận xét & Gửi</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Gõ nhận xét bổ sung (tùy chọn) → bấm <b>[Gửi đánh giá]</b>.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⏰ Quy tắc 24h:</b> Nếu không đánh giá trong 24h sau khi phiếu hoàn thành, hệ thống tự động ghi nhận <b>5.0★</b> cho KTV.</div>
          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>🔒 Đánh giá bảo vệ:</b> Sau khi gửi, không thể chỉnh sửa lại để đảm bảo tính khách quan.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "3. Hỗ Trợ Trực Tuyến — KTV & Chuyên Viên",
            iconName: "bicycle",
            defaultExpanded: false,
            targetRoles: ["TECH", "SPECIALIST"],
            articles: [
                HelpArticle(
                    id: "ktv_android",
                    title: "3.1. KTV/Chuyên viên: Nhận & Xử lý phiếu trên Android",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — NHẬN & XỬ LÝ PHIẾU TRÊN ANDROID</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ QUAN TRỌNG:</b> KTV và Chuyên viên <b>TUYỆT ĐỐI KHÔNG</b> được tạo phiếu hỗ trợ mới. Nút "+ Tạo yêu cầu" đã bị ẩn trên Android.</div>

          <h4>A. Thiết lập thông báo (Làm ngay khi cài App)</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật thông báo đẩy</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Cài đặt điện thoại → Ứng dụng → IT Service & Assets → <b>Thông báo: Bật tất cả</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật giọng đọc TTS trong App</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">App → ⚙️ Settings → Thông báo → bật <b>Giọng đọc tiếng Việt</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cấp quyền Vị trí nền</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Cài đặt → Ứng dụng → IT Service & Assets → Vị trí → chọn <b>"Luôn cho phép"</b>.</div></div>
  </div>

          <h4>B. Nhận điều phối & Xử lý phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Khi có phiếu điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Điện thoại rung + âm thanh cảnh báo + <b>giọng đọc tiếng Việt 2 lần</b> nội dung sự cố (tên thiết bị, phòng, tầng).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm vào thông báo</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở trực tiếp phiếu được điều phối.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xác nhận tiếp nhận</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Tiếp nhận]</b> để xác nhận đã nhận lệnh điều phối.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chat với người dùng</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nhắn tin trong khung Chat. Ảnh lỗi có thể phóng to/thu nhỏ bằng 2 ngón tay.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bắt đầu di chuyển</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>🚀 "Bắt đầu di chuyển"</b> — GPS nền bật, vẽ lộ trình OSRM. Người dùng thấy bạn trên bản đồ.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">6</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đến nơi</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>📍 "Đã đến nơi"</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">7</div>
    <div><b style="color:#0f172a;font-size:12.5px">Hoàn thành sửa chữa</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>✅ "Hoàn thành"</b> → nhập ghi chú kết quả → Xác nhận. Người dùng nhận thông báo đánh giá.</div></div>
  </div>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📍 GPS nền:</b> Nếu chưa cấp quyền "Luôn cho phép vị trí", lộ trình sẽ không ghi chính xác khi tắt màn hình — ảnh hưởng công tác phí.</div>
        
"""#
                ),
                HelpArticle(
                    id: "ktv_ios",
                    title: "3.2. KTV/Chuyên viên: Nhận & Xử lý phiếu trên iOS",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — NHẬN & XỬ LÝ PHIẾU TRÊN iOS</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ QUAN TRỌNG:</b> Nút "+ Tạo yêu cầu" đã ẩn hoàn toàn trên iOS với vai trò KTV / Chuyên viên.</div>

          <h4>A. Thiết lập thông báo trên iOS (Bắt buộc)</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cho phép thông báo khi cài App</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khi App hỏi quyền → bấm <b>"Cho phép"</b>. Nếu bấm nhầm, vào <b>Cài đặt iPhone → IT Service & Assets → Thông báo → Bật tất cả</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật giọng đọc trong App</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">App → ⚙️ Settings → Thông báo → bật <b>Giọng đọc TTS</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cấp quyền Vị trí nền</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Cài đặt iPhone → IT Service & Assets → Vị trí → chọn <b>"Luôn luôn"</b>.</div></div>
  </div>

          <h4>B. Nhận & Xử lý phiếu trên iOS</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Khi được điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">iOS hiện banner thông báo + âm thanh + giọng đọc tiếng Việt 2 lần nội dung sự cố.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm banner thông báo, hoặc mở Tab Hỗ trợ → <b>Phiếu của tôi</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chat & Xem ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nhắn tin với người dùng. Vuốt xem ảnh, chụm/mở để phóng to.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bắt đầu di chuyển</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>🚀 "Bắt đầu di chuyển"</b>. Hệ thống gửi GPS, người dùng thấy lộ trình.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Hoàn thành</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm ✅ <b>Hoàn thành</b> → Nhập ghi chú → Xác nhận.</div></div>
  </div>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>🔔 Không nghe giọng đọc?</b> Kiểm tra công tắc im lặng bên hông iPhone. Chế độ Tập trung (Focus) có thể chặn thông báo.</div>
          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📍 GPS iOS:</b> Bắt buộc chọn "Luôn luôn" trong cài đặt vị trí để GPS ghi lộ trình ngay cả khi màn hình tắt.</div>
        
"""#
                ),
                HelpArticle(
                    id: "ktv_web",
                    title: "3.3. KTV/Chuyên viên: Nhận & Xử lý phiếu trên Web",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — NHẬN & XỬ LÝ PHIẾU TRÊN WEB</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ QUAN TRỌNG:</b> KTV và Chuyên viên <b>KHÔNG</b> thấy nút "+ Tạo phiếu" trên Web Portal.</div>

          <h4>A. Bật thông báo trình duyệt</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cho phép thông báo Web</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khi đăng nhập lần đầu, trình duyệt hỏi quyền thông báo → bấm <b>Cho phép</b>. Nếu bỏ qua, bấm biểu tượng 🔒 trên thanh URL → Thông báo → Cho phép.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật giọng đọc TTS</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm biểu tượng 🔊 trên Header → bật <b>Giọng đọc TTS</b>.</div></div>
  </div>

          <h4>B. Nhận & Xử lý phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Khi được điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Trình duyệt hiện pop-up thông báo + âm thanh cảnh báo + giọng đọc nội dung phiếu.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm pop-up hoặc vào menu <b>Hỗ trợ → Phiếu của tôi</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chat & Xem ảnh</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khung chat realtime bên phải. Bấm ảnh → phóng to bằng Zoom/Pan.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cập nhật trạng thái</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm lần lượt: <b>Tiếp nhận → Bắt đầu di chuyển → Đã đến → Hoàn thành</b>.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>💡 Mẹo:</b> Ghim tab Web IT Service & Assets (chuột phải vào tab → Pin Tab) để luôn chạy nền và không bỏ lỡ thông báo.</div>
        
"""#
                ),
                HelpArticle(
                    id: "ktv_desktop",
                    title: "3.4. KTV/Chuyên viên: Nhận & Xử lý phiếu trên Desktop",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — NHẬN & XỬ LÝ PHIẾU TRÊN DESKTOP</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ QUAN TRỌNG:</b> Nút "+ Tạo yêu cầu" <b>KHÔNG</b> hiển thị cho KTV / Chuyên viên trên Desktop.</div>

          <h4>A. Thiết lập Desktop</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Khởi động App Desktop</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở IT Service & Assets Desktop. App chạy nền trong System Tray (góc phải taskbar).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật thông báo Windows</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Settings → Thông báo → bật <b>Thông báo hệ thống Windows</b> và <b>Âm thanh cảnh báo</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật giọng đọc TTS</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Settings → Giọng đọc → bật <b>TTS tiếng Việt</b>. Chọn chế độ <b>REPEAT</b> (lặp 30s) để không bỏ lỡ.</div></div>
  </div>

          <h4>B. Nhận & Xử lý phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Khi được điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Cửa sổ Desktop tự nổi lên + âm thanh cảnh báo + giọng đọc nội dung sự cố.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm thông báo Windows hoặc vào menu <b>Hỗ trợ</b> trong ứng dụng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xử lý & Chat</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khung chat, ảnh, các nút cập nhật trạng thái đầy đủ.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Hoàn thành</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm ✅ <b>Hoàn thành</b> → nhập ghi chú → xác nhận.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>🖥️ Ưu thế Desktop:</b> Chạy nền 24/7 — không bỏ lỡ lệnh điều phối kể cả khi đang dùng Microsoft Office hay ứng dụng khác.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "4. Hỗ Trợ Trực Tuyến — HelpDesk (Điều Phối Viên)",
            iconName: "headphones",
            defaultExpanded: false,
            targetRoles: ["HELPDESK"],
            articles: [
                HelpArticle(
                    id: "helpdesk_android",
                    title: "4.1. HelpDesk: Điều phối phiếu trên Android",
                    htmlContent: #"""

          <h3>HELPDESK — ĐIỀU PHỐI PHIẾU TRÊN ANDROID</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ Lưu ý:</b> HelpDesk <b>KHÔNG</b> được tạo phiếu hỗ trợ mới — chỉ điều phối và theo dõi tiến độ.</div>

          <h4>Màn hình chính HelpDesk</h4>
          <ul>
            <li>Dashboard tổng quan: Phiếu mới / Đang xử lý / Hoàn thành trong ngày.</li>
            <li>Nhận thông báo đẩy + giọng đọc khi có phiếu mới từ nhân viên.</li>
          </ul>

          <h4>Quy trình điều phối phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhận thông báo phiếu mới</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khi nhân viên tạo phiếu, HelpDesk nhận thông báo đẩy + âm thanh tức thì.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xem chi tiết phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm thông báo → đọc mô tả, xem ảnh hiện trường, xác định mức ưu tiên.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn KTV / Chuyên viên</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Điều phối]</b> → chọn từ danh sách KTV/Chuyên viên (hiển thị Online/Offline, số phiếu đang xử lý).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xác nhận điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Xác nhận]</b>. KTV được chọn nhận thông báo giọng nói 2 lần ngay lập tức.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Theo dõi tiến độ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Trạng thái cập nhật realtime: Điều phối → Di chuyển → Đã đến → Hoàn thành.</div></div>
  </div>

          <h4>Màn hình giám sát KTV</h4>
          <ul>
            <li>Bấm biểu tượng <b>📊 Giám sát KTV</b> để xem bảng tổng quan KTV đang hoạt động.</li>
            <li>Hiển thị: Tên KTV, trạng thái, số phiếu đang xử lý, vị trí GPS trên bản đồ.</li>
          </ul>
        
"""#
                ),
                HelpArticle(
                    id: "helpdesk_ios",
                    title: "4.2. HelpDesk: Điều phối phiếu trên iOS",
                    htmlContent: #"""

          <h3>HELPDESK — ĐIỀU PHỐI PHIẾU TRÊN iOS</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span>

          <div style="background:#fff1f2;border-left:4px solid #e11d48;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ Lưu ý:</b> Nút "+ Tạo yêu cầu" đã ẩn với role HelpDesk trên iOS.</div>

          <h4>Thiết lập thông báo HelpDesk trên iOS</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật thông báo đẩy</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Cài đặt iPhone → IT Service & Assets → Thông báo → bật <b>Cho phép thông báo</b>, <b>Âm thanh</b>, <b>Thông báo khóa màn hình</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bật giọng đọc</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">App → Settings → Thông báo → bật <b>Giọng đọc TTS</b>.</div></div>
  </div>

          <h4>Điều phối phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Tab Hỗ trợ → Danh sách Chờ điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Lọc phiếu trạng thái <b>Chờ xử lý</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở chi tiết phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm vào phiếu → xem mô tả, ảnh, chat lịch sử.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điều phối KTV/Chuyên viên</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>Điều phối</b> → chọn người phù hợp → Xác nhận.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Theo dõi trên Live Tracking</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tab <b>🗺️ Live Tracking</b>: xem bản đồ vị trí tất cả KTV đang hoạt động.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📱 Mẹo iOS:</b> Bật chế độ <b>Màn hình luôn bật</b> (iPhone Pro) để theo dõi dashboard liên tục mà không cần mở khóa.</div>
        
"""#
                ),
                HelpArticle(
                    id: "helpdesk_web",
                    title: "4.3. HelpDesk: Điều phối phiếu trên Web",
                    htmlContent: #"""

          <h3>HELPDESK — ĐIỀU PHỐI PHIẾU TRÊN WEB</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span>

          <h4>Bảng điều phối Web (đầy đủ nhất)</h4>
          <ul>
            <li>Menu → <b>Hỗ trợ → Danh sách phiếu</b>: Lọc theo Trạng thái, Ngày, Phòng ban, KTV.</li>
            <li>Màu sắc cột Trạng thái trực quan. Filter dropdown cho từng cột.</li>
          </ul>

          <h4>Quy trình điều phối trên Web</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lọc phiếu "Chờ điều phối"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Dropdown Trạng thái → chọn <b>Chờ xử lý</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm vào phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Panel chi tiết mở bên phải (split view) — không cần rời khỏi trang.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn KTV/Chuyên viên</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Dropdown <b>Điều phối cho</b> → gõ tên tìm kiếm. KTV Online được ưu tiên đầu danh sách.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xác nhận</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Xác nhận điều phối]</b>. Phiếu chuyển màu xanh — Đang xử lý.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Theo dõi Live</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút 🗺️ <b>Live Tracking</b> mở bản đồ realtime tất cả KTV.</div></div>
  </div>

          <h4>Dashboard thống kê HelpDesk</h4>
          <ul>
            <li>Widget: Phiếu hôm nay / Tổng tháng / % SLA đúng hạn.</li>
            <li>Biểu đồ phân bố phiếu theo giờ, KTV, phòng ban.</li>
          </ul>
        
"""#
                ),
                HelpArticle(
                    id: "helpdesk_desktop",
                    title: "4.4. HelpDesk: Điều phối phiếu trên Desktop",
                    htmlContent: #"""

          <h3>HELPDESK — ĐIỀU PHỐI PHIẾU TRÊN DESKTOP</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Ưu điểm Desktop cho HelpDesk</h4>
          <ul>
            <li>Màn hình lớn, nhiều cột dữ liệu — phù hợp xử lý lượng phiếu lớn.</li>
            <li>Chạy nền 24/7 — không bỏ lỡ phiếu mới.</li>
            <li>In phiếu điều phối A4 trực tiếp từ ứng dụng.</li>
            <li>Chế độ giọng đọc REPEAT: lặp 30s cho đến khi HelpDesk mở phiếu.</li>
          </ul>

          <h4>Quy trình điều phối trên Desktop</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Hỗ trợ → Danh sách phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở ứng dụng, bấm <b>Hỗ trợ</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lọc & Tìm kiếm</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Thanh tìm kiếm + filter trạng thái, ngày, phòng ban.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Double-click phiếu → bấm <b>Điều phối</b> → chọn KTV.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">In phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>🖨️ In phiếu A4</b> để có bản in vật lý chuẩn NĐ 30.</div></div>
  </div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "5. Hỗ Trợ Trực Tuyến — Quản Lý (Manager)",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: false,
            targetRoles: ["MANAGER"],
            articles: [
                HelpArticle(
                    id: "manager_support_all",
                    title: "5.1. Quản lý: Tạo, Điều phối & Giám sát phiếu (Tất cả nền tảng)",
                    htmlContent: #"""

          <h3>QUẢN LÝ (MANAGER) — TẠO, ĐIỀU PHỐI & GIÁM SÁT PHIẾU</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Quyền hạn của Quản lý với phiếu hỗ trợ</h4>
          <ul>
            <li>✓ Tạo phiếu mới thay mặt nhân viên trong phòng ban.</li>
            <li>✓ Xem toàn bộ phiếu của phòng ban phụ trách.</li>
            <li>✓ Điều phối phiếu cho KTV/Chuyên viên.</li>
            <li>✓ Đóng hoặc Reopen phiếu (trong vòng 24h).</li>
            <li>✓ Xem thống kê KPI, biểu đồ đánh giá sao của phòng ban.</li>
          </ul>

          <h4>Tạo phiếu thay mặt nhân viên</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Truy cập Hỗ trợ → Tạo phiếu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Quản lý thấy nút <b>"+ Tạo yêu cầu"</b> trên tất cả nền tảng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn nhân viên báo cáo</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn đúng nhân viên trong phòng, thiết bị, mô tả và ảnh.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điều phối ngay (tùy chọn)</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Có thể điều phối ngay khi tạo hoặc để HelpDesk xử lý sau.</div></div>
  </div>

          <h4>Giám sát dashboard phòng ban</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Android/iOS</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Trang chủ → widget phiếu mới / đang xử lý / hoàn thành trong ngày.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Web/Desktop</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Dashboard đầy đủ với biểu đồ, bảng xếp hạng KPI KTV của phòng ban.</div></div>
  </div>

          <h4>Quy trình Reopen phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Trong vòng 24h sau khi phiếu hoàn thành</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở phiếu → bấm <b>[Mở lại phiếu]</b> nếu sự cố tái phát.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Sau 24h</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Phiếu bị khóa — cần tạo phiếu mới.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📊 Báo cáo KPI phòng ban:</b> Menu → <b>Báo cáo → KPI IT</b> → chọn khoảng thời gian. Hỗ trợ xuất Excel (.xlsx) và PDF A4 chuẩn NĐ 30.</div>
        
"""#
                ),
                HelpArticle(
                    id: "itil_flow",
                    title: "5.2. Quy Trình 6 Bước ITIL — Luồng Xử Lý Chuẩn",
                    htmlContent: #"""

          <h3>QUY TRÌNH 6 BƯỚC XỬ LÝ PHIẾU CHUẨN ITIL</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <div style="position:relative;padding-left:4px">
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">🟡 NHÂN VIÊN TẠO PHIẾU</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Staff chọn thiết bị, mô tả sự cố, đính kèm ảnh và gửi yêu cầu hỗ trợ.</div></div>
  </div>
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">🔵 HELPDESK / QUẢN LÝ TIẾP NHẬN</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">HelpDesk nhận thông báo tức thì, xem phiếu, đánh giá mức độ ưu tiên.</div></div>
  </div>
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">🟠 ĐIỀU PHỐI KTV / CHUYÊN VIÊN</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">HelpDesk chỉ định KTV/Chuyên viên phù hợp. KTV nghe giọng đọc cảnh báo 2 lần.</div></div>
  </div>
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">🟣 KTV DI CHUYỂN & XỬ LÝ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">KTV bấm Bắt đầu di chuyển — GPS bật nền, vẽ lộ trình OSRM. Nhân viên theo dõi live.</div></div>
  </div>
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">✅ KTV HOÀN THÀNH</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">KTV bấm Hoàn thành, nhập ghi chú kết quả. Công tác phí tự động tổng hợp theo GPS.</div></div>
  </div>
            <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">6</div>
    <div><b style="color:#0f172a;font-size:12.5px">⭐ NHÂN VIÊN ĐÁNH GIÁ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nhân viên chấm 1–5 sao trong 24h. Sau 24h hệ thống tự ghi nhận 5.0★.</div></div>
  </div>
          </div>

          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;margin-top:14px">
            <tr style="background:#f1f5f9">
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Mức ưu tiên</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">SLA cam kết</th>
            </tr>
            <tr><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px">🔴 Khẩn cấp</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">Tối đa 1 giờ</td></tr>
            <tr style="background:#f8fafc"><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px">🟠 Cao</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">Tối đa 4 giờ</td></tr>
            <tr><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px">🟡 Trung bình</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">Tối đa 8 giờ</td></tr>
            <tr style="background:#f8fafc"><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px">🟢 Thấp</td><td style="padding:6px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">Tối đa 24 giờ</td></tr>
          </table>
          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⏱ Vượt SLA:</b> Hệ thống tự động gửi cảnh báo lên Quản lý và HelpDesk khi phiếu chưa được xử lý đúng hạn.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "6. Quản Lý Thiết Bị — Quản Lý (Manager)",
            iconName: "laptopcomputer",
            defaultExpanded: false,
            targetRoles: ["MANAGER"],
            articles: [
                HelpArticle(
                    id: "manager_device_android",
                    title: "6.1. Manager: Thêm & Quản lý thiết bị trên Android",
                    htmlContent: #"""

          <h3>QUẢN LÝ — THÊM & QUẢN LÝ THIẾT BỊ TRÊN ANDROID</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span>

          <h4>Thêm thiết bị mới</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mục Thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Menu dưới → <b>Thiết bị</b> → bấm <b>+ Thêm thiết bị</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điền thông tin cơ bản</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tên thiết bị, Loại (hệ thống tự sinh mã: <code>MT_</code> máy tính, <code>LT_</code> laptop, <code>PR_</code> máy in, <code>PH_</code> điện thoại), Serial/Mã định danh.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cấu hình chi tiết</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">CPU, RAM, Ổ cứng, Màu sắc, Hãng, Model.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Gán phòng ban & người dùng</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn Phòng ban, Đơn vị, người đang giữ thiết bị trong phòng ban của bạn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Ngày mua & bảo hành</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nhập ngày mua, hạn bảo hành — hệ thống tự cảnh báo khi sắp hết hạn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">6</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lưu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Lưu thiết bị]</b>. QR Code tự động tạo.</div></div>
  </div>

          <h4>Quét QR nhanh</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm biểu tượng 📷 QR</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Màn hình danh sách → bấm icon Camera.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Quét tem QR trên thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Camera nhận dạng QR → hiện thông tin thiết bị tức thì.</div></div>
  </div>

          <h4>Phê duyệt nhân viên mới vào phòng ban</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Nhận thông báo trên Trang chủ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Khi có nhân viên đăng ký, nút <b>👥 Duyệt NV</b> xuất hiện kèm số lượng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Kiểm tra & Phê duyệt</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Vào danh sách chờ duyệt → bấm <b>[Phê duyệt]</b> → kích hoạt tài khoản.</div></div>
  </div>
        
"""#
                ),
                HelpArticle(
                    id: "manager_device_ios",
                    title: "6.2. Manager: Thêm & Quản lý thiết bị trên iOS",
                    htmlContent: #"""

          <h3>QUẢN LÝ — THÊM & QUẢN LÝ THIẾT BỊ TRÊN iOS</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span>

          <h4>Thêm thiết bị trên iOS</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Tab Thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chuyển sang tab <b>Thiết bị</b> trên thanh điều hướng dưới.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "+"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút + góc trên phải → Form thêm thiết bị.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điền thông tin</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tương tự Android. iOS hỗ trợ keyboard gợi ý thông minh.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Quét QR tích hợp</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm icon Camera → Camera iOS nhận dạng QR → tự điền thông tin serial.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lưu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>Lưu</b> góc trên phải. Đồng bộ Cloud ngay lập tức.</div></div>
  </div>

          <h4>Tìm kiếm & Lọc thiết bị</h4>
          <ul>
            <li>Thanh tìm kiếm trên cùng: nhập tên, serial, phòng ban.</li>
            <li>Filter theo Trạng thái: Đang dùng / Hỏng / Bảo trì / Thanh lý.</li>
            <li>Vuốt trái để xóa (chỉ Manager trở lên), vuốt phải để chỉnh sửa nhanh.</li>
          </ul>
        
"""#
                ),
                HelpArticle(
                    id: "manager_device_web",
                    title: "6.3. Manager: Thêm & Quản lý thiết bị trên Web",
                    htmlContent: #"""

          <h3>QUẢN LÝ — THÊM & QUẢN LÝ THIẾT BỊ TRÊN WEB</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span>

          <h4>Import hàng loạt bằng Excel</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Thiết bị → Import Excel</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Menu → Thiết bị → <b>Import Excel</b> → Tải file mẫu.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điền danh sách</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Điền đúng format trong file mẫu (tên, serial, loại, phòng ban).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Upload & Kiểm tra kết quả</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Upload file → xem số dòng thành công/lỗi → sửa và upload lại nếu cần.</div></div>
  </div>

          <h4>Thêm từng thiết bị</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Thiết bị → + Thêm</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>"+ Thêm thiết bị"</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Form 2 cột đầy đủ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Web có form chi tiết nhất, giao diện 2 cột trực quan.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Upload ảnh thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Kéo thả ảnh thực tế (JPG/PNG, tối đa 5MB).</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lưu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>[Lưu]</b>. QR và Barcode tự sinh.</div></div>
  </div>

          <h4>Xuất báo cáo kiểm kê</h4>
          <ul>
            <li>Chọn nhiều thiết bị → <b>Xuất Excel</b> — file .xlsx đầy đủ thông tin.</li>
            <li>Filter trước khi xuất: Phòng ban, Trạng thái, Loại thiết bị, Khoảng thời gian.</li>
          </ul>
        
"""#
                ),
                HelpArticle(
                    id: "manager_device_desktop",
                    title: "6.4. Manager: Thêm & Quản lý thiết bị trên Desktop",
                    htmlContent: #"""

          <h3>QUẢN LÝ — THÊM & QUẢN LÝ THIẾT BỊ TRÊN DESKTOP</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Lợi thế Desktop</h4>
          <ul>
            <li>Hỗ trợ <b>đầu đọc Barcode USB/Bluetooth</b> — quét mã tốc độ cao khi kiểm kê.</li>
            <li>In tem QR/Barcode trực tiếp qua máy in nhiệt USB.</li>
            <li>Hiển thị nhiều cột hơn trên màn hình rộng.</li>
          </ul>

          <h4>Thêm thiết bị với đầu đọc Barcode</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Thiết bị → Thêm mới</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>"+ Thêm thiết bị"</b> hoặc tổ hợp <code>Ctrl+N</code>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Đặt con trỏ vào ô Serial</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Click vào trường Serial/Mã định danh.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Quét Barcode bằng đầu đọc USB</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Đầu đọc tự điền mã vào ô — cực nhanh, không cần nhập tay.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Điền thông tin còn lại & Lưu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Loại thiết bị, phòng ban, người dùng → Lưu.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">In tem ngay</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>🖨️ In tem QR</b> để in tem dán lên thiết bị ngay sau khi tạo.</div></div>
  </div>

          <h4>Kiểm kê bằng đầu đọc Barcode</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Thiết bị → Kiểm kê → Bắt đầu quét</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở chế độ kiểm kê.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Quét lần lượt từng thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Hệ thống đánh dấu đã kiểm kê tự động.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xuất biên bản kiểm kê</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Sau khi quét xong → <b>Xuất báo cáo</b> ra Excel hoặc PDF A4.</div></div>
  </div>
        
"""#
                ),
                HelpArticle(
                    id: "device_lifecycle",
                    title: "6.5. Vòng đời thiết bị: Cấp phát, Luân chuyển & Thanh lý",
                    htmlContent: #"""

          <h3>VÒNG ĐỜI THIẾT BỊ — 6 GIAI ĐOẠN</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#002a8f;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">📦 GIAI ĐOẠN 1 — NHẬP KHO & ĐỊNH DANH</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Nhập thiết bị, hệ thống sinh mã loại chuẩn tự động (<code>MT_</code> máy tính, <code>LT_</code> laptop, <code>PR_</code> máy in). In tem QR/Barcode dán lên thiết bị.</div>
          </div>
          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#0f766e;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">📤 GIAI ĐOẠN 2 — CẤP PHÁT & BÀN GIAO</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Gán thiết bị cho người dùng. Hệ thống tự xuất <b>Biên bản bàn giao A4</b> chuẩn Nghị định 30 để ký tên.</div>
          </div>
          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#0369a1;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">🔄 GIAI ĐOẠN 3 — VẬN HÀNH & LUÂN CHUYỂN</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Cập nhật người dùng mới khi thiết bị chuyển giao. Toàn bộ lịch sử bàn giao được ghi lại.</div>
          </div>
          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#b45309;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">🔧 GIAI ĐOẠN 4 — BẢO DƯỠNG & SỬA CHỮA</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Lịch sử phiếu sự cố tự động gắn vào hồ sơ thiết bị. Xem lại tất cả lần báo hỏng, KTV xử lý, kết quả.</div>
          </div>
          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#6d28d9;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">📋 GIAI ĐOẠN 5 — KIỂM KÊ ĐỊNH KỲ</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Quét QR/Barcode hàng loạt bằng Mobile hoặc Desktop. Tự xác định thiết bị thiếu/dư và xuất biên bản.</div>
          </div>
          <div style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin:10px 0">
            <div style="background:#dc2626;color:#fff;padding:7px 12px;font-size:12px;font-weight:bold">♻️ GIAI ĐOẠN 6 — THANH LÝ & LƯU TRỮ</div>
            <div style="padding:9px 12px;font-size:12px;color:#334155;line-height:1.6">Đổi trạng thái sang <b>Đã thanh lý</b>. Thiết bị vẫn lưu trong hệ thống để tra cứu lịch sử — không bị xóa vĩnh viễn.</div>
          </div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "7. Quản Lý Thiết Bị — Nhân Viên & KTV (Chỉ Xem)",
            iconName: "laptopcomputer",
            defaultExpanded: false,
            targetRoles: ["STAFF", "TECH", "SPECIALIST"],
            articles: [
                HelpArticle(
                    id: "staff_device_view",
                    title: "7.1. Nhân viên: Xem thiết bị cá nhân được bàn giao",
                    htmlContent: #"""

          <h3>NHÂN VIÊN — XEM THIẾT BỊ ĐƯỢC BÀN GIAO CÁ NHÂN</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>
          <p>Nhân viên chỉ xem thiết bị cá nhân — <b>không thể thêm, sửa hoặc xóa</b>.</p>

          <h4>Cách truy cập danh sách thiết bị</h4>
          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse">
            <tr style="background:#f1f5f9"><th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Nền tảng</th><th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Cách truy cập</th></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px"><b>Android</b></td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Menu dưới → Tab <b>Thiết bị</b></td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px"><b>iOS</b></td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Tab bar → <b>Thiết bị</b></td></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px"><b>Web</b></td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Menu trái → <b>Thiết bị của tôi</b></td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px"><b>Desktop</b></td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Menu → <b>Thiết bị</b></td></tr>
          </table>

          <h4>Thông tin nhân viên được xem</h4>
          <ul>
            <li>Tên thiết bị, Loại, Serial/Mã định danh.</li>
            <li>Cấu hình: CPU, RAM, Ổ cứng, Màu sắc.</li>
            <li>Ngày bàn giao, Hạn bảo hành.</li>
            <li>Trạng thái hiện tại: Đang sử dụng / Đang bảo trì / Hỏng.</li>
            <li>Lịch sử phiếu sự cố liên quan đến thiết bị.</li>
          </ul>

          <h4>Báo hỏng nhanh từ hồ sơ thiết bị</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm vào thiết bị trong danh sách</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở hồ sơ chi tiết thiết bị.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "🔔 Báo hỏng"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Phiếu hỗ trợ mới tự động điền tên thiết bị — tiết kiệm thời gian.</div></div>
  </div>
        
"""#
                ),
                HelpArticle(
                    id: "ktv_device_view",
                    title: "7.2. KTV/Chuyên viên: Xem thông tin thiết bị khi xử lý phiếu",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — XEM THÔNG TIN THIẾT BỊ KHI XỬ LÝ</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>
          <p>KTV xem hồ sơ thiết bị từ trong phiếu đang xử lý — để chuẩn bị công cụ, linh kiện trước khi đến hiện trường.</p>

          <h4>Xem hồ sơ thiết bị từ phiếu</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở phiếu được điều phối</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm vào phiếu trong Phiếu của tôi.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm vào tên thiết bị</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Trong chi tiết phiếu, tên thiết bị là liên kết — bấm để xem hồ sơ đầy đủ.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xem tab Lịch sử sự cố</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Xem tất cả lần báo hỏng trước của thiết bị — giúp chẩn đoán nhanh hơn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xem cấu hình chi tiết</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">CPU, RAM, thông số kỹ thuật — chuẩn bị đúng linh kiện cần mang theo.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📋 Mẹo kỹ thuật:</b> Xem lịch sử sự cố giúp biết trước lỗi tái phát, tránh mất thời gian chẩn đoán lại tại hiện trường.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "8. In Tem QR/Barcode & Báo Cáo A4 (Manager)",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: false,
            targetRoles: ["MANAGER"],
            articles: [
                HelpArticle(
                    id: "print_qr",
                    title: "8.1. In tem QR Code & Barcode dán thiết bị",
                    htmlContent: #"""

          <h3>IN TEM QR CODE & BARCODE — QUẢN LÝ</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>
          <p>Tính năng in tem chỉ trên <b>Web</b> và <b>Desktop</b>. Mobile App hỗ trợ quét nhưng không in.</p>

          <h4>Các loại tem hỗ trợ</h4>
          <ul>
            <li><b>Tem nhiệt cuộn 50×30mm:</b> Phù hợp máy in nhiệt Xprinter, TSC.</li>
            <li><b>Tem nhỏ 35×22mm:</b> Dán thiết bị nhỏ (chuột, tai nghe, điện thoại).</li>
            <li><b>Tem lớn 70×40mm:</b> Server, UPS, màn hình lớn.</li>
            <li><b>Decal A4 Tomy:</b> In nhiều tem trên một tờ A4 (24 tem/tờ).</li>
          </ul>

          <h4>Cách in tem trên Web / Desktop</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn thiết bị cần in</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Tích chọn một hoặc nhiều thiết bị trong danh sách.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Bấm "🖨️ In tem QR/Barcode"</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Nút trên thanh công cụ.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn khổ tem</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn kích thước phù hợp máy in của bạn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Preview & In</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Xem trước bố cục → bấm <b>In</b> hoặc <b>Xuất PDF</b>.</div></div>
  </div>
        
"""#
                ),
                HelpArticle(
                    id: "print_a4",
                    title: "8.2. Xuất báo cáo & Biên bản A4 chuẩn Nghị định 30",
                    htmlContent: #"""

          <h3>XUẤT BÁO CÁO & BIÊN BẢN A4 CHUẨN NGHỊ ĐỊNH 30</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Các loại biên bản & báo cáo</h4>
          <ul>
            <li><b>Biên bản bàn giao thiết bị</b> — Tạo khi gán thiết bị cho người dùng.</li>
            <li><b>Phiếu hỗ trợ kỹ thuật</b> — Chi tiết sự cố, người xử lý, kết quả.</li>
            <li><b>Báo cáo kiểm kê thiết bị</b> — Danh sách theo phòng ban / kỳ kiểm kê.</li>
            <li><b>Bảng tổng hợp KPI KTV</b> — Xếp hạng KTV theo điểm đánh giá.</li>
            <li><b>Báo cáo công tác phí</b> — Km di chuyển, chi phí tổng hợp theo tháng.</li>
          </ul>

          <h4>Cách xuất báo cáo</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Báo cáo & In ấn</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn mục báo cáo cần xuất.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Lọc dữ liệu</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn khoảng thời gian, phòng ban, người dùng.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xuất PDF hoặc Excel</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>Xuất PDF</b> để in A4, hoặc <b>Xuất Excel</b> để có file .xlsx.</div></div>
  </div>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📋 Chuẩn NĐ 30:</b> Tất cả biên bản đều có đủ Quốc hiệu — Tiêu ngữ, tên cơ quan và 3 cấp chữ ký (Lãnh đạo / Trưởng bộ phận / Người lập) theo cấu hình của Manager.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "9. Chấm Công GPS & Công Tác Phí — KTV / Chuyên Viên",
            iconName: "location.fill",
            defaultExpanded: false,
            targetRoles: ["TECH", "SPECIALIST"],
            articles: [
                HelpArticle(
                    id: "attendance_guide",
                    title: "9.1. Chấm công GPS: Vào ca & Ra ca (Android / iOS)",
                    htmlContent: #"""

          <h3>CHẤM CÔNG GPS — VÀO CA & RA CA</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span>
          <p>Chỉ trên <b>Mobile (Android & iOS)</b> — xác nhận vị trí thực tế tại cơ quan bằng GPS.</p>

          <h4>4 ca làm việc chuẩn</h4>
          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse">
            <tr style="background:#f1f5f9"><th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Ca làm việc</th><th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Giờ làm</th></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Hành chính</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">08:00 — 17:00</td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Ca 1</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">07:00 — 15:00</td></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Ca 2</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">14:00 — 22:00</td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Ca 3 / Ca đêm</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">22:00 — 06:00</td></tr>
          </table>

          <h4>Cách chấm công</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Mở Chấm công</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Menu → <b>Chấm công</b>.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn ca làm việc</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Chọn đúng ca của ngày hôm nay.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Kiểm tra GPS</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Hệ thống tự kiểm tra khoảng cách đến cơ quan — phải trong bán kính GPS hợp lệ.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">4</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chấm công Vào ca</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm nút <b>✅ Chấm công Vào ca</b>. Hệ thống ghi nhận giờ và vị trí GPS.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">5</div>
    <div><b style="color:#0f172a;font-size:12.5px">Cuối ca: Chấm công Ra ca</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>✅ Chấm công Ra ca</b>. Hệ thống tự tính tổng giờ công.</div></div>
  </div>

          <h4>Nhắc nhở tan ca tự động</h4>
          <ul>
            <li><b>Trước 15 phút:</b> Điện thoại rung + thông báo nhắc nhở Check-out sắp tới.</li>
            <li><b>Đúng giờ tan ca:</b> Âm thanh + giọng đọc TTS nhắc nhở bấm Ra ca.</li>
          </ul>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>📍 GPS nền bắt buộc:</b> Cấp quyền <b>"Luôn cho phép vị trí"</b> để hệ thống ghi lộ trình công tác phí chính xác ngay cả khi tắt màn hình.</div>
        
"""#
                ),
                HelpArticle(
                    id: "travel_expense",
                    title: "9.2. Công tác phí: Cách tính & Xem báo cáo",
                    htmlContent: #"""

          <h3>CÔNG TÁC PHÍ — CÁCH TÍNH & XEM BÁO CÁO</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Công thức tính tự động</h4>
          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:11px 14px;margin:10px 0;border-radius:4px;font-size:12.5px;color:#0f172a">
            <b>Tổng chi phí = (Km GPS × 5.000đ) + (Phụ cấp ca × Hệ số ngoài giờ)</b><br>
            <ul style="margin:7px 0 0;padding-left:18px;font-size:12px;color:#334155">
              <li>Tiền xăng xe: <b>5.000đ/km</b> (tính theo GPS OSRM thực tế)</li>
              <li>Phụ cấp ca cơ bản: <b>50.000đ/chuyến</b></li>
              <li>Hệ số ngoài giờ: ×1.5 (tối / cuối tuần) | ×2.0 (ngày lễ)</li>
            </ul>
          </div>

          <h4>Quy tắc xử lý khi hủy chuyến</h4>
          <ul>
            <li>Đã di chuyển <b>≥ 50% quãng đường:</b> Hưởng <b>100%</b> công tác phí.</li>
            <li>Di chuyển <b>&lt; 50% quãng đường:</b> Áp dụng chính sách <b>HALF_TRIP (50% phí)</b>.</li>
            <li>Chưa xuất phát: <b>Không tính</b> công tác phí.</li>
          </ul>

          <h4>Xem & Xuất báo cáo công tác phí</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Chấm công → Công tác phí</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở màn hình tổng hợp công tác phí.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Chọn tháng cần xem</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Danh sách từng chuyến: ngày, địa điểm, km thực tế, chi phí.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xuất báo cáo</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Bấm <b>Xuất Excel</b> hoặc <b>Xuất PDF</b> để nộp phòng kế toán.</div></div>
  </div>

          <div style="background:#fffbeb;border-left:4px solid #f59e0b;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⚠️ Lưu ý:</b> GPS phải bật <b>Luôn luôn</b> trong cả chuyến đi. Nếu GPS bị tắt giữa chừng, km không được ghi đầy đủ và ảnh hưởng đến công tác phí.</div>
        
"""#
                )
            ]
        ),
        HelpCategory(
            title: "10. KPI IT & Đánh Giá Chất Lượng Dịch Vụ",
            iconName: "chart.bar.doc.horizontal",
            defaultExpanded: false,
            targetRoles: ["HELPDESK", "MANAGER"],
            articles: [
                HelpArticle(
                    id: "kpi_formula",
                    title: "10.1. Công thức KPI 5 chỉ tiêu — Quản lý & HelpDesk",
                    htmlContent: #"""

          <h3>CÔNG THỨC KPI IT — 5 CHỈ TIÊU CHUẨN (TB-LH 161)</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>
          <p>Áp dụng cho: <b>Quản lý (Manager)</b> và <b>HelpDesk</b> khi xem báo cáo đánh giá KTV.</p>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:11px 14px;margin:10px 0;border-radius:4px">
            <b>Điểm KPI (%) = (C1 × 20%) + (P1 × 20%) + (P2 × 40%) + (P3 × 10%) + (P4 × 10%)</b>
          </div>

          <table border="0" cellpadding="0" cellspacing="0" style="width:100%;border-collapse:collapse;margin:12px 0">
            <tr style="background:#f1f5f9">
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Ký hiệu</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Mô tả</th>
              <th style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;color:#002a8f">Trọng số</th>
            </tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">C1</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Tỷ lệ xử lý đúng hạn SLA</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold;color:#002a8f">20%</td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">P1</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Số phiếu hoàn thành trong kỳ</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold;color:#002a8f">20%</td></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">P2</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Điểm CSAT trung bình (1–5 sao)</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold;color:#002a8f">40%</td></tr>
            <tr style="background:#f8fafc"><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">P3</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Tỷ lệ phiếu không bị Reopen</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold;color:#002a8f">10%</td></tr>
            <tr><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold">P4</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px">Tỷ lệ chấm công đầy đủ trong kỳ</td><td style="padding:7px 10px;border:1px solid #e2e8f0;font-size:12px;font-weight:bold;color:#002a8f">10%</td></tr>
          </table>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>⏰ Quy tắc tự động 5 sao (24h):</b> Nếu nhân viên không đánh giá trong 24h sau khi phiếu hoàn thành, hệ thống tự ghi nhận <b>5.0★ (100%)</b> — bảo vệ KPI KTV khỏi sự trì hoãn đánh giá.</div>
        
"""#
                ),
                HelpArticle(
                    id: "ktv_kpi_view",
                    title: "10.2. KTV/Chuyên viên: Xem điểm KPI cá nhân",
                    htmlContent: #"""

          <h3>KTV / CHUYÊN VIÊN — XEM ĐIỂM KPI CÁ NHÂN</h3>
          <span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#3ddc84;color:#000">Android</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#555;color:#fff">iOS</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#0ea5e9;color:#fff">Web</span><span style="display:inline-block;padding:1px 7px;font-size:10px;font-weight:bold;border-radius:3px;margin-right:3px;background:#7c3aed;color:#fff">Desktop</span>

          <h4>Xem điểm KPI của mình</h4>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">1</div>
    <div><b style="color:#0f172a;font-size:12.5px">Menu → Báo cáo cá nhân hoặc Hồ sơ</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Mở mục Báo cáo hoặc bấm vào Avatar hồ sơ cá nhân.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">2</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xem điểm đánh giá</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Biểu đồ điểm sao CSAT theo tháng, số phiếu xử lý, tỷ lệ đúng hạn.</div></div>
  </div>
          <div style="display:flex;gap:10px;margin-bottom:9px;align-items:flex-start">
    <div style="min-width:24px;height:24px;border-radius:50%;background:#002a8f;color:#fff;font-size:11.5px;font-weight:bold;display:flex;align-items:center;justify-content:center;flex-shrink:0">3</div>
    <div><b style="color:#0f172a;font-size:12.5px">Xem nhận xét của nhân viên</b><div style="font-size:12px;color:#475569;margin-top:3px;line-height:1.5">Danh sách nhận xét kèm tên người gửi (nếu không ẩn danh).</div></div>
  </div>

          <h4>Yếu tố ảnh hưởng KPI của KTV</h4>
          <ul>
            <li>✓ Xử lý phiếu đúng hạn SLA → tăng điểm C1.</li>
            <li>✓ Nhân viên đánh giá cao (4–5 sao) → tăng điểm P2 (trọng số cao nhất 40%).</li>
            <li>✓ Phiếu không bị Reopen (xử lý đúng từ đầu) → tăng điểm P3.</li>
            <li>✓ Chấm công đầy đủ mỗi ngày → tăng điểm P4.</li>
            <li>✗ Nhân viên đánh giá thấp (1–2 sao) → giảm điểm P2 đáng kể.</li>
          </ul>

          <div style="background:#f0f9ff;border-left:4px solid #0284c7;padding:9px 13px;margin:10px 0;border-radius:4px;font-size:12px;color:#334155;line-height:1.5"><b>💡 Mẹo nâng cao KPI:</b> Chat với nhân viên ngay sau khi nhận phiếu, cập nhật trạng thái thường xuyên, và xử lý triệt để để tránh phiếu bị Reopen.</div>
        
"""#
                )
            ]
        )
    ]
}
