import SwiftUI
import UIKit

public struct ShareActivityView: UIViewControllerRepresentable {
    public let activityItems: [Any]
    public let applicationActivities: [UIActivity]? = nil

    public init(activityItems: [Any]) {
        self.activityItems = activityItems
    }

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

public struct MediaViewerSheet: View {
    public let imageUrl: String
    public let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isSharing: Bool = false

    public init(imageUrl: String, title: String = "Hình ảnh đính kèm") {
        self.imageUrl = imageUrl
        self.title = title
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    Spacer()

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Button(action: { isSharing = true }) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 10)

                Spacer()

                // Pinch-to-zoom image
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 1.0), 4.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    }
                                    .simultaneously(with:
                                        DragGesture()
                                            .onChanged { value in
                                                if scale > 1.0 {
                                                    offset = CGSize(
                                                        width: lastOffset.width + value.translation.width,
                                                        height: lastOffset.height + value.translation.height
                                                    )
                                                }
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                    )
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.6))
                            Text("Không tải được ảnh từ máy chủ")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                Text("Chụm/mở 2 ngón tay để thu phóng • Chạm 2 lần để phóng to")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $isSharing) {
            if let url = URL(string: imageUrl) {
                ShareActivityView(activityItems: [url])
            }
        }
    }
}
