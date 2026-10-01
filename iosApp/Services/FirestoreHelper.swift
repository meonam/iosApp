import Foundation

// MARK: - FIRESTORE REST VALUE HELPER
public struct FirestoreHelper {
    public static func getString(_ field: [String: Any]?) -> String {
        return field?["stringValue"] as? String ?? ""
    }

    public static func getInt64(_ field: [String: Any]?) -> Int64 {
        if let str = field?["integerValue"] as? String, let val = Int64(str) {
            return val
        }
        if let num = field?["integerValue"] as? Int64 {
            return num
        }
        if let num = field?["integerValue"] as? Int {
            return Int64(num)
        }
        return 0
    }

    public static func getInt(_ field: [String: Any]?) -> Int {
        return Int(getInt64(field))
    }

    public static func getDouble(_ field: [String: Any]?) -> Double {
        if let d = field?["doubleValue"] as? Double {
            return d
        }
        if let str = field?["doubleValue"] as? String, let val = Double(str) {
            return val
        }
        return Double(getInt64(field))
    }

    public static func getBool(_ field: [String: Any]?, defaultValue: Bool = false) -> Bool {
        if let b = field?["booleanValue"] as? Bool { return b }
        if let s = field?["stringValue"] as? String { return s.lowercased() == "true" || s == "1" }
        if let i = field?["integerValue"] as? String { return i == "1" }
        return defaultValue
    }

    public static func getArray(_ field: [String: Any]?) -> [[String: Any]] {
        if let arrObj = field?["arrayValue"] as? [String: Any],
           let values = arrObj["values"] as? [[String: Any]] {
            return values
        }
        return []
    }

    public static func getStringArray(_ field: [String: Any]?) -> [String] {
        return getArray(field).compactMap { $0["stringValue"] as? String }
    }

    public static func getMap(_ field: [String: Any]?) -> [String: Any] {
        if let mapObj = field?["mapValue"] as? [String: Any],
           let fields = mapObj["fields"] as? [String: Any] {
            return fields
        }
        return [:]
    }

    // MARK: - 2-Parameter Convenience Overloads (dictionary + key)
    public static func getString(_ fields: [String: Any]?, _ key: String) -> String {
        return getString(fields?[key] as? [String: Any])
    }

    public static func getInt64(_ fields: [String: Any]?, _ key: String) -> Int64 {
        return getInt64(fields?[key] as? [String: Any])
    }

    public static func getInt(_ fields: [String: Any]?, _ key: String) -> Int {
        return getInt(fields?[key] as? [String: Any])
    }

    public static func getDouble(_ fields: [String: Any]?, _ key: String) -> Double {
        return getDouble(fields?[key] as? [String: Any])
    }

    public static func getBool(_ fields: [String: Any]?, _ key: String, defaultValue: Bool = false) -> Bool {
        return getBool(fields?[key] as? [String: Any], defaultValue: defaultValue)
    }

    public static func getArray(_ fields: [String: Any]?, _ key: String) -> [[String: Any]] {
        return getArray(fields?[key] as? [String: Any])
    }

    public static func getStringArray(_ fields: [String: Any]?, _ key: String) -> [String] {
        return getStringArray(fields?[key] as? [String: Any])
    }

    public static func getMap(_ fields: [String: Any]?, _ key: String) -> [String: Any] {
        return getMap(fields?[key] as? [String: Any])
    }

    // Tiện ích đóng gói Swift Value sang Firestore REST format
    public static func valueToFirestore(_ value: Any) -> [String: Any] {
        if let str = value as? String {
            return ["stringValue": str]
        } else if let b = value as? Bool {
            return ["booleanValue": b]
        } else if let num = value as? Int64 {
            return ["integerValue": String(num)]
        } else if let num = value as? Int {
            return ["integerValue": String(num)]
        } else if let num = value as? Double {
            return ["doubleValue": num]
        } else if let arr = value as? [String] {
            return ["arrayValue": ["values": arr.map { ["stringValue": $0] }]]
        } else if let dict = value as? [String: String] {
            var fields: [String: Any] = [:]
            for (k, v) in dict { fields[k] = ["stringValue": v] }
            return ["mapValue": ["fields": fields]]
        }
        return ["stringValue": "\(value)"]
    }

