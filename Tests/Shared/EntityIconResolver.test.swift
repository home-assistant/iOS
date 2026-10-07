@testable import Shared
import Testing

struct EntityIconResolverTests {
    // MARK: - stateIcon special cases

    @Test func updateStateIcon() {
        #expect(EntityIconResolver.icon(
            domain: "update",
            deviceClass: nil,
            state: "on",
            attributes: [:],
            map: nil
        ) == "mdi:package-up")

        #expect(EntityIconResolver.icon(
            domain: "update",
            deviceClass: nil,
            state: "off",
            attributes: [:],
            map: nil
        ) == "mdi:package")

        #expect(EntityIconResolver.icon(
            domain: "update",
            deviceClass: nil,
            state: "on",
            attributes: ["in_progress": true],
            map: nil
        ) == "mdi:package-down")
    }

    @Test func deviceTrackerStateIcon() {
        #expect(EntityIconResolver.icon(
            domain: "device_tracker",
            deviceClass: nil,
            state: "home",
            attributes: ["source_type": "router"],
            map: nil
        ) == "mdi:lan-connect")

        #expect(EntityIconResolver.icon(
            domain: "device_tracker",
            deviceClass: nil,
            state: "not_home",
            attributes: ["source_type": "bluetooth"],
            map: nil
        ) == "mdi:bluetooth")

        #expect(EntityIconResolver.icon(
            domain: "device_tracker",
            deviceClass: nil,
            state: "not_home",
            attributes: [:],
            map: nil
        ) == "mdi:account-arrow-right")

        #expect(EntityIconResolver.icon(
            domain: "device_tracker",
            deviceClass: nil,
            state: "home",
            attributes: [:],
            map: nil
        ) == "mdi:account")
    }

    @Test func sunStateIcon() {
        #expect(EntityIconResolver.icon(
            domain: "sun",
            deviceClass: nil,
            state: "above_horizon",
            attributes: [:],
            map: nil
        ) == "mdi:white-balance-sunny")

        #expect(EntityIconResolver.icon(
            domain: "sun",
            deviceClass: nil,
            state: "below_horizon",
            attributes: [:],
            map: nil
        ) == "mdi:weather-night")
    }

    @Test func inputDatetimeStateIcon() {
        #expect(EntityIconResolver.icon(
            domain: "input_datetime",
            deviceClass: nil,
            state: nil,
            attributes: ["has_date": false, "has_time": true],
            map: nil
        ) == "mdi:clock")

        #expect(EntityIconResolver.icon(
            domain: "input_datetime",
            deviceClass: nil,
            state: nil,
            attributes: ["has_date": true, "has_time": false],
            map: nil
        ) == "mdi:calendar")

        // With both date and time there is no special-case icon; without a map it falls through to nil.
        #expect(EntityIconResolver.icon(
            domain: "input_datetime",
            deviceClass: nil,
            state: nil,
            attributes: ["has_date": true, "has_time": true],
            map: nil
        ) == nil)
    }

    // MARK: - Component resolution precedence

    @Test func stateMatchTakesPrecedenceOverRangeAndDefault() {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "battery": EntityComponentIcon(
                    defaultIcon: "mdi:battery",
                    state: ["on": "mdi:battery-charging"],
                    range: ["0": "mdi:battery-outline", "50": "mdi:battery-50"]
                ),
            ],
        ]

        #expect(EntityIconResolver.icon(
            domain: "sensor",
            deviceClass: "battery",
            state: "on",
            attributes: [:],
            map: map
        ) == "mdi:battery-charging")
    }

    @Test func defaultUsedWhenNoStateOrRangeMatches() {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "_": EntityComponentIcon(defaultIcon: "mdi:eye", state: nil, range: nil),
            ],
        ]

        #expect(EntityIconResolver.icon(
            domain: "sensor",
            deviceClass: nil,
            state: "whatever",
            attributes: [:],
            map: map
        ) == "mdi:eye")
    }

    @Test func deviceClassEntryPreferredOverUnderscoreDefault() {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "_": EntityComponentIcon(defaultIcon: "mdi:eye", state: nil, range: nil),
                "temperature": EntityComponentIcon(defaultIcon: "mdi:thermometer", state: nil, range: nil),
            ],
        ]

        #expect(EntityIconResolver.componentDefaultIcon(
            domain: "sensor",
            deviceClass: "temperature",
            map: map
        ) == "mdi:thermometer")

        #expect(EntityIconResolver.componentDefaultIcon(
            domain: "sensor",
            deviceClass: "humidity",
            map: map
        ) == "mdi:eye")
    }

    // MARK: - Range threshold selection

    @Test func rangeSelectsHighestThresholdNotAboveValue() {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "battery": EntityComponentIcon(
                    defaultIcon: "mdi:battery",
                    state: nil,
                    range: [
                        "0": "mdi:battery-outline",
                        "20": "mdi:battery-20",
                        "50": "mdi:battery-50",
                        "90": "mdi:battery-90",
                    ]
                ),
            ],
        ]

        func icon(for state: String) -> String? {
            EntityIconResolver.icon(
                domain: "sensor",
                deviceClass: "battery",
                state: state,
                attributes: [:],
                map: map
            )
        }

        #expect(icon(for: "0") == "mdi:battery-outline")
        #expect(icon(for: "35") == "mdi:battery-20")
        #expect(icon(for: "50") == "mdi:battery-50")
        #expect(icon(for: "100") == "mdi:battery-90")
    }

    @Test func rangeBelowLowestThresholdFallsBackToDefault() {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "battery": EntityComponentIcon(
                    defaultIcon: "mdi:battery",
                    state: nil,
                    range: ["10": "mdi:battery-10", "50": "mdi:battery-50"]
                ),
            ],
        ]

        #expect(EntityIconResolver.icon(
            domain: "sensor",
            deviceClass: "battery",
            state: "5",
            attributes: [:],
            map: map
        ) == "mdi:battery")
    }

    @Test func noMatchReturnsNilSoCallerCanFallBack() {
        #expect(EntityIconResolver.icon(
            domain: "sensor",
            deviceClass: nil,
            state: "on",
            attributes: [:],
            map: [:]
        ) == nil)
    }
}
