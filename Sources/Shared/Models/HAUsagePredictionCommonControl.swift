//
//  HAUsagePredictionCommonControl.swift
//  HomeAssistant
//
//  Created by Bruno Pantaleão on 14/1/26.
//  Copyright © 2026 Home Assistant. All rights reserved.
//

import Foundation
import HAKit

public struct HAUsagePredictionCommonControl: Codable, HADataDecodable {
    /// [EntityId]
    public let entities: [String]

    public init(data: HAData) throws {
        self.entities = try data.decode("entities")
    }
}
