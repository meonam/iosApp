import SwiftUI

// MARK: - MÀN HÌNH CHỜ PHÊ DUYỆT (ĐỒNG BỘ THEO ANDROID)
public struct PendingApprovalView: View {
    @ObservedObject var viewModel: AuthViewModel
    var onApproved: (String) -> Void
    var onLogout: () -> Void

    @State private var isChecking: Bool = false
    @State private var checkTimer: Timer? = nil

    public init(viewModel: AuthViewModel, onApproved: @escaping (String) -> Void, onLogout: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onApproved = onApproved
        self.onLogout = onLogout
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 16) {
                        Image(systemName: "hourglass.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.appPrimaryPink)
                            .padding(.bottom, 8)

                        Text("Tài khoản đang chờ phê duyệt")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.appSecondaryDarkBlue)
                            .multilineTextAlignment(.center)

                        Text("Admin của \(viewModel.currentCompanyId.isEmpty ? "công ty" : viewModel.currentCompanyId) sẽ xem xét yêu cầu của bạn. Vui lòng chờ thông báo.")
                            .font(.system(size: 14))
                            .foregroundColor(.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        if let email = viewModel.currentUser?.email {
                            Text("Email đăng ký: \(email)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                                .padding(.top, 8)
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 24)

                    VStack(spacing: 16) {
                        Button(action: checkStatus) {
                            HStack {
                                if isChecking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Kiểm tra trạng thái")
                                        .font(.system(size: 16, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.appPrimaryPink)
                            .cornerRadius(12)
                        }
                        .disabled(isChecking)

                        Button(action: onLogout) {
                            Text("Đăng xuất")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.appDanger)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.appDanger, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private func startTimer() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            checkStatus()
        }
    }

    private func stopTimer() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func checkStatus() {
        guard !isChecking, let user = viewModel.currentUser else { return }
        isChecking = true

        Task {
            let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(viewModel.currentCompanyId)/users/\(user.email)"
            guard let url = URL(string: urlStr) else {
                await MainActor.run { isChecking = false }
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(viewModel.currentIdToken)", forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {
                    
                    let status = FirestoreHelper.getString(fields["status"] as? [String: Any])
                    let role = FirestoreHelper.getString(fields["role"] as? [String: Any])

                    await MainActor.run {
                        isChecking = false
                        if status == "APPROVED" || status == "ACTIVE" {
                            stopTimer()
                            onApproved(role)
                        }
                    }
                } else {
                    await MainActor.run { isChecking = false }
                }
            } catch {
                await MainActor.run { isChecking = false }
            }
        }
    }
}
