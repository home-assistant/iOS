#if os(iOS)
import Foundation
import PromiseKit
import UIKit

public class PeriodicUpdateManager {
    public let applicationStateGetter: () -> UIApplication.State
    public init(applicationStateGetter: @escaping () -> UIApplication.State) {
        self.applicationStateGetter = applicationStateGetter
    }

    private var periodicUpdateTimer: Timer? {
        willSet {
            if periodicUpdateTimer != newValue {
                periodicUpdateTimer?.invalidate()
            }
        }
    }

    public static var supportsBackgroundPeriodicUpdates: Bool {
        Current.isCatalyst || Current.isAppExtension
    }

    public func invalidatePeriodicUpdateTimer(forBackground: Bool = false) {
        if !Self.supportsBackgroundPeriodicUpdates || !forBackground {
            periodicUpdateTimer = nil
        }
    }

    /// Whether the next periodic update is on the run loop. For tests, which cannot see the timer.
    var isPeriodicUpdateScheduled: Bool {
        periodicUpdateTimer?.isValid == true
    }

    private func schedulePeriodicUpdateTimer() {
        guard periodicUpdateTimer == nil || periodicUpdateTimer?.isValid == false else {
            return
        }

        guard Self.supportsBackgroundPeriodicUpdates || applicationStateGetter() != .background else {
            // it's fine to schedule, but we don't wanna fire two when we come back to foreground later
            Current.Log.info("not scheduling periodic update; backgrounded")
            return
        }

        guard let interval = Current.settingsStore.periodicUpdateInterval else {
            Current.Log.info("not scheduling periodic update; disabled")
            return
        }

        periodicUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.connectAPI(reason: .periodic)
        }
    }

    /// Warm connects within this window of any connect start are skipped: macOS posts
    /// `NSApplicationDidBecomeActiveNotification` twice per activation, about 300 ms apart, and the
    /// second would repeat the first connect in full. Two seconds covers that gap with room to
    /// spare and is shorter than any deliberate switch back to the app.
    static let warmConnectDedupeWindow: TimeInterval = 2

    /// Only touched from the main thread: every caller is a notification observer, the timer, or
    /// the launch task on the main actor.
    private var lastConnectStartDate: Date?

    public func connectAPI(reason: HomeAssistantAPI.ConnectReason) {
        let now = Current.date()
        if reason == .warm, let lastConnectStartDate {
            // A wall-clock reading: a clock set back makes this negative, which is outside the
            // window rather than inside it, so a stale timestamp never skips more than one connect.
            let elapsed = now.timeIntervalSince(lastConnectStartDate)
            if (0 ..< Self.warmConnectDedupeWindow).contains(elapsed) {
                Current.Log.info("skipping warm connect; one started \(String(format: "%.1f", elapsed))s ago")
                // The skipped connect would have rescheduled the periodic update in its `finally`;
                // on iOS backgrounding in between has invalidated it, so put it back here.
                schedulePeriodicUpdateTimer()
                return
            }
        }
        lastConnectStartDate = now

        Current.backgroundTask(withName: BackgroundTask.connectApi.rawValue) { _ in
            when(resolved: Current.apis.map { api in
                api.Connect(reason: reason)
            }).asVoid()
        }.done {
            Current.Log.info("Connect finished for reason \(reason)")
        }.catch { error in
            // if the error is e.g. token is invalid, we'll force onboarding through status-code-watching mechanisms
            Current.Log.error("Couldn't connect for reason \(reason): \(error)")
        }.finally {
            self.schedulePeriodicUpdateTimer()
        }
    }
}
#endif
