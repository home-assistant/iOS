import Foundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

public class Haptics {
    public static let shared = Haptics()

    private init() {}

    public func play(_ feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
    }

    public func notify(_ feedbackType: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(feedbackType)
    }
}
