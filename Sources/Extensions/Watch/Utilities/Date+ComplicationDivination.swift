import ClockKit
import Foundation

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
        self * 1_000_000
    }
}

extension Int {
    var nanosecondsToMilliseconds: Int {
        Int(round(Double(self) / 1_000_000))
    }
}
