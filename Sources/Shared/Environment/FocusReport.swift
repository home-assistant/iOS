import Foundation

/// What we currently know about Focus: which named Focus the user was last in, and whether any
/// Focus is running right now.
///
/// Two sources each know half of it and neither is complete on its own. The Focus Filter runs when
/// a Focus *starts* and is the only thing that ever tells us its name. `INShareFocusStatusIntent`
/// pushes whether any Focus is running, which is the only thing that tells us one ended — but
/// asking iOS for that status back reports `false` for a Focus whose status the user doesn't
/// share, and during a switch it still describes the Focus that just ended.
///
/// The name is deliberately sticky: iOS wipes the filter's name on deactivation and skips
/// re-running the filter for quick reactivations, so the last reported name is the best answer to
/// "which Focus?" at all times — `isFocused` is what answers "is one on?".
public struct FocusReport: Equatable {
    /// The last name any Focus Filter run reported. `nil` only while no named filter has ever run.
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

        // Falling back to `name` covers state persisted before `lastKnownName` existed.
        let lastKnownName = filterState?.lastKnownName ?? filterState?.name

        let isFocused: Bool?
        if let filterState, filterState.name?.isEmpty == false,
           !hasEnded(filterState: filterState, receivedStatus: receivedStatus) {
            // A filter only runs with a name when a Focus starts — the nil-name run iOS makes on
            // deactivation must not count — and nothing has told us it ended since.
            isFocused = true
        } else {
            isFocused = receivedStatus?.isFocused ?? liveIsFocused()
        }

        return .init(
            name: lastKnownName?.isEmpty == false ? lastKnownName : nil,
            isFocused: isFocused
        )
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
