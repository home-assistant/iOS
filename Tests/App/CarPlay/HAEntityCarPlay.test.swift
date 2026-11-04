import HAKit
@testable import Shared
import SharedTesting
import Testing
import UIKit

@Suite(.sharedState)
@MainActor
struct HAEntityCarPlayTests {
    @Test("Given an entity without a custom icon when requesting a CarPlay icon then it uses the domain/state icon")
    func usesDomainAndStateBasedIconWhenNoCustomIconExists() throws {
        let entity = try HAEntity(
            entityId: "light.kitchen",
            state: Domain.State.off.rawValue,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Kitchen light",
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.lightbulbIcon
                .carPlayIcon(color: entity.stateIconColor())
                .pngData()
        )

        #expect(actualData == expectedData)
    }

    @Test(
        "Given an entity with a custom icon when requesting a CarPlay icon then it preserves that icon before falling back"
    )
    func usesCustomAttributeIconBeforeFallbacks() throws {
        let entity = try HAEntity(
            entityId: "sensor.temperature",
            state: "23",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Temperature",
                "icon": "mdi:thermometer",
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.thermometerIcon
                .carPlayIcon(color: entity.stateIconColor())
                .pngData()
        )

        #expect(actualData == expectedData)
    }

    @Test("Given an active light with server RGB color when requesting a CarPlay icon then it uses that live color")
    func usesServerProvidedRGBColorForActiveLightIcon() throws {
        let entity = try HAEntity(
            entityId: "light.kitchen",
            state: Domain.State.on.rawValue,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Kitchen light",
                "color_mode": "rgb",
                "rgb_color": [255, 140, 0],
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let actualData = try #require(entity.getIcon()?.pngData())
        let expectedData = try #require(
            MaterialDesignIcons.lightbulbIcon
                .carPlayIcon(color: UIColor(red: 1, green: 140.0 / 255.0, blue: 0, alpha: 1))
                .pngData()
        )

        #expect(actualData == expectedData)
    }

    @Test("Given a domain without a dedicated CarPlay icon then getMDI falls back to Domain.icon")
    func usesDomainIconFallbackForUnhandledDomain() throws {
        let entity = try HAEntity(
            entityId: "media_player.living_room",
            state: "playing",
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: [
                "friendly_name": "Living room speaker",
            ],
            context: .init(id: "context", userId: "user", parentId: nil)
        )

        let expected = Domain.mediaPlayer.icon(
            deviceClass: entity.deviceClass.rawValue,
            state: Domain.State(rawValue: entity.state)
        )
        #expect(entity.getMDI() == expected)
    }

    // MARK: - Hardcoded icons per domain, state and device class

