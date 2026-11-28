import AppKit

extension NSApplication {
    /// The windows the user thinks of as the app's windows, which leaves out the status item, menus and
    /// panels.
    var normalAppWindows: [NSWindow] {
        windows.filter { window in
            window.level == .normal &&
                window.canBecomeKey
        }
    }
}
