import Foundation
import Shared

/// What a `WebViewController` is on screen as.
///
/// The main frontend is the app: it remembers where it is for the next launch, publishes its page
/// for Handoff and Siri, and offers the sidebar gestures. A native modal shows one frontend route
/// in a presentation of its own over it, and does none of that: the page underneath stays what the
/// app is showing. The frontend names the route; a modal booted ahead of time has none yet and is
/// told over the bus.
enum WebViewControllerRole: Equatable {
    case mainFrontend
    case nativeModal(path: String?)

    var isMainFrontend: Bool {
        self == .mainFrontend
    }

    /// The frontend route to load first, relative to the server's base URL. `nil` lets the controller
    /// choose between the kiosk dashboard, the restored last path, and the server default.
    var pinnedPath: String? {
        switch self {
        case .mainFrontend:
            return nil
        case let .nativeModal(path):
            return path
        }
    }
}
