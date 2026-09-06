@testable import HomeAssistant
@testable import Shared
import Testing

struct SiriValueIntentsTests {
    /// Locking is safe to say out loud; unlocking is not offered at all.
    @Test func locksAreNotReachableByTheOnOffCommands() {
        #expect(!Domain.voiceControllable.contains(.lock))
        #expect(Domain.voiceReadable.contains(.lock))
        #expect(Domain.lock.toggleServices?.on == .unlock)
        #expect(Domain.lock.toggleServices?.off == .lock)
    }

    /// `SetTemperatureAppIntent` hard-codes 7...35 because App Intents needs a literal range. If the
    /// frontend defaults ever move, that literal has to move with them.
    @Test func temperatureRangeMatchesTheFrontendDefaults() {
        #expect(ClimateControlState.defaultMinTemperature == 7.0)
        #expect(ClimateControlState.defaultMaxTemperature == 35.0)
    }

    @Test func dialogsReadNaturally() {
        #expect(L10n.AppIntents.Dialog.locked("Front door") == "Locked Front door")
        #expect(L10n.AppIntents.Dialog.setBrightness("Lamp", 30) == "Set Lamp to 30%")
        #expect(L10n.AppIntents.Dialog.setTemperature("Hallway", "21") == "Set Hallway to 21")
    }
}
