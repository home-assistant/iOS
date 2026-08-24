import SwiftUI

/// Ties an `AppMigrationScreenLock` hold to the lifetime of a view. Applied via
/// `View.appMigrationKeepsScreenAwake()`.
///
/// Paired on appear/disappear rather than taken for the whole app session: the idle timer is a
/// device-wide setting, and leaving it disabled after the flow closes would quietly stop the phone
/// from ever sleeping.
struct AppMigrationScreenLockModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear { AppMigrationScreenLock.acquire() }
            .onDisappear { AppMigrationScreenLock.release() }
    }
}
