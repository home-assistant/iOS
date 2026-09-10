import Foundation
import NowPlaying
import Observation

/// The Now Playing session the system drives, kept deliberately small.
///
/// This process has a hard 6144 KB jetsam ledger, so it links no Companion framework and does no
/// work the host app can do instead: artwork arrives pre-fetched and pre-sized in the App Group,
/// and a command is one webhook POST with no entity-state round trip beforehand.
///
/// The snapshot here is mutable rather than a frozen copy of whatever the host app last published.
/// The system keeps this object alive between commands, so a command issued from Control Center is
/// reconciled against Home Assistant here — otherwise pressing Next changes the speaker while the
/// card keeps showing the old song until the containing app is next opened.
@MainActor
@Observable
final class HomeAssistantRemoteMediaSession: RemoteMediaSessionRepresentable {
    let id: String
    /// What the card currently shows. Updated by the host app through `update`, and by this
    /// process's own reconciliation after a command.
    private var snapshot: RemoteMediaSnapshot
    private let selection: RemoteMediaSelection
    /// Cached context, refreshed when the host delivers new attributes so route changes are picked
    /// up without making every command build the app's networking stack.
    private var context: RemoteMediaTransportContext?

    /// Rapid Control Center use overlaps commands, and a slow reply to Next #1 must never overwrite
    /// the track Next #3 landed on.
    private let gate = RemoteMediaReconciliationGate()

    /// Registers this session's push token with Home Assistant, and re-offers it whenever the
    /// Follow lifetime changes under it.
    @ObservationIgnored private let registrar = RemoteMediaSessionRegistrar()
    @ObservationIgnored private var pushTokens: RemoteMediaPushTokenObserver?

    init(attributes: RemoteMediaSessionAttributes) {
        self.id = attributes.id
        self.snapshot = attributes.snapshot
        self.selection = attributes.snapshot.selection
        self.context = RemoteMediaTransportStore.load()
        registrar.adopt(lifetime: attributes.lifetime)
        RemoteMediaLog.logger
            .info("session created following \(attributes.snapshot.selection.entityId, privacy: .public)")
    }

    /// Starts watching for this session's own APNs update token, which is what lets Home Assistant
    /// refresh the card while nothing of ours is running.
    ///
    /// Called after `session(_:)` returns rather than from `init`: the framework associates this
    /// object with a system session only once it has been handed back, and there is no token to
    /// read until it has.
    func startObservingPushToken() {
        guard pushTokens == nil else { return }
        let observer = RemoteMediaPushTokenObserver(
            currentToken: { [weak self] in self?.pushToken },
            tokenUpdates: { [weak self] in self?.pushTokenUpdates ?? AsyncStream { $0.finish() } },
            onToken: { [weak self] token in self?.register(token) }
        )
        pushTokens = observer
        observer.start()
    }

    func update(_ attributes: RemoteMediaSessionAttributes) {
        guard attributes.id == id else { return }
        // A framework update is authoritative. Invalidate first so a readback already queued on the
        // main actor cannot overwrite these newer pushed attributes after they are applied.
        gate.invalidate()
        apply(attributes.snapshot)
        context = RemoteMediaTransportStore.load()
        // Following the same player again is a new relationship, so the token has to be
        // registered against it even when the token itself has not changed.
        registrar.adopt(lifetime: attributes.lifetime)
        if let token = pushToken { register(RemoteMediaPushToken(token)) }
    }

    /// Offers the session's update token to Home Assistant, which is what lets the server push this
    /// card's state while nothing of ours is running.
    private func register(_ token: RemoteMediaPushToken) {
        let context = context ?? RemoteMediaTransportStore.load()
        self.context = context
        registrar.offer(
            token: token,
            sessionId: id,
            serverId: selection.serverId,
            entityId: selection.entityId,
            context: context
        )
    }

    // MARK: - Artwork

    /// The cached bytes for this track's cover, or `nil`. Never touches the network.
    private nonisolated static func cachedArtwork(
        for descriptor: RemoteMediaArtworkDescriptor,
        sessionId: String,
        trackId: String
    ) -> Data? {
        guard let key = descriptor.resolvedKey(sessionId: sessionId, trackId: trackId) else { return nil }
        return RemoteMediaArtworkCache.data(for: .init(cacheKey: key))
    }

    /// The cover for one artwork request, fetching it if that is what it takes.
    ///
    /// The provider may fetch a credential-free source when the host app is not running. Cached
    /// bytes are returned directly so the extension stays within its 6144 KB memory limit.
    private nonisolated static func artworkRepresentation(
        for descriptor: RemoteMediaArtworkDescriptor,
        sessionId: String,
        trackId: String
    ) async throws -> ArtworkRepresentation {
        if let cached = cachedArtwork(for: descriptor, sessionId: sessionId, trackId: trackId) {
            return try ArtworkRepresentation(data: cached)
        }

        guard let url = descriptor.url else {
            // Artwork only Home Assistant's own authentication can reach. The extension holds no
            // credentials and will not be given any, so there is nothing to wait for.
            throw RemoteMediaError.invalidArtwork
        }

        let outcome = await RemoteMediaArtworkFetcher.fetch(from: url)
        guard let data = outcome.data else {
            RemoteMediaLog.logger.error("artwork fetch failed: \(outcome.reason, privacy: .public)")
            throw RemoteMediaError.invalidArtwork
        }
        // Network bytes are bounded, but a small compressed image can still have enormous pixel
        // dimensions. ImageIO creates only a 512-pixel thumbnail, keeping full-resolution decode
        // out of this process's 6144 KB ledger.
        guard let prepared = RemoteMediaArtworkDownsampler.downsample(data) else {
            throw RemoteMediaError.invalidArtwork
        }

        if let key = descriptor.resolvedKey(sessionId: sessionId, trackId: trackId) {
            do {
                try RemoteMediaArtworkCache.store(prepared, for: .init(cacheKey: key))
            } catch {
                // The image is already in hand; only the next request is affected.
                RemoteMediaLog.logger.error("artwork cache write failed")
            }
        }

        return try ArtworkRepresentation(data: prepared)
    }

