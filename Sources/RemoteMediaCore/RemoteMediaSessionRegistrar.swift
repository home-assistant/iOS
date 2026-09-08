import Foundation

/// Offers this session's APNs update token to Home Assistant, once per thing worth saying.
///
/// Registration is deliberately at-least-once rather than once-ever. A Home Assistant that does not
/// yet understand the webhook answers it with an empty 200, so a success proves only that the
/// request was accepted — there is no reply that means "this server will push your card", and
/// nothing here records one. What makes the feature arrive on its own after the server is upgraded
/// is that the offer is repeated every time a representation is created: the token is re-offered by
/// the next extension launch, and the upgraded server stores it then. Home Assistant treats an
/// identical registration as a no-op, so repeating it costs the server nothing.
///
/// Within one representation the offer is made once, because the host app publishes many state
/// updates per track and the token is the same for all of them. That "already offered" state is
/// therefore runtime-only, and must stay that way: persisting it would be the one thing that could
/// stop an upgraded server from ever being told.
@MainActor
public final class RemoteMediaSessionRegistrar {
    private let ledger = RemoteMediaRegistrationLedger()
    private let sender: RemoteMediaRegistrationSender
    /// The Follow relationship the newest attributes describe.
    private var lifetime: RemoteMediaFollowLifetime?
    /// The host app's newest re-offer request that has already been acted on. Runtime-only, like
    /// the ledger it re-arms: a persisted record of having registered is the one thing that could
    /// stop an upgraded server from ever being told.
    private var honouredReoffer: Int?

    /// A default of `nil` rather than a fresh sender: a default argument is evaluated outside the
    /// actor, and building one there is isolation the compiler will not grant.
    public init(sender: RemoteMediaRegistrationSender? = nil) {
        self.sender = sender ?? RemoteMediaRegistrationSender()
    }

    /// Adopts the Follow relationship the newest attributes describe.
    ///
    /// A change means the token registered so far belongs to a relationship the user has ended, so
    /// the current one is offered again — the session identifier is derived from the server and the
    /// entity, so following the same player again reuses it and only the lifetime tells the two
    /// relationships apart.
    public func adopt(lifetime: RemoteMediaFollowLifetime?) {
        guard lifetime != self.lifetime else { return }
        self.lifetime = lifetime
        // A registration still in flight belongs to the relationship that just ended.
        sender.cancel()
        ledger.adopt(lifetime: lifetime)
    }

    /// Acts on a host-app request to offer the registration again.
    ///
    /// Called before every offer rather than on a timer: the host app cannot make this process
    /// run, so the request waits in the App Group until the system next does, and this is where it
    /// is found. A representation that has never looked adopts the current value without re-arming,
    /// because a new representation offers once anyway.
    private func consumeReofferRequest() {
        let epoch = RemoteMediaReofferSignal.epoch
        defer { honouredReoffer = epoch }
        guard let honouredReoffer, epoch > honouredReoffer else { return }
        RemoteMediaLog.logger.info(
            "RemoteMedia registration re-offer requested epoch=\(epoch, privacy: .public)"
        )
        ledger.rearm()
    }

    /// Offers `token` for this session, if it says something the server has not been told.
    public func offer(
        token: RemoteMediaPushToken,
        sessionId: String,
        serverId: String,
        entityId: String,
        context: RemoteMediaTransportContext?
    ) {
        consumeReofferRequest()
        guard let lifetime else {
            // Attributes from a build that predates ordered relationships. Registering would hand
            // the server a token it could not place in time, which is worse than not registering:
            // the user can stop and follow again, and everything about this session is local until
            // they do.
            RemoteMediaLog.logger.info(
                """
                RemoteMedia registration session=\(sessionId, privacy: .public) \
                result=no ordered lifetime, re-follow required
                """
            )
            return
        }
        let registration = RemoteMediaSessionRegistration(
            sessionId: sessionId,
            serverId: serverId,
            entityId: entityId,
            lifetime: lifetime,
            pushToken: token.hex
        )
        guard let pending = ledger.pending(registration) else { return }
        guard let context else {
            // Nothing is followed, or the host app has not written the routes yet. The token is
            // still owed, so put it back for whichever update comes next.
            ledger.release(pending)
            log(pending, token: token, result: "no transport context")
            return
        }
        // Apple treats this as a device-scoped identifier, so only the fingerprint may be logged.
        log(pending, token: token, result: "sending")
        sender.send(
            pending,
            context: context,
            isCurrent: { [weak self] in self?.lifetime == pending.lifetime }
        ) { [weak self] outcome in
            guard let self else { return }
            if case .unreachable = outcome {
                // Never delivered, so let the next state update offer it again.
                ledger.release(pending)
            }
            log(pending, token: token, result: Self.describe(outcome))
        }
    }

    /// Abandons any registration in flight. The local session is untouched.
    public func cancel() {
        sender.cancel()
    }

    private func log(
        _ registration: RemoteMediaSessionRegistration,
        token: RemoteMediaPushToken,
        result: String
    ) {
        RemoteMediaLog.logger.info(
            """
            RemoteMedia registration session=\(registration.sessionId, privacy: .public) \
            generation=\(registration.generation, privacy: .public) \
            sequence=\(registration.generationSequence, privacy: .public) \
            token=\(token.fingerprint, privacy: .public) \
            bytes=\(token.byteCount, privacy: .public) \
            result=\(result, privacy: .public)
            """
        )
    }

    static func describe(_ outcome: RemoteMediaRegistrationSender.Outcome) -> String {
        switch outcome {
        case let .delivered(attempts): return "accepted after \(attempts)"
        case .refused: return "refused"
        case let .unreachable(attempts): return "unreachable after \(attempts)"
        case .superseded: return "superseded"
        }
    }
}
