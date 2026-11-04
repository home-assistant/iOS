import Foundation
import Shared
import SwiftUI

/// Backs the row that opts back into WebKit's Enhanced Security heuristic.
@MainActor
final class EnhancedWebSecuritySettingsViewModel: ObservableObject {
    /// Whether the override has anything to act on, which is what decides if the row is shown at
    /// all: the heuristic never fires on an HTTPS-only setup, so for those users this would be a
    /// security switch that changes nothing.
    let isRelevant: Bool

    @Published private(set) var isEnabled: Bool

    init(
        isRelevant: Bool = WebKitEnhancedSecurity.isRelevantForConfiguredServers(),
        isEnabled: Bool = Current.settingsStore.enhancedWebSecurityEnabled
    ) {
        self.isRelevant = isRelevant
        self.isEnabled = isEnabled
    }

    var enabled: Binding<Bool> {
        .init(
            get: { self.isEnabled },
            set: { self.setEnabled($0) }
        )
    }

    /// Writing the setting is all this does: the override itself is read when the next web view is
    /// built, which is why the row tells the user it takes effect on the next launch.
    func setEnabled(_ newValue: Bool) {
        isEnabled = newValue
        Current.settingsStore.enhancedWebSecurityEnabled = newValue
    }
}
