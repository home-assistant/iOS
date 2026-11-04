#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import SwiftUI
import UIKit

/// Lightweight line-based YAML colorizer for the sample payloads. It only ever re-emits the
/// original characters (never inserts or drops any), so selecting and copying preserves the
/// exact source text.
@available(iOS 17.2, *)
enum YAMLSyntaxHighlighter {
    private enum Token {
        case comment
        case key
        case string
        case number
        case boolean
        case punctuation
        case value

        var color: Color {
            switch self {
            case .comment: return Color(uiColor: .secondaryLabel)
            case .key: return Color(uiColor: .systemBlue)
            case .string: return Color(uiColor: .systemGreen)
            case .number: return Color(uiColor: .systemPurple)
            case .boolean: return Color(uiColor: .systemOrange)
            case .punctuation: return Color(uiColor: .secondaryLabel)
            case .value: return Color(uiColor: .label)
            }
        }
    }

    static func highlight(_ yaml: String) -> AttributedString {
        let lines = yaml.components(separatedBy: "\n")
        var result = AttributedString()
        for (index, line) in lines.enumerated() {
            result.append(highlight(line: line))
            if index < lines.count - 1 {
                result.append(AttributedString("\n"))
            }
        }
        return result
    }

    private static func styled(_ text: String, _ token: Token) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = token.color
        return attributed
    }

    private static func highlight(line: String) -> AttributedString {
        var out = AttributedString()

        let indentCount = line.prefix { $0 == " " }.count
        out.append(AttributedString(String(line.prefix(indentCount))))
        var rest = String(line.dropFirst(indentCount))

        if rest.hasPrefix("#") {
            out.append(styled(rest, .comment))
            return out
        }

        if rest.hasPrefix("- ") {
            out.append(styled("- ", .punctuation))
            rest = String(rest.dropFirst(2))
        } else if rest == "-" {
            out.append(styled("-", .punctuation))
            return out
        }

        guard let colonIndex = rest.firstIndex(of: ":") else {
            out.append(AttributedString(rest))
            return out
        }

        out.append(styled(String(rest[..<colonIndex]), .key))
        out.append(styled(":", .punctuation))
        out.append(highlight(value: String(rest[rest.index(after: colonIndex)...])))
        return out
    }

    private static func highlight(value raw: String) -> AttributedString {
        var out = AttributedString()
        let leadingCount = raw.prefix { $0 == " " }.count
        out.append(AttributedString(String(raw.prefix(leadingCount))))
        let token = String(raw.dropFirst(leadingCount))
        guard !token.isEmpty else { return out }

        if token.hasPrefix("\"") {
            out.append(styled(token, .string))
        } else if token.hasPrefix("{") {
            out.append(highlight(flowMap: token))
        } else if isBoolean(token) {
            out.append(styled(token, .boolean))
        } else if isNumber(token) {
            out.append(styled(token, .number))
        } else {
            out.append(styled(token, .value))
        }
        return out
    }

    private static func highlight(flowMap token: String) -> AttributedString {
        var out = AttributedString()
        var word = ""
        func flush(asKey: Bool) {
            guard !word.isEmpty else { return }
            if isNumber(word) {
                out.append(styled(word, .number))
            } else if isBoolean(word) {
                out.append(styled(word, .boolean))
            } else {
                out.append(styled(word, asKey ? .key : .value))
            }
            word = ""
        }
        for character in token {
            switch character {
            case "{", "}", ",":
                flush(asKey: false)
                out.append(styled(String(character), .punctuation))
            case ":":
                flush(asKey: true)
                out.append(styled(":", .punctuation))
            case " ":
                flush(asKey: false)
                out.append(AttributedString(" "))
            default:
                word.append(character)
            }
        }
        flush(asKey: false)
        return out
    }

    private static func isBoolean(_ token: String) -> Bool {
        ["true", "false", "null", "yes", "no"].contains(token.lowercased())
    }

    private static func isNumber(_ token: String) -> Bool {
        !token.isEmpty && Double(token) != nil
    }
}

#endif
