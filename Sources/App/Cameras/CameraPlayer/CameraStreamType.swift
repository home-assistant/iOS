import Foundation

/// A stream type the Home Assistant frontend knows how to play for a camera entity.
///
/// Mirrors `StreamType` in core's `camera` component: a camera reports the set it supports through
/// `frontend_stream_types` on the `camera/capabilities` websocket command, and the frontend picks
/// its player from that set rather than probing each one.
enum CameraStreamType: String {
    case hls
    case webRTC = "web_rtc"
}
