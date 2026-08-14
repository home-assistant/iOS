import Foundation

/// Failures of `HomeAssistantConfigFlowClient` that aren't already a transport error.
public enum HomeAssistantConfigFlowError: LocalizedError, Equatable {
    /// The server answered with something that isn't a config flow envelope.
    case unexpectedResponse

    public var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return L10n.AppIntents.Error.invalidResponse
        }
    }
}
