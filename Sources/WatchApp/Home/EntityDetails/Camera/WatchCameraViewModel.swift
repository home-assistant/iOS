// AVFoundation explicitly: watchOS's AVKit is only the SwiftUI player view and doesn't re-export it,
// so `AVPlayer` isn't in scope through `import AVKit` alone the way it is on iOS.
import AVFoundation
import Foundation
import PromiseKit
import Shared
import UIKit

/// Backs the camera screen a camera row opens.
///
/// It resolves the stream the same way the watch's camera notifications do: it asks the server for
/// the entity's stream paths (`stream_camera`) and plays the HLS stream when there is one, falling
/// back to the always-available MJPEG proxy (`/api/camera_proxy_stream`) when the server offers no
/// HLS path, when the request fails, or when the player never gets the stream playing.
final class WatchCameraViewModel: ObservableObject {
    /// What the screen shows right now: an `AVPlayer` fed by HLS, or the latest MJPEG frame.
    enum Stream {
        case hls(AVPlayer)
        case mjpeg(UIImage)
    }

    @Published private(set) var stream: Stream?
    @Published private(set) var isLoading = false
    /// Set when no stream could be started at all — the screen shows it with a retry button.
    @Published private(set) var errorMessage: String?

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private var api: HomeAssistantAPI?
    private var baseURL: URL?
    private var streamer: MJPEGStreamer?
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var hlsTimeout: DispatchWorkItem?
    /// False while no screen is watching, so an answer that arrives after the user left doesn't
    /// start a stream nobody sees.
    private var isActive = false

    /// How long HLS gets to start playing before the screen falls back to MJPEG. A broken stream
    /// reports `.failed`, but one the watch can't play at all just sits in `.unknown` forever, which
    /// would leave the screen spinning on a camera the MJPEG proxy could have shown.
    private static let hlsStartTimeout: TimeInterval = 10

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self.item = item
        self.itemInfo = itemInfo
    }

    deinit {
        hlsTimeout?.cancel()
        statusObservation?.invalidate()
        player?.pause()
        streamer?.cancel()
    }

    /// The name the user configured for the item, falling back to the entity's own name.
    var name: String {
        item.name(info: itemInfo)
    }

    func start() {
        // A screen already showing something — a stream, a spinner or a failure waiting on the
        // retry button — has nothing to start.
        guard stream == nil, !isLoading, errorMessage == nil else { return }
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == item.serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("Server \(item.serverId) not synced to the watch for camera \(item.id)")
            show(message: L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }
        // Synchronous URL evaluation on purpose: on watchOS the last-known network state is always
        // current (same reasoning as `WatchServiceCallSender`).
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            show(message: ServerConnectionError.noActiveURL(server.info.name).localizedDescription)
            return
        }

        self.api = api
        self.baseURL = baseURL
        isActive = true
        isLoading = true
        errorMessage = nil

        api.StreamCamera(entityId: item.id).done { [weak self] response in
            guard let self, isActive else { return }
            if let hlsPath = response.hlsPath {
                startHLS(url: baseURL.appendingPathComponent(hlsPath))
            } else {
                startMJPEG()
            }
        }.catch { [weak self] error in
            guard let self, isActive else { return }
            Current.Log.info("No HLS stream for \(item.id), using MJPEG: \(error)")
            startMJPEG()
        }
    }

    /// Ends the stream and resets the screen, so leaving it doesn't keep the camera (and the
    /// radio) running.
    func stop() {
        isActive = false
        tearDownHLS()
        streamer?.cancel()
        streamer = nil
        stream = nil
        isLoading = false
        errorMessage = nil
    }

    func retry() {
        stop()
        start()
    }

    // MARK: - Private

    private func startHLS(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        // Muted on purpose: watchOS plays audio through a picked output, and prompting for one just
        // to glance at a camera would get in the way of the stream.
        player.isMuted = true

        statusObservation = playerItem.observe(\.status) { [weak self] playerItem, _ in
            // KVO fires on whichever thread changed the status.
            DispatchQueue.main.async { [weak self] in
                guard let self, isActive else { return }
                switch playerItem.status {
                case .readyToPlay:
                    hlsTimeout?.cancel()
                    hlsTimeout = nil
                    isLoading = false
                    player.play()
                case .failed:
                    let reason = playerItem.error?.localizedDescription ?? "unknown"
                    Current.Log.error("HLS stream failed for \(item.id), using MJPEG: \(reason)")
                    fallBackToMJPEG()
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        self.player = player
        stream = .hls(player)
        player.play()

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, isActive, isLoading else { return }
            Current.Log.info("HLS stream for \(item.id) didn't start in time, using MJPEG")
            fallBackToMJPEG()
        }
        hlsTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hlsStartTimeout, execute: timeout)
    }

    private func startMJPEG() {
        guard let api, let baseURL else {
            show(message: L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }
        isLoading = true
        errorMessage = nil

        let videoStreamer = api.VideoStreamer()
        streamer = videoStreamer
        let url = baseURL.appendingPathComponent("api/camera_proxy_stream/\(item.id)", isDirectory: false)
        // The streamer reports every frame — and the end of the stream — on the main queue.
        videoStreamer.streamImages(fromURL: url) { [weak self] image, error in
            // A cancelled stream still reports its end — ignore it once the screen is gone.
            guard let self, isActive else { return }
            if let image {
                isLoading = false
                errorMessage = nil
                stream = .mjpeg(image)
            } else if let error {
                Current.Log.error("MJPEG stream failed for \(item.id): \(error)")
                streamer?.cancel()
                streamer = nil
                show(message: error.localizedDescription)
            }
        }
    }

    private func fallBackToMJPEG() {
        tearDownHLS()
        startMJPEG()
    }

    private func tearDownHLS() {
        hlsTimeout?.cancel()
        hlsTimeout = nil
        statusObservation?.invalidate()
        statusObservation = nil
        player?.pause()
        player = nil
        stream = nil
    }

    private func show(message: String) {
        stream = nil
        isLoading = false
        errorMessage = message
    }
}

#if DEBUG
extension WatchCameraViewModel {
    /// Preview-only state, so the screen renders without a server: a view model that already shows
    /// something doesn't start a stream when the screen appears.
    static func preview(
        name: String,
        stream: Stream? = nil,
        isLoading: Bool = false,
        errorMessage: String? = nil
    ) -> WatchCameraViewModel {
        let viewModel = WatchCameraViewModel(
            item: .init(id: "camera.front_door", serverId: "1", type: .entity),
            itemInfo: .init(id: "1-camera.front_door", name: name, iconName: "mdi:cctv")
        )
        viewModel.stream = stream
        viewModel.isLoading = isLoading
        viewModel.errorMessage = errorMessage
        return viewModel
    }
}
#endif
