import Foundation

enum WebRTCStreamErrorCode: String, CaseIterable {
    case unsupportedStreamType = "unsupported_stream_type"
    case invalidPayload = "invalid_payload"
    case microphoneDenied = "microphone_denied"
    case serverUnavailable = "server_unavailable"
    case signalingFailed = "signaling_failed"
    case connectionFailed = "connection_failed"
    case timedOut = "timeout"
    case interrupted
}
