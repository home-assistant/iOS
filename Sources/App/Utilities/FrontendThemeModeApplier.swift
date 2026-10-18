import Foundation
import Shared
import UIKit

/// Styles each window with the theme mode of the frontend its scene is showing.
///
/// Windows with no server of their own — the Mac's Settings, About and Assist windows, and onboarding —
/// follow the frontend that reported last.
@MainActor
final class FrontendThemeModeApplier {
    static let shared = FrontendThemeModeApplier()

    private let windowScenes: @MainActor () -> [UIWindowScene]
    private var modes: [Identifier<Server>: FrontendThemeMode] = [:]
    private var scenes: [Identifier<Server>: @MainActor () -> UIWindowScene?] = [:]
    private var fallback: FrontendThemeMode = .automatic

    init(windowScenes: (@MainActor () -> [UIWindowScene])? = nil) {
        self.windowScenes = windowScenes ?? {
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apply),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func mode(for server: Identifier<Server>) -> FrontendThemeMode {
        modes[server] ?? .automatic
    }

    func setMode(_ mode: FrontendThemeMode, for server: Identifier<Server>) {
        modes[server] = mode
        fallback = mode
        apply()
    }

    /// The scene is resolved on every apply, because the frontend is handed over before it has a window.
    func frontend(for server: Identifier<Server>, showingIn scene: @escaping @MainActor () -> UIWindowScene?) {
        scenes[server] = scene
        apply()
    }

    @objc func apply() {
        var modeByScene: [String: FrontendThemeMode] = [:]
        for (server, scene) in scenes {
            guard let identifier = scene()?.session.persistentIdentifier, let mode = modes[server] else { continue }
            modeByScene[identifier] = mode
        }

        for scene in windowScenes() {
            let mode = modeByScene[scene.session.persistentIdentifier] ?? fallback
            for window in scene.windows {
                window.overrideUserInterfaceStyle = mode.userInterfaceStyle
            }
        }
    }
}
