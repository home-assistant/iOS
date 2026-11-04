import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct WidgetOpenPageAppIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    // Carries over configurations from the deprecated SiriKit widget intent
    static let intentClassName = "WidgetOpenPageIntent"

    static let title: LocalizedStringResource = .init("widgets.open_page.title", defaultValue: "Open Page")
    static let description = IntentDescription(
        .init("widgets.open_page.description", defaultValue: "Open a frontend page in Home Assistant.")
    )

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: .init("widgets.open_page.parameter.pages", defaultValue: "Pages"),
        size: [
            .systemSmall: 3,
            .systemMedium: 6,
            .systemLarge: 12,
            .systemExtraLarge: 20,
        ]
    )
    var pages: [PageAppEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
