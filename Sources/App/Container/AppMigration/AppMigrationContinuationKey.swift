import Foundation

/// Keys of the user info carried by `Notification.Name.appMigrationDidRequestNextChunk`.
enum AppMigrationContinuationKey {
    /// Which handoff the request belongs to. `String`.
    static let sessionID = "sessionID"
    /// Which slice the new app still needs. `Int`.
    static let nextIndex = "nextIndex"
    /// The slice that just arrived. `AppMigrationChunk`.
    static let chunk = "chunk"
}

extension Notification.Name {
    /// Posted when the new app asks for the next slice of a payload that did not fit in one link.
    static let appMigrationDidRequestNextChunk = Notification.Name("AppMigrationDidRequestNextChunk")

    /// Posted on the new app when another slice arrives for a handoff already on screen.
    static let appMigrationDidReceiveChunk = Notification.Name("AppMigrationDidReceiveChunk")
}
