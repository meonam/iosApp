import SwiftUI

public struct PendingApprovalView: View {
    @ObservedObject var authViewModel: AuthViewModel
    var onApproved: () -> Void
    var onLogout: () -> Void
    
    @State private var isChecking = false
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    public init(authViewModel: AuthViewModel, onApproved: @escaping () -> Void, onLogout: @escaping () -> Void) {
        self.authViewModel = authViewModel
        self.onApproved = onApproved
        self.onLogout = onLogout
    }
    
    public init(viewModel: AuthViewModel, onApproved: @escaping (String) -> Void, onLogout: @escaping () -> Void) {
        self.authViewModel = viewModel
        self.onApproved = { onApproved(viewModel.currentUser?.role ?? "STAFF") }
        self.onLogout = onLogout
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.safeAreaInsets.top)
                        topBar
                    }
                    .background(Color.appPrimary)
                    
                    Spacer()
                    
                    VStack(spacing: 24) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                        
                        Text("Đang chờ phê duyệt")
                            .font(.title2)
                            .bold()
                        
                        Text("Tài khoản của bạn đã được ghi nhận và đang chờ quản trị viên phê duyệt. Quá trình này có thể mất một khoảng thời gian.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 32)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Họ tên:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(authViewModel.currentUser?.fullName ?? "--")
                                    .bold()
                            }
                            HStack {
                                Text("Email:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(authViewModel.currentUser?.email ?? "--")
                                    .bold()
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                        
                        Text("Liên hệ admin: admin@sgcoop.com")
                            .font(.footnote)
                            .foregroundColor(.blue)
                        
                        if isChecking {
                            ProgressView("Đang kiểm tra trạng thái...")
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(action: checkApprovalStatus) {
                            Text("Làm mới")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appPrimary)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: onLogout) {
                            Text("Đăng xuất")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.red)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        }
                    }
                    .padding()
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
        .onAppear {
            checkApprovalStatus()
        }
        .onReceive(timer) { _ in
            checkApprovalStatus()
        }
    }
    
    private var topBar: some View {
        HStack {
            Spacer()
            Text("Chờ duyệt")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding()
    }
    
    private func checkApprovalStatus() {
        let companyId = authViewModel.currentUser?.companyId ?? ""
        let userId = authViewModel.currentUser?.id ?? ""
        let token = authViewModel.currentIdToken
        
        guard !companyId.isEmpty, !userId.isEmpty, !token.isEmpty else { return }
        
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(companyId)/users/\(userId)"
        guard let url = URL(string: urlStr) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        isChecking = true
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                DispatchQueue.main.async {
                    self.isChecking = false
                    if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let fields = json["fields"] as? [String: Any] {
                            let isApproved = FirestoreHelper.getBool(fields["isApproved"] as? [String: Any])
                            if isApproved {
                                self.onApproved()
                            }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isChecking = false
                }
            }
        }
    }
}
