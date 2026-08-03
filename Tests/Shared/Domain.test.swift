import Foundation
import HAKit
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

    @Test func actionabilityFollowsMainActionWithLockException() {
        for domain in Domain.allCases {
            let expected = domain.mainAction != nil || domain == .lock
            #expect(domain.isActionable == expected, "isActionable mismatch for Domain.\(domain)")
        }
    }

    @Test func stateDependentIconMembership() {
        let expected: Set<Domain> = [.cover, .inputBoolean, .light, .lock, .switch]
        for domain in Domain.allCases {
            #expect(
                domain.hasStateDependentIcon == expected.contains(domain),
                "hasStateDependentIcon mismatch for Domain.\(domain)"
            )
        }
    }

    @Test func irrelevantStateMembership() {
        let expected: Set<Domain> = [.script, .scene]
        for domain in Domain.allCases {
            #expect(
                domain.hasIrrelevantState == expected.contains(domain),
                "hasIrrelevantState mismatch for Domain.\(domain)"
            )
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

struct MagicItemWatchDisplayOnlyTests {
    @Test func sensorEntitiesAreDisplayOnly() {
        for entityId in ["sensor.temperature", "binary_sensor.front_door"] {
            let item = MagicItem(id: entityId, serverId: "1", type: .entity)
            #expect(item.isWatchDisplayOnly, "\(entityId) should be display-only on the watch")
        }
    }

    @Test func runnableAndNonEntityItemsAreNotDisplayOnly() {
        let runnable = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        #expect(!runnable.isWatchDisplayOnly)

        // Only entity items can be display-only — the item type decides, not the id's domain.
        let script = MagicItem(id: "sensor.temperature", serverId: "1", type: .script)
        #expect(!script.isWatchDisplayOnly)

        let folder = MagicItem(id: "folder", serverId: "", type: .folder)
        #expect(!folder.isWatchDisplayOnly)
    }
}

struct DomainFeatureSupportTests {
    @Test func carPlaySupportedMembership() {
        let expected: Set<Domain> = [
            .automation, .button, .climate, .cover, .fan, .humidifier, .inputBoolean, .inputButton,
            .light, .lock, .scene, .script, .switch, .vacuum, .valve,
        ]
        #expect(Set(Domain.carPlaySupported) == expected, "Domain.carPlaySupported membership changed")
    }

    @Test func controlScreenMembership() {
        let expected: Set<Domain> = [.climate, .vacuum]
        #expect(Set(Domain.controlScreenDomains) == expected, "Domain.controlScreenDomains membership changed")
        for domain in Domain.allCases {
            #expect(
                domain.hasControlScreen == expected.contains(domain),
                "hasControlScreen mismatch for Domain.\(domain)"
            )
        }
    }

    @Test func builtInConfirmationMembership() {
        let expected: Set<Domain> = [.lock]
        #expect(
            Set(Domain.builtInConfirmationDomains) == expected,
            "Domain.builtInConfirmationDomains membership changed"
        )
        for domain in Domain.allCases {
            #expect(
                domain.hasBuiltInConfirmation == expected.contains(domain),
                "hasBuiltInConfirmation mismatch for Domain.\(domain)"
            )
        }
    }

    @Test func controlScreenDomainsAreNeitherRunnableNorDisplayOnly() {
        // A control-screen domain's tap opens its own screen; an action or the sensor details
        // screen competing for the same tap would be ambiguous.
        for domain in Domain.controlScreenDomains {
            #expect(!domain.isActionable, "Domain.\(domain) has a control screen but also an action")
            #expect(!domain.isWatchDisplayOnly, "Domain.\(domain) has a control screen but is display-only")
        }
    }

    @Test func watchSupportedMembership() {
        let expected: Set<Domain> = [
            .automation, .button, .cover, .fan, .humidifier, .inputBoolean, .inputButton,
            .light, .lock, .scene, .script, .switch, .valve,
        ]
        #expect(Set(Domain.watchSupported) == expected, "Domain.watchSupported membership changed")
    }

    @Test func watchSupportedDomainsAreActionable() {
        // `watchSupported` is the list the watch can actually run; a non-actionable domain in it
        // would tap into the "unsupported" alert. Display-only domains live in their own list.
        for domain in Domain.watchSupported {
            #expect(domain.isActionable, "Domain.\(domain) is watch-supported but has no action")
        }
    }

    @Test func watchDisplayOnlyMembership() {
        let expected: Set<Domain> = [.sensor, .binarySensor]
        #expect(Set(Domain.watchDisplayOnly) == expected, "Domain.watchDisplayOnly membership changed")
        for domain in Domain.allCases {
            #expect(
                domain.isWatchDisplayOnly == expected.contains(domain),
                "isWatchDisplayOnly mismatch for Domain.\(domain)"
            )
        }
    }

    @Test func watchDisplayOnlyDomainsHaveNoAction() {
        // These are on the watch to be read: the row opens the details screen instead of running
        // anything, so an actionable domain here would silently lose its action.
        for domain in Domain.watchDisplayOnly {
            #expect(!domain.isActionable, "Domain.\(domain) is display-only but has an action")
        }
    }

    @Test func watchAddableIsRunnablePlusDisplayOnlyPlusControlScreen() {
        #expect(Domain.watchAddable == Domain.watchSupported + Domain.watchDisplayOnly + Domain.controlScreenDomains)
        #expect(Set(Domain.watchSupported).isDisjoint(with: Set(Domain.watchDisplayOnly)))
        #expect(Set(Domain.watchSupported).isDisjoint(with: Set(Domain.controlScreenDomains)))
        #expect(Set(Domain.watchDisplayOnly).isDisjoint(with: Set(Domain.controlScreenDomains)))
        for domain in Domain.watchAddable {
            #expect(
                domain.isActionable || domain.isWatchDisplayOnly || domain.hasControlScreen,
                "Domain.\(domain) is addable to the watch but neither runnable, display-only, nor control-screen"
            )
        }
    }

    @Test func commonlyUsedWidgetSupportedMembership() {
        let expected: Set<Domain> = [.light, .switch, .cover, .fan, .inputBoolean, .humidifier, .valve]
        #expect(Set(Domain.commonlyUsedWidgetSupported) == expected, "Domain.commonlyUsedWidgetSupported changed")
    }

    @Test func sensorWidgetSupportedMembership() {
        let expected: Set<Domain> = [
            .sensor, .binarySensor, .inputBoolean, .person, .lock, .number, .inputNumber,
            .inputText, .inputSelect, .select, .climate, .weather, .sun, .deviceTracker, .update,
        ]
        #expect(Set(Domain.sensorWidgetSupported) == expected, "Domain.sensorWidgetSupported membership changed")
    }

    @Test func appDatabaseExcludedMembership() {
        let expected: Set<Domain> = [
            .geoLocation, .conversation, .stt, .tts, .wakeWord, .assistSatellite, .notify, .image,
        ]
        #expect(Set(Domain.appDatabaseExcluded) == expected, "Domain.appDatabaseExcluded membership changed")
    }

    @Test func groupsHaveNoDuplicates() {
        let groups: [(String, [Domain])] = [
            ("carPlaySupported", Domain.carPlaySupported),
            ("watchSupported", Domain.watchSupported),
            ("watchDisplayOnly", Domain.watchDisplayOnly),
            ("watchAddable", Domain.watchAddable),
            ("controlScreenDomains", Domain.controlScreenDomains),
            ("commonlyUsedWidgetSupported", Domain.commonlyUsedWidgetSupported),
            ("sensorWidgetSupported", Domain.sensorWidgetSupported),
            ("appDatabaseExcluded", Domain.appDatabaseExcluded),
        ]
        for (name, group) in groups {
            #expect(group.count == Set(group).count, "\(name) contains duplicate domains")
        }
    }

    @Test func supportedDomainsAreNotExcludedFromPersistence() {
        let excluded = Set(Domain.appDatabaseExcluded)
        let featureLists: [(String, [Domain])] = [
            ("carPlaySupported", Domain.carPlaySupported),
            ("watchSupported", Domain.watchSupported),
            ("watchAddable", Domain.watchAddable),
            ("controlScreenDomains", Domain.controlScreenDomains),
            ("commonlyUsedWidgetSupported", Domain.commonlyUsedWidgetSupported),
            ("sensorWidgetSupported", Domain.sensorWidgetSupported),
        ]
        for (name, list) in featureLists {
            for domain in list {
                #expect(!excluded.contains(domain), "\(name) domain \(domain) must not be in appDatabaseExcluded")
            }
        }
    }
}

