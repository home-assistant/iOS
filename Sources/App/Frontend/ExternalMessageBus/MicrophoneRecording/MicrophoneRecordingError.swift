import Foundation
import Shared

enum MicrophoneRecordingError: Error, Equatable {
    case microphoneDenied
    case recordingFailed
    case sessionNotFound
    case interrupted

    var code: String {
        switch self {
        case .microphoneDenied: return "microphone_denied"
        case .recordingFailed: return "recording_failed"
        case .sessionNotFound: return "not_found"
        case .interrupted: return "interrupted"
        }
    }

    var message: String {
        switch self {
        case .microphoneDenied: return L10n.MicrophoneRecording.Errors.microphoneDenied
        case .recordingFailed: return L10n.MicrophoneRecording.Errors.recordingFailed
        case .sessionNotFound: return L10n.MicrophoneRecording.Errors.sessionNotFound
        case .interrupted: return L10n.MicrophoneRecording.Errors.interrupted
        }
    }
}
