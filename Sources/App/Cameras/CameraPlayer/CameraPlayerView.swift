import GRDB
import Shared
import SwiftUI

/// A camera player view that automatically falls back from WebRTC to HLS to MJPEG
/// when a streaming method is not supported.
@available(iOS 16.0, *)
struct CameraPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?

    @State private var playerType: PlayerType = .webRTC
    @State private var appEntity: HAAppEntity?
    @State private var name: String?
    @State private var controlsVisible = true
    @State private var showLoader = true

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
        ZStack {
            ZStack(alignment: .topLeading) {
                NavigationStack {
                    content
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                if controlsVisible {
                                    CloseButton {
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .modify { view in
                            if #available(iOS 18.0, *) {
                                view.toolbarVisibility(controlsVisible ? .automatic : .hidden, for: .navigationBar)
                            } else {
                                view
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                nameBadge
            }
            if showLoader {
                HAProgressView(style: .extraLarge)
            }
        }
        .onAppear {
            appEntity = HAAppEntity.entity(id: cameraEntityId, serverId: server.identifier.rawValue)
            name = appEntity?.registryTitle ?? appEntity?.name ?? cameraName
        }
        .statusBarHidden(true)
        .modify { view in
            if #available(iOS 16.0, *) {
                view.persistentSystemOverlays(.hidden)
            } else {
                view
            }
        }
    }

    @ViewBuilder
    private var nameBadge: some View {
        if let name, controlsVisible {
            Text(name)
                .font(.headline)
                .padding(.horizontal, DesignSystem.Spaces.two)
                .padding(.vertical, DesignSystem.Spaces.one)
                .modify { view in
                    if #available(iOS 26.0, *) {
                        view
                            .glassEffect(.regular.interactive(), in: .capsule)
                    } else {
                        view
                            .background(.regularMaterial)
                            .clipShape(.capsule)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, DesignSystem.Spaces.two)
                .padding(.top, DesignSystem.Spaces.one)
        }
    }

    private var content: some View {
        Group {
            switch playerType {
            case .webRTC:
                WebRTCVideoPlayerView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    cameraName: cameraName,
                    controlsVisible: $controlsVisible,
                    showLoader: $showLoader,
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
