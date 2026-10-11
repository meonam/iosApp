import Foundation

// MARK: - FIREBASE CONFIGURATION (ĐỒNG BỘ 1:1 VỚI ANDROID QLTB-81F4C)
public struct FirebaseConfig {
    public static let projectId = "qltb-81f4c"
    public static let apiKey = "AIzaSyAehFfYkaZZnaOw3zXQNxokB21D2XcUG6A"

    // ĐÃ CHUYỂN HOÀN TOÀN SANG MÁY ẢO GOOGLE CLOUD VM (136.80.195.63)
    public static let serverBaseUrl = "http://136.80.195.63"
    public static let firestoreBaseUrl = "http://136.80.195.63/v1/projects/\(projectId)/databases/(default)/documents"
    public static let authSignInUrl = "http://136.80.195.63/v1/accounts:signInWithPassword?key=\(apiKey)"
    public static let authSignUpUrl = "http://136.80.195.63/v1/accounts:signUp?key=\(apiKey)"
    public static let authSendOobUrl = "http://136.80.195.63/v1/accounts:sendOobCode?key=\(apiKey)"
    public static let authUpdateUrl = "http://136.80.195.63/v1/accounts:update?key=\(apiKey)"
    public static let storageBucket = "qltb-81f4c.firebasestorage.app"
    
    // WebRTC Signaling & CoTurn STUN/TURN
    public static let stunServer = "stun:136.80.195.63:3478"
    public static let turnServer = "turn:136.80.195.63:3478"
    public static let turnUsername = "qltbuser"
    public static let turnPassword = "QltbTurn2026!"
    public static let wsSignalingUrl = "ws://136.80.195.63/ws"
}
