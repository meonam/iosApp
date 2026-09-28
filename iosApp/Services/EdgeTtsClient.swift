import Foundation
import CryptoKit
import AVFoundation

public class EdgeTtsClient: NSObject, AVAudioPlayerDelegate, URLSessionWebSocketDelegate {
    public static let shared = EdgeTtsClient()

    private let winEpoch: Int64 = 11644473600
    private let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private let secMsGecVersion = "1-143.0.3650.75"

    private var audioPlayer: AVAudioPlayer?
    private let playerLock = NSLock()
    private var fallbackSynthesizer: AVSpeechSynthesizer?

    private override init() {
        super.init()
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

    // MARK: - 1. SYNTHESIZE TEXT QUA MICROSOFT EDGE TTS (GIỌNG NỮ BTV VTV vi-VN-HoaiMyNeural)
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

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        task.resume()

        return await withCheckedContinuation { continuation in
            var audioBuffer = Data()
            var isFinished = false

            func finish(success: Bool) {
                guard !isFinished else { return }
                isFinished = true
                task.cancel(with: .normalClosure, reason: nil)

                // Khi tải thành công và có dữ liệu âm thanh > 500 bytes (tương tự Android)
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

            // 1. Gửi cấu hình speech.config
            let configMsg = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n" +
                "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
            task.send(.string(configMsg)) { err in
                if let err = err {
                    print("[EdgeTtsClient] send config error: \(err)")
                    finish(success: false)
                    return
                }

                // 2. Gửi SSML chuẩn cú pháp Microsoft Edge TTS
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
                    if let sErr = sErr {
                        print("[EdgeTtsClient] send ssml error: \(sErr)")
                        finish(success: false)
                    }
                }
            }

            // 3. Nhận phản hồi âm thanh dạng binary chunks
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

            receiveNext()

            // 4. Timeout an toàn 10s
            DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                if !isFinished {
                    print("[EdgeTtsClient] WebSocket timeout 10s reached")
                    finish(success: false)
                }
            }
        }
    }

    // MARK: - 2. DỰ PHÒNG ONLINE: GOOGLE TRANSLATE TTS (GIỌNG NỮ TIẾNG VIỆT TỰ NHIÊN)
    public func synthesizeGoogleTTS(text: String, outputFile: URL) async -> Bool {
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/translate_tts?ie=UTF-8&tl=vi&client=tw-ob&q=\(encoded)") else {
            return false
        }
        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 6.0
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 500 {
                let parent = outputFile.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                try data.write(to: outputFile)
                print("[EdgeTtsClient] Fallback to Google TTS successfully, size: \(data.count) bytes")
                return true
            }
        } catch {
            print("[EdgeTtsClient] Google TTS fallback error: \(error)")
        }
        return false
    }

    // MARK: - SPEAK TEXT (CHUẨN GIỌNG NỮ BTV VTV HOÀI MY NHƯ TRÊN ANDROID)
    public func speak(text: String, voice: String = "vi-VN-HoaiMyNeural") {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Tính MD5 để lưu đệm tránh tải lại nhiều lần
        let md5 = Insecure.MD5.hash(data: Data(clean.utf8)).map { String(format: "%02x", $0) }.joined()
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let ttsDir = cacheDir.appendingPathComponent("tts_cache")
        let audioFile = ttsDir.appendingPathComponent("vtv_\(md5).mp3")

        Task {
            // Kiểm tra cache đã có và file hợp lệ (> 500 bytes)
            var hasAudio = false
            if FileManager.default.fileExists(atPath: audioFile.path) {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: audioFile.path),
                   let size = attrs[.size] as? Int64, size > 500 {
                    hasAudio = true
                } else {
                    try? FileManager.default.removeItem(at: audioFile)
                }
            }

            // 1. Thử tổng hợp qua Microsoft Edge TTS (Hoài My Neural)
            if !hasAudio {
                hasAudio = await self.synthesizeToFile(text: clean, outputFile: audioFile, voice: voice)
            }

            // 2. Nếu Edge TTS bị chặn hoặc lỗi mạng, thử Google TTS tiếng Việt (giọng nữ trợ lý)
            if !hasAudio {
                hasAudio = await self.synthesizeGoogleTTS(text: clean, outputFile: audioFile)
            }

            // 3. Phát tệp âm thanh MP3
            if hasAudio && FileManager.default.fileExists(atPath: audioFile.path) {
                await MainActor.run {
                    self.playAudioFile(url: audioFile, originalText: clean)
                }
            } else {
                // 4. Dự phòng cuối cùng khi hoàn toàn mất kết nối Internet: AVSpeechSynthesizer
                print("[EdgeTtsClient] Online TTS failed, using system TTS fallback")
                await MainActor.run {
                    self.speakFallback(text: clean)
                }
            }
        }
    }

    // MARK: - PLAY AUDIO FILE (LOA NGOÀI, ÂM LƯỢNG CỰC ĐẠI)
    private func playAudioFile(url: URL, originalText: String) {
        playerLock.lock()
        defer { playerLock.unlock() }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try session.overrideOutputAudioPort(.speaker)

            audioPlayer?.stop()
            audioPlayer = nil
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 1.0
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.prepareToPlay()
            let started = audioPlayer?.play() ?? false
            if !started {
                print("[EdgeTtsClient] Failed to start audioPlayer, falling back")
                speakFallback(text: originalText)
            }
        } catch {
            print("[EdgeTtsClient] Play audio error: \(error)")
            speakFallback(text: originalText)
        }
    }

    // MARK: - DỰ PHÒNG GIỌNG ĐỌC HỆ THỐNG (CHỈ ĐỌC VĂN BẢN THUẦN TÚY)
    private func speakFallback(text: String) {
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
        playerLock.lock()
        defer { playerLock.unlock() }

        audioPlayer?.stop()
        audioPlayer = nil
        if fallbackSynthesizer?.isSpeaking == true {
            fallbackSynthesizer?.stopSpeaking(at: .immediate)
        }
    }
}
