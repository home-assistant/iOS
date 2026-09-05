import Shared
import UIKit

/// Keeps the screen awake for the length of a migration, on both sides of it.
///
/// A multi-link handoff bounces between the two apps and each hop needs whichever app is in front to
/// be running, so a device that locks mid-transfer strands it — the user comes back to a half-moved
/// migration rather than a finished one. Held with a counter rather than a flag because both flows
/// can be alive at once on a device where the user re-opened the old app while the new one was
/// importing; the screen must stay awake until the last of them is done.
enum AppMigrationScreenLock {
    private static var holds = 0

    @MainActor
    static func acquire() {
        holds += 1
        guard holds == 1 else { return }
        Current.Log.info("Disabling idle timer for the duration of the migration")
        UIApplication.shared.isIdleTimerDisabled = true
    }

    @MainActor
    static func release() {
        guard holds > 0 else { return }
        holds -= 1
        guard holds == 0 else { return }
        Current.Log.info("Re-enabling idle timer after the migration")
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
