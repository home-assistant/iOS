import HAIconic
import SwiftUI
import UIKit

/// Animated orb shown while Assist is listening. Voice activity is shown by a plain circle behind the
/// orb that grows and shrinks with the microphone input level (0...1), no glow or shadow involved.
public struct AssistVoiceOrbView: View {
    private let level: Double
    private let size: AssistVoiceOrbSize
    private let accessibilityLabel: String
    /// Renders the pre-iOS 26 fill and border instead of Liquid Glass, so the legacy look stays
    /// previewable alongside the current one.
    private let forcesLegacyAppearance: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.assistOrbFixedTime) private var fixedTime

    public init(
        level: Double,
        size: AssistVoiceOrbSize = .regular,
        accessibilityLabel: String,
        forcesLegacyAppearance: Bool = false
    ) {
        self.level = level
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.forcesLegacyAppearance = forcesLegacyAppearance
    }

    private enum Constants {
        struct Blob {
            let lightColor: Color
            let darkColor: Color
            let speed: Double
            let phase: Double

            func color(for colorScheme: ColorScheme) -> Color {
                colorScheme == .dark ? darkColor : lightColor
            }
        }

        /// Dark mode takes the deep end of the palette, where the white microphone glyph still reads
        /// against the blend of the three: the light blobs are the brightest thing on a dark screen and
        /// swallow the glyph. The spread between the darkest and the brightest is kept wide, or the orb
        /// flattens into one dull disc once the colours come down.
        static let blobs: [Blob] = [
            .init(lightColor: .cyan, darkColor: .cyan50, speed: 1.6, phase: 0),
            .init(lightColor: .haPrimary, darkColor: .brand30, speed: -2.1, phase: 2.1),
            .init(lightColor: .teal, darkColor: .cyan30, speed: 2.7, phase: 4.2),
        ]

        /// What the orb has to tell apart from the screen behind it, which is white in light mode and
        /// near black in dark mode, so these values cannot be shared between the two. The watch has no
        /// light mode, so there it is always the dark one.
        struct Appearance {
            let activityCircleColor: Color
            let activityCircleOpacity: Double
            let orbBackgroundOpacity: Double
            let orbGlassTintOpacity: Double
            let microphoneOpacity: Double

            static let light = Appearance(
                activityCircleColor: .haPrimary,
                activityCircleOpacity: 0.25,
                orbBackgroundOpacity: 0.35,
                orbGlassTintOpacity: 0.5,
                microphoneOpacity: 0.9
            )

            /// `haPrimary` at a quarter opacity is all but black against a dark background, so the
            /// activity circle switches to a light blue and leans on it harder to stay visible. The
            /// orb's own fill and glass tint pull back instead, since in dark mode they are what buries
            /// the microphone glyph.
            static let dark = Appearance(
                activityCircleColor: .brand60,
                activityCircleOpacity: 0.35,
                orbBackgroundOpacity: 0.25,
                orbGlassTintOpacity: 0.3,
                microphoneOpacity: 1
            )

            static func matching(_ colorScheme: ColorScheme) -> Appearance {
                colorScheme == .dark ? .dark : .light
            }
        }

        /// The lengths that change with the orb's size. The scale factors, the palette and the timings
        /// are shared, so the two sizes move identically — one is just drawn bigger than the other.
        struct Metrics {
            let orbSize: CGFloat
            let activityCircleSize: CGFloat
            let blobSize: CGFloat
            let blobBlurRadius: CGFloat
            let blobOffset: CGFloat
            let blobOffsetPerLevel: CGFloat
            /// Drawing the glyph is a text render into a bitmap, and the body below runs on every frame
            /// of the animation timeline, so it is rasterized once per size here instead.
            let microphoneImage: UIImage

            static let regular = Metrics(
                orbSize: 64,
                activityCircleSize: 64,
                blobSize: 42,
                blobBlurRadius: 10,
                blobOffset: 7,
                blobOffsetPerLevel: 15,
                microphoneImage: microphoneGlyph(ofSide: 30)
            )

            /// An eighth larger than `regular`: on the watch the orb stands alone in the middle of the
            /// screen, and the loudest activity circle is still only 115pt across — inside the 176pt of
            /// the smallest watch.
            static let watch = Metrics(
                orbSize: 72,
                activityCircleSize: 72,
                blobSize: 48,
                blobBlurRadius: 11,
                blobOffset: 8,
                blobOffsetPerLevel: 17,
                microphoneImage: microphoneGlyph(ofSide: 34)
            )

            static func matching(_ size: AssistVoiceOrbSize) -> Metrics {
                switch size {
                case .regular: Metrics.regular
                case .watch: Metrics.watch
                }
            }

            private static func microphoneGlyph(ofSide side: CGFloat) -> UIImage {
                MaterialDesignIcons.microphoneIcon.image(
                    ofSize: CGSize(width: side, height: side),
                    color: .white
                )
            }
        }

        /// Hidden behind the orb at silence and growing when talking, so the size change is the thing
        /// the user notices. The per-level factor is capped by the room between the orb's centre and
        /// the bottom of the screen: at 0.6 the loudest ring is 102pt wide and still lands on screen.
        static let activityCircleScale: CGFloat = 1
        static let activityCircleScalePerLevel: CGFloat = 0.6

        static let orbScalePerLevel: CGFloat = 0.25
        static let orbBorderStartOpacity: Double = 0.55
        static let orbBorderEndOpacity: Double = 0.08
        static let orbBorderWidth: CGFloat = DesignSystem.Border.Width.default

        /// The vertical wobble runs slightly slower than the horizontal one, so the blobs trace ellipses.
        static let blobVerticalSpeedRatio: Double = 0.8

        static let levelAnimation: Animation = .easeOut(duration: 0.1)
    }

    public var body: some View {
        Group {
            if let fixedTime {
                orb(at: fixedTime)
            } else {
                TimelineView(.animation) { context in
                    orb(at: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .animation(Constants.levelAnimation, value: level)
        .accessibilityLabel(accessibilityLabel)
    }

    private func orb(at time: TimeInterval) -> some View {
        let appearance = Constants.Appearance.matching(colorScheme)
        let metrics = Constants.Metrics.matching(size)

        return ZStack {
            Circle()
                .fill(appearance.activityCircleColor.opacity(appearance.activityCircleOpacity))
                .frame(width: metrics.activityCircleSize, height: metrics.activityCircleSize)
                .scaleEffect(Constants.activityCircleScale + level * Constants.activityCircleScalePerLevel)

            ZStack {
                ForEach(Array(Constants.blobs.enumerated()), id: \.offset) { _, blob in
                    let offsetAmplitude = metrics.blobOffset + level * metrics.blobOffsetPerLevel
                    Circle()
                        .fill(blob.color(for: colorScheme))
                        .frame(width: metrics.blobSize, height: metrics.blobSize)
                        .offset(
                            x: cos(time * blob.speed + blob.phase) * offsetAmplitude,
                            y: sin(
                                time * blob.speed * Constants.blobVerticalSpeedRatio + blob.phase
                            ) * offsetAmplitude
                        )
                        .blur(radius: metrics.blobBlurRadius)
                }
            }
            .frame(width: metrics.orbSize, height: metrics.orbSize)
            .clipShape(Circle())
            .modify { view in
                if #available(iOS 26.0, watchOS 26.0, *), !forcesLegacyAppearance {
                    view.glassEffect(
                        .regular.tint(Color.haPrimary.opacity(appearance.orbGlassTintOpacity)),
                        in: .circle
                    )
                } else {
                    view
                        .background(Circle().fill(Color.haPrimary.opacity(appearance.orbBackgroundOpacity)))
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(Constants.orbBorderStartOpacity),
                                            .white.opacity(Constants.orbBorderEndOpacity),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: Constants.orbBorderWidth
                                )
                        )
                }
            }
            .scaleEffect(1 + level * Constants.orbScalePerLevel)

            Image(uiImage: metrics.microphoneImage)
                .opacity(appearance.microphoneOpacity)
                .scaleEffect(1 + level * Constants.orbScalePerLevel)
        }
        .frame(width: metrics.orbSize, height: metrics.orbSize)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 0.5, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 1, accessibilityLabel: "Listening")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}

#Preview("Dark") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 0.5, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 1, accessibilityLabel: "Listening")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Watch") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, size: .watch, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 0.5, size: .watch, accessibilityLabel: "Listening")
        AssistVoiceOrbView(level: 1, size: .watch, accessibilityLabel: "Listening")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}

#Preview("Legacy") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 0.5, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 1, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}

#Preview("Legacy dark") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 0.5, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 1, accessibilityLabel: "Listening", forcesLegacyAppearance: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
