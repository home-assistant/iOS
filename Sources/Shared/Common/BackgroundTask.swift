import Foundation
import PromiseKit
#if os(iOS)
import UIKit
#endif

public enum BackgroundTaskError: Error {
    case outOfTime
}

public protocol HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue>
}

// enum for namespacing
public enum HomeAssistantBackgroundTask {
    public static func execute<ReturnType, IdentifierType>(
        withName name: String,
        beginBackgroundTask: (String, @escaping () -> Void) -> (IdentifierType?, TimeInterval?),
        endBackgroundTask: @escaping (IdentifierType) -> Void,
        wrapping: (TimeInterval?) -> Promise<ReturnType>
    ) -> Promise<ReturnType> {
        func describe(_ identifier: IdentifierType?) -> String {
            if let identifier = identifier {
                #if os(iOS)
                if let identifier = identifier as? UIBackgroundTaskIdentifier {
                    return String(describing: identifier.rawValue)
                } else {
                    return String(describing: identifier)
                }
                #else
                return String(describing: identifier)
                #endif
            } else {
                return "(none)"
            }
        }

        var identifier: IdentifierType?
        var remaining: TimeInterval?

        // we can't guarantee to Swift that this will be assigned, but it will
        var finished: () -> Void = {}

        let promise = Promise<Void> { seal in
            (identifier, remaining) = beginBackgroundTask(name) {
                Current.Log.error("out of time for background task \(name) \(describe(identifier))")
                seal.reject(BackgroundTaskError.outOfTime)
            }

            finished = {
                seal.fulfill(())
            }
        }.tap { result in
            guard let endableIdentifier = identifier else { return }

            let endBackgroundTask = {
                endBackgroundTask(endableIdentifier)
                identifier = nil
            }

            if case .rejected(BackgroundTaskError.outOfTime) = result {
                // immediately execute, or we'll be terminated by the system!
                endBackgroundTask()
            } else {
                // give it a run loop, since we want the promise's e.g. completion handlers to be invoked first
                DispatchQueue.main.async { endBackgroundTask() }
            }
        }

        // make sure we only invoke the promise-returning block once, in case it has side-effects
        let underlying = wrapping(remaining)

        let underlyingWithFinished = underlying
            .ensure { finished() }

        return firstly {
            when(fulfilled: [promise.asVoid(), underlyingWithFinished.asVoid()])
        }.then {
            underlying
        }
    }
}
