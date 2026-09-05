import Shared
import SwiftUI

extension View {
    /// Puts both halves of the developer-account migration over the app.
    ///
    /// Full screen and on the window root, because the handoff can arrive while onboarding is up on a
    /// fresh install of the new app — which is the normal case, not an edge one.
    func appMigrationCover() -> some View {
        modifier(AppMigrationCoverModifier())
    }
}
