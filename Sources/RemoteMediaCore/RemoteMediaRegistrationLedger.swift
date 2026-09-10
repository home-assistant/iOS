import Foundation

/// Decides whether a push token still needs telling the server about.
///
/// Two things have to be true before a registration goes out: it has to say something new, and it
/// has to describe the Follow relationship the session is actually in. Token delivery is
/// asynchronous, so a registration built while the previous relationship was current can arrive
/// after the user has stopped following and followed again — registering it then would hand the
/// server a token for a relationship it has already replaced.
///
/// This is only local race protection. It is not, and must not become, a record that the server
/// has stored anything: see `RemoteMediaSessionRegistrar` for why that distinction is what makes
/// the feature arrive on its own after Home Assistant is upgraded.
@MainActor
public final class RemoteMediaRegistrationLedger {
    private var lifetime: RemoteMediaFollowLifetime?
    private var sent: RemoteMediaSessionRegistration?

    public init() {}

    /// Adopts the Follow relationship the newest attributes describe. A change means whatever was
    /// registered belongs to a relationship that is over, so the current token is registered again.
    ///
    /// Compared for equality, never for order: a generation is an identity, and the sequence beside
    /// it exists so the *server* can order two relationships, not so this can pick a winner.
    public func adopt(lifetime: RemoteMediaFollowLifetime?) {
        guard lifetime != self.lifetime else { return }
        self.lifetime = lifetime
        sent = nil
    }

    /// The registration to send, or `nil` when there is nothing new to say.
    ///
    /// The comparison covers the whole payload, so the dedupe key is the session, the generation,
    /// the sequence and the token together — a change in any of them is news.
    public func pending(_ registration: RemoteMediaSessionRegistration) -> RemoteMediaSessionRegistration? {
        guard registration.lifetime == lifetime else { return nil }
        guard registration != sent else { return nil }
        sent = registration
        return registration
    }

    /// Offers whatever is current again, without touching the relationship.
    ///
    /// For the case the ledger cannot see: the request was accepted and the server did not keep it
    /// — it predated the feature, or its stored session is gone. A success proves only that the
    /// request was read, so nothing here can distinguish that from a registration that landed, and
    /// the host app is what notices and asks.
    ///
    /// The Follow relationship is deliberately untouched: re-offering is the same registration
    /// again, not a new one, so the generation and its place in the order stay exactly as they are.
    public func rearm() {
        sent = nil
    }

    /// Puts a registration back, so the next thing that would have offered it does.
    ///
    /// For the case where the request never reached anyone: the token is still owed to the server,
    /// and the host app publishing the next state change is a free chance to try again. A server
    /// that answered and refused is deliberately not released — repeating a request the server has
    /// already read and rejected would turn every state change into a pointless POST.
    public func release(_ registration: RemoteMediaSessionRegistration) {
        guard sent == registration else { return }
        sent = nil
    }
}
