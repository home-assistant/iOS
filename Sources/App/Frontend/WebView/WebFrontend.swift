import Shared
import SwiftUI
import UIKit

/// A swappable SwiftUI host for the web frontend. `ContainerView` renders one of these for the active
/// server and receives its backing `WebViewController` via `onWebViewController`; swap the concrete type and
/// the app coordinator (`ContainerView`) keeps working.
protocol WebFrontendView: View {
    init(server: Server, onWebViewController: @escaping (WebViewController) -> Void)
}

/// The running web frontend the app coordinator drives. Abstracts `WebViewController` so the coordinator
/// (`AppContainerCoordinator`) never references it directly. `WebViewController` conforms below.
protocol WebFrontend: AnyObject {
    var server: Server { get }
    var presentationWindow: UIWindow? { get }
    func show(alert: ServerAlert)
    func open(inline url: URL, avoidUnnecessaryReload: Bool)
    func openPanel(_ url: URL)
    func dismissOverlayController(animated: Bool, completion: (() -> Void)?)
    func presentOverlayController(controller: UIViewController, animated: Bool)
}

extension WebViewController: WebFrontend {
    var presentationWindow: UIWindow? { viewIfLoaded?.window }
}
