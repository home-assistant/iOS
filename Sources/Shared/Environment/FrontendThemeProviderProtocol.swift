import Foundation
import HADesignSystem
import SwiftUI

/// Reads the frontend theme the web view captured, so native screens can be drawn in the colors the
/// user configured on their server instead of the app's compiled-in defaults.
public protocol FrontendThemeProviderProtocol {
    /// Every property captured for a server in one appearance, keyed by property name. Passing `nil`
    /// for `serverId` resolves to the server the user last used.
    func variables(for serverId: String?, appearance: FrontendThemeAppearance) -> [String: FrontendThemeVariable]

    /// The raw computed CSS value of one property — a length, a font, a colour, whatever it is.
    func value(of name: String, for serverId: String?, appearance: FrontendThemeAppearance) -> String?

    /// A colour for one property, resolving light and dark from their own captured rows, or `nil`
    /// when the property was never captured or is not a colour.
    func color(of name: String, for serverId: String?) -> Color?

    /// A colour for a known frontend property, falling back to the default the frontend ships when
    /// nothing has been captured for this server yet — so a screen drawn before the web view has ever
    /// loaded still gets the stock theme. Properties whose default the app cannot resolve on its own
    /// (the `--ha-color-*` core palette, which lives outside `color.globals.ts`) fall back to `.clear`,
    /// exactly as ``FrontendColors/color`` does; a capture is what gives those a real value.
    func color(_ frontendColor: FrontendColors, for serverId: String?) -> Color

    /// Replace what is stored for one server and appearance with a freshly captured theme.
    func store(_ variables: [FrontendThemeVariable], for serverId: String, appearance: FrontendThemeAppearance)

    /// Drop the in-memory cache and read the database again.
    func reload()
}

public extension FrontendThemeProviderProtocol {
    func variables(appearance: FrontendThemeAppearance) -> [String: FrontendThemeVariable] {
        variables(for: nil, appearance: appearance)
    }

    func color(of name: String) -> Color? {
        color(of: name, for: nil)
    }

    func color(_ frontendColor: FrontendColors) -> Color {
        color(frontendColor, for: nil)
    }
}
