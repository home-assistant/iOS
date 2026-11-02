import Foundation
@testable import Shared
import Testing

/// Table-driven coverage of `Domain`'s state lists, device-class wording, cover icons and flags, plus
/// the HVAC mode catalog.
struct DomainStateTablesTests {
    @Test func everyDomainListsItsStatesEndingWithUnavailableAndUnknown() {
        for domain in Domain.allCases {
            let states = domain.states
            #expect(Array(states.suffix(2)) == [.unavailable, .unknown], "\(domain)")
        }
        #expect(Domain.cover.states.prefix(4) == [.open, .closed, .opening, .closing])
        #expect(Domain.lock.states.contains(.jammed))
        #expect(Domain.sensor.states == [.unavailable, .unknown])
    }

    @Test func binarySensorWordingFollowsTheDeviceClass() {
        for deviceClass in DeviceClass.allCases {
            let on = Domain.binarySensor.stateForDeviceClass(deviceClass, state: .on)
            let off = Domain.binarySensor.stateForDeviceClass(deviceClass, state: .off)
            #expect(!on.isEmpty, "\(deviceClass)")
            #expect(!off.isEmpty, "\(deviceClass)")
        }
        #expect(
            Domain.binarySensor.stateForDeviceClass(.door, state: .on)
                != Domain.binarySensor.stateForDeviceClass(.door, state: .off)
        )
        #expect(
            Domain.binarySensor.stateForDeviceClass(.garage, state: .on)
                == Domain.binarySensor.stateForDeviceClass(.garageDoor, state: .on)
        )
    }

    @Test func coverAndLockStatesGetContextualWording() {
        for state: Domain.State in [.open, .closed, .opening, .closing, .unknown] {
            #expect(!Domain.cover.stateForDeviceClass(.unknown, state: state).isEmpty, "\(state)")
        }
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .jammed).hasSuffix("!"))
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .locking).hasSuffix("..."))
        #expect(Domain.lock.stateForDeviceClass(.unknown, state: .unlocking).hasSuffix("..."))
        #expect(
            Domain.lock.stateForDeviceClass(.unknown, state: .locked)
                != Domain.lock.stateForDeviceClass(.unknown, state: .unlocked)
        )
        #expect(!Domain.lock.stateForDeviceClass(.unknown, state: .unavailable).isEmpty)
        #expect(!Domain.light.stateForDeviceClass(.unknown, state: .on).isEmpty)
    }

    @Test func coverIconsDependOnDeviceClassAndState() {
        for deviceClass in DeviceClass.allCases {
            let closed = Domain.cover.icon(deviceClass: deviceClass.rawValue, state: .closed)
            let open = Domain.cover.icon(deviceClass: deviceClass.rawValue, state: .open)
            #expect(closed.name != open.name, "\(deviceClass)")
        }
        #expect(Domain.cover.icon(deviceClass: "garage", state: .closed).name == MaterialDesignIcons.garageIcon.name)
        #expect(Domain.cover.icon(deviceClass: "gate", state: .open).name == MaterialDesignIcons.gateOpenIcon.name)
        #expect(Domain.cover.icon().name == MaterialDesignIcons.windowOpenIcon.name)
    }

    @Test func flagsAreConsistentForEveryDomain() {
        for domain in Domain.allCases {
            #expect(domain.localizedDescription == domain.name)
            #expect(domain.isActionable == (domain.mainAction != nil || domain == .lock))
            _ = domain.isCarPlaySupported
            _ = domain.isWatchSupported
            _ = domain.isWatchDisplayOnly
            _ = domain.hasControlScreen
            _ = domain.hasBuiltInConfirmation
            _ = domain.icon()
        }
        #expect(Domain.cover.hasStateDependentIcon)
        #expect(!Domain.sensor.hasStateDependentIcon)
        #expect(Domain.script.hasIrrelevantState)
        #expect(!Domain.light.hasIrrelevantState)
    }

    @Test func hvacModesHaveTitlesAndIcons() {
        for mode in ClimateHvacMode.allCases {
            #expect(!mode.title.isEmpty, "\(mode)")
            #expect(ClimateHvacMode.localizedTitle(forMode: mode.rawValue) == mode.title)
            _ = mode.icon
        }
        #expect(Set(ClimateHvacMode.allCases.map(\.icon.name)).count == ClimateHvacMode.allCases.count)
        #expect(!ClimateHvacMode.localizedTitle(forMode: "eco_boost").isEmpty)
    }
}
