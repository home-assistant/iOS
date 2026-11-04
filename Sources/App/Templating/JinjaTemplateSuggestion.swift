import Foundation

/// One autocomplete suggestion offered above the keyboard while editing a Jinja template.
struct JinjaTemplateSuggestion: Identifiable, Equatable {
    /// Shown on the suggestion chip.
    let label: String
    /// Inserted into the template at the cursor, replacing the typed prefix.
    let insertion: String
    /// How many UTF-16 units before the cursor the insertion replaces (the typed prefix).
    let replacingCount: Int
    /// How far (UTF-16 units) to move the cursor back from the insertion's end after inserting —
    /// e.g. to land inside `{{  }}` or between quotes.
    let cursorOffsetFromEnd: Int
    /// Explicit text range to replace, used when replacing an inline entity pill.
    let replacementRange: NSRange?

    init(
        label: String,
        insertion: String,
        replacingCount: Int = 0,
        cursorOffsetFromEnd: Int = 0,
        replacementRange: NSRange? = nil
    ) {
        self.label = label
        self.insertion = insertion
        self.replacingCount = replacingCount
        self.cursorOffsetFromEnd = cursorOffsetFromEnd
        self.replacementRange = replacementRange
    }

    var id: String { label + insertion }
}
