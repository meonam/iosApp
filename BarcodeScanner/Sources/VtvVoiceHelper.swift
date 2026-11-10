import Foundation
import AVFoundation

/// Trợ lý phát thông báo giọng đọc Nữ BTV VTV (vi-VN-HoaiMyNeural / en-US-JennyNeural)
/// khi truyền file kiểm kê qua NET hoàn tất trên iOS (đã khuếch đại +10.5dB).
final class VtvVoiceHelper: NSObject {
    static let shared = VtvVoiceHelper()
    
    private var audioPlayer: AVAudioPlayer?
    private var lastPlayedTimestamp: TimeInterval = 0
    
    private override init() {
        super.init()
    }
    
    /// Phát câu thông báo chuẩn VTV:
    /// "File đã được truyền đến bộ phận IT, vui lòng đến máy in để nhận phiếu!"
    func playScanTransferSuccess() {
        let now = Date().timeIntervalSince1970
        if now - lastPlayedTimestamp < 3.0 {
            return
        }
        lastPlayedTimestamp = now
        
        let langCode = Locale.preferredLanguages.first?.lowercased() ?? "vi"
        let resourceName = langCode.hasPrefix("en") ? "voice_scan_sent_en" : "voice_scan_sent_vi"
        
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mp3") else {
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            
            audioPlayer?.stop()
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 1.0
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            print("VtvVoiceHelper error: \(error.localizedDescription)")
        }
    }
}
