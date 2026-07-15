import Foundation
import GRDB
import RealmSwift

// MARK: - Legacy Realm models

// These minimal Object subclasses mirror the final (v29) Realm schema of the
// models that used to live in Realm. The `@objc(...)` names must match the
// historical class names so Realm maps them onto the existing tables. They
// exist purely so `RealmToGRDBMigration` can read the legacy store; nothing
// else in the app may import RealmSwift.

@objc(RLMZone)
private final class LegacyRealmZone: Object {
    @objc dynamic var identifier: String = ""
    @objc dynamic var entityId: String = ""
    @objc dynamic var serverIdentifier: String = ""
    @objc dynamic var FriendlyName: String?
    @objc dynamic var Latitude: Double = 0.0
    @objc dynamic var Longitude: Double = 0.0
    @objc dynamic var Radius: Double = 0.0
    @objc dynamic var TrackingEnabled = true
    @objc dynamic var enterNotification = true
    @objc dynamic var exitNotification = true
    @objc dynamic var inRegion = false
    @objc dynamic var isPassive = false
    @objc dynamic var BeaconUUID: String?
    let BeaconMajor = RealmProperty<Int?>()
    let BeaconMinor = RealmProperty<Int?>()
    var SSIDTrigger = List<String>()
    var SSIDFilter = List<String>()

    override static func primaryKey() -> String? { "identifier" }
}

@objc(NotificationAction)
private final class LegacyRealmNotificationAction: Object {
    @objc dynamic var uuid: String = UUID().uuidString
    @objc dynamic var Identifier: String = ""
    @objc dynamic var Title: String = ""
    @objc dynamic var TextInput: Bool = false
    @objc dynamic var isServerControlled: Bool = false
    @objc dynamic var icon: String?
    @objc dynamic var Foreground: Bool = false
    @objc dynamic var Destructive: Bool = false
    @objc dynamic var AuthenticationRequired: Bool = false
    @objc dynamic var TextInputButtonTitle: String = ""
    @objc dynamic var TextInputPlaceholder: String = ""

    override static func primaryKey() -> String? { "uuid" }
}

@objc(NotificationCategory)
private final class LegacyRealmNotificationCategory: Object {
    @objc dynamic var isServerControlled: Bool = false
    @objc dynamic var serverIdentifier: String = ""
    @objc dynamic var Name: String = ""
    @objc dynamic var Identifier: String = ""
    @objc dynamic var HiddenPreviewsBodyPlaceholder: String?
    @objc dynamic var CategorySummaryFormat: String?
    @objc dynamic var SendDismissActions: Bool = true
    @objc dynamic var HiddenPreviewsShowTitle: Bool = false
    @objc dynamic var HiddenPreviewsShowSubtitle: Bool = false
    var Actions = List<LegacyRealmNotificationAction>()

    override static func primaryKey() -> String? { "Identifier" }
}

@objc(WatchComplication)
private final class LegacyRealmWatchComplication: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var serverIdentifier: String?
    @objc dynamic var rawFamily: String = ""
    @objc dynamic var rawTemplate: String = ""
    @objc dynamic var complicationData: Data?
    @objc dynamic var CreatedAt = Date()
    @objc dynamic var name: String?
    @objc dynamic var IsPublic: Bool = true

    override static func primaryKey() -> String? { "identifier" }
}

// MARK: - Migration

/// One-time import of the legacy Realm store into GRDB.
///
/// Runs at startup of the main app (and the watch app). Once every model has
/// been imported the completion flag is set and the Realm store is never
/// opened again; a future release can then drop the RealmSwift dependency and
/// this file, and delete the legacy store directory.
public enum RealmToGRDBMigration {
    static let migrationCompletedKey = "hasCompletedRealmToGRDBMigration"
    static let migrationAttemptsKey = "realmToGRDBMigrationAttempts"
    static let maxMigrationAttempts = 3

    public static func migrateIfNeeded() {
        guard NSClassFromString("XCTest") == nil else { return }

        let prefs = Current.settingsStore.prefs
        guard !prefs.bool(forKey: migrationCompletedKey) else { return }

        let storeURL = storeDirectoryURL.appendingPathComponent("store.realm", isDirectory: false)

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            // fresh install, nothing to migrate
            prefs.set(true, forKey: migrationCompletedKey)
            return
        }

