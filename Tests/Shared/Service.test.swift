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
        #expect(Service.openValve.rawValue == "open_valve", "Service.openValve raw value should be 'open_valve'")
        #expect(Service.closeValve.rawValue == "close_valve", "Service.closeValve raw value should be 'close_valve'")
        #expect(Service.trigger.rawValue == "trigger", "Service.trigger raw value should be 'trigger'")
        #expect(
            Service.setTemperature.rawValue == "set_temperature",
            "Service.setTemperature raw value should be 'set_temperature'"
        )
        #expect(
            Service.setHvacMode.rawValue == "set_hvac_mode",
            "Service.setHvacMode raw value should be 'set_hvac_mode'"
        )
        #expect(
            Service.setFanMode.rawValue == "set_fan_mode",
            "Service.setFanMode raw value should be 'set_fan_mode'"
        )
        #expect(
            Service.setSwingMode.rawValue == "set_swing_mode",
            "Service.setSwingMode raw value should be 'set_swing_mode'"
        )
        #expect(
            Service.setSwingHorizontalMode.rawValue == "set_swing_horizontal_mode",
            "Service.setSwingHorizontalMode raw value should be 'set_swing_horizontal_mode'"
        )
        #expect(
            Service.setPresetMode.rawValue == "set_preset_mode",
            "Service.setPresetMode raw value should be 'set_preset_mode'"
        )
        #expect(
            Service.setHumidity.rawValue == "set_humidity",
            "Service.setHumidity raw value should be 'set_humidity'"
        )
        #expect(Service.start.rawValue == "start", "Service.start raw value should be 'start'")
        #expect(Service.pause.rawValue == "pause", "Service.pause raw value should be 'pause'")
        #expect(Service.stop.rawValue == "stop", "Service.stop raw value should be 'stop'")
        #expect(
            Service.returnToBase.rawValue == "return_to_base",
            "Service.returnToBase raw value should be 'return_to_base'"
        )
        #expect(
            Service.setFanSpeed.rawValue == "set_fan_speed",
            "Service.setFanSpeed raw value should be 'set_fan_speed'"
        )
        #expect(Service.locate.rawValue == "locate", "Service.locate raw value should be 'locate'")
        #expect(
            Service.cleanArea.rawValue == "clean_area",
            "Service.cleanArea raw value should be 'clean_area'"
        )

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
        #expect(
            Service(rawValue: "stop_cover") == .stopCover,
            "Service(rawValue: 'stop_cover') should initialize to .stopCover"
        )
        #expect(
            Service(rawValue: "set_cover_position") == .setCoverPosition,
            "Service(rawValue: 'set_cover_position') should initialize to .setCoverPosition"
        )
        #expect(
            Service(rawValue: "set_percentage") == .setPercentage,
            "Service(rawValue: 'set_percentage') should initialize to .setPercentage"
        )
        #expect(Service(rawValue: "trigger") == .trigger, "Service(rawValue: 'trigger') should initialize to .trigger")

        // Test invalid raw value
        #expect(Service(rawValue: "invalid") == nil, "Service(rawValue: 'invalid') should return nil")

        // Test case count
        #expect(
            Service.allCases.count == 29,
            "Service enum should have 29 cases, but has \(Service.allCases.count). Cases: \(Service.allCases.map(\.rawValue).joined(separator: ", "))"
        )
    }
}
