import GRDB
import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI

/// A camera player view that automatically falls back from WebRTC to HLS to MJPEG
/// when a streaming method is not supported.
struct CameraPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    private let server: Server
    private let cameraName: String?

    @State private var cameraEntityId: String
    @State private var playerType: PlayerType = .webRTC
    @State private var appEntity: HAAppEntity?
    @State private var name: String?
    @State private var subtitle: String?
    @State private var cameras: [HAAppEntity] = []
    /// Precomputed context subtitle per camera entity id, resolved once when the list is loaded so the
    /// picker rows don't hit the database on every render.
    @State private var cameraSubtitles: [String: String] = [:]
    /// Snapshot thumbnail per camera entity id, fetched lazily so the picker can show a live still with an
    /// SF Symbol placeholder until it arrives.
    @State private var cameraSnapshots: [String: UIImage] = [:]
    @State private var controlsVisible = true
    @State private var showLoader = true

    private let maxTitleTextWidth: CGFloat = 100

    enum PlayerType {
        case webRTC
        case hls
        case mjpeg
    }

    init(server: Server, cameraEntityId: String, cameraName: String? = nil) {
        self.server = server
        self._cameraEntityId = State(initialValue: cameraEntityId)
        self.cameraName = cameraName
    }

    var body: some View {
        ZStack {
            navigationStack

            if showLoader {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            loadMetadata()
            loadCameras()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private var navigationStack: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        CloseButton {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        nameBadge
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
    }

    @ViewBuilder
    private var nameBadge: some View {
        if let name, controlsVisible {
            Menu {
                ForEach(cameras) { camera in
                    Button {
                        switchCamera(to: camera.entityId)
                    } label: {
                        if let snapshot = cameraSnapshots[camera.entityId] {
                            Image(uiImage: snapshot)
                                .renderingMode(.original)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.one))
                        } else {
                            Image(systemSymbol: .videoFill)
                        }
                        Text(camera.name)
                        if let subtitle = cameraSubtitles[camera.entityId], !subtitle.isEmpty {
                            Text(subtitle)
                        }
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spaces.one) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                        Text(name)
                            .font(DesignSystem.Font.caption.bold())
                            .foregroundStyle(.primary)
                            .frame(maxWidth: maxTitleTextWidth, alignment: .leading)
                            .truncationMode(.middle)
                        if let subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(DesignSystem.Font.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: maxTitleTextWidth, alignment: .leading)
                                .truncationMode(.middle)
                        }
                    }
                    if cameras.count > 1 {
                        Image(systemSymbol: .chevronUpChevronDown)
                            .font(DesignSystem.Font.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DesignSystem.Spaces.two)
                .padding(.vertical, DesignSystem.Spaces.one)
            }
            .menuOrder(.fixed)
            .disabled(cameras.count <= 1)
        }
    }

    private var content: some View {
        Group {
            switch playerType {
            case .webRTC:
                WebRTCVideoPlayerView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    cameraName: name ?? cameraName,
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
                    cameraName: name ?? cameraName,
                    controlsVisible: $controlsVisible,
                    onHLSUnsupported: {
                        fallbackToMJPEG()
                    }
                )
            case .mjpeg:
                CameraMJPEGPlayerView(
                    server: server,
                    cameraEntityId: cameraEntityId,
                    cameraName: name ?? cameraName,
                    controlsVisible: $controlsVisible
                )
            }
        }
        // Rebuild the whole player subtree when the camera changes so the previous stream is torn
        // down cleanly (the WebRTC controller closes its connection in `viewWillDisappear`) before a
        // new one starts, rather than reusing the existing player/view model.
        .id(cameraEntityId)
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

    private func loadMetadata() {
        appEntity = HAAppEntity.entity(id: cameraEntityId, serverId: server.identifier.rawValue)
        name = appEntity?.name ?? cameraName
        subtitle = appEntity?.contextualSubtitle
    }

    private func loadCameras() {
        do {
            let loaded = try HAAppEntity.config()
                .filter { $0.serverId == server.identifier.rawValue && $0.domain == Domain.camera.rawValue }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            cameras = loaded
            cameraSubtitles = Dictionary(
                uniqueKeysWithValues: loaded.compactMap { camera in
                    camera.contextualSubtitle.map { (camera.entityId, $0) }
                }
            )
            Task { await loadSnapshots(for: loaded) }
        } catch {
            Current.Log.error("Failed to load cameras for picker: \(error)")
        }
    }

    /// Fetches a still thumbnail for each camera to show as its picker icon. Failures are logged and
    /// simply leave that camera on its SF Symbol placeholder.
    @MainActor
    private func loadSnapshots(for cameras: [HAAppEntity]) async {
        guard let api = Current.api(for: server) else { return }
        for camera in cameras where cameraSnapshots[camera.entityId] == nil {
            do {
                let image: UIImage = try await withCheckedThrowingContinuation { continuation in
                    api.getCameraSnapshot(cameraEntityID: camera.entityId)
                        .done { continuation.resume(returning: $0) }
                        .catch { continuation.resume(throwing: $0) }
                }
                let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 120, height: 120))
                cameraSnapshots[camera.entityId] = thumbnail ?? image
            } catch {
                Current.Log.error("Failed to load snapshot for \(camera.entityId): \(error)")
            }
        }
    }

    private func switchCamera(to entityId: String) {
        guard entityId != cameraEntityId else { return }
        // Restart from the top of the fallback chain and show the loader while the new stream connects.
        // Changing `cameraEntityId` re-identifies `content`, tearing down the current player first.
        showLoader = true
        playerType = .webRTC
        cameraEntityId = entityId
        loadMetadata()
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
