import Foundation
import PromiseKit
#if os(iOS)
import UIKit
#endif

public enum BackgroundTask: String {
    case backgroundFetch = "background-fetch"
    case lifecycleManagerDidFinishLaunching = "lifecycle-manager-didFinishLaunching"
    case lifecycleManagerDidEnterBackground = "lifecycle-manager-didEnterBackground"
    case lifecycleManagerDidBecomeActive = "lifecycle-manager-didBecomeActive"
    case shortcutItem = "shortcut-item"
    case handlePushAction = "handle-push-action"
    case notificationManagerDidReceiveRegistrationToken = "notificationManager-didReceiveRegistrationToken"
    case zoneManagerPerformEvent = "zone-manager-perform-event"
    case watchPushAction = "watch-push-action"
    case webhookSendEphemeral = "webhook-send-ephemeral"
    case webhookSend = "webhook-send"
    case webhookInvoke = "webhook-invoke"
    case manualLocationUpdate = "manual-location-update"
    case signaledUpdateSensors = "signaled-update-sensors"
    case connectApi = "connect-api"
    case realmWrite = "realm-write"
    case pushLocationRequest = "push-location-request"
    case remindersSync = "reminders-sync"
    case legacyModelCleanup = "legacy-model-cleanup"
    case focusFilterSensorUpdate = "focus-filter-sensor-update"
    case watchMirrorPush = "watch-mirror-push"
    case panelsSave = "panels-save"
    case appIconShortcutItems = "app-icon-shortcut-items"
    case frontendThemeSave = "frontend-theme-save"
}

public enum BackgroundTaskError: Error {
    case outOfTime
    /// The system refused the assertion, so the wrapped work was not started.
    case denied
}

public protocol HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue>

    /// With `requiringAssertion`, the work is skipped and `.denied` returned when the system refuses
    /// the assertion; database work started without one can be frozen holding the file lock.
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue>
}

public extension HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        callAsFunction(withName: name, wrapping: wrapping)
    }
}

// enum for namespacing
public enum HomeAssistantBackgroundTask {
    public static func execute<ReturnType, IdentifierType>(
        withName name: String,
        beginBackgroundTask: (String, @escaping () -> Void) -> (IdentifierType?, TimeInterval?),
        endBackgroundTask: @escaping (IdentifierType) -> Void,
        requiresAssertion: Bool = false,
        wrapping: (TimeInterval?) -> Promise<ReturnType>
    ) -> Promise<ReturnType> {
        func describe(_ identifier: IdentifierType?) -> String {
            if let identifier {
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

        if requiresAssertion, identifier == nil {
            Current.Log.error("background task \(name) was denied; not starting its work")
            return Promise(error: BackgroundTaskError.denied)
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
