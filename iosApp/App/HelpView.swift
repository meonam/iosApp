import SwiftUI
import SafariServices

// MARK: - MÀN HÌNH TRỢ GIÚP (HELP VIEW)
public struct HelpView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onBack: () -> Void

    @State private var selectedTabIndex: Int = 0 // 0: Tiếng Việt, 1: English
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
                        Color.clear.frame(height: geometry.safeAreaInsets.top)

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

                            Text(selectedArticle != nil ? (selectedTabIndex == 0 ? selectedArticle!.titleVi : selectedArticle!.titleEn) : (selectedTabIndex == 0 ? "Trợ Giúp & Hướng Dẫn" : "Help & Support"))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)

                        if selectedArticle == nil {
                            HStack(spacing: 0) {
                                TabButton(title: "Tiếng Việt", isSelected: selectedTabIndex == 0) { selectedTabIndex = 0 }
                                TabButton(title: "English", isSelected: selectedTabIndex == 1) { selectedTabIndex = 1 }
                            }
                        }
                    }
                    .background(Color.appPrimary)

                    // CONTENT
                    if let article = selectedArticle {
                        WebView(htmlContent: selectedTabIndex == 0 ? article.htmlContentVi : article.htmlContentEn)
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Header Card
                                HStack {
                                    Image(systemName: "book.pages")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color.appPrimary)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(selectedTabIndex == 0 ? "TÀI LIỆU HƯỚNG DẪN" : "USER MANUAL")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(Color.appPrimary)
                                        Text(selectedTabIndex == 0 ? "Chọn chuyên mục bên dưới để xem hướng dẫn chi tiết" : "Select a category below to see detailed instructions")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

                                // Categories
                                ForEach(categories, id: \.titleVi) { category in
                                    let isExpanded = expandedCategories[category.titleVi] ?? category.defaultExpanded
                                    
                                    VStack(spacing: 0) {
                                        Button(action: {
                                            expandedCategories[category.titleVi] = !isExpanded
                                        }) {
                                            HStack {
                                                Image(systemName: category.iconName)
                                                    .foregroundColor(Color.appPrimary)
                                                    .frame(width: 24, height: 24)
                                                
                                                Text(selectedTabIndex == 0 ? category.titleVi : category.titleEn)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.black)
                                                
                                                Spacer()
                                                
                                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(16)
                                        }
                                        
                                        if isExpanded {
                                            Divider().padding(.horizontal, 16)
                                            VStack(spacing: 8) {
                                                ForEach(category.articles, id: \.id) { article in
                                                    Button(action: { selectedArticle = article }) {
                                                        HStack {
                                                            Text(selectedTabIndex == 0 ? article.titleVi : article.titleEn)
                                                                .font(.system(size: 13, weight: .medium))
                                                                .foregroundColor(Color(hex: "0369A1"))
                                                            Spacer()
                                                            Image(systemName: "chevron.right")
                                                                .font(.system(size: 12))
                                                                .foregroundColor(Color(hex: "0369A1"))
                                                        }
                                                        .padding(.vertical, 10)
                                                        .padding(.horizontal, 12)
                                                        .background(Color(hex: "F8FAFC"))
                                                        .cornerRadius(8)
                                                    }
                                                }
                                            }
                                            .padding(16)
                                        }
                                    }
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                                }

                                // Gửi phản hồi / Hỗ trợ
                                VStack(spacing: 12) {
                                    Button(action: {
                                        showFeedbackForm = true
                                    }) {
                                        HStack {
                                            Image(systemName: "envelope")
                                            Text(selectedTabIndex == 0 ? "Gửi phản hồi / Báo lỗi" : "Send Feedback / Report Bug")
                                                .font(.system(size: 14, weight: .bold))
                                            Spacer()
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white)
                                        .foregroundColor(Color.appPrimary)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 1)
                                    }

                                    Button(action: {
                                        if let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") { // Example video URL
                                            safariURL = url
                                            showSafari = true
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "play.rectangle")
                                            Text(selectedTabIndex == 0 ? "Video hướng dẫn" : "Video Tutorials")
                                                .font(.system(size: 14, weight: .bold))
                                            Spacer()
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.white)
                                        .foregroundColor(Color.red)
                                        .cornerRadius(12)
                                        .shadow(color: Color.black.opacity(0.05), radius: 1)
                                    }
                                    
                                    Text("App Version 1.0.0")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                }
                                .padding(.top, 8)
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

// MARK: - Tab Button Component
fileprivate struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .bold : .regular))
                    .foregroundColor(.white)
                
                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
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

// MARK: - Simple WebView for HTML Content
import WebKit

fileprivate struct WebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let htmlHeader = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">
            <style>
                body { font-family: -apple-system, sans-serif; padding: 14px; font-size: 14px; color: #333; line-height: 1.5; }
                h3 { color: #002a8f; border-bottom: 2px solid #002a8f; padding-bottom: 6px; }
            </style>
        </head>
        <body>
        """
        let htmlFooter = "</body></html>"
        uiView.loadHTMLString(htmlHeader + htmlContent + htmlFooter, baseURL: nil)
    }
}

// MARK: - Dummy Data Models
struct HelpArticle {
    let id: String
    let titleVi: String
    let titleEn: String
    let htmlContentVi: String
    let htmlContentEn: String
}

struct HelpCategory {
    let titleVi: String
    let titleEn: String
    let iconName: String
    let defaultExpanded: Bool
    let articles: [HelpArticle]
}

class HelpRepository {
    static func getHelpCategories() -> [HelpCategory] {
        return [
            HelpCategory(
                titleVi: "Chấm công", titleEn: "Attendance", iconName: "clock", defaultExpanded: true,
                articles: [
                    HelpArticle(id: "1", titleVi: "Hướng dẫn chấm công", titleEn: "How to check in", htmlContentVi: "<p>Nội dung hướng dẫn chấm công...</p>", htmlContentEn: "<p>Content for check in...</p>")
                ]
            ),
            HelpCategory(
                titleVi: "Thiết bị", titleEn: "Devices", iconName: "laptopcomputer", defaultExpanded: false,
                articles: [
                    HelpArticle(id: "2", titleVi: "Quản lý thiết bị", titleEn: "Device Management", htmlContentVi: "<p>Nội dung quản lý thiết bị...</p>", htmlContentEn: "<p>Device management content...</p>")
                ]
            ),
            HelpCategory(
                titleVi: "Hỗ trợ", titleEn: "Support", iconName: "person.2.headset", defaultExpanded: false,
                articles: []
            ),
            HelpCategory(
                titleVi: "Tài khoản", titleEn: "Account", iconName: "person.crop.circle", defaultExpanded: false,
                articles: []
            )
        ]
    }
}
