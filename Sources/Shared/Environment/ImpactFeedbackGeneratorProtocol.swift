#if os(macOS)
import Foundation

public protocol ImpactFeedbackGeneratorProtocol {
    func impactOccurred()
    func impactOccurred(style: Haptics.ImpactStyle)
}

final class ImpactFeedbackGenerator: ImpactFeedbackGeneratorProtocol {
    func impactOccurred() {
        impactOccurred(style: .medium)
    }

    func impactOccurred(style: Haptics.ImpactStyle) {
        Haptics.shared.play(style)
    }
}

#elseif os(iOS)
import Foundation
import UIKit

public protocol ImpactFeedbackGeneratorProtocol {
    func impactOccurred()
    func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle)
}

final class ImpactFeedbackGenerator: ImpactFeedbackGeneratorProtocol {
    func impactOccurred() {
        impactOccurred(style: .medium)
    }

    func impactOccurred(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}
#endif
