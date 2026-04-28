import SwiftUI

/// Validation/formatting helper for notification identifier fields.
///
/// Categories and actions require identifiers containing only letters, digits
/// and underscores. Action identifiers must additionally be uppercase. This
/// replaces the old Eureka `NotificationIdentifierRow` so the constraints can
/// be reused from SwiftUI forms.
enum NotificationIdentifierField {
    /// Sanitises text in-place according to the casing rules. Spaces are
    /// replaced with underscores; any other characters outside the allowed
    /// alphanumeric+underscore set are dropped.
    static func sanitize(_ value: String, uppercaseOnly: Bool) -> String {
        let working = value.replacingOccurrences(of: " ", with: "_")
        let allowed: Set<Character>
        if uppercaseOnly {
            allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        } else {
            allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")
        }

        let filtered = working.filter { allowed.contains($0) }
        if uppercaseOnly {
            return filtered.uppercased()
        }
        return filtered
    }

    /// True when the sanitized identifier is valid (non-empty, correct casing).
    static func isValid(_ value: String, uppercaseOnly: Bool) -> Bool {
        guard !value.isEmpty else { return false }
        return sanitize(value, uppercaseOnly: uppercaseOnly) == value
    }
}

/// SwiftUI `TextField` wrapper enforcing identifier casing and validation.
///
/// - Parameters:
///   - title: Label shown above or alongside the field by the parent `Form`.
///   - text: Binding to the sanitized identifier string.
///   - uppercaseOnly: When true, only `[A-Z0-9_]` characters are allowed.
///   - isDisabled: Disables editing (used when the identifier is already set).
struct NotificationIdentifierTextField: View {
    let title: String
    @Binding var text: String
    let uppercaseOnly: Bool
    let isDisabled: Bool

    init(
        title: String,
        text: Binding<String>,
        uppercaseOnly: Bool,
        isDisabled: Bool = false
    ) {
        self.title = title
        self._text = text
        self.uppercaseOnly = uppercaseOnly
        self.isDisabled = isDisabled
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", text: Binding(
                get: { text },
                set: { newValue in
                    text = NotificationIdentifierField.sanitize(newValue, uppercaseOnly: uppercaseOnly)
                }
            ))
            .multilineTextAlignment(.trailing)
            .disableAutocorrection(true)
            .textInputAutocapitalization(uppercaseOnly ? .characters : .never)
            .keyboardType(.asciiCapable)
            .foregroundColor(
                NotificationIdentifierField.isValid(text, uppercaseOnly: uppercaseOnly) || text.isEmpty
                    ? .primary
                    : .red
            )
            .disabled(isDisabled)
        }
    }
}