        let attempt = prefs.integer(forKey: migrationAttemptsKey) + 1
        prefs.set(attempt, forKey: migrationAttemptsKey)
        guard attempt <= maxMigrationAttempts else {
            // A store that always fails to open (corrupt, or a schema newer
            // than we know about) would otherwise be retried, and reported as
            // an error, on every launch forever. Give up after a few tries and
            // leave the store on disk untouched.
            Current.Log.error("Abandoning Realm to GRDB migration after \(attempt - 1) failed attempts")
            prefs.set(true, forKey: migrationCompletedKey)
            return
        }

        do {
            let realm = try legacyRealm(storeURL: storeURL)
            let counts = try migrate(realm: realm)
            prefs.set(true, forKey: migrationCompletedKey)

            let message = "Migrated Realm to GRDB: " +
                "\(counts.zones) zone(s), " +
                "\(counts.categories) notification category(ies), " +
                "\(counts.complications) complication(s)"
            Current.Log.info(message)
            Current.clientEventStore.addEvent(ClientEvent(text: message, type: .database))
        } catch {
            // Not setting the completion flag means we retry on next launch,
            // up to maxMigrationAttempts.
            Current.Log.error("Realm to GRDB migration failed (attempt \(attempt)): \(error)")
            Current.crashReporter.logError(error as NSError)
        }
    }

    /// Deletes the legacy Realm store and its side files. Used by the app
    /// reset flow: without this a reset would clear GRDB and the completion
    /// flag but leave the Realm store on disk, so the importer would run again
    /// on the next launch and resurrect the data the user just wiped.
    public static func deleteLegacyStore() {
        let storeURL = storeDirectoryURL.appendingPathComponent("store.realm", isDirectory: false)
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            _ = try Realm.deleteFiles(for: Realm.Configuration(fileURL: storeURL))
        } catch {
            Current.Log.error("Failed to delete legacy Realm store: \(error)")
        }
    }

    private static var storeDirectoryURL: URL {
        let fileManager = FileManager.default
        let storeDirectoryURL = fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: AppConstants.AppGroupID)?
            .appendingPathComponent("dataStore", isDirectory: true)

        if storeDirectoryURL == nil {
            Current.Log.error("Unable to get directory URL! AppGroupID: \(AppConstants.AppGroupID)")
        }

        return storeDirectoryURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    private static func legacyRealm(storeURL: URL) throws -> Realm {
        // Schema history:
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
        let config = Realm.Configuration(
            fileURL: storeURL,
            schemaVersion: 29,
            migrationBlock: { migration, oldVersion in
                Current.Log.info("migrating legacy realm from \(oldVersion)")
                if oldVersion < 9 {
                    migration.enumerateObjects(ofType: "NotificationAction") { _, newObject in
                        newObject?["uuid"] = UUID().uuidString
                    }
                }

                if oldVersion < 11 {
                    // Identifier is a primary key, and Realm is _suppose_ to prevent this from being possible
                    // but it seems like some time in the past, it allowed the same identifier to be inserted >1 time
                    var discoveredIdentifiers = Set<String>()
                    migration.enumerateObjects(ofType: "NotificationCategory") { _, newObject in
                        if let newObject, let identifier = newObject["Identifier"] as? String {
                            if discoveredIdentifiers.contains(identifier) {
                                migration.delete(newObject)
                            } else {
                                discoveredIdentifiers.insert(identifier)
                            }
                        }
                    }
                }

                if oldVersion < 13 {
                    migration.enumerateObjects(ofType: "WatchComplication") { _, newObject in
                        // initially creating these with their old family name
                        // this is so we migrate them to have identical names on both watch and phone, independently
                        // since future objects are created with a UUID-based identifier, this won't be an issue
                        // we also need to reference them by family for complications configured prior to watchOS 7
                        newObject!["identifier"] = newObject!["rawFamily"]
                    }
                }

                if oldVersion < 14 {
                    migration.enumerateObjects(ofType: "WatchComplication") { _, newObject in
                        newObject?["IsPublic"] = true
                    }
                }

                if oldVersion < 18 {
                    // set the serverIdentifier to the historic value for anything synced earlier
                    for typeName in ["NotificationCategory", "RLMZone", "WatchComplication"] {
                        migration.enumerateObjects(ofType: typeName) { _, newObject in
                            newObject?["serverIdentifier"] = Server.historicId.rawValue
                        }
                    }
                }

                if oldVersion < 19 {
                    migration.renameProperty(onType: "RLMZone", from: "ID", to: "entityId")

                    migration.enumerateObjects(ofType: "RLMZone") { oldObject, newObject in
                        if let oldId = oldObject?["ID"] as? String,
                           let serverId = newObject?["serverIdentifier"] as? String {
                            let newId = AppZone.primaryKey(sourceIdentifier: oldId, serverIdentifier: serverId)
                            newObject?["identifier"] = newId
                        }
                    }
                }
            },
            deleteRealmIfMigrationNeeded: false,
            objectTypes: [
                LegacyRealmZone.self,
                LegacyRealmNotificationAction.self,
                LegacyRealmNotificationCategory.self,
                LegacyRealmWatchComplication.self,
            ]
        )

        return try Realm(configuration: config)
    }

    private static func migrate(realm: Realm) throws -> (zones: Int, categories: Int, complications: Int) {
        let zones: [AppZone] = realm.objects(LegacyRealmZone.self).map { legacy in
            AppZone(
                entityId: legacy.entityId,
                serverIdentifier: legacy.serverIdentifier,
                friendlyName: legacy.FriendlyName,
                latitude: legacy.Latitude,
                longitude: legacy.Longitude,
                radius: legacy.Radius,
                trackingEnabled: legacy.TrackingEnabled,
                enterNotification: legacy.enterNotification,
                exitNotification: legacy.exitNotification,
                inRegion: legacy.inRegion,
                isPassive: legacy.isPassive,
                beaconUUID: legacy.BeaconUUID,
                beaconMajor: legacy.BeaconMajor.value,
                beaconMinor: legacy.BeaconMinor.value,
                ssidTrigger: Array(legacy.SSIDTrigger),
                ssidFilter: Array(legacy.SSIDFilter)
            )
        }

        let categories: [NotificationCategory] = realm.objects(LegacyRealmNotificationCategory.self).map { legacy in
            NotificationCategory(
                identifier: legacy.Identifier,
                serverIdentifier: legacy.serverIdentifier,
                name: legacy.Name,
                isServerControlled: legacy.isServerControlled,
                hiddenPreviewsBodyPlaceholder: legacy.HiddenPreviewsBodyPlaceholder,
                categorySummaryFormat: legacy.CategorySummaryFormat,
                sendDismissActions: legacy.SendDismissActions,
                hiddenPreviewsShowTitle: legacy.HiddenPreviewsShowTitle,
                hiddenPreviewsShowSubtitle: legacy.HiddenPreviewsShowSubtitle,
                actions: legacy.Actions.map { action in
                    NotificationAction(
                        id: action.uuid,
                        identifier: action.Identifier,
                        title: action.Title,
                        textInput: action.TextInput,
                        isServerControlled: action.isServerControlled,
                        icon: action.icon,
                        foreground: action.Foreground,
                        destructive: action.Destructive,
                        authenticationRequired: action.AuthenticationRequired,
                        textInputButtonTitle: action.TextInputButtonTitle,
                        textInputPlaceholder: action.TextInputPlaceholder
                    )
                }
            )
        }

        let complications: [WatchComplication] = realm.objects(LegacyRealmWatchComplication.self).map { legacy in
            var complication = WatchComplication(
                identifier: legacy.identifier,
                serverIdentifier: legacy.serverIdentifier,
                family: ComplicationGroupMember(rawValue: legacy.rawFamily) ?? .modularSmall,
                template: ComplicationTemplate(rawValue: legacy.rawTemplate),
                createdAt: legacy.CreatedAt,
                name: legacy.name,
                isPublic: legacy.IsPublic
            )
            complication.complicationData = Self.migratingMDIIcon(in: legacy.complicationData)
                .flatMap { String(data: $0, encoding: .utf8) }
            return complication
        }

        try Current.database().write { db in
            for zone in zones {
                try zone.save(db)
            }
            for category in categories {
                try category.save(db)
            }
            for complication in complications {
                try complication.save(db)
            }
        }

        return (zones: zones.count, categories: categories.count, complications: complications.count)
    }

    /// The legacy store always migrated MDI icon names on open; apply the same
    /// migration while importing so renamed icons keep working.
    private static func migratingMDIIcon(in complicationData: Data?) -> Data? {
        guard let complicationData,
              let json = try? JSONSerialization.jsonObject(with: complicationData) as? [String: Any],
              let iconDict = json["icon"] as? [String: String],
              let icon = iconDict["icon"] else {
            return complicationData
        }

        var updatedIconDict = iconDict
        updatedIconDict["icon"] = MDIMigration.migrate(icon: icon)
        var updatedJson = json
        updatedJson["icon"] = updatedIconDict

        return (try? JSONSerialization.data(withJSONObject: updatedJson)) ?? complicationData
    }
}
