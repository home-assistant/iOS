import Foundation
import Shared
import UIKit

/// The handful of haptics the transfer uses on both sides, so each moment feels the same in each app.
enum AppMigrationHaptics {
    /// A button that moves the flow along.
    static func tap() {
        Current.impactFeedback.impactOccurred(style: .light)
    }

    /// One stage of the progress script giving way to the next.
    static func stage() {
        Current.impactFeedback.impactOccurred(style: .soft)
    }

    /// The previous app being taken over by a request, or a choice that undoes work.
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
