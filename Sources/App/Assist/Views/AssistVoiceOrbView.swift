import SFSafeSymbols
import Shared
import SwiftUI

/// Animated orb shown while Assist is listening, pulsing with the microphone input level (0...1).
struct AssistVoiceOrbView: View {
    let level: Double

    private let blobs: [(color: Color, speed: Double, phase: Double)] = [
        (.cyan, 1.6, 0),
        (.haPrimary, -2.1, 2.1),
        (.teal, 2.7, 4.2),
    ]

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.haPrimary.opacity(0.6), Color.haPrimary.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(0.8 + level * 0.5)
                    .opacity(0.35 + level * 0.65)

                ZStack {
                    ForEach(Array(blobs.enumerated()), id: \.offset) { _, blob in
                        Circle()
                            .fill(blob.color)
                            .frame(width: 42, height: 42)
                            .offset(
                                x: cos(time * blob.speed + blob.phase) * (7 + level * 15),
                                y: sin(time * blob.speed * 0.8 + blob.phase) * (7 + level * 15)
                            )
                            .blur(radius: 10)
                    }
                }
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.haPrimary.opacity(0.35)))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .scaleEffect(1 + level * 0.25)
                .shadow(color: Color.haPrimary.opacity(0.3 + level * 0.4), radius: 12 + level * 16)

                Image(systemSymbol: .waveform)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .scaleEffect(1 + level * 0.25)
            }
        }
        .animation(.easeOut(duration: 0.15), value: level)
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
