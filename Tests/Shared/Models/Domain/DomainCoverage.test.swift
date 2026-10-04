import Foundation
import HAKit
@testable import Shared
import Testing

/// The parts of `Domain` that `DomainTests` leaves alone: the per-domain state lists, the
/// device-class wording, the cover icons, the voice and watch lists, and the state descriptions.
struct DomainCoverageTests {
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

    // MARK: - Parsing and states

    @Test func entityIdParsesItsDomain() {
        #expect(Domain(entityId: "light.kitchen") == .light)
        #expect(Domain(entityId: "binary_sensor.door") == .binarySensor)
        #expect(Domain(entityId: "not_a_domain.thing") == nil)
        #expect(Domain(entityId: "") == nil)
    }

    @Test func statesListTheDomainsOwnStatesThenUnavailableAndUnknown() {
        #expect(Domain.cover.states == [.open, .closed, .opening, .closing, .unavailable, .unknown])
        #expect(Domain.fan.states == [.on, .off, .unavailable, .unknown])
        #expect(Domain.light.states == [.on, .off, .unavailable, .unknown])
        #expect(Domain.switch.states == [.on, .off, .unavailable, .unknown])
        #expect(
            Domain.lock.states == [.locked, .unlocked, .jammed, .locking, .unlocking, .unavailable, .unknown]
        )
        #expect(Domain.sensor.states == [.unavailable, .unknown])
    }

    // MARK: - Device class wording

    @Test func binarySensorDeviceClassesUseTheirOwnWording() {
        let cases: [(DeviceClass, String, String)] = [
            (
                .door,
                CoreStrings.componentBinarySensorEntityComponentDoorStateOn,
                CoreStrings.componentBinarySensorEntityComponentDoorStateOff
            ),
            (
                .window,
                CoreStrings.componentBinarySensorEntityComponentWindowStateOn,
                CoreStrings.componentBinarySensorEntityComponentWindowStateOff
            ),
            (
                .garage,
                CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOn,
                CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOff
            ),
            (
                .garageDoor,
                CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOn,
                CoreStrings.componentBinarySensorEntityComponentGarageDoorStateOff
            ),
            (
                .lock,
                CoreStrings.componentBinarySensorEntityComponentLockStateOn,
                CoreStrings.componentBinarySensorEntityComponentLockStateOff
            ),
            (
                .opening,
                CoreStrings.componentBinarySensorEntityComponentOpeningStateOn,
                CoreStrings.componentBinarySensorEntityComponentOpeningStateOff
            ),
            (
                .presence,
                CoreStrings.componentBinarySensorEntityComponentPresenceStateOn,
                CoreStrings.componentBinarySensorEntityComponentPresenceStateOff
            ),
            (
                .connectivity,
                CoreStrings.componentBinarySensorEntityComponentConnectivityStateOn,
                CoreStrings.componentBinarySensorEntityComponentConnectivityStateOff
            ),
            (.gate, CoreStrings.commonStateOpen, CoreStrings.commonStateClosed),
            (
                .shade,
                CoreStrings.componentCoverEntityComponentStateOpen,
                CoreStrings.componentCoverEntityComponentStateClosed
            ),
            (
                .motion,
                CoreStrings.componentBinarySensorEntityComponentStateOn,
                CoreStrings.componentBinarySensorEntityComponentStateOff
            ),
        ]

        for (deviceClass, on, off) in cases {
            #expect(Domain.binarySensor.stateForDeviceClass(deviceClass, state: .on) == on, "\(deviceClass) on")
            #expect(Domain.binarySensor.stateForDeviceClass(deviceClass, state: .off) == off, "\(deviceClass) off")
        }
    }

    @Test func coverStatesUseTheCoverWording() {
        #expect(
            Domain.cover.stateForDeviceClass(.unknown, state: .open)
                == CoreStrings.componentCoverEntityComponentStateOpen
        )
        #expect(
            Domain.cover.stateForDeviceClass(.unknown, state: .closed)
                == CoreStrings.componentCoverEntityComponentStateClosed
        )
        #expect(
            Domain.cover.stateForDeviceClass(.unknown, state: .opening)
                == Domain.cover.localizedState(for: "opening").leadingCapitalized
        )
        #expect(
            Domain.cover.stateForDeviceClass(.unknown, state: .closing)
                == Domain.cover.localizedState(for: "closing").leadingCapitalized
        )
        #expect(
            Domain.cover.stateForDeviceClass(.unknown, state: .unavailable)
                == Domain.cover.localizedState(for: "unavailable").leadingCapitalized
        )
    }

    @Test func lockStatesMarkTransitionsAndJams() {
        let locking = Domain.lock.localizedState(for: "locking").leadingCapitalized
        let unlocking = Domain.lock.localizedState(for: "unlocking").leadingCapitalized
        let jammed = Domain.lock.localizedState(for: "jammed").leadingCapitalized

        #expect(
            Domain.lock.stateForDeviceClass(.unknown, state: .locked)
                == CoreStrings.componentLockEntityComponentStateLocked
        )
        #expect(
            Domain.lock.stateForDeviceClass(.unknown, state: .unlocked)
                == CoreStrings.componentLockEntityComponentStateUnlocked
        )
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .locking) == locking + "...")
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .unlocking) == unlocking + "...")
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .jammed) == jammed + "!")
        #expect(
            Domain.lock.stateForDeviceClass(.unknown, state: .unknown)
                == Domain.lock.localizedState(for: "unknown").leadingCapitalized
        )
    }

    @Test func otherDomainsUseTheirLocalizedState() {
        #expect(
            Domain.light.stateForDeviceClass(.unknown, state: .on)
                == Domain.light.localizedState(for: "on").leadingCapitalized
        )
        #expect(!Domain.light.stateForDeviceClass(.unknown, state: .on).isEmpty)
    }

    @Test func localizedStateFallsBackToTheRawState() {
        #expect(Domain.sensor.localizedState(for: "some_unmapped_value_42") == "some_unmapped_value_42")
        // A button that has never been pressed has no timestamp to render relatively.
        #expect(Domain.button.localizedState(for: "unknown") == Domain.sensor.localizedState(for: "unknown"))
    }

    // MARK: - Contextual descriptions

    @Test func climateDescriptionIsTheClimateSummary() throws {
        let climate = try entity(
            "climate.living_room",
            state: "heat",
            attributes: ["current_temperature": 21.5, "temperature": 22]
        )
        #expect(
            Domain.climate.contextualStateDescription(for: climate)
                == ClimateControlState(entity: climate).stateSummary
        )
    }

    @Test func binarySensorDescriptionUsesTheDeviceClassWording() throws {
        let door = try entity("binary_sensor.front_door", state: "on", attributes: ["device_class": "door"])
        #expect(
            Domain.binarySensor.contextualStateDescription(for: door)
                == CoreStrings.componentBinarySensorEntityComponentDoorStateOn
        )
    }

    @Test func nonEnumStateWithoutUnitIsTheCapitalizedState() throws {
        let select = try entity("input_select.mode", state: "quiet_mode_x7")
        #expect(Domain.inputSelect.contextualStateDescription(for: select) == "Quiet_mode_x7")
    }

    @Test func lockDescriptionUsesTheLockWording() throws {
        let lock = try entity("lock.front", state: "locked")
        #expect(
            Domain.lock.contextualStateDescription(for: lock)
                == CoreStrings.componentLockEntityComponentStateLocked
        )
    }

    // MARK: - Icons

    @Test func closedCoverIconsFollowTheDeviceClass() {
        let expected: [(String?, MaterialDesignIcons)] = [
            ("garage", .garageIcon),
            ("garage_door", .garageIcon),
            ("gate", .gateIcon),
            ("shutter", .windowShutterIcon),
            ("blind", .blindsHorizontalClosedIcon),
            ("shade", .rollerShadeClosedIcon),
            ("curtain", .curtainsClosedIcon),
            ("door", .doorClosedIcon),
            ("damper", .circleSlice8Icon),
            ("window", .windowClosedIcon),
            ("awning", .windowClosedIcon),
            (nil, .windowClosedIcon),
        ]
        for (deviceClass, icon) in expected {
            #expect(Domain.cover.icon(deviceClass: deviceClass, state: .closed) == icon, "\(deviceClass ?? "nil")")
        }
    }

    @Test func openCoverIconsFollowTheDeviceClass() {
        let expected: [(String?, MaterialDesignIcons)] = [
            ("garage", .garageOpenIcon),
            ("garage_door", .garageOpenIcon),
            ("gate", .gateOpenIcon),
            ("shutter", .windowShutterOpenIcon),
            ("blind", .blindsHorizontalIcon),
            ("shade", .rollerShadeIcon),
            ("curtain", .curtainsIcon),
            ("door", .doorOpenIcon),
            ("damper", .circleIcon),
            ("window", .windowOpenIcon),
            (nil, .windowOpenIcon),
        ]
        for (deviceClass, icon) in expected {
            #expect(Domain.cover.icon(deviceClass: deviceClass, state: .open) == icon, "\(deviceClass ?? "nil")")
        }
        // Without a state the cover is drawn open.
        #expect(Domain.cover.icon() == .windowOpenIcon)
    }

    @Test func domainNamesFallBackToTheRawValueWithoutACoreString() {
        for domain in [Domain.zone, .airQuality, .conversation, .stt, .tts, .wakeWord, .counter, .infrared,
                       .radioFrequency] {
            #expect(domain.name == domain.rawValue)
        }
        for domain in Domain.allCases {
            #expect(domain.localizedDescription == domain.name)
        }
    }

    // MARK: - Feature lists

    @Test func membershipFlagsMirrorTheirLists() {
        for domain in Domain.allCases {
            #expect(domain.isCarPlaySupported == Domain.carPlaySupported.contains(domain))
            #expect(domain.isWatchSupported == Domain.watchSupported.contains(domain))
            #expect(domain.isWatchDisplayOnly == Domain.watchDisplayOnly.contains(domain))
            #expect(domain.hasControlScreen == Domain.controlScreenDomains.contains(domain))
            #expect(domain.hasBuiltInConfirmation == Domain.builtInConfirmationDomains.contains(domain))
        }
    }

    @Test func voiceListsKeepCoversOnOpenAndClose() {
        #expect(Domain.voiceOpenable == [.cover])
        #expect(Domain.voiceSwitchOffered == [.light, .switch, .inputBoolean, .fan, .humidifier, .group])
        #expect(!Domain.voiceSwitchOffered.contains(.cover))
        #expect(Domain.voiceReadable == Domain.voiceControllable + [.waterHeater, .sensor, .binarySensor])
    }

    @Test func onlyStateAwareVoiceDomainsCanBeSwitchedOff() {
        #expect(Domain.light.isVoiceSwitchable)
        #expect(Domain.switch.isVoiceSwitchable)
        #expect(Domain.cover.isVoiceSwitchable)
        #expect(!Domain.scene.isVoiceSwitchable)
        #expect(!Domain.lock.isVoiceSwitchable)
        #expect(!Domain.sensor.isVoiceSwitchable)
    }

    @Test func watchAreaControlsSortMostUsedFirstAndUnknownLast() {
        let last = Domain.watchAreaControlsOrder.count
        #expect(Domain.watchAreaControlsSortIndex(for: .light) == 0)
        #expect(Domain.watchAreaControlsSortIndex(for: .switch) == 1)
        #expect(Domain.watchAreaControlsSortIndex(for: .automation) == last - 1)
        #expect(Domain.watchAreaControlsSortIndex(for: .sensor) == last)
        #expect(Domain.watchAreaControlsSortIndex(for: nil) == last)
    }

    @Test func watchAddableCoversEveryWatchList() {
        #expect(Domain.watchAddable == Domain.watchSupported + Domain.watchDisplayOnly + Domain.controlScreenDomains)
    }
}
