import Foundation
import WebRTC
import Combine
import SwiftUI
import AVFoundation

public enum CallState {
    case idle
    case calling
    case incoming
    case connected
    case ended
}

public class WebRtcCallManager: NSObject, ObservableObject {
    public static let shared = WebRtcCallManager()
    
    @Published public var callState: CallState = .idle
    @Published public var isMuted: Bool = false
    @Published public var isSpeakerOn: Bool = true
    @Published public var remoteUserName: String = ""
    @Published public var remoteUserEmail: String = ""
    @Published public var currentCallId: String? = nil
    
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    
    // Mặc định nạp sẵn STUN của Google & TURN Metered dự phòng (đồng bộ 1:1 Android)
    private var iceServers: [RTCIceServer] = [
        RTCIceServer(urlStrings: [
            "stun:stun.l.google.com:19302",
            "stun:stun1.l.google.com:19302",
            "stun:stun2.l.google.com:19302",
            "stun:stun3.l.google.com:19302",
            "stun:stun4.l.google.com:19302"
        ]),
        RTCIceServer(
            urlStrings: [
                "turn:global.relay.metered.ca:80",
                "turn:global.relay.metered.ca:80?transport=tcp",
                "turn:global.relay.metered.ca:443",
                "turns:global.relay.metered.ca:443?transport=tcp"
            ],
            username: "278a0280a1e018ea207a1f7d",
            credential: "qGneN028RkU9by65"
        )
    ]
    
    public var companyId: String = "SGCOOP"
    public var idToken: String = ""
    private let firestoreBaseUrl = FirebaseConfig.firestoreBaseUrl
    
    private var signalingTimer: AnyCancellable?
    private var isCaller: Bool = false
    private var processedCandidateIds: Set<String> = []
    
    private override init() {
        super.init()
        initWebRTC()
    }
    
    private func initWebRTC() {
        // 1. Khởi tạo SSL cho WebRTC
        RTCInitializeSSL()
        
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        
        // 2. Tải TURN động từ Metered API
        fetchIceServers()
    }
    
