import Foundation

/// A player `CameraPlayerView` can show for a camera.
///
/// The order the players are tried in comes from the camera's reported capabilities; see
/// `CameraStreamPlan`.
enum CameraPlayerType: Equatable {
    case webRTC
    case hls
    case mjpeg
}
