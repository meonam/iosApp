import Foundation
import UIKit

public enum CloudinaryService {
    public static let cloudName = "nhxhhbqf"
    public static let uploadPreset = "qltb_preset"
    public static let uploadUrl = "https://api.cloudinary.com/v1_1/nhxhhbqf/image/upload"

    public static func uploadImage(
        _ image: UIImage,
        folder: String = "support_chat",
        compressionQuality: CGFloat = 0.85
    ) async -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return await uploadImageData(data, folder: folder)
    }

    public static func uploadImageData(
        _ data: Data,
        folder: String = "support_chat"
    ) async -> String? {
        guard let url = URL(string: uploadUrl) else { return nil }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()

        // 1. upload_preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)

        // 2. folder
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"folder\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(folder)\r\n".data(using: .utf8)!)

        // 3. file
        let filename = "ticket_img_\(Int(Date().timeIntervalSince1970)).jpg"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
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

            guard let json = try JSONSerialization.jsonObject(with: respData) as? [String: Any],
                  let secureUrl = json["secure_url"] as? String else {
                return nil
            }
            return secureUrl
        } catch {
            return nil
        }
    }
}
