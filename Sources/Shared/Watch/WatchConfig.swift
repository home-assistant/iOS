//
//  WatchConfig.swift
//  App
//
//  Created by Bruno Pantaleão on 14/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import GRDB

public struct WatchConfig: Codable, FetchableRecord, PersistableRecord {
    public var id = UUID().uuidString
    public var showAssist: Bool = true
    public var items: [MagicItem] = []

    public init(id: String = UUID().uuidString, showAssist: Bool = true, items: [MagicItem] = []) {
        self.id = id
        self.showAssist = showAssist
        self.items = items
    }
}