    private static func entity(_ entityId: String, _ state: String, deviceClass: String? = nil) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(),
            lastUpdated: Date(),
            attributes: entityId.hasPrefix("zone.")
                ? ["latitude": 0.0, "longitude": 0.0, "radius": 100.0, "passive": false]
                : deviceClass.map { ["device_class": $0] } ?? [:],
            context: .init(id: "context", userId: "user", parentId: nil)
        )
    }

    /// (entity id, state, device class, expected icon)
    private static let iconCases: [(String, String, String?, MaterialDesignIcons)] = [
        ("button.reboot", "unknown", "restart", .restartIcon),
        ("button.upgrade", "unknown", "update", .packageUpIcon),
        ("button.press", "unknown", nil, .gestureTapButtonIcon),
        ("input_boolean.guest", "on", nil, .checkCircleOutlineIcon),
        ("input_boolean.guest", "off", nil, .closeCircleOutlineIcon),
        ("input_boolean.ha_ios_placeholder", "on", nil, .toggleSwitchOutlineIcon),
        ("input_button.bell", "unknown", nil, .gestureTapButtonIcon),
        ("lock.front", "locked", nil, .lockIcon),
        ("lock.front", "unlocked", nil, .lockOpenIcon),
        ("lock.front", "jammed", nil, .lockAlertIcon),
        ("lock.front", "locking", nil, .lockClockIcon),
        ("lock.front", "unlocking", nil, .lockClockIcon),
        ("lock.front", "weird", nil, .lockIcon),
        ("scene.movie", "scening", nil, .paletteOutlineIcon),
        ("script.go", "off", nil, .scriptTextOutlineIcon),
        ("switch.plug", "on", "outlet", .powerPlugIcon),
        ("switch.plug", "off", "outlet", .powerPlugOffIcon),
        ("switch.toggle", "on", "switch", .toggleSwitchIcon),
        ("switch.toggle", "off", "switch", .toggleSwitchOffIcon),
        ("switch.other", "on", nil, .flashIcon),
        ("switch.other", "weird", nil, .lightSwitchIcon),
        ("switch.ha_ios_placeholder", "on", nil, .lightSwitchIcon),
        ("sensor.temperature", "21", nil, .eyeIcon),
        ("binary_sensor.door", "on", nil, .radioboxBlankIcon),
        ("zone.home", "0", nil, .mapIcon),
        ("person.me", "home", nil, .accountIcon),
        ("camera.porch", "idle", nil, .cameraIcon),
        ("fan.ceiling", "on", nil, .fanIcon),
        ("automation.night", "on", nil, .homeAutomationIcon),
        ("todo.shopping", "3", nil, .checkboxMarkedOutlineIcon),
        ("climate.hall", "heat", nil, .homeThermometerOutlineIcon),
        ("cover.garage", "opening", "garage", .arrowUpBoxIcon),
        ("cover.garage", "closing", "garage", .arrowDownBoxIcon),
        ("cover.garage", "closed", "garage", .garageIcon),
        ("cover.garage", "open", "garage", .garageOpenIcon),
        ("cover.gate", "opening", "gate", .gateArrowRightIcon),
        ("cover.gate", "closed", "gate", .gateIcon),
        ("cover.gate", "open", "gate", .gateOpenIcon),
        ("cover.door", "open", "door", .doorOpenIcon),
        ("cover.door", "closed", "door", .doorClosedIcon),
        ("cover.damper", "open", "damper", .circleIcon),
        ("cover.damper", "closed", "damper", .circleSlice8Icon),
        ("cover.shutter", "opening", "shutter", .arrowUpBoxIcon),
        ("cover.shutter", "closing", "shutter", .arrowDownBoxIcon),
        ("cover.shutter", "closed", "shutter", .windowShutterIcon),
        ("cover.shutter", "open", "shutter", .windowShutterOpenIcon),
        ("cover.curtain", "opening", "curtain", .arrowSplitVerticalIcon),
        ("cover.curtain", "closing", "curtain", .arrowCollapseHorizontalIcon),
        ("cover.curtain", "closed", "curtain", .curtainsClosedIcon),
        ("cover.curtain", "open", "curtain", .curtainsIcon),
        ("cover.blind", "opening", "blind", .arrowUpBoxIcon),
        ("cover.shade", "closing", "shade", .arrowDownBoxIcon),
        ("cover.blind", "closed", "blind", .blindsIcon),
        ("cover.shade", "open", "shade", .blindsOpenIcon),
        ("cover.window", "open", nil, .arrowUpBoxIcon),
        ("cover.window", "closing", nil, .arrowDownBoxIcon),
        ("cover.window", "closed", nil, .windowClosedIcon),
        ("cover.window", "opening", nil, .windowOpenIcon),
        ("cover.window", "weird", nil, .bookmarkIcon),
        ("mystery.thing", "on", nil, .bookmarkIcon),
    ]

    @Test func everyDomainStateAndDeviceClassHasItsIcon() throws {
        for (entityId, state, deviceClass, expected) in Self.iconCases {
            let icon = try Self.entity(entityId, state, deviceClass: deviceClass).getMDI()
            #expect(icon.name == expected.name, "\(entityId) \(state) \(deviceClass ?? "-")")
        }
    }

    /// The backend's icon map wins over the hardcoded mapping when it has an entry.
    @Test func theComponentIconMapResolvesFirst() throws {
        let map: EntityComponentIconsMap = [
            "switch": ["_": EntityComponentIcon(defaultIcon: "mdi:rocket", state: nil, range: nil)],
        ]

        let icon = try Self.entity("switch.other", "on").getMDI(componentIcons: map)

        #expect(icon.name == MaterialDesignIcons(serversideValueNamed: "mdi:rocket").name)
        let light = try Self.entity("light.a", "on").getMDI(componentIcons: map)
        #expect(light.name == MaterialDesignIcons.lightbulbIcon.name)
    }

    /// The API registers with the sensor container, so it gets a container of its own.
    @Test func pressingAnEntityOfAnUnknownDomainDoesNothing() throws {
        let previousSensors = Current.sensors
        Current.sensors = SensorContainer()
        defer { Current.sensors = previousSensors }
        let api = HomeAssistantAPI(server: .fake())

        let promise = try Self.entity("mystery.thing", "on").onPress(for: api)

        #expect(promise.isFulfilled)
    }

    @Test func gridAndCondensedIconsRender() {
        #expect(MaterialDesignIcons.lightbulbIcon.carPlayGridIcon().size != .zero)
        #expect(MaterialDesignIcons.lightbulbIcon.carPlayGridIcon(color: .red).size != .zero)
        if #available(iOS 26.0, *) {
            #expect(MaterialDesignIcons.lightbulbIcon.carPlayCondensedElementImage().size != .zero)
        }
    }
}
