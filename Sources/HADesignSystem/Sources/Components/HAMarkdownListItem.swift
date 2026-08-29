import Foundation

/// One item of a Markdown list, as parsed by ``HAMarkdownParser``.
public struct HAMarkdownListItem: Equatable, Sendable {
    /// Nesting depth, counted in levels rather than spaces — the parser has already divided by the
    /// indent width, so a view can indent by a fixed step without re-reading the source.
    public let indent: Int
    public let text: String
    /// Whether this item's own marker was a number.
    ///
    /// Per item, not per list: a bullet nested under a numbered item is a bullet, and taking the
    /// whole list's kind from its first line would renumber it as the parent's next entry.
    public let ordered: Bool
    /// Whether the item is a GFM task-list checkbox, and if so whether it is ticked. `nil` for an
    /// ordinary bullet.
    public let checked: Bool?

    public init(indent: Int = 0, text: String, ordered: Bool = false, checked: Bool? = nil) {
        self.indent = indent
        self.text = text
        self.ordered = ordered
        self.checked = checked
    }
}
