import CloudKit
import Foundation
import Shared
import UIKit

/// Syncs the app's GRDB database with the user's other devices through their private
/// CloudKit database, when the user has opted in (Settings → iCloud Sync).
///
/// The whole database travels as a single snapshot record and the copy modified most
/// recently wins. No Home Assistant credentials are involved: tokens and webhook
/// secrets live only in the Keychain, and the server list stored in GRDB is sanitized
/// before persisting (`ServerInfo.mirroredForPersistence`), so a device that adopts a
/// synced snapshot obtains its own token through the standard re-authentication flow.
///
/// Syncs run shortly after launch, when the app enters the foreground, after local
/// database changes and on demand from the settings screen.
@MainActor
final class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? = Current.settingsStore.iCloudSyncLastSyncDate
    @Published private(set) var lastErrorMessage: String?

    enum SyncError: LocalizedError {
        case iCloudUnavailable

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                return L10n.SettingsDetails.CloudSync.Error.icloudUnavailable
            }
        }
    }

    private enum RecordField {
        static let payload = "payload"
        static let contentHash = "contentHash"
        static let formatVersion = "formatVersion"
        static let sourceDeviceID = "sourceDeviceID"
    }

    private struct RemoteSnapshot {
        let record: CKRecord
        let snapshot: CloudSyncSnapshot

        var contentHash: String {
            record[RecordField.contentHash] as? String ?? snapshot.contentHash
        }
    }

    private static let recordType = "AppDatabaseSnapshot"
    private static let recordName = "appDatabaseSnapshot"

    private let serializer: CloudSyncSnapshotSerializerProtocol = CloudSyncSnapshotSerializer()
    private let databaseObserver = CloudSyncDatabaseObserver()
    private var notificationObservers: [NSObjectProtocol] = []
    private var pendingSyncTask: Task<Void, Never>?
    /// Applying a remote snapshot rewrites every table, which would re-trigger the
    /// database observer and bounce the same data straight back up; suppressed while
    /// (and shortly after) an import runs.
    private var suppressDatabaseObservation = false

    private var container: CKContainer { CKContainer(identifier: AppConstants.iCloudContainerID) }
    private var database: CKDatabase { container.privateCloudDatabase }
    private var recordID: CKRecord.ID { CKRecord.ID(recordName: Self.recordName) }

    private init() {}

    /// Installs the foreground and database-change observers and schedules an initial
    /// sync. Called at app launch and after the user opts in; does nothing while the
    /// user has not opted in.
    func start() {
        guard Current.settingsStore.iCloudSyncEnabled, notificationObservers.isEmpty else { return }

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleSync(after: 1)
            }
        })

        databaseObserver.start { [weak self] in
            Task { @MainActor in
                guard let self, !self.suppressDatabaseObservation else { return }
                self.scheduleSync(after: 5)
            }
        }

        scheduleSync(after: 1)
    }

    /// Opts in: verifies the iCloud account, then adopts the cloud copy if one exists
    /// (another device enabled sync first) or uploads this device's data as the first
    /// snapshot. Throws when no iCloud account is available.
    func enable() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { throw SyncError.iCloudUnavailable }

        Current.settingsStore.iCloudSyncEnabled = true
        start()

        await run { [self] in
            if let remote = try await fetchRemote() {
                try applyRemote(remote)
            } else {
                try await upload(serializer.exportSnapshot(), over: nil)
            }
        }
    }

    /// Opts out: stops observing and syncing. The snapshot already in iCloud is kept
    /// (other devices may still use it); `deleteCloudData()` removes it explicitly.
    func disable() {
        Current.settingsStore.iCloudSyncEnabled = false
        Current.settingsStore.iCloudSyncLastSyncedHash = nil
        pendingSyncTask?.cancel()
        pendingSyncTask = nil
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        databaseObserver.stop()
    }

    func syncNow() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            await self?.performSync()
        }
    }

    /// Deletes the snapshot record from the user's private CloudKit database.
    func deleteCloudData() async throws {
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            // Nothing in iCloud; already the state the user asked for.
        }
    }

    private func scheduleSync(after seconds: TimeInterval) {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.performSync()
        }
    }

    private func performSync() async {
        await run { [self] in
            let local = try serializer.exportSnapshot()
            let localHash = local.contentHash
            let lastSyncedHash = Current.settingsStore.iCloudSyncLastSyncedHash

            guard let remote = try await fetchRemote() else {
                try await upload(local, over: nil)
                return
            }

            let remoteHash = remote.contentHash
            if remoteHash == localHash {
                markSynced(hash: localHash)
            } else if localHash == lastSyncedHash {
                // Only the cloud copy changed since the last completed sync.
                try applyRemote(remote)
            } else if remoteHash == lastSyncedHash {
                // Only this device changed since the last completed sync.
                try await upload(local, over: remote.record)
            } else {
                // Both sides changed; the copy modified most recently wins.
                let remoteDate = remote.record.modificationDate ?? .distantPast
                if remoteDate > localDatabaseModificationDate() {
                    try applyRemote(remote)
                } else {
                    try await upload(local, over: remote.record)
                }
            }
        }
    }

    /// Shared harness for sync work: gates on opt-in and re-entrancy, checks the
    /// iCloud account, and funnels errors into `lastErrorMessage` for the settings UI.
    private func run(_ body: () async throws -> Void) async {
        guard Current.settingsStore.iCloudSyncEnabled, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let status = try await container.accountStatus()
            guard status == .available else { throw SyncError.iCloudUnavailable }
            try await body()
            lastErrorMessage = nil
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Lost a save race against another device; the next pass reconciles.
            scheduleSync(after: 5)
        } catch {
            Current.Log.error("iCloud sync failed: \(error)")
            lastErrorMessage = error.localizedDescription
        }
    }

    private func fetchRemote() async throws -> RemoteSnapshot? {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }

        guard let asset = record[RecordField.payload] as? CKAsset, let fileURL = asset.fileURL else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try RemoteSnapshot(record: record, snapshot: decoder.decode(CloudSyncSnapshot.self, from: data))
    }

    private func applyRemote(_ remote: RemoteSnapshot) throws {
        suppressDatabaseObservation = true
        defer {
            // The observer delivers changes asynchronously, so keep suppressing for a
            // moment after the import transaction commits.
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                self?.suppressDatabaseObservation = false
            }
        }

        try serializer.importSnapshot(remote.snapshot)

        // If this device has no signed-in servers, materialize the synced (token-free)
        // server list; the existing mirror-restore flow then asks the user to
        // re-authenticate before any server can be reached.
        _ = Current.servers.restoreKeychainFromMirrorIfNeeded()

        markSynced(hash: remote.contentHash)
        Current.Log.info("iCloud sync applied snapshot from \(remote.snapshot.sourceDeviceID)")
    }

    private func upload(_ snapshot: CloudSyncSnapshot, over existingRecord: CKRecord?) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(snapshot)

        let assetURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloud-sync-\(UUID().uuidString).json")
        try data.write(to: assetURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: assetURL) }

        let record = existingRecord ?? CKRecord(recordType: Self.recordType, recordID: recordID)
        record[RecordField.payload] = CKAsset(fileURL: assetURL)
        record[RecordField.contentHash] = snapshot.contentHash
        record[RecordField.formatVersion] = snapshot.formatVersion
        record[RecordField.sourceDeviceID] = snapshot.sourceDeviceID
        _ = try await database.save(record)

        markSynced(hash: snapshot.contentHash)
        Current.Log.info("iCloud sync uploaded snapshot \(snapshot.contentHash)")
    }

    private func markSynced(hash: String) {
        Current.settingsStore.iCloudSyncLastSyncedHash = hash
        let now = Current.date()
        Current.settingsStore.iCloudSyncLastSyncDate = now
        lastSyncDate = now
    }

    /// Best-effort timestamp of the last local database change, taken from the SQLite
    /// files' modification dates; used only to break both-sides-changed conflicts.
    private func localDatabaseModificationDate() -> Date {
        let fileManager = FileManager.default
        let paths = [
            AppConstants.appGRDBFile.path,
            AppConstants.appGRDBFile.path + "-wal",
        ]
        let dates = paths.compactMap { path in
            (try? fileManager.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        }
        return dates.max() ?? .distantPast
    }
}
