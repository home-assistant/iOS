import Foundation
@testable import HomeAssistant
import Testing

/// The descriptions travel to Home Assistant in an `error` event and end up in its log, so an empty
/// one leaves whoever set the integration up with nothing to go on.
struct WyomingProtocolErrorTests {
    private static let allCases: [WyomingProtocolError] = [
        .connectionClosed,
        .malformedEvent,
        .eventTooLarge,
        .missingEventData("synthesize"),
        .unsupportedAudioFormat(WyomingAudioFormat(rate: 16000, width: 4, channels: 1)),
        .speechRecognitionUnavailable("xx-XX"),
        .speechRecognitionNotAuthorized,
        .noAudioReceived,
        .synthesisFailed,
        .timedOut,
    ]

    @Test func everyFailureDescribesItself() {
        for error in Self.allCases {
            #expect(error.errorDescription?.isEmpty == false, "\(error) has no description")
        }
    }

    @Test func namesTheEventMissingItsData() {
        let description = WyomingProtocolError.missingEventData("synthesize").errorDescription
        #expect(description?.contains("synthesize") == true)
    }

    /// The rate, width and channel count all point at what the client got wrong.
    @Test func spellsOutTheRejectedAudioFormat() {
        let format = WyomingAudioFormat(rate: 8000, width: 4, channels: 2)
        let description = WyomingProtocolError.unsupportedAudioFormat(format).errorDescription

        #expect(description?.contains("8000") == true)
        #expect(description?.contains("32-bit") == true)
        #expect(description?.contains("2 channel") == true)
    }
}
