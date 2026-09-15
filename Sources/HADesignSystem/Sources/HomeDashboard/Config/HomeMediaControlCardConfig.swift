import Foundation

/// A media player as its now-playing card: what it is playing, and the controls to change it. The
/// media-players view uses these instead of tiles, the way the web dashboard does.
public struct HomeMediaControlCardConfig: Equatable, Sendable {
    public let entityId: String

    public init(entityId: String) {
        self.entityId = entityId
    }
}
