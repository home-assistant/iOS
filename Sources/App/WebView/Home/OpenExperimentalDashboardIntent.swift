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

        // Navigate to the experimental dashboard using a custom URL scheme or deep link
        // This is a placeholder - you'll need to implement the actual navigation mechanism
        // based on how your app handles deep linking
        let urlString = "homeassistant://experimental-dashboard/\(server.id)"
        if let url = URL(string: urlString) {
            DispatchQueue.main.async {
                URLOpener.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        #endif

        return .result()
    }
}
