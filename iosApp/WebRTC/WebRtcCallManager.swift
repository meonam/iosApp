import Foundation
import WebRTC
import Combine
import SwiftUI

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
    @Published public var isSpeakerOn: Bool = false
    @Published public var remoteUserName: String = ""
    @Published public var remoteUserEmail: String = ""
    @Published public var currentCallId: String? = nil
    
    private var peerConnectionFactory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var remoteAudioTrack: RTCAudioTrack?
    private var iceServers: [RTCIceServer] = []
    
    public var companyId: String = "SGCOOP"
    public var idToken: String = ""
    private let firestoreBaseUrl = FirebaseConfig.firestoreBaseUrl
    
    private var signalingTimer: AnyCancellable?
    private var isCaller: Bool = false
    
    private override init() {
        super.init()
        initWebRTC()
    }
    
    private func initWebRTC() {
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        peerConnectionFactory = RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
        
        // Fetch STUN/TURN
        fetchIceServers()
    }
    
    private func fetchIceServers() {
        guard let url = URL(string: "https://sgcoop.metered.live/api/v1/turn/credentials?apiKey=0c0142caa7c19416eb65b713d658b7abe996") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    var servers: [RTCIceServer] = []
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
                    self.iceServers = servers
                }
            } catch {
                print("Failed to parse ICE servers: \(error)")
            }
        }.resume()
    }
    
    private func createPeerConnection() -> RTCPeerConnection? {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.sdpSemantics = .unifiedPlan
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: ["DtlsSrtpKeyAgreement": kRTCMediaConstraintsValueTrue])
        
        let pc = peerConnectionFactory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        let audioSource = peerConnectionFactory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "audio0")
        
        if let pc = pc, let track = localAudioTrack {
            pc.add(track, streamIds: ["stream0"])
        }
        
        return pc
    }
    
    public func startCall(targetEmail: String, targetName: String, callerName: String, callerEmail: String) {
        self.remoteUserEmail = targetEmail
        self.remoteUserName = targetName
        self.isCaller = true
        self.callState = .calling
        self.currentCallId = UUID().uuidString.lowercased()
        
        self.peerConnection = createPeerConnection()
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": kRTCMediaConstraintsValueTrue], optionalConstraints: nil)
        
        peerConnection?.offer(for: constraints) { sdp, error in
            guard let sdp = sdp else { return }
            self.peerConnection?.setLocalDescription(sdp, completionHandler: { error in
                if error == nil {
                    self.createCallDocument(sdp: sdp, targetEmail: targetEmail, callerName: callerName, callerEmail: callerEmail)
                    self.startSignalingPolling()
                }
            })
        }
    }
    
    public func answerCall(callId: String, callerName: String, callerEmail: String) {
        self.currentCallId = callId
        self.remoteUserName = callerName
        self.remoteUserEmail = callerEmail
        self.isCaller = false
        self.callState = .connected
        
        self.peerConnection = createPeerConnection()
        
        // Fetch offer from Firestore and set Remote Description
        fetchCallDocument { offerSdp in
            guard let sdp = offerSdp else { return }
            let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)
            self.peerConnection?.setRemoteDescription(sessionDescription, completionHandler: { error in
                if error == nil {
                    let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": kRTCMediaConstraintsValueTrue], optionalConstraints: nil)
                    self.peerConnection?.answer(for: constraints, completionHandler: { answerSdp, error in
                        guard let answerSdp = answerSdp else { return }
                        self.peerConnection?.setLocalDescription(answerSdp, completionHandler: { error in
                            if error == nil {
                                self.updateCallWithAnswer(sdp: answerSdp)
                                self.startSignalingPolling()
                            }
                        })
                    })
                }
            })
        }
    }
    
    public func endCall() {
        self.peerConnection?.close()
        self.peerConnection = nil
        self.localAudioTrack = nil
        self.remoteAudioTrack = nil
        self.signalingTimer?.cancel()
        
        if let callId = currentCallId {
            updateCallStateEnded(callId: callId)
        }
        
        DispatchQueue.main.async {
            self.callState = .ended
            self.currentCallId = nil
            self.isMuted = false
            self.isSpeakerOn = false
        }
    }
    
    public func toggleMute() {
        isMuted.toggle()
        localAudioTrack?.isEnabled = !isMuted
    }
    
    public func toggleSpeaker() {
        isSpeakerOn.toggle()
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            if isSpeakerOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Failed to toggle speaker: \(error)")
        }
        #endif
    }
    
    // MARK: - Signaling logic with Firestore REST API
    private func createCallDocument(sdp: RTCSessionDescription, targetEmail: String, callerName: String, callerEmail: String) {
        guard let callId = currentCallId else { return }
        
        let urlStr = "\(firestoreBaseUrl)/companies/\(companyId)/calls?documentId=\(callId)"
        guard let url = URL(string: urlStr) else { return }
        
        let body: [String: Any] = [
            "fields": [
                "callerEmail": ["stringValue": callerEmail],
                "callerName": ["stringValue": callerName],
                "callerRole": ["stringValue": "iOS User"],
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
        
        URLSession.shared.dataTask(with: request).resume()
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
        
        URLSession.shared.dataTask(with: request).resume()
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
                "sdpMid": ["stringValue": candidate.sdpMid ?? ""],
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
    
    private func startSignalingPolling() {
        signalingTimer?.cancel()
        signalingTimer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollSignaling()
            }
    }
    
    private func pollSignaling() {
        guard let callId = currentCallId else { return }
        
        // 1. Poll Call Document for status and answer (if caller)
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
                            DispatchQueue.main.async {
                                self.endCall()
                            }
                            return
                        } else if (statusUpper == "CONNECTED" || statusUpper == "ACCEPTED") && self.isCaller && self.callState == .calling {
                            DispatchQueue.main.async {
                                self.callState = .connected
                            }
                        }
                    }
                    
                    if self.isCaller, self.peerConnection?.remoteDescription == nil,
                       let answer = fields["answer"] as? [String: Any],
                       let mapValue = answer["mapValue"] as? [String: Any],
                       let mapFields = mapValue["fields"] as? [String: Any],
                       let sdpObj = mapFields["sdp"] as? [String: Any],
                       let sdpString = sdpObj["stringValue"] as? String {
                        
                        let sessionDesc = RTCSessionDescription(type: .answer, sdp: sdpString)
                        self.peerConnection?.setRemoteDescription(sessionDesc, completionHandler: { error in
                            print("Set remote description: \(String(describing: error))")
                        })
                    }
                }
            }.resume()
        }
        
        // 2. Poll ICE Candidates
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
                        // check if already processed - skipping optimization for simplicity, WebRTC handles duplicates gracefully
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
                        }
                    }
                }
            }.resume()
        }
    }
}

extension WebRtcCallManager: RTCPeerConnectionDelegate {
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let audioTrack = stream.audioTracks.first {
            self.remoteAudioTrack = audioTrack
        }
    }
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        sendIceCandidate(candidate)
    }
    public func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    public func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
