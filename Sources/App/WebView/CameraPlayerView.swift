import Shared
import SwiftUI

/// A camera player view that automatically falls back from WebRTC to HLS
/// when the camera doesn't support WebRTC streaming.
@available(iOS 16.0, *)
struct CameraPlayerView: View {
    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    @State private var playerType: PlayerType = .webRTC

    enum PlayerType {
        case webRTC
        case hls
    }

    init(server: Server, cameraEntityId: String, cameraName: String? = nil) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
    }

    var body: some View {
        Group {
            switch playerType {
            case .webRTC:
                WebRTCVideoPlayerView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    cameraName: cameraName,
                    onWebRTCUnsupported: {
                        fallbackToHLS()
                    }
                )
            case .hls:
                CameraStreamHLSView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    cameraName: cameraName
                )
            }
        }
    }

    private func fallbackToHLS() {
        Current.Log.info("Camera \(cameraEntityId) does not support WebRTC, falling back to HLS")
        withAnimation {
            playerType = .hls
        }
    }
}

#if DEBUG
@available(iOS 16.0, *)
#Preview {
    CameraPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
