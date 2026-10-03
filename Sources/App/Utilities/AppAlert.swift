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
        /// The action Return presses on the Mac, as `UIAlertController.preferredAction` is on iOS.
        var isPreferred = false
        var handler: (() -> Void)?

        init(title: String, style: Style = .default, isPreferred: Bool = false, handler: (() -> Void)? = nil) {
            self.title = title
            self.style = style
            self.isPreferred = isPreferred
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

    /// The order the Mac's buttons go in. The first one is pressed by Return, so it is the preferred action,
    /// else the cancel action, else the first ordinary one; a destructive action never comes first unless it
    /// is all there is.
    var macButtonOrder: [Action] {
        let first = actions.first(where: \.isPreferred)
            ?? actions.first(where: { $0.style == .cancel })
            ?? actions.first(where: { $0.style == .default })
            ?? actions.first
        guard let first else { return [] }
        let rest = actions.filter { $0.title != first.title || $0.style != first.style }
        return [first] + rest
    }

    /// What the Mac shows as the bold message and the text under it: a title is the message, and without
    /// one the message itself takes its place rather than sitting under an empty line.
    var macTexts: (message: String, informative: String) {
        if let title {
            return (title, message ?? "")
        }
        return (message ?? "", "")
    }

    #if os(macOS)
    /// Shows the alert as a sheet on `window`, or as an app-modal alert when there is no window to attach
    /// it to. Call on the main thread.
    func present(on window: NSWindow?) {
        let alert = NSAlert()
        let texts = macTexts
        alert.messageText = texts.message
        alert.informativeText = texts.informative

        let ordered = macButtonOrder
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
            let alertAction = UIAlertAction(title: action.title, style: style) { _ in action.handler?() }
            controller.addAction(alertAction)
            if action.isPreferred {
                controller.preferredAction = alertAction
            }
        }
        return controller
    }
    #endif
}
