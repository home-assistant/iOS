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
    @Test func coversTheDevicesPeopleNameOutLoud() {
        let domains = Domain.voiceControllable
        #expect(domains.contains(.light))
        #expect(domains.contains(.switch))
        #expect(domains.contains(.fan))
        #expect(domains.contains(.cover))
        #expect(domains.contains(.climate))
        #expect(domains.contains(.mediaPlayer))
        // Helpers behave exactly like a switch, and people toggle them constantly.
        #expect(domains.contains(.inputBoolean))
        // Named by whoever made them, so worth offering even with no room.
        #expect(domains.contains(.scene))
        #expect(domains.contains(.group))
        #expect(domains.contains(.humidifier))
    }

    @Test func questionsReachMoreDomainsThanCommands() {
        // Safe to report, not to change by voice.
        #expect(Domain.voiceReadable.contains(.lock))
        #expect(!Domain.voiceControllable.contains(.lock))
        #expect(Domain.voiceReadable.contains(.vacuum))
        #expect(Domain.voiceReadable.contains(.alarmControlPanel))
        // A scene has no on/off state to report.
        #expect(!Domain.voiceReadable.contains(.scene))
        // Everything commandable is also readable.
        for domain in Domain.voiceControllable where domain != .scene {
            #expect(Domain.voiceReadable.contains(domain), "\(domain.rawValue) is not readable")
        }
    }

    @Test func onlyTwoWayDomainsCanBeTurnedOff() {
        // A scene's off service is its on service; turning one "off" would activate it.
        #expect(!Domain.scene.isVoiceSwitchable)
        #expect(Domain.light.isVoiceSwitchable)
        #expect(Domain.group.isVoiceSwitchable)
        #expect(Domain.cover.isVoiceSwitchable)
        // Not offered at all, so not switchable either.
        #expect(!Domain.lock.isVoiceSwitchable)
    }

    @Test func onlyDevicesAreExpectedToSitInARoom() {
        #expect(Domain.light.expectsAnArea)
        #expect(Domain.mediaPlayer.expectsAnArea)
        #expect(!Domain.scene.expectsAnArea)
        #expect(!Domain.group.expectsAnArea)
    }

    @Test func riskyReadOnlyAndRarelySpokenDomainsAreNot() {
        let domains = Domain.voiceControllable
        #expect(!domains.contains(.button))
        // A misheard phrase here has real consequences.
        #expect(!domains.contains(.lock))
        #expect(!domains.contains(.siren))
        // Nothing to switch.
        #expect(!domains.contains(.sensor))
        // Their own actions read better than "turn off".
        #expect(!domains.contains(.script))
        #expect(!domains.contains(.automation))
    }

    @Test func everySwitchableDomainIsTwoWay() {
        for domain in Domain.voiceControllable where domain.isVoiceSwitchable {
            #expect(domain.toggleServices?.on != domain.toggleServices?.off, "\(domain.rawValue) is one-way")
        }
    }

    @Test func everyControllableDomainResolvesAService() {
        for domain in Domain.voiceControllable {
            #expect(domain.toggleServices != nil, "\(domain.rawValue) has no service to call")
        }
    }
}
