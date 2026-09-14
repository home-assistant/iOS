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
}
