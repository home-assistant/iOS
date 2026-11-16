import Foundation

/// Whether this app has handed its setup to the other app, read from the app group so the
/// extensions and the watch relay stop talking to the servers as well, not only the main process.
public enum AppMigrationHandoff {
    public static let phaseDefaultsKey = "appMigrationHandoffPhase"

    public static var isActive: Bool {
        UserDefaults(suiteName: AppConstants.AppGroupID)?.string(forKey: phaseDefaultsKey) != nil
    }
}
