import Foundation
import HAKit
@testable import Shared
import SharedTesting
import Testing

/// `EntityComponentIconsService` fetching `frontend/get_icons` over a connection that answers each
/// request as it is sent, so a fetch never waits on a request the test has yet to answer. `Current` is
/// read on the test's task only, so each test gets its own environment.
@Suite(.isolatedEnvironment)
struct EntityComponentIconsServiceFetchTests {
    /// The answer the connection gives every request; a test changes it between fetches.
    private final class Answer: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Result<HAData, HAError>

        init(_ value: Result<HAData, HAError>) {
            self.value = value
        }

        var current: Result<HAData, HAError> {
            get { lock.lock(); defer { lock.unlock() }; return value }
            set { lock.lock(); value = newValue; lock.unlock() }
        }
    }

    private func makeServer(version: Version, answer: Answer) -> (Server, RespondingHAConnection) {
        let server = Server.fake { $0.version = version }
        let api = HomeAssistantAPI(server: server)
        let connection = RespondingHAConnection { _ in answer.current }
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        return (server, connection)
    }

    @Test func fetchedMapsAreCachedPerServer() async {
        let answer = Answer(.success(.dictionary([
            "resources": [
                "light": ["_": ["default": "mdi:lightbulb", "state": ["off": "mdi:lightbulb-off"]]],
            ],
        ])))
        let (server, connection) = makeServer(version: Version(major: 2025, minor: 1, patch: 0), answer: answer)
        let service = EntityComponentIconsService()

        let map = await service.fetch(for: server)
        #expect(map?["light"]?["_"]?.defaultIcon == "mdi:lightbulb")
        #expect(service.iconsMap(for: server.identifier.rawValue)?["light"]?["_"]?.state?["off"] == "mdi:lightbulb-off")

        // A failed refresh keeps the last good map.
        answer.current = .failure(.internal(debugDescription: "x"))
        let failed = await service.fetch(for: server)
        #expect(failed?.isEmpty == true)
        #expect(service.iconsMap(for: server.identifier.rawValue)?["light"] != nil)
        #expect(service.iconsMap(for: "other") == nil)
        #expect(connection.sentCommands == ["frontend/get_icons", "frontend/get_icons"])
        #expect(connection.sentData.allSatisfy { $0["category"] as? String == "entity_component" })
    }

    @Test func oldServersAreNeverAsked() async {
        let (server, connection) = makeServer(
            version: Version(major: 2023, minor: 12, patch: 0),
            answer: Answer(.success(.empty))
        )
        let map = await EntityComponentIconsService().fetch(for: server)
        #expect(map == nil)
        #expect(connection.sentCommands.isEmpty)
    }

    @Test func responsesWithoutResourcesDecodeEmpty() throws {
        // swiftformat:disable:next hoistTry
        #expect(try EntityComponentIconsResponse(data: .dictionary([:])).resources.isEmpty)
        // swiftformat:disable:next hoistTry
        #expect(try EntityComponentIconsResponse(data: .dictionary(["resources": ["light": "nope"]])).resources.isEmpty)
    }
}
