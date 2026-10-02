import Foundation

// MARK: - FIREBASE STORAGE SERVICE (ĐỒNG BỘ 1:1 THEO FIREBASESTORAGEHELPER.KT TRÊN ANDROID)
/// Dịch vụ quản lý tải tệp đính kèm tài liệu, hình ảnh lên Firebase Storage với cơ chế tự động Fallback sang Cloudinary
public enum FirebaseStorageService {
    private static let tag = "FirebaseStorageService"

    /// Tải tệp đính kèm văn bản, tài liệu, hình ảnh (PDF, Word, Excel, CSV, Text, PNG, JPG...) lên Firebase Storage.
    /// Cấu trúc đường dẫn đồng bộ 100% với Web app & Android:
    /// companies/{companyId}/ticket_attachments/{ticketId}/{timestamp}_{cleanFileName}
    public static func uploadTicketAttachment(
        data: Data,
        companyId: String,
        ticketId: String,
        fileName: String,
        mimeType: String = "",
        idToken: String = ""
    ) async -> String? {
        let cleanComp = companyId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "SGCOOP" : companyId.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let cleanTicketId = ticketId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "temp_ticket" : ticketId.trimmingCharacters(in: .whitespacesAndNewlines)
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let cleanFileName = fileName.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        let storagePath = "companies/\(cleanComp)/ticket_attachments/\(cleanTicketId)/\(timestamp)_\(cleanFileName)"
        let resolvedContentType = resolveMimeType(fileName: fileName, customMime: mimeType)

        // 1. Cố gắng tải lên Firebase Storage thông qua Google Cloud Storage / Firebase Storage REST API
        if let firebaseUrl = await uploadToFirebaseStorage(
            data: data,
            storagePath: storagePath,
            contentType: resolvedContentType,
            idToken: idToken
        ) {
            print("[\(tag)] ✅ Tải tệp lên Firebase Storage thành công: \(firebaseUrl)")
            return firebaseUrl
        }

        // 2. Tự động Fallback sang Cloudinary giống Android FirebaseStorageHelper.kt (lines 80-82)
        print("[\(tag)] ⚠️ Tải tệp lên Firebase Storage thất bại (Bucket chưa sẵn sàng hoặc không cấp quyền), chuyển fallback sang Cloudinary...")
        let isImage = ["jpg", "jpeg", "png", "webp", "gif", "bmp"].contains((fileName as NSString).pathExtension.lowercased())
        if isImage {
            return await CloudinaryService.uploadImageData(data, folder: "support_tickets")
        } else {
            return await CloudinaryService.uploadRawData(data, folder: "support_tickets", fileName: fileName)
        }
    }

    /// Upload tệp lên Firebase Storage REST API
    private static func uploadToFirebaseStorage(
        data: Data,
        storagePath: String,
        contentType: String,
        idToken: String
    ) async -> String? {
        guard let encodedName = storagePath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/\(FirebaseConfig.storageBucket)/o?uploadType=media&name=\(encodedName)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45

        let trimmedToken = idToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedToken.isEmpty {
            request.setValue("Bearer \(trimmedToken)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = data

        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                return nil
            }

            // Đường dẫn download chuẩn Firebase: /v0/b/<bucket>/o/<escapedPath>?alt=media&token=<token>
            let escapedPath = storagePath.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? storagePath
            if let downloadTokens = json["downloadTokens"] as? String,
               let firstToken = downloadTokens.split(separator: ",").first {
                return "https://firebasestorage.googleapis.com/v0/b/\(FirebaseConfig.storageBucket)/o/\(escapedPath)?alt=media&token=\(firstToken)"
            }

            return "https://firebasestorage.googleapis.com/v0/b/\(FirebaseConfig.storageBucket)/o/\(escapedPath)?alt=media"
        } catch {
            return nil
        }
    }

    /// Xác định MIME Type chuẩn theo phần mở rộng của tệp
    public static func resolveMimeType(fileName: String, customMime: String = "") -> String {
        if !customMime.isEmpty && customMime != "application/octet-stream" && customMime != "other" && customMime != "file" {
            return customMime
        }

        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "csv": return "text/csv"
        case "txt": return "text/plain"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html", "htm": return "text/html"
        case "zip": return "application/zip"
        case "rar": return "application/x-rar-compressed"
        case "7z": return "application/x-7z-compressed"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }
}
