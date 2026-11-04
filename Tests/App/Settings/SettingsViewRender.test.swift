import Foundation
@testable import HomeAssistant
@testable import Shared
import SharedTesting
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
@Suite(.sharedState)
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

    /// The Mac sidebar's warning row opens the explanation in the detail column, listing the
    /// servers that report the same instance ID.
    @Test func rendersTheServerIdentityDetailOnMac() {
        let previousCatalyst = Current.isCatalyst
        let previousServers = Current.servers
        defer {
            Current.isCatalyst = previousCatalyst
            Current.servers = previousServers
        }
        let servers = FakeServerManager()
        for (identifier, name) in [("home", "Home"), ("chalet", "Chalet")] {
            servers.add(identifier: .init(rawValue: identifier), serverInfo: with(ServerInfo.fake()) {
                $0.remoteName = name
                $0.instanceID = "shared-instance"
            })
        }
        Current.servers = servers
        Current.isCatalyst = true

        render(SettingsView(macSidebarSelection: .serverIdentity))

        #expect(ServersObserver().serverIdentityConflicts.map { $0.map(\.name) } == [["Home", "Chalet"]])
    }

    /// Without TestFlight the App Labs section drops out entirely, so the list falls back to the
    /// headed sections alone.
    @Test func rendersTheListWithoutAppLabs() {
        withEnvironment(isTestFlight: false) {
            #expect(!SettingsItem.appLabs.isVisible)
            render(SettingsView())
        }
    }

    // MARK: - Search and the Mac split view

    private func twoServers() -> FakeServerManager {
        let servers = FakeServerManager()
        for (identifier, name) in [("home", "Home"), ("chalet", "Chalet")] {
            servers.add(identifier: .init(rawValue: identifier), serverInfo: with(ServerInfo.fake()) {
                $0.remoteName = name
            })
        }
        return servers
    }

    /// Searching lists the servers screen, servers matched by name or by their connection settings,
    /// and the matching rows of every section; a query nothing matches shows the empty state.
    @Test func searchingListsServersSectionsAndTheEmptyState() async throws {
        let previousServers = Current.servers
        let previousCatalyst = Current.isCatalyst
        defer {
            Current.servers = previousServers
            Current.isCatalyst = previousCatalyst
        }
        Current.servers = twoServers()
        Current.isCatalyst = false

        let driver = await SwiftUIScreenDriver.show(
            SettingsView().injectingViewControllerProvider(),
            inNavigationStack: false
        )
        defer { driver.close() }

        await driver.search("Chalet")
        #expect(!driver.rows.isEmpty)

        await driver.search(SettingsItem.servers.title)
        #expect(!driver.rows.isEmpty)

        let connectionEntry = try #require(ConnectionSettingsView.settingsSearchEntries.first)
        await driver.search(connectionEntry.title)
        #expect(driver.rows.count >= 2)

        await driver.search("zqxjv no such setting")
        #expect(driver.rows.count == 1)

        await driver.search("")
        #expect(driver.rows.count > 5)
    }

    /// With debug strings on, the list warns about it and its button turns them back off.
    @Test func theTranslationKeysWarningTurnsDebugStringsOff() async throws {
        let previousKeys = prefs.object(forKey: "showTranslationKeys")
        let previousServers = Current.servers
        let previousCatalyst = Current.isCatalyst
        defer {
            prefs.set(previousKeys, forKey: "showTranslationKeys")
            Current.servers = previousServers
            Current.isCatalyst = previousCatalyst
        }
        prefs.set(true, forKey: "showTranslationKeys")
        Current.servers = FakeServerManager(initial: 1)
        Current.isCatalyst = false
        let previousTestFlight = Current.isTestFlight
        Current.isTestFlight = false
        defer { Current.isTestFlight = previousTestFlight }

        let driver = await SwiftUIScreenDriver.show(
            SettingsView().injectingViewControllerProvider(),
            inNavigationStack: false
        )
        defer { driver.close() }

        // The warning sits right below the servers.
        await driver.tapRow(IndexPath(item: 0, section: 1))
        await #expect(driver.waitUntil { !prefs.bool(forKey: "showTranslationKeys") })

        // Without App Labs, About is the last section and What's New the one above it; both only
        // raise their sheets.
        let lastSection = driver.sectionCount - 1
        await driver.tapRow(IndexPath(item: 0, section: lastSection))
        await driver.tapRow(IndexPath(item: 0, section: lastSection - 1))
    }

    /// A row opens its screen through the list's navigation destination; scrolling down shows App
    /// Labs at the very bottom, and Close is offered on the leading side.
    @Test func rowsOpenTheirScreensAndAppLabsSitsLast() async throws {
        let previousServers = Current.servers
        let previousCatalyst = Current.isCatalyst
        let previousTestFlight = Current.isTestFlight
        defer {
            Current.servers = previousServers
            Current.isCatalyst = previousCatalyst
            Current.isTestFlight = previousTestFlight
        }
        Current.servers = FakeServerManager(initial: 1)
        Current.isCatalyst = false
        Current.isTestFlight = true

        try await SettingsTestDatabase.with { _ in
            let driver = await SwiftUIScreenDriver.show(
                SettingsView().injectingViewControllerProvider(),
                inNavigationStack: false
            )
            defer { driver.close() }

            // The first settings group follows the servers section.
            try await #require(driver.push(IndexPath(item: 0, section: 1)))
            await driver.popToRoot()

            let last = driver.sectionCount - 1
            await driver.tapRow(IndexPath(item: 0, section: last))
            await driver.popToRoot()
            for index in driver.barButtons.indices where driver.barButtons[index].title == nil {
                await driver.tapBarButton(index)
            }
        }
    }

    /// The Help row opens the companion documentation in the browser instead of pushing a screen.
    @Test func helpOpensTheCompanionDocumentation() async throws {
        let previousServers = Current.servers
        let previousCatalyst = Current.isCatalyst
        let previousTranslationKeys = prefs.object(forKey: "showTranslationKeys")
        defer {
            Current.servers = previousServers
            Current.isCatalyst = previousCatalyst
            prefs.set(previousTranslationKeys, forKey: "showTranslationKeys")
        }
        Current.servers = FakeServerManager(initial: 1)
        Current.isCatalyst = false
        prefs.set(false, forKey: "showTranslationKeys")

        try await SettingsTestDatabase.with { _ in
            try await RecordingURLOpener.with { opener in
                let driver = await SwiftUIScreenDriver.show(
                    SettingsView().injectingViewControllerProvider(),
                    inNavigationStack: false
                )
                defer { driver.close() }

                // The servers section comes first, then each settings group that has rows.
                let groupsBefore = SettingsSection.groupsAboveTrailingRows
                    .prefix { $0 != .helpSupport }
                    .filter { !$0.items.isEmpty }
                    .count
                let row = try #require(SettingsSection.helpSupport.items.firstIndex(of: .help))
                await driver.tapRow(IndexPath(item: row, section: 1 + groupsBefore))
                #expect(opener.openedURLs.map(\.url.absoluteString) == ["https://companion.home-assistant.io"])
                #expect(driver.depth == 1)
            }
        }
    }

    /// Renders the Mac split view at regular width, so the sidebar and the detail column both show,
    /// for each kind of sidebar selection, with and without a search.
    @Test(arguments: 0 ..< 5)
    func rendersTheMacSplitView(selectionIndex: Int) async throws {
        let selections: [MacSettingsSidebarSelection?] = [
            .item(.general),
            .server(.init(rawValue: "home")),
            .server(.init(rawValue: "missing")),
            .serverSwitching,
            nil,
        ]
        let selection = selections[selectionIndex]
        let previousKeys = prefs.object(forKey: "showTranslationKeys")
        let previousServers = Current.servers
        let previousCatalyst = Current.isCatalyst
        defer {
            prefs.set(previousKeys, forKey: "showTranslationKeys")
            Current.servers = previousServers
            Current.isCatalyst = previousCatalyst
        }
        prefs.set(true, forKey: "showTranslationKeys")
        Current.servers = twoServers()
        Current.isCatalyst = true

        try await SettingsTestDatabase.with { _ in
            let host = UIHostingController(
                rootView: SettingsView(macSidebarSelection: selection).injectingViewControllerProvider()
            )
            if #available(iOS 17, *) { host.traitOverrides.horizontalSizeClass = .regular }
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 1180, height: 1600))
            window.rootViewController = host
            window.isHidden = false
            defer {
                window.isHidden = true
                window.rootViewController = nil
            }
            for _ in 0 ..< 3 {
                window.layoutIfNeeded()
                try? await Task.sleep(nanoseconds: 10_000_000)
            }

            // Search from the sidebar's search field.
            let navigationControllers = Self.descendants(of: host, as: UINavigationController.self)
            if let search = navigationControllers.compactMap({
                $0.topViewController?.navigationItem.searchController
            }).first {
                for query in ["Chalet", "zqxjv no such setting", ""] {
                    search.searchBar.text = query
                    search.searchBar.delegate?.searchBar?(search.searchBar, textDidChange: query)
                    search.searchResultsUpdater?.updateSearchResults(for: search)
                    for _ in 0 ..< 2 {
                        window.layoutIfNeeded()
                        try? await Task.sleep(nanoseconds: 10_000_000)
                    }
                }
            }
            #expect(!navigationControllers.isEmpty)
        }
    }

    private static func descendants<T: UIViewController>(of root: UIViewController, as type: T.Type) -> [T] {
        var found: [T] = []
        var stack = [root]
        while let next = stack.popLast() {
            if let match = next as? T { found.append(match) }
            stack.append(contentsOf: next.children)
        }
        return found
    }
}
