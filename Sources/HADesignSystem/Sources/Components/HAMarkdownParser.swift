import Foundation

/// Splits Markdown into ``HAMarkdownBlock`` values.
///
/// `AttributedString(markdown:)` reads inline syntax well and block structure not at all — headings,
/// bullets and code fences all arrive as plain lines with their punctuation intact. This recovers
/// the block layer so ``HAMarkdownText`` can lay it out, and leaves the inline layer to Foundation.
///
/// The dialect is the one the frontend passes to `marked`: GFM, which is what `ha-markdown` renders.
/// Kept free of SwiftUI so it can be tested as the pure function it is.
public enum HAMarkdownParser {
    /// Spaces per nesting level in a list. CommonMark counts a nested item from its parent's content
    /// column, which varies; two spaces is the common convention and what the frontend's source
    /// generally uses.
    private static let indentWidth = 2

    public static func parse(_ markdown: String) -> [HAMarkdownBlock] {
        var blocks: [HAMarkdownBlock] = []
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }
            if let fence = codeFence(trimmed) {
                let (block, next) = parseCodeBlock(lines, from: index, fence: fence)
                blocks.append(block)
                index = next
                continue
            }
            if isRule(trimmed) {
                blocks.append(.rule)
                index += 1
                continue
            }
            if let heading = parseHeading(trimmed) {
                blocks.append(heading)
                index += 1
                continue
            }
            if trimmed.hasPrefix(">") {
                let (block, next) = parseQuote(lines, from: index)
                blocks.append(block)
                index = next
                continue
            }
            if isTableHeader(lines, at: index) {
                let (block, next) = parseTable(lines, from: index)
                blocks.append(block)
                index = next
                continue
            }
            if listMarker(trimmed) != nil {
                let (block, next) = parseList(lines, from: index)
                blocks.append(block)
                index = next
                continue
            }
            let (block, next) = parseParagraph(lines, from: index)
            blocks.append(block)
            index = next
        }
        return blocks
    }

    // MARK: - Headings and rules

    private static func parseHeading(_ trimmed: String) -> HAMarkdownBlock? {
        let hashes = trimmed.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else {
            return nil
        }
        let rest = trimmed.dropFirst(hashes.count)
        // `#Not a heading` is a paragraph in CommonMark: the hashes need a space after them.
        guard rest.first == " " else {
            return nil
        }
        // Trailing hashes are decoration in the closed-ATX style and are not part of the text.
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") {
            text.removeLast()
        }
        return .heading(level: hashes.count, text: text.trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ trimmed: String) -> Bool {
        for marker in ["-", "*", "_"] {
            let stripped = trimmed.replacingOccurrences(of: " ", with: "")
            if stripped.count >= 3, stripped.allSatisfy({ String($0) == marker }) {
                return true
            }
        }
        return false
    }

    // MARK: - Code

    /// The whole opening run when the line opens a fenced block — the character *and* how many of
    /// them.
    ///
    /// Both matter. A ``` block may legitimately contain ~~~ and vice versa, and GFM closes a fence
    /// only on a run of the same character at least as long: inside a four-backtick block, a
    /// three-backtick line is code, not the end of it.
    private static func codeFence(_ trimmed: String) -> String? {
        for character in ["`", "~"] {
            let run = trimmed.prefix { String($0) == character }
            if run.count >= 3 {
                return String(run)
            }
        }
        return nil
    }

    /// A fence closes on a run of the same character at least as long as the one that opened it.
    private static func closesFence(_ line: String, opening fence: String) -> Bool {
        guard let character = fence.first else {
            return false
        }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.prefix { $0 == character }.count >= fence.count
    }

    private static func parseCodeBlock(
        _ lines: [String],
        from start: Int,
        fence: String
    ) -> (HAMarkdownBlock, Int) {
        let info = lines[start].trimmingCharacters(in: .whitespaces).dropFirst(fence.count)
        let language = info.trimmingCharacters(in: .whitespaces)
        var body: [String] = []
        var index = start + 1
        while index < lines.count {
            if closesFence(lines[index], opening: fence) {
                index += 1
                break
            }
            body.append(lines[index])
            index += 1
        }
        return (
            .codeBlock(language: language.isEmpty ? nil : language, code: body.joined(separator: "\n")),
            index
        )
    }

    // MARK: - Quotes

    private static func parseQuote(_ lines: [String], from start: Int) -> (HAMarkdownBlock, Int) {
        var body: [String] = []
        var index = start
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(">") else {
                break
            }
            var content = Substring(trimmed).dropFirst()
            if content.first == " " {
                content = content.dropFirst()
            }
            body.append(String(content))
            index += 1
        }
        return (.quote(body), index)
    }

    // MARK: - Lists

    /// The marker and the text after it, when the line starts a list item.
    private static func listMarker(_ trimmed: String) -> (number: Int?, text: String)? {
        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            return (nil, String(trimmed.dropFirst(marker.count)))
        }
        let digits = trimmed.prefix(while: \.isNumber)
        guard !digits.isEmpty, let number = Int(digits) else {
            return nil
        }
        let rest = trimmed.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else {
            return nil
        }
        // The ordinal is kept, not just the fact that there was one: `5. Fifth` is valid GFM and
        // renumbering it from 1 would contradict the source.
        return (number, String(rest.dropFirst(2)))
    }

    private static func parseList(_ lines: [String], from start: Int) -> (HAMarkdownBlock, Int) {
        var items: [HAMarkdownListItem] = []
        var index = start
        // The list's kind is set by its first item; a bullet appearing under a numbered list is a
        // nested list in CommonMark, and flattening it here keeps one block rather than three.
        let ordered = listMarker(lines[start].trimmingCharacters(in: .whitespaces))?.number != nil

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let marker = listMarker(trimmed) else {
                break
            }
            let leading = line.prefix { $0 == " " }.count
            var text = marker.text
            var checked: Bool?
            if text.hasPrefix("[ ] ") {
                checked = false
                text = String(text.dropFirst(4))
            } else if text.lowercased().hasPrefix("[x] ") {
                checked = true
                text = String(text.dropFirst(4))
            }
            items.append(HAMarkdownListItem(
                indent: leading / indentWidth,
                text: text.trimmingCharacters(in: .whitespaces),
                number: marker.number,
                checked: checked
            ))
            index += 1
        }
        return (.list(ordered: ordered, items: items), index)
    }

    // MARK: - Tables

    /// A GFM table is a header row followed by a delimiter row of dashes; without the delimiter the
    /// pipes are just text.
    private static func isTableHeader(_ lines: [String], at index: Int) -> Bool {
        guard lines[index].trimmingCharacters(in: .whitespaces).contains("|"),
              index + 1 < lines.count else {
            return false
        }
        let delimiter = lines[index + 1].trimmingCharacters(in: .whitespaces)
        guard delimiter.contains("-") else {
            return false
        }
        return delimiter.allSatisfy { $0 == "-" || $0 == "|" || $0 == ":" || $0 == " " }
    }

    private static func parseTable(_ lines: [String], from start: Int) -> (HAMarkdownBlock, Int) {
        let headers = tableCells(lines[start])
        var rows: [[String]] = []
        var index = start + 2
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("|"), !trimmed.isEmpty else {
                break
            }
            rows.append(tableCells(lines[index]))
            index += 1
        }
        return (.table(headers: headers, rows: rows), index)
    }

    private static func tableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        // The outer pipes are optional in GFM; dropping them avoids an empty cell at each end.
        if trimmed.hasPrefix("|") {
            trimmed = String(trimmed.dropFirst())
        }
        if trimmed.hasSuffix("|") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: - Paragraphs

    private static func parseParagraph(_ lines: [String], from start: Int) -> (HAMarkdownBlock, Int) {
        var body: [String] = []
        var index = start
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                break
            }
            // A paragraph also ends where another block begins, without needing a blank line first
            // — `marked` lets a heading, fence or bullet interrupt one, and so does CommonMark.
            if index > start, startsBlock(lines, at: index) {
                break
            }
            body.append(trimmed)
            index += 1
        }
        // Soft line breaks inside a paragraph are spaces, not newlines. `breaks: true` would make
        // them hard breaks, but the frontend leaves that off for `ha-markdown` by default.
        return (.paragraph(body.joined(separator: " ")), index)
    }

    /// Whether a line opens a block other than a paragraph.
    private static func startsBlock(_ lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        return isRule(trimmed)
            || codeFence(trimmed) != nil
            || parseHeading(trimmed) != nil
            || trimmed.hasPrefix(">")
            || listMarker(trimmed) != nil
            || isTableHeader(lines, at: index)
    }
}

extension HAMarkdownParser: FrontendComponent {
    public static var frontendComponentName: String { "ha-markdown" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
