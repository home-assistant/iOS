import Shared
import SwiftUI

/// Animated orb shown while Assist is listening. Voice activity is shown by a plain circle behind the
/// orb that grows and shrinks with the microphone input level (0...1), no glow or shadow involved.
struct AssistVoiceOrbView: View {
    let level: Double
    /// Renders the pre-iOS 26 fill and border instead of Liquid Glass, so the legacy look stays
    /// previewable alongside the current one.
    var forcesLegacyAppearance = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.assistOrbFixedTime) private var fixedTime

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

        /// The design system's `cyan50`-style tokens cannot be used here: `BaseColors` spells them as
        /// `Color(hex: "0xAARRGGBB")`, a form `Color(hex:)` rejects, so each one silently resolves to
        /// `.clear`. These are the same palette values, written in a form that survives.
        static func srgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
            Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
        }

        /// Dark mode takes the deep end of the palette, where the white microphone glyph still reads
        /// against the blend of the three: the light blobs are the brightest thing on a dark screen and
        /// swallow the glyph. The spread between the darkest and the brightest is kept wide, or the orb
        /// flattens into one dull disc once the colours come down.
        static let blobs: [Blob] = [
            .init(lightColor: .cyan, darkColor: srgb(0x07, 0x80, 0x98), speed: 1.6, phase: 0),
            .init(lightColor: .haPrimary, darkColor: srgb(0x00, 0x70, 0x93), speed: -2.1, phase: 2.1),
            .init(lightColor: .teal, darkColor: srgb(0x01, 0x4C, 0x5B), speed: 2.7, phase: 4.2),
        ]

        /// What the orb has to tell apart from the screen behind it, which is white in light mode and
        /// near black in dark mode, so these values cannot be shared between the two.
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
                activityCircleColor: srgb(0x37, 0xC8, 0xFD),
                activityCircleOpacity: 0.35,
                orbBackgroundOpacity: 0.25,
                orbGlassTintOpacity: 0.3,
                microphoneOpacity: 1
            )

            static func matching(_ colorScheme: ColorScheme) -> Appearance {
                colorScheme == .dark ? .dark : .light
            }
        }

        static let activityCircleSize: CGFloat = 64
        /// Hidden behind the orb at silence and growing when talking, so the size change is the thing
        /// the user notices. The per-level factor is capped by the room between the orb's centre and
        /// the bottom of the screen: at 0.6 the loudest ring is 102pt wide and still lands on screen.
        static let activityCircleScale: CGFloat = 1
        static let activityCircleScalePerLevel: CGFloat = 0.6

        static let orbSize: CGFloat = 64
        static let orbScalePerLevel: CGFloat = 0.25
        static let orbBorderStartOpacity: Double = 0.55
        static let orbBorderEndOpacity: Double = 0.08
        static let orbBorderWidth: CGFloat = DesignSystem.Border.Width.default

        static let blobSize: CGFloat = 42
        static let blobBlurRadius: CGFloat = 10
        static let blobOffset: CGFloat = 7
        static let blobOffsetPerLevel: CGFloat = 15
        /// The vertical wobble runs slightly slower than the horizontal one, so the blobs trace ellipses.
        static let blobVerticalSpeedRatio: Double = 0.8

        static let microphoneIconSize = CGSize(width: 30, height: 30)
        /// Drawing the glyph is a text render into a bitmap, and the body below runs on every frame
        /// of the animation timeline, so it is rasterized once here instead.
        static let microphoneImage = MaterialDesignIcons.microphoneIcon.image(
            ofSize: microphoneIconSize,
            color: .white
        )

        static let levelAnimation: Animation = .easeOut(duration: 0.1)
    }

    var body: some View {
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
        .accessibilityLabel(L10n.Assist.Button.Listening.title)
    }

    private func orb(at time: TimeInterval) -> some View {
        let appearance = Constants.Appearance.matching(colorScheme)

        return ZStack {
            Circle()
                .fill(appearance.activityCircleColor.opacity(appearance.activityCircleOpacity))
                .frame(width: Constants.activityCircleSize, height: Constants.activityCircleSize)
                .scaleEffect(Constants.activityCircleScale + level * Constants.activityCircleScalePerLevel)

            ZStack {
                ForEach(Array(Constants.blobs.enumerated()), id: \.offset) { _, blob in
                    let offsetAmplitude = Constants.blobOffset + level * Constants.blobOffsetPerLevel
                    Circle()
                        .fill(blob.color(for: colorScheme))
                        .frame(width: Constants.blobSize, height: Constants.blobSize)
                        .offset(
                            x: cos(time * blob.speed + blob.phase) * offsetAmplitude,
                            y: sin(
                                time * blob.speed * Constants.blobVerticalSpeedRatio + blob.phase
                            ) * offsetAmplitude
                        )
                        .blur(radius: Constants.blobBlurRadius)
                }
            }
            .frame(width: Constants.orbSize, height: Constants.orbSize)
            .clipShape(Circle())
            .modify { view in
                if #available(iOS 26.0, *), !forcesLegacyAppearance {
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

            Image(uiImage: Constants.microphoneImage)
                .opacity(appearance.microphoneOpacity)
                .scaleEffect(1 + level * Constants.orbScalePerLevel)
        }
        .frame(width: Constants.orbSize, height: Constants.orbSize)
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0)
        AssistVoiceOrbView(level: 0.5)
        AssistVoiceOrbView(level: 1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Dark") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0)
        AssistVoiceOrbView(level: 0.5)
        AssistVoiceOrbView(level: 1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
    .preferredColorScheme(.dark)
}

#Preview("Legacy") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 0.5, forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 1, forcesLegacyAppearance: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
}

#Preview("Legacy dark") {
    VStack(spacing: DesignSystem.Spaces.six) {
        AssistVoiceOrbView(level: 0, forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 0.5, forcesLegacyAppearance: true)
        AssistVoiceOrbView(level: 1, forcesLegacyAppearance: true)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemBackground))
    .preferredColorScheme(.dark)
}
