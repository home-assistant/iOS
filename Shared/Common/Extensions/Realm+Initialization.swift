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

        guard let directoryURL = storeDirectoryURL else {
            Current.Log.error("Unable to get directory URL! AppGroupID: \(Constants.AppGroupID)")
            Realm.handleFatalError("Unable to get datastoreURL for Realm!.", HomeAssistantAPI.APIError.unknown)
            return URL(string: "http://somethingbroke.fake")!
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
            } catch let error as NSError {
                Realm.handleFatalError("Error while attempting to create data store URL", error)
            }
        }

        let storeURL = directoryURL.appendingPathComponent("store.realm", isDirectory: false)

        #if targetEnvironment(simulator)
            Current.Log.info("Realm is stored at \(storeURL.description)")
        #endif

        let config = Realm.Configuration(fileURL: storeURL, schemaVersion: 4,
                                         migrationBlock: nil, deleteRealmIfMigrationNeeded: false)
        var configuredRealm: Realm!
        do {
            configuredRealm = try Realm(configuration: config)
        } catch let error as NSError {
            Realm.handleFatalError("Error while attempting to create Realm", error)
        }
        return configuredRealm
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

    private static func handleFatalError(_ message: String, _ error: Swift.Error) {
        let errMsg = "\(message): \(error)"
        Current.Log.error(errMsg)
        #if os(iOS)
        let alert = UIAlertController(title: "Realm Error!",
                                      message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Quit App", style: .destructive, handler: { _ in exit(1) }))

        let win = UIWindow(frame: UIScreen.main.bounds)
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        win.rootViewController = vc
        win.windowLevel = UIWindow.Level.alert + 1
        win.makeKeyAndVisible()
        vc.present(alert, animated: true, completion: nil)

        #else
        fatalError(errMsg)
        #endif
    }
}
