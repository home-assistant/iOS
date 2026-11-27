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

    /// How long the request may go unanswered before the socket carrying it is treated as dead.
    ///
    /// HAKit queues a command for as long as its socket is not ready and never times it out, so a
    /// socket that silently died, or a reconnect that never completes, would leave the player on its
    /// loader for good. Device logs show this command answered within 50 ms on a working
    /// connection; the same budget `WebRTCViewPlayerViewModel` gives its signaling commands.
    static let unansweredTimeout: TimeInterval = 8

    let frontendStreamTypes: Set<CameraStreamType>
    let twoWayAudio: Bool

    init(frontendStreamTypes: Set<CameraStreamType>, twoWayAudio: Bool = false) {
        self.frontendStreamTypes = frontendStreamTypes
        self.twoWayAudio = twoWayAudio
    }

    /// Stream types this app doesn't know about are dropped rather than failing the whole response,
    /// so a camera that gains a new one still resolves to the types the app can actually play.
    init(data: HAData) {
        let rawTypes: [String] = (try? data.decode("frontend_stream_types")) ?? []
        self.frontendStreamTypes = Set(rawTypes.compactMap(CameraStreamType.init(rawValue:)))
        self.twoWayAudio = (try? data.decode("two_way_audio")) ?? false
    }

    /// Fetches the capabilities for a camera entity.
    ///
    /// Answers `.answered(nil)` — rather than an empty set — when the request fails or the server is
    /// too old to answer it, so the caller keeps the try-everything cascade instead of refusing to
    /// play. Answers `.unanswered` when nothing comes back within `timeout`, which is the socket
    /// being unusable rather than the camera lacking anything.
    static func fetch(
        server: Server,
        cameraEntityId: String,
        timeout: TimeInterval = unansweredTimeout
    ) async -> CameraCapabilitiesFetchOutcome {
        guard let api = Current.api(for: server) else { return .answered(nil) }
        return await withCheckedContinuation { continuation in
            let gate = ResumeGate()
            let request = api.connection.send(.init(
                type: .webSocket(webSocketCommand),
                data: ["entity_id": cameraEntityId]
            )) { result in
                guard gate.claim() else { return }
                switch result {
                case let .success(data):
                    continuation.resume(returning: .answered(CameraCapabilities(data: data)))
                case let .failure(error):
                    Current.Log.error(
                        "Failed to fetch camera capabilities for \(cameraEntityId): \(error.localizedDescription)"
                    )
                    continuation.resume(returning: .answered(nil))
                }
            }
            // On HAKit's callback queue, where the completion above lands too, so the two never race.
            api.connection.callbackQueue.asyncAfter(deadline: .now() + timeout) {
                guard gate.claim() else { return }
                request.cancel()
                Current.Log.error(
                    "Camera capabilities for \(cameraEntityId) went unanswered for \(Int(timeout))s, treating the socket as dead"
                )
                continuation.resume(returning: .unanswered)
            }
        }
    }

    /// Hands the continuation to whichever of the answer and the timeout comes first.
    private final class ResumeGate {
        private let lock = NSLock()
        private var isClaimed = false

        func claim() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !isClaimed else { return false }
            isClaimed = true
            return true
        }
    }
}
