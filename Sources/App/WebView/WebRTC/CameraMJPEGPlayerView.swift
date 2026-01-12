import Shared
import SwiftUI

/// A SwiftUI view for displaying MJPEG camera streams.
@available(iOS 16.0, *)
struct CameraMJPEGPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentImage: UIImage?
    @State private var streamer: MJPEGStreamer?

    init(server: Server, cameraEntityId: String, cameraName: String? = nil) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
    }

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let currentImage {
                Image(uiImage: currentImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
            startStream()
        }
        .onDisappear {
            stopStream()
        }
    }

    private func startStream() {
        guard let api = Current.api(for: server) else {
            errorMessage = L10n.CameraPlayer.Errors.unableToConnectToServer
            isLoading = false
            return
        }

        guard let baseURL = api.server.info.connection.activeURL() else {
            errorMessage = L10n.CameraPlayer.Errors.unableToConnectToServer
            isLoading = false
            return
        }

        // Use the camera proxy stream endpoint for MJPEG
        let mjpegURL = baseURL.appendingPathComponent("api/camera_proxy_stream/\(cameraEntityId)")

        // Use the API's VideoStreamer which handles authentication automatically
        let videoStreamer = api.VideoStreamer()
        self.streamer = videoStreamer

        videoStreamer.streamImages(fromURL: mjpegURL) { [self] image, error in
            if let image {
                currentImage = image
                isLoading = false
            } else if let error {
                Current.Log.error("MJPEG stream error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func stopStream() {
        streamer?.cancel()
        streamer = nil
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
