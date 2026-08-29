#if !os(watchOS)
import SwiftUI

/// Rendered Markdown. The SwiftUI counterpart of the frontend's `ha-markdown` and the
/// `ha-markdown-element` inside it.
///
/// Block structure comes from ``HAMarkdownParser``; the inline syntax within each block is left to
/// `AttributedString`'s Markdown parser, which handles emphasis, code spans and links well. That
/// split is the whole point — Foundation drops headings, bullets and fences, and this puts them
/// back.
public struct HAMarkdownText: View {
    /// Indent per nesting level in a list, matching the step the frontend's `ul` gets from its
    /// default padding.
    private static let listIndent: CGFloat = 16

    private let blocks: [HAMarkdownBlock]

    public init(_ markdown: String) {
        self.blocks = HAMarkdownParser.parse(markdown)
    }

    /// Renders blocks that have already been parsed, for a caller that keeps them around rather
    /// than re-parsing on every body evaluation.
    public init(blocks: [HAMarkdownBlock]) {
        self.blocks = blocks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func view(for block: HAMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(Self.inline(text))
                .font(Self.headingFont(level: level))
                .fixedSize(horizontal: false, vertical: true)
        case let .paragraph(text):
            Text(Self.inline(text))
                .font(DesignSystem.Font.body)
                .fixedSize(horizontal: false, vertical: true)
        case let .list(ordered, items):
            list(ordered: ordered, items: items)
        case let .codeBlock(_, code):
            codeBlock(code)
        case let .quote(lines):
            quote(lines)
        case .rule:
            Rectangle()
                .fill(Color.haDivider)
                .frame(height: DesignSystem.Border.Width.default)
        case let .table(headers, rows):
            table(headers: headers, rows: rows)
        }
    }

    // MARK: - Blocks

    private func list(ordered: Bool, items: [HAMarkdownListItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spaces.one) {
                    // Numbered from the item's own marker and counted within its own level, so a
                    // bullet nested under "1." stays a bullet and the next numbered item is "2.".
                    marker(for: item, position: Self.number(of: item, at: index, in: items))
                    Text(Self.inline(item.text))
                        .font(DesignSystem.Font.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: .zero)
                }
                .padding(.leading, CGFloat(item.indent) * Self.listIndent)
            }
        }
    }

    /// An ordered item's number counts only the ordered items at its own indent since the last time
    /// that level restarted — otherwise a nested bullet would push the numbering along with it.
    private static func number(of item: HAMarkdownListItem, at index: Int, in items: [HAMarkdownListItem]) -> Int {
        var count = 0
        for earlier in items[..<index].reversed() {
            if earlier.indent < item.indent {
                break
            }
            if earlier.indent == item.indent, earlier.ordered {
                count += 1
            }
        }
        return count
    }

    @ViewBuilder
    private func marker(for item: HAMarkdownListItem, position: Int) -> some View {
        let ordered = item.ordered
        if let checked = item.checked {
            // A GFM task list renders as checkboxes rather than bullets, and they are not
            // interactive here for the same reason they are not in the frontend: the source of
            // truth is the Markdown, which this only displays.
            MaterialDesignIconsImage(
                icon: checked ? .checkboxMarkedOutlineIcon : .checkboxBlankOutlineIcon,
                size: 16
            )
            .foregroundStyle(checked ? Color.haPrimary : .secondary)
        } else if ordered {
            Text("\(position + 1).")
                .font(DesignSystem.Font.body)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        } else {
            Text("•")
                .font(DesignSystem.Font.body)
                .foregroundStyle(.secondary)
        }
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.footnote, design: .monospaced))
            // Without this the whole block collapses to a single truncated line: text answers a
            // short height proposal by dropping to one line, and `sizeThatFits` offers exactly that.
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spaces.one)
            .background(Color.haNeutralQuietFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half))
    }

    private func quote(_ lines: [String]) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            // The bar down the left is how a `blockquote` reads in the frontend's stylesheet.
            Rectangle()
                .fill(Color.haDivider)
                .frame(width: 3)
            Text(Self.inline(lines.joined(separator: " ")))
                .font(DesignSystem.Font.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .zero)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func table(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            tableRow(headers, isHeader: true)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Rectangle()
                    .fill(Color.haDivider)
                    .frame(height: DesignSystem.Border.Width.default)
                tableRow(row, isHeader: false)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.half)
                .strokeBorder(Color.haDivider, lineWidth: DesignSystem.Border.Width.default)
        }
    }

    private func tableRow(_ cells: [String], isHeader: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spaces.one) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                Text(Self.inline(cell))
                    .font(DesignSystem.Font.body)
                    .fontWeight(isHeader ? .semibold : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spaces.one)
        .background(isHeader ? Color.haNeutralQuietFill : Color.clear)
    }

    // MARK: - Inline

    /// Emphasis, code spans and links, via Foundation. Falls back to the raw text when the inline
    /// Markdown will not parse, so a stray bracket still reads as what the author wrote rather than
    /// making the line vanish.
    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }

    private static func headingFont(level: Int) -> Font {
        switch level {
        case 1: DesignSystem.Font.title
        case 2: DesignSystem.Font.title2
        case 3: DesignSystem.Font.title3
        case 4: DesignSystem.Font.headline
        case 5: DesignSystem.Font.subheadline
        // The frontend keeps shrinking to h6, which ends up below body size. Collapsing 5 and 6
        // into one size would lose the only thing that tells them apart.
        default: DesignSystem.Font.footnote
        }
    }
}

#Preview {
    ScrollView {
        HAMarkdownText(
            """
            # Good morning

            The **kitchen** light is on and the _hallway_ is off.

            ## Today

            - [x] Coffee
            - [ ] Water the plants
              - Ferns first

            1. Unlock the door
            2. Disarm the alarm

            > The garage has been open for 2 hours.

            ```yaml
            trigger:
              platform: state
            ```

            | Room | State |
            | --- | --- |
            | Kitchen | On |
            | Hallway | Off |

            ---

            Check `sensor.power` for details.
            """
        )
        .padding()
    }
}

extension HAMarkdownText: FrontendComponent {
    public static var frontendComponentName: String { "ha-markdown" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
