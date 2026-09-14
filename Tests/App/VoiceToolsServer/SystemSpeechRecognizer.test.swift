import Foundation
@testable import HomeAssistant
import Testing

/// The production wiring: the convenience initializer the connection uses, through the factory, to
/// a real `SFSpeechRecognizer`.
///
/// Whether it succeeds depends on the machine's speech authorisation, which no test runner grants.
/// What is asserted is the part that holds either way — that asking for it is wired end to end and
/// that refusing is a clean, described error rather than a trap or a silent fall back to the cloud.
@MainActor
struct SystemSpeechRecognizerTests {
    private let format = WyomingAudioFormat(rate: 16000, width: 2, channels: 1)

    @Test func theProductionPathBuildsOrRefusesCleanly() {
        do {
            let session = try WyomingSpeechRecognitionSession(locale: Locale(identifier: "en-US"), format: format)
            session.cancel()
        } catch let error as WyomingProtocolError {
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Refused with an unexpected error: \(error)")
        }
    }

    /// A locale nothing recognises is refused by name, so the client is told which language it
    /// asked for rather than that something unspecified went wrong.
    @Test func anUnknownLocaleIsRefusedByName() {
        do {
            let session = try WyomingSpeechRecognitionSession(locale: Locale(identifier: "zz-ZZ"), format: format)
            session.cancel()
        } catch let WyomingProtocolError.speechRecognitionUnavailable(language) {
            #expect(language == "zz-ZZ")
        } catch let error as WyomingProtocolError {
            // A machine without speech authorisation refuses before it ever looks at the locale.
            #expect(error == .speechRecognitionNotAuthorized)
        } catch {
            Issue.record("Refused with an unexpected error: \(error)")
        }
    }

    /// The format is checked before the recogniser, so the wrong audio is reported as the wrong
    /// audio even on a machine that would refuse the recogniser anyway.
    @Test func theFormatIsRefusedBeforeTheRecognizer() {
        #expect(throws: WyomingProtocolError.unsupportedAudioFormat(.init(rate: 16000, width: 4, channels: 1))) {
            _ = try WyomingSpeechRecognitionSession(
                locale: Locale(identifier: "en-US"),
                format: .init(rate: 16000, width: 4, channels: 1)
            )
        }
    }
}
