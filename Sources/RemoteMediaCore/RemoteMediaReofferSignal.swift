import Foundation

/// The host app asking the extension to offer its registration to Home Assistant again.
///
/// The APNs update token belongs to the Now Playing session and never leaves the extension, so the
/// host app cannot register on its behalf. What it can do is say "the server may no longer have
/// this" — after a launch, a foreground, or a server reconnect — and leave that where the extension
/// will find it the next time the system runs it.
///
/// A counter rather than a flag, and in the App Group rather than in memory, because the two
/// processes do not overlap: a request raised while nothing of ours is running has to still be
/// there afterwards, and one that has already been acted on must not be acted on twice. The
/// extension records the value it honoured; anything higher is news.
///
/// Nothing secret is written here. The value is an integer, and the token it eventually causes to
/// be sent is read inside the extension and posted from there.
public enum RemoteMediaReofferSignal {
    private static let key = "remoteMediaRegistrationReofferEpoch"

    /// Where the request is kept. Replaced in tests, so exercising it never writes to the App
    /// Group the running app shares — and so one test's request cannot become another's.
    public static var defaults: UserDefaults? = RemoteMediaAppGroup.identifier
        .flatMap(UserDefaults.init(suiteName:))

    /// The newest request. `0` when none has ever been made.
    public static var epoch: Int {
        defaults?.integer(forKey: key) ?? 0
    }

    /// Asks for the current registration to be offered again.
    ///
    /// Host app only, and deliberately cheap: it says nothing about which relationship, because
    /// the extension already knows which one it is in. Raising it does not end a Follow, does not
    /// change its generation, and does not advance its sequence — the relationship is untouched
    /// and Home Assistant treats the resulting registration as the no-op it is.
    public static func request() {
        guard let defaults else { return }
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    /// Forgets any outstanding request. Used when nothing is followed any more.
    public static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
