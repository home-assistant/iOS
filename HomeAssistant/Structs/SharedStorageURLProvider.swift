//
//  SharedStorageURLProvider.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

let kAppGroupID = "group.io.robbie.homeassistant"

/// Concrete implementation of `StorageURLProviding` that stores items in shared storage.
struct SharedStorageURLProvider: StorageURLProviding {
    private let fileManager = FileManager.default

    func dataStoreURL() -> URL? {
        let storeDirectoryURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: kAppGroupID)?
            .appendingPathComponent("dataStore", isDirectory: true)
            .appendingPathComponent("store", isDirectory: false)
        guard let directoryURL = storeDirectoryURL else {
            return nil
        }

        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true,
                                                attributes: nil)
            } catch {
                print("Error while attempting to create data store URL: \(error)")
            }
        }

        return directoryURL.appendingPathComponent("store.realm", isDirectory: false)
    }
}
