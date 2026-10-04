@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the settings list out in the states the plain render tests leave out: with debug strings
/// switched on, which adds the "translation keys are visible" warning, and pushed onto the
/// container's own navigation stack instead of embedding one.
///
/// Stays on the iOS path, whose rows are value-based links: the Catalyst sidebar keeps eager
/// `NavigationLink(destination:)` rows, so rendering it would construct every destination screen.
@MainActor
final class SettingsViewTranslationKeysRenderTests: XCTestCase {
    private static let translationKeysKey = "showTranslationKeys"

    private var previousServers: ServerManager!
    private var previousShowTranslationKeys: Any?

    override func setUp() async throws {
        previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 2)
        previousShowTranslationKeys = prefs.object(forKey: Self.translationKeysKey)
    }

    override func tearDown() async throws {
        Current.servers = previousServers
        if let previousShowTranslationKeys {
            prefs.set(previousShowTranslationKeys, forKey: Self.translationKeysKey)
        } else {
            prefs.removeObject(forKey: Self.translationKeysKey)
        }
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view.injectingViewControllerProvider())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testRendersTheTranslationKeysWarning() {
        prefs.set(true, forKey: Self.translationKeysKey)

        render(SettingsView())

        XCTAssertTrue(prefs.bool(forKey: Self.translationKeysKey))
    }

    func testRendersWhenPushedOntoTheContainersStack() {
        prefs.set(false, forKey: Self.translationKeysKey)

        render(NavigationStack { SettingsView(embedInOwnNavigation: false) })
    }
}
