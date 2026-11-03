import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import ObjectiveC
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// The main menu and status item plumbing: the menu builder gets the web view and file menus (inserted
/// the first time, replaced after), commands carry their URL, the status item title subscribes to the
/// configured template (and only resubscribes when it changes), the REST fallback renders every kind of
/// answer, and the browser-only preference opens the server in the browser.
///
/// `.sharedState`: the tests write the menu bar preferences and swap `Current.servers`, the cached API
/// and `URLOpener.shared`.
@Suite(.sharedState)
@MainActor
struct MenuManagerTests {
    /// Implements just the `UIMenuBuilder` calls `MenuManager` makes on iOS; the protocol is added to
    /// the class at runtime because its full (largely iOS 26) surface isn't needed here.
    private final class FakeMenuBuilder: NSObject {
        var menus: [String: UIMenu] = [:]
        var removed: [String] = []
        var insertedSiblings = 0
        var insertedChildren = 0
        var replacements = 0

        @objc(menuForIdentifier:)
        func menu(for identifier: UIMenu.Identifier) -> UIMenu? {
            menus[identifier.rawValue]
        }

        @objc(removeMenuForIdentifier:)
        func remove(menu identifier: UIMenu.Identifier) {
            removed.append(identifier.rawValue)
        }

        @objc(insertSiblingMenu:beforeMenuForIdentifier:)
        func insertSibling(_ menu: UIMenu, beforeMenu identifier: UIMenu.Identifier) {
            menus[menu.identifier.rawValue] = menu
            insertedSiblings += 1
        }

        @objc(insertChildMenu:atStartOfMenuForIdentifier:)
        func insertChild(_ menu: UIMenu, atStartOfMenu identifier: UIMenu.Identifier) {
            menus[menu.identifier.rawValue] = menu
            insertedChildren += 1
        }

        @objc(replaceMenuForIdentifier:withMenu:)
        func replace(menu identifier: UIMenu.Identifier, with replacement: UIMenu) {
            menus[identifier.rawValue] = replacement
            replacements += 1
        }
    }

    private func makeManager() throws -> (MenuManager, FakeMenuBuilder) {
        let builder = FakeMenuBuilder()
        let menuBuilderProtocol = try #require(objc_getProtocol("UIMenuBuilder"))
        class_addProtocol(FakeMenuBuilder.self, menuBuilderProtocol)
        let menuBuilder = try #require((builder as AnyObject) as? UIMenuBuilder)
        return (MenuManager(builder: menuBuilder), builder)
    }

    private static let preferenceKeys = [
        "menuItemTemplate", "menuItemTemplate-server", "locationVisibility", "macNativeFeaturesOnly",
    ]

    private func preservingPreferences(_ body: () async throws -> Void) async rethrows {
        let prefs = Current.settingsStore.prefs
        let previous = Self.preferenceKeys.map { prefs.object(forKey: $0) }
        let previousServers = Current.servers
        let previousOpener = URLOpener.shared
        defer {
            for (key, value) in zip(Self.preferenceKeys, previous) {
                prefs.set(value, forKey: key)
            }
            Current.servers = previousServers
            URLOpener.shared = previousOpener
        }
        try await body()
    }

    // MARK: - Menus

    @Test func menusAreInsertedOnceThenReplaced() throws {
        let (manager, builder) = try makeManager()
        #expect(builder.removed.contains(UIMenu.Identifier.format.rawValue))
        #expect(builder.insertedSiblings == 1)
        #expect(builder.insertedChildren == 1)
        #expect(builder.menus["ha.webViewActions"]?.children.count == 2)
        #expect(builder.menus["ha.file"]?.children.count == 1)

        manager.update()
        #expect(builder.replacements == 2)
        #expect(builder.insertedSiblings == 1)
    }

    @Test func commandsCarryTheirURL() {
        let action = NSSelectorFromString("refresh")
        let withURL = UICommand(title: "Open", action: action, propertyList: ["url": "https://example.com/a"])
        #expect(MenuManager.url(from: withURL)?.absoluteString == "https://example.com/a")
        #expect(MenuManager.url(from: UICommand(title: "None", action: action)) == nil)
        #expect(MenuManager.url(from: UICommand(title: "Bad", action: action, propertyList: ["url": 1])) == nil)
    }

    // MARK: - Status item title

