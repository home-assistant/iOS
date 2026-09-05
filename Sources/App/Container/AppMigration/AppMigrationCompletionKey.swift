import Foundation

/// Keys of the user info carried by `Notification.Name.appMigrationDidComplete`.
enum AppMigrationCompletionKey {
    /// How many servers the new app reported importing. `Int`.
    static let serverCount = "serverCount"
}

extension Notification.Name {
    /// Posted when the new app confirms it imported this app's data, so whichever migration screen
    /// is on display can move to its final state and the app can retire itself.
    static let appMigrationDidComplete = Notification.Name("AppMigrationDidComplete")
}
