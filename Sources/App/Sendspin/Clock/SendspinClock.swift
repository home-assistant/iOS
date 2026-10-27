import Darwin
import Foundation

/// This device's side of clock synchronization: microseconds on the host clock, which is the same
/// clock the audio hardware stamps its render cycles with, so a time the filter maps a server
/// timestamp to can be compared directly with when a buffer will be heard.
enum SendspinClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func nowMicroseconds() -> Int64 {
        microseconds(fromHostTime: mach_absolute_time())
    }

    static func microseconds(fromHostTime hostTime: UInt64) -> Int64 {
        let nanoseconds = Double(hostTime) * Double(timebase.numer) / Double(timebase.denom)
        return Int64(nanoseconds / 1000)
    }
}
