import AppIntents
import Foundation
import Shared

/// What the Areas widget is configured with: the server whose areas it lists.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetAreasAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init(
        "widgets.areas.title",
        defaultValue: "Areas"
    )

    static var isDiscoverable: Bool = false

    @Parameter(
        title: .init("widgets.param.server.title", defaultValue: "Server")
    )
    var server: IntentServerAppEntity

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
