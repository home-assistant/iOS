import Foundation

/// Failures raised while reading a Wyoming client's events or answering them.
///
/// The descriptions travel to Home Assistant in an `error` event and end up in its log, so they are
/// deliberately plain English rather than localized: the reader is whoever set the integration up,
/// looking at a server log, not the person holding the phone.
enum WyomingProtocolError: Error, LocalizedError, Equatable {
    case connectionClosed
    case malformedEvent
    case eventTooLarge
    case missingEventData(String)
    case unsupportedAudioFormat(WyomingAudioFormat)
    case speechRecognitionUnavailable(String)
    case speechRecognitionNotAuthorized
    case noAudioReceived
    case synthesisFailed
    case timedOut

    var errorDescription: String? {
        switch self {
        case .connectionClosed:
            return "The connection was closed"
        case .malformedEvent:
            return "Received an event that is not valid Wyoming JSON"
        case .eventTooLarge:
            return "Received an event larger than this server accepts"
        case let .missingEventData(type):
            return "The \(type) event arrived without a data section"
        case let .unsupportedAudioFormat(format):
            return "Unsupported audio format: \(format.rate) Hz, \(format.width * 8)-bit, " +
                "\(format.channels) channel(s). Send 16-bit PCM."
        case let .speechRecognitionUnavailable(language):
            return "On-device speech recognition is not available for \(language) on this device"
        case .speechRecognitionNotAuthorized:
            return "Speech recognition permission has not been granted to the Home Assistant app"
        case .noAudioReceived:
            return "No audio was received before the stream ended"
        case .synthesisFailed:
            return "Speech synthesis produced no audio"
        case .timedOut:
            return "Timed out waiting for the device to finish"
        }
    }
}
