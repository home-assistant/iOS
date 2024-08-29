import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlAssistItem {
    let server: IntentServerAppEntity
}

@available(iOSApplicationExtension 18, *)
struct ControlAssistValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlAssistConfiguration) async throws -> ControlAssistItem {
        .init(server: configuration.server ?? .init(identifier: "-1"))
    }

    func placeholder(for configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(server: configuration.server ?? .init(identifier: "-1"))
    }

    func previewValue(configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(server: configuration.server ?? .init(identifier: "-1"))
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ControlAssistConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Assist in App"

    @Parameter(
        title: "Server"
    )
    var server: IntentServerAppEntity?

}
