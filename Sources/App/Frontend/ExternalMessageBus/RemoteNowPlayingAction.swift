@preconcurrency import Shared

/// Action to follow — or stop following — a media player in the phone's system media controls.
///
/// Unlike the other actions this one is state-aware: `isFollowing` is what the app knew when the
/// frontend asked for the entity's actions, and it only decides what the row says. What tapping it
/// does is worked out again from the persisted selection, because the followed player can change
/// between the frontend building the list and the user choosing from it.
@available(iOS 27.0, *)
struct RemoteNowPlayingAction: EntityAddToAction {
    /// `true` when this exact server and entity was the followed one, which makes the row read
    /// "stop following" rather than offering to follow it again.
    let isFollowing: Bool

    init(isFollowing: Bool = false) {
        self.isFollowing = isFollowing
    }

    var mdiIcon: String { "mdi:speaker-play" }
    var actionType: String { EntityAddToActionType.remoteNowPlaying.rawValue }

    func text() -> String {
        isFollowing
            ? L10n.WebView.AddTo.Option.RemoteNowPlaying.stopTitle
            : L10n.WebView.AddTo.Option.RemoteNowPlaying.title
    }

    func details() -> String? {
        isFollowing
            ? L10n.WebView.AddTo.Option.RemoteNowPlaying.stopDetails
            : L10n.WebView.AddTo.Option.RemoteNowPlaying.details
    }
}
