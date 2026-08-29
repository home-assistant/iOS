#if !os(watchOS)
import HAIconic
import SwiftUI

/// What is playing, with transport controls. The SwiftUI counterpart of the frontend's
/// `hui-media-control-card`.
///
/// The card is a flat block of the player's colour with the artwork as a **square on the trailing
/// edge**, faded into the block by a gradient — not a full-bleed image behind everything. That is
/// the frontend's `.color-block` / `.image` / `.color-gradient` layering, and it is what keeps the
/// title legible whatever the cover art looks like.
///
/// For the same reason the text colour is derived from the background rather than hardcoded: the
/// frontend takes the dominant colour of the artwork and contrasts against it, so a yellow cover
/// gets dark text and a black one gets light text.
public struct HAMediaControlCard: View {
    private static let controlSize: CGFloat = 26
    private static let playControlSize: CGFloat = 32

    private let name: String
    private let icon: MaterialDesignIcons
    private let title: String?
    private let subtitle: String?
    private let artwork: Image?
    private let accent: Color
    private let height: CGFloat
    private let isPlaying: Bool
    private let progress: Double?
    private let onPlayPause: (() -> Void)?
    private let onPrevious: (() -> Void)?
    private let onNext: (() -> Void)?
    private let onMore: (() -> Void)?

    /// - Parameters:
    ///   - accent: The card's block colour. The frontend derives it from the artwork; here it is the
    ///     caller's, since extracting a dominant colour needs the decoded image.
    ///   - height: The card's height, which is also the artwork square's side — the frontend sets
    ///     the image's width from the card's height for exactly that reason.
    ///   - progress: How far through, 0…1. `nil` hides the bar, as the frontend does for a stream
    ///     with no known duration.
    public init(
        name: String,
        icon: MaterialDesignIcons = .speakerIcon,
        title: String? = nil,
        subtitle: String? = nil,
        artwork: Image? = nil,
        accent: Color = .haPrimary,
        height: CGFloat = 150,
        isPlaying: Bool = false,
        progress: Double? = nil,
        onPlayPause: (() -> Void)? = nil,
        onPrevious: (() -> Void)? = nil,
        onNext: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil
    ) {
        self.name = name
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
        self.accent = accent
        self.height = height
        self.isPlaying = isPlaying
        self.progress = progress
        self.onPlayPause = onPlayPause
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onMore = onMore
    }

    /// Black or white against the block colour, the frontend's `getContrastedColorHex` — which is
    /// why this shares ``ColorContrast`` with ``HALabel`` and ``HAQRCode``.
    private var foreground: Color {
        ColorContrast.contrastingForeground(on: accent)
    }

    public var body: some View {
        HACard {
            ZStack(alignment: .topLeading) {
                background
                content
            }
            .frame(height: height)
            .foregroundStyle(foreground)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(name))
    }

    // MARK: - Background

    private var background: some View {
        ZStack(alignment: .trailing) {
            accent
            if let artwork {
                artwork
                    .resizable()
                    .scaledToFill()
                    .frame(width: height, height: height)
                    .clipped()
                    // The block colour fading out across the artwork's leading edge, so the image
                    // does not start with a hard vertical seam.
                    .overlay {
                        LinearGradient(
                            colors: [accent, accent.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            topInfo
            Spacer(minLength: DesignSystem.Spaces.one)
            if let title {
                Text(title)
                    .font(DesignSystem.Font.title3)
                    .lineLimit(1)
            }
            if let subtitle {
                Text(subtitle)
                    .font(DesignSystem.Font.subheadline)
                    .opacity(0.8)
                    .lineLimit(1)
            }
            // Under the text and left-aligned, not beside it: the frontend stacks the transport
            // below the title so the artwork keeps the trailing half of the card to itself.
            controls
            if let progress {
                progressBar(progress)
            }
        }
        .padding(DesignSystem.Spaces.two)
    }

    private var topInfo: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            MaterialDesignIconsImage(icon: icon, size: 22)
            Text(name)
                .font(DesignSystem.Font.body)
                .lineLimit(1)
            Spacer(minLength: DesignSystem.Spaces.one)
            if let onMore {
                Button(action: onMore) {
                    MaterialDesignIconsImage(icon: .dotsVerticalIcon, size: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(HADesignSystemEnvironment.current.strings.moreInformation))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: DesignSystem.Spaces.two) {
            if let onPrevious {
                control(.skipPreviousIcon, action: onPrevious)
            }
            if let onPlayPause {
                control(isPlaying ? .pauseIcon : .playIcon, action: onPlayPause, size: Self.playControlSize)
            }
            if let onNext {
                control(.skipNextIcon, action: onNext)
            }
            Spacer(minLength: .zero)
        }
    }

    private func control(
        _ icon: MaterialDesignIcons,
        action: @escaping () -> Void,
        size: CGFloat = HAMediaControlCard.controlSize
    ) -> some View {
        Button(action: action) {
            MaterialDesignIconsImage(icon: icon, size: size)
        }
        .buttonStyle(.plain)
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(foreground.opacity(0.25))
                Capsule()
                    .fill(foreground)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HAMediaControlCard(
            name: "Living room",
            title: "Speak to Me",
            subtitle: "Pink Floyd",
            accent: .haPrimary,
            isPlaying: true,
            progress: 0.35,
            onPlayPause: {},
            onPrevious: {},
            onNext: {},
            onMore: {}
        )
        // A pale block takes dark text, exactly as the frontend's contrast rule decides.
        HAMediaControlCard(
            name: "Kitchen",
            title: "I Wanna Be A Hippy",
            subtitle: "Technohead",
            accent: .yellow,
            isPlaying: false,
            progress: 0.1,
            onPlayPause: {},
            onPrevious: {},
            onNext: {}
        )
        HAMediaControlCard(name: "Kitchen speaker", accent: .haDisabled)
    }
    .padding()
    .background(Color.haNeutralQuietFill)
}

extension HAMediaControlCard: FrontendComponent {
    public static var frontendComponentName: String { "hui-media-control-card" }
}
#endif
