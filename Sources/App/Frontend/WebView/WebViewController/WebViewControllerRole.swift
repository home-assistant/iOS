import Foundation
import Shared

/// What a `WebViewController` is on screen as.
///
/// The main frontend is the app: it remembers where it is for the next launch, publishes its page
/// for Handoff and Siri, and offers the sidebar gestures. A standalone more-info screen shows one
/// entity's details in a sheet over it, at the frontend's frameless `/more-info` route, and does
/// none of that: the page underneath stays what the app is showing.
enum WebViewControllerRole: Equatable {
    case mainFrontend
    case standaloneMoreInfo(entityId: String)

    var isMainFrontend: Bool {
        self == .mainFrontend
    }

    /// The frontend route to load first, relative to the server's base URL. `nil` lets the controller
    /// choose between the kiosk dashboard, the restored last path, and the server default.
    var pinnedPath: String? {
        switch self {
        case .mainFrontend:
            return nil
        case let .standaloneMoreInfo(entityId):
            return Self.standaloneMoreInfoPath(entityId: entityId)
        }
    }

    /// The frontend's frameless more-info page. It reads the entity from the same query item as the
    /// more-info deep link on any other route, and shows the info view by default.
    static func standaloneMoreInfoPath(entityId: String) -> String {
        var components = URLComponents()
        components.path = "/more-info"
        components.queryItems = [
            URLQueryItem(name: AppConstants.QueryItems.openMoreInfoDialog.rawValue, value: entityId),
        ]
        return components.string ?? "/more-info"
    }
}
