import Foundation
import AVFoundation
import UIKit

/**
 * Dịch vụ duy trì hoạt động ngầm 24/7 trên iOS (Background Keep-Alive Service).
 * Tận dụng chế độ `UIBackgroundModes: audio` đã khai báo trong Info.plist.
 * Khi ứng dụng chạy nền hoặc màn hình bị khóa/tắt:
 * Dịch vụ phát luồng âm thanh im lặng (silent audio loop) để iOS KHÔNG BAO GIỜ suspend tiến trình app.
 * Nhờ đó, bộ polling của SupportViewModel vẫn hoạt động liên tục mỗi 2 giây,
 * sẵn sàng nhận lệnh điều phối ngay tức thì và bật sáng màn hình khóa để thông báo cho KTV.
 */
public class BackgroundKeepAliveService: NSObject, AVAudioPlayerDelegate {
    public static let shared = BackgroundKeepAliveService()

    private var silentPlayer: AVAudioPlayer?
    private var isRunning = false
    private let lock = NSRecursiveLock()

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended {
            try? AVAudioSession.sharedInstance().setActive(true)
            if isRunning && silentPlayer?.isPlaying != true {
                silentPlayer?.play()
                print("[BackgroundKeepAlive] 🟢 Khôi phục âm thanh keep-alive sau gián đoạn")
            }
        }
    }

    public func start() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.start()
            }
            return
        }

        lock.lock()
        defer { lock.unlock() }

        guard !isRunning || silentPlayer?.isPlaying != true else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try? session.setActive(true)

            if silentPlayer == nil {
                let wavData = generateSilentWav()
                silentPlayer = try AVAudioPlayer(data: wavData)
                silentPlayer?.delegate = self
                silentPlayer?.volume = 0.01 // Âm lượng siêu nhỏ với dữ liệu PCM toàn số 0 (hoàn toàn im lặng tuyệt đối)
                silentPlayer?.numberOfLoops = -1 // Lặp vô hạn
                silentPlayer?.prepareToPlay()
            }
            let ok = silentPlayer?.play() ?? false
            isRunning = ok
            print("[BackgroundKeepAlive] 🟢 Bắt đầu duy trì tiến trình chạy nền 24/7 (Audio Keep-Alive): \(ok)")
        } catch {
            print("[BackgroundKeepAlive] ❌ Lỗi khởi động silent player: \(error)")
        }
    }

    public func stop() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.stop()
            }
            return
        }

        lock.lock()
        defer { lock.unlock() }

        guard isRunning else { return }

        silentPlayer?.stop()
        silentPlayer = nil
        isRunning = false
        print("[BackgroundKeepAlive] 🔴 Dừng duy trì tiến trình chạy nền")
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isRunning {
            silentPlayer?.play()
        }
    }

    // MARK: - TẠO DỮ LIỆU WAV 1 GIÂY IM LẶNG TRONG BỘ NHỚ RAM
    private func generateSilentWav() -> Data {
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels * bitsPerSample / 8)
        let blockAlign = numChannels * bitsPerSample / 8
        let numSamples: Int32 = 8000 // 1 giây im lặng
        let dataSize = numSamples * Int32(blockAlign)

        var data = Data()
        data.append("RIFF".utf8)
        var chunkSize = 36 + dataSize
        data.append(Data(bytes: &chunkSize, count: 4))
        data.append("WAVE".utf8)
        data.append("fmt ".utf8)
        var subchunk1Size: Int32 = 16
        data.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: Int16 = 1
        data.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        data.append(Data(bytes: &channels, count: 2))
        var rate = sampleRate
        data.append(Data(bytes: &rate, count: 4))
        var bRate = byteRate
        data.append(Data(bytes: &bRate, count: 4))
        var align = blockAlign
        data.append(Data(bytes: &align, count: 2))
        var bits = bitsPerSample
        data.append(Data(bytes: &bits, count: 2))
        data.append("data".utf8)
        var dSize = dataSize
        data.append(Data(bytes: &dSize, count: 4))
        data.append(Data(repeating: 0, count: Int(dataSize)))
        return data
    }
}
