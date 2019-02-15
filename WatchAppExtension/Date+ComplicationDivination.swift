//
//  Date+ComplicationDivination.swift
//  WatchAppExtension
//
//  Created by Robert Trencheny on 2/15/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

// From https://crunchybagel.com/detecting-which-complication-was-tapped/

import Foundation
import ClockKit

extension Date {
    func encodedForComplication(family: CLKComplicationFamily) -> Date? {
        let calendar = Calendar.current

        var dc = calendar.dateComponents(in: calendar.timeZone, from: self)
        dc.nanosecond = family.rawValue.millisecondsToNanoseconds

        return calendar.date(from: dc)
    }

    var complicationFamilyFromEncodedDate: CLKComplicationFamily? {
        let calendar = Calendar.current
        let ns = calendar.component(.nanosecond, from: self)

        return CLKComplicationFamily(rawValue: ns.nanosecondsToMilliseconds)
    }
}

extension Int {
    var millisecondsToNanoseconds: Int {
        return self * 1000000
    }
}

extension Int {
    var nanosecondsToMilliseconds: Int {
        return Int(round(Double(self) / 1000000))
    }
}
