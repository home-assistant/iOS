import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the settings list out so SwiftUI evaluates its body, covering the section and row
/// builders on both the iOS list and the Catalyst sidebar, including the header-less App Labs
/// section and the static subtitle its row carries.
@MainActor
@Suite(.serialized)
struct SettingsViewRenderTests {
    private func withEnvironment(isCatalyst: Bool, isTestFlight: Bool, _ work: () -> Void) {
        let previousCatalyst = Current.isCatalyst
        let previousTestFlight = Current.isTestFlight
        let previousServers = Current.servers
        defer {
            Current.isCatalyst = previousCatalyst
            Current.isTestFlight = previousTestFlight
            Current.servers = previousServers
        }
        Current.isCatalyst = isCatalyst
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

    @Test func rendersTheIOSListWithAppLabs() {
        withEnvironment(isCatalyst: false, isTestFlight: true) {
            #expect(SettingsItem.appLabs.isVisible)
            render(SettingsView())
        }
    }

    /// Without TestFlight the App Labs section drops out entirely, so the list falls back to the
    /// headed sections alone.
    @Test func rendersTheIOSListWithoutAppLabs() {
        withEnvironment(isCatalyst: false, isTestFlight: false) {
            #expect(!SettingsItem.appLabs.isVisible)
            render(SettingsView())
        }
    }

    @Test func rendersTheCatalystSidebarWithAppLabs() {
        withEnvironment(isCatalyst: true, isTestFlight: true) {
            render(SettingsView())
        }
    }
}
