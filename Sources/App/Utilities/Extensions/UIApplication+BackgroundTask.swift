import Foundation
import PromiseKit
import Shared
import UIKit

class ApplicationBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    private let beginTask: (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier
    private let endTask: (UIBackgroundTaskIdentifier) -> Void
    private let remainingTime: () -> TimeInterval

    init(
        beginTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier = {
            UIApplication.shared.beginBackgroundTask(withName: $0, expirationHandler: $1)
        },
        endTask: @escaping (UIBackgroundTaskIdentifier) -> Void = { UIApplication.shared.endBackgroundTask($0) },
        remainingTime: @escaping () -> TimeInterval = { UIApplication.shared.backgroundTimeRemaining }
    ) {
        self.beginTask = beginTask
        self.endTask = endTask
        self.remainingTime = remainingTime
    }

    public func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        HomeAssistantBackgroundTask.execute(
            withName: name,
            beginBackgroundTask: { [self] name, expirationHandler in
                // UIKit permits begin/endBackgroundTask from any thread. Only the optional
                // remaining-time hint requires main; never wait on main from a caller's queue.
                let identifier = beginTask(name, expirationHandler)
                let remaining: TimeInterval?
                if Thread.isMainThread {
                    remaining = remainingTime()
                } else {
                    Current.Log.debug("Background task \(name): skipping remaining-time hint off main")
                    remaining = nil
                }
                return (identifier == .invalid ? nil : identifier, remaining.flatMap { $0 < 100 ? $0 : nil })
            },
            endBackgroundTask: endTask,
            wrapping: wrapping
        )
    }
}
