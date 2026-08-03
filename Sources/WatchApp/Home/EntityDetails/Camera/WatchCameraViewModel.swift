// AVFoundation explicitly: watchOS's AVKit is only the SwiftUI player view and doesn't re-export it,
// so `AVPlayer` isn't in scope through `import AVKit` alone the way it is on iOS.
import AVFoundation
import Foundation
import PromiseKit
import Shared
import UIKit

/// Backs the camera screen a camera row opens.
///
/// MJPEG first, always: the proxy (`/api/camera_proxy_stream`) is what the watch plays best — it
/// starts on the first frame, needs no round-trip to ask the server what it can stream, and it
/// authenticates like the rest of the app, so mTLS and self-signed servers work. HLS is only the
/// last resort, for cameras that stream but produce no image at all (many doorbells), and even then
/// only for servers AVFoundation can reach on its own (see `canPlayHLS(on:)`).
final class WatchCameraViewModel: ObservableObject {
    /// What the screen shows right now: the latest MJPEG frame, or an `AVPlayer` fed by HLS.
    enum Stream {
        case mjpeg(UIImage)
        case hls(AVPlayer)
    }

    /// How the camera is being watched. Protocol names on purpose — they're what the picker shows,
    /// and what a user comparing the two would look for.
    enum Mode: String, Identifiable, CaseIterable {
        case mjpeg
        case hls

        var id: String { rawValue }

        var title: String {
            rawValue.uppercased()
        }
    }

    @Published private(set) var stream: Stream?
    @Published private(set) var isLoading = false
    /// Set when no stream could be started at all — the screen shows it with a retry button.
    @Published private(set) var errorMessage: String?
    /// Why the HLS last resort didn't play either, shown under the failure above so the screen
    /// reports both stages instead of only the one that happened to fail last.
    @Published private(set) var errorDetail: String?
    /// Which stream is playing. MJPEG until the camera proves it can't, or until the user picks
    /// otherwise from the mode picker.
    @Published private(set) var mode: Mode = .mjpeg
    /// True once the proxy has actually delivered a frame — only then is MJPEG a mode the user can
    /// come back to.
    @Published private(set) var isMJPEGAvailable = false
    /// True once the server has answered with an HLS path this watch could play.
    @Published private(set) var isHLSAvailable = false

    let item: MagicItem
    let itemInfo: MagicItem.Info

    /// The modes the user can choose between; the picker only appears when there's more than one.
    var availableModes: [Mode] {
        Mode.allCases.filter { mode in
            switch mode {
            case .mjpeg: return isMJPEGAvailable
            case .hls: return isHLSAvailable
            }
        }
    }

    private var server: Server?
    private var api: HomeAssistantAPI?
    private var baseURL: URL?
    private var streamer: MJPEGStreamer?
    private var player: AVPlayer?
    private var statusObservation: NSKeyValueObservation?
    private var hlsTimeout: DispatchWorkItem?
    /// The path the server last reported for this camera's HLS stream, so switching modes doesn't
    /// ask again.
    private var hlsPath: String?
    /// Kept so the failure screen can name both stages, whichever one ends the attempt.
    private var mjpegFailureReason: String?
    private var hlsFailureReason: String?
    /// False while no screen is watching, so an answer that arrives after the user left doesn't
    /// start a stream nobody sees.
    private var isActive = false

