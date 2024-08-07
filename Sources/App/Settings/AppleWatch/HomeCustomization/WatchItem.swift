//
//  WatchItem.swift
//  App
//
//  Created by Bruno Pantaleão on 07/08/2024.
//  Copyright © 2024 Home Assistant. All rights reserved.
//

import Foundation
import Shared
import GRDB

struct WatchItem: Codable {
    let id: String
    let type: WatchItemType

    enum WatchItemType: Codable {
        case action(LegacyAction)
        case script(HAScript)
    }

    struct LegacyAction: Codable  {
        let id: String
        let name: String
        let iconName: String
        let backgroundColor: String
        let textColor: String
        let iconColor: String
    }
}

struct WatchConfig: Codable, FetchableRecord, PersistableRecord {
    var id = UUID().uuidString
    var showAssist: Bool = true
    var items: [WatchItem] = []
}
