import Foundation
import Shared

/// Reports exactly one outcome for a CarPlay action, within a bounded time.
///
/// Actions reach the server over the WebSocket, and HAKit queues a request while the connection is
/// down without ever expiring it. A tap in a dead zone therefore never calls back at all: the row
/// stays on "Executing…" and the driver is left guessing whether it registered. Arming a deadline
/// alongside the request means the first of the two to land wins, and the caller always hears back
/// exactly once — so the row always settles and a failure can be shown.
final class CarPlayOperationDeadline {
    /// How long an action waits before it is reported as failed. Long enough to ride out a slow
    /// cellular round trip, short enough that the driver isn't left watching a row that will never
    /// resolve. Matches the App Intents request timeout.
    static let interval: TimeInterval = 10

    private enum Outcome {
        case succeeded
        /// Carries the reported error, or `nil` when the action simply never answered.
        case failed(Error?)
    }

    private let server: Server
    private var timeoutWorkItem: DispatchWorkItem?
    private var report: ((CarPlayOperationError?) -> Void)?

    /// - Parameters:
    ///   - server: the server the action runs against, whose connection state decides what a
    ///     failure is reported as.
    ///   - timeout: seconds to wait for an outcome before treating the action as failed.
    ///   - report: called once, on the main queue, with `nil` on success or what to tell the driver.
    init(
        server: Server,
        timeout: TimeInterval = CarPlayOperationDeadline.interval,
        report: @escaping (CarPlayOperationError?) -> Void
    ) {
        self.server = server
        self.report = report
        // Held strongly by the work item, so a caller that fires and forgets still gets its
        // outcome; reporting releases the item and breaks the cycle.
        let workItem = DispatchWorkItem { [self] in
            deliver(.failed(nil))
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    /// The action completed. Later calls — including a reply that arrives after the deadline
    /// already fired — are ignored.
    func succeed() {
        finish(.succeeded)
    }

    /// The action failed, with the error the transport or server reported if there was one.
    func fail(_ underlying: Error? = nil) {
        finish(.failed(underlying))
    }

    private func finish(_ outcome: Outcome) {
        // Replies can land on HAKit's callback queue while the deadline fires on main. Funnelling
        // both through main decides "first one wins" in one place and hands the report to CarPlay's
        // UI on the queue it needs.
        if Thread.isMainThread {
            deliver(outcome)
        } else {
            DispatchQueue.main.async { [self] in
                deliver(outcome)
            }
        }
    }

    private func deliver(_ outcome: Outcome) {
        guard let report else { return }
        release()

        switch outcome {
        case .succeeded:
            report(nil)
        case let .failed(underlying):
            report(CarPlayOperationError.resolve(underlying: underlying, server: server))
        }
    }

    private func release() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        report = nil
    }
}
