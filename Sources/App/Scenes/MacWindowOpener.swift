#if os(macOS)
import AppKit
import Shared
import SwiftUI

/// Opens the app's windows for code that is not inside a view: the scene manager, the menu bar item,
/// deep links. SwiftUI only hands its `openWindow` action to the scene graph, so `HAApp` registers it here
/// as soon as it has one.
final class MacWindowOpener {
    static let shared = MacWindowOpener()

    private var openWindow: OpenWindowAction?
    /// Requests that arrived before SwiftUI handed over its action, replayed once it does.
    private var pending: [SceneActivity] = []

    private init() {}

    func register(_ openWindow: OpenWindowAction) {
        self.openWindow = openWindow
        let queued = pending
        pending = []
        queued.forEach(open(_:))
    }

    /// Brings the window for `activity` to the front, opening one when none is on screen.
    func open(_ activity: SceneActivity) {
        dispatchPrecondition(condition: .onQueue(.main))

        if let window = existingWindow(for: activity) {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else if let openWindow {
            openWindow(id: activity.activityIdentifier)
        } else {
            pending.append(activity)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    /// SwiftUI names a window after its scene's identifier, followed by a suffix of its own for the windows
    /// of a `WindowGroup`.
    func existingWindow(for activity: SceneActivity) -> NSWindow? {
        NSApp.windows.first { window in
            guard let identifier = window.identifier?.rawValue else { return false }
            return identifier.hasPrefix(activity.activityIdentifier) && window.canBecomeKey
        }
    }
}
#endif
