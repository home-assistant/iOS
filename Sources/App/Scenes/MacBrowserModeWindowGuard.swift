#if os(macOS)
import AppKit
import Shared
import SwiftUI

/// Honours "Open Home Assistant UI in browser" for the main window. With that setting on there is never an
/// in-app frontend, so a main window that comes up is closed again, and the browser is opened in its place
/// the first time that happens in the life of the process: the user's cold launch. Windows that appear
/// later are closed without reopening the browser; the Dock icon and the menu bar item open it on request.
struct MacBrowserModeWindowGuard: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        GuardView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class GuardView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            let isInitialConnection = MacBrowserSceneLauncher.markSceneConnected()
            let actions = MacBrowserSceneLauncher.actions(isInitialConnection: isInitialConnection)
            guard actions.destroysEmptyWindow,
                  let url = Current.servers.all.first?.activeURLUsingLastKnownNetworkState() else { return }

            if actions.opensBrowser {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
            // Closing a window from inside the pass that is putting it on screen is not allowed.
            DispatchQueue.main.async { [weak window] in
                window?.close()
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}
#endif
