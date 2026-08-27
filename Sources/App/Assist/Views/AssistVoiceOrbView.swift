import SFSafeSymbols
import Shared
import SwiftUI

/// Animated orb shown while Assist is listening. Voice activity is shown by a plain circle behind the
/// orb that grows and shrinks with the microphone input level (0...1), no glow or shadow involved.
struct AssistVoiceOrbView: View {
    let level: Double

    private enum Constants {
        struct Blob {
            let color: Color
            let speed: Double
            let phase: Double
        }

        static let blobs: [Blob] = [
            .init(color: .cyan, speed: 1.6, phase: 0),
            .init(color: .haPrimary, speed: -2.1, phase: 2.1),
            .init(color: .teal, speed: 2.7, phase: 4.2),
        ]

        /// Footprint reserved for the orb, so a loud level never resizes the surrounding layout.
        static let size: CGFloat = 140

        static let activityCircleSize: CGFloat = 64
        static let activityCircleOpacity: Double = 0.25
        /// Hidden behind the orb at silence and growing when talking, so the size change is the thing
        /// the user notices. The per-level factor is capped by the room between the orb's centre and
        /// the bottom of the screen: at 0.6 the loudest ring is 102pt wide and still lands on screen.
        static let activityCircleScale: CGFloat = 1
        static let activityCircleScalePerLevel: CGFloat = 0.6

        static let orbSize: CGFloat = 64
        static let orbBackgroundOpacity: Double = 0.35
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
        static let microphoneFontSize: CGFloat = 22
        static let microphoneOpacity: Double = 0.9

        static let levelAnimation: Animation = .easeOut(duration: 0.1)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(Color.haPrimary.opacity(Constants.activityCircleOpacity))
                    .frame(width: Constants.activityCircleSize, height: Constants.activityCircleSize)
                    .scaleEffect(Constants.activityCircleScale + level * Constants.activityCircleScalePerLevel)

                ZStack {
                    ForEach(Array(Constants.blobs.enumerated()), id: \.offset) { _, blob in
                        let offsetAmplitude = Constants.blobOffset + level * Constants.blobOffsetPerLevel
                        Circle()
                            .fill(blob.color)
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
                .background(Circle().fill(Color.haPrimary.opacity(Constants.orbBackgroundOpacity)))
                .clipShape(Circle())
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
                .scaleEffect(1 + level * Constants.orbScalePerLevel)

                Image(uiImage: MaterialDesignIcons.microphoneIcon.image(
                    ofSize: Constants.microphoneIconSize,
                    color: .white
                ))
                .font(.system(size: Constants.microphoneFontSize, weight: .medium))
                .foregroundStyle(.white.opacity(Constants.microphoneOpacity))
                .scaleEffect(1 + level * Constants.orbScalePerLevel)
            }
            .frame(width: Constants.size, height: Constants.size)
        }
        .animation(Constants.levelAnimation, value: level)
        .accessibilityLabel(L10n.Assist.Button.Listening.title)
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
