import Foundation

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