struct DomainTimestampStateTests {
    /// 2026-08-03 18:15:00 UTC — the dishwasher finish time from the report, and the instant every
    /// test below measures against so the relative wording is deterministic.
    private static let referenceDate = Date(timeIntervalSince1970: 1_785_780_900)

    private func makeEntity(
        entityId: String,
        state: String,
        attributes: [String: Any] = [:]
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Self.referenceDate,
            lastUpdated: Self.referenceDate,
            attributes: attributes,
            context: .init(id: "context", userId: nil, parentId: nil)
        )
    }

    /// Runs `body` with "now" frozen an hour before the reference timestamp, so a sensor reporting
    /// that timestamp is always exactly one hour in the future.
    private func withFrozenClock<T>(_ body: () throws -> T) rethrows -> T {
        let previousDate = Current.date
        Current.date = { Self.referenceDate.addingTimeInterval(-3600) }
        defer { Current.date = previousDate }
        return try body()
    }

    @Test func timestampSensorRendersRelativeTimeInsteadOfRawISOString() throws {
        let entity = try makeEntity(
            entityId: "sensor.dishwasher_programme_finish_time",
            state: "2026-08-03T18:15:00+00:00",
            attributes: ["device_class": "timestamp"]
        )

        let formatter = RelativeDateTimeFormatter()
        let now = Self.referenceDate.addingTimeInterval(-3600)
        let expected = formatter.localizedString(for: Self.referenceDate, relativeTo: now).leadingCapitalized

        let description = withFrozenClock {
            Domain.sensor.contextualStateDescription(for: entity)
        }

        // The raw UTC string is what the watch used to show; anything relative is an improvement,
        // but pin the wording so a formatter regression is caught.
        #expect(description != "2026-08-03T18:15:00+00:00")
        #expect(description == expected)
    }

    /// The old parser required fractional seconds, so every sensor reporting plain seconds fell
    /// through to the raw string. Both spellings must resolve to the same instant.
    @Test func timestampParsingAcceptsBothISOSpellings() {
        #expect(EntityTimestampFormatter.date(from: "2026-08-03T18:15:00+00:00") == Self.referenceDate)
        #expect(EntityTimestampFormatter.date(from: "2026-08-03T18:15:00.000000+00:00") == Self.referenceDate)
        #expect(EntityTimestampFormatter.date(from: "2026-08-03T20:15:00+02:00") == Self.referenceDate)
    }

    @Test func unavailableTimestampSensorKeepsItsLocalizedWording() throws {
        let entity = try makeEntity(
            entityId: "sensor.dishwasher_programme_finish_time",
            state: Domain.State.unavailable.rawValue,
            attributes: ["device_class": "timestamp"]
        )

        let description = Domain.sensor.contextualStateDescription(for: entity)
        #expect(description == entity.localizedState.leadingCapitalized)
        #expect(description != Domain.State.unavailable.rawValue)
    }

    @Test func dateSensorRendersLocalizedDateWithoutShiftingTheDay() throws {
        let entity = try makeEntity(
            entityId: "sensor.next_bin_collection",
            state: "2026-08-03",
            attributes: ["device_class": "date"]
        )

        let formatter = with(DateFormatter()) {
            $0.dateStyle = .medium
            $0.timeStyle = .none
            $0.timeZone = TimeZone(secondsFromGMT: 0)
        }

        let description = Domain.sensor.contextualStateDescription(for: entity)
        #expect(description != "2026-08-03")
        #expect(description == formatter.string(from: Self.referenceDate))
    }

    @Test func nonTimestampSensorsAreUnaffected() throws {
        let entity = try makeEntity(
            entityId: "sensor.power_consumed",
            state: "0.203",
            attributes: ["device_class": "power", "unit_of_measurement": "kW"]
        )

        #expect(Domain.sensor.contextualStateDescription(for: entity) == "0.203 kW")
    }

    @Test func timestampFormatterRejectsNonTimestampStates() {
        #expect(EntityTimestampFormatter.date(from: "unavailable") == nil)
        #expect(EntityTimestampFormatter.relativeDescription(for: "on") == nil)
        #expect(EntityTimestampFormatter.dateDescription(for: "not a date") == nil)
    }
}
