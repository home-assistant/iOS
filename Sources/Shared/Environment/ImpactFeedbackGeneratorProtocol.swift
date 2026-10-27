#if os(iOS)
import Foundation
import UIKit

public protocol ImpactFeedbackGeneratorProtocol {
    func impactOccurred()
    func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType)
}

final class ImpactFeedbackGenerator: ImpactFeedbackGeneratorProtocol {
    func impactOccurred() {
        impactOccurred(style: .medium)
    }

    func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    func notificationOccurred(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
#endif
