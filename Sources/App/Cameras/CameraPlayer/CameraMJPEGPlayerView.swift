import Shared
import SwiftUI

/// A SwiftUI view for displaying MJPEG camera streams.
struct CameraMJPEGPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let controlsVisible: Binding<Bool>?

    @State private var isLoading = true
    @State private var errorMessage: String?

    init(
        server: Server,
        cameraEntityId: String,
        cameraName: String? = nil,
        controlsVisible: Binding<Bool>? = nil
    ) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.controlsVisible = controlsVisible
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
        .contentShape(Rectangle())
        .onTapGesture {
            controlsVisible?.wrappedValue.toggle()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - View controller representable wrapper

#if os(macOS)
private struct MJPEGStreamContainerView: NSViewControllerRepresentable {
    let server: Server
    let cameraEntityId: String
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeNSViewController(context: Context) -> MJPEGStreamViewController {
        MJPEGStreamViewController(
            server: server,
            cameraEntityId: cameraEntityId,
            coordinator: context.coordinator
        )
    }

    func updateNSViewController(_ nsViewController: MJPEGStreamViewController, context: Context) {
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
#else
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
#endif

// MARK: - View controller for MJPEG streaming

private class MJPEGStreamViewController: PlatformViewController {
    private let server: Server
    private let cameraEntityId: String
    private weak var coordinator: MJPEGStreamContainerView.Coordinator?

    private var streamer: MJPEGStreamer?
    #if os(macOS)
    private let imageView = NSImageView()
    #else
    private let imageView = UIImageView()
    #endif
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

    #if os(macOS)
    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        view = container
    }
    #endif

    override func viewDidLoad() {
        super.viewDidLoad()

        #if os(macOS)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        // An image view asks for its image's own size; the stream fits the player, not the reverse.
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            imageView.setContentHuggingPriority(.defaultLow, for: orientation)
            imageView.setContentCompressionResistancePriority(.defaultLow, for: orientation)
        }
        #else
        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .black
        #endif
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

        Task { [weak self] in
            guard let self else { return }

            guard let baseURL = await api.server.activeURL() else {
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
    }

    private enum StreamError: LocalizedError {
        case unableToConnect

        var errorDescription: String? {
            L10n.CameraPlayer.Errors.unableToConnectToServer
        }
    }
}

#if DEBUG
#Preview {
    CameraMJPEGPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
