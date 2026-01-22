#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && os(iOS)
import ActivityKit
import Foundation

/// Activity attributes for displaying AppIntent execution confirmations in the Dynamic Island
@available(iOS 16.1, *)
public struct AppIntentConfirmationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Title of the confirmation message
        public var title: String
        /// Whether the operation was successful
        public var isSuccess: Bool
        /// Timestamp when the activity was created
        public var timestamp: Date

        public init(title: String, isSuccess: Bool, timestamp: Date = .init()) {
            self.title = title
            self.isSuccess = isSuccess
            self.timestamp = timestamp
        }
    }

    /// Unique identifier for the confirmation (maps to NotificationIdentifier)
    public var id: String

    public init(id: String) {
        self.id = id
    }
}
#endif
