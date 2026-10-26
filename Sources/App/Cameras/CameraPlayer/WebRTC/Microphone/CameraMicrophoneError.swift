import Foundation
import Shared

enum CameraMicrophoneError: Error, Equatable {
    case microphoneDenied
    case serverUnavailable
    case signalingFailed(String?)
    case connectionFailed
    case timedOut
    case interrupted

    var code: WebRTCStreamErrorCode {
        switch self {
        case .microphoneDenied: return .microphoneDenied
        case .serverUnavailable: return .serverUnavailable
        case .signalingFailed: return .signalingFailed
        case .connectionFailed: return .connectionFailed
        case .timedOut: return .timedOut
        case .interrupted: return .interrupted
        }
    }

    var message: String {
        switch self {
        case .microphoneDenied: return L10n.CameraMicrophone.Errors.microphoneDenied
        case .serverUnavailable: return L10n.CameraPlayer.Errors.unableToConnectToServer
        case let .signalingFailed(message): return message ?? L10n.CameraMicrophone.Errors.signalingFailed
        case .connectionFailed: return L10n.CameraMicrophone.Errors.connectionFailed
        case .timedOut: return L10n.CameraMicrophone.Errors.timedOut
        case .interrupted: return L10n.CameraMicrophone.Errors.interrupted
        }
    }
}
