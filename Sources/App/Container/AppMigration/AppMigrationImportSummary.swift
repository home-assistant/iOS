import Foundation

/// What the app taking over actually applied, for the screen it shows afterwards.
struct AppMigrationImportSummary: Equatable {
    let serverCount: Int
    let configurationEntryCount: Int
    /// The configuration half was present but could not be applied. The servers still were, so the
    /// migration counts as a success — the screen just says the configuration has to be redone.
    let configurationFailed: Bool
}
