#if os(macOS)
import Shared
import SwiftUI

/// The menu bar commands that act on the frontend: reloading and searching the page, the native sidebar,
/// the toolbar, and sending the sensors. They apply to the window the user is working in.
struct MacWebViewCommands: Commands {
    @ObservedObject private var nativeSidebar = MacNativeSidebarState.shared

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(L10n.Menu.File.updateSensors) {
                frontmostWebViewController { $0.updateSensors() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        // The frontend's text fields are plain ones, so the Format menu has nothing to act on.
        CommandGroup(replacing: .textFormatting) {}

        CommandGroup(replacing: .toolbar) {
            Button(L10n.Menu.View.reloadPage) {
                frontmostWebViewController { $0.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button(L10n.Menu.View.find) {
                frontmostWebViewController { $0.showFindInteraction() }
            }
            .keyboardShortcut("f", modifiers: .command)

            if nativeSidebar.isEnabled {
                Button(nativeSidebar.isVisible ? L10n.Menu.View.hideSidebar : L10n.Menu.View.showSidebar) {
                    nativeSidebar.toggle()
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }

            Button(L10n.Menu.View.customizeToolbar) {
                frontmostWebViewController { $0.customizeToolbar() }
            }
        }
    }

    /// Runs `action` on the frontend of the window the user is working in, falling back to the one the app
    /// last showed when a window without a frontend (Settings, About) is in front.
    private func frontmostWebViewController(_ action: @escaping (WebViewController) -> Void) {
        Current.sceneManager.webViewController(in: NSApp.keyWindow ?? NSApp.mainWindow).done(action)
    }
}
#endif
