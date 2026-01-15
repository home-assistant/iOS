import Foundation
import Shared
import UIKit

@available(iOS 16.0, *)
@MainActor
final class CameraMJPEGPlayerViewModel: ObservableObject {
    private let server: Server
    private let cameraEntityId: String

    @Published var isLoading: Bool = true
    @Published var errorMessage: String?
    @Published var uiImage: UIImage?

    private var hasStarted = false
    private var streamer: MJPEGStreamer?

    init(server: Server, cameraEntityId: String) {
        self.server = server
        self.cameraEntityId = cameraEntityId
    }

    func start() {
        // Prevent multiple concurrent starts which can cause multiple NSURLSession delegates
        guard !hasStarted else { return }
        hasStarted = true

        guard let api = Current.api(for: server) else {
            errorMessage = StreamError.unableToConnect.localizedDescription
            isLoading = false
            hasStarted = false
            return
        }

        api.StreamCamera(entityId: cameraEntityId).pipe { [weak self] result in
            switch result {
            case let .fulfilled(imagePath):
                if let url = api.server.info.connection.activeURL()?.appendingPathComponent(imagePath.mjpegPath ?? "") {
                    DispatchQueue.main.async { [weak self] in
                        self?.isLoading = false
                        self?.hasStarted = false
                        self?.startStream(url, api: api)
                    }
                } else {
                    Current.Log.error("Failed to get active URL for server \(api.server.info.name)")
                }
            case let .rejected(error):
                Current.Log.error("Failed to get MJPEG URL: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                    self?.hasStarted = false
                }
            }

            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
                self?.hasStarted = false
            }
        }
    }

    private func startStream(_ url: URL, api: HomeAssistantAPI) {
        // Ensure any previous session is torn down before starting a new one
        streamer?.cancel()
        streamer = nil

        streamer = api.VideoStreamer()
        streamer?.streamImages(fromURL: url) { [weak self] uiImage, error in
            DispatchQueue.main.async {
                guard let self else { return }
                
                if let uiImage {
                    // First frame received, stream has started successfully
                    self.isLoading = false
                    self.uiImage = uiImage
                } else if let error {
                    // Stream error occurred
                    Current.Log.error("MJPEG Stream error: \(error.localizedDescription)")
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.hasStarted = false
                    self.streamer?.cancel()
                    self.streamer = nil
                }
            }
        }
    }

    func stop() {
        streamer?.cancel()
        hasStarted = false
        streamer = nil
    }

    deinit {
        // Ensure URLSession delegate is invalidated
        streamer?.cancel()
        streamer = nil
    }

    private enum StreamError: LocalizedError {
        case unableToConnect

        var errorDescription: String? {
            L10n.CameraPlayer.Errors.unableToConnectToServer
        }
    }
}
