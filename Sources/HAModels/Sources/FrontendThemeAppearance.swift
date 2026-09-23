import Foundation
import GRDB

/// Which of the frontend's two appearances a set of theme variables was resolved in.
///
/// The frontend resolves a theme's custom properties differently depending on whether it is
/// rendering light or dark, so a captured value is only meaningful alongside the appearance it came
/// from. Rows are stored per appearance and read back with the one the native screen is drawing in.
///
/// Distinct from the app's `FrontendThemeMode`, which is the automatic/light/dark preference the
/// user picks in their frontend profile: this is what that preference actually resolved to.
public enum FrontendThemeAppearance: String, Codable, CaseIterable, Sendable, DatabaseValueConvertible {
    case light
    case dark
}
