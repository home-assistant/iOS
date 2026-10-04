import Foundation
import HAKit
@testable import Shared
import Testing

/// `EntityToggler` against a scripted connection: what it reads, and which service it calls.
struct EntityTogglerTests {
    private func makeConnection(state: String?, entityId: String) -> MagicItemTestConnection {
        let connection = MagicItemTestConnection()
        if let state {
            connection.responses["states/\(entityId)"] = .success(.dictionary(["state": state]))
        }
        connection.responses["call_service"] = .success(.empty)
        return connection
    }

    private func serviceCall(in connection: MagicItemTestConnection) throws -> (domain: String?, service: String?, entityId: String?) {
        let request = try #require(connection.sentRequests.last)
        #expect(request.type.command == "call_service")
        let serviceData = request.data["service_data"] as? [String: Any]
        return (
            request.data["domain"] as? String,
            request.data["service"] as? String,
            serviceData?["entity_id"] as? String
        )
    }

    @Test func offLightIsTurnedOn() async throws {
        let connection = makeConnection(state: "off", entityId: "light.kitchen")
        try await EntityToggler.toggle(domain: .light, entityId: "light.kitchen", connection: connection)

        #expect(connection.sentRequests.first?.type == .rest(.get, "states/light.kitchen"))
        let call = try serviceCall(in: connection)
        #expect(call.domain == "light")
        #expect(call.service == Service.turnOn.rawValue)
        #expect(call.entityId == "light.kitchen")
    }

    @Test func lockedLockIsUnlocked() async throws {
        let connection = makeConnection(state: "locked", entityId: "lock.front")
        try await EntityToggler.toggle(domain: .lock, entityId: "lock.front", connection: connection)

        let call = try serviceCall(in: connection)
        #expect(call.domain == "lock")
        #expect(call.service == Service.unlock.rawValue)
    }

    @Test func groupIsToggledThroughHomeAssistant() async throws {
        let connection = makeConnection(state: "on", entityId: "group.downstairs")
        try await EntityToggler.toggle(domain: .group, entityId: "group.downstairs", connection: connection)

        let call = try serviceCall(in: connection)
        #expect(call.domain == "homeassistant")
        #expect(call.service == Service.turnOff.rawValue)
        #expect(call.entityId == "group.downstairs")
    }

    @Test func singleServiceDomainsSkipTheStateLookup() async throws {
        let connection = makeConnection(state: nil, entityId: "button.doorbell")
        try await EntityToggler.toggle(domain: .button, entityId: "button.doorbell", connection: connection)

        #expect(connection.sentRequests.count == 1)
        let call = try serviceCall(in: connection)
        #expect(call.domain == "button")
        #expect(call.service == Service.press.rawValue)
    }

    @Test func domainsWithoutAnOnOffPairCannotBeToggled() async {
        let connection = MagicItemTestConnection()
        await #expect(throws: EntityToggler.ToggleError.self) {
            try await EntityToggler.toggle(domain: .sensor, entityId: "sensor.power", connection: connection)
        }
        #expect(connection.sentRequests.isEmpty)
    }

    @Test func aStateWithoutAValueStopsTheToggle() async {
        let connection = MagicItemTestConnection()
        connection.responses["states/light.kitchen"] = .success(.dictionary(["attributes": [String: Any]()]))
        await #expect(throws: EntityToggler.ToggleError.self) {
            try await EntityToggler.toggle(domain: .light, entityId: "light.kitchen", connection: connection)
        }
        #expect(connection.sentRequests.count == 1)
    }

    @Test func aFailedStateLookupStopsTheToggle() async {
        let connection = MagicItemTestConnection()
        await #expect(throws: HAError.self) {
            try await EntityToggler.toggle(domain: .light, entityId: "light.kitchen", connection: connection)
        }
        #expect(connection.sentRequests.count == 1)
    }

    @Test func aRejectedServiceCallIsReported() async {
        let connection = MagicItemTestConnection()
        connection.responses["call_service"] = .failure(.internal(debugDescription: "unit-test"))
        await #expect(throws: HAError.self) {
            try await EntityToggler.toggle(domain: .button, entityId: "button.doorbell", connection: connection)
        }
    }

    @Test func errorsDescribeThemselves() {
        #expect(
            EntityToggler.ToggleError.domainNotToggleable(.sensor).errorDescription == "sensor cannot be toggled"
        )
        #expect(
            EntityToggler.ToggleError.stateUnavailable("light.kitchen").errorDescription
                == "No state available for light.kitchen"
        )
    }
}
