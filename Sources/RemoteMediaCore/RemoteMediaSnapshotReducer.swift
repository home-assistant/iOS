import Foundation

/// Decides what the Now Playing card should show, given what it showed before and what Home
/// Assistant just reported.
///
/// "Follow in Now Playing" means follow this player until I stop following it — not "show a card
/// only while Home Assistant says `playing`". Integrations pass through transitional states on the
/// way to a settled one: an Echo answering Pause can report `playing → idle → paused`, and can
/// briefly clear its media attributes entirely while changing track. Treating those as the end of
/// playback removes the card exactly when the user is pressing buttons on it.
///
/// So this keeps the last meaningful media across transitional states and reports the playback
/// state that best describes them. It is a general resilience policy, deliberately not keyed on any
/// integration's name.
public enum RemoteMediaSnapshotReducer {
    /// The snapshot to display, or `nil` when nothing meaningful has ever been seen for this
    /// selection and there is therefore nothing to show yet.
    public static func reduce(
        previous: RemoteMediaSnapshot?,
        incoming: RemoteMediaSnapshot
    ) -> RemoteMediaSnapshot? {
        let playback = RemoteMediaPlaybackState(homeAssistantState: incoming.state)

        // A real track: take it wholesale. A genuinely new track must not keep any of the previous
        // one's identity, least of all its artwork.
        if incoming.hasMeaningfulMedia {
            guard let previous, previous.trackId == incoming.trackId else {
                return incoming
            }
            // Same track: let the dynamic values move and leave stable metadata alone.
            // Artwork can arrive after the metadata, especially when the host app finishes
            // preparing an authenticated source after it has already published the track.
            return incoming.withArtwork(incoming.artwork ?? previous.artwork)
        }

        // No meaningful media in this report. Without something to fall back on there is nothing
        // to show; the selection stays followed, so the next meaningful report starts the card.
        guard let previous, previous.hasMeaningfulMedia else { return nil }

        // Retain the media and describe the transition. `indeterminate` (`unavailable`/`unknown`)
        // means the integration stopped reporting, which is not the same as having stopped, so the
        // last known playback state is kept rather than inventing one.
        let retainedState = playback == .indeterminate ? previous.state : incoming.state
        return previous
            .withState(retainedState)
            .withPosition(previous.position, updatedAtUnix: previous.positionUpdatedAtUnix)
    }

    /// Whether a selection should stop being followed altogether.
    ///
    /// Only a selection that can never report again is terminal. `unavailable` is not: an Echo
    /// drops off and comes back, and tearing the session down would lose the card for good.
    public static func isTerminal(entityExists: Bool) -> Bool {
        !entityExists
    }
}
