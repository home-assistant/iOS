import Foundation
import Shared

enum CameraMicrophoneError: Error, Equatable {
    case microphoneDenied
    case serverUnavailable
    case signalingFailed(String?)
    case connectionFailed
    case timedOut
    case interrupted

    var code: String {
        switch self {
        case .microphoneDenied: return "microphone_denied"
        case .serverUnavailable: return "server_unavailable"
        case .signalingFailed: return "signaling_failed"
        case .connectionFailed: return "connection_failed"
        case .timedOut: return "timeout"
        case .interrupted: return "interrupted"
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
