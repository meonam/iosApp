import SwiftUI

public struct CallView: View {
    @ObservedObject var callManager = WebRtcCallManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var callDurationSeconds: Int = 0
    @State private var timerSubscription: Timer? = nil
    @State private var isPulsing: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Nền gradient tối chuẩn đàm thoại
            LinearGradient(
                colors: [Color(hex: "#0F172A"), Color(hex: "#1E293B"), Color(hex: "#090D16")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 36) {
                Spacer()
                
                // Tiêu đề & thời lượng cuộc gọi
                VStack(spacing: 12) {
                    Text(callManager.remoteUserName.isEmpty ? "HelpDesk IT" : callManager.remoteUserName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    if !callManager.remoteUserEmail.isEmpty {
                        Text(callManager.remoteUserEmail)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusIndicatorColor)
                            .frame(width: 10, height: 10)
                        
                        Text(statusDisplayTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(statusIndicatorColor)
                    }
                    .padding(.top, 4)
                }
                
                Spacer()
                
                // Avatar đàm thoại với vòng sóng âm
                ZStack {
                    if callManager.callState != .connected {
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                            .frame(width: 160, height: 160)
                            .scaleEffect(isPulsing ? 1.25 : 0.95)
                            .opacity(isPulsing ? 0.0 : 0.8)
                    }
                    
                    Circle()
                        .fill(callManager.callState == .connected ? Color(hex: "#059669") : Color(hex: "#1D4ED8"))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                        )
                        .shadow(color: (callManager.callState == .connected ? Color.green : Color.blue).opacity(0.5), radius: 16)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
                
                Spacer()
                
                // Bảng nút điều khiển: Mute, Cúp máy, Speaker
                HStack(spacing: 36) {
                    // Nút Mute Micro
                    VStack(spacing: 8) {
                        Button(action: {
                            callManager.toggleMute()
                        }) {
                            Circle()
                                .fill(callManager.isMuted ? Color.white : Color.white.opacity(0.2))
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                        .font(.title2)
                                        .foregroundColor(callManager.isMuted ? .black : .white)
                                )
                        }
                        Text(callManager.isMuted ? "Đã tắt mic" : "Tắt mic")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Nút Kết thúc cuộc gọi (Đỏ)
                    VStack(spacing: 8) {
                        Button(action: {
                            callManager.endCall()
                            IncomingCallManager.shared.isCallPresented = false
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 76, height: 76)
                                .shadow(color: Color.red.opacity(0.5), radius: 10, x: 0, y: 4)
                                .overlay(
                                    Image(systemName: "phone.down.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                        }
                        Text("Kết thúc")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    // Nút Bật / Tắt Loa ngoài
                    VStack(spacing: 8) {
                        Button(action: {
                            callManager.toggleSpeaker()
                        }) {
                            Circle()
                                .fill(callManager.isSpeakerOn ? Color.white : Color.white.opacity(0.2))
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Image(systemName: callManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.1.fill")
                                        .font(.title2)
                                        .foregroundColor(callManager.isSpeakerOn ? .black : .white)
                                )
                        }
                        Text(callManager.isSpeakerOn ? "Loa ngoài" : "Loa trong")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            if callManager.callState == .connected {
                startTimer()
            }
        }
        .onDisappear {
            timerSubscription?.invalidate()
            timerSubscription = nil
        }
        .onReceive(callManager.$callState) { state in
            if state == .connected {
                startTimer()
            } else if state == .ended {
                timerSubscription?.invalidate()
                timerSubscription = nil
                IncomingCallManager.shared.isCallPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
    
    private func startTimer() {
        guard timerSubscription == nil else { return }
        callDurationSeconds = 0
        timerSubscription = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDurationSeconds += 1
        }
    }
    
    private var formattedDuration: String {
        let mins = callDurationSeconds / 60
        let secs = callDurationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    private var statusDisplayTitle: String {
        switch callManager.callState {
        case .calling:
            return "Đang gọi..."
        case .incoming:
            return "Cuộc gọi đến..."
        case .connected:
            return "Đang đàm thoại (\(formattedDuration))"
        case .ended:
            return "Cuộc gọi đã kết thúc"
        case .idle:
            return ""
        }
    }
    
    private var statusIndicatorColor: Color {
        switch callManager.callState {
        case .connected:
            return Color.green
        case .calling, .incoming:
            return Color(hex: "#38BDF8")
        case .ended:
            return Color(hex: "#F87171")
        case .idle:
            return Color.gray
        }
    }
}
