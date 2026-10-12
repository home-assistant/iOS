import Foundation

/// One complete WebSocket message, with when its last byte arrived on this device's clock.
struct SendspinWebSocketFrame {
    enum Kind {
        case text
        case binary
    }

    let kind: Kind
    let data: Data
    /// Microseconds on `SendspinClock`, taken as soon as the message is delivered.
    let receivedAt: Int64
}
