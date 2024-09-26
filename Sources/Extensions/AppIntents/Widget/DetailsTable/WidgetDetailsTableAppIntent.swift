import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsTableAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.actions.title", defaultValue: "Actions")
    static let description = IntentDescription(
        .init("widgets.actions.description", defaultValue: "Perform Home Assistant actions.")
    )

    @Parameter(
        title: .init("TODO", defaultValue: "Choose Sensor"),
        size: [
            .systemSmall: 2,
            .systemMedium: 4,
        ]
    )
    var sensors: [IntentDetailsTableAppEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
