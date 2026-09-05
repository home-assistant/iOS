@testable import Shared
import Testing

struct ServerPriorityTests {
    private func withServers(_ count: Int, _ body: ([Server]) throws -> Void) rethrows {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: count)
        Current.servers = manager
        try body(manager.all)
    }

    @Test func fallsBackToAStableOrderByName() throws {
        try withServers(3) { servers in
            ServerPriority.cacheClosestServer(nil)
            let ordered = ServerPriority.ordered(servers.shuffled())
            let names = ordered.map(\.info.name)
            #expect(names == names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        }
    }

    @Test func theCachedClosestServerLeads() throws {
        try withServers(3) { servers in
            let last = try #require(servers.last)
            ServerPriority.cacheClosestServer(last.identifier)

            #expect(ServerPriority.cachedClosestServer == last.identifier)
            #expect(ServerPriority.ordered(servers).first?.identifier == last.identifier)
        }
    }

    /// A nil match means "stay put", so it must not erase what the app already worked out.
    @Test func aNilMatchKeepsThePreviousAnswer() throws {
        try withServers(2) { servers in
            let first = try #require(servers.first)
            ServerPriority.cacheClosestServer(first.identifier)
            ServerPriority.cacheClosestServer(nil)

            #expect(ServerPriority.cachedClosestServer == first.identifier)
        }
    }
}
