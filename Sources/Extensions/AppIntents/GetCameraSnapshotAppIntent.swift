import AppIntents
import Shared
import UIKit
import UniformTypeIdentifiers

@available(iOS 17.0, *)
struct GetCameraSnapshotAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.get_camera_snapshot.title",
        defaultValue: "Get camera snapshot"
    )

    static var description = IntentDescription(.init(
        "app_intents.get_camera_snapshot.description",
        defaultValue: "Get a single still frame from a camera"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$server
            \.$camera
        }
    }

    @Parameter(title: .init("app_intents.server.title", defaultValue: "Server"))
    var server: IntentServerAppEntity

    @Parameter(title: .init("app_intents.get_camera_snapshot.camera.title", defaultValue: "Camera"))
    var camera: IntentCameraEntity

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        await Current.connectivity.syncNetworkInformation()
        guard camera.serverId == server.id,
              let server = server.getServer(),
              let api = Current.api(for: server) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        let image = try await api.getCameraSnapshot(cameraEntityID: camera.entityId).async()
        guard let pngData = image.pngData() else {
            throw ShortcutAppIntentError(L10n.AppIntents.GetCameraSnapshot.Error.pngConversion)
        }

        let filename = "\(camera.entityId)_snapshot.png"
        return .result(value: .init(data: pngData, filename: filename, type: .png))
    }
}
