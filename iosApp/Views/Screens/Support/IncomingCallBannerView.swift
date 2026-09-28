import SwiftUI

// MARK: - INCOMING CALL BANNER / DIALOG VIEW FOR IOS (ĐỒNG BỘ 1:1 VỚI INCOMINGCALLACTIVITY TRÊN ANDROID)
public struct IncomingCallBannerView: View {
    let call: IncomingCallInfo
    let onAccept: () -> Void
    let onReject: () -> Void

    @State private var isPulsing: Bool = false

    public init(
        call: IncomingCallInfo,
        onAccept: @escaping () -> Void,
        onReject: @escaping () -> Void
    ) {
        self.call = call
        self.onAccept = onAccept
        self.onReject = onReject
    }

    public var body: some View {
        ZStack {
            // Nền tối mờ toàn màn hình
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Header thông tin cuộc gọi đến
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text("CUỘC GỌI NỘI BỘ ĐẾN")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                            .tracking(1.2)
                    }

                    Text(call.callerName.isEmpty ? "HelpDesk IT" : call.callerName)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    if !call.callerRole.isEmpty {
                        Text(call.callerRole)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if !call.callerEmail.isEmpty {
                        Text(call.callerEmail)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Avatar với hiệu ứng sóng âm reo chuông
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 3)
                        .frame(width: 160, height: 160)
                        .scaleEffect(isPulsing ? 1.25 : 0.95)
                        .opacity(isPulsing ? 0.0 : 0.8)

                    Circle()
                        .stroke(Color.green.opacity(0.5), lineWidth: 2)
                        .frame(width: 135, height: 135)
                        .scaleEffect(isPulsing ? 1.15 : 0.98)
                        .opacity(isPulsing ? 0.2 : 0.9)

                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 110, height: 110)
                        .shadow(color: .green.opacity(0.5), radius: 12, x: 0, y: 6)

                    Image(systemName: "phone.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isPulsing ? 15 : -15))
                }
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }

                Spacer()

                // Hai nút hành động: Từ chối & Bắt máy
                HStack(spacing: 48) {
                    // Nút Từ chối
                    VStack(spacing: 8) {
                        Button(action: onReject) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .red.opacity(0.5), radius: 8, x: 0, y: 4)

                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Text("Từ chối")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Nút Bắt máy
                    VStack(spacing: 8) {
                        Button(action: onAccept) {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 72, height: 72)
                                    .shadow(color: .green.opacity(0.6), radius: 10, x: 0, y: 4)

                                Image(systemName: "phone.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }

                        Text("Trả lời")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .zIndex(999)
    }
}
