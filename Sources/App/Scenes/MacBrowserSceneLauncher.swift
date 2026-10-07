import Shared

/// Gates the Mac "Open Home Assistant UI in browser" (`macNativeFeaturesOnly`) auto-launch that runs when a
/// `"WebView"` scene connects (see `QuickActionWindowSceneDelegate`).
///
/// The empty webview window is destroyed on every `"WebView"` scene connection — under `macNativeFeaturesOnly`
/// there is never an in-app window — but Home Assistant is opened in the browser only on the *first* connection
/// of the process, the user's cold launch. macOS reconnects this scene in the background throughout the app's
/// lifetime (for state restoration and other background work), and every reconnection used to reopen the
/// browser, so the dashboard reappeared every few minutes even though the user never asked for it (#4985).
/// Later, genuinely user-initiated opens while the app is already running are handled elsewhere — the Dock
/// reopen handler and the status-item menu both go through `StatusItemPrimaryAction.openInBrowserIfNeeded()`.
enum MacBrowserSceneLauncher {
    /// Whether the initial (cold-launch) `"WebView"` scene connection has already been observed this process.
    /// Reset only implicitly, by the process being relaunched.
    private(set) static var didHandleInitialSceneConnection = false

    /// Records that a `"WebView"` scene has connected and reports whether this was the first connection of the
    /// process (i.e. the user's cold launch). Subsequent calls return `false`.
    @discardableResult
    static func markSceneConnected() -> Bool {
        let isInitialConnection = !didHandleInitialSceneConnection
        didHandleInitialSceneConnection = true
        return isInitialConnection
    }

    /// Whether the "Open Home Assistant UI in browser" behaviour applies on this platform/configuration.
    static var isBrowserLaunchEnabled: Bool {
        Current.isCatalyst && Current.settingsStore.macNativeFeaturesOnly
    }

    struct SceneConnectionActions {
        let opensBrowser: Bool
        let destroysEmptyWindow: Bool
    }

    static func actions(isInitialConnection: Bool) -> SceneConnectionActions {
        guard isBrowserLaunchEnabled else {
            return SceneConnectionActions(opensBrowser: false, destroysEmptyWindow: false)
        }
        return SceneConnectionActions(opensBrowser: isInitialConnection, destroysEmptyWindow: true)
    }

    #if DEBUG
    static func resetInitialSceneConnectionForTesting() {
        didHandleInitialSceneConnection = false
    }
    #endif
}
