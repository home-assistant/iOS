//
//  DataEntryFlow.swift
//  Shared
//
//  Created by Stephan Vanterpool on 7/22/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

public struct DataEntryFlowForm: ImmutableMappable {
    struct Field: ImmutableMappable {
        enum Kind: String {
            case string
        }

        let name: String
        let kind: Kind

        init(map: Map) throws {
            self.name = try map.value("name")
            self.kind = try map.value("type")
        }
    }

    let schema: [Field]
    let flowId: String
    let errors: [String: String]

    public init(map: Map) throws {
        self.schema = try map.value("data_schema")
        self.flowId = try map.value("flow_id")
        self.errors =  try map.value("errors")        
    }
}
