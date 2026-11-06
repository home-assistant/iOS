import Foundation

/// What asking the server for a camera's capabilities came back with.
///
/// The two failure shapes mean different things for the player: a server that answered but could
/// not say (an older core, a rejected request) leaves every stream type worth trying, while a
/// server that never answered has a WebSocket that cannot carry WebRTC signaling either.
enum CameraCapabilitiesFetchOutcome: Equatable {
    /// The server replied; `nil` when the request failed or the server predates the command.
    case answered(CameraCapabilities?)
    /// The request went into the WebSocket and nothing came back within the timeout.
    case unanswered

    /// The capabilities the server reported, if it reported any.
    var capabilities: CameraCapabilities? {
        switch self {
        case let .answered(capabilities):
            return capabilities
        case .unanswered:
            return nil
        }
    }
}
