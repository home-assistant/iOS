import Foundation

/// Error surfaced to the user by App Intents, carrying an already-localized message.
///
/// App Intents show `errorDescription` verbatim in Shortcuts / Siri, so every message that reaches
/// here is expected to be user-facing text rather than a debug description.
public struct ShortcutAppIntentError: LocalizedError {
    public let errorDescription: String?

    public init(_ errorDescription: String) {
        self.errorDescription = errorDescription
    }
}
