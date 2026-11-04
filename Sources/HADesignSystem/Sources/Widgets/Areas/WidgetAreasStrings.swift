#if !os(watchOS)
import Foundation

/// The copy the areas widget draws.
///
/// Handed in rather than looked up: the design system ships no string tables, and the app's
/// translations are the ones that have to end up on screen. Only the paging arrows need any — the
/// floor headings are named by the server, and the areas by themselves.
public struct WidgetAreasStrings {
    public let previousPage: String
    public let nextPage: String

    public init(previousPage: String, nextPage: String) {
        self.previousPage = previousPage
        self.nextPage = nextPage
    }

    /// English stand-ins, for previews and the component gallery.
    public static let preview = WidgetAreasStrings(previousPage: "Previous areas", nextPage: "More areas")
}
#endif
