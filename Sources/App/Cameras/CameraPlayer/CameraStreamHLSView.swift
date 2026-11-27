import AVKit
import Shared
import SwiftUI

/// A SwiftUI view for playing HLS camera streams.
struct CameraStreamHLSView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let onHLSUnsupported: (() -> Void)?
    private let onVideoStarted: (() -> Void)?
    private let controlsVisible: Binding<Bool>?
    private let isMuted: Bool

    @State private var player: AVPlayer?
    /// The asset does not retain its resource loader delegate, so hold it for as long as the player
    /// lives or the stream stops mid-load on a server that needs a client certificate.
    @State private var assetLoader: CameraHLSAssetLoader?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasCalledFallback = false

    init(
        server: Server,
        cameraEntityId: String,
        cameraName: String? = nil,
        controlsVisible: Binding<Bool>? = nil,
        isMuted: Bool = false,
        onHLSUnsupported: (() -> Void)? = nil,
        onVideoStarted: (() -> Void)? = nil
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.controlsVisible = controlsVisible
        self.isMuted = isMuted
        self.onHLSUnsupported = onHLSUnsupported
        self.onVideoStarted = onVideoStarted
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            }

            if isLoading {
                CameraStreamLoadingView()
            }

            if let errorMessage, onHLSUnsupported == nil {
                // Only show error if there's no fallback available
                VStack(spacing: 16) {
                    Image(systemSymbol: .exclamationmarkTriangle)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            controlsVisible?.wrappedValue.toggle()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { await loadStream() }
        .onChange(of: isMuted) { _ in applyMute(to: player) }
        .onDisappear {
            player?.pause()
            player = nil
            assetLoader = nil
        }
    }

    @MainActor
    private func loadStream() async {
        guard let api = Current.api(for: server) else {
            handleError(L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }

        do {
            let streamURL = try await fetchStreamURL(api: api)
            guard !Task.isCancelled else { return }
            await playStream(at: streamURL, api: api)
        } catch {
            guard !Task.isCancelled else { return }
            Current.Log.error("Failed to load HLS stream: \(error.localizedDescription)")
            handleError(error.localizedDescription)
        }
    }

    private func handleError(_ message: String) {
        if let onHLSUnsupported, !hasCalledFallback {
            hasCalledFallback = true
            onHLSUnsupported()
        } else {
            errorMessage = message
            isLoading = false
        }
    }

    /// Asks the server to start an HLS stream and resolves the playlist URL for it.
    ///
    /// `stream_camera` runs the same `camera.async_request_stream(..., "hls")` the frontend reaches
    /// through `camera/stream`, so a camera the frontend can play over HLS answers here too — but
    /// only once the request has actually completed, which is why this awaits the promise instead
    /// of reading whatever value it happens to hold.
    private func fetchStreamURL(api: HomeAssistantAPI) async throws -> URL {
        let response = try await api.StreamCamera(entityId: cameraEntityId).asyncValue()

        guard let hlsPath = response.hlsPath else {
            throw StreamError.noHLSAvailable
        }
        guard let baseURL = await api.server.activeURL() else {
            throw StreamError.noActiveURL
        }
        return Self.playlistURL(baseURL: baseURL, hlsPath: hlsPath)
    }

    /// Resolves the playlist against the server's URL. `hls_path` comes back server-absolute, so
    /// appending it with its leading slash intact leaves a double slash in the URL and swallows the
    /// base path of a server installed under a subpath.
    static func playlistURL(baseURL: URL, hlsPath: String) -> URL {
        let relativePath = hlsPath.hasPrefix("/") ? String(hlsPath.dropFirst()) : hlsPath
        return baseURL.appendingPathComponent(relativePath)
    }

    /// Non-private for tests.
    @MainActor
    func applyMute(to avPlayer: AVPlayer?) {
        avPlayer?.isMuted = isMuted
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playback,
                mode: isMuted ? .moviePlayback : .default,
                options: isMuted ? .mixWithOthers : []
            )
        } catch {
            Current.Log.error("Failed to set audio session category: \(error.localizedDescription)")
        }
    }

    /// Non-private for tests.
    @MainActor
    func statusChanged(to status: AVPlayerItem.Status, of avPlayer: AVPlayer) {
        if status == .readyToPlay {
            isLoading = false
            avPlayer.play()
            onVideoStarted?()
        } else if status == .failed {
            handleError(avPlayer.currentItem?.error?.localizedDescription ?? L10n.CameraPlayer.Errors.unknown)
        }
    }

    @MainActor
    private func playStream(at url: URL, api: HomeAssistantAPI) async {
        // A server behind a client certificate, or reached with a security exception, needs its
        // requests to go through the app's own session; AVFoundation cannot present either itself.
        let (asset, loader) = CameraHLSAssetLoader.asset(for: url, api: api)
        assetLoader = loader
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)
        applyMute(to: avPlayer)
        player = avPlayer

        for await status in playerItem.publisher(for: \.status).values {
            statusChanged(to: status, of: avPlayer)
        }
    }

    enum StreamError: LocalizedError {
        case noActiveURL
        case noHLSAvailable

        var errorDescription: String? {
            switch self {
            case .noActiveURL:
                return L10n.CameraPlayer.Errors.unableToConnectToServer
            case .noHLSAvailable:
                return L10n.CameraPlayer.Errors.noStreamAvailable
            }
        }
    }
}

#if DEBUG
#Preview {
    CameraStreamHLSView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
