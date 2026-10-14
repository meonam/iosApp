import Foundation
import UIKit

// MARK: - CLOUDINARY SERVICE (ĐÃ CHUYỂN HƯỚNG 100% SANG Ổ CỨNG MÁY CHỦ NỘI BỘ QLTB SERVER 103.179.172.229)
public enum CloudinaryService {
    public static let uploadUrl = "https://103.179.172.229.sslip.io/api/storage/upload"
    public static let fallbackUploadUrl = "http://103.179.172.229/api/storage/upload"

    public static func uploadImage(
        _ image: UIImage,
        folder: String = "general",
        compressionQuality: CGFloat = 0.85
    ) async -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return await uploadImageData(data, folder: folder)
    }

    public static func uploadImageData(
        _ data: Data,
        folder: String = "general"
    ) async -> String? {
        guard let url = URL(string: uploadUrl) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()

        // 1. folder
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(folder)\r\n".data(using: .utf8)!)

        // 2. file
        let filename = "img_\(Int(Date().timeIntervalSince1970)).jpg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (respData, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
                return nil
            }
            if let secureUrl = json["secure_url"] as? String {
                return secureUrl
            }
            return json["url"] as? String
        } catch {
            return nil
        }
    }

    /// Tải tệp tài liệu, văn bản (PDF, Word, Excel, CSV, Text...) lên ổ cứng máy chủ nội bộ
    public static func uploadRawData(
        _ data: Data,
        folder: String = "support_tickets",
        fileName: String = "attachment.dat"
    ) async -> String? {
        let safeFileName = fileName.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        guard let url = URL(string: uploadUrl) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        var body = Data()

        // 1. folder
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(folder)\r\n".data(using: .utf8)!)

        // 2. file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (respData, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any] else {
                return nil
            }
            if let secureUrl = json["secure_url"] as? String {
                return secureUrl
            }
            return json["url"] as? String
        } catch {
            return nil
        }
    }
}

