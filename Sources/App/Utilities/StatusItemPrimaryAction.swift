import Foundation
import Shared

/// Shared decision for what the macOS status item should do when "activated" (icon click or the
/// "Toggle" menu item). When the user enabled "Open Home Assistant UI in browser"
/// (`macNativeFeaturesOnly`) there is no in-app web view to toggle — it is destroyed at launch by
/// `QuickActionWindowSceneDelegate` — so any "show me Home Assistant" affordance must open the default
/// browser instead of spawning a web-view window. The preference is read live on every call because
/// flipping it does not reconfigure the status item (it posts no `menuRelatedSettingDidChange`).
enum StatusItemPrimaryAction {
    /// Opens Home Assistant in the default browser when the browser preference is on.
    /// - Returns: `true` if it handled the action (browser opened), `false` to fall through to the
    ///   normal toggle/activate behaviour.
    static func openInBrowserIfNeeded() -> Bool {
        guard Current.settingsStore.macNativeFeaturesOnly else { return false }
        // Prefer the server shown in the menu-bar title; its getter already falls back to the first
        // server, so this also covers users without a configured menu-bar template.
        let server = Current.settingsStore.menuItemTemplate?.server ?? Current.servers.all.first
        // This only runs on macOS, where the last-known network information is read live from
        // macBridge, so the synchronous evaluation is current. Callers need the handled/unhandled
        // decision synchronously to fall through to the toggle behavior.
        guard let url = server?.activeURLUsingLastKnownNetworkState() else { return false }
        URLOpener.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
}