    private func fetchIceServers() {
        guard let url = URL(string: "https://sgcoop.metered.live/api/v1/turn/credentials?apiKey=0c0142caa7c19416eb65b713d658b7abe996") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    var servers: [RTCIceServer] = []
                    // Luôn giữ STUN Google ở đầu
                    servers.append(RTCIceServer(urlStrings: [
                        "stun:stun.l.google.com:19302",
                        "stun:stun1.l.google.com:19302"
                    ]))
                    for item in json {
                        if let urls = item["urls"] as? String {
                            let username = item["username"] as? String ?? ""
                            let credential = item["credential"] as? String ?? ""
                            servers.append(RTCIceServer(urlStrings: [urls], username: username, credential: credential))
                        } else if let urlsArray = item["urls"] as? [String] {
                            let username = item["username"] as? String ?? ""
                            let credential = item["credential"] as? String ?? ""
                            servers.append(RTCIceServer(urlStrings: urlsArray, username: username, credential: credential))
                        }
                    }
                    DispatchQueue.main.async {
                        self.iceServers = servers
                        print("[WebRtcCallManager] Loaded \(servers.count) ICE servers")
                    }
                }
            } catch {
                print("[WebRtcCallManager] Failed to parse ICE servers: \(error)")
            }
        }.resume()
    }
    
    // MARK: - AUDIO SESSION CONFIGURATION
    private func configureAudioForCall() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setCategory(
                AVAudioSession.Category.playAndRecord.rawValue,
                with: [.allowBluetooth, .defaultToSpeaker]
            )
            try rtcAudioSession.setMode(AVAudioSession.Mode.voiceChat.rawValue)
            try rtcAudioSession.setActive(true)
            self.isSpeakerOn = true
            print("[WebRtcCallManager] RTCAudioSession configured for voice chat (speaker default)")
        } catch {
            print("[WebRtcCallManager] RTCAudioSession error: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
    
    private func resetAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setActive(false)
        } catch {
            print("[WebRtcCallManager] Reset RTCAudioSession error: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
    
    // MARK: - PEER CONNECTION CREATION
    private func createPeerConnection() -> RTCPeerConnection? {
        configureAudioForCall()
        
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue]
        )
        
        guard let pc = peerConnectionFactory.peerConnection(with: config, constraints: constraints, delegate: self) else {
            print("[WebRtcCallManager] Failed to create peerConnection")
            return nil
        }
        
        let audioConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "googEchoCancellation": "true",
                "googAutoGainControl": "true",
                "googNoiseSuppression": "true",
                "googHighpassFilter": "true"
            ],
            optionalConstraints: nil
        )
        let audioSource = peerConnectionFactory.audioSource(with: audioConstraints)
        localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true
        
        if let track = localAudioTrack {
            pc.add(track, streamIds: ["ARDAMS"])
        }
        
        return pc
    }
    
    // MARK: - OUTBOUND CALL
    public func startCall(targetEmail: String, targetName: String, callerName: String, callerEmail: String) {
        self.remoteUserEmail = targetEmail
        self.remoteUserName = targetName
        self.isCaller = true
        self.callState = .calling
        self.currentCallId = UUID().uuidString.lowercased()
        self.processedCandidateIds.removeAll()
        
        self.peerConnection = createPeerConnection()
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": kRTCMediaConstraintsValueTrue,
                "OfferToReceiveVideo": kRTCMediaConstraintsValueFalse
            ],
            optionalConstraints: nil
        )
        
        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                print("[WebRtcCallManager] Error creating offer: \(String(describing: error))")
                return
            }
            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    print("[WebRtcCallManager] Error setting local description (offer): \(error)")
                    return
                }
                self.createCallDocument(sdp: sdp, targetEmail: targetEmail, callerName: callerName, callerEmail: callerEmail)
                self.startSignalingPolling()
            }
        }
    }
    
    // MARK: - ANSWER INBOUND CALL
    public func answerCall(callId: String, callerName: String, callerEmail: String, offerSdp: String? = nil) {
        self.currentCallId = callId
        self.remoteUserName = callerName
        self.remoteUserEmail = callerEmail
        self.isCaller = false
        self.callState = .connected
        self.processedCandidateIds.removeAll()
        
        self.peerConnection = createPeerConnection()
        
        if let directSdp = offerSdp, !directSdp.isEmpty {
            print("[WebRtcCallManager] Using direct Offer SDP from incoming call info")
            self.proceedAnswerWithOfferSdp(directSdp)
        } else {
            print("[WebRtcCallManager] Fetching Offer SDP from Firestore for call \(callId)")
            fetchCallDocument { [weak self] fetchedSdp in
                guard let self = self, let sdp = fetchedSdp, !sdp.isEmpty else {
                    print("[WebRtcCallManager] Could not find Offer SDP for call: \(callId)")
                    return
                }
                self.proceedAnswerWithOfferSdp(sdp)
            }
        }
    }
    
    private func proceedAnswerWithOfferSdp(_ sdp: String) {
        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        self.peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                print("[WebRtcCallManager] Error setting remote description (offer): \(error)")
                return
            }
            
            let constraints = RTCMediaConstraints(
                mandatoryConstraints: [
                    "OfferToReceiveAudio": kRTCMediaConstraintsValueTrue,
                    "OfferToReceiveVideo": kRTCMediaConstraintsValueFalse
                ],
                optionalConstraints: nil
            )
            
            self.peerConnection?.answer(for: constraints) { [weak self] answerSdp, error in
                guard let self = self else { return }
                if let error = error {
                    print("[WebRtcCallManager] Error creating answer: \(error)")
                    return
                }
                guard let answerSdp = answerSdp else { return }
                
                self.peerConnection?.setLocalDescription(answerSdp) { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        print("[WebRtcCallManager] Error setting local description (answer): \(error)")
                        return
                    }
                    print("[WebRtcCallManager] Answer SDP created, uploading to Firestore...")
                    self.updateCallWithAnswer(sdp: answerSdp)
                    self.startSignalingPolling()
                }
            }
        }
    }
    
    // MARK: - END CALL
    public func endCall() {
        self.peerConnection?.close()
        self.peerConnection = nil
        self.localAudioTrack = nil
        self.remoteAudioTrack = nil
        self.signalingTimer?.cancel()
        self.signalingTimer = nil
        self.processedCandidateIds.removeAll()
        
        if let callId = currentCallId {
            updateCallStateEnded(callId: callId)
        }
        
        resetAudioSession()
        
        DispatchQueue.main.async {
            self.callState = .ended
            self.currentCallId = nil
            self.isMuted = false
            self.isSpeakerOn = true
        }
    }
    
    public func toggleMute() {
        isMuted.toggle()
        localAudioTrack?.isEnabled = !isMuted
    }
    
    public func toggleSpeaker() {
        isSpeakerOn.toggle()
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        do {
            if isSpeakerOn {
                try rtcAudioSession.overrideOutputAudioPort(.speaker)
            } else {
                try rtcAudioSession.overrideOutputAudioPort(.none)
            }
        } catch {
            print("[WebRtcCallManager] Toggle speaker error: \(error)")
        }
        rtcAudioSession.unlockForConfiguration()
    }
    
    // MARK: - FIRESTORE REST API OPERATIONS
    private func createCallDocument(sdp: RTCSessionDescription, targetEmail: String, callerName: String, callerEmail: String) {
        guard let callId = currentCallId else { return }
        
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls?documentId=\(callId)"
        guard let url = URL(string: urlStr) else { return }
        
        let body: [String: Any] = [
            "fields": [
                "id": ["stringValue": callId],
                "callerEmail": ["stringValue": callerEmail],
                "callerName": ["stringValue": callerName],
                "callerRole": ["stringValue": "KTV"],
                "calleeEmail": ["stringValue": targetEmail],
                "targetEmail": ["stringValue": targetEmail],
                "companyId": ["stringValue": companyId],
                "offer": [
                    "mapValue": [
                        "fields": [
                            "type": ["stringValue": "offer"],
                            "sdp": ["stringValue": sdp.sdp]
                        ]
                    ]
                ],
                "status": ["stringValue": "RINGING"],
                "createdAt": ["integerValue": "\(Int64(Date().timeIntervalSince1970 * 1000))"]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, resp, err in
            if let http = resp as? HTTPURLResponse {
                print("[WebRtcCallManager] createCallDocument status: \(http.statusCode)")
            }
            if let err = err {
                print("[WebRtcCallManager] createCallDocument error: \(err)")
            }
        }.resume()
    }
    
    private func fetchCallDocument(completion: @escaping (String?) -> Void) {
        guard let callId = currentCallId else {
            completion(nil)
            return
        }
        
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)"
        guard let url = URL(string: urlStr) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else {
                completion(nil)
                return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let fields = json["fields"] as? [String: Any],
               let offer = fields["offer"] as? [String: Any],
               let mapValue = offer["mapValue"] as? [String: Any],
               let mapFields = mapValue["fields"] as? [String: Any],
               let sdpObj = mapFields["sdp"] as? [String: Any],
               let sdpString = sdpObj["stringValue"] as? String {
                completion(sdpString)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func updateCallWithAnswer(sdp: RTCSessionDescription) {
        guard let callId = currentCallId else { return }
        
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)?updateMask.fieldPaths=answer&updateMask.fieldPaths=status&updateMask.fieldPaths=acceptedAt"
        guard let url = URL(string: urlStr) else { return }
        
        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "CONNECTED"],
                "acceptedAt": ["integerValue": "\(now)"],
                "answer": [
                    "mapValue": [
                        "fields": [
                            "type": ["stringValue": "answer"],
                            "sdp": ["stringValue": sdp.sdp]
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { _, resp, err in
            if let http = resp as? HTTPURLResponse {
                print("[WebRtcCallManager] updateCallWithAnswer HTTP status: \(http.statusCode)")
            }
            if let err = err {
                print("[WebRtcCallManager] updateCallWithAnswer error: \(err)")
            }
        }.resume()
    }
    
    private func updateCallStateEnded(callId: String) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)?updateMask.fieldPaths=status&updateMask.fieldPaths=endedAt"
        guard let url = URL(string: urlStr) else { return }
        
        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "ENDED"],
                "endedAt": ["integerValue": "\(now)"]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func sendIceCandidate(_ candidate: RTCIceCandidate) {
        guard let callId = currentCallId else { return }
        let collection = isCaller ? "callerCandidates" : "calleeCandidates"
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)/\(collection)"
        guard let url = URL(string: urlStr) else { return }
        
        let body: [String: Any] = [
            "fields": [
                "sdpMid": ["stringValue": candidate.sdpMid ?? "0"],
                "sdpMLineIndex": ["integerValue": "\(candidate.sdpMLineIndex)"],
                "candidate": ["stringValue": candidate.sdp]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !idToken.isEmpty {
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    // MARK: - SIGNALING POLLING
    private func startSignalingPolling() {
        signalingTimer?.cancel()
        signalingTimer = Timer.publish(every: 1.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollSignaling()
            }
    }
    
    private func pollSignaling() {
        guard let callId = currentCallId else { return }
        
        // 1. Kiểm tra trạng thái cuộc gọi
        let callUrlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)"
        if let url = URL(string: callUrlStr) {
            var request = URLRequest(url: url)
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self = self, let data = data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let fields = json["fields"] as? [String: Any] {
                    
                    if let statusObj = fields["status"] as? [String: Any],
                       let status = statusObj["stringValue"] as? String {
                        let statusUpper = status.uppercased()
                        if statusUpper == "ENDED" || statusUpper == "CANCELLED" || statusUpper == "REJECTED" || statusUpper == "TIMEOUT" {
                            print("[WebRtcCallManager] Call terminated from remote: \(statusUpper)")
                            DispatchQueue.main.async {
                                self.endCall()
                            }
                            return
                        } else if (statusUpper == "CONNECTED" || statusUpper == "ACCEPTED") && self.callState != .connected {
                            DispatchQueue.main.async {
                                self.callState = .connected
                            }
                        }
                    }
                    
                    // Người gọi (Caller) nhận Answer SDP
                    if self.isCaller, self.peerConnection?.remoteDescription == nil,
                       let answer = fields["answer"] as? [String: Any],
                       let mapValue = answer["mapValue"] as? [String: Any],
                       let mapFields = mapValue["fields"] as? [String: Any],
                       let sdpObj = mapFields["sdp"] as? [String: Any],
                       let sdpString = sdpObj["stringValue"] as? String {
                        
                        let sessionDesc = RTCSessionDescription(type: .answer, sdp: sdpString)
                        self.peerConnection?.setRemoteDescription(sessionDesc) { error in
                            if let error = error {
                                print("[WebRtcCallManager] Error setting remote description (answer): \(error)")
                            } else {
                                print("[WebRtcCallManager] Caller remote description set successfully")
                            }
                        }
                    }
                }
            }.resume()
        }
        
        // 2. Trao đổi ứng viên mạng (ICE Candidates)
        let targetCollection = isCaller ? "calleeCandidates" : "callerCandidates"
        let candidatesUrlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls/\(callId)/\(targetCollection)"
        if let url = URL(string: candidatesUrlStr) {
            var request = URLRequest(url: url)
            if !idToken.isEmpty {
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            }
            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let self = self, let data = data else { return }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let documents = json["documents"] as? [[String: Any]] {
                    
                    for doc in documents {
                        guard let name = doc["name"] as? String else { continue }
                        let docId = name.components(separatedBy: "/").last ?? ""
                        if self.processedCandidateIds.contains(docId) { continue }
                        
                        if let fields = doc["fields"] as? [String: Any],
                           let sdpMidObj = fields["sdpMid"] as? [String: Any],
                           let sdpMid = sdpMidObj["stringValue"] as? String,
                           let candidateObj = fields["candidate"] as? [String: Any],
                           let candidateStr = candidateObj["stringValue"] as? String {
                            
                            var sdpMLineIndex: Int32 = 0
                            if let sdpMLineIndexObj = fields["sdpMLineIndex"] as? [String: Any] {
                                if let strVal = sdpMLineIndexObj["integerValue"] as? String, let val = Int32(strVal) {
                                    sdpMLineIndex = val
                                } else if let numVal = sdpMLineIndexObj["doubleValue"] as? Double {
                                    sdpMLineIndex = Int32(numVal)
                                }
                            }
                            
                            let candidate = RTCIceCandidate(sdp: candidateStr, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
                            self.peerConnection?.add(candidate)
                            self.processedCandidateIds.insert(docId)
                        }
                    }
                }
            }.resume()
        }
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRtcCallManager: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("[WebRtcCallManager] SignalingState changed: \(stateChanged.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("[WebRtcCallManager] didAdd stream: audioTracks=\(stream.audioTracks.count)")
        if let audioTrack = stream.audioTracks.first {
            self.remoteAudioTrack = audioTrack
            audioTrack.isEnabled = true
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("[WebRtcCallManager] didRemove stream")
    }
    
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("[WebRtcCallManager] IceConnectionState changed: \(newState.rawValue)")
        if newState == .connected || newState == .completed {
            DispatchQueue.main.async {
                self.callState = .connected
            }
        }
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("[WebRtcCallManager] IceGatheringState changed: \(newState.rawValue)")
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        sendIceCandidate(candidate)
    }
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
