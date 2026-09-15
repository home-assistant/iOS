import Foundation

/// What the server is doing, as far as the dashboard is concerned. Home Assistant reports a good few
/// more states; the dashboard only branches on these three.
public enum HomeServerState: Equatable, Sendable {
    /// Up and serving states.
    case running
    /// Still starting: the frontend shows a "starting" card rather than an empty home.
    case starting
    /// Started in recovery mode, where there is nothing to show but the fact.
    case recovery
}
