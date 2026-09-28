import SwiftUI
import UniformTypeIdentifiers

// MARK: - CHAT PENDING ATTACHMENT (ĐỒNG BỘ AndroidPendingAttachment.kt TRÊN ANDROID)
/// Đại diện một tệp đang chờ upload trước khi gửi tin nhắn
public struct ChatPendingAttachment: Identifiable, Equatable {
    public let id: UUID = UUID()
    public let data: Data
    public let fileName: String
    public let fileSize: Int64
    /// "image" hoặc "file"
    public let type: String

    public init(data: Data, fileName: String, fileSize: Int64, type: String) {
        self.data = data
        self.fileName = fileName
        self.fileSize = fileSize
        self.type = type
    }

    public static func == (lhs: ChatPendingAttachment, rhs: ChatPendingAttachment) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - CHAT DOCUMENT PICKER (UIDocumentPickerViewController wrapped for SwiftUI)
/// Wrapper UIViewControllerRepresentable cho UIDocumentPickerViewController
/// Cho phép chọn bất kỳ loại tệp nào (PDF, Word, Excel, ZIP, APK, v.v.)
public struct ChatDocumentPicker: UIViewControllerRepresentable {
    let onPick: ([URL]) -> Void

    public init(onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Cho phép tất cả loại tệp
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }

    public func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    public class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
