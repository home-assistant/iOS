@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@Suite(.serialized)
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
}