    // MARK: - What the system renders

    var playbackSnapshot: MediaPlaybackSnapshot? {
        guard snapshot.hasMeaningfulMedia else { return nil }
        return .init(
            state: snapshot.playback.isPlaying ? .playing() : .paused,
            elapsedTime: snapshot.position,
            // The only place the wire's Unix seconds become a `Date`.
            timestamp: snapshot.positionUpdatedAtUnix.map(Date.init(timeIntervalSince1970:))
        )
    }

    var content: (any MediaContentRepresentable)? {
        let snapshot = snapshot
        guard snapshot.hasMeaningfulMedia else { return nil }
        let artwork = snapshot.artwork.map { descriptor in
            // Keyed on the artwork's identity so a new track's cover replaces the previous one.
            Artwork(id: descriptor.identity) { [id, trackId = snapshot.trackId] _ in
                try await Self.artworkRepresentation(
                    for: descriptor,
                    sessionId: id,
                    trackId: trackId
                )
            }
        }
        return MusicContent(
            id: snapshot.trackId,
            songTitle: snapshot.title ?? snapshot.deviceName,
            artistName: snapshot.artist ?? "",
            albumName: snapshot.album ?? "",
            type: snapshot.deviceClass == "tv" ? .video : .audio,
            duration: snapshot.duration.map { .finite($0) },
            artwork: artwork
        )
    }

    var commands: [MediaCommand] {
        let snapshot = snapshot
        guard snapshot.hasMeaningfulMedia else { return [] }
        return RemoteMediaCommand.allCases
            .filter { snapshot.features.commands.contains($0) }
            .compactMap { command in
                switch command {
                case .play: return .play { try await self.send(.play) }
                case .pause: return .pause { try await self.send(.pause) }
                case .togglePlayPause: return .togglePlayPause { try await self.send(.togglePlayPause) }
                case .stop: return .stop { try await self.send(.stop) }
                case .previous: return .previous { try await self.send(.previous) }
                case .next: return .next { try await self.send(.next) }
                case .seek: return .seekToPosition { try await self.send(.seek, value: $0) }
                case .volume: return nil // Volume is a device capability, not a MediaCommand.
                }
            }
    }

    var devices: [MediaDevice] {
        var capabilities: [MediaDevice.Capability] = []
        if snapshot.features.contains(.volumeSet), let volume = snapshot.volume {
            capabilities.append(.absoluteVolume(Float(volume)) { value in
                try await self.send(.volume, value: Double(value))
            })
        }
        return [.init(
            id: id,
            name: snapshot.deviceName,
            type: snapshot.deviceClass == "tv" ? .tv : .speaker,
            capabilities: capabilities
        )]
    }

    // MARK: - Commands

    /// One webhook POST per user action, then a bounded read-back so the card reflects what the
    /// speaker actually did. A failure is reported to the system and logged; it never tears the
    /// session down, because the user is still following this player.
    private func send(_ command: RemoteMediaCommand, value: Double? = nil) async throws {
        let context = context ?? RemoteMediaTransportStore.load()
        self.context = context
        guard let context else {
            RemoteMediaLog.logger.error("command \(command.rawValue, privacy: .public): no transport context")
            throw RemoteMediaWebhookClient.ClientError.noTransportContext
        }

        // Claim a generation before the command goes out, so a reply to an older one cannot land
        // on top of this. Claiming also cancels the reconciliation still running for the last.
        let generation = gate.begin()
        let burst = RemoteMediaCommandBurst()

        let condition = RemoteMediaSettleCondition.forCommand(command, value: value, previous: snapshot)
        do {
            try await burst.send(command, value: value, selection: selection, context: context)
        } catch {
            RemoteMediaLog.logger.error(
                "command \(command.rawValue, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
        startReconciling(using: burst, until: condition, generation: generation, context: context)
    }

    private func startReconciling(
        using burst: RemoteMediaCommandBurst,
        until condition: RemoteMediaSettleCondition,
        generation: Int,
        context: RemoteMediaTransportContext
    ) {
        let task = Task { [weak self, selection] in
            await burst.reconcile(selection: selection, context: context, until: condition) { readback in
                await MainActor.run {
                    // A slow reply to an older command must not land on the track a newer one
                    // has since reached.
                    guard let self, self.gate.isCurrent(generation) else { return }
                    self.applyReadback(readback)
                }
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                gate.finish(generation)
            }
        }
        gate.track(task, for: generation)
    }

    private func applyReadback(_ readback: RemoteMediaStateReadback) {
        switch readback {
        case let .entity(state):
            apply(state.snapshot)
        case .missing, .unreadable:
            // Neither is a reason to change what is on screen. A missing entity ends the session
            // through the host app, which owns the followed selection.
            RemoteMediaLog.logger.debug("reconcile produced no usable state")
        }
    }

    /// Runs every incoming snapshot through the reducer, so a transient `idle` or a momentarily
    /// blank set of attributes never empties the card.
    private func apply(_ incoming: RemoteMediaSnapshot) {
        guard let reduced = RemoteMediaSnapshotReducer.reduce(previous: snapshot, incoming: incoming),
              reduced != snapshot else { return }
        snapshot = reduced
    }
}
