import Foundation

/// One item of a Markdown list, as parsed by ``HAMarkdownParser``.
public struct HAMarkdownListItem: Equatable, Sendable {
    /// Nesting depth, counted in levels rather than spaces — the parser has already divided by the
    /// indent width, so a view can indent by a fixed step without re-reading the source.
    public let indent: Int
    public let text: String
    /// The ordinal the item's own marker carried, or `nil` when it was a bullet.
    ///
    /// Per item, not per list: a bullet nested under a numbered item is a bullet, and taking the
    /// whole list's kind from its first line would renumber it as the parent's next entry. The
    /// number itself is kept because `5. Fifth` is valid GFM and starts the list at five.
    public let number: Int?

    /// Whether the item's marker was a number at all.
    public var ordered: Bool { number != nil }
    /// Whether the item is a GFM task-list checkbox, and if so whether it is ticked. `nil` for an
    /// ordinary bullet.
    public let checked: Bool?

    public init(indent: Int = 0, text: String, number: Int? = nil, checked: Bool? = nil) {
        self.indent = indent
        self.text = text
        self.number = number
        self.checked = checked
    }
}
