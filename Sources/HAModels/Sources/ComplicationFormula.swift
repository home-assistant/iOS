import Foundation

/// The content of a complication slot: an ordered mix of hardcoded text and dynamic tokens,
/// concatenated at render time by `ComplicationFormulaResolver`.
///
/// Entity-sourced complications may only use the on-device tokens (`entityName`, `state`,
/// `attribute`): they resolve from the entity fetch the watch already performs, never through
/// server-side template rendering, which is an admin-only operation. The `template` part exists
/// solely for template-sourced complications.
public struct ComplicationFormula: Codable, Equatable {
    public enum Part: Codable, Equatable {
        /// Hardcoded text, rendered verbatim.
        case text(String)
        /// The complication's display name (entity name for entity kind, the complication's own
        /// name for template kind).
        case entityName
        /// The formatted value: entity state / value attribute with precision + unit applied.
        case state
        /// A raw entity attribute by name.
        case attribute(String)
        /// A server-rendered template (template-kind complications only).
        case template(String)
    }

    public var parts: [Part]

    public init(parts: [Part]) {
        self.parts = parts
    }

    public var isEmpty: Bool { parts.isEmpty }

    /// The template sources carried by this formula, for batching server renders.
    public var templates: [String] {
        parts.compactMap {
            if case let .template(source) = $0 { return source }
            return nil
        }
    }

    // MARK: - Token string form (editor display/parsing)

    /// Token placeholders shown in (and parsed from) the editor's formula field. Template parts
    /// appear as a bare `{template}` token — the source itself is edited in the template editor and
    /// re-attached by `init(tokenString:templateSource:)`; one template part per formula.
    public enum Token {
        public static let name = "{name}"
        public static let value = "{value}"
        public static let attributePrefix = "{attr:"
        public static let template = "{template}"
    }

    /// The formula rendered as an editable token string, e.g. `"{name}: {value} kWh"`.
    public var tokenString: String {
        parts.map { part in
            switch part {
            case let .text(text): return text
            case .entityName: return Token.name
            case .state: return Token.value
            case let .attribute(name): return "\(Token.attributePrefix)\(name)}"
            case .template: return Token.template
            }
        }.joined()
    }

    /// Parses a token string back into parts. Unknown or unmatched braces are kept as literal text,
    /// so nothing a user types can fail to parse. `{template}` tokens resolve to the given source
    /// (template-kind complications edit that source in the dedicated template editor).
    public init(tokenString: String, templateSource: String? = nil) {
        var parts: [Part] = []
        var pendingText = ""

        func flushText() {
            if !pendingText.isEmpty {
                parts.append(.text(pendingText))
                pendingText = ""
            }
        }

        var remainder = Substring(tokenString)
        while let open = remainder.firstIndex(of: "{") {
            pendingText += remainder[..<open]
            let afterOpen = remainder[open...]
            guard let close = afterOpen.firstIndex(of: "}") else {
                // Unmatched "{" — literal text to the end.
                pendingText += afterOpen
                remainder = Substring()
                break
            }
            let token = String(afterOpen[...close])
            switch true {
            case token == Token.name:
                flushText()
                parts.append(.entityName)
            case token == Token.value:
                flushText()
                parts.append(.state)
            case token == Token.template:
                flushText()
                parts.append(.template(templateSource ?? ""))
            case token.hasPrefix(Token.attributePrefix) && token.count > Token.attributePrefix.count + 1:
                flushText()
                let name = String(token.dropFirst(Token.attributePrefix.count).dropLast())
                parts.append(.attribute(name))
            default:
                // Unknown token — keep it verbatim.
                pendingText += token
            }
            remainder = afterOpen[afterOpen.index(after: close)...]
        }
        pendingText += remainder
        flushText()

        self.parts = parts
    }
}
