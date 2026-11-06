import Foundation

/// Decides which players to try for a camera, and in what order.
///
/// The frontend's `ha-camera-stream` picks its player from `frontend_stream_types` instead of
/// probing: no stream type means the MJPEG proxy, `hls` alone means the HLS player, and WebRTC is
/// preferred whenever the camera offers it. This mirrors that choice.
///
/// The app keeps a cascade after that first choice, where the browser instead mounts both players
/// at once and hides the one that loses. The outcome is the same — a stream that negotiates but
/// never delivers a frame gives way to the next one — but the app gets there one player at a time.
enum CameraStreamPlan {
    /// The players to try, most preferred first. Always ends in `.mjpeg`, which needs no stream
    /// support at all and so is the last thing that can still show a picture.
    static func players(for capabilities: CameraCapabilities?) -> [CameraPlayerType] {
        guard let capabilities else {
            // No capabilities to go on (the request failed, or the server predates the command):
            // try everything, which is what the player did before it asked.
            return [.webRTC, .hls, .mjpeg]
        }

        var players: [CameraPlayerType] = []
        if capabilities.frontendStreamTypes.contains(.webRTC) {
            players.append(.webRTC)
        }
        if capabilities.frontendStreamTypes.contains(.hls) {
            players.append(.hls)
        }
        players.append(.mjpeg)
        return players
    }

    /// The players to try given how the capabilities request went.
    ///
    /// A request the server never answered means its WebSocket is not carrying commands, and WebRTC
    /// signaling runs over that same socket: starting there would only spend the connection gate's
    /// wait before cascading. HLS (`stream_camera` over the webhook) and the MJPEG proxy go over
    /// HTTP and play while the socket is still coming back.
    static func players(for outcome: CameraCapabilitiesFetchOutcome) -> [CameraPlayerType] {
        switch outcome {
        case let .answered(capabilities):
            return players(for: capabilities)
        case .unanswered:
            return [.hls, .mjpeg]
        }
    }
}
