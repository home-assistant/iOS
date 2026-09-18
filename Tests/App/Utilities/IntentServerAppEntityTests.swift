@testable import HomeAssistant
@testable import Shared
import Testing

/// Server entity lookup for App Intents: an exact local id always wins, and a synced unknown id is
/// accepted only on a single-server device that is not waiting to restore mirrored servers.
///
/// Serialized because every test swaps the process-wide server registry.
@Suite(.serialized)
struct IntentServerAppEntityTests {
    private func withServers(
        _ servers: FakeServerManager,
        _ body: (FakeServerManager) async throws -> Void
    ) async rethrows {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = servers
        try await body(servers)
    }

    @discardableResult
    private func addServer(
        to servers: FakeServerManager,
        id: String,
        name: String
    ) -> Server {
        var info = ServerInfo.fake()
        info.remoteName = name
        return servers.add(identifier: .init(rawValue: id), serverInfo: info)
    }

    @Test func exactIdResolvesWithOneServerAndKeepsItsIdAndName() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "phone"))

            #expect(entity.getServer()?.identifier.rawValue == "phone")
            #expect(entity.getInfo()?.name == "Phone Home")

            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: ["phone"])
            #expect(resolved.map(\.id) == ["phone"])
            #expect(resolved.first?.getInfo()?.name == "Phone Home")
        }
    }

    @Test func exactIdResolvesAmongSeveralServers() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            addServer(to: servers, id: "cabin", name: "Cabin")
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "cabin"))

            #expect(entity.getServer()?.identifier.rawValue == "cabin")
            #expect(entity.getInfo()?.name == "Cabin")
        }
    }

    /// A shortcut copied from another installation keeps that installation's server id. On a
    /// one-server device that id still names the only configured instance, and must not be rewritten.
    @Test func unknownIdResolvesOnASingleServerDeviceWithoutChangingTheEntityId() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "mac"))

            #expect(entity.getServer()?.identifier.rawValue == "phone")
            #expect(entity.id == "mac")
            #expect(entity.getInfo()?.name == "Phone Home")

            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: ["mac"])
            #expect(resolved.map(\.id) == ["mac"])
            #expect(resolved.first?.getInfo()?.name == "Phone Home")
        }
    }

    @Test func emptyIdDoesNotFallBack() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            let entity = IntentServerAppEntity(identifier: .init(rawValue: ""))

            #expect(entity.getServer() == nil)
            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: [""])
            #expect(resolved.isEmpty)
        }
    }

    @Test func unknownIdDoesNotFallBackWithNoServers() async throws {
        try await withServers(FakeServerManager(initial: 0)) { _ in
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "mac"))
            #expect(entity.getServer() == nil)
            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: ["mac"])
            #expect(resolved.isEmpty)
        }
    }

    @Test func unknownIdDoesNotFallBackWithSeveralServers() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            addServer(to: servers, id: "cabin", name: "Cabin")
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "mac"))

            #expect(entity.getServer() == nil)
            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: ["mac"])
            #expect(resolved.isEmpty)
        }
    }

    @Test func unknownIdDoesNotFallBackWhileMirrorRestoreIsPending() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            servers.isMirrorRestorePending = true
            let entity = IntentServerAppEntity(identifier: .init(rawValue: "mac"))

            #expect(entity.getServer() == nil)
            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: ["mac"])
            #expect(resolved.isEmpty)
        }
    }

    /// Known, foreign, repeated, and empty identifiers in one query: order is the request order,
    /// duplicates collapse, and unresolved entries are dropped.
    @Test func aBatchKeepsOrderDeduplicatesAndOmitsUnresolvedEntries() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")

            let resolved = try await IntentServerAppEntity.IntentServerAppEntityQuery().entities(for: [
                "phone",
                "mac",
                "phone",
                "",
            ])

            #expect(resolved.map(\.id) == ["phone", "mac"])
            #expect(resolved.map { $0.getInfo()?.name } == ["Phone Home", "Phone Home"])
        }
    }

    @Test func suggestedEntitiesKeepLocalIds() async throws {
        try await withServers(FakeServerManager(initial: 0)) { servers in
            addServer(to: servers, id: "phone", name: "Phone Home")
            let suggested = try await IntentServerAppEntity.IntentServerAppEntityQuery().suggestedEntities()
            #expect(suggested.map(\.id) == ["phone"])
        }
    }
}
