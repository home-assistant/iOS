import Foundation

/// A searchable row inside a settings screen, indexed by the root settings search.
/// When a query matches an entry, the entry title is surfaced as the subtitle of
/// the row representing the screen in the search results.
struct SettingsSearchEntry: Hashable {
    /// The user-visible title of the row inside the screen.
    let title: String
    /// Additional localized synonyms for the row.
    let keywords: [String]

    init(_ title: String, keywords: [String] = []) {
        self.title = title
        self.keywords = keywords
    }

    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if title.localizedStandardContains(query) {
            return true
        }
        return keywords.contains { $0.localizedStandardContains(query) }
    }
}
