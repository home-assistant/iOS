import Foundation

/// Computes the entity suggestions shown under the Jinja editor, and how a picked entity should be
/// inserted at the cursor: matching the typed prefix inside an open quote, as a `states('…')` call
/// inside an expression, or wrapped in a whole `{{ states('…') }}` expression in literal text.
struct JinjaAutocompleteProvider {
    /// Entity ids of the selected server.
    var entityIds: [String]

    /// The suggestions for the footer pills. Empty until the user is typing an entity id — i.e.
    /// inside an open quote — then filtered by the typed prefix.
    func entitySuggestions(text: String, cursorLocation: Int, limit: Int = 5) -> [JinjaTemplateSuggestion] {
        guard let prefix = quotedPrefix(text: text, cursorLocation: cursorLocation) else { return [] }
        return entityIds
            .filter { prefix.isEmpty || $0.localizedCaseInsensitiveContains(prefix) }
            .prefix(limit)
            .map { JinjaTemplateSuggestion(
                label: $0,
                insertion: $0,
                replacingCount: (prefix as NSString).length
            ) }
    }

    /// The text being typed inside an open quote at the cursor — what the pills are filtered by,
    /// and what the entity picker's search is pre-seeded with.
    func quotedPrefix(text: String, cursorLocation: Int) -> String? {
        let nsText = text as NSString
        guard cursorLocation >= 0, cursorLocation <= nsText.length else { return nil }
        let before = nsText.substring(to: cursorLocation)
        guard let expression = openExpression(in: before) else { return nil }
        return openQuotedPrefix(in: expression)
    }

    /// How to insert a specific entity id (pill tap or entity picker) at the cursor.
    func entityInsertion(for entityId: String, text: String, cursorLocation: Int) -> JinjaTemplateSuggestion {
        let nsText = text as NSString
        let before = nsText.substring(to: min(max(cursorLocation, 0), nsText.length))

        guard let expression = openExpression(in: before) else {
            // Literal text → a whole expression.
            return JinjaTemplateSuggestion(label: entityId, insertion: "{{ states('\(entityId)') }}")
        }
        if let prefix = openQuotedPrefix(in: expression) {
            // Inside an open quote → the bare id, replacing whatever was typed.
            return JinjaTemplateSuggestion(
                label: entityId,
                insertion: entityId,
                replacingCount: (prefix as NSString).length
            )
        }
        // Inside an expression → a states() call.
        return JinjaTemplateSuggestion(label: entityId, insertion: "states('\(entityId)')")
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
}
