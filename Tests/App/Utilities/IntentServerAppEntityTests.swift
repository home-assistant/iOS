@testable import HomeAssistant
@testable import Shared
import Testing

/// Server identifiers are generated per installation, so a shortcut synced between devices through
/// iCloud carries an identifier the second device never issued. These cover how far that identifier
/// is trusted: a single server is unambiguous, several servers are not, and widgets don't guess at
/// all.
@Suite(.serialized)
struct IntentServerAppEntityTests {
    private static let foreignIdentifier = "identifier-from-another-device"

    private func withServers(count: Int, _ body: ([Server]) async throws -> Void) async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }

        let manager = FakeServerManager(initial: count)
        Current.servers = manager
        try await body(manager.all)
    }

    @Test func resolvesAnUnknownIdentifierToTheOnlyServer() async throws {
        try await withServers(count: 1) { servers in
            let entity = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            #expect(entity.shortcutServer()?.identifier == servers[0].identifier)
        }
    }

    @Test func doesNotGuessBetweenSeveralServers() async throws {
        try await withServers(count: 2) { _ in
            let entity = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            #expect(entity.shortcutServer() == nil)
        }
    }

    @Test func resolvesAKnownIdentifierWhenSeveralServersExist() async throws {
        try await withServers(count: 2) { servers in
            let entity = IntentServerAppEntity(from: servers[1])
            #expect(entity.shortcutServer()?.identifier == servers[1].identifier)
            #expect(entity.getServer()?.identifier == servers[1].identifier)
        }
    }

    /// The Shortcuts editor reads its label from the resolved server, so a synced shortcut names the
    /// server it will actually run against instead of showing "Unknown".
    @Test func describesTheResolvedServer() async throws {
        try await withServers(count: 1) { servers in
            let entity = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            #expect(entity.getInfo()?.name == servers[0].info.name)
        }
    }

    /// Widgets resolve strictly: one configured for a server that is gone shows nothing, rather
    /// than quietly switching to whichever server is left.
    @Test func strictResolutionNeverFallsBack() async throws {
        try await withServers(count: 1) { _ in
            let entity = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            #expect(entity.getServer() == nil)
        }
    }

    /// The query hands back the identifier it was given rather than the local server's one, so
    /// correcting the shortcut on one device doesn't rewrite it into something the other can no
    /// longer resolve.
    @Test func queryKeepsTheRequestedIdentifier() async throws {
        try await withServers(count: 1) { servers in
            let entities = try await IntentServerAppEntity.defaultQuery.entities(for: [Self.foreignIdentifier])
            #expect(entities.map(\.id) == [Self.foreignIdentifier])
            #expect(entities.first?.shortcutServer()?.identifier == servers[0].identifier)
        }
    }

    @Test func queryDropsAnIdentifierItCannotResolve() async throws {
        try await withServers(count: 2) { _ in
            let entities = try await IntentServerAppEntity.defaultQuery.entities(for: [Self.foreignIdentifier])
            #expect(entities.isEmpty)
        }
    }
}
