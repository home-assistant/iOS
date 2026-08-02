import Shared
import SwiftUI

/// Environment action rows use to push a `WatchHomeNavigation` screen.
///
/// Navigation is programmatic on purpose: `WatchHomeView` owns the stack's path and injects this
/// action, and rows trigger it from plain `Button`s. `NavigationLink` resolves as inert inside the
/// styled home rows on watchOS (taps do nothing), while buttons in the same rows work reliably —
/// so buttons appending to the path are the dependable way to push.
struct WatchNavigateAction {
    let navigate: (WatchHomeNavigation) -> Void

    func callAsFunction(_ destination: WatchHomeNavigation) {
        navigate(destination)
    }

    fileprivate struct Key: EnvironmentKey {
        static let defaultValue = WatchNavigateAction { destination in
            Current.Log.error("watchNavigate used outside WatchHomeView's stack: \(destination)")
        }
    }
}

extension EnvironmentValues {
    var watchNavigate: WatchNavigateAction {
        get { self[WatchNavigateAction.Key.self] }
        set { self[WatchNavigateAction.Key.self] = newValue }
    }
}
