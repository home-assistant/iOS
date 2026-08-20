import Foundation

/// What the iOS Focus Filter last told us, stored in the app group so the sensor can read it from
/// whichever process happens to be running.
public struct FocusFilterState: Codable, Equatable {
    /// The `FocusName` the user paired with the Focus that activated, or `nil` when the filter ran
    /// without one selected — including the reset run iOS makes when a Focus deactivates.
    public var name: String?
    /// When the filter last ran, so writing the same name twice still notifies observers.
    public var date: Date
    /// The last non-empty name any filter run ever reported, surviving the nil-name runs that
    /// clear `name`. iOS doesn't re-run the filter when the same Focus quickly reactivates, so
    /// this is the only durable record of which Focus the user was last in.
    public var lastKnownName: String?

    public init(name: String?, date: Date, lastKnownName: String? = nil) {
        self.name = name
        self.date = date
        self.lastKnownName = lastKnownName
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
    private(set) lazy var state = FocusFilterStateSync()

    /// The last Focus Filter run, with the moment it happened so it can be ordered against what
    /// the Focus status pushed us.
    public lazy var activeFocusState: () -> FocusFilterState? = { [weak self] in
        self?.state.value
    }

    /// The name reported by the last Focus Filter run, if any.
    public lazy var activeFocusName: () -> String? = { [weak self] in
        self?.activeFocusState()?.name
    }

    /// Called by the Focus Filter's App Intent when a Focus activates — and, with `nil`, when one
    /// deactivates. A nil run must not erase the last name we knew: iOS skips re-running the
    /// filter for quick reactivations, so the previous name is carried forward instead.
    public lazy var setActiveFocusName: (String?) -> Void = { [weak self] name in
        guard let self else { return }
        let previous = state.value
        let lastKnownName: String?
        if let name, !name.isEmpty {
            lastKnownName = name
        } else {
            lastKnownName = previous?.lastKnownName ?? previous?.name
        }
        state.value = FocusFilterState(name: name, date: Current.date(), lastKnownName: lastKnownName)
    }
}
