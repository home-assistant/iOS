import AVFoundation
@testable import Shared
import Testing

@Suite(.serialized)
struct CarPlayAssistDebugSettingsTests {
    init() {
        Self.removeStoredSettings()
    }

    @Test func defaultsWhenNothingStored() {
        #expect(Current.settingsStore.carPlayAssistDebugSettings == CarPlayAssistDebugSettings.default)
    }

    @Test func roundTripsStoredSettings() {
        defer { Self.removeStoredSettings() }

        let settings = CarPlayAssistDebugSettings(
            audioCategory: .playback,
            audioMode: .spokenAudio,
            preferredSampleRate: .rate48000,
            allowBluetoothHFP: false,
            allowBluetoothA2DP: false,
            duckOthers: true,
            interruptSpokenAudio: true,
            playRecordingIndicatorTone: false,
            recorderManagesAudioSession: true,
            ttsPlaybackStrategy: .downloadedAVAudioPlayer,
            ttsReconfigureAudioSession: true,
            ttsDeactivateBeforeReconfigure: true,
            ttsActivateAudioSession: false,
            ttsCategory: .record,
            ttsMode: .measurement,
            ttsAllowBluetoothHFP: false,
            ttsAllowBluetoothA2DP: false,
            ttsDuckOthers: true,
            ttsInterruptSpokenAudio: false,
            avPlayerAutomaticallyWaitsToMinimizeStalling: false,
            ttsPlaybackDelay: .ms500
        )

        Current.settingsStore.carPlayAssistDebugSettings = settings

        #expect(Current.settingsStore.carPlayAssistDebugSettings == settings)
    }

    @Test func resetRestoresDefaults() {
        defer { Self.removeStoredSettings() }

        Current.settingsStore.carPlayAssistDebugSettings = CarPlayAssistDebugSettings(
            audioCategory: .record,
            audioMode: .measurement,
            preferredSampleRate: .rate44100,
            allowBluetoothHFP: false,
            allowBluetoothA2DP: false,
            duckOthers: true,
            interruptSpokenAudio: true,
            playRecordingIndicatorTone: false,
            recorderManagesAudioSession: true,
            ttsPlaybackStrategy: .downloadedAVAudioPlayer,
            ttsReconfigureAudioSession: true,
            ttsDeactivateBeforeReconfigure: true,
            ttsActivateAudioSession: false,
            ttsCategory: .playback,
            ttsMode: .spokenAudio,
            ttsAllowBluetoothHFP: false,
            ttsAllowBluetoothA2DP: false,
            ttsDuckOthers: true,
            ttsInterruptSpokenAudio: false,
            avPlayerAutomaticallyWaitsToMinimizeStalling: false,
            ttsPlaybackDelay: .ms1000
        )

        Current.settingsStore.resetCarPlayAssistDebugSettings()

        #expect(Current.settingsStore.carPlayAssistDebugSettings == CarPlayAssistDebugSettings.default)
    }

    @Test func invalidPersistedValuesFallBackToDefaults() {
        defer { Self.removeStoredSettings() }

        let defaults = CarPlayAssistDebugSettings.default
        let prefs = Current.settingsStore.prefs
        prefs.set("not-a-category", forKey: "carPlayAssistAudioCategory")
        prefs.set("not-a-mode", forKey: "carPlayAssistAudioMode")
        prefs.set(12345, forKey: "carPlayAssistPreferredSampleRate")
        prefs.set("not-a-strategy", forKey: "carPlayAssistTTSPlaybackStrategy")
        prefs.set(12345, forKey: "carPlayAssistTTSPlaybackDelay")
        prefs.set(true, forKey: "carPlayAssistDuckOthers")

        let settings = Current.settingsStore.carPlayAssistDebugSettings

        #expect(settings.audioCategory == defaults.audioCategory)
        #expect(settings.audioMode == defaults.audioMode)
        #expect(settings.preferredSampleRate == defaults.preferredSampleRate)
        #expect(settings.ttsPlaybackStrategy == defaults.ttsPlaybackStrategy)
        #expect(settings.ttsPlaybackDelay == defaults.ttsPlaybackDelay)
        #expect(settings.duckOthers)
    }

