import AVKit
import Shared
import SwiftUI

/// A SwiftUI view for playing HLS camera streams.
@available(iOS 16.0, *)
struct CameraStreamHLSView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let onHLSUnsupported: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasCalledFallback = false

    init(
        server: Server,
        cameraEntityId: String,
        cameraName: String? = nil,
        onHLSUnsupported: (() -> Void)? = nil
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.onHLSUnsupported = onHLSUnsupported
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

            if let errorMessage, onHLSUnsupported == nil {
                // Only show error if there's no fallback available
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
            handleError(L10n.CameraPlayer.Errors.unableToConnectToServer)
            return
        }

        Task {
            do {
                let streamURL = try await fetchStreamURL(api: api)
                setupPlayer(with: streamURL)
            } catch {
                await MainActor.run {
                    Current.Log.error("Failed to load HLS stream: \(error.localizedDescription)")
                    handleError(error.localizedDescription)
                }
            }
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

    private func fetchStreamURL(api: HomeAssistantAPI) async throws -> URL {
        let response = api.StreamCamera(entityId: cameraEntityId).value

        if let hlsPath = response?.hlsPath,
           let baseURL = api.server.info.connection.activeURL() {
            return baseURL.appendingPathComponent(hlsPath)
        } else {
            throw StreamError.noHLSAvailable
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
                    let errorMsg = playerItem.error?.localizedDescription ?? L10n.CameraPlayer.Errors.unknown
                    handleError(errorMsg)
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
@available(iOS 16.0, *)
#Preview {
    CameraStreamHLSView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
