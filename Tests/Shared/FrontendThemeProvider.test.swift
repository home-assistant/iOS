import GRDB
@testable import Shared
import SwiftUI
import Testing
import UIKit

@Suite(.serialized)
struct FrontendThemeProviderTests {
    @Test("Stored properties are read back per server and appearance")
    func readsBackWhatItStored() throws {
        try withThemeEnvironment { provider, serverId in
            provider.store(
                [
                    variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)"),
                    variable(serverId: serverId, appearance: .light, name: "--spacing", value: "8px", color: nil),
                ],
                for: serverId,
                appearance: .light
            )

            #expect(provider.variables(for: serverId, appearance: .light).count == 2)
            #expect(provider.value(of: "--spacing", for: serverId, appearance: .light) == "8px")
            #expect(provider.value(of: "--nope", for: serverId, appearance: .light) == nil)
            #expect(provider.variables(for: serverId, appearance: .dark).isEmpty)
        }
    }

    /// A screen that names no server means the one the user was last looking at.
    @Test("A nil server resolves to the last active server")
    func resolvesTheLastActiveServer() throws {
        try withThemeEnvironment { provider, serverId in
            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
                for: serverId,
                appearance: .light
            )

            Current.settingsStore.lastActiveServerIdentifier = serverId
            #expect(provider.variables(appearance: .light).count == 1)

            // An identifier no server answers to still falls back to the one server there is.
            Current.settingsStore.lastActiveServerIdentifier = "gone"
            #expect(provider.variables(appearance: .light).count == 1)
        }
    }

    @Test("Colors resolve from the row captured for the appearance being drawn")
    func resolvesColorsPerAppearance() throws {
        try withThemeEnvironment { provider, serverId in
            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(255, 0, 0)")],
                for: serverId,
                appearance: .light
            )
            provider.store(
                [variable(serverId: serverId, appearance: .dark, name: "--primary-color", color: "rgb(0, 0, 255)")],
                for: serverId,
                appearance: .dark
            )

            let color = try #require(provider.color(of: "--primary-color", for: serverId))
            #expect(components(color, style: .light) == RGBA(red: 255, green: 0, blue: 0, alpha: 255))
            #expect(components(color, style: .dark) == RGBA(red: 0, green: 0, blue: 255, alpha: 255))
        }
    }

    /// Only `value` is set for a theme whose colour the browser never canonicalised, so it is tried too.
    @Test("A color falls back to the raw value when no canonical color was captured")
    func resolvesColorsFromTheRawValue() throws {
        try withThemeEnvironment { provider, serverId in
            provider.store(
                [variable(
                    serverId: serverId,
                    appearance: .light,
                    name: "--primary-color",
                    value: "#ff9800",
                    color: nil
                )],
                for: serverId,
                appearance: .light
            )

            let color = try #require(provider.color(of: "--primary-color", for: serverId))
            #expect(components(color, style: .light) == RGBA(red: 255, green: 152, blue: 0, alpha: 255))
        }
    }

    @Test("A property that was never captured has no color")
    func hasNoColorForAnUncapturedProperty() throws {
        try withThemeEnvironment { provider, serverId in
            #expect(provider.color(of: "--primary-color", for: serverId) == nil)
            // Nor does a property that is stored but is not a colour.
            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--spacing", value: "8px", color: nil)],
                for: serverId,
                appearance: .light
            )
            #expect(provider.color(of: "--spacing", for: serverId) == nil)
        }
    }

    /// Before the web view has ever loaded there is nothing captured, and the screen still has to draw.
    @Test("A known frontend property falls back to the default the frontend ships")
    func fallsBackToTheFrontendDefault() throws {
        try withThemeEnvironment { provider, serverId in
            let fallback = provider.color(.accentColor, for: serverId)
            #expect(components(fallback, style: .light) == RGBA(red: 255, green: 152, blue: 0, alpha: 255))

            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--accent-color", color: "rgb(1, 2, 3)")],
                for: serverId,
                appearance: .light
            )

            let captured = provider.color(.accentColor, for: serverId)
            #expect(components(captured, style: .light) == RGBA(red: 1, green: 2, blue: 3, alpha: 255))
        }
    }

    @Test("Storing notifies observers")
    func notifiesOnStore() throws {
        try withThemeEnvironment { provider, serverId in
            var notifications = 0
            let token = NotificationCenter.default.addObserver(
                forName: FrontendThemeProvider.didChangeNotification,
                object: nil,
                queue: nil
            ) { _ in notifications += 1 }
            defer { NotificationCenter.default.removeObserver(token) }

            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
                for: serverId,
                appearance: .light
            )
            provider.reload()

            #expect(notifications == 2)
        }
    }

    /// The cache is filled from the database on first use, which is what themes a screen that is drawn
    /// before the web view has loaded in this launch.
    @Test("Reloading picks up rows written behind the cache's back")
    func reloadsFromTheDatabase() throws {
        try withThemeEnvironment { provider, serverId in
            try FrontendThemeVariable.replaceAll(
                [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
                serverId: serverId,
                appearance: .light
            )

            // A provider that has never read anything loads lazily on the first lookup.
            #expect(provider.variables(for: serverId, appearance: .light).count == 1)

            try FrontendThemeVariable.replaceAll([], serverId: serverId, appearance: .light)
            #expect(provider.variables(for: serverId, appearance: .light).count == 1)

            provider.reload()
            #expect(provider.variables(for: serverId, appearance: .light).isEmpty)
        }
    }

    /// A capture for one server must not convince the cache it holds every server: the first theme
    /// event of a launch fills one server and one appearance, and the rest are still only on disk.
    @Test("A capture for one server does not hide another server's stored theme")
    func storingOneServerStillLoadsTheOthers() throws {
        try withThemeEnvironment { provider, serverId in
            let otherServerId = "other-server"
            try FrontendThemeVariable.replaceAll(
                [variable(
                    serverId: otherServerId,
                    appearance: .light,
                    name: "--primary-color",
                    color: "rgb(9, 9, 9)"
                )],
                serverId: otherServerId,
                appearance: .light
            )

            // The very first thing this provider does is store, before it has ever read the database.
            provider.store(
                [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
                for: serverId,
                appearance: .light
            )

            #expect(provider.variables(for: otherServerId, appearance: .light).count == 1)
            // ...and the freshly stored theme is not clobbered by that load.
            let stored = provider.variables(for: serverId, appearance: .light)
            #expect(stored["--primary-color"]?.colorValue == "rgb(1, 2, 3)")
        }
    }

    @Test("With no servers there is nothing to resolve against")
    func hasNoVariablesWithoutAServer() throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        let database = try DatabaseQueue(path: ":memory:")
        try FrontendThemeVariableTable().createIfNeeded(database: database)
        Current.database = { database }
        Current.servers = FakeServerManager(initial: 0)

        #expect(FrontendThemeProvider().variables(appearance: .light).isEmpty)
    }

    /// A database the theme cannot be written to or read from leaves the screens on their defaults
    /// rather than taking the web view's message handling down with it.
    @Test("A failing database leaves nothing cached")
    func survivesDatabaseFailures() throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        // No theme table, so every read and write against it throws.
        let database = try DatabaseQueue(path: ":memory:")
        Current.database = { database }
        let servers = FakeServerManager(initial: 0)
        let server = servers.addFake()
        Current.servers = servers
        let serverId = server.identifier.rawValue

        let provider = FrontendThemeProvider()
        provider.store(
            [variable(serverId: serverId, appearance: .light, name: "--primary-color", color: "rgb(1, 2, 3)")],
            for: serverId,
            appearance: .light
        )

        #expect(provider.variables(for: serverId, appearance: .light).isEmpty)
        #expect(provider.color(of: "--primary-color", for: serverId) == nil)
    }

    private struct RGBA: Equatable {
        let red, green, blue, alpha: Int
    }

    private func components(_ color: Color, style: UIUserInterfaceStyle) -> RGBA {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(
            red: Int((red * 255).rounded()),
            green: Int((green * 255).rounded()),
            blue: Int((blue * 255).rounded()),
            alpha: Int((alpha * 255).rounded())
        )
    }

    private func variable(
        serverId: String,
        appearance: FrontendThemeAppearance,
        name: String,
        value: String? = nil,
        color: String?
    ) -> FrontendThemeVariable {
        FrontendThemeVariable(
            serverId: serverId,
            appearance: appearance,
            name: name,
            value: value ?? color ?? "",
            colorValue: color,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func withThemeEnvironment(
        perform work: (FrontendThemeProvider, String) throws -> Void
    ) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let previousLastActive = Current.settingsStore.lastActiveServerIdentifier
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.settingsStore.lastActiveServerIdentifier = previousLastActive
        }

        let database = try DatabaseQueue(path: ":memory:")
        try FrontendThemeVariableTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager(initial: 0)
        let server = servers.addFake()
        Current.servers = servers

        try work(FrontendThemeProvider(), server.identifier.rawValue)
    }
}
