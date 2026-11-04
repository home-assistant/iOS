import Foundation
import GRDB

/// How Assist should open when it is triggered from the Home Assistant frontend dashboard.
///
/// Only applies to the `assist/show` external bus message; widgets, shortcuts and other in-app
/// entry points keep asking for the mode they were configured with.
public enum AssistStartMode: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible, Sendable {
    /// Follow whatever the frontend requested in the `assist/show` message.
    case auto
    /// Always start listening, ignoring what the frontend requested.
    case voice
    /// Always start with the text input, ignoring what the frontend requested.
    case text

    public var id: String { rawValue }

    /// Resolves whether Assist should start recording, given what the frontend asked for.
    public func resolveAutoStartRecording(frontendRequested: Bool) -> Bool {
        switch self {
        case .auto:
            return frontendRequested
        case .voice:
            return true
        case .text:
            return false
        }
    }
}
