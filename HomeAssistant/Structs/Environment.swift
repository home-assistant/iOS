//
//  Environment.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation

/// The current "operating envrionment" the app.
struct Environment {
    /// Provides URLs usable for storing data. 
    var storageURLProviding: StorageURLProviding = SharedStorageURLProvider()    
}
