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
        let config = Realm.Configuration(
            fileURL: storeURL,
            schemaVersion: 10,
            migrationBlock: { migration, oldVersion in
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
            },
            deleteRealmIfMigrationNeeded: false
        )

        do {
            return try Realm(configuration: config)
        } catch let error {
            Current.logError?(error as NSError)

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
        Current.logError?(error as NSError)
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

            let win = UIWindow(frame: UIScreen.main.bounds)
            let vc = UIViewController()
            vc.view.backgroundColor = .black
            win.rootViewController = vc
            win.windowLevel = UIWindow.Level.statusBar
            win.makeKeyAndVisible()
            vc.present(alert, animated: true, completion: nil)

            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [win] _ in
                // we don't know when in the lifecycle this will present, we may get another window on top
                // this is basically fatal so it isn't really problematic to never, well, stop doing this
                win.makeKeyAndVisible()
            })
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
