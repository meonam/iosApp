import Foundation
import CryptoKit
import AVFoundation

// MARK: - WEBSOCKET TASK DELEGATE CHO EDGE TTS
private class EdgeTtsWebSocketDelegate: NSObject, URLSessionWebSocketDelegate {
    var onOpen: (() -> Void)?
    var onError: ((Error) -> Void)?

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        onOpen?()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            onError?(error)
        }
    }
}

public class EdgeTtsClient: NSObject, AVAudioPlayerDelegate {
    public static let shared = EdgeTtsClient()

    private let winEpoch: Int64 = 11644473600
    private let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private let secMsGecVersion = "1-143.0.3650.75"

    private var audioPlayer: AVAudioPlayer?
    // SỬ DỤNG NSRecursiveLock ĐỂ CHỐNG DEADLOCK TUYỆT ĐỐI KHI GỌI LỒNG NHAU GIỮA CÁC LUỒNG
    private let playerLock = NSRecursiveLock()
    private var playbackContinuation: CheckedContinuation<Void, Never>?
    private var fallbackSynthesizer: AVSpeechSynthesizer?

    private override init() {
        super.init()
        clearTtsCache()
    }

    public func clearTtsCache() {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let ttsDir = cacheDir.appendingPathComponent("tts_cache")
        try? FileManager.default.removeItem(at: ttsDir)
    }