    @Test func audioSessionMappingsMatchDebugOptions() {
        #expect(CarPlayAssistAudioCategory.playAndRecord.avCategory == AVAudioSession.Category.playAndRecord)
        #expect(CarPlayAssistAudioCategory.playback.avCategory == AVAudioSession.Category.playback)
        #expect(CarPlayAssistAudioCategory.record.avCategory == AVAudioSession.Category.record)
        #expect(CarPlayAssistAudioCategory.playAndRecord.title.isEmpty == false)
        #expect(CarPlayAssistAudioCategory.playback.title.isEmpty == false)
        #expect(CarPlayAssistAudioCategory.record.title.isEmpty == false)

        #expect(CarPlayAssistAudioMode.default.avMode == AVAudioSession.Mode.default)
        #expect(CarPlayAssistAudioMode.voiceChat.avMode == AVAudioSession.Mode.voiceChat)
        #expect(CarPlayAssistAudioMode.voicePrompt.avMode == AVAudioSession.Mode.voicePrompt)
        #expect(CarPlayAssistAudioMode.spokenAudio.avMode == AVAudioSession.Mode.spokenAudio)
        #expect(CarPlayAssistAudioMode.measurement.avMode == AVAudioSession.Mode.measurement)
        #expect(CarPlayAssistAudioMode.default.title.isEmpty == false)
        #expect(CarPlayAssistAudioMode.voiceChat.title.isEmpty == false)
        #expect(CarPlayAssistAudioMode.voicePrompt.title.isEmpty == false)
        #expect(CarPlayAssistAudioMode.spokenAudio.title.isEmpty == false)
        #expect(CarPlayAssistAudioMode.measurement.title.isEmpty == false)
    }

    @Test func displayValuesExposeExpectedUnits() {
        #expect(CarPlayAssistPreferredSampleRate.rate16000.title == "16000 Hz")
        #expect(CarPlayAssistPreferredSampleRate.rate24000.value == 24000)
        #expect(CarPlayAssistPreferredSampleRate.rate44100.value == 44100)
        #expect(CarPlayAssistPreferredSampleRate.rate48000.title == "48000 Hz")

        #expect(CarPlayAssistTTSPlaybackStrategy.avPlayer.title.isEmpty == false)
        #expect(CarPlayAssistTTSPlaybackStrategy.downloadedAVAudioPlayer.title.isEmpty == false)

        #expect(CarPlayAssistPlaybackDelay.none.title.isEmpty == false)
        #expect(CarPlayAssistPlaybackDelay.none.seconds == 0)
        #expect(CarPlayAssistPlaybackDelay.ms100.title == "100 ms")
        #expect(CarPlayAssistPlaybackDelay.ms100.seconds == 0.1)
        #expect(CarPlayAssistPlaybackDelay.ms250.title == "250 ms")
        #expect(CarPlayAssistPlaybackDelay.ms250.seconds == 0.25)
        #expect(CarPlayAssistPlaybackDelay.ms500.title == "500 ms")
        #expect(CarPlayAssistPlaybackDelay.ms500.seconds == 0.5)
        #expect(CarPlayAssistPlaybackDelay.ms1000.title == "1000 ms")
        #expect(CarPlayAssistPlaybackDelay.ms1000.seconds == 1)
    }

    private static let settingsKeys = [
        "carPlayAssistAudioCategory",
        "carPlayAssistAudioMode",
        "carPlayAssistPreferredSampleRate",
        "carPlayAssistAllowBluetoothHFP",
        "carPlayAssistAllowBluetoothA2DP",
        "carPlayAssistDuckOthers",
        "carPlayAssistInterruptSpokenAudio",
        "carPlayAssistPlayRecordingIndicatorTone",
        "carPlayAssistRecorderManagesAudioSession",
        "carPlayAssistTTSPlaybackStrategy",
        "carPlayAssistTTSReconfigureAudioSession",
        "carPlayAssistTTSDeactivateBeforeReconfigure",
        "carPlayAssistTTSActivateAudioSession",
        "carPlayAssistTTSCategory",
        "carPlayAssistTTSMode",
        "carPlayAssistTTSAllowBluetoothHFP",
        "carPlayAssistTTSAllowBluetoothA2DP",
        "carPlayAssistTTSDuckOthers",
        "carPlayAssistTTSInterruptSpokenAudio",
        "carPlayAssistAVPlayerAutomaticallyWaitsToMinimizeStalling",
        "carPlayAssistTTSPlaybackDelay",
    ]

    private static func removeStoredSettings() {
        settingsKeys.forEach { Current.settingsStore.prefs.removeObject(forKey: $0) }
    }
}
