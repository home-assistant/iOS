import Foundation

/// What we currently know about Focus: which named Focus is running, and whether any is at all.
///
/// Two sources each know half of it and neither is complete on its own. The Focus Filter runs when
/// a Focus *starts* and is the only thing that ever tells us its name. `INShareFocusStatusIntent`
/// pushes whether any Focus is running, which is the only thing that tells us one ended — but
/// asking iOS for that status back reports `false` for a Focus whose status the user doesn't
/// share, and during a switch it still describes the Focus that just ended.
///
/// So neither source is allowed to overrule the other outright: they are ordered by when they
/// happened, and a filter run that nothing newer has ended stands as proof that its Focus is on.
public struct FocusReport: Equatable {
    /// The name the Focus Filter reported for the running Focus. `nil` when no Focus is running, or
    /// when the running one has no filter pairing it with a name.
    public let name: String?
    /// Whether any Focus is running, or `nil` when nothing we have access to can say.
    public let isFocused: Bool?

    public init(name: String?, isFocused: Bool?) {
        self.name = name
        self.isFocused = isFocused
    }

    /// iOS starts the new Focus — running its filter — before it reports the previous one ending,
    /// so a status saying nothing is running this soon after a filter run is the tail end of a
    /// switch rather than the Focus we were just told about ending.
    static let switchGracePeriod: TimeInterval = 5

    public static func current() -> FocusReport {
        let filterState = Current.focusFilter.activeFocusState()
        let receivedStatus = Current.focusStatus.lastReceived()

        if let filterState, !hasEnded(filterState: filterState, receivedStatus: receivedStatus) {
            let reportedName = filterState.name
            return .init(
                name: reportedName?.isEmpty == false ? reportedName : nil,
                // A filter only runs when a Focus starts, and nothing has told us it ended since.
                isFocused: true
            )
        }

        return .init(name: nil, isFocused: receivedStatus?.isFocused ?? liveIsFocused())
    }

    /// Whether iOS said every Focus had ended after the filter ran, which is what makes the name it
    /// reported stale. Checked against the last such moment rather than the current status, so a
    /// Focus that started without a filter can't inherit the name of the one before it.
    private static func hasEnded(filterState: FocusFilterState, receivedStatus: FocusStatusState?) -> Bool {
        guard let lastEndedDate = receivedStatus?.lastEndedDate else { return false }
        return lastEndedDate > filterState.date.addingTimeInterval(switchGracePeriod)
    }

    /// Asking iOS directly, which only the app can do, and which only answers for Focuses whose
    /// status the user shares. The fallback for when no status was ever pushed to us.
    private static func liveIsFocused() -> Bool? {
        guard Current.focusStatus.isAvailable(),
              Current.focusStatus.authorizationStatus() == .authorized else {
            return nil
        }
        return Current.focusStatus.status().isFocused
    }
}
