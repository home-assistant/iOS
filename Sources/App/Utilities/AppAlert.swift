import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// An alert described once and shown with the platform's own: `UIAlertController` on iOS, `NSAlert` on
/// the Mac. For alerts raised from outside a SwiftUI view, where `.alert` is not an option.
struct AppAlert {
    struct Action {
        enum Style {
            case `default`
            case cancel
            case destructive
        }

        var title: String
        var style: Style = .default
        var handler: (() -> Void)?

        init(title: String, style: Style = .default, handler: (() -> Void)? = nil) {
            self.title = title
            self.style = style
            self.handler = handler
        }
    }

    var title: String?
    var message: String?
    var actions: [Action]

    init(title: String? = nil, message: String? = nil, actions: [Action]) {
        self.title = title
        self.message = message
        self.actions = actions
    }

    #if os(macOS)
    /// Shows the alert as a sheet on `window`, or as an app-modal alert when there is no window to attach
    /// it to. Call on the main thread.
    func present(on window: NSWindow?) {
        let alert = NSAlert()
        alert.messageText = title ?? ""
        alert.informativeText = message ?? ""

        // AppKit gives the first button the default role, so the confirming actions go in ahead of cancel.
        let ordered = actions.filter { $0.style != .cancel } + actions.filter { $0.style == .cancel }
        for action in ordered {
            let button = alert.addButton(withTitle: action.title)
            button.hasDestructiveAction = action.style == .destructive
            if action.style == .cancel {
                button.keyEquivalent = "\u{1b}"
            }
        }

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            guard ordered.indices.contains(index) else { return }
            ordered[index].handler?()
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(alert.runModal())
        }
    }
    #else
    func makeAlertController() -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        for action in actions {
            let style: UIAlertAction.Style = switch action.style {
            case .default: .default
            case .cancel: .cancel
            case .destructive: .destructive
            }
            controller.addAction(UIAlertAction(title: action.title, style: style) { _ in action.handler?() })
        }
        return controller
    }
    #endif
}