    @Test func theStatusItemTitleFollowsTheTemplate() async throws {
        try await preservingPreferences {
            let servers = FakeServerManager(initial: 1)
            let server = servers.all[0]
            Current.servers = servers
            let connection = HAMockConnection()
            connection.automaticallyTransitionToConnecting = false
            let api = HomeAssistantAPI(server: server)
            api.connection = connection
            Current.setCachedApi(api, for: server.identifier)
            defer { Current.resetAPICache(for: [server.identifier]) }

            let (manager, _) = try makeManager()
            var updates: [String] = []

            // Hidden from the menu bar: nothing to subscribe to.
            Current.settingsStore.locationVisibility = .dock
            Current.settingsStore.menuItemTemplate = (server, "{{ 1 }}")
            #expect(manager.subscribeStatusItemTitle(existing: nil) { updates.append($0) } == nil)

            Current.settingsStore.locationVisibility = .menuBar
            let first = try #require(manager.subscribeStatusItemTitle(existing: nil) { updates.append($0) })
            #expect(first.template == "{{ 1 }}")
            #expect(connection.pendingSubscriptions.count == 1)

            // The same template keeps the subscription.
            let same = manager.subscribeStatusItemTitle(existing: first) { updates.append($0) }
            #expect(same == first)

            // A new template replaces it.
            Current.settingsStore.menuItemTemplate = (server, "{{ 2 }}")
            let second = try #require(manager.subscribeStatusItemTitle(existing: first) { updates.append($0) })
            #expect(second != first)
            #expect(second.template == "{{ 2 }}")
            #expect(connection.cancelledSubscriptions.count == 1)
            second.cancel()
            #expect(!updates.contains { !$0.isEmpty })
        }
    }

    @Test func aServerWithoutAnAPIHasNoTitle() async throws {
        try await preservingPreferences {
            let servers = FakeServerManager()
            var info = ServerInfo.fake()
            info.connection.set(address: nil, for: .external)
            let server = servers.add(identifier: .init(rawValue: "offline"), serverInfo: info)
            Current.servers = servers
            Current.settingsStore.locationVisibility = .dockAndMenuBar
            Current.settingsStore.menuItemTemplate = (server, "{{ 1 }}")

            let (manager, _) = try makeManager()
            var updates: [String] = []
            #expect(manager.subscribeStatusItemTitle(existing: nil) { updates.append($0) } == nil)
            #expect(updates == [""])
        }
    }

    @Test func theRESTFallbackRendersEachKindOfAnswer() throws {
        let answers: [(HAData, String?)] = [
            (.dictionary(["a": 1]), "[\"a\": 1]"),
            (.array([.primitive(1)]), nil),
            (.empty, ""),
        ]
        for (data, expected) in answers {
            let connection = HAMockConnection()
            connection.automaticallyTransitionToConnecting = false
            let api = HomeAssistantAPI(server: .fake())
            api.connection = connection
            var updates: [String] = []
            let token = StatusItemTitleRenderer.subscribe(api: api, template: "{{ x }}") { updates.append($0) }
            defer { token.cancel() }

            let subscription = try #require(connection.pendingSubscriptions.first)
            subscription.initiated(.success(.empty))
            let request = try #require(connection.pendingRequests.first)
            request.completion(.success(data))

            #expect(updates.count == 1)
            if let expected {
                #expect(updates.first == expected)
            }
        }
    }

    @Test func subscriptionsCompareByIdentity() {
        let server = Server.fake()
        let token = HAMockCancellable({})
        let one = MenuManagerTitleSubscription(server: server, template: "{{ 1 }}", token: token)
        let other = MenuManagerTitleSubscription(server: server, template: "{{ 1 }}", token: token)
        #expect(one == one)
        #expect(one != other)
        one.cancel()
        #expect(token.wasCancelled)
    }

    // MARK: - Browser-only preference

    @Test func theBrowserPreferenceOpensTheServerInTheBrowser() async {
        await preservingPreferences {
            let opener = MockURLOpener()
            URLOpener.shared = opener
            Current.servers = FakeServerManager(initial: 1)
            Current.settingsStore.menuItemTemplate = nil

            Current.settingsStore.macNativeFeaturesOnly = false
            #expect(!StatusItemPrimaryAction.openInBrowserIfNeeded())
            #expect(opener.openedURLs.isEmpty)

            Current.settingsStore.macNativeFeaturesOnly = true
            #expect(StatusItemPrimaryAction.openInBrowserIfNeeded())
            #expect(opener.openedURLs.count == 1)

            Current.servers = FakeServerManager(initial: 0)
            #expect(!StatusItemPrimaryAction.openInBrowserIfNeeded())
        }
    }
}