    // MARK: - BULLETPROOF FIRESTORE REST EXECUTOR
    @discardableResult
    public static func executeSafeRequest(_ originalRequest: URLRequest, timeoutInterval: TimeInterval = 15.0) async -> (Data, HTTPURLResponse)? {
        var req = originalRequest
        req.timeoutInterval = timeoutInterval

        // 1. Sanitize Authorization header:
        // Only keep Bearer token if it looks like a valid Firebase JWT (starts with "Bearer ey" and length > 40).
        // Non-JWT tokens like "token_<uuid>" cause Google Cloud Identity Gateway to immediately return 401.
        let authHeader = req.value(forHTTPHeaderField: "Authorization") ?? ""
        var hadBearer = false
        if !authHeader.isEmpty {
            if authHeader.hasPrefix("Bearer ") {
                let tokenPart = String(authHeader.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
                if tokenPart.hasPrefix("ey") && tokenPart.count > 40 {
                    hadBearer = true
                } else {
                    req.setValue(nil, forHTTPHeaderField: "Authorization")
                }
            } else {
                hadBearer = true
            }
        }

        // 2. Perform request
        if let (data, response) = try? await URLSession.shared.data(for: req),
           let httpResponse = response as? HTTPURLResponse {

            // Success (200...299)
            if (200...299).contains(httpResponse.statusCode) {
                return (data, httpResponse)
            }

            // 3. Fallback on 401 Unauthorized or 403 Forbidden:
            // If the token was rejected (expired or invalid), retry WITHOUT Authorization header.
            // Firestore rules allow public access ('allow read: if true;').
            if (httpResponse.statusCode == 401 || httpResponse.statusCode == 403) && hadBearer {
                var retryReq = originalRequest
                retryReq.timeoutInterval = timeoutInterval
                retryReq.setValue(nil, forHTTPHeaderField: "Authorization")
                if let (retryData, retryResponse) = try? await URLSession.shared.data(for: retryReq),
                   let retryHttp = retryResponse as? HTTPURLResponse,
                   (200...299).contains(retryHttp.statusCode) {
                    return (retryData, retryHttp)
                }
            }

            return (data, httpResponse)
        }

        // 4. In case of network failure/timeout, attempt one fallback retry without Authorization
        var fallbackReq = originalRequest
        fallbackReq.timeoutInterval = timeoutInterval
        fallbackReq.setValue(nil, forHTTPHeaderField: "Authorization")
        if let (data, response) = try? await URLSession.shared.data(for: fallbackReq),
           let httpResponse = response as? HTTPURLResponse {
            return (data, httpResponse)
        }

        return nil
    }

    public static func safeGet(url: URL, idToken: String = "") async -> (data: Data, statusCode: Int)? {
        var req = URLRequest(url: url)
        if !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = await executeSafeRequest(req) else { return nil }
        return (data, resp.statusCode)
    }

    public static func safePost(url: URL, body: Data, idToken: String = "") async -> (data: Data, statusCode: Int)? {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        if !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = await executeSafeRequest(req) else { return nil }
        return (data, resp.statusCode)
    }

    public static func safePatch(url: URL, body: Data, idToken: String = "") async -> (data: Data, statusCode: Int)? {
        var req = URLRequest(url: url)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        if !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = await executeSafeRequest(req) else { return nil }
        return (data, resp.statusCode)
    }

    public static func safeDelete(url: URL, idToken: String = "") async -> (data: Data, statusCode: Int)? {
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        if !idToken.isEmpty {
            req.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, resp) = await executeSafeRequest(req) else { return nil }
        return (data, resp.statusCode)
    }
}
