import Shared
import SwiftUI

/// A camera player view that automatically falls back from WebRTC to HLS to MJPEG
/// when a streaming method is not supported.
@available(iOS 16.0, *)
struct CameraPlayerView: View {
    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    @State private var playerType: PlayerType = .webRTC

    enum PlayerType {
        case webRTC
        case hls
        case mjpeg
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
                    cameraName: cameraName,
                    onHLSUnsupported: {
                        fallbackToMJPEG()
                    }
                )
            case .mjpeg:
                CameraMJPEGPlayerView(
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

    private func fallbackToMJPEG() {
        Current.Log.info("Camera \(cameraEntityId) does not support HLS, falling back to MJPEG")
        withAnimation {
            playerType = .mjpeg
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
