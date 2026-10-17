import Foundation

/// What we currently know about Focus: which named Focus is running, and whether any Focus is
/// running right now.
///
/// Two sources each know half of it and neither is complete on its own. The Focus Filter runs when
/// a Focus *starts* and is the only thing that ever tells us its name. `INShareFocusStatusIntent`
/// pushes whether any Focus is running, which is what tells us one ended — but it says `false`
/// for a Focus whose status the user doesn't share, whether pushed to us or asked for, during a
/// switch it still describes the Focus that just ended, and iOS doesn't reliably push it at all
/// when every Focus ends, so for a Focus the app can ask iOS about, asking is what settles it in
/// either direction.
///
/// The name only ever belongs to the Focus whose filter run reported it. Once that Focus ended, a
/// later "focused" answer is a different Focus, or the same one iOS reactivated without re-running
/// the filter: neither carries a name, and reporting the old one there put a Focus that ended
/// hours earlier on the sensor when a Focus with no filter paired to it started.
public struct FocusReport: Equatable {
    /// The name the Focus Filter reported for the Focus that is running, or `nil` while no named
    /// filter run is current: none ever ran, the last run was a reset, or iOS confirmed every Focus
    /// ended since it ran.
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
        let now = Current.date()

        let liveStatus = liveIsFocused()

        // A filter only runs with a name when a Focus starts — the nil-name run iOS makes on
        // deactivation must not count — and nothing has told us it ended since.
        let name: String?
        if let filterState, let reportedName = filterState.name, !reportedName.isEmpty,
           !hasEnded(filterState: filterState, receivedStatus: receivedStatus, liveStatus: liveStatus, now: now) {
            name = reportedName
        } else {
            name = nil
        }

        let isFocused: Bool?
        if name != nil {
            isFocused = true
        } else if let receivedStatus, let pushSaysFocused = receivedStatus.isFocused, pushSaysFocused,
                  let liveSaysFocused = liveStatus, !liveSaysFocused,
                  now.timeIntervalSince(receivedStatus.date) > switchGracePeriod {
            // Rely on iOS's live Focus state, not the Focus name: whatever iOS answers is the
            // source of truth, so a live "not focused" ends a pushed "running" once that push has
            // had the switch window to settle.
            isFocused = false
        } else if let receivedStatus, receivedStatus.isFocused == false, liveStatus == true,
                  now.timeIntervalSince(receivedStatus.date) > switchGracePeriod {
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

        let report = FocusReport(name: name, isFocused: isFocused)

        if name != nil, let filterState, filterState.liveConfirmedDate == nil, liveStatus == true,
           now.timeIntervalSince(filterState.date) > switchGracePeriod {
            // iOS only answers "focused" for a Focus whose status the user shares, so an answer
            // that lands while this name stands says the live status is about this Focus, and a
            // later "not focused" from it is this Focus ending. Not taken inside the switch
            // window, where the answer can still be about the Focus that just ended.
            Current.focusFilter.confirmLive(filterState)
        }

        // Both Focus sensors stand on this, and every input comes from a different process at a
        // different moment, so the inputs are logged alongside the answer to make a wrong report
        // readable after the fact.
        Current.Log.info {
            let filter = filterState.map {
                "name(\($0.name ?? "<none>")) at(\($0.date)) " +
                    "liveConfirmed(\(String(describing: $0.liveConfirmedDate)))"
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

    /// Whether the Focus whose filter run reported the name has ended, which is what makes that
    /// name stale.
    ///
    /// Only a Focus the Focus status is known to be about can be ended by it. Focus status is
    /// shared per Focus, and the ones the user doesn't share read back as "not focused" for as long
    /// as they run — repeatedly, since iOS re-shares that on its own — so without a confirmation to
    /// pair it with, a status saying nothing is running says nothing about this Focus. The filter's
    /// own reset run still ends those.
    ///
    /// Two things confirm it: iOS pushing "running" after the filter ran, and iOS answering
    /// "focused" while the name stood. The push alone was not enough — it comes to the Intents
    /// extension, which iOS has running before it has finished launching the app to run the
    /// filter, so for a Focus that starts with the app closed it usually lands *before* the filter
    /// run it confirms and never counted. Once confirmed, the Focus has ended when iOS said every
    /// Focus had ended after that run, or answers "not focused" now; both only after the switch
    /// window, inside which they can still describe the Focus that just ended.
    private static func hasEnded(
        filterState: FocusFilterState,
        receivedStatus: FocusStatusState?,
        liveStatus: Bool?,
        now: Date
    ) -> Bool {
        let settledAfterFilter = filterState.date.addingTimeInterval(switchGracePeriod)

        let confirmedByPush = receivedStatus?.lastStartedDate.map { $0 >= filterState.date } ?? false
        guard filterState.liveConfirmedDate != nil || confirmedByPush else { return false }

        if let lastEndedDate = receivedStatus?.lastEndedDate, lastEndedDate > settledAfterFilter {
            return true
        }
        return liveStatus == false && now > settledAfterFilter
    }

    /// Asking iOS directly, which only the app can do, and which only answers for Focuses whose
    /// status the user shares. The fallback for when no status was ever pushed to us, what ends a
    /// pushed "running" whose "ended" push never came, and what starts a Focus the last push —
    /// which can be days old — still calls not running. In an app extension this is the status
    /// iOS pushed, read back together with the filter run it has to be weighed against.
    private static func liveIsFocused() -> Bool? {
        guard Current.focusStatus.isAvailable(),
              Current.focusStatus.authorizationStatus() == .authorized else {
            return nil
        }
        return Current.focusStatus.status().isFocused
    }
}
