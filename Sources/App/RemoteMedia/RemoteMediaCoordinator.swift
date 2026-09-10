#if !targetEnvironment(macCatalyst)
import HAKit
import Shared
import UIKit

@available(iOS 27.0, *)
@MainActor
final class RemoteMediaCoordinator: ObservableObject, ServerObserver {
    static let shared = RemoteMediaCoordinator()

    @Published private(set) var selection: RemoteMediaSelection?
    @Published private(set) var snapshot: RemoteMediaSnapshot?
    @Published private(set) var error: String?
    private let publisher: RemoteMediaSessionPublisher
    private let dismissals: RemoteMediaDismissalSender
    private let artwork = RemoteMediaArtworkPreparer()
    private var subscription: HACancellable?
    private var foregroundObserver: NSObjectProtocol?
    private var generation = 0
    private var hasPublished = false
    private var artworkTask: Task<Void, Never>?
    /// The artwork identity currently attached or being prepared, so repeated state deliveries for
    /// the same track neither restart preparation nor drop the image that is already showing.
    private var artworkKey: String?

    convenience init() {
        self.init(publisher: .init(driver: AppleRemoteMediaSessionDriver()))
    }

    init(publisher: RemoteMediaSessionPublisher, dismissals: RemoteMediaDismissalSender = .init()) {
        self.publisher = publisher
        self.dismissals = dismissals
        self.selection = Current.settingsStore.remoteMediaSelection
        publisher.onError = { [weak self] error in
            self?.error = error == nil ? nil : L10n.RemoteMedia.sessionError
        }
    }

    func start() {
        guard foregroundObserver == nil else { return }
        // A relationship from a build that predates ordered lifetimes gets a place in the order,
        // so a followed player does not silently stop being registrable.
        Current.settingsStore.migrateRemoteMediaFollowLifetime()
        Current.servers.add(observer: self)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
        reconcileDismissals()
    }

    /// Finishes any dismissal that never reached its server.
    ///
    /// Driven by the host app's own lifecycle — launch, and the server list changing — rather than
    /// by a timer: what is owed is a courtesy the server heals from on its own, and a process that
    /// wakes to retry one is not worth the battery.
    private func reconcileDismissals() {
        guard !Current.settingsStore.remoteMediaPendingDismissals.isEmpty else { return }
        Task { await RemoteMediaDismissalReconciler.reconcile() }
    }

    /// The one way a Follow relationship starts, is replaced, or ends.
    ///
    /// Every path the user can take to stop following — the button on this feature's settings
    /// screen, "Stop following" under an entity's "Add to" — comes through here, and so does
    /// choosing a different player. Nothing else does: an app going to the background, an extension
    /// exiting, a player pausing or dropping to `unavailable`, or Home Assistant being unreachable
    /// all leave the relationship intact, which is the whole point of following one.
    func follow(_ selection: RemoteMediaSelection?) {
        // Validated rather than merely domain-checked: a followed id is persisted and later
        // interpolated into the `render_template` query the extension reads state back with.
        // `nil` is always allowed — it is how the user stops following.
        if let selection, !RemoteMediaEntityId.isValid(selection.entityId) { return }
        // Taken before anything it depends on is torn down, and used only after: stopping is a user
        // action, so it must not wait for the network.
        let ending = RemoteMediaFollowEnd.capture(
            selection: self.selection,
            lifetime: Current.settingsStore.remoteMediaFollowLifetime,
            context: RemoteMediaTransportStore.load()
        )
        // Written down before anything is sent, so a request that never lands — or an app that is
        // killed between the two — leaves something for a later launch to finish.
        if let ending {
            Current.settingsStore.addRemoteMediaPendingDismissal(ending.pending)
        }
        // Each Follow is its own relationship. Re-following the same player reuses the session
        // identifier, so this is what lets the server retire the token the last one registered and
        // know which of the two came later.
        Current.settingsStore.startRemoteMediaFollowLifetime(following: selection)
        self.selection = selection
        publisher.publish(nil)
        if selection == nil {
            // Nothing followed: the extension must not keep a usable webhook secret or stale art.
            RemoteMediaTransportStore.clear()
            RemoteMediaArtworkCache.removeAll()
        }
        refresh()
        guard let ending else { return }
        // Best effort, and deliberately last. The replacement relationship is already starting, and
        // a dismissal that fails changes nothing here — it stays written down, and the ordered
        // lifetime means the server ignores it if the replacement got there first.
        Task { [dismissals] in
            if await dismissals.send(ending) {
                Current.settingsStore.removeRemoteMediaPendingDismissal(ending.pending)
            }
        }
    }

