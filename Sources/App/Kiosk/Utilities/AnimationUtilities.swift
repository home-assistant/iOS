import SwiftUI

// MARK: - Kiosk Animations

/// Pre-defined animations for consistent UX across the kiosk mode
public enum KioskAnimation {
    /// Quick fade animation for subtle transitions
    public static let fade = Animation.easeInOut(duration: KioskConstants.Animation.quick)

    /// Standard animation for most transitions
    public static let standard = Animation.easeInOut(duration: KioskConstants.Animation.standard)

    /// Slow animation for screensaver transitions
    public static let slow = Animation.easeInOut(duration: KioskConstants.Animation.slow)

    /// Spring animation for interactive elements
    public static let spring = Animation.spring(response: KioskConstants.Animation.springResponse, dampingFraction: 0.8)

    /// Bouncy spring for playful interactions
    public static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)

    /// Smooth spring for panels and overlays
    public static let panel = Animation.spring(response: 0.4, dampingFraction: 0.85)

    /// Gentle animation for pixel shift
    public static let pixelShift = Animation.easeInOut(duration: KioskConstants.Animation.pixelShift)
}

// MARK: - Kiosk Transitions

/// Pre-defined transitions for consistent UX
public enum KioskTransition {
    /// Fade in/out
    public static let fade = AnyTransition.opacity

    /// Scale and fade
    public static let scaleAndFade = AnyTransition.scale.combined(with: .opacity)

    /// Slide from bottom with fade
    public static let slideFromBottom = AnyTransition.move(edge: .bottom).combined(with: .opacity)

    /// Slide from top with fade
    public static let slideFromTop = AnyTransition.move(edge: .top).combined(with: .opacity)

    /// Slide from left with fade
    public static let slideFromLeft = AnyTransition.move(edge: .leading).combined(with: .opacity)

    /// Slide from right with fade
    public static let slideFromRight = AnyTransition.move(edge: .trailing).combined(with: .opacity)

    /// Asymmetric panel transition (slide in, fade out)
    public static func panel(edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Screensaver transition (slow fade)
    public static let screensaver = AnyTransition.opacity.animation(KioskAnimation.slow)

    /// Alert transition (scale up, fade out)
    public static let alert = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.9).combined(with: .opacity),
        removal: .opacity
    )
}

// MARK: - View Modifiers

/// Applies a smooth appear animation
public struct AppearAnimationModifier: ViewModifier {
    let animation: Animation
    @State private var isVisible = false

    public init(animation: Animation = KioskAnimation.standard) {
        self.animation = animation
    }

    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                withAnimation(animation) {
                    isVisible = true
                }
            }
    }
}

/// Applies a pulse animation (useful for drawing attention)
public struct PulseAnimationModifier: ViewModifier {
    @State private var isPulsing = false
    let duration: Double

    public init(duration: Double = 1.0) {
        self.duration = duration
    }

    public func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

/// Applies a shimmer loading animation
public struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    public func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear,
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply smooth appear animation
    public func appearAnimation(_ animation: Animation = KioskAnimation.standard) -> some View {
        modifier(AppearAnimationModifier(animation: animation))
    }

    /// Apply pulse animation
    public func pulseAnimation(duration: Double = 1.0) -> some View {
        modifier(PulseAnimationModifier(duration: duration))
    }

    /// Apply shimmer loading animation
    public func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    /// Apply a smooth scale effect on press
    public func pressEffect() -> some View {
        buttonStyle(PressEffectButtonStyle())
    }
}

// MARK: - Button Styles

/// Button style that scales down slightly on press
public struct PressEffectButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Button style with spring bounce effect
public struct BounceButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// Button style that highlights on press
public struct HighlightButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: KioskConstants.UI.smallCornerRadius)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Animated Property Wrappers

/// Property wrapper that animates value changes
@propertyWrapper
public struct Animated<Value: Equatable>: DynamicProperty {
    @State private var value: Value
    private let animation: Animation

    public init(wrappedValue: Value, animation: Animation = .default) {
        _value = State(initialValue: wrappedValue)
        self.animation = animation
    }

    public var wrappedValue: Value {
        get { value }
        nonmutating set {
            withAnimation(animation) {
                value = newValue
            }
        }
    }

    public var projectedValue: Binding<Value> {
        Binding(
            get: { value },
            set: { newValue in
                withAnimation(animation) {
                    value = newValue
                }
            }
        )
    }
}
