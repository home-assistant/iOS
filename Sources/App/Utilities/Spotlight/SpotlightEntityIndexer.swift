import AppIntents
import CoreSpotlight
import CryptoKit
import Foundation
import Shared
import UIKit

/// Publishes the entities and calendars cached in the local database to Spotlight, so searching the
/// system for an entity's name (or its area, device or server) finds it and opens its more-info
/// dialog, and searching for a calendar finds it.
///
/// The index is rebuilt from the database rather than kept in sync incrementally: a full snapshot is
/// cheap to derive, and comparing its signature against the last indexed one means a refresh that
/// changed nothing costs a single hash instead of thousands of Spotlight writes.
@available(iOS 18.0, *)
@MainActor
final class SpotlightEntityIndexer: ServerObserver {
    static let shared = SpotlightEntityIndexer()

    private enum Constants {
        static let indexName = "HomeAssistantEntities"
        static let stateKey = "spotlightEntityIndexState"
        static let batchSize = 500
        static let coalescingDelay: Duration = .seconds(2)
        /// Bump this when the attributes written per entity change, so a build that indexes the same
        /// entities differently still rewrites the index instead of matching the stored signature.
        static let formatVersion = 4
    }

    /// What the index currently holds: the signature of the snapshot that produced it, and the ids it
    /// contains, so entities that disappear from the database can be removed from Spotlight too.
    ///
    /// `calendarIds` is optional so state written before calendars were indexed still decodes; a nil
    /// list simply means there is nothing of that type to clean up.
    private struct IndexState: Codable {
        let signature: String
        let entityIds: [String]
        let calendarIds: [String]?
    }

    private struct Snapshot {
        let entities: [HAAppEntityAppIntentEntity]
        let calendars: [HACalendarAppEntity]
        let signature: String
    }

    private let index = CSSearchableIndex(name: Constants.indexName)
    private let defaults = UserDefaults(suiteName: AppConstants.AppGroupID)
    private var databaseObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var reindexTask: Task<Void, Never>?
    /// Set when a pass was cancelled or deferred because the app left the foreground, so the next
    /// foreground redoes it instead of waiting for another database update.
    private var needsReindexOnForeground = false

    private init() {}

