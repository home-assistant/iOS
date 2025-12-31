import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenExperimentalDashboard: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenExperimentalDashboard.rawValue,
            provider: ControlOpenExperimentalDashboardValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenExperimentalDashboardIntent()
                intent.server = template.server
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(
                    template.displayText ?? template.server.getServer()?.info.name ?? "Home Assistant",
                    systemImage: template.icon.id
                )
            }
        }
        .displayName(.init(
            "widgets.controls.open_experimental_dashboard.configuration.title",
            defaultValue: "Open Experimental Dashboard"
        ))
        .description(.init(
            "widgets.controls.open_experimental_dashboard.description",
            defaultValue: "Opens the experimental dashboard for the selected server"
        ))
    }
}
