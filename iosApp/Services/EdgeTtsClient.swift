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

    // MARK: - GENERATE SEC-MS-GEC SIGNATURE (CHÍNH XÁC 1:1 THEO ANDROID & EDGE)
    private func generateSecMsGec() -> String {
        let unixTime = Int64(Date().timeIntervalSince1970)
        var ticks = unixTime + winEpoch
        ticks -= (ticks % 300)
        let ticks100ns = ticks * 10_000_000
        let strToHash = "\(ticks100ns)\(trustedClientToken)"
        let digest = SHA256.hash(data: Data(strToHash.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - SYNTHESIZE TEXT TO MP3 FILE (CACHE TRÁNH TẢI LẠI)
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
        request.timeoutInterval = 8
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
        request.setValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0", forHTTPHeaderField: "User-Agent")
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

                // Kiểm tra audioBuffer có decode được bởi AVAudioPlayer không
                if success && audioBuffer.count > 1000, (try? AVAudioPlayer(data: audioBuffer)) != nil {
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
                    } catch {}
                }
                continuation.resume(returning: false)
            }

            // 1. Send speech.config
            let configMsg = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n" +
                "{\"context\":{\"synthesis\":{\"audio\":{\"metadataoptions\":{\"sentenceBoundaryEnabled\":\"false\",\"wordBoundaryEnabled\":\"false\"},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
            task.send(.string(configMsg)) { err in
                if let _ = err {
                    finish(success: false)
                    return
                }

                // 2. Send SSML chuẩn cú pháp Microsoft Edge TTS
                let reqId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                let escaped = trimmed
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\"", with: "&quot;")
                    .replacingOccurrences(of: "'", with: "&apos;")
                let voiceFull = "Microsoft Server Speech Text to Speech Voice (vi-VN, HoaiMyNeural)"
                let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='vi-VN'><voice name='\(voiceFull)'><prosody pitch='+0Hz' rate='+0%' volume='+0%'>\(escaped)</prosody></voice></speak>"
                let ssmlMsg = "X-RequestId:\(reqId)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"

                task.send(.string(ssmlMsg)) { sErr in
                    if let _ = sErr {
                        finish(success: false)
                    }
                }
            }

            // 3. Receive responses
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
                    case .failure:
                        finish(success: false)
                    }
                }
            }

            receiveNext()

            // 4. Timeout safety 10.0s (tăng từ 6s để tránh timeout trên mạng yếu)
            DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
                if !isFinished {
                    finish(success: false)
                }
            }
        }
    }

    // MARK: - SPEAK TEXT (CHUẨN GIỌNG NỮ BTV VTV HOÀI MY NHƯ TRÊN ANDROID)
    public func speak(text: String, voice: String = "vi-VN-HoaiMyNeural") {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        // Tính MD5 để lưu đệm
        let md5 = Insecure.MD5.hash(data: Data(clean.utf8)).map { String(format: "%02x", $0) }.joined()
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let ttsDir = cacheDir.appendingPathComponent("tts_cache")
        let audioFile = ttsDir.appendingPathComponent("vtv_\(md5).mp3")

        Task {
            // Kiểm tra cache đã có và file hợp lệ
            var hasAudio = false
            if FileManager.default.fileExists(atPath: audioFile.path) {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: audioFile.path),
                   let size = attrs[.size] as? Int64, size > 1000,
                   let player = try? AVAudioPlayer(contentsOf: audioFile), player.duration > 0.1 {
                    hasAudio = true
                }
            }

            if !hasAudio {
                hasAudio = await self.synthesizeToFile(text: clean, outputFile: audioFile, voice: voice)
            }

            if hasAudio && FileManager.default.fileExists(atPath: audioFile.path) {
                await MainActor.run {
                    self.playAudioFile(url: audioFile, originalText: clean)
                }
            } else {
                // Dự phòng khi offline / mạng yếu: AVSpeechSynthesizer đọc ĐÚNG NỘI DUNG VĂN BẢN
                await MainActor.run {
                    self.speakFallback(text: clean)
                }
            }
        }
    }

    // MARK: - PLAY AUDIO FILE
    private func playAudioFile(url: URL, originalText: String) {
        playerLock.lock()
        defer { playerLock.unlock() }

        do {
            let session = AVAudioSession.sharedInstance()
            // Đặt category TRƯỚC KHI tạo player - đảm bảo phát qua loa ngoài, âm lượng tối đa
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .allowBluetooth])
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
                speakFallback(text: originalText)
            }
        } catch {
            print("[EdgeTtsClient] Play audio error: \(error)")
            // CỰC KỲ QUAN TRỌNG: PHẢI ĐỌC originalText, TUYỆT ĐỐI KHÔNG ĐỌC TÊN FILE HAY MÃ HASH
            speakFallback(text: originalText)
        }
    }

    // MARK: - DỰ PHÒNG GIỌNG ĐỌC HỆ THỐNG (CHỈ ĐỌC VĂN BẢN THUẦN TÚY)
    private func speakFallback(text: String) {
        // Tuyệt đối không đọc các chuỗi mã hash, tên file kỹ thuật (chống lỗi đọc mã số)
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
