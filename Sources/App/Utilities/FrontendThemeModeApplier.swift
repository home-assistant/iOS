import Foundation
import Shared
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Styles each window with the theme mode of the frontend its scene is showing.
///
/// Windows with no server of their own — the Mac's Settings, About and Assist windows, and onboarding —
/// follow the frontend that reported last.
@MainActor
final class FrontendThemeModeApplier {
    static let shared = FrontendThemeModeApplier()

    /// Posted when a scene comes to the front: on the Mac, where every window is its own scene, that is a
    /// window becoming key.
    static var sceneDidActivateNotification: Notification.Name {
        #if os(macOS)
        return NSWindow.didBecomeKeyNotification
        #else
        return UIScene.didActivateNotification
        #endif
    }

    private let windowScenes: @MainActor () -> [PlatformWindowScene]
    private var modes: [Identifier<Server>: FrontendThemeMode] = [:]
    private var scenes: [Identifier<Server>: @MainActor () -> PlatformWindowScene?] = [:]
    private var fallback: FrontendThemeMode = .automatic

    init(windowScenes: (@MainActor () -> [PlatformWindowScene])? = nil) {
        self.windowScenes = windowScenes ?? {
            #if os(macOS)
            return NSApplication.shared.windows
            #else
            return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            #endif
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(apply),
            name: Self.sceneDidActivateNotification,
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
    func frontend(
        for server: Identifier<Server>,
        showingIn scene: @escaping @MainActor () -> PlatformWindowScene?
    ) {
        scenes[server] = scene
        apply()
    }

    #if os(macOS)
    @objc func apply() {
        var modeByWindow: [ObjectIdentifier: FrontendThemeMode] = [:]
        for (server, scene) in scenes {
            guard let window = scene(), let mode = modes[server] else { continue }
            modeByWindow[ObjectIdentifier(window)] = mode
        }

        for window in windowScenes() {
            // A sheet, popover or other child window belongs to the window it is attached to, the way
            // everything a scene presents shares the scene's windows on iOS.
            let owner = Self.owner(of: window)
            // The status item, menus and tooltips live above the normal level and follow the system.
            guard owner.level == .normal else { continue }
            let appearance = (modeByWindow[ObjectIdentifier(owner)] ?? fallback).appearance
            if window.appearance?.name != appearance?.name {
                window.appearance = appearance
            }
        }
    }

    private static func owner(of window: NSWindow) -> NSWindow {
        var owner = window
        while let parent = owner.sheetParent ?? owner.parent {
            owner = parent
        }
        return owner
    }
    #else
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
    #endif
}
