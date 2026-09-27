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

    public static func getBool(_ field: [String: Any]?) -> Bool {
        return field?["booleanValue"] as? Bool ?? false
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

    public static func getBool(_ fields: [String: Any]?, _ key: String) -> Bool {
        return getBool(fields?[key] as? [String: Any])
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
}
