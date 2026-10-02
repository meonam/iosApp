import Foundation

// MARK: - FIREBASE CONFIGURATION (ĐỒNG BỘ 1:1 VỚI ANDROID QLTB-81F4C)
public struct FirebaseConfig {
    public static let projectId = "qltb-81f4c"
    public static let apiKey = "AIzaSyAehFfYkaZZnaOw3zXQNxokB21D2XcUG6A"

    public static let firestoreBaseUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    public static let authSignInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)"
    public static let authSignUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)"
    public static let authSendOobUrl = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(apiKey)"
    public static let authUpdateUrl = "https://identitytoolkit.googleapis.com/v1/accounts:update?key=\(apiKey)"
    public static let storageBucket = "qltb-81f4c.firebasestorage.app"
}
