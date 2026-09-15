import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the settings list out so SwiftUI evaluates its body, covering the section and row
/// builders including the header-less App Labs section and the static subtitle its row carries.
///
/// Stays on the iOS path, whose rows are value-based links: the Catalyst sidebar keeps eager
/// `NavigationLink(destination:)` rows, so rendering it would construct every destination screen
/// — and the view models some of them build in `init`, which reach for the real database.
@MainActor
@Suite(.serialized)
struct SettingsViewRenderTests {
    private func withEnvironment(isTestFlight: Bool, _ work: () -> Void) {
        let previousTestFlight = Current.isTestFlight
        let previousServers = Current.servers
        defer {
            Current.isTestFlight = previousTestFlight
            Current.servers = previousServers
        }
        Current.isTestFlight = isTestFlight
        Current.servers = FakeServerManager(initial: 1)
        work()
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window
    /// is key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view.injectingViewControllerProvider())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func rendersTheListWithAppLabs() {
        withEnvironment(isTestFlight: true) {
            #expect(SettingsItem.appLabs.isVisible)
            render(SettingsView())
        }
    }

    /// Without TestFlight the App Labs section drops out entirely, so the list falls back to the
    /// headed sections alone.
    @Test func rendersTheListWithoutAppLabs() {
        withEnvironment(isTestFlight: false) {
            #expect(!SettingsItem.appLabs.isVisible)
            render(SettingsView())
        }
    }
}
