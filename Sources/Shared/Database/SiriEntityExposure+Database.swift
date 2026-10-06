import Foundation
import GRDB

// `SiriEntityExposure` itself lives in the `HAModels` package; these are its
// `Current.database()`-backed queries.
public extension SiriEntityExposure {
    static func hiddenEntityIds(domain: String? = nil) -> Set<String> {
        Set(rows(domain: domain).filter { !$0.isExposed }.map(\.id))
    }

    static func isExposed(serverId: String, entityId: String) -> Bool {
        !hiddenEntityIds().contains(ServerEntity.uniqueId(serverId: serverId, entityId: entityId))
    }

    static func defaultEntityIds(domain: String) -> Set<String> {
        Set(rows(domain: domain).filter { $0.isDefault && $0.isExposed }.map(\.id))
    }

    static func defaultEntityId(serverId: String, domain: String) -> String? {
        rows(domain: domain).first { $0.serverId == serverId && $0.isDefault && $0.isExposed }?.id
    }

    static func setExposed(_ isExposed: Bool, serverId: String, entityId: String, domain: String) {
        do {
            try Current.database().write { db in
                let id = ServerEntity.uniqueId(serverId: serverId, entityId: entityId)
                let existing = try SiriEntityExposure.fetchOne(db, key: id)
                try SiriEntityExposure(
                    serverId: serverId,
                    entityId: entityId,
                    domain: domain,
                    isExposed: isExposed,
                    isDefault: isExposed && (existing?.isDefault ?? false)
                ).insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save Siri exposure for \(entityId), error: \(error.localizedDescription)")
        }
    }

    static func setDefault(entityId: String?, serverId: String, domain: String) {
        do {
            try Current.database().write { db in
                try SiriEntityExposure
                    .filter(Column(DatabaseTables.SiriEntityExposure.serverId.rawValue) == serverId)
                    .filter(Column(DatabaseTables.SiriEntityExposure.domain.rawValue) == domain)
                    .updateAll(db, Column(DatabaseTables.SiriEntityExposure.isDefault.rawValue).set(to: false))
                guard let entityId else { return }
                try SiriEntityExposure(
                    serverId: serverId,
                    entityId: entityId,
                    domain: domain,
                    isExposed: true,
                    isDefault: true
                ).insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save Siri default for \(serverId), error: \(error.localizedDescription)")
        }
    }

    static func delete(serverId: String) {
        do {
            _ = try Current.database().write { db in
                try SiriEntityExposure
                    .filter(Column(DatabaseTables.SiriEntityExposure.serverId.rawValue) == serverId)
                    .deleteAll(db)
            }
        } catch {
            Current.Log.error("Failed to delete Siri exposure for \(serverId), error: \(error.localizedDescription)")
        }
    }

    private static func rows(domain: String?) -> [SiriEntityExposure] {
        do {
            return try Current.database().read { db in
                if let domain {
                    return try SiriEntityExposure
                        .filter(Column(DatabaseTables.SiriEntityExposure.domain.rawValue) == domain)
                        .fetchAll(db)
                }
                return try SiriEntityExposure.fetchAll(db)
            }
        } catch {
            Current.Log.error("Failed to read Siri entity exposure, error: \(error.localizedDescription)")
            return []
        }
    }
}
