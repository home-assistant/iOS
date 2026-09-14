import Foundation
import HAKit
import Shared

/// The stream types a camera entity supports, as reported by the `camera/capabilities` websocket
/// command.
///
/// This is the first thing the frontend's `ha-camera-stream` asks the server for. Core computes the
/// set from the entity itself: a camera without `CameraEntityFeature.STREAM` reports nothing (the
/// frontend then falls back to the MJPEG proxy), a camera backed by the `stream` component reports
/// `hls`, one served by a WebRTC provider such as go2rtc reports both, and one with a native WebRTC
/// implementation — Nest, for instance — reports only `web_rtc` and has no HLS stream at all.
///
/// Asking for this up front is what lets the app play the same cameras the frontend does: without
/// it every camera starts with a WebRTC offer that core rejects (`require_webrtc_support`), and the
/// player only discovers the right stream type by failing its way down the cascade.
struct CameraCapabilities: Equatable {
    /// The websocket command that returns these capabilities, added to core in 2024.11.
    static let webSocketCommand = "camera/capabilities"

    let frontendStreamTypes: Set<CameraStreamType>

    init(frontendStreamTypes: Set<CameraStreamType>) {
        self.frontendStreamTypes = frontendStreamTypes
    }

    /// Stream types this app doesn't know about are dropped rather than failing the whole response,
    /// so a camera that gains a new one still resolves to the types the app can actually play.
    init(data: HAData) {
        let rawTypes: [String] = (try? data.decode("frontend_stream_types")) ?? []
        self.frontendStreamTypes = Set(rawTypes.compactMap(CameraStreamType.init(rawValue:)))
    }

    /// Fetches the capabilities for a camera entity.
    ///
    /// Returns `nil` — rather than an empty set — when the request fails or the server is too old
    /// to answer it, so the caller keeps the try-everything cascade instead of refusing to play.
    static func fetch(server: Server, cameraEntityId: String) async -> CameraCapabilities? {
        guard let api = Current.api(for: server) else { return nil }
        return await withCheckedContinuation { continuation in
            api.connection.send(.init(
                type: .webSocket(webSocketCommand),
                data: ["entity_id": cameraEntityId]
            )) { result in
                switch result {
                case let .success(data):
                    continuation.resume(returning: CameraCapabilities(data: data))
                case let .failure(error):
                    Current.Log.error(
                        "Failed to fetch camera capabilities for \(cameraEntityId): \(error.localizedDescription)"
                    )
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
