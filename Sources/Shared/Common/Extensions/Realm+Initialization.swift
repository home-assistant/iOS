//
//  Realm+Initialization.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift
#if os(iOS)
import UIKit
#endif

extension Realm {
    /// An in-memory data store, intended to be used in tests.
    public static let mock: () -> Realm = {
        do {
            return try Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Memory"))
        } catch let error {
            fatalError("Error setting up Realm.mock! \(error)")
        }
    }

    public static var storeDirectoryURL: URL {
        let fileManager = FileManager.default
        let storeDirectoryURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)?
            .appendingPathComponent("dataStore", isDirectory: true)

        if storeDirectoryURL == nil {
            Current.Log.error("Unable to get directory URL! AppGroupID: \(Constants.AppGroupID)")
        }

        return storeDirectoryURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    /// The live data store, located in shared storage.
    public static let live: () -> Realm = {
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
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                                attributes: attributes)
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
        // 7  - 2020-07-20 v2020.5 (added RLMScene)
        // 9  - 2020-07-23 v2020.5 (primary key removal on NotificationAction)
        // 10 - 2020-07-31 v2020.5 (added isServerControlled to Action)
        // 11 - 2020-08-12 v2020.5.2 (cleaning up duplicate NotificationCategory identifiers)
        // 12 - 2020-08-16 v2020.6 (mdi upgrade/migration to 5.x)
        // 13 - 2020-10-17 v2020.7 (allow multiple complications)
        // 14 - 2020-10-29 v2020.8 (complication privacy)
        let config = Realm.Configuration(
            fileURL: storeURL,
            schemaVersion: 14,
            migrationBlock: { migration, oldVersion in
                Current.Log.info("migrating from \(oldVersion)")
                if oldVersion < 9 {
                    migration.enumerateObjects(ofType: NotificationAction.className()) { _, newObject in
                        newObject?["uuid"] = UUID().uuidString
                    }
                }

                if oldVersion < 10 {
                    migration.enumerateObjects(ofType: Action.className()) { _, newObject in
                        newObject?["isServerControlled"] = false
                    }
                }

                if oldVersion < 11 {
                    // Identifier is a primary key, and Realm is _suppose_ to prevent this from being possible
                    // but it seems like some time in the past, it allowed the same identifier to be inserted >1 time
                    var discoveredIdentifiers = Set<String>()
                    migration.enumerateObjects(ofType: NotificationCategory.className()) { _, newObject in
                        if let newObject = newObject, let identifier = newObject["Identifier"] as? String {
                            if discoveredIdentifiers.contains(identifier) {
                                migration.delete(newObject)
                            } else {
                                discoveredIdentifiers.insert(identifier)
                            }
                        }
                    }
                }

                if oldVersion < 12 {
                    let mdiMigration = MDIMigration()
                    migration.enumerateObjects(ofType: Action.className()) { _, newObject in
                        let iconNameKey = "IconName"
                        if let oldIconName = newObject?[iconNameKey] as? String {
                            newObject?[iconNameKey] = mdiMigration.migrate(icon: oldIconName)
                        }
                    }
                    migration.enumerateObjects(ofType: WatchComplication.className()) { _, newObject in
                        let dataKey = "complicationData"
                        let iconDictKey = "icon"
                        let iconDictIconKey = "icon"

                        if let oldData = newObject?[dataKey] as? Data,
                           // swiftlint:disable:next line_length
                           let oldJson = try? JSONSerialization.jsonObject(with: oldData, options: []) as? [String: Any],
                           let oldIconDict = oldJson[iconDictKey] as? [String: String],
                           let oldIconIcon = oldIconDict[iconDictIconKey] {
                            var updatedIconDict = oldIconDict
                            updatedIconDict[iconDictIconKey] = mdiMigration.migrate(icon: oldIconIcon)
                            var updatedJson = oldJson
                            updatedJson[iconDictKey] = updatedIconDict
                            if let newData = try? JSONSerialization.data(withJSONObject: updatedJson, options: []) {
                                newObject?[dataKey] = newData
                            }
                        }
                    }
                }

                if oldVersion < 13 {
                    migration.enumerateObjects(ofType: WatchComplication.className()) { _, newObject in
                        // initially creating these with their old family name
                        // this is so we migrate them to have identical names on both watch and phone, independently
                        // since future objects are created with a UUID-based identifier, this won't be an issue
                        // we also need to reference them by family for complications configured prior to watchOS 7
                        newObject!["identifier"] = newObject!["rawFamily"]
                    }
                }

                if oldVersion < 14 {
                    migration.enumerateObjects(ofType: WatchComplication.className()) { _, newObject in
                         newObject?["IsPublic"] = true
                    }
                }
            },
            deleteRealmIfMigrationNeeded: false
        )

        do {
            return try Realm(configuration: config)
        } catch let error {
            Current.crashReporter.logError(error as NSError)

            Realm.handleError(
                message: error.localizedDescription,
                error: error
            )

            do {
                // temporarily provide an in-memory instance so we don't crash
                return try Realm(configuration: .init(inMemoryIdentifier: "Fallback"))
            } catch {
                fatalError(String(describing: error))
            }
        }
    }

    /// Backup the Realm database, returning the URL of the backup location.
    public static func backup() -> URL? {
        let backupURL = Realm.storeDirectoryURL.appendingPathComponent("backup.realm")

        if FileManager.default.fileExists(atPath: backupURL.path) {
            do {
                _ = try FileManager.default.removeItem(at: backupURL)
            } catch let error {
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
    public static func reset() {
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
        fatalError("\(message) \(error.localizedDescription)")
        #endif
    }

    public func reentrantWrite<Result>(
        withoutNotifying tokens: [NotificationToken] = [],
        _ block: (() throws -> Result)
    ) throws -> Result {
        if isInWriteTransaction {
            return try block()
        } else {
            return try write(withoutNotifying: tokens, block)
        }
    }
}