    func start() {
        guard databaseObserver == nil else { return }

        databaseObserver = NotificationCenter.default.addObserver(
            forName: .appDatabaseUpdaterDidFinishRoutine,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleReindex(reason: "database updated")
            }
        }
        // Catalyst is excluded like the rest of its lifecycle handling: it can sit in .background
        // without a foreground transition ever following, which would defer the reindex forever.
        if !Current.isCatalyst {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.cancelPendingReindex()
                }
            }
            foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.reindexAfterForegroundIfNeeded()
                }
            }
        }
        Current.servers.add(observer: self)
        scheduleReindex(reason: "app launch")
    }

    /// A pass running while backgrounded reads the shared-container database with nothing keeping the
    /// process alive, so a suspension mid-read is caught holding the SQLite file lock (0xdead10cc).
    /// The index is only visible from Spotlight anyway, so the work can wait for the next foreground.
    private func cancelPendingReindex() {
        guard reindexTask != nil else { return }
        reindexTask?.cancel()
        reindexTask = nil
        needsReindexOnForeground = true
    }

    private func reindexAfterForegroundIfNeeded() {
        guard needsReindexOnForeground else { return }
        needsReindexOnForeground = false
        scheduleReindex(reason: "returned to foreground")
    }

    nonisolated func serversDidChange(_ serverManager: ServerManager) {
        Task { @MainActor [weak self] in
            self?.scheduleReindex(reason: "servers changed")
        }
    }

    /// One notification arrives per server, and a database refresh touches every server in turn, so
    /// the work is deferred briefly and the pending task replaced to collapse a burst into one pass.
    private func scheduleReindex(reason: String) {
        reindexTask?.cancel()
        reindexTask = Task { [weak self] in
            try? await Task.sleep(for: Constants.coalescingDelay)
            guard !Task.isCancelled else { return }
            await self?.reindex(reason: reason)
        }
    }

    private func reindex(reason: String) async {
        // A trigger fired while backgrounded (background refresh, servers changing) lands here with
        // the coalescing delay already spent; defer it to the foreground instead of reading the
        // database from an unprotected background process.
        if !Current.isCatalyst, UIApplication.shared.applicationState == .background {
            needsReindexOnForeground = true
            return
        }
        let snapshot = await Task.detached(priority: .utility) { Self.makeSnapshot() }.value
        guard let snapshot else { return }

        let previousState = loadState()
        guard snapshot.signature != previousState?.signature else {
            Current.Log.verbose("Spotlight entity index already up to date (\(reason))")
            return
        }

        let indexedIds = snapshot.entities.map(\.id)
        let indexedCalendarIds = snapshot.calendars.map(\.id)
        let staleIds = Set(previousState?.entityIds ?? []).subtracting(indexedIds)
        let staleCalendarIds = Set(previousState?.calendarIds ?? []).subtracting(indexedCalendarIds)

        do {
            if !staleIds.isEmpty {
                try await index.deleteAppEntities(
                    identifiedBy: Array(staleIds),
                    ofType: HAAppEntityAppIntentEntity.self
                )
            }
            if !staleCalendarIds.isEmpty {
                try await index.deleteAppEntities(
                    identifiedBy: Array(staleCalendarIds),
                    ofType: HACalendarAppEntity.self
                )
            }
            for batch in stride(from: 0, to: snapshot.entities.count, by: Constants.batchSize) {
                // A newer pass supersedes this one; leaving the state unsaved makes it redo the work.
                guard !Task.isCancelled else { return }
                let upperBound = min(batch + Constants.batchSize, snapshot.entities.count)
                try await index.indexAppEntities(Array(snapshot.entities[batch ..< upperBound]))
            }
            // Indexed separately because `indexAppEntities` takes one entity type at a time; the two
            // share the index and the state so a single signature still covers both.
            if !snapshot.calendars.isEmpty {
                guard !Task.isCancelled else { return }
                try await index.indexAppEntities(snapshot.calendars)
            }
            save(IndexState(
                signature: snapshot.signature,
                entityIds: indexedIds,
                calendarIds: indexedCalendarIds
            ))
            Current.Log
                .info(
                    "Spotlight entity index updated (\(reason)): \(indexedIds.count) entities, \(indexedCalendarIds.count) calendars, \(staleIds.count + staleCalendarIds.count) removed"
                )
        } catch {
            Current.Log.error("Failed to update Spotlight entity index: \(error.localizedDescription)")
        }
    }

    /// The entities worth searching for, in a stable order, paired with a signature of everything the
    /// index carries. The server name is part of that signature even when it stays out of the displayed
    /// subtitle, because it is always indexed as a search term, so renaming a single server still
    /// rewrites the index.
    ///
    /// `nil` when the database can't be read, so a failed read never empties the index — an empty
    /// snapshot legitimately means "no servers" and does clear it.
    ///
    /// Hidden entities are excluded (as everywhere else in the app) and so are config/diagnostic ones,
    /// which would otherwise bury the entities people search for under firmware versions and signal
    /// strengths.
    private nonisolated static func makeSnapshot() -> Snapshot? {
        let servers = Current.servers.all.sorted { $0.identifier.rawValue < $1.identifier.rawValue }
        let includesServerContext = servers.count > 1

        let allEntities: [HAAppEntity]
        do {
            allEntities = try HAAppEntity.config()
        } catch {
            Current.Log.error("Failed to read entities for Spotlight index: \(error.localizedDescription)")
            return nil
        }

        var entities: [HAAppEntityAppIntentEntity] = []
        var signatureLines = ["serverContext=\(includesServerContext)"]

        for server in servers {
            let serverId = server.identifier.rawValue
            let serverEntities = allEntities
                .filter { $0.serverId == serverId && $0.entityCategory == nil }
                .sorted { $0.id < $1.id }
            let areasMap = serverEntities.areasMap(for: serverId)
            let devicesMap = serverEntities.devicesMap(for: serverId)
            let floorNamesMap = serverEntities.floorNamesMap(for: serverId)

            for entity in serverEntities {
                let indexed = HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: devicesMap[entity.entityId]?.name,
                    floorName: floorNamesMap[entity.entityId],
                    displayString: entity.name,
                    iconName: iconName(for: entity),
                    includesServerContext: includesServerContext
                )
                entities.append(indexed)
                signatureLines.append([
                    indexed.id,
                    indexed.displayString,
                    indexed.areaName ?? "",
                    indexed.deviceName ?? "",
                    indexed.floorName ?? "",
                    indexed.serverName,
                    indexed.iconName,
                ].joined(separator: "|"))
            }
        }

        let calendars = HACalendar.all().map(HACalendarAppEntity.init(calendar:))
        for calendar in calendars {
            signatureLines.append([
                "calendar",
                calendar.id,
                calendar.name,
                calendar.entityId,
                calendar.serverName ?? "",
            ].joined(separator: "|"))
        }

        return Snapshot(
            entities: entities,
            calendars: calendars,
            signature: signature(for: signatureLines)
        )
    }

    /// The same precedence the entity pickers use: the entity's own icon, then the frontend default
    /// resolved from the backend `entity_component` map, then the domain fallback.
    private nonisolated static func iconName(for entity: HAAppEntity) -> String {
        if let icon = entity.icon, !icon.isEmpty {
            return icon
        }
        if let resolvedIcon = entity.resolvedIcon, !resolvedIcon.isEmpty {
            return resolvedIcon
        }
        return Domain(rawValue: entity.domain)?.icon(deviceClass: entity.rawDeviceClass).name
            ?? MaterialDesignIcons.dotsGridIcon.name
    }

    private nonisolated static func signature(for lines: [String]) -> String {
        let payload = (["v\(Constants.formatVersion)"] + lines).joined(separator: "\n")
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadState() -> IndexState? {
        guard let data = defaults?.data(forKey: Constants.stateKey) else { return nil }
        return try? JSONDecoder().decode(IndexState.self, from: data)
    }

    private func save(_ state: IndexState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: Constants.stateKey)
    }
}
