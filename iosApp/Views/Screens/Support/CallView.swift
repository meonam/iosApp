import SwiftUI

public struct CallView: View {
    @ObservedObject var callManager = WebRtcCallManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // User Info
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.gray)
                    
                    Text(callManager.remoteUserName)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(statusText)
                        .font(.title3)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    // Mute
                    Button(action: {
                        callManager.toggleMute()
                    }) {
                        Circle()
                            .fill(callManager.isMuted ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.title)
                                    .foregroundColor(callManager.isMuted ? .black : .white)
                            )
                    }
                    
                    // End Call
                    Button(action: {
                        callManager.endCall()
                        IncomingCallManager.shared.isCallPresented = false
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: "phone.down.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Speaker
                    Button(action: {
                        callManager.toggleSpeaker()
                    }) {
                        Circle()
                            .fill(callManager.isSpeakerOn ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 70, height: 70)
                            .overlay(
                                Image(systemName: callManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                    .font(.title)
                                    .foregroundColor(callManager.isSpeakerOn ? .black : .white)
                            )
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onReceive(callManager.$callState) { state in
            if state == .ended {
                IncomingCallManager.shared.isCallPresented = false
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
    
    private var statusText: String {
        switch callManager.callState {
        case .calling: return "Calling..."
        case .incoming: return "Incoming Call..."
        case .connected: return "Connected"
        case .ended: return "Call Ended"
        case .idle: return ""
        }
    }
}
