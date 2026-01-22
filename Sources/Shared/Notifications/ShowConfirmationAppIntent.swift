#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && os(iOS)
import ActivityKit
import AppIntents
import Foundation

/// AppIntent that shows a confirmation message via Live Activity on iOS 16.2+
@available(iOS 16.2, *)
public struct ShowConfirmationAppIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "Show Confirmation"
    public static var description: IntentDescription = "Shows a confirmation message in the Dynamic Island"

    // Mark as not discoverable since this is an internal helper intent
    public static var isDiscoverable: Bool = false

    // Don't open the app when this intent runs - just show the Live Activity
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Identifier")
    public var identifier: String

    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Is Success")
    public var isSuccess: Bool

    @Parameter(title: "Duration")
    public var duration: Double

    public init(identifier: String, title: String, isSuccess: Bool, duration: Double = 3.0) {
        self.identifier = identifier
        self.title = title
        self.isSuccess = isSuccess
        self.duration = duration
    }

    public init() {
        self.identifier = ""
        self.title = ""
        self.isSuccess = false
        self.duration = 3.0
    }

    public func perform() async throws -> some IntentResult {
        let attributes = AppIntentConfirmationAttributes(id: identifier)
        let contentState = AppIntentConfirmationAttributes.ContentState(
            title: title,
            isSuccess: isSuccess
        )

        let content = ActivityContent(state: contentState, staleDate: nil)
        let activity = try Activity.request(attributes: attributes, content: content)

        Current.Log.info("Started Live Activity for confirmation: \(identifier)")

        // Schedule auto-dismiss after duration
        Task {
            try? await Task.sleep(for: .seconds(duration))

            // End the activity
            let finalState = AppIntentConfirmationAttributes.ContentState(
                title: title,
                isSuccess: isSuccess
            )
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        return .result()
    }
}
#endif
