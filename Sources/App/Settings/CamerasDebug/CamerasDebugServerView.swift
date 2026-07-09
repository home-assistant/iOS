import Shared
import SwiftUI

/// Debug screen listing the camera entities for a given server. Tapping a camera
/// opens the live `CameraPlayerView` (WebRTC/HLS/MJPEG) for that entity.
struct CamerasDebugServerView: View {
    let server: Server

    @State private var cameras: [HAAppEntity] = []
    @State private var selectedCamera: HAAppEntity?

    var body: some View {
        List {
            if cameras.isEmpty {
                Text(verbatim: "No camera entities found for this server.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(cameras) { camera in
                    Section {
                        Button {
                            selectedCamera = camera
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                                Text(camera.name)
                                    .foregroundStyle(Color(uiColor: .label))
                                Text(verbatim: camera.entityId)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            copyDeeplink(for: camera)
                        } label: {
                            HStack(spacing: DesignSystem.Spaces.two) {
                                Image(systemSymbol: .docOnDoc)
                                    .foregroundStyle(Color.haPrimary)
                                Text(verbatim: "Copy deeplink")
                                    .foregroundStyle(Color(uiColor: .label))
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(server.info.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadCameras)
        .fullScreenCover(item: $selectedCamera) { camera in
            CameraPlayerView(
                server: server,
                cameraEntityId: camera.entityId,
                cameraName: camera.name,
                showsDebugOverlay: true
            )
        }
    }

    private func copyDeeplink(for camera: HAAppEntity) {
        guard let url = AppConstants.openCameraDeeplinkURL(
            entityId: camera.entityId,
            serverId: server.identifier.rawValue
        ) else {
            Current.Log.error("Failed to build camera deeplink for \(camera.entityId)")
            return
        }
        UIPasteboard.general.string = url.absoluteString
    }

    private func loadCameras() {
        do {
            cameras = try HAAppEntity.config()
                .filter { $0.serverId == server.identifier.rawValue && $0.domain == Domain.camera.rawValue }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            Current.Log.error("Failed to load cameras for debug view, error: \(error)")
        }
    }
}

#if DEBUG
#Preview {
    NavigationView {
        CamerasDebugServerView(server: ServerFixture.standard)
    }
}
#endif
