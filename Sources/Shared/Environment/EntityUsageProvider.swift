import Foundation
import HAKit

/// Reads and refreshes the cache of the entities the signed-in user controls most.
///
/// The ranking itself is the backend's: `usage_prediction/common_control` computes it per user from
/// the last 30 days of service calls and only ever answers for the time of day it is asked in. This
/// keeps each answer in the app's database so the app and its extensions can order entities by how
/// much the user actually uses them without a round trip, and so a widget that cannot reach the
/// server shows the last known ranking instead of nothing.
///
/// Widgets refresh it too, not only the app: the app cannot ask for a bucket it is never open for,
/// and a household that never opens the app at night would otherwise keep an empty `night` bucket
/// forever. The table itself is created by the app (extensions skip schema setup), so a write from
/// an extension before the app has ever run is logged and dropped — the fetched ranking is still
/// returned and shown.
public protocol EntityUsageProviderProtocol {
    /// Fetches the ranking for the current time of day and caches it, returning the entity ids to
    /// show now. A failed request falls back to the cache rather than an empty list.
    @discardableResult
    func refresh(for server: Server, now: Date) async -> [String]

    /// The server's most-used entity ids from the cache alone, most used first.
    ///
    /// Merged across every time of day, so the order is the same all day: a list of suggestions
    /// that reshuffles itself at 6pm is harder to use than one that doesn't.
    func mostUsedEntityIds(serverId: String, limit: Int?) -> [String]
}

public extension EntityUsageProviderProtocol {
    @discardableResult
    func refresh(for server: Server) async -> [String] {
        await refresh(for: server, now: Date())
    }

    func mostUsedEntityIds(serverId: String) -> [String] {
        mostUsedEntityIds(serverId: serverId, limit: nil)
    }
}

final class EntityUsageProvider: EntityUsageProviderProtocol {
    static var shared: EntityUsageProviderProtocol = EntityUsageProvider()

    func refresh(for server: Server, now: Date) async -> [String] {
        let serverId = server.identifier.rawValue
        let timeCategory = EntityUsageTimeCategory.forDate(now)

        guard let fetched = await fetch(for: server) else {
            // The request failed: keep what is cached (an unreachable server says nothing about
            // what the user uses) and answer from it, leading with this time of day.
            return EntityUsageRecord.rankedEntityIds(
                serverId: serverId,
                currentCategory: timeCategory,
                now: now
            )
        }

        EntityUsageRecord.save(
            entityIds: fetched,
            serverId: serverId,
            timeCategory: timeCategory,
            now: now
        )
        // Housekeeping is the app's: a widget refreshes every 15 minutes and there is no reason for
        // each of those to take a write lock on the shared database to find nothing to delete.
        if !Current.isAppExtension {
            EntityUsageRecord.prune(
                now: now,
                knownServerIds: Set(Current.servers.all.map(\.identifier.rawValue))
            )
        }
        return fetched
    }

    func mostUsedEntityIds(serverId: String, limit: Int?) -> [String] {
        EntityUsageRecord.rankedEntityIds(serverId: serverId, limit: limit)
    }

    /// The backend's ranking for right now, or `nil` when the request failed — which is not the
    /// same as an empty ranking, and must not overwrite the cache.
    private func fetch(for server: Server) async -> [String]? {
        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to fetch usage prediction: no API available for server")
            return nil
        }

        return await withCheckedContinuation { (continuation: CheckedContinuation<[String]?, Never>) in
            api.connection.send(.usagePredictionCommonControl()) { result in
                switch result {
                case let .success(response):
                    continuation.resume(returning: response.entities)
                case let .failure(error):
                    Current.Log.error("Failed to fetch usage prediction: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
