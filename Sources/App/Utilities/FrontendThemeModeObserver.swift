import Foundation
import HAKit
import Shared
import UIKit

/// Overrides the app's interface style with the theme mode of the server whose frontend is on screen.
@MainActor
final class FrontendThemeModeObserver {
    static let shared = FrontendThemeModeObserver()

    private let defaults: UserDefaults
    private let applyStyle: @MainActor (UIUserInterfaceStyle) -> Void

    private var serverIdentifier: Identifier<Server>?
    private var subscription: HACancellable?
    private var appliedMode: FrontendThemeMode = .automatic

    /// `applyStyle` is the seam tests use, so they don't restyle the windows the test host runs in.
    init(
        defaults: UserDefaults = prefs,
        applyStyle: (@MainActor (UIUserInterfaceStyle) -> Void)? = nil
    ) {
        self.defaults = defaults
        self.applyStyle = applyStyle ?? FrontendThemeModeObserver.overrideConnectedWindows
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// `nil` — onboarding, or a server being recovered — gives the appearance back to the device.
    func observe(server: Server?) {
        guard server?.identifier != serverIdentifier else { return }

        subscription?.cancel()
        subscription = nil
        serverIdentifier = server?.identifier

        guard let server else {
            apply(.automatic)
            return
        }

        // The remembered mode covers the wait for the websocket, so a cold launch doesn't flash.
        apply(cachedMode(for: server.identifier))
        subscribe(to: server)
    }

    private func subscribe(to server: Server) {
        guard let connection = Current.api(for: server)?.connection else {
            // No usable URL for this server yet; the next scene activation tries again.
            Current.Log.info("no connection to read the frontend theme mode from yet")
            return
        }

        let identifier = server.identifier
        subscription = connection.subscribe(
            to: HARequest(
                type: .webSocket("frontend/subscribe_user_data"),
                data: ["key": "theme"],
                // The default expires ten seconds in, which would end the subscription at the first reconnect.
                retryDuration: nil
            ),
            initiated: { result in
                guard case let .failure(error) = result else { return }
                // Cores that predate server-side theme preferences have no preference to honour.
                Current.Log.info("frontend theme mode unavailable: \(error.localizedDescription)")
            },
            handler: { [weak self] _, data in
                // HAKit's `callbackQueue` is the main queue everywhere in the app.
                MainActor.assumeIsolated {
                    self?.handle(data, for: identifier)
                }
            }
        )
    }

    private func handle(_ data: HAData, for identifier: Identifier<Server>) {
        // An answer that arrives after the user switched server belongs to the old one.
        guard identifier == serverIdentifier else { return }
        guard case let .dictionary(response) = data else { return }

        let mode = FrontendThemeMode(userDataValue: response["value"])
        defaults.set(mode.rawValue, forKey: Self.cacheKey(for: identifier))
        apply(mode)
    }

    private func apply(_ mode: FrontendThemeMode) {
        appliedMode = mode
        applyStyle(mode.userInterfaceStyle)
    }

    /// Catches up windows opened after the mode was read, and retries a server that had no URL then.
    @objc private func sceneDidActivate() {
        apply(appliedMode)

        guard subscription == nil, let identifier = serverIdentifier,
              let server = Current.servers.server(forServerIdentifier: identifier.rawValue) else { return }
        subscribe(to: server)
    }

    /// Overriding the windows also reaches the UIKit controllers presented over the frontend.
    static func overrideConnectedWindows(_ style: UIUserInterfaceStyle) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }

    private func cachedMode(for identifier: Identifier<Server>) -> FrontendThemeMode {
        defaults.string(forKey: Self.cacheKey(for: identifier))
            .flatMap(FrontendThemeMode.init(rawValue:)) ?? .automatic
    }

    private static func cacheKey(for identifier: Identifier<Server>) -> String {
        "frontendThemeMode-\(identifier.rawValue)"
    }
}
