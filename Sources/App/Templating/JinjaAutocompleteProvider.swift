import Foundation

/// Computes autocomplete suggestions for a Jinja template at a cursor position, mirroring what the
/// Home Assistant frontend's template editor offers: entity ids inside quotes, template functions
/// and keywords inside expressions, filters after a pipe, and expression openers in literal text.
struct JinjaAutocompleteProvider {
    /// Entity ids of the selected server, offered inside quoted strings.
    var entityIds: [String]

    /// Call-style helpers and no-argument functions the frontend's editor completes.
    static let functions: [String] = [
        "states('')", "is_state('', '')", "state_attr('', '')", "is_state_attr('', '', '')",
        "has_value('')", "now()", "utcnow()", "as_timestamp()", "iif()",
    ]

    /// Common filters, offered after a `|`.
    static let filters: [String] = [
        "round(2)", "int", "float", "abs", "lower", "upper", "title",
        "replace('', '')", "default('')", "timestamp_custom('%H:%M')",
    ]

    static let keywords: [String] = [
        "if", "else", "elif", "endif", "for", "endfor", "in", "and", "or", "not", "is",
        "true", "false", "none",
    ]

    /// Suggestions for `text` with the cursor at `cursorLocation` (UTF-16, as UITextView reports).
    func suggestions(text: String, cursorLocation: Int) -> [JinjaTemplateSuggestion] {
        let nsText = text as NSString
        guard cursorLocation >= 0, cursorLocation <= nsText.length else { return [] }
        let before = nsText.substring(to: cursorLocation)

        // Outside any expression → offer to open one.
        guard let expression = openExpression(in: before) else {
            return [
                JinjaTemplateSuggestion(label: "{{ }}", insertion: "{{  }}", cursorOffsetFromEnd: 3),
                JinjaTemplateSuggestion(label: "{% %}", insertion: "{%  %}", cursorOffsetFromEnd: 3),
            ]
        }

        // Inside an open quote → entity ids, filtered by the typed prefix.
        if let quotedPrefix = openQuotedPrefix(in: expression) {
            return entityIds
                .filter { quotedPrefix.isEmpty || $0.localizedCaseInsensitiveContains(quotedPrefix) }
                .prefix(15)
                .map { JinjaTemplateSuggestion(
                    label: $0,
                    insertion: $0,
                    replacingCount: (quotedPrefix as NSString).length
                ) }
        }

        let word = trailingWord(in: before)
        let replacing = (word as NSString).length

        // After a pipe → filters.
        if isAfterPipe(before, wordLength: replacing) {
            return Self.filters
                .filter { word.isEmpty || $0.hasPrefix(word) }
                .map { JinjaTemplateSuggestion(label: $0, insertion: $0, replacingCount: replacing) }
        }

        // Plain identifier → functions + keywords. Call-style completions land the cursor inside
        // the first quotes/parens.
        return (Self.functions + Self.keywords)
            .filter { word.isEmpty || $0.hasPrefix(word) }
            .prefix(15)
            .map { name in
                JinjaTemplateSuggestion(
                    label: name,
                    insertion: name,
                    replacingCount: replacing,
                    cursorOffsetFromEnd: cursorBackOffset(for: name)
                )
            }
    }

    /// The content of the innermost expression (`{{ …` or `{% …`) still open at the cursor, or nil
    /// when the cursor sits in literal text.
    private func openExpression(in before: String) -> String? {
        let openers = ["{{", "{%"]
        let closers = ["}}", "%}"]
        var lastOpenRange: Range<String.Index>?
        for opener in openers {
            if let range = before.range(of: opener, options: .backwards),
               lastOpenRange == nil || range.lowerBound > lastOpenRange!.lowerBound {
                lastOpenRange = range
            }
        }
        guard let openRange = lastOpenRange else { return nil }
        let tail = String(before[openRange.upperBound...])
        // Closed again before the cursor → literal text.
        guard !closers.contains(where: { tail.contains($0) }) else { return nil }
        return tail
    }

    /// The typed prefix inside an unterminated quote, or nil when no quote is open.
    private func openQuotedPrefix(in expression: String) -> String? {
        var openQuote: Character?
        var prefixStart: String.Index?
        var index = expression.startIndex
        while index < expression.endIndex {
            let character = expression[index]
            if let quote = openQuote {
                if character == quote {
                    openQuote = nil
                    prefixStart = nil
                }
            } else if character == "'" || character == "\"" {
                openQuote = character
                prefixStart = expression.index(after: index)
            }
            index = expression.index(after: index)
        }
        guard openQuote != nil, let start = prefixStart else { return nil }
        return String(expression[start...])
    }

    /// The identifier being typed immediately before the cursor.
    private func trailingWord(in before: String) -> String {
        String(before.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" }.reversed())
    }

    /// Whether the token before the current word is a Jinja filter pipe.
    private func isAfterPipe(_ before: String, wordLength: Int) -> Bool {
        let untilWord = (before as NSString).substring(to: (before as NSString).length - wordLength)
        guard let last = untilWord.reversed().first(where: { !$0.isWhitespace }) else { return false }
        return last == "|"
    }

    /// Where call-style completions should leave the cursor: inside the first quotes, else inside
    /// the parens, else at the end.
    private func cursorBackOffset(for completion: String) -> Int {
        if let range = completion.range(of: "''") {
            return (String(completion[range.upperBound...]) as NSString).length + 1
        }
        if completion.hasSuffix("()") { return 1 }
        return 0
    }
}
