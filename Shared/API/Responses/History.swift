//
//  History.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/5/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import Foundation
import ObjectMapper

class HistoryResponse: Mappable {

    //    var EntityId: String?
    //    var Domain: String?
    var Entities: [HistoryGroup]?

    required init?(map: Map) {
        print("MAP", map)
    }

    func mapping(map: Map) {
        print("map", map)
        Entities <- map
        //        EntityId <- map["message"]
        //        Domain    <- (map["message"] == "API running.")
        //        Events <- map[
    }
}

class HistoryGroup: Mappable {

    var Events: [Entity]?

    required init?(map: Map) {
        print("MAP", map)
    }

    func mapping(map: Map) {
        print("map", map)
        Events <- map
        //        EntityId <- map["message"]
        //        Domain    <- (map["message"] == "API running.")
        //        Events <- map[
    }
}
