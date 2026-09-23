import Foundation

/// What we currently know about Focus: which named Focus the user was last in, and whether any
/// Focus is running right now.
///
/// Two sources each know half of it and neither is complete on its own. The Focus Filter runs when
/// a Focus *starts* and is the only thing that ever tells us its name. `INShareFocusStatusIntent`
/// pushes whether any Focus is running, which is what tells us one ended — but it says `false`
/// for a Focus whose status the user doesn't share, whether pushed to us or asked for, during a
/// switch it still describes the Focus that just ended, and iOS doesn't reliably push it at all
/// when every Focus ends, so for a Focus the app can ask iOS about, asking is what settles it in
/// either direction.
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

    /// How long after a filter run a status saying nothing is running is read as the tail end of a
    /// switch rather than as that Focus ending.
    ///
    /// iOS starts the new Focus — running its filter — before it reports the previous one ending,
    /// and the two land in different processes: the status in the Intents extension, the filter in
    /// the app, which iOS often has to launch in the background first. The window has to cover
    /// that launch, or a Focus started while the app isn't running blanks the sensor it just
    /// reported to. Nothing hangs on the window being tight: the filter's own reset run is what
    /// normally ends a Focus, and it clears the name whenever it lands.
    static let switchGracePeriod: TimeInterval = 30

    public static func current() -> FocusReport {
        let filterState = Current.focusFilter.activeFocusState()
        let receivedStatus = Current.focusStatus.lastReceived()

        // Falling back to `name` covers state persisted before `lastKnownName` existed.
        let lastKnownName = filterState?.lastKnownName ?? filterState?.name

        let liveStatus = liveIsFocused()

        let isFocused: Bool?
        if let filterState, let name = filterState.name, !name.isEmpty,
           !hasEnded(filterState: filterState, receivedStatus: receivedStatus) {
            // A filter only runs with a name when a Focus starts — the nil-name run iOS makes on
            // deactivation must not count — and nothing has told us it ended since.
            isFocused = true
        } else if let receivedStatus, let pushSaysFocused = receivedStatus.isFocused, pushSaysFocused,
                  let liveSaysFocused = liveStatus, !liveSaysFocused,
                  Current.date().timeIntervalSince(receivedStatus.date) > switchGracePeriod {
            // Rely on iOS's live Focus state, not the Focus name: whatever iOS answers is the
            // source of truth, so a live "not focused" ends a pushed "running" once that push has
            // had the switch window to settle.
            isFocused = false
        } else if let receivedStatus, receivedStatus.isFocused == false, liveStatus == true,
                  Current.date().timeIntervalSince(receivedStatus.date) > switchGracePeriod {
            // The same rule the other way round, and the reason a Focus could read as off while
            // iOS said one was running. A pushed "nothing is running" is the weakest thing we
            // hold: it is also what iOS says about a Focus the user doesn't share, iOS only
            // pushes it when it feels like it, and nothing ages it out — one arriving days ago
            // otherwise outranked every later answer. Asking iOS is not ambiguous in this
            // direction, because it never answers "focused" while no Focus is on, so once that
            // push has had the switch window to settle the live answer replaces it.
            isFocused = true
        } else {
            isFocused = receivedStatus?.isFocused ?? liveStatus
        }

        let report = FocusReport(
            name: lastKnownName?.isEmpty == false ? lastKnownName : nil,
            isFocused: isFocused
        )

        // Both Focus sensors stand on this, and every input comes from a different process at a
        // different moment, so the inputs are logged alongside the answer to make a wrong report
        // readable after the fact.
        Current.Log.info {
            let filter = filterState.map {
                "name(\($0.name ?? "<none>")) lastKnown(\($0.lastKnownName ?? "<none>")) at(\($0.date))"
            } ?? "<never ran>"
            let status = receivedStatus.map {
                "isFocused(\(String(describing: $0.isFocused))) at(\($0.date)) " +
                    "lastEnded(\(String(describing: $0.lastEndedDate))) " +
                    "lastStarted(\(String(describing: $0.lastStartedDate)))"
            } ?? "<never received>"
            return "focus report: \(report) from filter[\(filter)] status[\(status)] " +
                "live(\(String(describing: liveStatus)))"
        }

        return report
    }

    /// Whether iOS said every Focus had ended after the filter ran, which is what makes the name it
    /// reported stale. Checked against the last such moment rather than the current status, so a
    /// Focus that started without a filter can't inherit the name of the one before it.
    ///
    /// It only counts for a Focus iOS confirmed running after that filter run. Focus status is
    /// shared per Focus, and the ones the user doesn't share read back as "not focused" for as
    /// long as they run — repeatedly, since iOS re-shares that on its own — so without a
    /// confirmation to pair it with, a status saying nothing is running says nothing about this
    /// Focus. The filter's own reset run still ends those.
    private static func hasEnded(filterState: FocusFilterState, receivedStatus: FocusStatusState?) -> Bool {
        guard let receivedStatus,
              let lastEndedDate = receivedStatus.lastEndedDate,
              lastEndedDate > filterState.date.addingTimeInterval(switchGracePeriod) else { return false }
        guard let lastStartedDate = receivedStatus.lastStartedDate else { return false }
        return lastStartedDate >= filterState.date
    }

    /// Asking iOS directly, which only the app can do, and which only answers for Focuses whose
    /// status the user shares. The fallback for when no status was ever pushed to us, what ends a
    /// pushed "running" whose "ended" push never came, and what starts a Focus the last push —
    /// which can be days old — still calls not running.
    private static func liveIsFocused() -> Bool? {
        guard Current.focusStatus.isAvailable(),
              Current.focusStatus.authorizationStatus() == .authorized else {
            return nil
        }
        return Current.focusStatus.status().isFocused
    }
}
