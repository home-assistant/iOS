import Foundation

/// What the iOS Focus Filter last told us, stored in the app group so the sensor can read it from
/// whichever process happens to be running.
public struct FocusFilterState: Codable, Equatable {
    /// The `FocusName` the user paired with the Focus that activated, or `nil` when the filter ran
    /// without one selected — including the reset run iOS makes when a Focus deactivates.
    public var name: String?
    /// When the filter last ran, so writing the same name twice still notifies observers.
    public var date: Date
    /// When iOS itself answered that a Focus was on while this name stood, or `nil` while it never
    /// has. A Focus whose status the user doesn't share reads back as "not focused" for as long as it
    /// runs, so this is what says the live answer is about this Focus — and so can end it.
    public var liveConfirmedDate: Date?

    public init(name: String?, date: Date, liveConfirmedDate: Date? = nil) {
        self.name = name
        self.date = date
        self.liveConfirmedDate = liveConfirmedDate
    }
}

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

public class FocusFilterStateSync: UserDefaultsValueSync<FocusFilterState> {
    init() {
        super.init(settingsKey: "FocusFilterStateKey")
    }
}

/// The bridge between the iOS Focus Filter — which is the only way to learn _which_ Focus is
/// running, since iOS offers no API for it — and the `focus_name` sensor.
///
/// The filter's App Intent stores the name the user paired with the activating Focus here; the
/// sensor reads it back, and pairs it with `Current.focusStatus` to tell "no Focus is running" from
/// "a Focus is running that we have no name for".
public class FocusFilterWrapper {
    /// How long a reported name is protected from the reset run that follows it.
    ///
    /// Switching Focus runs two filter passes — the starting Focus' with its name, the ending
    /// Focus' with none — around the same moment and in no guaranteed order, and both are timed by
    /// when the app got round to running them rather than by when iOS decided them. Without this,
    /// a reset arriving second erases the name the switch just reported, and the sensor blanks
    /// while a Focus is running.
    static let resetGracePeriod: TimeInterval = 10

    private(set) lazy var state = FocusFilterStateSync()

    /// Unobserved on purpose — see `FocusFilterLiveConfirmation`.
    private(set) lazy var liveConfirmation = UserDefaultsValueSync<FocusFilterLiveConfirmation>(
        settingsKey: "FocusFilterLiveConfirmationKey"
    )

    /// The last Focus Filter run, with the moment it happened so it can be ordered against what
    /// the Focus status pushed us, and whether iOS has confirmed it since.
    public lazy var activeFocusState: () -> FocusFilterState? = { [weak self] in
        guard let self, var state = state.value else { return nil }
        if let confirmation = liveConfirmation.value, confirmation.filterDate == state.date {
            state.liveConfirmedDate = confirmation.date
        }
        return state
    }

    /// The name reported by the last Focus Filter run, if any.
    public lazy var activeFocusName: () -> String? = { [weak self] in
        self?.activeFocusState()?.name
    }

    /// Called by the Focus Filter's App Intent when a Focus activates — and, with `nil`, when one
    /// deactivates.
    public lazy var setActiveFocusName: (String?) -> Void = { [weak self] name in
        guard let self else { return }
        let previous = state.value
        let now = Current.date()
        let isReset = name?.isEmpty != false

        if isReset, let previous, let previousName = previous.name, !previousName.isEmpty,
           now.timeIntervalSince(previous.date) < Self.resetGracePeriod {
            // The Focus that just ended in a switch, reported after the one that started it.
            Current.Log.info("focus filter ignoring reset run right after \(previousName) was reported")
            return
        }

        state.value = FocusFilterState(name: name, date: now)
    }

    /// Records that iOS answered a Focus was on while the named run `filterState` stood. Only the
    /// run still current can be confirmed: a later run is a different Focus.
    public lazy var confirmLive: (FocusFilterState) -> Void = { [weak self] filterState in
        guard let self, let current = state.value, current.date == filterState.date,
              current.name?.isEmpty == false else { return }
        if let existing = liveConfirmation.value, existing.filterDate == current.date { return }
        Current.Log.info("focus filter run for \(current.name ?? "") confirmed by the live focus status")
        liveConfirmation.value = FocusFilterLiveConfirmation(filterDate: current.date, date: Current.date())
    }

    /// Stops reporting a name the user deleted in settings. A filter still paired with it reports
    /// it again the next time it runs, which is when the name exists again as far as the app is
    /// concerned.
    public lazy var forgetFocusName: (String) -> Void = { [weak self] name in
        guard let self, let previous = state.value, previous.name == name else { return }
        state.value = FocusFilterState(name: nil, date: Current.date())
    }
}
