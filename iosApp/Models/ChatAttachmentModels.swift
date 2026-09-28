import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - CHAT PENDING ATTACHMENT (ĐỒNG BỘ AndroidPendingAttachment.kt TRÊN ANDROID)
/// Đại diện một tệp đang chờ upload trước khi gửi tin nhắn
public struct ChatPendingAttachment: Identifiable, Equatable {
    public var id = UUID()
    public var data: Data
    public var fileName: String
    public var fileSize: Int64
    /// "image" hoặc "file"
    public var type: String

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

// MARK: - CHAT IMAGE PICKER (PHPickerViewController wrapped for SwiftUI - iOS 14+)
/// Hỗ trợ chọn ảnh từ thư viện, tương thích đầy đủ với iOS 15+
public struct ChatImagePicker: UIViewControllerRepresentable {
    public var maxSelection: Int = 5
    public var onPick: ([UIImage]) -> Void

    public init(maxSelection: Int = 5, onPick: @escaping ([UIImage]) -> Void) {
        self.maxSelection = maxSelection
        self.onPick = onPick
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = max(1, maxSelection)
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    public class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: ([UIImage]) -> Void

        init(onPick: @escaping ([UIImage]) -> Void) {
            self.onPick = onPick
        }

        public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return }

            var loadedImages: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        defer { group.leave() }
                        if let img = object as? UIImage {
                            loadedImages.append(img)
                        }
                    }
                }
            }

            group.notify(queue: .main) {
                self.onPick(loadedImages)
            }
        }
    }
}

// MARK: - CHAT DOCUMENT PICKER (UIDocumentPickerViewController wrapped for SwiftUI)
/// Cho phép chọn bất kỳ loại tệp nào (PDF, Word, Excel, ZIP, APK, v.v.)
public struct ChatDocumentPicker: UIViewControllerRepresentable {
    public let onPick: ([URL]) -> Void

    public init(onPick: @escaping ([URL]) -> Void) {
        self.onPick = onPick
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    public func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
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
