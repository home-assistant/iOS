@testable import Shared
import Testing

/// The frontend's toggle tables, as ported: which domains toggle from a tile icon by default, which
/// services a toggle picks between, and how the entity's state picks one.
struct DomainToggleTests {
    /// `DOMAINS_TOGGLE`, plus the button, input button, and scene the tile card adds to it.
    @Test func tileIconTogglesForTheFrontendsToggleDomains() {
        let toggling: [Domain] = [
            .fan, .inputBoolean, .light, .switch, .group, .automation, .humidifier, .valve,
            .button, .inputButton, .scene,
        ]
        for domain in toggling {
            #expect(domain.togglesFromTileIcon, "\(domain.rawValue)")
        }
        for domain in [Domain.script, .cover, .lock, .climate, .mediaPlayer, .sensor, .vacuum] {
            #expect(!domain.togglesFromTileIcon, "\(domain.rawValue)")
        }
    }

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

    /// `turnOnOffEntity`: a group is toggled through `homeassistant`, every other domain through
    /// its own services.
    @Test func groupIsToggledThroughHomeAssistant() {
        #expect(Domain.group.toggleServiceDomain == "homeassistant")
        #expect(Domain.light.toggleServiceDomain == "light")
        #expect(Domain.lock.toggleServiceDomain == "lock")
    }
}
