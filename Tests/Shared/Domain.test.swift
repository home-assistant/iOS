@testable import Shared
import Testing

struct DomainTests {
    @Test func allDomainRawValues() {
        let expected: [Domain: String] = [
            .automation: "automation",
            .button: "button",
            .climate: "climate",
            .cover: "cover",
            .fan: "fan",
            .inputBoolean: "input_boolean",
            .inputButton: "input_button",
            .light: "light",
            .lock: "lock",
            .scene: "scene",
            .script: "script",
            .switch: "switch",
            .sensor: "sensor",
            .binarySensor: "binary_sensor",
            .zone: "zone",
            .person: "person",
            .camera: "camera",
            .todo: "todo",
            .airQuality: "air_quality",
            .alarmControlPanel: "alarm_control_panel",
            .alert: "alert",
            .assistSatellite: "assist_satellite",
            .calendar: "calendar",
            .conversation: "conversation",
            .date: "date",
            .dateTime: "datetime",
            .deviceTracker: "device_tracker",
            .event: "event",
            .geoLocation: "geo_location",
            .group: "group",
            .humidifier: "humidifier",
            .image: "image",
            .inputDatetime: "input_datetime",
            .inputNumber: "input_number",
            .inputSelect: "input_select",
            .inputText: "input_text",
            .lawnMower: "lawn_mower",
            .mediaPlayer: "media_player",
            .notify: "notify",
            .number: "number",
            .remote: "remote",
            .schedule: "schedule",
            .select: "select",
            .siren: "siren",
            .stt: "stt",
            .sun: "sun",
            .text: "text",
            .time: "time",
            .tts: "tts",
            .update: "update",
            .vacuum: "vacuum",
            .valve: "valve",
            .wakeWord: "wake_word",
            .waterHeater: "water_heater",
            .weather: "weather",
            .counter: "counter",
            .timer: "timer",
        ]

        #expect(
            expected.count == Domain.allCases.count,
            "Domain cases changed; update this test (\(expected.count) mapped vs \(Domain.allCases.count) total)"
        )

        for domain in Domain.allCases {
            let rawValue = expected[domain]
            #expect(rawValue != nil, "Missing expected raw value for Domain case \(domain)")
            #expect(domain.rawValue == rawValue, "Domain.\(domain) raw value should be \(rawValue ?? "nil")")
            if let rawValue {
                #expect(
                    Domain(rawValue: rawValue) == domain,
                    "Domain(rawValue: \"\(rawValue)\") should initialize to .\(domain)"
                )
            }
        }
    }

    @Test func allDomainStateRawValues() {
        let expected: [Domain.State: String] = [
            .locked: "locked",
            .unlocked: "unlocked",
            .jammed: "jammed",
            .locking: "locking",
            .unlocking: "unlocking",
            .on: "on",
            .off: "off",
            .opening: "opening",
            .closing: "closing",
            .closed: "closed",
            .open: "open",
            .unknown: "unknown",
            .unavailable: "unavailable",
        ]

        for (state, rawValue) in expected {
            #expect(state.rawValue == rawValue, "Domain.State.\(state) raw value should be \(rawValue)")
            #expect(
                Domain.State(rawValue: rawValue) == state,
                "Domain.State(rawValue: \"\(rawValue)\") should initialize to .\(state)"
            )
        }
    }
}

