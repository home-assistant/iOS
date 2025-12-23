import Shared
import SwiftUI

struct AssistWavesAnimation: View {
    // Configuration
    private let numberOfBars = 5
    private let minHeight: CGFloat = 40
    private let maxHeight: CGFloat = 200

    // Check out these colors - I added a gradient feel based on your input
    private let colors: [Color] = [.blue, .cyan, .blue.opacity(0.8), .teal, .blue]

    @State private var instructionOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Text(L10n.Assist.Button.FinishRecording.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .opacity(instructionOpacity)
                .offset(y: -100) // Position above the waves
                .onAppear {
                    // Wait 2 seconds so the user can read it, then fade out
                    withAnimation(.easeOut(duration: 1.0).delay(2.0)) {
                        instructionOpacity = 0
                    }
                }

            HStack(spacing: 6) {
                ForEach(0 ..< numberOfBars, id: \.self) { index in
                    WaveBar(
                        color: colors[index % colors.count],
                        minHeight: minHeight,
                        maxHeight: maxHeight,
                        // We stagger the animation slightly based on index
                        // to prevent them from moving in perfect unison
                        delay: Double(index) * 0.1
                    )
                    .blur(radius: 40)
                }
            }
            // This creates a nice glow effect without hiding the bars
            .background(
                HStack(spacing: 6) {
                    ForEach(0 ..< numberOfBars, id: \.self) { index in
                        WaveBar(
                            color: colors[index % colors.count],
                            minHeight: minHeight,
                            maxHeight: maxHeight,
                            delay: Double(index) * 0.1
                        )
                    }
                }
                .blur(radius: 60) // Soft glow
                .opacity(0.5)
            )
            .offset(y: 70)
        }
    }
}

// Subview to handle individual bar animation
struct WaveBar: View {
    let color: Color
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let delay: Double

    @State private var isAnimating = false

    // Generate a random duration for a more "organic" voice feel
    var randomDuration: Double {
        Double.random(in: 0.5 ... 0.9)
    }

    var body: some View {
        Capsule()
            .fill(color)
            .frame(maxWidth: .infinity)
            .frame(height: isAnimating ? maxHeight * CGFloat.random(in: 0.5 ... 1.0) : minHeight)
            .onAppear {
                // Different animation speeds for different bars creates the "Voice" chaos
                withAnimation(
                    .easeInOut(duration: randomDuration)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    isAnimating = true
                }
            }
    }
}

#Preview {
    VStack {
        Spacer()
        AssistWavesAnimation()
    }
}

#Preview("Dark") {
    VStack {
        Spacer()
        AssistWavesAnimation()
    }
    .preferredColorScheme(.dark)
}
