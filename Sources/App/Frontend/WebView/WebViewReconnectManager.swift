import Foundation
import Shared
import UIKit

@MainActor
final class WebViewReconnectManager: ObservableObject {
    struct Configuration {
        let delays: [TimeInterval]

        static let `default` = Configuration(delays: [10, 30, 60, 600])

        func delay(forAttempt attempt: Int) -> TimeInterval {
            delays[min(attempt, delays.count - 1)]
        }
    }

    typealias TimerScheduler = @MainActor (TimeInterval, @escaping @MainActor () -> Void) -> () -> Void

    private let configuration: Configuration
    private let scheduleTimer: TimerScheduler
    private let isAppActive: @MainActor () -> Bool

    private var cancelTimer: (() -> Void)?
    private var reconnectAction: (() -> Void)?
    private var attempt = 0
    private var isWatching = false

    init(
        configuration: Configuration = .default,
        isAppActive: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active },
        scheduleTimer: @escaping TimerScheduler = WebViewReconnectManager.defaultScheduleTimer
    ) {
        self.configuration = configuration
        self.isAppActive = isAppActive
        self.scheduleTimer = scheduleTimer
    }

    deinit {
        cancelTimer?()
    }

    func start(reconnectAction: @escaping () -> Void) {
        self.reconnectAction = reconnectAction
        guard !isWatching else { return }
        isWatching = true
        attempt = 0
        scheduleNextAttempt()
    }

    func stop() {
        cancelTimer?()
        cancelTimer = nil
        reconnectAction = nil
        attempt = 0
        isWatching = false
    }

    private func scheduleNextAttempt() {
        cancelTimer?()
        guard isWatching else { return }

        let delay = configuration.delay(forAttempt: attempt)
        cancelTimer = scheduleTimer(delay) { [weak self] in
            self?.performScheduledAttempt()
        }
    }

    private func performScheduledAttempt() {
        guard isWatching else { return }

        guard isAppActive() else {
            scheduleNextAttempt()
            return
        }

        let attemptNumber = attempt + 1
        let delay = configuration.delay(forAttempt: attempt)
        attempt += 1

        Current.Log
            .info(
                "Hard resetting disconnected web frontend after empty state backoff attempt \(attemptNumber), delay \(delay)s"
            )
        reconnectAction?()
        scheduleNextAttempt()
    }

    private static func defaultScheduleTimer(
        delay: TimeInterval,
        action: @escaping @MainActor () -> Void
    ) -> () -> Void {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                action()
            }
        }
        return {
            timer.invalidate()
        }
    }
}
