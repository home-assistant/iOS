import Foundation

public extension LocalizedStringResource {
    /// A string shown as it is, for an API that only takes a localized resource: a user's own text, such
    /// as an entity or server name, or a name the app has no translation for.
    ///
    /// Resolving a resource against the default table makes Foundation load and parse the whole
    /// `Localizable.strings` file again for every lookup, because the path App Intents resolves through
    /// doesn't cache the table. App Intents resolves a title and a subtitle for every entity it indexes
    /// for Spotlight or lists in Shortcuts, so with a few thousand entities one index pass kept a core
    /// busy for over a minute. Pointing the resource at a table that doesn't exist makes the lookup a
    /// cheap miss that hands the string back unchanged, formatting characters included.
    static func verbatim(_ string: String) -> LocalizedStringResource {
        LocalizedStringResource("\(string)", table: verbatimTable)
    }

    /// No strings file carries this name, and none should: the point is the miss.
    static let verbatimTable = "Verbatim"
}
