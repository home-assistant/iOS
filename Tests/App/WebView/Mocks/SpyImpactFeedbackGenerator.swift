import Shared
import UIKit

final class SpyImpactFeedbackGenerator: ImpactFeedbackGeneratorProtocol {
    enum Feedback: Equatable {
        case impact(UIImpactFeedbackGenerator.FeedbackStyle)
        case notification(UINotificationFeedbackGenerator.FeedbackType)
    }

    private(set) var feedbacks: [Feedback] = []

    func impactOccurred() {
        impactOccurred(style: .medium)
    }

    func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        feedbacks.append(.impact(style))
    }

    func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        feedbacks.append(.notification(type))
    }
}
