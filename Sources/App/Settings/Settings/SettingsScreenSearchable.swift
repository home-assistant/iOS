import Foundation

/// Conformed to by every settings screen reachable from the root settings list,
/// exposing the rows it contains so the root settings search can index screen
/// content and surface matches as row subtitles.
protocol SettingsScreenSearchable {
    /// The searchable rows this screen contains, using the same localized titles
    /// the rows display on screen.
    static var settingsSearchEntries: [SettingsSearchEntry] { get }
}