    // MARK: - AUDIO PLAYER DELEGATE
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playerLock.lock()
        let cont = playbackContinuation
        playbackContinuation = nil
        audioPlayer = nil
        playerLock.unlock()
        cont?.resume()
        restoreNormalAudioSession()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        playerLock.lock()
        let cont = playbackContinuation
        playbackContinuation = nil
        audioPlayer = nil
        playerLock.unlock()
        cont?.resume()
        restoreNormalAudioSession()
    }

    // Khôi phục AudioSession cho các app nền khác (YouTube, Spotify...) ngay khi dứt giọng đọc
    public func restoreNormalAudioSession() {
        DispatchQueue.main.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            BackgroundKeepAliveService.shared.resumeKeepAliveIfRunning()
        }
    }

    // MARK: - GENERATE SEC-MS-GEC SIGNATURE (CHÍNH XÁC 1:1 THEO ANDROID & PYTHON edge-tts)
    private func generateSecMsGec() -> String {
        var ticks = Date().timeIntervalSince1970
        ticks += Double(winEpoch)
        ticks -= ticks.truncatingRemainder(dividingBy: 300)
        let ticks100ns = ticks * 1e7
        let strToHash = "\(Int64(ticks100ns))\(trustedClientToken)"
        let digest = SHA256.hash(data: Data(strToHash.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - TÌM TỆP ÂM THANH GỐC TRONG BUNDLE
    public func getBundledAudioUrl(named name: String) -> URL? {
        let cleanName = name.replacingOccurrences(of: ".mp3", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        if let url = Bundle.main.url(forResource: cleanName, withExtension: "mp3", subdirectory: "Audio") {
            return url
        }
        if let url = Bundle.main.url(forResource: cleanName, withExtension: "mp3", subdirectory: "Resources/Audio") {
            return url
        }
        if let url = Bundle.main.url(forResource: cleanName, withExtension: "mp3") {
            return url
        }
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Audio/\(cleanName).mp3"),
            Bundle.main.bundleURL.appendingPathComponent("Resources/Audio/\(cleanName).mp3"),
            Bundle.main.bundleURL.appendingPathComponent("\(cleanName).mp3")
        ]
        for c in candidates {
            if FileManager.default.fileExists(atPath: c.path) {
                return c
            }
        }
        if let allMp3s = Bundle.main.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            if let matched = allMp3s.first(where: { $0.deletingPathExtension().lastPathComponent == cleanName }) {
                return matched
            }
        }
        return nil
    }

    // MARK: - 1. PHÁT TỆP ÂM THANH GỐC VTV ĐÓNG GÓI SẴN TRONG BUNDLE
    @discardableResult
    public func playBundledAudio(named name: String) -> Bool {
        guard let finalUrl = getBundledAudioUrl(named: name) else {
            print("[EdgeTtsClient] ⚠️ Không tìm thấy tệp âm thanh gốc '\(name).mp3' trong bundle!")
            return false
        }

        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.playBundledAudio(named: name)
            }
            return true
        }

        playerLock.lock()
        defer { playerLock.unlock() }

        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try? session.overrideOutputAudioPort(.speaker)
            try? session.setActive(true, options: .notifyOthersOnDeactivation)

            audioPlayer?.stop()
            audioPlayer = nil
            audioPlayer = try AVAudioPlayer(contentsOf: finalUrl)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.prepareToPlay()
            let started = audioPlayer?.play() ?? false
            print("[EdgeTtsClient] 🎙️ ĐANG PHÁT GIỌNG GỐC VTV CHUẨN: '\(name).mp3' - Bắt đầu: \(started)")
            return started
        } catch {
            print("[EdgeTtsClient] ❌ Lỗi phát tệp âm thanh gốc: \(error)")
            return false
        }
    }

    // MARK: - 2. TỔNG HỢP QUA MICROSOFT EDGE TTS (GIỌNG NỮ BTV VTV vi-VN-HoaiMyNeural)
    public func synthesizeToFile(text: String, outputFile: URL, voice: String = "vi-VN-HoaiMyNeural") async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let secMsGec = generateSecMsGec()
        let connId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let urlStr = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1" +
            "?TrustedClientToken=\(trustedClientToken)" +
            "&ConnectionId=\(connId)" +
            "&Sec-MS-GEC=\(secMsGec)" +
            "&Sec-MS-GEC-Version=\(secMsGecVersion)"

        guard let url = URL(string: urlStr) else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12.0
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0",
            forHTTPHeaderField: "User-Agent"
        )
        let muid = UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
        request.setValue("muid=\(muid);", forHTTPHeaderField: "Cookie")

        let wsDelegate = EdgeTtsWebSocketDelegate()
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: wsDelegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)

        return await withCheckedContinuation { continuation in
            var audioBuffer = Data()
            var isFinished = false

            func finish(success: Bool) {
                guard !isFinished else { return }
                isFinished = true
                task.cancel(with: .normalClosure, reason: nil)
                session.invalidateAndCancel()

                if success && audioBuffer.count > 500 {
                    do {
                        let parent = outputFile.deletingLastPathComponent()
                        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                        let tmpFile = parent.appendingPathComponent("\(outputFile.lastPathComponent).tmp")
                        try audioBuffer.write(to: tmpFile)
                        if FileManager.default.fileExists(atPath: outputFile.path) {
                            try FileManager.default.removeItem(at: outputFile)
                        }
                        try FileManager.default.moveItem(at: tmpFile, to: outputFile)
                        continuation.resume(returning: true)
                        return
                    } catch {
                        print("[EdgeTtsClient] Save audio error: \(error)")
                    }
                }
                continuation.resume(returning: false)
            }

            wsDelegate.onError = { err in
                print("[EdgeTtsClient] WebSocket connection error: \(err)")
                finish(success: false)
            }

            wsDelegate.onOpen = {
                let configMsg = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n" +
                    "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
                task.send(.string(configMsg)) { err in
                    if err != nil {
                        finish(success: false)
                        return
                    }

                    let reqId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                    let escaped = trimmed
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                        .replacingOccurrences(of: "\"", with: "&quot;")
                        .replacingOccurrences(of: "'", with: "&apos;")
                    let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='vi-VN'><voice name='\(voice)'><prosody pitch='+0Hz' rate='+0%'>\(escaped)</prosody></voice></speak>"
                    let ssmlMsg = "X-RequestId:\(reqId)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"

                    task.send(.string(ssmlMsg)) { sErr in
                        if sErr != nil {
                            finish(success: false)
                        }
                    }
                }
            }

            func receiveNext() {
                task.receive { result in
                    guard !isFinished else { return }
                    switch result {
                    case .success(let msg):
                        switch msg {
                        case .data(let data):
                            if data.count >= 2 {
                                let headerLen = Int(data[0]) << 8 | Int(data[1])
                                let audioStart = 2 + headerLen
                                if audioStart < data.count {
                                    audioBuffer.append(data.subdata(in: audioStart..<data.count))
                                }
                            }
                            receiveNext()
                        case .string(let str):
                            if str.contains("Path:turn.end") {
                                finish(success: true)
                                return
                            }
                            receiveNext()
                        @unknown default:
                            receiveNext()
                        }
                    case .failure(let err):
                        print("[EdgeTtsClient] receive failure: \(err)")
                        finish(success: false)
                    }
                }
            }

            task.resume()
            receiveNext()

            DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                if !isFinished {
                    print("[EdgeTtsClient] WebSocket timeout reached")
                    finish(success: false)
                }
            }
        }
    }

    // MARK: - 3. PLAY AUDIO FILE SUSPEND (CHỜ PHÁT XONG HOÀN TOÀN)
    public func playAudioFileSuspend(url: URL) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.playerLock.lock()
                let oldCont = self.playbackContinuation
                self.playbackContinuation = continuation
                self.playerLock.unlock()
                oldCont?.resume()

                do {
                    let session = AVAudioSession.sharedInstance()
                    try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
                    try? session.overrideOutputAudioPort(.speaker)
                    try? session.setActive(true, options: .notifyOthersOnDeactivation)

                    self.audioPlayer?.stop()
                    self.audioPlayer = nil
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.delegate = self
                    player.volume = 1.0
                    player.numberOfLoops = 0
                    player.prepareToPlay()
                    let duration = player.duration
                    self.audioPlayer = player
                    if player.play() {
                        // Timeout an toàn: duration + 0.6s để bảo đảm resume continuation nếu delegate không gọi
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.6) {
                            self.playerLock.lock()
                            if self.playbackContinuation != nil {
                                let cont = self.playbackContinuation
                                self.playbackContinuation = nil
                                self.audioPlayer = nil
                                self.playerLock.unlock()
                                cont?.resume()
                            } else {
                                self.playerLock.unlock()
                            }
                        }
                    } else {
                        self.playerLock.lock()
                        let cont = self.playbackContinuation
                        self.playbackContinuation = nil
                        self.audioPlayer = nil
                        self.playerLock.unlock()
                        cont?.resume()
                    }
                } catch {
                    print("[EdgeTtsClient] Play audio error: \(error)")
                    self.playerLock.lock()
                    let cont = self.playbackContinuation
                    self.playbackContinuation = nil
                    self.audioPlayer = nil
                    self.playerLock.unlock()
                    cont?.resume()
                }
            }
        }
    }

    public func playBundledAudioSuspend(named name: String) async {
        guard let finalUrl = getBundledAudioUrl(named: name) else {
            print("[EdgeTtsClient] ⚠️ Không tìm thấy tệp bundle '\(name).mp3'")
            return
        }
        await playAudioFileSuspend(url: finalUrl)
    }

    // MARK: - 4. PHÁT ÂM THANH ASYNC ĐỒNG BỘ 1:1 THEO ANDROID (ƯU TIÊN ONLINE TTS -> DỰ PHÒNG BUNDLE)
    public func speakSuspend(text: String, fallbackBundledName: String? = nil, voice: String = "vi-VN-HoaiMyNeural") async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        let md5 = Insecure.MD5.hash(data: Data(clean.utf8)).map { String(format: "%02x", $0) }.joined()
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let ttsDir = cacheDir.appendingPathComponent("tts_cache")
        try? FileManager.default.createDirectory(at: ttsDir, withIntermediateDirectories: true)
        let audioFile = ttsDir.appendingPathComponent("vtv_\(md5).mp3")

        var hasAudio = false
        if FileManager.default.fileExists(atPath: audioFile.path) {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: audioFile.path),
               let size = attrs[.size] as? Int64, size > 500 {
                hasAudio = true
            } else {
                try? FileManager.default.removeItem(at: audioFile)
            }
        }

        // 1. ƯU TIÊN SỐ 1: Tổng hợp giọng Nữ BTV Hoài My Neural (Đọc rõ ràng cụ thể tên đơn vị & nội dung)
        if !hasAudio {
            hasAudio = await synthesizeToFile(text: clean, outputFile: audioFile, voice: voice)
        }

        if hasAudio && FileManager.default.fileExists(atPath: audioFile.path) {
            await playAudioFileSuspend(url: audioFile)
            return
        }

        // 2. DỰ PHÒNG KHI OFFLINE / MẤT MẠNG: Phát tệp âm thanh VTV gốc đóng gói sẵn trong Bundle
        if let bundled = fallbackBundledName {
            await playBundledAudioSuspend(named: bundled)
            return
        }

        // 3. DỰ PHÒNG CUỐI CÙNG: Giọng đọc hệ thống iOS
        await MainActor.run {
            self.speakFallback(text: clean)
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
    }

    public func speak(text: String, fallbackBundledName: String? = nil, voice: String = "vi-VN-HoaiMyNeural") {
        Task {
            await self.speakSuspend(text: text, fallbackBundledName: fallbackBundledName, voice: voice)
        }
    }

    // MARK: - DỰ PHÒNG GIỌNG ĐỌC HỆ THỐNG
    private func speakFallback(text: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.speakFallback(text: text)
            }
            return
        }

        if text.hasPrefix("vtv_") || text.hasSuffix(".mp3") ||
           (text.count >= 24 && text.range(of: "^[a-f0-9_.-]+$", options: .regularExpression) != nil) {
            return
        }

        if fallbackSynthesizer == nil {
            fallbackSynthesizer = AVSpeechSynthesizer()
        }
        if fallbackSynthesizer?.isSpeaking == true {
            fallbackSynthesizer?.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        utterance.rate = 0.50
        utterance.volume = 1.0
        fallbackSynthesizer?.speak(utterance)
    }

    public func stop() {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.stop()
            }
            return
        }

        playerLock.lock()
        audioPlayer?.stop()
        audioPlayer = nil
        let cont = playbackContinuation
        playbackContinuation = nil
        playerLock.unlock()

        cont?.resume()

        if fallbackSynthesizer?.isSpeaking == true {
            fallbackSynthesizer?.stopSpeaking(at: .immediate)
        }
        restoreNormalAudioSession()
    }
}
