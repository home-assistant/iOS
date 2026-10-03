#if os(macOS)
import Shared
import SwiftUI

/// The menu bar commands that act on the frontend: reloading and searching the page, the native sidebar,
/// the toolbar, and sending the sensors. They apply to the window the user is working in.
struct MacWebViewCommands: Commands {
    @ObservedObject private var nativeSidebar = MacNativeSidebarState.shared
    @ObservedObject private var keyWindow = MacKeyWindowObserver.shared

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.Menu.File.updateSensors) {
                frontmostWebViewController?.updateSensors()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(frontmostWebViewController == nil)
        }

        CommandGroup(replacing: .toolbar) {
            Button(L10n.Menu.View.reloadPage) {
                frontmostWebViewController?.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(frontmostWebViewController == nil)

            Button(L10n.Menu.View.find) {
                frontmostWebViewController?.showFindInteraction()
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(frontmostWebViewController == nil)

            if nativeSidebar.isEnabled {
                Button(nativeSidebar.isVisible ? L10n.Menu.View.hideSidebar : L10n.Menu.View.showSidebar) {
                    nativeSidebar.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            Button(L10n.Menu.View.customizeToolbar) {
                frontmostWebViewController?.customizeToolbar()
            }
            .disabled(frontmostWebViewController == nil)
        }
    }

    /// The frontend of the window the user is working in; a sheet counts for the window under it.
    private var frontmostWebViewController: WebViewController? {
        let window = keyWindow.window
        return Current.sceneManager.webViewController(in: window?.sheetParent ?? window)
    }
}
#endif
