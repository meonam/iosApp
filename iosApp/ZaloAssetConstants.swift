import SwiftUI

public struct ZaloReactionItem: Identifiable, Hashable, Sendable {
    public var id: String { emoji }
    public let emoji: String
    public let name: String
    public let iconUrl: String

    public init(emoji: String, name: String, iconUrl: String) {
        self.emoji = emoji
        self.name = name
        self.iconUrl = iconUrl
    }
}

public struct ZaloIconItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let code: String
    public let iconUrl: String

    public init(id: String, code: String, iconUrl: String) {
        self.id = id
        self.code = code
        self.iconUrl = iconUrl
    }
}

public enum ZaloAssetConstants {
    public static let cdnBase = "https://res.cloudinary.com/nhxhhbqf/image/upload/q_auto,f_auto"

    // 6 Biểu cảm Reaction Zalo chuẩn Android ZaloAssetConstants.kt
    public static let reactions: [ZaloReactionItem] = [
        ZaloReactionItem(emoji: "❤️", name: "Thả tim", iconUrl: "\(cdnBase)/v1/zalo_reactions/heart.png"),
        ZaloReactionItem(emoji: "👍", name: "Thích", iconUrl: "\(cdnBase)/v1/zalo_reactions/like.png"),
        ZaloReactionItem(emoji: "😄", name: "Haha", iconUrl: "\(cdnBase)/v1/zalo_reactions/laugh.png"),
        ZaloReactionItem(emoji: "😮", name: "Wow", iconUrl: "\(cdnBase)/v1/zalo_reactions/wow.png"),
        ZaloReactionItem(emoji: "😢", name: "Buồn", iconUrl: "\(cdnBase)/v1/zalo_reactions/sad.png"),
        ZaloReactionItem(emoji: "😡", name: "Tức giận", iconUrl: "\(cdnBase)/v1/zalo_reactions/angry.png")
    ]

    // 63 Icon Zalo
    public static let icons: [ZaloIconItem] = (1...63).map { i in
        let numStr = String(format: "%02d", i)
        let id = "zalo_icon_\(numStr)"
        let code = ":zalo_\(numStr):"
        let iconUrl = "\(cdnBase)/v1/zalo_icons/\(id).png"
        return ZaloIconItem(id: id, code: code, iconUrl: iconUrl)
    }

    public static let iconMap: [String: ZaloIconItem] = Dictionary(uniqueKeysWithValues: icons.map { ($0.code, $0) })
}

// MARK: - Zalo Reaction Bar View (Floating quick reaction bar)
public struct ZaloReactionBar: View {
    public let onSelectEmoji: (String) -> Void

    public init(onSelectEmoji: @escaping (String) -> Void) {
        self.onSelectEmoji = onSelectEmoji
    }

    public var body: some View {
        HStack(spacing: 12) {
            ForEach(ZaloAssetConstants.reactions) { item in
                Button(action: {
                    onSelectEmoji(item.emoji)
                }) {
                    VStack(spacing: 2) {
                        Text(item.emoji)
                            .font(.system(size: 26))
                            .scaleEffect(1.0)
                        Text(item.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Zalo Icon Picker Sheet (Grid of 63 icons)
public struct ZaloIconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let onSelectCode: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 44, maximum: 54), spacing: 10)
    ]

    public init(onSelectCode: @escaping (String) -> Void) {
        self.onSelectCode = onSelectCode
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ZaloAssetConstants.icons) { item in
                        Button(action: {
                            onSelectCode(item.code)
                            dismiss()
                        }) {
                            AsyncImage(url: URL(string: item.iconUrl)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 38, height: 38)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 38, height: 38)
                                case .failure:
                                    Image(systemName: "face.smiling")
                                        .font(.system(size: 24))
                                        .foregroundColor(.appPrimaryPink)
                                        .frame(width: 38, height: 38)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(6)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Bộ Icon Zalo (63 icons)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.appPrimaryPink)
                }
            }
        }
    }
}
