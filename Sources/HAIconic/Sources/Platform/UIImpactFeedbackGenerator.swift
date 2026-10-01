#if os(macOS)
import AppKit

/// A Mac has one kind of haptic, played by a Force Touch trackpad, so every impact style feels alike.
public final class UIImpactFeedbackGenerator {
    public enum FeedbackStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    public init(style: FeedbackStyle = .medium) {}

    public func prepare() {}

    public func impactOccurred() {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }
}
#endif
