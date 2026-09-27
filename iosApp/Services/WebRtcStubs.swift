import Foundation
import Combine

enum CallState {
    case idle, calling, incoming, connected, ended
}

class WebRtcCallManager: ObservableObject {
    static let shared = WebRtcCallManager()
    private init() {}

    @Published var remoteUserName: String = ""
    @Published var callState: CallState = .idle
    @Published var isMuted: Bool = false
    @Published var isSpeakerOn: Bool = false

    func startCall(targetEmail: String, targetName: String, callerName: String, callerEmail: String) {
        remoteUserName = targetName
        callState = .calling
    }

    func endCall() {
        callState = .ended
    }

    func toggleMute() {
        isMuted.toggle()
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
    }
}
