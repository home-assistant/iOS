import Foundation

public extension SettingsStore {
    /// The current Follow relationship, stored as one encoded value so selection and lifetime
    /// cannot tear across process termination.
    internal var remoteMediaFollowRecord: RemoteMediaFollowRecord? {
        get {
            guard let data = prefs.data(forKey: Self.remoteMediaFollowRecordKey) else { return nil }
            return try? JSONDecoder().decode(RemoteMediaFollowRecord.self, from: data)
        }
        set {
            prefs.set(
                newValue.flatMap { try? JSONEncoder().encode($0) },
                forKey: Self.remoteMediaFollowRecordKey
            )
        }
    }

    /// Reads the atomic record first and falls back to the pre-record key until startup migrates it.
    var remoteMediaSelection: RemoteMediaSelection? {
        if let record = remoteMediaFollowRecord { return record.selection }
        guard let data = prefs.data(forKey: Self.legacyRemoteMediaSelectionKey) else { return nil }
        return try? JSONDecoder().decode(RemoteMediaSelection.self, from: data)
    }

    /// Reads the atomic record first and falls back to the pre-record key until startup migrates it.
    var remoteMediaFollowLifetime: RemoteMediaFollowLifetime? {
        if let record = remoteMediaFollowRecord { return record.lifetime }
        guard let data = prefs.data(forKey: Self.legacyRemoteMediaFollowLifetimeKey) else { return nil }
        return try? JSONDecoder().decode(RemoteMediaFollowLifetime.self, from: data)
    }

    /// How many Follow relationships this install has created.
    ///
    /// This counter is written before the atomic record. Termination between those writes can
    /// spend a number, which is harmless; writing the record first could let a relaunch reuse its
    /// sequence, which would not be.
    var remoteMediaFollowSequence: Int {
        get { max(0, prefs.integer(forKey: Self.remoteMediaFollowSequenceKey)) }
        set { prefs.set(newValue, forKey: Self.remoteMediaFollowSequenceKey) }
    }

    /// Begins a relationship for `selection`, or ends the current one when nothing is followed.
    ///
    /// The counter moves exactly once per relationship. Selection and lifetime are then committed
    /// together, so every persisted player always has the generation and sequence minted for it.
    @discardableResult
    func startRemoteMediaFollowLifetime(
        following selection: RemoteMediaSelection?
    ) -> RemoteMediaFollowLifetime? {
        guard let selection else {
            remoteMediaFollowRecord = nil
            clearLegacyRemoteMediaFollowState()
            return nil
        }
        let sequence = RemoteMediaFollowLifetime.nextSequence(after: remoteMediaFollowSequence)
        remoteMediaFollowSequence = sequence
        let lifetime = RemoteMediaFollowLifetime(generation: UUID().uuidString, sequence: sequence)
        remoteMediaFollowRecord = .init(selection: selection, lifetime: lifetime)
        clearLegacyRemoteMediaFollowState()
        return lifetime
    }

    /// Converts pre-record and partially written state into one safe relationship.
    ///
    /// A legacy selection and lifetime cannot prove they belong together. Minting a later lifetime
    /// is the recovery mechanism: Home Assistant can reject any delayed registration from the old
    /// relationship once this one registers, while the user keeps following the selected player.
    @discardableResult
    func migrateRemoteMediaFollowLifetime() -> RemoteMediaFollowLifetime? {
        defer { prefs.removeObject(forKey: Self.legacyRemoteMediaSessionGenerationKey) }
        if let record = remoteMediaFollowRecord {
            remoteMediaFollowSequence = max(remoteMediaFollowSequence, record.lifetime.sequence)
            clearLegacyRemoteMediaFollowState()
            return record.lifetime
        }

        guard let selection = legacyRemoteMediaSelection else {
            clearLegacyRemoteMediaFollowState()
            return nil
        }
        let previous = max(remoteMediaFollowSequence, legacyRemoteMediaFollowLifetime?.sequence ?? 0)
        let sequence = RemoteMediaFollowLifetime.nextSequence(after: previous)
        remoteMediaFollowSequence = sequence
        let lifetime = RemoteMediaFollowLifetime(generation: UUID().uuidString, sequence: sequence)
        remoteMediaFollowRecord = .init(selection: selection, lifetime: lifetime)
        clearLegacyRemoteMediaFollowState()
        return lifetime
    }

    /// Follow relationships that have ended locally but that Home Assistant may not know about.
    ///
    /// Identity only — no token, no secret, no URL — so this is safe in ordinary preferences. See
    /// `RemoteMediaPendingDismissal` and `RemoteMediaDismissalReconciler`.
    var remoteMediaPendingDismissals: [RemoteMediaPendingDismissal] {
        get {
            guard let data = prefs.data(forKey: "remoteMediaPendingDismissals") else { return [] }
            return (try? JSONDecoder().decode([RemoteMediaPendingDismissal].self, from: data)) ?? []
        }
        set {
            // Bounded: a server that is never reachable again must not be able to grow this
            // without limit, and the oldest unsent dismissals are the least worth keeping — the
            // sessions they name have long since had their tokens rejected by APNs.
            let bounded = newValue.suffix(Self.remoteMediaPendingDismissalLimit)
            prefs.set(
                bounded.isEmpty ? nil : try? JSONEncoder().encode(Array(bounded)),
                forKey: "remoteMediaPendingDismissals"
            )
        }
    }

    static let remoteMediaPendingDismissalLimit = 16

    /// Records that `pending` is owed to the server, replacing any earlier record of it.
    func addRemoteMediaPendingDismissal(_ pending: RemoteMediaPendingDismissal) {
        var records = remoteMediaPendingDismissals.filter { !$0.describesSameLifetime(as: pending) }
        records.append(pending)
        remoteMediaPendingDismissals = records
    }

    /// Forgets a dismissal the server has accepted.
    func removeRemoteMediaPendingDismissal(_ pending: RemoteMediaPendingDismissal) {
        remoteMediaPendingDismissals = remoteMediaPendingDismissals
            .filter { !$0.describesSameLifetime(as: pending) }
    }

    private static let remoteMediaFollowRecordKey = "remoteMediaFollowRecord"
    private static let remoteMediaFollowSequenceKey = "remoteMediaFollowSequence"
    private static let legacyRemoteMediaSelectionKey = "remoteMediaSelection"
    private static let legacyRemoteMediaFollowLifetimeKey = "remoteMediaFollowLifetime"
    private static let legacyRemoteMediaSessionGenerationKey = "remoteMediaSessionGeneration"

    private var legacyRemoteMediaSelection: RemoteMediaSelection? {
        guard let data = prefs.data(forKey: Self.legacyRemoteMediaSelectionKey) else { return nil }
        return try? JSONDecoder().decode(RemoteMediaSelection.self, from: data)
    }

    private var legacyRemoteMediaFollowLifetime: RemoteMediaFollowLifetime? {
        guard let data = prefs.data(forKey: Self.legacyRemoteMediaFollowLifetimeKey) else { return nil }
        return try? JSONDecoder().decode(RemoteMediaFollowLifetime.self, from: data)
    }

    private func clearLegacyRemoteMediaFollowState() {
        prefs.removeObject(forKey: Self.legacyRemoteMediaSelectionKey)
        prefs.removeObject(forKey: Self.legacyRemoteMediaFollowLifetimeKey)
    }
}
