import AppIntents
import Foundation
import Shared

@available(iOS 18.0, *)
struct OpenExperimentalDashboardIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.open_experimental_dashboard.title",
        defaultValue: "Open Experimental Dashboard"
    )

    static var description = IntentDescription(
        .init(
            "app_intents.open_experimental_dashboard.description",
            defaultValue: "Opens the experimental dashboard"
        )
    )

    static var openAppWhenRun: Bool = true

    @Parameter(title: .init("app_intents.server.title", defaultValue: "Server"))
    var server: IntentServerAppEntity?

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let server else {
            return .result()
        }
        #if !WIDGET_EXTENSION

        // Navigate to the experimental dashboard using the URL scheme
        if let url = AppConstants.openExperimentalDashboardDeeplinkURL(serverId: server.id) {
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        #endif

        return .result()
    }
}
