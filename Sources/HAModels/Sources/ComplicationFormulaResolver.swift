import Foundation

/// The dynamic values a formula resolves against. Built by the caller from data it already has —
/// the watch's entity fetch or the iOS live preview — so resolution itself is pure and synchronous.
/// Template parts are looked up in `renderedTemplates` (rendered ahead of time, template-kind
/// complications only); entity-kind formulas resolve entirely from the other fields, on-device.
public struct ComplicationFormulaContext {
    /// The complication's display name (entity name for entity kind, the complication's own name
    /// for template kind).
    public var entityName: String
    /// The formatted value — entity state / value attribute with precision and unit applied — the
    /// same string the value slot traditionally shows.
    public var formattedState: String
    /// Raw attribute lookup, stringified by the caller. Return nil for unknown attributes.
    public var attributeValue: (String) -> String?
    /// Pre-rendered template results keyed by template source.
    public var renderedTemplates: [String: String]

    public init(
        entityName: String,
        formattedState: String,
        attributeValue: @escaping (String) -> String? = { _ in nil },
        renderedTemplates: [String: String] = [:]
    ) {
        self.entityName = entityName
        self.formattedState = formattedState
        self.attributeValue = attributeValue
        self.renderedTemplates = renderedTemplates
    }
}

public enum ComplicationFormulaResolver {
    /// Concatenates the formula's parts against the context.
    ///
    /// Text parts adjacent to a dynamic part that resolved empty are dropped, so separators and
    /// affixes degrade gracefully: `"{name} - {value}"` with no value renders "name", not
    /// "name - "; `"Battery: {value}"` with no value renders nothing. The result is trimmed.
    public static func resolve(_ formula: ComplicationFormula, context: ComplicationFormulaContext) -> String {
        // Resolve every part first so text parts can look at both neighbors.
        let resolved: [(isDynamic: Bool, value: String)] = formula.parts.map { part in
            switch part {
            case let .text(text):
                return (false, text)
            case .entityName:
                return (true, context.entityName)
            case .state:
                return (true, context.formattedState)
            case let .attribute(name):
                return (true, context.attributeValue(name) ?? "")
            case let .template(source):
                return (true, context.renderedTemplates[source] ?? "")
            }
        }

        var output = ""
        for (index, part) in resolved.enumerated() {
            if !part.isDynamic {
                let previousEmpty = index > 0 && resolved[index - 1].isDynamic
                    && resolved[index - 1].value.isEmpty
                let nextEmpty = index + 1 < resolved.count && resolved[index + 1].isDynamic
                    && resolved[index + 1].value.isEmpty
                if previousEmpty || nextEmpty { continue }
            }
            output += part.value
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
