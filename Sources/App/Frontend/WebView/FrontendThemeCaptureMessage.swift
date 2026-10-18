import Foundation
import Shared

/// The `updateThemeVariables` payload `WebSocketBridge.js` posts, decoded into rows ready to store.
///
/// Kept apart from the message handler so the decoding — which is all of the interesting behaviour —
/// can be exercised without a web view: which appearance the capture belongs to, and which of the
/// reported properties survive into the database.
struct FrontendThemeCaptureMessage {
    let appearance: FrontendThemeAppearance
    let variables: [FrontendThemeVariable]

    /// Returns `nil` when the payload carries nothing worth storing, so the caller can drop it
    /// rather than replace a good theme with an empty one.
    ///
    /// `fallbackAppearance` is only consulted when the frontend did not say which appearance it
    /// resolved the theme in — its own flag is authoritative, because the user can pin the frontend
    /// to light or dark independently of the system.
    init?(
        messageBody: [String: Any],
        serverId: String,
        fallbackAppearance: FrontendThemeAppearance,
        capturedAt: Date
    ) {
        guard let rawVariables = messageBody["variables"] as? [[String: Any]] else {
            return nil
        }

        let appearance: FrontendThemeAppearance
        if let isDarkMode = messageBody["darkMode"] as? Bool {
            appearance = isDarkMode ? .dark : .light
        } else {
            appearance = fallbackAppearance
        }

        let themeName = messageBody["themeName"] as? String
        let variables = rawVariables.compactMap { raw -> FrontendThemeVariable? in
            guard let name = raw["name"] as? String, let value = raw["value"] as? String else {
                return nil
            }
            return FrontendThemeVariable(
                serverId: serverId,
                appearance: appearance,
                name: name,
                value: value,
                colorValue: raw["color"] as? String,
                themeName: themeName,
                updatedAt: capturedAt
            )
        }
        guard !variables.isEmpty else {
            return nil
        }

        self.appearance = appearance
        self.variables = variables
    }
}
