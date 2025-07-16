@testable import Shared
import Testing

struct ServiceTests {
    @Test func testEnumCases() async throws {
        // Test raw values
        assert(Service.turnOn.rawValue == "turn_on")
        assert(Service.turnOff.rawValue == "turn_off")
        assert(Service.toggle.rawValue == "toggle")
        assert(Service.press.rawValue == "press")
        assert(Service.lock.rawValue == "lock")
        assert(Service.unlock.rawValue == "unlock")
        assert(Service.open.rawValue == "open")
        assert(Service.openCover.rawValue == "open_cover")
        assert(Service.closeCover.rawValue == "close_cover")

        // Test initialization from raw value
        assert(Service(rawValue: "turn_on") == .turnOn)
        assert(Service(rawValue: "turn_off") == .turnOff)
        assert(Service(rawValue: "toggle") == .toggle)
        assert(Service(rawValue: "press") == .press)
        assert(Service(rawValue: "lock") == .lock)
        assert(Service(rawValue: "unlock") == .unlock)
        assert(Service(rawValue: "open") == .open)
        assert(Service(rawValue: "open_cover") == .openCover)
        assert(Service(rawValue: "close_cover") == .closeCover)

        // Test invalid raw value
        assert(Service(rawValue: "invalid") == nil)

        assert(
            Service.allCases.count == 9,
            "Wrong Service enum cases count, it currently has \(Service.allCases.count)"
        )
    }
}
