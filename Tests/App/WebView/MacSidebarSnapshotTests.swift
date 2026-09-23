@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

@Suite(.serialized)
@MainActor
struct MacSidebarSnapshotTests {
    private enum Constants {
        static let width: CGFloat = 240
        static let height: CGFloat = 420
    }

    private func panel(_ path: String, component: String = "lovelace", title: String) -> HAPanel {
        HAPanel(
            icon: nil,
            title: title,
            path: path,
            component: component,
            showInSidebar: true,
            defaultVisible: nil,
            rawTitle: title
        )
    }

    private var previewPanels: [HAPanel] {
        [
            panel("home", component: "home", title: "Overview"),
            panel("energy", component: "energy", title: "Energy"),
            panel("config", component: "config", title: "Settings"),
        ]
    }

    private func makeViewModel(suiteName: String, hiddenPanelPaths: [String] = []) -> MacSidebarViewModel {
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let server = ServerFixture.standard
        let store = MacSidebarSnapshotStore(userDefaults: userDefaults)
        store.store(
            MacSidebarSnapshot(
                panels: previewPanels,
                hiddenPanels: hiddenPanelPaths.isEmpty ? nil : hiddenPanelPaths,
                isAdmin: true,
                userName: "Bruno"
            ),
            for: server.identifier.rawValue
        )
        return MacSidebarViewModel(server: server, overlayState: WebFrontendOverlayState(), snapshotStore: store)
    }

    @Test func rendersInTheAppsDefaultAccentUntilAThemeIsCaptured() {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        Current.frontendTheme = { StubFrontendThemeProvider() }

        let viewModel = makeViewModel(suiteName: "MacSidebarSnapshotTests.default")
        assertLightDarkSnapshots(
            of: MacSidebarView(viewModel: viewModel).frame(width: Constants.width, height: Constants.height),
            layout: .fixed(width: Constants.width, height: Constants.height)
        )
    }

    @Test func rendersInTheServersCapturedPrimaryColor() {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        let stub = StubFrontendThemeProvider()
        stub.set(.purple, for: .primaryColor)
        Current.frontendTheme = { stub }

        let viewModel = makeViewModel(suiteName: "MacSidebarSnapshotTests.tinted")
        assertLightDarkSnapshots(
            of: MacSidebarView(viewModel: viewModel).frame(width: Constants.width, height: Constants.height),
            layout: .fixed(width: Constants.width, height: Constants.height)
        )
    }

    @Test func rendersHiddenItemsInTheServersCapturedPrimaryColorWhileEditing() {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        let stub = StubFrontendThemeProvider()
        stub.set(.purple, for: .primaryColor)
        Current.frontendTheme = { stub }

        let viewModel = makeViewModel(suiteName: "MacSidebarSnapshotTests.hidden", hiddenPanelPaths: ["energy"])
        viewModel.isEditing = true
        assertLightDarkSnapshots(
            of: MacSidebarView(viewModel: viewModel).frame(width: Constants.width, height: Constants.height),
            layout: .fixed(width: Constants.width, height: Constants.height)
        )
    }

    @Test func accentColorUpdatesWhenTheCapturedThemeChanges() async {
        let previousProvider = Current.frontendTheme
        defer { Current.frontendTheme = previousProvider }
        let stub = StubFrontendThemeProvider()
        Current.frontendTheme = { stub }

        let viewModel = makeViewModel(suiteName: "MacSidebarSnapshotTests.notification")
        #expect(viewModel.accentColor == .haPrimary)

        stub.set(.purple, for: .primaryColor)
        NotificationCenter.default.post(name: FrontendThemeProvider.didChangeNotification, object: nil)
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.accentColor == .purple)
    }
}
