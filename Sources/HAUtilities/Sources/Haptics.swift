import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public class Haptics {
    public static let shared = Haptics()

    private init() {}

    #if os(macOS)
    /// The strengths iOS offers. A Mac trackpad has a single tap, so they all feel the same there.
    public enum ImpactStyle {
        case light
        case medium
        case heavy
        case soft
        case rigid
    }

    public enum NotificationType {
        case success
        case warning
        case error
    }

    public func play(_ feedbackStyle: ImpactStyle) {
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
    }

    public func notify(_ feedbackType: NotificationType) {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }
    #else
    public func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }

    public func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
    }
    #endif
}
