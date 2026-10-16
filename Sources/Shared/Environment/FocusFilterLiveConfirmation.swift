import Foundation

/// The live confirmation of one filter run, keyed by that run's date.
///
/// Kept apart from `FocusFilterState`: the sensors observe that key and treat every write to it as
/// a Focus change, so recording an observation there would start a whole sensor run of its own.
public struct FocusFilterLiveConfirmation: Codable, Equatable {
    /// The `FocusFilterState.date` of the run this confirms.
    public var filterDate: Date
    /// When iOS answered that a Focus was on.
    public var date: Date

    public init(filterDate: Date, date: Date) {
        self.filterDate = filterDate
        self.date = date
    }
}
