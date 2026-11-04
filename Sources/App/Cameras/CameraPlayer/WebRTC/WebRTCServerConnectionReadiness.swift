import Foundation
import HAKit

/// What a server's WebSocket state means for a camera stream that is about to be set up.
enum WebRTCServerConnectionReadiness: Equatable {
    /// Commands sent now will be answered.
    case ready
    /// The connection is on its way back; a command sent now would never be answered.
    case waiting
    /// The connection is idle and nothing is bringing it back, so it needs a nudge.
    case needsConnect
    /// The server refused us; waiting will not help.
    case unusable

    /// Moving between networks leaves the WebSocket looking usable while it is already dead —
    /// HAKit needs the better part of a minute to notice and reconnect. A command sent into that
    /// gap gets no reply and no error, which is what leaves the player waiting on a stream that was
    /// never requested.
    init(state: HAConnectionState) {
        switch state {
        case .ready:
            self = .ready
        case .connecting, .authenticating:
            self = .waiting
        case .disconnected(reason: .disconnected):
            self = .needsConnect
        case .disconnected(reason: .waitingToReconnect):
            self = .waiting
        case .disconnected(reason: .rejected):
            self = .unusable
        }
    }
}
