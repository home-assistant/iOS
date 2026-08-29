import Foundation

/// One item of a Markdown list, as parsed by ``HAMarkdownParser``.
public struct HAMarkdownListItem: Equatable, Sendable {
    /// Nesting depth, counted in levels rather than spaces — the parser has already divided by the
    /// indent width, so a view can indent by a fixed step without re-reading the source.
    public let indent: Int
    public let text: String
    /// Whether the item is a GFM task-list checkbox, and if so whether it is ticked. `nil` for an
    /// ordinary bullet.
    public let checked: Bool?

    public init(indent: Int = 0, text: String, checked: Bool? = nil) {
        self.indent = indent
        self.text = text
        self.checked = checked
    }
}

/// A block-level piece of Markdown. The frontend renders `ha-markdown` with `marked` in GFM mode,
/// so this covers the GFM block set: headings, lists including task lists, fenced code, block
/// quotes, thematic breaks and tables.
///
/// Inline syntax — emphasis, code spans, links — is deliberately *not* modelled here. It stays in
/// the text of each block and is handed to `AttributedString`'s Markdown parser at render time,
/// which handles it well; it is only block structure that it drops.
public enum HAMarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list(ordered: Bool, items: [HAMarkdownListItem])
    case codeBlock(language: String?, code: String)
    case quote([String])
    /// A thematic break — `---`, `***` or `___`.
    case rule
    case table(headers: [String], rows: [[String]])
}

extension HAMarkdownBlock: FrontendComponent {
    public static var frontendComponentName: String { "ha-markdown" }
}
