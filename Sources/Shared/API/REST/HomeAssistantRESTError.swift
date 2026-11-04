import Foundation

/// Failures of a `HomeAssistantRESTClient` request that aren't already a `URLError`.
public enum HomeAssistantRESTError: LocalizedError, Equatable {
    /// The response wasn't an HTTP response at all.
    case invalidResponse
    /// The server answered with a status outside 2xx. The body is kept because Home Assistant puts
    /// its reason there (e.g. a rejected template renders its Jinja error).
    case unacceptableStatus(code: Int, body: String?)
    /// A bearer token could not be obtained before the deadline elapsed.
    case tokenUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return L10n.AppIntents.Error.invalidResponse
        case let .unacceptableStatus(code, body):
            guard let body = body?.trimmingCharacters(in: .whitespacesAndNewlines), body.isEmpty == false else {
                return L10n.AppIntents.Error.httpStatus(code)
            }
            return "\(L10n.AppIntents.Error.httpStatus(code)) - \(body)"
        case .tokenUnavailable:
            return L10n.AppIntents.Error.tokenUnavailable
        }
    }
}
