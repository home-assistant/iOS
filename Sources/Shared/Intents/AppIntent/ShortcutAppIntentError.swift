import Foundation

/// Error surfaced to the user by App Intents, carrying an already-localized message.
///
/// Every message that reaches here is expected to be user-facing text rather than a debug
/// description, because Shortcuts and Siri show it verbatim.
public struct ShortcutAppIntentError: LocalizedError {
    public let errorDescription: String?

    public init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}

/// App Intents reads this, not `errorDescription`, when it decides what to tell the user: an error
/// that doesn't carry one is reported to Siri as a generic failure with the reason dropped.
extension ShortcutAppIntentError: CustomLocalizedStringResourceConvertible {
    public var localizedStringResource: LocalizedStringResource {
        .init(stringLiteral: errorDescription ?? "")
    }
}
