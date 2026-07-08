import GRDB
import SFSafeSymbols
import Shared
import SwiftUI

/// A camera player view that automatically falls back from WebRTC to HLS to MJPEG
/// when a streaming method is not supported.
struct CameraPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    private let server: Server
    private let cameraEntityId: String
    private let cameraName: String?
    private let showsDebugOverlay: Bool

    @State private var playerType: PlayerType = .webRTC
    @State private var appEntity: HAAppEntity?
    @State private var name: String?
    @State private var controlsVisible = true
    @State private var showLoader = true

    enum PlayerType {
        case webRTC
        case hls
        case mjpeg

        var debugTitle: String {
            switch self {
            case .webRTC: return "WebRTC"
            case .hls: return "HLS"
            case .mjpeg: return "MJPEG"
            }
        }
    }

    init(server: Server, cameraEntityId: String, cameraName: String? = nil, showsDebugOverlay: Bool = false) {
        self.server = server
        self.cameraEntityId = cameraEntityId
        self.cameraName = cameraName
        self.showsDebugOverlay = showsDebugOverlay
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .topLeading) {
                NavigationStack {
                    content
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                if controlsVisible {
                                    HStack(spacing: DesignSystem.Spaces.one) {
                                        Button {
                                            openMoreInfo()
                                        } label: {
                                            Image(systemSymbol: .safari)
                                        }
                                    }
                                }
                            }

                            ToolbarItem(placement: .primaryAction) {
                                CloseButton {
                                    dismiss()
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
        .overlay(alignment: .bottomLeading) {
            playerTypeBadge
        }
        .onAppear {
            appEntity = HAAppEntity.entity(id: cameraEntityId, serverId: server.identifier.rawValue)
            name = appEntity?.name ?? cameraName
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    @ViewBuilder
    private var playerTypeBadge: some View {
        if showsDebugOverlay {
            Text(verbatim: playerType.debugTitle)
                .font(.caption.monospaced())
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.vertical, DesignSystem.Spaces.half)
                .background(.regularMaterial)
                .clipShape(.capsule)
                .padding(.leading, DesignSystem.Spaces.two)
                .padding(.bottom, DesignSystem.Spaces.two)
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
                .padding(.top, DesignSystem.Spaces.half)
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

    private func openMoreInfo() {
        if let url = AppConstants
            .openEntityDeeplinkURL(entityId: cameraEntityId, serverId: server.identifier.rawValue) {
            URLOpener.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

#if DEBUG
#Preview {
    CameraPlayerView(
        server: ServerFixture.standard,
        cameraEntityId: "camera.front_door",
        cameraName: "Front Door"
    )
}
#endif
