import SwiftUI

extension View {
    /// Holds the screen awake while this view is on screen, so a migration left running on a desk is
    /// still going when the user comes back to it.
    func appMigrationKeepsScreenAwake() -> some View {
        modifier(AppMigrationScreenLockModifier())
    }
}
