import Foundation
import Network
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
    typealias RecoverySignalObserver = @MainActor (@escaping @MainActor () -> Void) -> () -> Void

    private let configuration: Configuration
    private let scheduleTimer: TimerScheduler
    private let isAppActive: @MainActor () -> Bool
    private let observeRecoverySignals: RecoverySignalObserver

    private var cancelTimer: (() -> Void)?
    private var cancelRecoverySignals: (() -> Void)?
    private var reconnectAction: (() -> Void)?
    private var attempt = 0
    private var isWatching = false

    init(
        configuration: Configuration = .default,
        isAppActive: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active },
        scheduleTimer: @escaping TimerScheduler = WebViewReconnectManager.defaultScheduleTimer,
        observeRecoverySignals: @escaping RecoverySignalObserver = WebViewReconnectManager.defaultObserveRecoverySignals
    ) {
        self.configuration = configuration
        self.isAppActive = isAppActive
        self.scheduleTimer = scheduleTimer
        self.observeRecoverySignals = observeRecoverySignals
    }

    deinit {
        cancelTimer?()
        cancelRecoverySignals?()
    }

    func start(reconnectAction: @escaping () -> Void) {
        self.reconnectAction = reconnectAction
        guard !isWatching else { return }
        isWatching = true
        attempt = 0
        cancelRecoverySignals = observeRecoverySignals { [weak self] in
            self?.performRecoverySignalAttempt()
        }
        scheduleNextAttempt()
    }

    func stop() {
        cancelTimer?()
        cancelTimer = nil
        cancelRecoverySignals?()
        cancelRecoverySignals = nil
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

    private func performRecoverySignalAttempt() {
        guard isWatching, isAppActive() else { return }

        Current.Log.info("Retrying disconnected web frontend immediately after foreground/network recovery")
        attempt = 0
        reconnectAction?()
        scheduleNextAttempt()
    }

    private static func defaultObserveRecoverySignals(
        action: @escaping @MainActor () -> Void
    ) -> () -> Void {
        let center = NotificationCenter.default
        let foregroundObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                action()
            }
        }

        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "io.robbie.HomeAssistant.webview-reconnect-network")
        monitor.pathUpdateHandler = { path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in
                action()
            }
        }
        monitor.start(queue: queue)

        return {
            center.removeObserver(foregroundObserver)
            monitor.cancel()
        }
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
