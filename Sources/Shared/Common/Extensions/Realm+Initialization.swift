import Foundation
import RealmSwift
#if os(iOS)
import UIKit
#endif
import PromiseKit

public extension Realm {
    /// An in-memory data store, intended to be used in tests.
    static let mock: () -> Realm = {
        do {
            return try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Memory"))
        } catch {
            fatalError("Error setting up Realm.mock! \(error)")
        }
    }

    static var storeDirectoryURL: URL {
        let fileManager = FileManager.default
        let storeDirectoryURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID)?
            .appendingPathComponent("dataStore", isDirectory: true)

        if storeDirectoryURL == nil {
            Current.Log.error("Unable to get directory URL! AppGroupID: \(AppConstants.AppGroupID)")
        }

        return storeDirectoryURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    /// The live data store, located in shared storage.
    static let live: () -> Realm = {
        getRealm()
    }

    // swiftlint:disable cyclomatic_complexity
    /// Mainly used to specify objectTypes in a context such as an extension, otherwise always use "Realm.live"
    static func getRealm(objectTypes: [ObjectBase.Type]? = nil) -> Realm {
        if NSClassFromString("XCTest") != nil {
            do {
                return try Realm(configuration: .init(inMemoryIdentifier: "Tests", deleteRealmIfMigrationNeeded: true))
            } catch {
                fatalError("couldn't create realm in unit test")
            }
        }

        let fileManager = FileManager.default

        let directoryURL = Realm.storeDirectoryURL

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                let attributes =
                    [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                try fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: attributes
                )
            } catch {
                Realm.handleError(
                    message: "Error while attempting to create data store URL",
                    error: error
                )
            }
        }

        let storeURL = directoryURL.appendingPathComponent("store.realm", isDirectory: false)

        #if targetEnvironment(simulator)
        Current.Log.info("Realm is stored at \(storeURL.description)")
        #endif

        // 5  - 2020-07-08 v2020.4
        // 6  - 2020-07-12 v2020.4
        // 9  - 2020-07-23 v2020.5 (primary key removal on NotificationAction)
        // 11 - 2020-08-12 v2020.5.2 (cleaning up duplicate NotificationCategory identifiers)
        // 12 - 2020-08-16 v2020.6 (mdi upgrade/migration to 5.x)
        // 13 - 2020-10-17 v2020.7 (allow multiple complications)
        // 14 - 2020-10-29 v2020.8 (complication privacy)
        // 15 - 2021-03-21 v2021.4 (scene properties)
        // 16 - 2021-04-12 v2021.5 (accuracy authorization on location history entries)
        // 17 - 2021-09-20 v2021.10 (added notification action key icon)
        // 18 - 2021-11-15 v2021.12 (added server identifier keys to various models)
        // 19 - 2021-11-27 v2021.12 (zone property renames)
        // 20…25 - 2022-08-13 v2022.x undoing realm automatic migration
        // 26 - 2022-08-13 v2022.x bumping mdi version
        // 29 - 2026-05-27 v2026.x Remove legacy iOS action Realm models
        // 30 - 2026-07 v2026.x Migrate WatchComplication from Realm to GRDB

        // Current schema version from database
        if let currentSchemaVersion = try? schemaVersionAtURL(storeURL) {
            Current.Log.verbose("Current schema version \(currentSchemaVersion)")
        }

        // New schema version
        let schemaVersion: UInt64 = 30
        Current.Log.verbose("Schema version defined: \(schemaVersion)")

        let config = Realm.Configuration(
            fileURL: storeURL,
            schemaVersion: schemaVersion,
            migrationBlock: { migration, oldVersion in
                Current.Log.info("migrating from \(oldVersion)")
                if oldVersion < 9 {
                    migration.enumerateObjects(ofType: NotificationAction.className()) { _, newObject in
                        newObject?["uuid"] = UUID().uuidString
                    }
                }

                if oldVersion < 11 {
                    // Identifier is a primary key, and Realm is _suppose_ to prevent this from being possible
                    // but it seems like some time in the past, it allowed the same identifier to be inserted >1 time
                    var discoveredIdentifiers = Set<String>()
                    migration.enumerateObjects(ofType: NotificationCategory.className()) { _, newObject in
                        if let newObject, let identifier = newObject["Identifier"] as? String {
                            if discoveredIdentifiers.contains(identifier) {
                                migration.delete(newObject)
                            } else {
                                discoveredIdentifiers.insert(identifier)
                            }
                        }
                    }
                }

                // WatchComplication moved off Realm to GRDB; its historical Realm migrations
                // (v13/v14 identifier + IsPublic, v18 serverIdentifier, MDI icon) are handled by the
                // one-time Realm→GRDB migration instead.

                if oldVersion < 16 {
                    // nothing, it added an optional
                }

                if oldVersion < 17 {
                    // nothing, it added an optional
                }

                if oldVersion < 18 {
                    // set the serverIdentifier to the historic value for anything synced earlier
                    func migrate(_ modelType: (some Object & UpdatableModel).Type) {
                        migration.enumerateObjects(ofType: modelType.className()) { _, newObject in
                            newObject?[modelType.serverIdentifierKey()] = Server.historicId.rawValue
                        }
                    }

                    migrate(NotificationCategory.self)
                    migrate(RLMZone.self)
                }

                if oldVersion < 19 {
                    migration.renameProperty(onType: RLMZone.className(), from: "ID", to: "entityId")

                    migration.enumerateObjects(ofType: RLMZone.className()) { oldObject, newObject in
                        if let oldId = oldObject?["ID"] as? String,
                           let serverId = newObject?["serverIdentifier"] as? String {
                            let newId = RLMZone.primaryKey(sourceIdentifier: oldId, serverIdentifier: serverId)
                            Current.Log.info("change \(oldId) + \(serverId) to \(newId)")
                            newObject?["identifier"] = newId
                        }
                    }
                }

                if oldVersion < 30 {
                    // One-time migration of legacy watch complications from Realm to GRDB. The
                    // `WatchComplication` class no longer exists, so we read the old rows dynamically and
                    // write GRDB records (mirroring the historic v13/v14/v18 + MDI icon fixups).
                    migration.enumerateObjects(ofType: "WatchComplication") { oldObject, _ in
                        guard let oldObject else { return }
                        let dataString: String? = (oldObject["complicationData"] as? Data)
                            .flatMap { String(data: $0, encoding: .utf8) }
                        var complication = WatchComplication(
                            identifier: (oldObject["identifier"] as? String) ?? UUID().uuidString,
                            serverIdentifier: (oldObject["serverIdentifier"] as? String) ?? Server.historicId.rawValue,
                            family: ComplicationGroupMember(rawValue: (oldObject["rawFamily"] as? String) ?? "")
                                ?? .modularSmall,
                            template: ComplicationTemplate(rawValue: (oldObject["rawTemplate"] as? String) ?? ""),
                            createdAt: (oldObject["CreatedAt"] as? Date) ?? Current.date(),
                            name: oldObject["name"] as? String,
                            isPublic: (oldObject["IsPublic"] as? Bool) ?? true
                        )
                        complication.complicationData = dataString
                        do {
                            try complication.save()
                        } catch {
                            Current.Log.error("Failed to migrate complication \(complication.identifier): \(error)")
                        }
                    }
                }
            },
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: { realmFileSizeInBytes, usedBytes in
                // from https://www.mongodb.com/docs/realm/sdk/swift/realm-files/compacting/
                let maxFileSize = 10 * 1024 * 1024
                // Check for the realm file size to be greater than the max file size, and the amount of bytes
                // currently used to be less than 50% of the total realm file size
                return (realmFileSizeInBytes > maxFileSize) && (Double(usedBytes) / Double(realmFileSizeInBytes)) < 0.5
            },
            objectTypes: objectTypes
        )

        do {
            return try Realm(configuration: config)
        } catch {
            Current.crashReporter.logError(error as NSError)

            Realm.handleError(
                message: error.localizedDescription,
                error: error
            )

            do {
                // Temporarily provide an in-memory instance so we don't crash. The identifier must be
                // unique per call: in-memory Realms share schema by identifier, so reusing one across
                // calls with different `objectTypes` throws a schema mismatch — which used to hit the
                // fatalError below and take the whole app down at launch.
                return try Realm(configuration: .init(
                    inMemoryIdentifier: "Fallback-\(UUID().uuidString)",
                    objectTypes: objectTypes
                ))
            } catch {
                fatalError(String(describing: error))
            }
        }
    }

    /// Backup the Realm database, returning the URL of the backup location.
    static func backup() -> URL? {
        let backupURL = Realm.storeDirectoryURL.appendingPathComponent("backup.realm")

        if FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                _ = try FileManager.default.removeItem(at: backupURL)
            } catch {
                Current.Log.error("Error while removing existing Realm backup: \(error)")
            }
        }

        let realm = Realm.live()
        realm.beginWrite()

        do {
            try realm.writeCopy(toFile: backupURL)
        } catch {
            Current.Log.error("Error while writing copy of database to URL \(backupURL): \(error)")
            return nil
        }

        realm.cancelWrite()

        return backupURL
    }

    /// Deletes all Realm objects
    static func reset() {
        let realm = Realm.live()
        realm.beginWrite()
        realm.deleteAll()
        try? realm.commitWrite()
    }

    private static var hasShownError = false

    private static func handleError(
        message: String,
        error: Swift.Error
    ) {
        Current.crashReporter.logError(error as NSError)
        Current.Log.error([message, error])

        #if os(iOS)
        DispatchQueue.main.async {
            guard !hasShownError else {
                return
            }

            hasShownError = true

            let alert = UIAlertController(
                title: L10n.Database.Problem.title,
                message: error.localizedDescription,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: L10n.Database.Problem.delete, style: .destructive, handler: { _ in
                // swiftlint:disable:next force_try
                try! FileManager.default.removeItem(at: storeDirectoryURL)
                exit(1)
            }))
            alert.addAction(UIAlertAction(title: L10n.Database.Problem.quit, style: .cancel, handler: { _ in
                exit(1)
            }))

            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
                if let handler = Current.realmFatalPresentation {
                    handler(alert)
                    timer.invalidate()
                }
            })

            timer.fire()
        }
        #else
        // Don't crash here: on watchOS this ran before `getRealm`'s in-memory fallback could engage,
        // so any Realm open error (e.g. file locked during a background wake) killed the app instead
        // of degrading to the fallback store.
        Current.Log.error("Realm error (continuing with fallback): \(message) \(error.localizedDescription)")
        #endif
    }

    @discardableResult
    func reentrantWrite<Result>(
        withoutNotifying tokens: [NotificationToken] = [],
        _ block: () throws -> Result
    ) -> Promise<Result> {
        let promise: Promise<Result>

        if isInWriteTransaction {
            promise = Promise { seal in
                try seal.fulfill(block())
            }
        } else {
            promise = Current.backgroundTask(withName: BackgroundTask.realmWrite.rawValue) { _ in
                Promise<Result> { seal in
                    try seal.fulfill(write(withoutNotifying: tokens, block))
                }
            }
        }

        promise.catch { error in
            Current.Log.error(error)
        }

        return promise
    }
}
