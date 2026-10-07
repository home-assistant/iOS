import UIKit

/// Colors Jinja template source for the template editor: literal text is secondary, expression
/// bodies primary, with delimiters, keywords, numbers, and strings tinted — a lightweight take on
/// the CodeMirror Jinja highlighting the Home Assistant frontend uses.
enum JinjaSyntaxHighlighter {
    static func highlight(
        _ text: String,
        font: UIFont,
        entityReferences: [JinjaEntityReference] = []
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: UIColor.secondaryLabel,
        ])
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)

        func apply(_ pattern: String, color: UIColor, in searchRange: NSRange) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
            for match in regex.matches(in: text, range: searchRange) {
                result.addAttribute(.foregroundColor, value: color, range: match.range)
            }
        }

        // Expression/statement blocks, including ones still being typed (unterminated).
        guard let expressionRegex = try? NSRegularExpression(
            pattern: "\\{\\{.*?\\}\\}|\\{%.*?%\\}|\\{\\{(?!.*\\}\\}).*$|\\{%(?!.*%\\}).*$",
            options: [.dotMatchesLineSeparators]
        ) else { return result }

        for match in expressionRegex.matches(in: text, range: fullRange) {
            let range = match.range
            result.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            apply(
                "\\b(if|elif|else|endif|for|endfor|in|and|or|not|is|true|false|none)\\b",
                color: .systemPurple,
                in: range
            )
            apply("\\b[A-Za-z_][A-Za-z0-9_]*(?=\\s*\\()", color: .systemTeal, in: range)
            apply("(?<=\\|)\\s*[A-Za-z_][A-Za-z0-9_]*", color: .systemTeal, in: range)
            apply("\\b\\d+(\\.\\d+)?\\b", color: .systemBlue, in: range)
            apply("'[^']*'|\"[^\"]*\"", color: .systemOrange, in: range)
            apply("\\{\\{|\\}\\}|\\{%|%\\}|\\|", color: .systemPink, in: range)
        }

        for reference in entityReferences where NSMaxRange(reference.range) <= fullRange.length {
            result.addAttributes([
                .backgroundColor: UIColor.tertiarySystemFill,
                .foregroundColor: UIColor.label,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: UIColor.haPrimary,
            ], range: reference.range)
        }

        return result
    }
}
