import Foundation

/// A player's snapshot plus the local-only source of its cover.
///
/// This is what `RemoteMediaSnapshotMapper` reads from one report and what `RemoteMediaSnapshotReducer`
/// reconciles reports into; the reconciled state is the `previous` of the next report. The snapshot is
/// safe to publish and `artworkSource` is not. What to show is derived with
/// `displayedSnapshot(preparedArtworkFrom:)`, which returns a plain snapshot that cannot be fed back in.
public struct RemoteMediaEntityState: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let snapshot: RemoteMediaSnapshot
    /// Where to fetch the cover of `snapshot.track`. Non-`nil` exactly when that cover is `deferred`.
    public let artworkSource: RemoteMediaArtworkSource?
    /// A digest of the server and entity this state describes, so reports for different players cannot
    /// be reconciled into one another. Local only; it is not part of the snapshot.
    let playerScope: RemoteMediaDigest

    init(snapshot: RemoteMediaSnapshot, artworkSource: RemoteMediaArtworkSource?, playerScope: RemoteMediaDigest) {
        precondition(
            (artworkSource != nil) == (snapshot.track?.artwork == .deferred),
            "A source exists exactly when the track's cover is deferred"
        )
        self.snapshot = snapshot
        self.artworkSource = artworkSource
        self.playerScope = playerScope
    }

    /// The snapshot to show, with the cover prepared from `source` attached.
    ///
    /// Attached only when `source` is this state's own, so a cover prepared for another picture, track
    /// or player never shows, even at the same address. The caller prepares again whenever
    /// `artworkSource` differs from what it last prepared, stores the result under `source.cacheKey`, and
    /// passes it here; until then the track shows no cover rather than the old one.
    public func displayedSnapshot(preparedArtworkFrom source: RemoteMediaArtworkSource) -> RemoteMediaSnapshot {
        guard source == artworkSource, let track = snapshot.track else { return snapshot }
        return RemoteMediaSnapshot(
            player: snapshot.player,
            track: track.with(artwork: .available(cacheKey: source.cacheKey))
        )
    }

    /// Only the publishable snapshot is printed; the artwork source and the player scope are left out.
    public var description: String { "RemoteMediaEntityState(snapshot: \(snapshot))" }
    public var debugDescription: String { description }
}
