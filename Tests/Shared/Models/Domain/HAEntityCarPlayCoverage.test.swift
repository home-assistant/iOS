import Foundation
import HAKit
import PromiseKit
@testable import Shared
import Testing
import UIKit

/// The CarPlay/watch icon mapping in `HAEntity+CarPlay`: the hand-maintained per-domain icons, the
/// backend icon map taking precedence when given, and pressing an entity from a list.
struct HAEntityCarPlayCoverageTests {
    private func entity(
        _ entityId: String,
        state: String,
        attributes: [String: Any] = [:]
    ) throws -> HAEntity {
        try HAEntity(
            entityId: entityId,
            state: state,
            lastChanged: Date(timeIntervalSince1970: 0),
            lastUpdated: Date(timeIntervalSince1970: 0),
            attributes: attributes,
            context: .init(id: "context", userId: nil, parentId: nil)
        )
    }

    private func mdi(
        _ entityId: String,
        state: String,
        deviceClass: String? = nil
    ) throws -> MaterialDesignIcons {
        var attributes: [String: Any] = [:]
        if let deviceClass {
            attributes["device_class"] = deviceClass
        }
        return try entity(entityId, state: state, attributes: attributes).getMDI()
    }

    @Test func fixedDomainIcons() throws {
        #expect(try mdi("input_button.doorbell", state: "unknown") == .gestureTapButtonIcon)
        #expect(try mdi("light.kitchen", state: "on") == .lightbulbIcon)
        #expect(try mdi("scene.movie", state: "unknown") == .paletteOutlineIcon)
        #expect(try mdi("script.open_gate", state: "off") == .scriptTextOutlineIcon)
        #expect(try mdi("sensor.power", state: "12") == .eyeIcon)
        #expect(try mdi("binary_sensor.motion", state: "on") == .radioboxBlankIcon)
        #expect(try mdi("zone.home", state: "2") == .mapIcon)
        #expect(try mdi("person.anna", state: "home") == .accountIcon)
        #expect(try mdi("camera.porch", state: "idle") == .cameraIcon)
        #expect(try mdi("fan.bedroom", state: "on") == .fanIcon)
        #expect(try mdi("automation.lights", state: "on") == .homeAutomationIcon)
        #expect(try mdi("todo.shopping", state: "3") == .checkboxMarkedOutlineIcon)
        #expect(try mdi("climate.living_room", state: "heat") == .homeThermometerOutlineIcon)
    }

    @Test func unmodeledDomainsUseTheDomainIconAndUnknownDomainsABookmark() throws {
        #expect(try mdi("vacuum.robot", state: "docked") == Domain.vacuum.icon(deviceClass: nil, state: nil))
        #expect(try mdi("not_a_domain.thing", state: "on") == .bookmarkIcon)
    }

    @Test func buttonIconsFollowTheDeviceClass() throws {
        #expect(try mdi("button.reboot", state: "unknown", deviceClass: "restart") == .restartIcon)
        #expect(try mdi("button.firmware", state: "unknown", deviceClass: "update") == .packageUpIcon)
        #expect(try mdi("button.press", state: "unknown") == .gestureTapButtonIcon)
    }

    @Test func inputBooleanIconsFollowTheState() throws {
        #expect(try mdi("input_boolean.guest", state: "on") == .checkCircleOutlineIcon)
        #expect(try mdi("input_boolean.guest", state: "off") == .closeCircleOutlineIcon)
        #expect(try mdi("input_boolean.guest", state: "not_a_state") == .toggleSwitchOutlineIcon)
        #expect(try mdi("input_boolean.ha_ios_placeholder", state: "on") == .toggleSwitchOutlineIcon)
    }

    @Test func lockIconsFollowTheState() throws {
        #expect(try mdi("lock.front", state: "locked") == .lockIcon)
        #expect(try mdi("lock.front", state: "unlocked") == .lockOpenIcon)
        #expect(try mdi("lock.front", state: "jammed") == .lockAlertIcon)
        #expect(try mdi("lock.front", state: "locking") == .lockClockIcon)
        #expect(try mdi("lock.front", state: "unlocking") == .lockClockIcon)
        #expect(try mdi("lock.front", state: "not_a_state") == .lockIcon)
    }

    @Test func switchIconsFollowTheDeviceClassAndState() throws {
        #expect(try mdi("switch.plug", state: "on", deviceClass: "outlet") == .powerPlugIcon)
        #expect(try mdi("switch.plug", state: "off", deviceClass: "outlet") == .powerPlugOffIcon)
        #expect(try mdi("switch.toggle", state: "on", deviceClass: "switch") == .toggleSwitchIcon)
        #expect(try mdi("switch.toggle", state: "off", deviceClass: "switch") == .toggleSwitchOffIcon)
        #expect(try mdi("switch.relay", state: "on") == .flashIcon)
        #expect(try mdi("switch.relay", state: "not_a_state") == .lightSwitchIcon)
        #expect(try mdi("switch.ha_ios_placeholder", state: "on") == .lightSwitchIcon)
    }

