@testable import HomeAssistant
@testable import Shared
import Testing

struct ControlEntityIntentRunnerTests {
    @Test func speaksOpenedForCoversAndTurnedOnForLights() {
        #expect(ControlEntityIntentRunner.dialog(for: .openCover, entityName: "Blinds") == "Opened Blinds")
        #expect(ControlEntityIntentRunner.dialog(for: .closeCover, entityName: "Blinds") == "Closed Blinds")
        #expect(ControlEntityIntentRunner.dialog(for: .turnOn, entityName: "Lamp") == "Turned on Lamp")
        #expect(ControlEntityIntentRunner.dialog(for: .turnOff, entityName: "Lamp") == "Turned off Lamp")
        #expect(ControlEntityIntentRunner.dialog(for: .toggle, entityName: "Lamp") == "Toggled Lamp")
    }

    @Test func valvesAndLocksBorrowTheOpenAndClosedWording() {
        #expect(ControlEntityIntentRunner.dialog(for: .openValve, entityName: "Water") == "Opened Water")
        #expect(ControlEntityIntentRunner.dialog(for: .closeValve, entityName: "Water") == "Closed Water")
        #expect(ControlEntityIntentRunner.dialog(for: .unlock, entityName: "Door") == "Opened Door")
    }
}

struct VoiceControllableDomainsTests {
    @Test func coversLightsAndCoversAreControllable() {
        let domains = Domain.voiceControllable
        #expect(domains.contains(.light))
        #expect(domains.contains(.switch))
        #expect(domains.contains(.fan))
        #expect(domains.contains(.cover))
        #expect(domains.contains(.valve))
    }

    @Test func scenesButtonsAndLocksAreNot() {
        let domains = Domain.voiceControllable
        // A scene's "off" service turns it on again, so "turn off" would re-activate it.
        #expect(!domains.contains(.scene))
        #expect(!domains.contains(.button))
        // Unlocking carries its own confirmation rather than answering a phrase.
        #expect(!domains.contains(.lock))
        #expect(!domains.contains(.sensor))
    }

    @Test func everyControllableDomainResolvesBothServices() {
        for domain in Domain.voiceControllable {
            #expect(domain.toggleServices != nil, "\(domain.rawValue) has no service pair")
            #expect(domain.toggleServices?.on != domain.toggleServices?.off, "\(domain.rawValue) is not two-way")
        }
    }
}
