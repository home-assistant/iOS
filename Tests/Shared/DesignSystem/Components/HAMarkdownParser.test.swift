@testable import HADesignSystem
import Testing

/// The block layer `AttributedString` drops. Inline syntax is not tested here — Foundation owns it.
struct HAMarkdownParserTests {
    @Test func headingsCarryTheirLevel() {
        #expect(HAMarkdownParser.parse("## Today") == [.heading(level: 2, text: "Today")])
    }

    /// CommonMark needs a space after the hashes; without one it is a paragraph, which matters for
    /// text like "#1 priority".
    @Test func hashesWithoutASpaceAreNotAHeading() {
        #expect(HAMarkdownParser.parse("#1 priority") == [.paragraph("#1 priority")])
    }

    @Test func closedAtxHeadingsDropTheirTrailingHashes() {
        #expect(HAMarkdownParser.parse("### Kitchen ###") == [.heading(level: 3, text: "Kitchen")])
    }

    /// Seven hashes is not a level-7 heading; there is no such thing.
    @Test func sevenHashesIsAParagraph() {
        #expect(HAMarkdownParser.parse("####### Deep") == [.paragraph("####### Deep")])
    }

    @Test func softLineBreaksJoinIntoOneParagraph() {
        #expect(HAMarkdownParser.parse("One line\nand another") == [.paragraph("One line and another")])
    }

    @Test func blankLinesSeparateParagraphs() {
        #expect(HAMarkdownParser.parse("First\n\nSecond") == [.paragraph("First"), .paragraph("Second")])
    }

    /// A heading may interrupt a paragraph without a blank line before it, as `marked` allows.
    @Test func aHeadingEndsTheParagraphBeforeIt() {
        #expect(HAMarkdownParser.parse("Text\n# Heading") == [
            .paragraph("Text"),
            .heading(level: 1, text: "Heading"),
        ])
    }

    @Test func bulletsBecomeAnUnorderedList() {
        #expect(HAMarkdownParser.parse("- One\n- Two") == [
            .list(ordered: false, items: [.init(text: "One"), .init(text: "Two")]),
        ])
    }

    @Test func numbersBecomeAnOrderedList() {
        #expect(HAMarkdownParser.parse("1. First\n2. Second") == [
            .list(ordered: true, items: [
                .init(text: "First", number: 1),
                .init(text: "Second", number: 2),
            ]),
        ])
    }

    @Test func indentedItemsRecordTheirDepth() {
        let blocks = HAMarkdownParser.parse("- Top\n  - Nested")
        #expect(blocks == [
            .list(ordered: false, items: [
                .init(indent: 0, text: "Top"),
                .init(indent: 1, text: "Nested"),
            ]),
        ])
    }

    /// `5. Fifth` is valid GFM and starts the list at five; renumbering from one would contradict
    /// the source.
    @Test func anOrderedListKeepsTheOrdinalItWasWrittenWith() {
        #expect(HAMarkdownParser.parse("5. Fifth\n6. Sixth") == [
            .list(ordered: true, items: [
                .init(text: "Fifth", number: 5),
                .init(text: "Sixth", number: 6),
            ]),
        ])
    }

    /// A four-backtick fence is closed only by four or more; a three-backtick line inside it is
    /// code, which is how a Markdown sample containing a fence is written.
    @Test func aLongerFenceIsNotClosedByAShorterOne() {
        #expect(HAMarkdownParser.parse("````\n```\nstill code\n````") == [
            .codeBlock(language: nil, code: "```\nstill code"),
        ])
    }

    /// A bullet nested under a numbered item is a bullet. Taking the list's kind from its first
    /// line would renumber it as the parent's next entry — "1. Parent" then "2. Child".
    @Test func aNestedBulletKeepsItsOwnMarkerKind() {
        let blocks = HAMarkdownParser.parse("1. Parent\n  - Child")
        #expect(blocks == [
            .list(ordered: true, items: [
                .init(indent: 0, text: "Parent", number: 1),
                .init(indent: 1, text: "Child"),
            ]),
        ])
    }

    @Test func taskListsRecordWhetherTheyAreTicked() {
        #expect(HAMarkdownParser.parse("- [x] Done\n- [ ] Todo") == [
            .list(ordered: false, items: [
                .init(text: "Done", checked: true),
                .init(text: "Todo", checked: false),
            ]),
        ])
    }

    @Test func fencedCodeKeepsItsLanguageAndLineBreaks() {
        #expect(HAMarkdownParser.parse("```yaml\ntrigger:\n  platform: state\n```") == [
            .codeBlock(language: "yaml", code: "trigger:\n  platform: state"),
        ])
    }

    /// A fence closes only on its own marker, so a ``` block may contain ~~~ without ending early.
    @Test func aMismatchedFenceDoesNotCloseTheBlock() {
        #expect(HAMarkdownParser.parse("```\n~~~\nstill code\n```") == [
            .codeBlock(language: nil, code: "~~~\nstill code"),
        ])
    }

    /// Markdown inside a fence is text, not markup — otherwise a code sample of Markdown would
    /// render as the thing it documents.
    @Test func markdownInsideAFenceIsNotParsed() {
        #expect(HAMarkdownParser.parse("```\n# Not a heading\n- not a bullet\n```") == [
            .codeBlock(language: nil, code: "# Not a heading\n- not a bullet"),
        ])
    }

    @Test func quotesDropTheirMarker() {
        #expect(HAMarkdownParser.parse("> Garage open\n> for 2 hours") == [
            .quote(["Garage open", "for 2 hours"]),
        ])
    }

    @Test func threeOrMoreMarkersAreAThematicBreak() {
        #expect(HAMarkdownParser.parse("---") == [.rule])
        #expect(HAMarkdownParser.parse("***") == [.rule])
        #expect(HAMarkdownParser.parse("___") == [.rule])
    }

    @Test func twoMarkersAreNotAThematicBreak() {
        #expect(HAMarkdownParser.parse("--") == [.paragraph("--")])
    }

    @Test func tablesSplitIntoHeadersAndRows() {
        let blocks = HAMarkdownParser.parse(
            """
            | Room | State |
            | --- | --- |
            | Kitchen | On |
            | Hallway | Off |
            """
        )
        #expect(blocks == [
            .table(headers: ["Room", "State"], rows: [["Kitchen", "On"], ["Hallway", "Off"]]),
        ])
    }

    /// GFM makes the outer pipes optional, and an alignment row still marks a table.
    @Test func tablesWithoutOuterPipesAndWithAlignmentStillParse() {
        #expect(HAMarkdownParser.parse("Room | State\n:--- | ---:\nKitchen | On") == [
            .table(headers: ["Room", "State"], rows: [["Kitchen", "On"]]),
        ])
    }

    /// Pipes alone do not make a table; without the delimiter row they are ordinary text.
    @Test func pipesWithoutADelimiterRowAreAParagraph() {
        #expect(HAMarkdownParser.parse("a | b\nc | d") == [.paragraph("a | b c | d")])
    }

    @Test func aDocumentParsesIntoItsBlocksInOrder() {
        let blocks = HAMarkdownParser.parse(
            """
            # Title

            Some prose.

            - One

            > Quoted

            ---
            """
        )
        #expect(blocks == [
            .heading(level: 1, text: "Title"),
            .paragraph("Some prose."),
            .list(ordered: false, items: [.init(text: "One")]),
            .quote(["Quoted"]),
            .rule,
        ])
    }

    @Test func emptyInputParsesToNoBlocks() {
        #expect(HAMarkdownParser.parse("").isEmpty)
        #expect(HAMarkdownParser.parse("\n\n  \n").isEmpty)
    }
}
