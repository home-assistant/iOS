import AVKit
import Shared
import SwiftUI

/// A SwiftUI view for playing HLS camera streams.
@available(iOS 16.0, *)
struct CameraHLSPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?

    init(server: Server, cameraEntityId: String, cameraName: String? = nil) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let player {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
            }

            // Overlay controls
            VStack {
                HStack {
                    if let cameraName {
                        Text(cameraName)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
                Spacer()
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                    Text(errorMessage)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            loadStream()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func loadStream() {
        guard let api = Current.api(for: server) else {
            errorMessage = L10n.CameraPlayer.Errors.unableToConnectToServer
            isLoading = false
            return
        }

        Task {
            do {
                let streamURL = try await fetchStreamURL(api: api)
                setupPlayer(with: streamURL)
            } catch {
                await MainActor.run {
                    Current.Log.error("Failed to load HLS stream: \(error.localizedDescription)")
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func fetchStreamURL(api: HomeAssistantAPI) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            api.connection.send(.init(
                type: .rest(.post, "camera_proxy/\(cameraEntityId)"),
                data: ["format": "hls"]
            )).promise.done { data in
                if let hlsPath: String = try? data.decode("hls_path"),
                   let baseURL = api.server.info.connection.activeURL() {
                    let streamURL = baseURL.appendingPathComponent(hlsPath)
                    continuation.resume(returning: streamURL)
                } else {
                    // Fallback to MJPEG proxy stream
                    if let baseURL = api.server.info.connection.activeURL() {
                        let mjpegURL = baseURL.appendingPathComponent("/api/camera_proxy_stream/\(cameraEntityId)")
                        continuation.resume(returning: mjpegURL)
                    } else {
                        continuation.resume(throwing: StreamError.noActiveURL)
                    }
                }
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

    @MainActor
    private func setupPlayer(with url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
        } catch {
            Current.Log.error("Failed to set audio session category: \(error.localizedDescription)")
        }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let avPlayer = AVPlayer(playerItem: playerItem)

        // Observe player status
        Task {
            for await status in playerItem.publisher(for: \.status).values {
                switch status {
                case .readyToPlay:
                    isLoading = false
                    avPlayer.play()
                case .failed:
                    errorMessage = playerItem.error?.localizedDescription ?? L10n.CameraPlayer.Errors.unknown
                    isLoading = false
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        player = avPlayer
    }

    enum StreamError: LocalizedError {
        case noActiveURL

        var errorDescription: String? {
            switch self {
            case .noActiveURL:
                return L10n.CameraPlayer.Errors.unableToConnectToServer
            }
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    CameraHLSPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
