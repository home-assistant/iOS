import Shared
import UIKit

/// The haptics of the migration flow, in one place so both directions feel identical.
///
/// The flow is deliberately something the user can watch from across a desk, so each beat is
/// distinct by feel alone: steps tick past lightly, a slice landing is lighter still (there can be
/// dozens), and only the two outcomes use the notification generator.
@MainActor
enum AppMigrationHaptics {
    /// A step in the list just turned into a checkmark.
    static func stepCompleted() {
        Current.impactFeedback.impactOccurred(style: .light)
    }

    /// A step failed. Softer than the end-of-flow error: the migration may still recover — a failed
    /// configuration step does not stop the servers from moving.
    static func stepFailed() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// One slice of a multi-link payload made it across. The softest beat in the flow because a large
    /// migration fires it once per round trip.
    static func transferAdvanced() {
        Current.impactFeedback.impactOccurred(style: .soft)
    }

    /// The migration finished — the new app has everything.
    static func migrationSucceeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// The migration stopped and the user has to act.
    static func migrationFailed() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
