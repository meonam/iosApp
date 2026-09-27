import SwiftUI

// MARK: - COMPANY BANNER TICKER VIEW (ĐỒNG BỘ 1:1 THEO COMPANYBANNERTICKER.KT TRÊN ANDROID)
public struct CompanyBannerTickerView: View {
    public enum BannerType: String {
        case info = "INFO"
        case warning = "WARNING"
        case maintenance = "MAINTENANCE"
    }

    var text: String
    var type: BannerType
    var isActive: Bool

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    public init(
        text: String = "",
        type: BannerType = .info,
        isActive: Bool = false
    ) {
        self.text = text
        self.type = type
        self.isActive = isActive
    }

    private var backgroundColor: Color {
        switch type {
        case .warning:
            return Color(hex: "#FEF3C7")
        case .maintenance:
            return Color(hex: "#F3E8FF")
        case .info:
            return Color(hex: "#EFF6FF")
        }
    }

    private var textColor: Color {
        switch type {
        case .warning:
            return Color(hex: "#92400E")
        case .maintenance:
            return Color(hex: "#6B21A8")
        case .info:
            return Color(hex: "#1E40AF")
        }
    }

    private var borderColor: Color {
        switch type {
        case .warning:
            return Color(hex: "#FCD34D")
        case .maintenance:
            return Color(hex: "#D8B4FE")
        case .info:
            return Color(hex: "#BFDBFE")
        }
    }

    private var iconName: String {
        switch type {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .info:
            return "megaphone.fill"
        }
    }

    private var cleanedText: String {
        text.replacingOccurrences(of: "\r\n", with: "  •  ")
            .replacingOccurrences(of: "\n", with: "  •  ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        if isActive && !cleanedText.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(textColor)

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Text(cleanedText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(textColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .background(
                                GeometryReader { textGeo in
                                    Color.clear.preference(
                                        key: TickerTextWidthPreferenceKey.self,
                                        value: textGeo.size.width
                                    )
                                }
                            )
                            .offset(x: offset)
                    }
                    .frame(width: w, alignment: .leading)
                    .clipped()
                    .onAppear {
                        containerWidth = w
                        startAnimationIfNeeded()
                    }
                    .onChange(of: w) { newWidth in
                        containerWidth = newWidth
                        startAnimationIfNeeded()
                    }
                }
                .frame(height: 18)
                .onPreferenceChange(TickerTextWidthPreferenceKey.self) { newTextWidth in
                    textWidth = newTextWidth
                    startAnimationIfNeeded()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: 1)
            )
        }
    }

    private func startAnimationIfNeeded() {
        guard textWidth > containerWidth && containerWidth > 0 else {
            offset = 0
            return
        }

        let totalDistance = textWidth + containerWidth
        let duration = Double(totalDistance) / 45.0 // Tốc độ trôi chữ ~45pt/giây

        offset = containerWidth
        withAnimation(
            Animation.linear(duration: duration)
                .repeatForever(autoreverses: false)
                .delay(0.5)
        ) {
            offset = -textWidth
        }
    }
}

private struct TickerTextWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