    func refresh() {
        generation += 1
        let generation = generation
        subscription?.cancel()
        subscription = nil
        artworkTask?.cancel()
        artworkTask = nil
        artworkKey = nil
        snapshot = nil
        hasPublished = false
        error = nil
        // The extension evaluates no network state of its own, so the routes and the secret it uses
        // are refreshed here whenever the followed player or the server's connection changes.
        RemoteMediaTransportContextWriter.update(for: selection)
        // The session token lives in the extension and never leaves it, so this is the only thing
        // the host app can say about registration: that the server may no longer have it. Raised on
        // every launch, foreground and server change, because none of those can tell whether Home
        // Assistant still holds the relationship — it answers an unrecognised registration and a
        // duplicate one identically. The extension acts on it the next time the system runs it, and
        // re-offering is the same relationship again: no new generation, no new sequence.
        if selection == nil {
            RemoteMediaReofferSignal.clear()
        } else {
            RemoteMediaReofferSignal.request()
        }
        // A followed player whose server is gone, or not connected yet, has no card — but the
        // relationship survives, so no dismissal is sent and the selection is kept. Deleting a
        // server does not delete its Home Assistant registration, and re-adding it should resume
        // rather than silently having stopped; a token left registered stops being pushed to on its
        // own, because APNs rejects it once the session has ended.
        guard let selection,
              let server = Current.servers.server(forServerIdentifier: selection.serverId),
              let api = Current.api(for: server) else {
            publisher.publish(nil)
            return
        }
        // Ask the server for this entity alone where it can filter, so following one player does not
        // stream every entity's state to the phone. Older servers send the unfiltered cache instead.
        var filter: [String: Any] = [:]
        if server.info.version > .canSubscribeEntitiesChangesWithFilter {
            filter = ["include": ["entities": [selection.entityId]]]
        }
        api.connectWebSocketIfNeeded()
        // HAKit's cache already handles reconnects and initial state delivery.
        subscription = api.connection.caches.states(filter).subscribe { [weak self] _, states in
            let state = states[selection.entityId]
                .flatMap { RemoteMediaSnapshotMapper.map($0, serverId: selection.serverId) }
            Task { @MainActor in
                guard let self, self.generation == generation else { return }
                self.apply(state, generation: generation)
            }
        }
    }

