@testable import Shared
import Testing

/// The frontend's toggle tables, as ported: which services a toggle picks between, and how the
/// entity's state picks one.
struct DomainToggleTests {
    /// `getToggleAction`: the special-cased pairs, and `turn_on`/`turn_off` for everything else.
    @Test func toggleServicesFollowTheFrontendsTable() {
        #expect(Domain.lock.toggleServices! == (on: .unlock, off: .lock))
        #expect(Domain.cover.toggleServices! == (on: .openCover, off: .closeCover))
        #expect(Domain.valve.toggleServices! == (on: .openValve, off: .closeValve))
        #expect(Domain.button.toggleServices! == (on: .press, off: .press))
        #expect(Domain.inputButton.toggleServices! == (on: .press, off: .press))
        #expect(Domain.scene.toggleServices! == (on: .turnOn, off: .turnOn))
        #expect(Domain.light.toggleServices! == (on: .turnOn, off: .turnOff))
        #expect(Domain.script.toggleServices! == (on: .turnOn, off: .turnOff))
        #expect(Domain.climate.toggleServices! == (on: .turnOn, off: .turnOff))

        #expect(Domain.sensor.toggleServices == nil)
        #expect(!Domain.sensor.canToggle)
        #expect(Domain.vacuum.toggleServices == nil)
        #expect(Domain.lock.canToggle)
    }

    /// A button or a scene has one service either way, so a toggle needn't ask for the state.
    @Test func singleServiceDomainsAreNotStateAware() {
        #expect(!Domain.button.toggleIsStateAware)
        #expect(!Domain.scene.toggleIsStateAware)
        #expect(Domain.light.toggleIsStateAware)
        #expect(Domain.lock.toggleIsStateAware)
    }

    /// `toggleEntity`: an entity in one of `STATES_OFF` is turned on, anything else is turned off —
    /// so a locked lock unlocks, an open cover closes, and a running script stops.
    @Test func stateDecidesWhichServiceAToggleCalls() {
        #expect(Domain.lock.toggleService(state: "locked") == .unlock)
        #expect(Domain.lock.toggleService(state: "unlocked") == .lock)
        #expect(Domain.lock.toggleService(state: "jammed") == .lock)
        #expect(Domain.cover.toggleService(state: "closed") == .openCover)
        #expect(Domain.cover.toggleService(state: "open") == .closeCover)
        #expect(Domain.light.toggleService(state: "off") == .turnOn)
        #expect(Domain.light.toggleService(state: "on") == .turnOff)
        #expect(Domain.script.toggleService(state: "off") == .turnOn)
        #expect(Domain.script.toggleService(state: "on") == .turnOff)
        #expect(Domain.button.toggleService(state: "2024-01-01T00:00:00+00:00") == .press)
        #expect(Domain.sensor.toggleService(state: "21.5") == nil)
    }

    /// `canToggleState`: the domains whose on/off pair depends on `supported_features` need those
    /// bits; every other domain toggles regardless, and an unread state leaves it to the domain.
    @Test func supportedFeaturesGateTheDependentDomains() {
        #expect(Domain.camera.toggleRequiredFeatures == 1)
        #expect(Domain.climate.toggleRequiredFeatures == 128 | 256)
        #expect(Domain.cover.toggleRequiredFeatures == 1 | 2)
        #expect(Domain.mediaPlayer.toggleRequiredFeatures == 128 | 256)
        #expect(Domain.siren.toggleRequiredFeatures == 1 | 2)
        #expect(Domain.light.toggleRequiredFeatures == nil)
        #expect(Domain.lock.toggleRequiredFeatures == nil)

        #expect(Domain.mediaPlayer.canToggle(supportedFeatures: nil))
        #expect(Domain.mediaPlayer.canToggle(supportedFeatures: 128 | 256 | 4))
        #expect(!Domain.mediaPlayer.canToggle(supportedFeatures: 128))
        #expect(Domain.siren.canToggle(supportedFeatures: 3))
        #expect(!Domain.siren.canToggle(supportedFeatures: 4))
        #expect(Domain.light.canToggle(supportedFeatures: 0))
        #expect(!Domain.sensor.canToggle(supportedFeatures: 0))
    }

    /// `turnOnOffEntity`: a group has no services of its own, so every call for it is addressed
    /// to `homeassistant`; every other domain answers for itself.
    @Test func groupIsControlledThroughHomeAssistant() {
        #expect(Domain.group.serviceDomain == "homeassistant")
        #expect(Domain.light.serviceDomain == "light")
        #expect(Domain.lock.serviceDomain == "lock")
    }
}
