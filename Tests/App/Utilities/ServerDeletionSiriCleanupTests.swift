@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
@Suite(.serialized)
struct ServerDeletionSiriCleanupTests {
    @Test func deletingAServerDropsItsSiriExposureRows() async throws {
        let previous = Current.servers
        defer { Current.servers = previous }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        server.update { $0.connection.set(address: nil, for: .external) }
        Current.servers = manager
        let serverId = server.identifier.rawValue
        try await SiriTestSeeding.clear(serverIds: [serverId])
        SiriServerExposure.setExposed(false, serverId: serverId)
        SiriEntityExposure.setExposed(false, serverId: serverId, entityId: "todo.a", domain: Domain.todo.rawValue)

        await server.deleteFromApp()

        #expect(manager.all.isEmpty)
        #expect(SiriServerExposure.isExposed(serverId: serverId))
        #expect(SiriEntityExposure.isExposed(serverId: serverId, entityId: "todo.a"))
    }
}
