import AppIntents
import Foundation
import Shared
import SwiftUI

// AppIntent that open app needs to have it's target the widget extension AND app target!
@available(iOS 17, *)
struct OpenZoneAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_zone.configuration.title",
        defaultValue: "Open Zone"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: .init("widgets.controls.open_zone.configuration.parameter.entity", defaultValue: "Zone")
    )
    var entity: HAAppEntityAppIntentEntity?

    func perform() async throws -> some IntentResult {
        guard let entity else { return .result() }
        #if !WIDGET_EXTENSION
        if let url = AppConstants.openEntityDeeplinkURL(entityId: entity.entityId, serverId: entity.serverId) {
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        #endif
        return .result()
    }
}
