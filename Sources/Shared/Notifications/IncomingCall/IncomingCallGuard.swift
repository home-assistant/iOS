import Foundation

/// Decides whether an incoming call may ring as a phone call, and remembers the calls that did.
///
/// An automation that loops, a push re-sent after a lost confirm (the local-push channel re-sends unconfirmed
/// pushes through APNs) or a replayed payload must never make the phone ring again and again:
///
/// - **Same call twice**: a tag that already rang during `duplicateWindow` does not ring again.
/// - **Too many calls**: at most `maximumCalls` calls ring within `rateWindow`, all servers together.
///
/// A call that is turned away here is not lost: it is shown as an ordinary time-sensitive notification.
///
/// The record lives in the App Group defaults, so the PushProvider extension and the app share it.
public struct IncomingCallGuard {
    public enum Decision: Equatable {
        case ring
        case duplicate
        case rateLimited
    }

    public static let duplicateWindow: TimeInterval = 10 * 60
    public static let rateWindow: TimeInterval = 60
    public static let maximumCalls = 3

    private static let storeKey = "incomingCallGuardHistory"
    private static let lock = NSLock()

    private let defaults: UserDefaults
    private let now: () -> Date

    /// Keeps its history in the App Group defaults, so the app and the PushProvider extension share it.
    public init() {
        self.init(defaults: Current.settingsStore.prefs, now: { Current.date() })
    }

    init(defaults: UserDefaults, now: @escaping () -> Date) {
        self.defaults = defaults
        self.now = now
    }

    /// Checks a call and, when it may ring, records it in the same step so two pushes for the same call cannot
    /// both pass.
    public func admit(tag: String) -> Decision {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let date = now()
        var history = load().filter { date.timeIntervalSince($0.value) < Self.duplicateWindow }

        if history[tag] != nil {
            store(history)
            return .duplicate
        }

        let recent = history.values.filter { date.timeIntervalSince($0) < Self.rateWindow }
        if recent.count >= Self.maximumCalls {
            store(history)
            return .rateLimited
        }

        history[tag] = date
        store(history)
        return .ring
    }

    /// Forgets everything, for example when the feature is turned off.
    public func reset() {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        defaults.removeObject(forKey: Self.storeKey)
    }

    private func load() -> [String: Date] {
        guard let stored = defaults.dictionary(forKey: Self.storeKey) else { return [:] }
        return stored.compactMapValues { $0 as? Date }
    }

    private func store(_ history: [String: Date]) {
        if history.isEmpty {
            defaults.removeObject(forKey: Self.storeKey)
        } else {
            defaults.set(history, forKey: Self.storeKey)
        }
    }
}
