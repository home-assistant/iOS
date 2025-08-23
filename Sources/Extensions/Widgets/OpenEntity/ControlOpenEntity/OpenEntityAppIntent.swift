import AppIntents
import Foundation
import Shared
import SwiftUI

// AppIntent that open app needs to have it's target the widget extension AND app target!
@available(iOS 17, *)
struct OpenEntityAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_entity.configuration.title",
        defaultValue: "Open Entity"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: .init("widgets.controls.open_entity.configuration.parameter.entity", defaultValue: "Entity")
    )
    var entity: HAAppEntityAppIntentEntity?

    func perform() async throws -> some IntentResult {
        guard let entity else { return .result() }
        #if !WIDGET_EXTENSION
        if Domain(entityId: entity.entityId) == .camera, let url = AppConstants.openCameraDeeplinkURL(
            entityId: entity.entityId,
            serverId: entity.serverId
        ) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        } else if let url =
            AppConstants.openEntityDeeplinkURL(entityId: entity.entityId, serverId: entity.serverId) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url)
            }
        }
        #endif
        return .result()
    }
}
