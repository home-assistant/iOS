import Foundation
import HAKit
@testable import Shared
import XCTest

final class EntityComponentIconsServiceTests: XCTestCase {
    private var server: Server!
    private var connection: CannedResponseHAConnection!

    override func setUp() {
        super.setUp()
        server = Server.fake(identifier: .init(rawValue: "entity-component-icons-\(UUID().uuidString)")) { info in
            info.version = .frontendGetIconsEntityComponent
        }
        connection = CannedResponseHAConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
    }

    override func tearDown() {
        Current.resetAPICache(for: [server.identifier])
        super.tearDown()
    }

    func testOlderServersAreNotAsked() async {
        server.update { $0.version = Version(major: 2024, minor: 1, patch: 0) }
        let service = EntityComponentIconsService()

        let map = await service.fetch(for: server)

        XCTAssertNil(map)
        XCTAssertTrue(connection.sentCommands.isEmpty)
    }

    func testServerWithoutReachableURLHasNoMap() async {
        let unreachable = Server.fake { info in
            info.version = .frontendGetIconsEntityComponent
            info.connection.set(address: nil, for: .external)
        }
        let service = EntityComponentIconsService()

        let map = await service.fetch(for: unreachable)

        XCTAssertNil(map)
        XCTAssertNil(service.iconsMap(for: unreachable.identifier.rawValue))
    }

    func testFetchedMapIsCachedPerServer() async {
        connection.responses = [
            "frontend/get_icons": .dictionary([
                "resources": [
                    "light": [
                        "_": ["default": "mdi:lightbulb", "state": ["off": "mdi:lightbulb-off"]],
                    ],
                    "sensor": [
                        "battery": ["default": "mdi:battery", "range": ["10": "mdi:battery-10"]],
                    ],
                ],
            ]),
        ]
        let service = EntityComponentIconsService()

        let map = await service.fetch(for: server)

        XCTAssertEqual(map?["light"]?["_"]?.defaultIcon, "mdi:lightbulb")
        XCTAssertEqual(map?["light"]?["_"]?.state, ["off": "mdi:lightbulb-off"])
        XCTAssertEqual(map?["sensor"]?["battery"]?.range, ["10": "mdi:battery-10"])
        XCTAssertEqual(service.iconsMap(for: server.identifier.rawValue), map)
        XCTAssertNil(service.iconsMap(for: "another-server"))
        XCTAssertEqual(connection.sentCommands, ["frontend/get_icons"])
    }

    func testFailedFetchKeepsThePreviousMap() async {
        connection.responses = [
            "frontend/get_icons": .dictionary([
                "resources": ["switch": ["_": ["default": "mdi:toggle-switch"]]],
            ]),
        ]
        let service = EntityComponentIconsService()
        await service.fetch(for: server)

        connection.responses = [:]
        let failed = await service.fetch(for: server)

        XCTAssertEqual(failed, [:])
        XCTAssertEqual(
            service.iconsMap(for: server.identifier.rawValue)?["switch"]?["_"]?.defaultIcon,
            "mdi:toggle-switch"
        )
    }
}
