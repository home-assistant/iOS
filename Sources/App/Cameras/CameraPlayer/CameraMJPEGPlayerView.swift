import Shared
import SwiftUI
import UIKit

/// A SwiftUI view for displaying MJPEG camera streams.
@available(iOS 16.0, *)
struct CameraMJPEGPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

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

            if errorMessage == nil {
                MJPEGStreamContainerView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage
                )
                .ignoresSafeArea()
            }

            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            if let errorMessage {
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
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - UIViewControllerRepresentable wrapper

@available(iOS 16.0, *)
private struct MJPEGStreamContainerView: UIViewControllerRepresentable {
    let server: Server
    let cameraEntityId: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeUIViewController(context: Context) -> MJPEGStreamViewController {
        MJPEGStreamViewController(
            server: server,
            cameraEntityId: cameraEntityId,
            coordinator: context.coordinator
        )
    }

    func updateUIViewController(_ uiViewController: MJPEGStreamViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, errorMessage: $errorMessage)
    }

    class Coordinator {
        @Binding var isLoading: Bool
        @Binding var errorMessage: String?

        init(isLoading: Binding<Bool>, errorMessage: Binding<String?>) {
            _isLoading = isLoading
            _errorMessage = errorMessage
        }

        func didReceiveFirstFrame() {
            isLoading = false
        }

        func didEncounterError(_ error: Error) {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - UIKit View Controller for MJPEG streaming

@available(iOS 16.0, *)
private class MJPEGStreamViewController: UIViewController {
    private let server: Server
    private let cameraEntityId: String
    private weak var coordinator: MJPEGStreamContainerView.Coordinator?

    private var streamer: MJPEGStreamer?
    private let imageView = UIImageView()
    private var hasReceivedFirstFrame = false

    init(
        server: Server,
        cameraEntityId: String,
        coordinator: MJPEGStreamContainerView.Coordinator
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        streamer?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        startStreaming()
    }

    private func startStreaming() {
        guard let api = Current.api(for: server) else {
            coordinator?.didEncounterError(StreamError.unableToConnect)
            return
        }

        guard let baseURL = api.server.info.connection.activeURL() else {
            coordinator?.didEncounterError(StreamError.unableToConnect)
            return
        }

        let mjpegURL = baseURL.appendingPathComponent("api/camera_proxy_stream/\(cameraEntityId)")

        // Create streamer once and keep it for the lifetime of this view controller
        let videoStreamer = api.VideoStreamer()
        streamer = videoStreamer

        videoStreamer.streamImages(fromURL: mjpegURL) { [weak self] image, error in
            guard let self else { return }

            if let image {
                imageView.image = image
                if !hasReceivedFirstFrame {
                    hasReceivedFirstFrame = true
                    coordinator?.didReceiveFirstFrame()
                }
            } else if let error {
                Current.Log.error("MJPEG stream error: \(error.localizedDescription)")
                coordinator?.didEncounterError(error)
            }
        }
    }

    private enum StreamError: LocalizedError {
        case unableToConnect

        var errorDescription: String? {
            L10n.CameraPlayer.Errors.unableToConnectToServer
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    CameraMJPEGPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
