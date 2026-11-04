import Shared
import SwiftUI

/// Environment action rows use to open the full-screen Assist cover.
///
/// The cover is owned by `WatchHomeView` — a single cover for the toolbar button, the complication
/// launch and the Assist items — so rows anywhere in the stack (folders included) ask for it through
/// this action instead of presenting one of their own.
struct WatchPresentAssistAction {
    let present: (WatchAssistPresentation) -> Void

    func callAsFunction(_ presentation: WatchAssistPresentation) {
        present(presentation)
    }

    fileprivate struct Key: EnvironmentKey {
        static let defaultValue = WatchPresentAssistAction { presentation in
            Current.Log.error("watchPresentAssist used outside WatchHomeView's stack: \(presentation.id)")
        }
    }
}

extension EnvironmentValues {
    var watchPresentAssist: WatchPresentAssistAction {
        get { self[WatchPresentAssistAction.Key.self] }
        set { self[WatchPresentAssistAction.Key.self] = newValue }
    }
}