struct DeviceClassTests {
    @Test func allDeviceClassRawValues() {
        let expected: [DeviceClass: String] = [
            .battery: "battery",
            .cold: "cold",
            .connectivity: "connectivity",
            .door: "door",
            .garage: "garage",
            .garageDoor: "garage_door",
            .gas: "gas",
            .heat: "heat",
            .humidity: "humidity",
            .illuminance: "illuminance",
            .light: "light",
            .lock: "lock",
            .moisture: "moisture",
            .motion: "motion",
            .moving: "moving",
            .occupancy: "occupancy",
            .opening: "opening",
            .plug: "plug",
            .power: "power",
            .presence: "presence",
            .pressure: "pressure",
            .problem: "problem",
            .safety: "safety",
            .smoke: "smoke",
            .sound: "sound",
            .temperature: "temperature",
            .timestamp: "timestamp",
            .vibration: "vibration",
            .window: "window",
            .gate: "gate",
            .damper: "damper",
            .shutter: "shutter",
            .curtain: "curtain",
            .blind: "blind",
            .shade: "shade",
            .restart: "restart",
            .update: "update",
            .outlet: "outlet",
            .switch: "switch",
            .batteryCharging: "battery_charging",
            .carbonMonoxide: "carbon_monoxide",
            .running: "running",
            .tamper: "tamper",
            .awning: "awning",
            .water: "water",
            .doorbell: "doorbell",
            .button: "button",
            .tv: "tv",
            .speaker: "speaker",
            .receiver: "receiver",
            .projector: "projector",
            .humidifier: "humidifier",
            .dehumidifier: "dehumidifier",
            .identify: "identify",
            .firmware: "firmware",
            .date: "date",
            .enum: "enum",
            .uptime: "uptime",
            .absoluteHumidity: "absolute_humidity",
            .apparentPower: "apparent_power",
            .aqi: "aqi",
            .area: "area",
            .atmosphericPressure: "atmospheric_pressure",
            .bloodGlucoseConcentration: "blood_glucose_concentration",
            .carbonDioxide: "carbon_dioxide",
            .conductivity: "conductivity",
            .current: "current",
            .dataRate: "data_rate",
            .dataSize: "data_size",
            .distance: "distance",
            .duration: "duration",
            .energy: "energy",
            .energyDistance: "energy_distance",
            .energyStorage: "energy_storage",
            .frequency: "frequency",
            .irradiance: "irradiance",
            .monetary: "monetary",
            .nitrogenDioxide: "nitrogen_dioxide",
            .nitrogenMonoxide: "nitrogen_monoxide",
            .nitrousOxide: "nitrous_oxide",
            .ozone: "ozone",
            .ph: "ph",
            .pm1: "pm1",
            .pm10: "pm10",
            .pm25: "pm25",
            .pm4: "pm4",
            .powerFactor: "power_factor",
            .precipitation: "precipitation",
            .precipitationIntensity: "precipitation_intensity",
            .reactiveEnergy: "reactive_energy",
            .reactivePower: "reactive_power",
            .signalStrength: "signal_strength",
            .soundPressure: "sound_pressure",
            .speed: "speed",
            .sulphurDioxide: "sulphur_dioxide",
            .temperatureDelta: "temperature_delta",
            .volatileOrganicCompounds: "volatile_organic_compounds",
            .volatileOrganicCompoundsParts: "volatile_organic_compounds_parts",
            .voltage: "voltage",
            .volume: "volume",
            .volumeStorage: "volume_storage",
            .volumeFlowRate: "volume_flow_rate",
            .weight: "weight",
            .windDirection: "wind_direction",
            .windSpeed: "wind_speed",
            .unknown: "unknown",
        ]

        #expect(
            expected.count == DeviceClass.allCases.count,
            "DeviceClass cases changed; update this test (\(expected.count) vs \(DeviceClass.allCases.count))"
        )

        for deviceClass in DeviceClass.allCases {
            let rawValue = expected[deviceClass]
            #expect(rawValue != nil, "Missing expected raw value for DeviceClass case \(deviceClass)")
            #expect(
                deviceClass.rawValue == rawValue,
                "DeviceClass.\(deviceClass) raw value should be \(rawValue ?? "nil")"
            )
            if let rawValue {
                #expect(
                    DeviceClass(rawValue: rawValue) == deviceClass,
                    "DeviceClass(rawValue: \"\(rawValue)\") should initialize to .\(deviceClass)"
                )
            }
        }
    }
}

struct DomainMappingTests {
    @Test func everyDomainMapsToAnExplicitIcon() {
        for domain in Domain.allCases {
            #expect(domain.icon() != .bookmarkIcon, "Domain.\(domain) should map to an explicit icon")
        }
    }

    @Test func everyDomainHasANonEmptyName() {
        for domain in Domain.allCases {
            #expect(!domain.name.isEmpty, "Domain.\(domain).name should not be empty")
            #expect(!domain.localizedDescription.isEmpty, "Domain.\(domain).localizedDescription should not be empty")
        }
    }

    @Test func mainActionMatchesExpectedGrouping() {
        let toggle: Set<Domain> = [.cover, .fan, .inputBoolean, .light, .switch, .humidifier, .valve]
        let press: Set<Domain> = [.button, .inputButton]
        let turnOn: Set<Domain> = [.scene, .script]
        let trigger: Set<Domain> = [.automation]

        for domain in Domain.allCases {
            let expected: Service?
            if toggle.contains(domain) {
                expected = .toggle
            } else if press.contains(domain) {
                expected = .press
            } else if turnOn.contains(domain) {
                expected = .turnOn
            } else if trigger.contains(domain) {
                expected = .trigger
            } else {
                expected = nil
            }
            #expect(domain.mainAction == expected, "mainAction mismatch for Domain.\(domain)")
        }
    }
}

struct MagicItemWidgetInteractionTests {
    private func interactionKind(forEntityId id: String) -> String {
        let item = MagicItem(id: id, serverId: "server-1", type: .entity)
        guard case let .appIntent(intent) = item.widgetInteractionType else {
            return "widgetURL"
        }
        switch intent {
        case .toggle: return "toggle"
        case .press: return "press"
        case .activate: return "activate"
        case .script: return "script"
        case .refresh: return "refresh"
        }
    }

    @Test func widgetInteractionRoutesByMainAction() {
        #expect(interactionKind(forEntityId: "light.kitchen") == "toggle")
        #expect(interactionKind(forEntityId: "switch.porch") == "toggle")
        #expect(interactionKind(forEntityId: "button.doorbell") == "press")
        #expect(interactionKind(forEntityId: "scene.movie") == "activate")
        #expect(interactionKind(forEntityId: "script.open_gate") == "activate")
        #expect(interactionKind(forEntityId: "automation.wakeup") == "toggle")
        let readOnly = interactionKind(forEntityId: "sensor.temperature")
        #expect(readOnly == "widgetURL" || readOnly == "refresh")
    }
}
