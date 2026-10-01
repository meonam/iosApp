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
            resumeKeepAliveIfRunning()
        }
    }

    public func resumeKeepAliveIfRunning() {
        guard isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
            if silentPlayer?.isPlaying != true {
                silentPlayer?.play()
                print("[BackgroundKeepAlive] 🟢 Khôi phục âm thanh keep-alive sau gián đoạn")
            }
        } catch {
            print("[BackgroundKeepAlive] ❌ Lỗi khôi phục silent player: \(error)")
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
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
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
            print("[BackgroundKeepAlive] 🟢 Bắt đầu duy trì tiến trình chạy nền 24/7 (Audio Keep-Alive - MixWithOthers): \(ok)")
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
        let byteRate: Int32 = sampleRate * Int32(numChannels * bitsPerSample / 8)
        let blockAlign: Int16 = numChannels * bitsPerSample / 8
        let numSamples: Int32 = 8000 // 1 giây im lặng
        let dataSize: Int32 = numSamples * Int32(blockAlign)

        var data = Data()
        data.append(contentsOf: [UInt8]("RIFF".utf8))
        var chunkSize: Int32 = 36 + dataSize
        data.append(withUnsafeBytes(of: &chunkSize) { Data($0) })
        data.append(contentsOf: [UInt8]("WAVE".utf8))
        data.append(contentsOf: [UInt8]("fmt ".utf8))
        var subchunk1Size: Int32 = 16
        data.append(withUnsafeBytes(of: &subchunk1Size) { Data($0) })
        var audioFormat: Int16 = 1
        data.append(withUnsafeBytes(of: &audioFormat) { Data($0) })
        var channels: Int16 = numChannels
        data.append(withUnsafeBytes(of: &channels) { Data($0) })
        var rate: Int32 = sampleRate
        data.append(withUnsafeBytes(of: &rate) { Data($0) })
        var bRate: Int32 = byteRate
        data.append(withUnsafeBytes(of: &bRate) { Data($0) })
        var align: Int16 = blockAlign
        data.append(withUnsafeBytes(of: &align) { Data($0) })
        var bits: Int16 = bitsPerSample
        data.append(withUnsafeBytes(of: &bits) { Data($0) })
        data.append(contentsOf: [UInt8]("data".utf8))
        var dSize: Int32 = dataSize
        data.append(withUnsafeBytes(of: &dSize) { Data($0) })
        data.append(Data(repeating: 0, count: Int(dataSize)))
        return data
    }
}
