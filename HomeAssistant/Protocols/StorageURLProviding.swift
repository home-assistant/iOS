//
//  StorageURLProviding.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

/// Provides locations for data to be stored in the local filesystem.
protocol StorageURLProviding {
    /// The URL for the data store.
    func dataStoreURL() -> URL?
}
