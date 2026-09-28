import Foundation
import SwiftUI
import AVFoundation
import AudioToolbox
import Combine
import UserNotifications

// MARK: - INCOMING CALL MODEL
public struct IncomingCallInfo: Identifiable, Equatable {
    public let id: String // callId
    public let callerName: String
    public let callerEmail: String
    public let callerRole: String
    public let targetEmail: String
    public let targetRole: String
    public let companyId: String
    public let createdAt: Int64
    public let offerSdp: String

    public static func == (lhs: IncomingCallInfo, rhs: IncomingCallInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - INCOMING CALL MANAGER (LẮNG NGHE & ĐỔ CHUÔNG CUỘC GỌI ĐẾN TRÊN IOS)
public class IncomingCallManager: NSObject, ObservableObject {
    public static let shared = IncomingCallManager()

    @Published public var activeIncomingCall: IncomingCallInfo? = nil
    @Published public var isCallPresented: Bool = false
    public private(set) var handledCallIds = Set<String>()

    private var pollTimer: AnyCancellable?
    private var vibrateTimer: Timer?
    private var ringAudioPlayer: AVAudioPlayer?

    private var currentUserEmail: String = ""
    private var isUserHelpDesk: Bool = false
    private var currentCompanyId: String = "SGCOOP"
    private var currentIdToken: String = ""
    private var isListening: Bool = false

    private override init() {
        super.init()
        prepareAudioPlayer()
    }

    private func prepareAudioPlayer() {
        if let soundUrl = Bundle.main.url(forResource: "phone_ring", withExtension: "wav", subdirectory: "Audio") ??
                          Bundle.main.url(forResource: "phone_ring", withExtension: "wav") {
            do {
                ringAudioPlayer = try AVAudioPlayer(contentsOf: soundUrl)
                ringAudioPlayer?.numberOfLoops = -1 // Lặp vô tận cho đến khi nghe hoặc cúp máy
                ringAudioPlayer?.prepareToPlay()
            } catch {
                print("[IncomingCallManager] Error loading ringtone: \(error)")
            }
        }
    }

    // MARK: - START / STOP LISTENING
    public func startListening(user: User, companyId: String, idToken: String) {
        self.currentUserEmail = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isAdminUser = user.isAdmin || user.role.lowercased().contains("admin") || user.role.lowercased().contains("quantri")
        if isAdminUser {
            print("[IncomingCallManager] Bỏ qua lắng nghe cuộc gọi vì tài khoản Quản trị viên (Admin) không nhận cuộc gọi của ai.")
            stopListening()
            return
        }
        self.isUserHelpDesk = user.isHelpDesk || user.role.lowercased().contains("helpdesk")
        self.currentCompanyId = companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.currentIdToken = idToken

        // Đồng bộ token sang WebRtcCallManager
        WebRtcCallManager.shared.companyId = self.currentCompanyId
        WebRtcCallManager.shared.idToken = idToken

        guard !currentUserEmail.isEmpty else { return }
        if isListening { return }
        isListening = true

        print("[IncomingCallManager] Bắt đầu lắng nghe cuộc gọi đến cho: \(currentUserEmail) tại \(currentCompanyId)")

        // Polling định kỳ mỗi 1.8 giây qua Firestore REST runQuery
        pollTimer?.cancel()
        pollTimer = Timer.publish(every: 1.8, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollIncomingCalls()
            }
    }

    public func stopListening() {
        isListening = false
        pollTimer?.cancel()
        pollTimer = nil
        stopRinging()
        activeIncomingCall = nil
    }

    // MARK: - REMOTE NOTIFICATION HOOK
    public func handleIncomingCallFromPush(userInfo: [AnyHashable: Any]) {
        guard let callId = userInfo["callId"] as? String, !callId.isEmpty else { return }
        let callerName = (userInfo["callerName"] as? String) ?? "HelpDesk IT"
        let callerEmail = (userInfo["callerEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let callerRole = (userInfo["callerRole"] as? String) ?? "HelpDesk"
        let targetEmail = (userInfo["targetEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let targetRole = (userInfo["targetRole"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let compId = (userInfo["companyId"] as? String)?.uppercased() ?? currentCompanyId

        if !callerEmail.isEmpty && callerEmail == currentUserEmail { return }

        let isTargetToMe = (targetEmail == currentUserEmail) ||
                           (!targetEmail.isEmpty && currentUserEmail.contains(targetEmail)) ||
                           (!currentUserEmail.isEmpty && targetEmail.contains(currentUserEmail))
        let isHelpdeskCall = isUserHelpDesk && (
            ["helpdesk", "hotline", "support", ""].contains(targetEmail) ||
            ["HELPDESK", "HOTLINE"].contains(targetRole)
        )

        if isTargetToMe || isHelpdeskCall {
            DispatchQueue.main.async {
                guard !self.handledCallIds.contains(callId),
                      !self.isCallPresented,
                      (WebRtcCallManager.shared.callState == .idle || WebRtcCallManager.shared.callState == .ended) else {
                    return
                }
                self.activeIncomingCall = IncomingCallInfo(
                    id: callId,
                    callerName: callerName,
                    callerEmail: callerEmail,
                    callerRole: callerRole,
                    targetEmail: targetEmail,
                    targetRole: targetRole,
                    companyId: compId,
                    createdAt: Int64(Date().timeIntervalSince1970 * 1000),
                    offerSdp: ""
                )
                self.startRinging()
            }
        }
    }

    // MARK: - POLL FIRESTORE FOR RINGING CALLS
    private func pollIncomingCalls() {
        guard isListening, !currentUserEmail.isEmpty else { return }

        // Nếu đang trong cuộc gọi đàm thoại hoặc màn hình CallView đang mở thì dừng mọi chuông và không đón thêm
        if isCallPresented || (WebRtcCallManager.shared.callState != .idle && WebRtcCallManager.shared.callState != .ended) {
            if activeIncomingCall != nil {
                stopRinging()
                activeIncomingCall = nil
            }
            return
        }

        let cleanComp = currentCompanyId.isEmpty ? "SGCOOP" : currentCompanyId
        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(cleanComp):runQuery"
        guard let url = URL(string: urlStr) else { return }

        let queryPayload: [String: Any] = [
            "structuredQuery": [
                "from": [["collectionId": "calls"]],
                "where": [
                    "fieldFilter": [
                        "field": ["fieldPath": "status"],
                        "op": "EQUAL",
                        "value": ["stringValue": "RINGING"]
                    ]
                ],
                "limit": 25
            ]
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: queryPayload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !currentIdToken.isEmpty {
            request.setValue("Bearer \(currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        request.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }

            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }

            var foundCall: IncomingCallInfo? = nil
            let now = Int64(Date().timeIntervalSince1970 * 1000)

            for item in jsonArray {
                guard let doc = item["document"] as? [String: Any],
                      let name = doc["name"] as? String,
                      let fields = doc["fields"] as? [String: Any] else { continue }

                let callId = name.components(separatedBy: "/").last ?? ""
                let callerEmail = ((fields["callerEmail"] as? [String: Any])?["stringValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let callerName = ((fields["callerName"] as? [String: Any])?["stringValue"] as? String) ?? "HelpDesk IT"
                let callerRole = ((fields["callerRole"] as? [String: Any])?["stringValue"] as? String) ?? "HelpDesk"
                let targetEmail = ((fields["targetEmail"] as? [String: Any])?["stringValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                let targetRole = ((fields["targetRole"] as? [String: Any])?["stringValue"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

                var createdAt: Int64 = now
                if let cObj = fields["createdAt"] as? [String: Any] {
                    if let cStr = cObj["integerValue"] as? String, let val = Int64(cStr) {
                        createdAt = val
                    }
                }

                // Bỏ qua nếu cuộc gọi quá hạn 3 phút (dung sai chênh lệch đồng hồ hệ thống)
                if abs(now - createdAt) > 180_000 { continue }

                // Bỏ qua nếu chính mình là người gọi hoặc cuộc gọi đã được xử lý
                if callerEmail == self.currentUserEmail { continue }
                if self.handledCallIds.contains(callId) { continue }

                // Kiểm tra xem cuộc gọi có gửi cho tài khoản này không
                let isTargetToMe = (targetEmail == self.currentUserEmail) ||
                                   (!targetEmail.isEmpty && self.currentUserEmail.contains(targetEmail)) ||
                                   (!self.currentUserEmail.isEmpty && targetEmail.contains(self.currentUserEmail))
                let isHelpdeskCall = self.isUserHelpDesk && (
                    ["helpdesk", "hotline", "support", ""].contains(targetEmail) ||
                    ["HELPDESK", "HOTLINE"].contains(targetRole)
                )

                if isTargetToMe || isHelpdeskCall {
                    var offerSdp = ""
                    if let offer = fields["offer"] as? [String: Any],
                       let mapValue = offer["mapValue"] as? [String: Any],
                       let mapFields = mapValue["fields"] as? [String: Any],
                       let sdpObj = mapFields["sdp"] as? [String: Any],
                       let sdpVal = sdpObj["stringValue"] as? String {
                        offerSdp = sdpVal
                    }

                    foundCall = IncomingCallInfo(
                        id: callId,
                        callerName: callerName,
                        callerEmail: callerEmail,
                        callerRole: callerRole,
                        targetEmail: targetEmail,
                        targetRole: targetRole,
                        companyId: cleanComp,
                        createdAt: createdAt,
                        offerSdp: offerSdp
                    )
                    break
                }
            }

            DispatchQueue.main.async {
                // Kiểm tra trạng thái: nếu đã bấm nghe hoặc CallView đang mở, lập tức dừng chuông và hủy banner
                guard self.isListening,
                      !self.isCallPresented,
                      (WebRtcCallManager.shared.callState == .idle || WebRtcCallManager.shared.callState == .ended) else {
                    self.stopRinging()
                    self.activeIncomingCall = nil
                    return
                }

                if let call = foundCall {
                    if self.handledCallIds.contains(call.id) {
                        self.stopRinging()
                        self.activeIncomingCall = nil
                        return
                    }
                    if self.activeIncomingCall?.id != call.id {
                        self.activeIncomingCall = call
                        self.startRinging()
                    }
                } else {
                    // Nếu cuộc gọi đang reo nhưng trên Firestore đã bị hủy/kết thúc
                    if self.activeIncomingCall != nil {
                        self.stopRinging()
                        self.activeIncomingCall = nil
                    }
                }
            }
        }.resume()
    }

    // MARK: - ACCEPT / REJECT
    public func acceptCall() {
        guard let call = activeIncomingCall else { return }
        let callId = call.id
        handledCallIds.insert(callId)

        // Dừng triệt để chuông và rung ngay lập tức trước khi chuyển sang đàm thoại
        stopRinging()
        activeIncomingCall = nil
        isCallPresented = true

        WebRtcCallManager.shared.companyId = call.companyId
        WebRtcCallManager.shared.idToken = currentIdToken
        WebRtcCallManager.shared.answerCall(
            callId: call.id,
            callerName: call.callerName,
            callerEmail: call.callerEmail,
            offerSdp: call.offerSdp.isEmpty ? nil : call.offerSdp
        )
    }

    public func rejectCall() {
        guard let call = activeIncomingCall else { return }
        let callId = call.id
        handledCallIds.insert(callId)

        stopRinging()
        activeIncomingCall = nil

        let urlStr = "\(FirebaseConfig.firestoreBaseUrl)/companies/\(call.companyId)/calls/\(call.id)?updateMask.fieldPaths=status"
        guard let url = URL(string: urlStr) else { return }

        let body: [String: Any] = [
            "fields": [
                "status": ["stringValue": "REJECTED"]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !currentIdToken.isEmpty {
            request.setValue("Bearer \(currentIdToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: request).resume()
    }

    // MARK: - SOUND & VIBRATION
    public func startRinging() {
        // Tuyệt đối không rung và không reo chuông nếu đã vào màn hình đàm thoại
        guard !isCallPresented,
              (WebRtcCallManager.shared.callState == .idle || WebRtcCallManager.shared.callState == .ended) else {
            stopRinging()
            return
        }
        guard let call = activeIncomingCall, !handledCallIds.contains(call.id) else {
            stopRinging()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            print("[IncomingCallManager] Audio session error: \(error)")
        }

        if ringAudioPlayer == nil {
            prepareAudioPlayer()
        }
        ringAudioPlayer?.currentTime = 0
        ringAudioPlayer?.play()

        // Rung máy định kỳ mỗi 1.2s với điều kiện an toàn
        vibrateTimer?.invalidate()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        vibrateTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.activeIncomingCall != nil,
                  !self.isCallPresented,
                  (WebRtcCallManager.shared.callState == .idle || WebRtcCallManager.shared.callState == .ended) else {
                self?.stopRinging()
                return
            }
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }

        // Bắn local notification nếu cần (thông báo cuộc gọi thoại nội bộ thân thiện)
        let content = UNMutableNotificationContent()
        content.title = "📞 Cuộc gọi thoại đến: \(call.callerName)"
        content.body = "Nhấn để trả lời cuộc gọi thoại nội bộ (\(call.callerRole))"
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: "INCOMING_CALL_\(call.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                print("[IncomingCallManager] Notification error: \(err)")
            }
        }
    }

    public func stopRinging() {
        ringAudioPlayer?.stop()
        ringAudioPlayer?.currentTime = 0
        vibrateTimer?.invalidate()
        vibrateTimer = nil

        if let call = activeIncomingCall {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["INCOMING_CALL_\(call.id)"])
        }
        if !handledCallIds.isEmpty {
            let ids = handledCallIds.map { "INCOMING_CALL_\($0)" }
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
        }
    }
}
