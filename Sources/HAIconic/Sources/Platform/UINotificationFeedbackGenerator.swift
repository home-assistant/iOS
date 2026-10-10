#if os(macOS)
import AppKit

/// A Mac has one kind of haptic, played by a Force Touch trackpad, so every notification type feels alike.
public final class UINotificationFeedbackGenerator {
    public enum FeedbackType {
        case success
        case warning
        case error
    }

    public init() {}

    public func prepare() {}

    public func notificationOccurred(_ notificationType: FeedbackType) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
}
#endif
