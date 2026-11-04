import Foundation
import HAKit
import Shared
import UIKit

/// Reads the theme mode of the server one frontend scene is showing, and reports it to the applier.
@MainActor
final class FrontendThemeModeObserver {
    private let defaults: UserDefaults
    private let applier: FrontendThemeModeApplier

    private var serverIdentifier: Identifier<Server>?
    private var subscription: HACancellable?

    init(defaults: UserDefaults = prefs, applier: FrontendThemeModeApplier = .shared) {
        self.defaults = defaults
        self.applier = applier
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    deinit {
        subscription?.cancel()
        NotificationCenter.default.removeObserver(self)
    }

    /// `nil` — onboarding, or a server being recovered — gives the appearance back to the device.
    func observe(server: Server?) {
        guard server?.identifier != serverIdentifier else { return }

        subscription?.cancel()
        subscription = nil
        let previous = serverIdentifier
        serverIdentifier = server?.identifier

        guard let server else {
            previous.map { applier.setMode(.automatic, for: $0) }
            return
        }

        // The remembered mode covers the wait for the websocket, so a cold launch doesn't flash.
        applier.setMode(cachedMode(for: server.identifier), for: server.identifier)
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
            initiated: { [weak self] result in
                guard case let .failure(error) = result else { return }
                Current.Log.info("frontend theme mode unavailable: \(error.localizedDescription)")
                // Only the command being unknown says this server has no preference; the rest are transient.
                guard case let .external(external) = error, external.code == "unknown_command" else { return }
                MainActor.assumeIsolated {
                    self?.forget(identifier)
                }
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
        applier.setMode(mode, for: identifier)
    }

    /// A server that cannot answer has no preference, so one remembered from before must not stick.
    private func forget(_ identifier: Identifier<Server>) {
        guard identifier == serverIdentifier else { return }
        defaults.removeObject(forKey: Self.cacheKey(for: identifier))
        applier.setMode(.automatic, for: identifier)
    }

    /// Retries a server that had no reachable URL when its frontend first appeared.
    @objc private func sceneDidActivate() {
        guard subscription == nil, let identifier = serverIdentifier,
              let server = Current.servers.server(forServerIdentifier: identifier.rawValue) else { return }
        subscribe(to: server)
    }

    private func cachedMode(for identifier: Identifier<Server>) -> FrontendThemeMode {
        defaults.string(forKey: Self.cacheKey(for: identifier))
            .flatMap(FrontendThemeMode.init(rawValue:)) ?? .automatic
    }

    private static func cacheKey(for identifier: Identifier<Server>) -> String {
        "frontendThemeMode-\(identifier.rawValue)"
    }
}
