@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@Suite(.sharedState)
@MainActor
struct MacSidebarViewModelTests {
    @Test func accentColorUpdatesWhenTheCapturedThemeChanges() async {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        let stub = StubFrontendThemeProvider()
        Current.frontendTheme = { stub }

        let suiteName = "MacSidebarViewModelTests.accentColor"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let viewModel = MacSidebarViewModel(
            server: ServerFixture.standard,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: MacSidebarSnapshotStore(userDefaults: userDefaults)
        )
        #expect(viewModel.accentColor == .haPrimary)

        stub.set(.purple, for: .primaryColor)
        NotificationCenter.default.post(name: FrontendThemeProvider.didChangeNotification, object: nil)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.accentColor == .purple)
    }

    @Test func badgeColorsFollowTheFrontendAccentColor() async {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        let stub = StubFrontendThemeProvider()
        Current.frontendTheme = { stub }

        let suiteName = "MacSidebarViewModelTests.badgeColor"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let viewModel = MacSidebarViewModel(
            server: ServerFixture.standard,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: MacSidebarSnapshotStore(userDefaults: userDefaults)
        )

        stub.set(.orange, for: .accentColor)
        stub.set(.black, for: .textPrimaryColor)
        NotificationCenter.default.post(name: FrontendThemeProvider.didChangeNotification, object: nil)
        let themed = await waitUntil { viewModel.badgeColor == .orange && viewModel.badgeTextColor == .black }
        #expect(themed)

        stub.set(.white, for: "--text-accent-color")
        NotificationCenter.default.post(name: FrontendThemeProvider.didChangeNotification, object: nil)
        let overridden = await waitUntil { viewModel.badgeTextColor == .white }
        #expect(overridden)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