    /// Publishes metadata immediately and lets artwork catch up, so the Now Playing card appears
    /// without waiting on a download.
    ///
    /// Artwork already in the cache is attached to the very first publish rather than arriving in a
    /// second one. The system asks for an image once per content identity, so a card published
    /// without artwork and corrected a moment later just stays blank.
    private func apply(_ state: RemoteMediaEntityState?, generation: Int) {
        guard let state else {
            publish(nil)
            return
        }
        // A host-only source must not be advertised until its file exists: the extension has no
        // credentials or safe URL with which to answer a cold request. A credential-free source
        // can be advertised immediately because the extension can fetch it if the host is gone.
        let desiredKey = artworkKey(for: state)
        let source = Self.fetchableSource(for: state)
        let isReady = desiredKey.map { RemoteMediaArtworkCache.contains(.init(cacheKey: $0)) } ?? false
        let descriptor: RemoteMediaArtworkDescriptor?
        if let desiredKey, isReady || source != nil {
            // The fetchable source travels with the key when there is one, so a later cold launch
            // whose cache has been pruned can get the image itself instead of showing none.
            descriptor = .init(cacheKey: desiredKey, url: source)
        } else {
            descriptor = nil
        }
        publish(state.snapshot.withArtwork(descriptor))

        // Preparation is keyed on artwork identity, not on every state delivery: a playing player
        // sends many, and restarting the download on each one means it never finishes.
        guard let desiredKey, !isReady else {
            artworkKey = desiredKey
            return
        }
        guard desiredKey != artworkKey || artworkTask == nil else { return }
        artworkKey = desiredKey
        artworkTask?.cancel()
        artworkTask = Task { [weak self, artwork] in
            let prepared = await artwork.descriptor(for: state)
            await MainActor.run {
                guard let self, self.generation == generation, self.artworkKey == desiredKey else { return }
                self.artworkTask = nil
                guard let current = self.snapshot, current.trackId == state.snapshot.trackId else { return }
                if let prepared {
                    // A credential-free source was already advertised so the extension could
                    // fetch it while this preparation ran. Host-only artwork needs this update to
                    // add its descriptor after the file is actually present.
                    guard current.artwork == nil else { return }
                    self.publish(current.withArtwork(prepared))
                    return
                }
                // A fetchable source remains useful to the extension even if host preparation
                // failed: it can still fetch that source itself, so the descriptor stays.
                guard source == nil else { return }
                // Host-only artwork that failed to prepare. Nothing is published: a host-only
                // descriptor is only ever advertised once its file exists, and preparation only
                // ran because it did not, so there is nothing on the card to take back. Releasing
                // the key is the whole point — it lets the next state delivery try again, which
                // a descriptor that matched `artworkKey` would otherwise skip.
                Current.Log.info("Remote media artwork unavailable; releasing its key to retry")
                self.artworkKey = nil
            }
        }
    }

    /// The artwork source the extension is allowed to fetch on its own, if this state has one.
    ///
    /// Only an absolute HTTPS URL that carries no credentials. A `media_player`'s `entity_picture`
    /// is often a Home Assistant proxy path with a signed token in its query, and that form must
    /// not reach the extension: the attributes it lives in are serialized through Apple's
    /// infrastructure and echoed back by the push relay. Those stay host-prepared.
    private static func fetchableSource(for state: RemoteMediaEntityState) -> URL? {
        guard let source = state.artworkSource, let url = URL(string: source) else { return nil }
        guard RemoteMediaArtworkFetcher.isFetchable(url) else { return nil }
        // A query is where Home Assistant puts its signed token. Nothing with one is treated as a
        // public reference, even when it is absolute and on some other host.
        guard url.query == nil else { return nil }
        return url
    }

    /// The cache key this state's artwork would have, or `nil` when there is nothing to show.
    private func artworkKey(for state: RemoteMediaEntityState) -> String? {
        guard state.snapshot.hasMeaningfulMedia, let source = state.artworkSource, !source.isEmpty else { return nil }
        return RemoteMediaArtworkCache.key(
            sessionId: state.snapshot.id,
            trackId: state.snapshot.trackId,
            source: source
        )
    }

    /// Publishes only a genuine change, so the extension is not handed the same session repeatedly.
    private func publish(_ snapshot: RemoteMediaSnapshot?) {
        guard self.snapshot != snapshot || !hasPublished else { return }
        hasPublished = true
        self.snapshot = snapshot
        publisher.publish(snapshot)
    }

    nonisolated func serversDidChange(_ serverManager: ServerManager) {
        Task { @MainActor [weak self] in
            self?.refresh()
            // A server that has just finished onboarding, or come back, is a chance to finish a
            // dismissal that could not be sent when the user stopped.
            self?.reconcileDismissals()
        }
    }
}
#endif
