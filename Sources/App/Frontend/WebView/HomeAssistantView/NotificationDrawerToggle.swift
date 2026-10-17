import Foundation

/// A bell tap: closes the frontend's notification drawer when it is open, otherwise opens it.
struct NotificationDrawerToggle {
    let evaluateJavaScript: (String, @escaping (Any?, (any Error)?) -> Void) -> Void
    let showDrawer: () -> Void

    func toggle() {
        evaluateJavaScript(WebViewJavascriptCommands.closeNotificationDrawerIfOpen) { result, _ in
            guard result as? Bool != true else { return }
            showDrawer()
        }
    }
}
