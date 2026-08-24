import Foundation

/// Where this install stands in the move to the new Apple Developer account.
///
/// Stored in the app-group defaults rather than the database so extensions — which never run the
/// migration but do need to know the app has been retired — can read it too.
public enum AppMigrationStatus {
    private static let handedOffAtKey = "appMigrationHandedOffAt"
    private static let importedAtKey = "appMigrationImportedAt"
    private static let promptDismissedAtKey = "appMigrationPromptDismissedAt"

    private static var prefs: UserDefaults { Current.settingsStore.prefs }

    /// When the new app acknowledged importing this app's data. Only ever set on the source app.
    public static var handedOffAt: Date? {
        get { prefs.object(forKey: handedOffAtKey) as? Date }
        set { prefs.set(newValue, forKey: handedOffAtKey) }
    }

    /// When this app imported a payload from the app it replaces. Only ever set on the destination.
    public static var importedAt: Date? {
        get { prefs.object(forKey: importedAtKey) as? Date }
        set { prefs.set(newValue, forKey: importedAtKey) }
    }

    /// When the user last chose "not now" on the migration prompt, so it is offered again on a later
    /// launch instead of every time the app is opened.
    public static var promptDismissedAt: Date? {
        get { prefs.object(forKey: promptDismissedAtKey) as? Date }
        set { prefs.set(newValue, forKey: promptDismissedAtKey) }
    }

    /// This app has handed its data over and should stop acting as the user's companion app: no
    /// sensor updates, no location updates, nothing that would fight with the app that replaced it.
    public static var isRetired: Bool { handedOffAt != nil }

    /// How long the prompt stays out of the way after "not now".
    public static let promptSnoozeInterval: TimeInterval = 60 * 60 * 24 * 3

    /// Whether the source app should offer the migration on this launch.
    public static var shouldPrompt: Bool {
        guard AppMigrationConstants.isConfigured, AppMigrationRole.current == .source, !isRetired else {
            return false
        }
        guard let promptDismissedAt else { return true }
        return Current.date().timeIntervalSince(promptDismissedAt) > promptSnoozeInterval
    }
}
