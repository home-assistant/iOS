import AppIntents
import Foundation
import Shared
import SwiftUI

@available(iOS 18, *)
struct OpenCameraListAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_camera_list.title",
        defaultValue: "Open Camera List"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: .init("widgets.controls.open_camera_list.parameter.server", defaultValue: "Server")
    )
    var server: IntentServerAppEntity?

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        if let url = AppConstants.openCameraListDeeplinkURL(serverId: server?.id) {
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        #endif
        return .result()
    }
}
