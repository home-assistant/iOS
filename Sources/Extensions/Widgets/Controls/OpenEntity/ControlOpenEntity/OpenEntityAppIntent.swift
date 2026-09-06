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
    // `openAppWhenRun` is deprecated from iOS 26; both stay until the deployment target passes 26.
    @available(iOS 26.0, watchOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @Parameter(
        title: .init("widgets.controls.open_entity.configuration.parameter.entity", defaultValue: "Entity")
    )
    var entity: HAAppEntityAppIntentEntity?

    func perform() async throws -> some IntentResult {
        guard let entity else { return .result() }
        #if !WIDGET_EXTENSION
        if let url = AppConstants.openEntityDestinationURL(
            entityId: entity.entityId,
            serverId: entity.serverId
        ) {
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        #endif
        return .result()
    }
}
