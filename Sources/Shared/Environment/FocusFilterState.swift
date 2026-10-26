import Foundation

/// One thing the Focus Filter said about which Focus is on, with when it said it, so what the
/// filter's runs and the app's readings of it said can be ordered and the newest one used.
///
/// Stored in the app group under a key that predates this type. JSON decoding ignores the field
/// an older build stored alongside these two, so the last run an older build recorded still reads.
public struct FocusFilterState: Codable, Equatable {
    /// The `FocusName` the user paired with the Focus that is on, or `nil` when no Focus with a
    /// name picked in the filter is on, which includes the run iOS makes when a Focus ends.
    public var name: String?
    /// When the filter said it.
    public var date: Date

    public init(name: String?, date: Date) {
        self.name = name
        self.date = date
    }
}
