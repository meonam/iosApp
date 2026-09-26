import Foundation

// MARK: - FIREBASE CONFIGURATION
public struct FirebaseConfig {
    public static let projectId = "qltb-77c8e"
    public static let apiKey = "AIzaSyCgAfxXX-3MzpT0RT5BIDiww6iDwtkADzM"

    public static let firestoreBaseUrl = "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents"
    public static let authSignInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)"
    public static let authSignUpUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(apiKey)"
    public static let authSendOobUrl = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=\(apiKey)"
    public static let authUpdateUrl = "https://identitytoolkit.googleapis.com/v1/accounts:update?key=\(apiKey)"
}