    /// How long HLS gets to start playing before the screen gives up on it. A broken stream reports
    /// `.failed`, but one the watch can't play at all just sits in `.unknown` forever, which would
    /// leave the screen spinning with nothing left to try.
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
            showFailure(message: L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }
        // Synchronous URL evaluation on purpose: on watchOS the last-known network state is always
        // current (same reasoning as `WatchServiceCallSender`).
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            showFailure(message: ServerConnectionError.noActiveURL(server.info.name).localizedDescription)
            return
        }

        self.server = server
        self.api = api
        self.baseURL = baseURL
        isActive = true
        mjpegFailureReason = nil
        hlsFailureReason = nil
        errorMessage = nil
        errorDetail = nil

        startMJPEG()
        // Asked for alongside the stream, not before it: the answer only decides whether the mode
        // picker appears, so waiting for it would delay the first frame for nothing.
        probeHLSAvailability()
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
        errorDetail = nil
        mode = .mjpeg
        isMJPEGAvailable = false
        isHLSAvailable = false
        hlsPath = nil
    }

    func retry() {
        stop()
        start()
    }

    /// Switches which stream the screen plays. Only reachable from the picker, so both modes are
    /// known to work — the one being left is torn down before the other starts.
    func select(mode newMode: Mode) {
        guard newMode != mode, isActive else { return }
        mode = newMode
        errorMessage = nil
        errorDetail = nil

        switch newMode {
        case .mjpeg:
            tearDownHLS()
            startMJPEG()
        case .hls:
            streamer?.cancel()
            streamer = nil
            stream = nil
            startHLSFromKnownPath()
        }
    }

    // MARK: - MJPEG

    private func startMJPEG() {
        guard let api, let baseURL else {
            showFailure(message: L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }
        isLoading = true

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
                errorDetail = nil
                isMJPEGAvailable = true
                stream = .mjpeg(image)
            } else if let error {
                streamer?.cancel()
                streamer = nil
                mjpegFailureReason = error.localizedDescription
                report(stage: "MJPEG", reason: error.localizedDescription)
                // The proxy serves no image for a camera that only streams — HLS is the last thing
                // left to try.
                fallBackToHLS()
            }
        }
    }

    // MARK: - HLS

    /// Whether the player can reach this server at all.
    ///
    /// AVFoundation fetches the playlist and segments itself: it never asks the app to answer the
    /// client certificate challenge, and it doesn't know about the self-signed certificates the
    /// user trusted here. iOS works around that by loading the asset through the app's own session
    /// (`CameraStreamHLSViewController`), which watchOS can't do — `AVAssetResourceLoader` doesn't
    /// exist there.
    private func canPlayHLS(on server: Server) -> Bool {
        let connection = server.info.connection
        return connection.clientCertificate == nil && !connection.securityExceptions.hasExceptions
    }

    /// Asks the server what it can stream, without touching the screen: a camera whose MJPEG works
    /// keeps playing, and the answer only turns the mode picker on.
    private func probeHLSAvailability() {
        guard let server, canPlayHLS(on: server), let api else { return }
        api.StreamCamera(entityId: item.id).done { [weak self] response in
            guard let self, isActive, let path = response.hlsPath else { return }
            hlsPath = path
            isHLSAvailable = true
        }.catch { [weak self] error in
            Current.Log.info("No HLS stream for \(self?.item.id ?? ""): \(error.localizedDescription)")
        }
    }

    private func fallBackToHLS() {
        stream = nil
        mode = .hls
        guard let server, canPlayHLS(on: server) else {
            recordHLSFailure(L10n.Watch.Camera.Error.hlsCertificates)
            showFailure()
            return
        }
        startHLSFromKnownPath()
    }

    /// Plays the HLS stream, asking the server for its path first when the availability probe
    /// hasn't answered yet.
    private func startHLSFromKnownPath() {
        guard let api, let baseURL else {
            showFailure(message: L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }
        isLoading = true

        if let hlsPath {
            startHLS(url: baseURL.appendingPathComponent(hlsPath))
            return
        }

        api.StreamCamera(entityId: item.id).done { [weak self] response in
            guard let self, isActive else { return }
            guard let path = response.hlsPath else {
                handleHLSFailure(L10n.CameraPlayer.Errors.noStreamAvailable)
                return
            }
            hlsPath = path
            isHLSAvailable = true
            startHLS(url: baseURL.appendingPathComponent(path))
        }.catch { [weak self] error in
            guard let self, isActive else { return }
            handleHLSFailure(error.localizedDescription)
        }
    }

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
                    errorMessage = nil
                    errorDetail = nil
                    player.play()
                case .failed:
                    handleHLSFailure(playerItem.error?.localizedDescription ?? "unknown")
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
            handleHLSFailure("didn't start playing within \(Int(Self.hlsStartTimeout))s")
        }
        hlsTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hlsStartTimeout, execute: timeout)
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

    // MARK: - Failure reporting

    /// HLS giving up returns the screen to MJPEG when the proxy has already proven it works — the
    /// user picked a mode from the picker, not a dead end. Only a camera with no working MJPEG at
    /// all (the case that sent us to HLS in the first place) ends on the failure screen.
    private func handleHLSFailure(_ reason: String) {
        recordHLSFailure(reason)
        tearDownHLS()
        // Don't keep offering a mode that just failed.
        isHLSAvailable = false
        guard isMJPEGAvailable else {
            showFailure()
            return
        }
        mode = .mjpeg
        startMJPEG()
    }

    private func recordHLSFailure(_ reason: String) {
        hlsFailureReason = reason
        report(stage: "HLS", reason: reason)
    }

    /// Both stages land in the watch's client events (Settings → Troubleshooting), so a stream that
    /// fails on device can be diagnosed without a debugger attached.
    private func report(stage: String, reason: String) {
        Current.Log.error("\(stage) camera stream failed for \(item.id): \(reason)")
        Current.clientEventStore.addEvent(.init(
            text: "Watch camera \(item.id) failed to stream over \(stage): \(reason)",
            type: .networkRequest,
            payload: ["camera": item.id, "server": item.serverId, "stage": stage, "reason": reason]
        ))
    }

    /// Shows the MJPEG failure — the attempt that matters on the watch — with the HLS one underneath
    /// when the last resort was tried too.
    private func showFailure(message: String? = nil) {
        stream = nil
        isLoading = false
        errorMessage = message ?? mjpegFailureReason ?? L10n.CameraPlayer.Errors.noStreamAvailable
        errorDetail = hlsFailureReason.map { L10n.Watch.Camera.Error.hls($0) }
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
        errorMessage: String? = nil,
        errorDetail: String? = nil,
        isMJPEGAvailable: Bool = false,
        isHLSAvailable: Bool = false
    ) -> WatchCameraViewModel {
        let viewModel = WatchCameraViewModel(
            item: .init(id: "camera.front_door", serverId: "1", type: .entity),
            itemInfo: .init(id: "1-camera.front_door", name: name, iconName: "mdi:cctv")
        )
        viewModel.stream = stream
        viewModel.isLoading = isLoading
        viewModel.errorMessage = errorMessage
        viewModel.errorDetail = errorDetail
        viewModel.isMJPEGAvailable = isMJPEGAvailable
        viewModel.isHLSAvailable = isHLSAvailable
        return viewModel
    }
}
#endif
