import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlOpenExperimentalDashboardItem {
    let server: IntentServerAppEntity
    let icon: SFSymbolEntity
    let displayText: String?
}

@available(iOS 18, *)
struct ControlOpenExperimentalDashboardValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlOpenExperimentalDashboardConfiguration) async throws
        -> ControlOpenExperimentalDashboardItem {
        item(configuration: configuration)
    }

    func placeholder(for configuration: ControlOpenExperimentalDashboardConfiguration)
        -> ControlOpenExperimentalDashboardItem {
        item(configuration: configuration)
    }

    func previewValue(configuration: ControlOpenExperimentalDashboardConfiguration)
        -> ControlOpenExperimentalDashboardItem {
        item(configuration: configuration)
    }

    private func item(configuration: ControlOpenExperimentalDashboardConfiguration)
        -> ControlOpenExperimentalDashboardItem {
        .init(
            server: configuration.server ?? placeholder().server,
            icon: configuration.icon ?? placeholder().icon,
            displayText: configuration.displayText
        )
    }

    private func placeholder() -> ControlOpenExperimentalDashboardItem {
        .init(
            server: .init(identifier: .init(rawValue: "")),
            icon: .init(id: SFSymbol.squareGrid2x2.rawValue),
            displayText: nil
        )
    }
}

@available(iOS 18.0, *)
struct ControlOpenExperimentalDashboardConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.controls.open_experimental_dashboard.configuration.title",
        defaultValue: "Open Experimental Dashboard"
    )

    @Parameter(
        title: .init(
            "widgets.controls.open_experimental_dashboard.configuration.parameter.server",
            defaultValue: "Server"
        ),
    )
    var server: IntentServerAppEntity?

    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?

    @Parameter(
        title: .init("app_intents.display_text.title", defaultValue: "Display Text")
    )
    var displayText: String?
}
