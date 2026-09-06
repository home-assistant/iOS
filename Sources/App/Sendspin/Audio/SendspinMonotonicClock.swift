import Darwin
import Foundation

/// The device's monotonic clock, in the microseconds the protocol measures everything in.
///
/// Audio render callbacks report a mach host time, and clock synchronisation works in local
/// microseconds, so both need to come from the same timebase.
enum SendspinMonotonicClock {
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    static func nowMicroseconds() -> Int64 {
        microseconds(fromHostTime: mach_absolute_time())
    }

    static func microseconds(fromHostTime hostTime: UInt64) -> Int64 {
        let nanoseconds = hostTime * UInt64(timebase.numer) / UInt64(timebase.denom)
        return Int64(nanoseconds / 1_000)
    }
}
