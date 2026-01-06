import SwiftUI

/// A reusable animated background view with gradient and floating orbs
/// Designed for use across multiple views in the app
struct ModernAssistBackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Constants

    private enum Constants {
        static let orbSize: CGFloat = 300
        static let orbRadius: CGFloat = 150
        static let backgroundBlurRadius: CGFloat = 40
        static let orbYOffsetMin: CGFloat = -50
        static let orbYOffsetMax: CGFloat = 50
        static let orbYOffset2Min: CGFloat = 0
        static let orbYOffset2Max: CGFloat = 100
        static let orbXOffsetLeft: CGFloat = -100
        static let orbOpacity: Double = 0.3
        static let ambientAnimationDuration: Double = 4
    }

    // MARK: - Properties

    let theme: ModernAssistTheme
    @State private var pulseAnimation = false

    // MARK: - Body

    var body: some View {
        LinearGradient(
            colors: theme.gradientColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // Animated orbs in background
            GeometryReader { geometry in
                ZStack {
                    // First orb - left side
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.orbColors(for: colorScheme).0.opacity(theme.orbOpacity(
                                        for: colorScheme,
                                        defaultOpacity: Constants.orbOpacity
                                    )),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(
                            x: Constants.orbXOffsetLeft,
                            y: pulseAnimation ? Constants.orbYOffsetMin : Constants.orbYOffsetMax
                        )
                        .blur(radius: Constants.backgroundBlurRadius)

                    // Second orb - right side
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.orbColors(for: colorScheme).1.opacity(theme.orbOpacity(
                                        for: colorScheme,
                                        defaultOpacity: Constants.orbOpacity
                                    )),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: Constants.orbRadius
                            )
                        )
                        .frame(width: Constants.orbSize, height: Constants.orbSize)
                        .offset(
                            x: geometry.size.width - Constants.orbXOffsetLeft * -1,
                            y: pulseAnimation ? Constants.orbYOffset2Max : Constants.orbYOffset2Min
                        )
                        .blur(radius: Constants.backgroundBlurRadius)
                }
            }
        }
        .onAppear {
            startAmbientAnimation()
        }
    }

    // MARK: - Animations

    private func startAmbientAnimation() {
        withAnimation(.easeInOut(duration: Constants.ambientAnimationDuration).repeatForever(autoreverses: true)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Preview

#Preview("Home Assistant Theme - Light") {
    ModernAssistBackgroundView(theme: .homeAssistant)
        .environment(\.colorScheme, .light)
}

#Preview("Home Assistant Theme - Dark") {
    ModernAssistBackgroundView(theme: .homeAssistant)
        .environment(\.colorScheme, .dark)
}

#Preview("Aurora Theme") {
    ModernAssistBackgroundView(theme: .aurora)
}

#Preview("Sunset Theme") {
    ModernAssistBackgroundView(theme: .sunset)
}

#Preview("Ocean Theme") {
    ModernAssistBackgroundView(theme: .ocean)
}
