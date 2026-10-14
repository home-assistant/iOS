import Foundation

/// Decides what to show for a followed player, given what was shown before and what Home Assistant
/// just reported. Integrations pass through transitional reports (an Echo answering Pause can report
/// `playing → idle → paused`, or briefly clear its media attributes while changing track) and send
/// partial ones, so the two halves of a snapshot are reconciled differently:
///
/// - The **player** always comes from the newest report, except that an `indeterminate` playback state
///   keeps the previous one: the integration is not saying, which is not the same as stopped.
/// - The **track** is sticky. A report with no track keeps the last known media for as long as the
///   player is followed; ending or resetting that belongs to the follow/session layer, not here. A
///   report describing the same track fills in what it lacks, and one describing a different track
///   replaces it outright, so nothing of the old track leaks into the new. The cover is part of the
///   track: a report that leaves the picture out keeps the known one, since Home Assistant leaves it out
///   both when there is none and while an integration refreshes.
///
/// `previous` must be this same player's last reconciled state, not what was displayed from it; a state
/// for another player traps.
public enum RemoteMediaSnapshotReducer {
    public static func reduce(
        previous: RemoteMediaEntityState?,
        incoming: RemoteMediaEntityState
    ) -> RemoteMediaEntityState {
        precondition(
            previous == nil || previous?.playerScope == incoming.playerScope,
            "Reports for different players cannot be reconciled"
        )
        let player = incoming.snapshot.player.playback == .indeterminate
            ? incoming.snapshot.player.with(playback: previous?.snapshot.player.playback ?? .indeterminate)
            : incoming.snapshot.player

        let track: RemoteMediaTrack?
        let artworkSource: RemoteMediaArtworkSource?
        switch (previous?.snapshot.track, incoming.snapshot.track) {
        case let (previousTrack?, incomingTrack?) where isSameTrack(previousTrack, incomingTrack):
            track = merging(incomingTrack, onto: previousTrack)
            // A source for the picture already held is not a new one, so it keeps the cache identity it
            // was created with.
            artworkSource = incoming.artworkSource.flatMap {
                $0.reference == previous?.artworkSource?.reference ? previous?.artworkSource : $0
            } ?? previous?.artworkSource
        case let (_, incomingTrack?):
            track = incomingTrack
            artworkSource = incoming.artworkSource
        case let (previousTrack, nil):
            track = previousTrack
            artworkSource = previous?.artworkSource
        }
        return RemoteMediaEntityState(
            snapshot: RemoteMediaSnapshot(player: player, track: track),
            artworkSource: artworkSource,
            playerScope: incoming.playerScope
        )
    }

    /// Whether two reports describe the same track: they share identifying evidence and nothing both
    /// state conflicts. A missing value is incomplete, not different, so only values present in both are
    /// compared.
    ///
    /// - Different `contentKey`s, or a different `title`, `artist` or `album` even under the same
    ///   `contentKey` (radio streams keep one id across songs), are different tracks.
    /// - Otherwise a shared `contentKey`, or without one at least one matching `title`, `artist` or
    ///   `album`, is the same track. With no evidence in common, such as a content key alone followed by
    ///   a title alone, they are treated as different: leaking an unrelated track's metadata is worse.
    private static func isSameTrack(_ previous: RemoteMediaTrack, _ incoming: RemoteMediaTrack) -> Bool {
        let descriptive = [
            (previous.title, incoming.title),
            (previous.artist, incoming.artist),
            (previous.album, incoming.album),
        ]
        if let previousKey = previous.contentKey, let incomingKey = incoming.contentKey {
            if previousKey != incomingKey { return false }
        }
        for case let (previousValue?, incomingValue?) in descriptive where previousValue != incomingValue {
            return false
        }
        if previous.contentKey != nil, previous.contentKey == incoming.contentKey { return true }
        return descriptive.contains { previousValue, incomingValue in
            previousValue != nil && previousValue == incomingValue
        }
    }

    /// The same track, each value from `incoming` when it has one. Position and its timestamp move
    /// together, so a report without a usable position (missing or invalid) keeps the previous pair rather
    /// than mixing the two.
    private static func merging(_ incoming: RemoteMediaTrack, onto previous: RemoteMediaTrack) -> RemoteMediaTrack {
        let measured = incoming.position == nil ? previous : incoming
        // Both tracks already have something to identify them by, so neither can the merged one.
        return RemoteMediaTrack(
            title: incoming.title ?? previous.title,
            artist: incoming.artist ?? previous.artist,
            album: incoming.album ?? previous.album,
            contentKey: incoming.contentKey ?? previous.contentKey,
            duration: incoming.duration ?? previous.duration,
            position: measured.position,
            positionUpdatedAtUnix: measured.positionUpdatedAtUnix,
            artwork: incoming.artwork == .absent ? previous.artwork : incoming.artwork
        ) ?? incoming
    }
}
