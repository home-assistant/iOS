import Foundation

/// Which streaming methods a camera is tried over, and which one is on screen.
///
/// Kept out of `CameraPlayerView` so the cascade — the part carrying the actual rules — can be
/// exercised without standing up a player.
struct CameraPlayerPlayback: Equatable {
    /// The methods to try, most preferred first, in the order `CameraStreamPlan` put them. Empty
    /// until the camera's capabilities arrive.
    private(set) var players: [CameraPlayerType] = []
    private(set) var index = 0
    private(set) var isRacingHLS = false
    private(set) var hlsHasVideo = false

    /// The method the cascade is on, or `nil` while the capabilities are still being fetched.
    var current: CameraPlayerType? {
        players.indices.contains(index) ? players[index] : nil
    }

    var mounted: [CameraPlayerType] {
        guard let current else { return [] }
        return isRacingHLS ? [.hls, current] : [current]
    }

    var visible: CameraPlayerType? {
        isRacingHLS && hlsHasVideo ? .hls : current
    }

    /// Whether the player's own loader should cover the screen: while there is no method yet, and
    /// for WebRTC, which reports its loading state upwards. The HLS and MJPEG players draw their
    /// own, so a second spinner over theirs would never clear.
    func isLoaderVisible(webRTCIsLoading: Bool) -> Bool {
        guard let visible else { return true }
        return visible == .webRTC && webRTCIsLoading
    }

    /// Adopts a freshly resolved plan, starting from its most preferred method.
    mutating func start(with players: [CameraPlayerType]) {
        self.players = players
        index = 0
        isRacingHLS = players.first == .webRTC && players.contains(.hls)
        hlsHasVideo = false
    }

    /// Forgets the plan, so the loader covers the screen until a new one is resolved.
    mutating func clear() {
        players = []
        index = 0
        endRace()
    }

    mutating func videoStarted(on player: CameraPlayerType) {
        guard isRacingHLS else { return }
        if player == .hls {
            hlsHasVideo = true
        } else {
            endRace()
        }
    }

    private mutating func endRace() {
        isRacingHLS = false
        hlsHasVideo = false
    }

    /// Moves past `player` after it failed, returning the method now on screen.
    ///
    /// Returns `nil` — changing nothing — when `player` is not the one on screen, which is how a
    /// late failure from a method already replaced is kept from skipping an untried one, and when
    /// there is nothing left to try. HLS failing while it races WebRTC only takes HLS out of the
    /// plan.
    @discardableResult
    mutating func advance(from player: CameraPlayerType) -> CameraPlayerType? {
        if isRacingHLS, player == .hls {
            players.removeAll { $0 == .hls }
            endRace()
            return current
        }
        guard current == player, players.indices.contains(index + 1) else { return nil }
        index += 1
        endRace()
        return players[index]
    }
}
