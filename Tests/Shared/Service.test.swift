@testable import Shared
import Testing

struct ServiceTests {
    @Test func testEnumCases() async throws {
        // Test raw values
        #expect(Service.turnOn.rawValue == "turn_on", "Service.turnOn raw value should be 'turn_on'")
        #expect(Service.turnOff.rawValue == "turn_off", "Service.turnOff raw value should be 'turn_off'")
        #expect(Service.toggle.rawValue == "toggle", "Service.toggle raw value should be 'toggle'")
        #expect(Service.press.rawValue == "press", "Service.press raw value should be 'press'")
        #expect(Service.lock.rawValue == "lock", "Service.lock raw value should be 'lock'")
        #expect(Service.unlock.rawValue == "unlock", "Service.unlock raw value should be 'unlock'")
        #expect(Service.open.rawValue == "open", "Service.open raw value should be 'open'")
        #expect(Service.openCover.rawValue == "open_cover", "Service.openCover raw value should be 'open_cover'")
        #expect(Service.closeCover.rawValue == "close_cover", "Service.closeCover raw value should be 'close_cover'")
        #expect(Service.trigger.rawValue == "trigger", "Service.trigger raw value should be 'trigger'")

        // Test initialization from raw value
        #expect(Service(rawValue: "turn_on") == .turnOn, "Service(rawValue: 'turn_on') should initialize to .turnOn")
        #expect(
            Service(rawValue: "turn_off") == .turnOff,
            "Service(rawValue: 'turn_off') should initialize to .turnOff"
        )
        #expect(Service(rawValue: "toggle") == .toggle, "Service(rawValue: 'toggle') should initialize to .toggle")
        #expect(Service(rawValue: "press") == .press, "Service(rawValue: 'press') should initialize to .press")
        #expect(Service(rawValue: "lock") == .lock, "Service(rawValue: 'lock') should initialize to .lock")
        #expect(Service(rawValue: "unlock") == .unlock, "Service(rawValue: 'unlock') should initialize to .unlock")
        #expect(Service(rawValue: "open") == .open, "Service(rawValue: 'open') should initialize to .open")
        #expect(
            Service(rawValue: "open_cover") == .openCover,
            "Service(rawValue: 'open_cover') should initialize to .openCover"
        )
        #expect(
            Service(rawValue: "close_cover") == .closeCover,
            "Service(rawValue: 'close_cover') should initialize to .closeCover"
        )
        #expect(Service(rawValue: "trigger") == .trigger, "Service(rawValue: 'trigger') should initialize to .trigger")

        // Test invalid raw value
        #expect(Service(rawValue: "invalid") == nil, "Service(rawValue: 'invalid') should return nil")

        // Test case count
        #expect(
            Service.allCases.count == 10,
            "Service enum should have 10 cases, but has \(Service.allCases.count). Cases: \(Service.allCases.map(\.rawValue).joined(separator: ", "))"
        )
    }
}
