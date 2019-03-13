//
//  Realm+Initialization.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/21/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import RealmSwift

extension Realm {
    /// An in-memory data store, intended to be used in tests.
    public static let mock = {
        // swiftlint:disable:next force_try
        try! Realm(configuration: Realm.Configuration(inMemoryIdentifier: "Memory"))
    }

    public static var storeDirectoryURL: URL {
        let fileManager = FileManager.default
        let storeDirectoryURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Constants.AppGroupID)?
            .appendingPathComponent("dataStore", isDirectory: true)

        guard let directoryURL = storeDirectoryURL else {
            fatalError("Unable to get datastoreURL.")
        }

        return directoryURL
    }

    /// The live data store, located in shared storage.
    public static let live: () -> Realm = {
        let fileManager = FileManager.default

        let directoryURL = Realm.storeDirectoryURL

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                let attributes =
                    [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                                attributes: attributes)
            } catch {
                Current.Log.error("Error while attempting to create data store URL: \(error)")
            }
        }

        let storeURL =  directoryURL.appendingPathComponent("store.realm", isDirectory: false)

        #if targetEnvironment(simulator)
            Current.Log.info("Realm is stored at \(storeURL.description)")
        #endif

        let config = Realm.Configuration(fileURL: storeURL, schemaVersion: 4,
                                         migrationBlock: nil, deleteRealmIfMigrationNeeded: true)
        // swiftlint:disable:next force_try
        return try! Realm(configuration: config)
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
}