    @Test func coverIconsFollowTheDeviceClassAndState() throws {
        let expected: [(String?, String, MaterialDesignIcons)] = [
            ("garage", "opening", .arrowUpBoxIcon),
            ("garage", "closing", .arrowDownBoxIcon),
            ("garage", "closed", .garageIcon),
            ("garage", "open", .garageOpenIcon),
            ("gate", "opening", .gateArrowRightIcon),
            ("gate", "closed", .gateIcon),
            ("gate", "open", .gateOpenIcon),
            ("door", "open", .doorOpenIcon),
            ("door", "closed", .doorClosedIcon),
            ("damper", "open", .circleIcon),
            ("damper", "closed", .circleSlice8Icon),
            ("shutter", "opening", .arrowUpBoxIcon),
            ("shutter", "closing", .arrowDownBoxIcon),
            ("shutter", "closed", .windowShutterIcon),
            ("shutter", "open", .windowShutterOpenIcon),
            ("curtain", "opening", .arrowSplitVerticalIcon),
            ("curtain", "closing", .arrowCollapseHorizontalIcon),
            ("curtain", "closed", .curtainsClosedIcon),
            ("curtain", "open", .curtainsIcon),
            ("blind", "opening", .arrowUpBoxIcon),
            ("blind", "closing", .arrowDownBoxIcon),
            ("shade", "closed", .blindsIcon),
            ("shade", "open", .blindsOpenIcon),
            (nil, "open", .arrowUpBoxIcon),
            (nil, "closing", .arrowDownBoxIcon),
            (nil, "closed", .windowClosedIcon),
            (nil, "opening", .windowOpenIcon),
        ]

        for (deviceClass, state, icon) in expected {
            #expect(
                try mdi("cover.test", state: state, deviceClass: deviceClass) == icon,
                "\(deviceClass ?? "nil") \(state)"
            )
        }
        #expect(try mdi("cover.test", state: "not_a_state") == .bookmarkIcon)
    }

    @Test func attributeIconWinsOverEverything() throws {
        let light = try entity("light.kitchen", state: "on", attributes: ["icon": "mdi:sofa"])
        let map: EntityComponentIconsMap = [
            "light": ["_": EntityComponentIcon(defaultIcon: "mdi:lamp", state: nil, range: nil)],
        ]
        #expect(light.getMDI() == .sofaIcon)
        #expect(light.getMDI(componentIcons: map) == .sofaIcon)
    }

    @Test func componentIconMapIsUsedWhenGiven() throws {
        let map: EntityComponentIconsMap = [
            "sensor": [
                "temperature": EntityComponentIcon(defaultIcon: "mdi:thermometer", state: nil, range: nil),
            ],
        ]
        let temperature = try entity("sensor.outside", state: "12", attributes: ["device_class": "temperature"])
        #expect(temperature.getMDI(componentIcons: map) == .thermometerIcon)
        #expect(temperature.getMDI() == .eyeIcon)

        // The frontend's state special-cases apply even with an empty map.
        let sun = try entity("sun.sun", state: "below_horizon")
        #expect(sun.getMDI(componentIcons: [:]) == .weatherNightIcon)

        // Nothing in the map for the domain keeps the hand-maintained icon.
        let light = try entity("light.kitchen", state: "on")
        #expect(light.getMDI(componentIcons: map) == .lightbulbIcon)
    }

    @Test func renderedIconAndColorAreProduced() throws {
        let light = try entity("light.kitchen", state: "on", attributes: ["rgb_color": [255, 0, 0]])
        #expect(light.getIcon() != nil)
        #expect(light.stateIconColor() != nil)
        #expect(light.stateIconColor(customColor: .systemRed) != nil)
    }

    @Test func localizedStateFallsBackToTheRawStateForUnknownDomains() throws {
        let unknown = try entity("not_a_domain.thing", state: "some_unmapped_value_42")
        #expect(unknown.localizedState == "some_unmapped_value_42")

        let light = try entity("light.kitchen", state: "on")
        #expect(light.localizedState == Domain.light.localizedState(for: "on"))
    }

    @Test func pressingAnEntityRunsItsDomainAction() async throws {
        let connection = MagicItemTestConnection()
        connection.responses["call_service"] = .success(.empty)
        let api = HomeAssistantAPI(server: Server.fake())
        api.connection = connection

        let light = try entity("light.kitchen", state: "off")
        #expect(await succeeds(light.onPress(for: api)))
        let request = try #require(connection.sentRequests.first)
        #expect(request.type.command == "call_service")
        #expect(request.data["domain"] as? String == "light")
        #expect(request.data["service"] as? String == Service.toggle.rawValue)

        // A domain the app doesn't know has nothing to run, which isn't a failure.
        let unknown = try entity("not_a_domain.thing", state: "on")
        #expect(await succeeds(unknown.onPress(for: api)))
        #expect(connection.sentRequests.count == 1)
    }

    @Test func pressingAnEntityReportsTheServerError() async throws {
        let connection = MagicItemTestConnection()
        connection.responses["call_service"] = .failure(.internal(debugDescription: "unit-test"))
        let api = HomeAssistantAPI(server: Server.fake())
        api.connection = connection

        let light = try entity("light.kitchen", state: "off")
        #expect(await !succeeds(light.onPress(for: api)))
    }

    private func succeeds(_ promise: Promise<Void>) async -> Bool {
        await withCheckedContinuation { continuation in
            promise.done {
                continuation.resume(returning: true)
            }.catch { _ in
                continuation.resume(returning: false)
            }
        }
    }
}
