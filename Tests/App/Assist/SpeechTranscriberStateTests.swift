import AVFoundation
@testable import HomeAssistant
import Speech
import Testing

/// The app's transcriber, not the Speech framework's type of the same name.
@available(iOS 17.0, *)
private typealias Transcriber = HomeAssistant.SpeechTranscriber

/// The parts of on-device speech that don't need a microphone or a speaker: the transcriber's
/// errors, locales, authorization mapping and stopping while idle, and the synthesizer's voices and
/// finish callback.
@MainActor
struct SpeechTranscriberStateTests {
    @Test func everyTranscriberErrorDescribesItself() {
        guard #available(iOS 17.0, *) else { return }
        let errors: [Transcriber.TranscriberError] = [
            .microphoneNotAuthorized,
            .speechRecognitionNotAuthorized,
            .notAvailable,
            .audioEngineError,
            .recognizerError("Recognizer went away"),
        ]
        let descriptions = errors.compactMap(\.errorDescription)
        #expect(descriptions.count == errors.count)
        #expect(Set(descriptions).count == errors.count)
        #expect(descriptions.last == "Recognizer went away")
    }

    @Test func theLocaleFollowsWhatTheTranscriberWasMadeWith() {
        guard #available(iOS 17.0, *) else { return }
        let english = Transcriber(localeIdentifier: "en-US")
        #expect(english.currentLocale == "en-US")

        english.updateLocale(Locale(identifier: "pt-BR"))
        #expect(english.currentLocale == "pt-BR")

        english.updateLocale(nil)
        #expect(english.currentLocale != "unknown")

        #expect(Transcriber(locale: Locale(identifier: "de-DE")).currentLocale == "de-DE")
        #expect(Transcriber().currentLocale != "unknown")
    }

    @Test func aLocaleWithoutARecognizerCannotListen() async {
        guard #available(iOS 17.0, *) else { return }
        let transcriber = Transcriber(localeIdentifier: "zz-ZZ")
        #expect(transcriber.currentLocale == "unknown")

        await #expect(throws: Transcriber.TranscriberError.self) {
            try await transcriber.startListening()
        }
        #expect(!transcriber.isListening)
    }

    @Test func stoppingWhileIdleReportsNothing() {
        guard #available(iOS 17.0, *) else { return }
        let transcriber = Transcriber(localeIdentifier: "en-US")
        transcriber.managesAudioSession = false
        var changes: [Bool] = []
        transcriber.onListeningStateChange = { changes.append($0) }

        transcriber.stopListening()

        #expect(changes.isEmpty)
        #expect(!transcriber.isListening)
        #expect(transcriber.transcript.isEmpty)
        #expect(transcriber.errorMessage == nil)
    }

    @Test func theAuthorizationStatusMapsTheSystemOne() {
        guard #available(iOS 17.0, *) else { return }
        let expected: Transcriber.AuthorizationStatus = switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        default: .notDetermined
        }
        #expect(Transcriber.authorizationStatus == expected)
    }

    @Test func theSynthesizerReportsWhenItFinishes() {
        guard #available(iOS 17.0, *) else { return }
        let synthesizer = SpeechSynthesizer()
        var finished = 0
        synthesizer.onFinished = { finished += 1 }
        synthesizer.managesAudioSession = false

        synthesizer.speechSynthesizer(AVSpeechSynthesizer(), didFinish: AVSpeechUtterance(string: "Done"))
        synthesizer.stop()

        #expect(finished == 1)
        #expect(!synthesizer.managesAudioSession)
    }

    @Test func aSynthesizerCanBeMadeForAnyVoiceIdentifier() {
        guard #available(iOS 17.0, *) else { return }
        let voice = AVSpeechSynthesisVoice.speechVoices().first?.identifier ?? "missing.voice"
        let synthesizer = SpeechSynthesizer(voiceIdentifier: voice)
        synthesizer.stop()
        #expect(synthesizer.onFinished == nil)
    }
}
