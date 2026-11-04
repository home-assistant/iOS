import SwiftUI

/// Keeps the OHF branding footer on the stand-by screen limited to the first stand-by of a cold launch:
/// the footer continues where the launch splash's copy left off, and once that first stand-by is
/// dismissed it never returns for the rest of the app session (reconnects, reloads, server switches).
@MainActor
final class StandByOHFBrandingState: ObservableObject {
    static let shared = StandByOHFBrandingState()

    @Published private(set) var showsBranding = true

    /// Called when a stand-by screen disappears; terminal for the rest of the app session.
    func markStandByDismissed() {
        showsBranding = false
    }
}
