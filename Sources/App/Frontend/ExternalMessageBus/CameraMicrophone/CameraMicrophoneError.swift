import Foundation

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
        case .microphoneDenied: return "Microphone access was denied"
        case .serverUnavailable: return "Home Assistant is not reachable"
        case let .signalingFailed(message): return message ?? "WebRTC signaling failed"
        case .connectionFailed: return "The WebRTC connection failed"
        case .timedOut: return "The WebRTC connection timed out"
        case .interrupted: return "The microphone session was interrupted"
        }
    }
}
