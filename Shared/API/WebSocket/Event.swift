//
//  Event.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 4/10/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import Foundation

public class Event {
    public let Data: [String: Any]
    public let EventType: String
    public let TimeFired: Date
    public let Origin: String

    init(_ dictionary: [String: Any]) {
        self.Data = dictionary["data"] as? [String: Any] ?? [:]
        // swiftlint:disable force_cast
        self.EventType = dictionary["event_type"] as! String
        self.TimeFired = dictionary["time_fired"] as! Date
        self.Origin = dictionary["origin"] as! String
    }
}
