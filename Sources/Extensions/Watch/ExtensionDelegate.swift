import ClockKit
import Communicator
import PromiseKit
import Shared
import UserNotifications
import WatchKit
import XCGLogger

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    // MARK: Fileprivate

    fileprivate var watchConnectivityBackgroundPromise: Guarantee<Void>
    fileprivate var watchConnectivityBackgroundSeal: (()) -> Void
    fileprivate var watchConnectivityWatchdogTimer: Timer?

    private var immediateCommunicatorService: ImmediateCommunicatorService?

    override init() {
        (self.watchConnectivityBackgroundPromise, self.watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        super.init()
    }

    // MARK: - WKExtensionDelegate -

    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        Current.Log.verbose("didFinishLaunching")

        UNUserNotificationCenter.current().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound, .criticalAlert, .providesAppNotificationSettings]

        WKExtension.shared().registerForRemoteNotifications()

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            Current.Log.verbose("Requested notifications access \(granted), \(String(describing: error))")
        }

        setupWatchCommunicator()

        // schedule the next background refresh
        Current.backgroundRefreshScheduler.schedule().cauterize()
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive.
        // If the application was previously in the background, optionally refresh the user interface.

        Current.Log.verbose("didBecomeActive")
        _ = HomeAssistantAPI.SyncWatchContext()
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state.
        // This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
        // or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Current.Log.verbose("willResignActive")
        _ = HomeAssistantAPI.SyncWatchContext()
        Current.backgroundRefreshScheduler.schedule().cauterize()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        _ = HomeAssistantAPI.SyncWatchContext()

        // Sent when the system needs to launch the application in the background to process tasks.
        // Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                Current.Log.verbose("WKApplicationRefreshBackgroundTask received")

                firstly {
                    when(fulfilled: Current.apis.map { $0.updateComplications(passively: true) })
                }.ensureThen {
                    Current.backgroundRefreshScheduler.schedule()
                }.ensure {
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }.cauterize()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: Date.distantFuture,
                    userInfo: nil
                )
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                enqueueForCompletion(connectivityTask)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                Current.webhooks.handleBackground(for: urlSessionTask.sessionIdentifier) {
                    Current.backgroundRefreshScheduler.schedule().done {
                        urlSessionTask.setTaskCompletedWithSnapshot(false)
                    }
                }
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    // Triggered when a complication is tapped
    func handleUserActivity(_ userInfo: [AnyHashable: Any]?) {
        let complication: WatchComplication?

        if let identifier = userInfo?[CLKLaunchedComplicationIdentifierKey] as? String,
           identifier != CLKDefaultComplicationIdentifier {
            complication = Current.realm().object(
                ofType: WatchComplication.self,
                forPrimaryKey: identifier
            )
        } else if let date = userInfo?[CLKLaunchedTimelineEntryDateKey] as? Date,
                  let clkFamily = date.complicationFamilyFromEncodedDate {
            let family = ComplicationGroupMember(family: clkFamily)
            complication = Current.realm().object(
                ofType: WatchComplication.self,
                forPrimaryKey: family.rawValue
            )
        } else {
            complication = nil
        }

        if let complication {
            Current.Log.info("launched for \(complication.identifier) of family \(complication.Family)")
        } else if let identifier = userInfo?[CLKLaunchedComplicationIdentifierKey] as? String,
                  identifier == AssistDefaultComplication.defaultComplicationId {
            NotificationCenter.default.post(name: AssistDefaultComplication.launchNotification, object: nil)
        } else {
            Current.Log.verbose("unknown or no complication launched the app")
        }
    }

    func setupWatchCommunicator() {
        // This directly mutates the data structure for observations to avoid race conditions.

        Communicator.State.observations.store[.init(queue: .main)] = { state in
            Current.Log.verbose("Activation state changed: \(state)")

            _ = HomeAssistantAPI.SyncWatchContext()
        }

        Reachability.observations.store[.init(queue: .main)] = { reachability in
            Current.Log.verbose("Reachability changed: \(reachability)")
        }

        InteractiveImmediateMessage.observations.store[.init(queue: .main)] = { message in
            Current.Log.verbose("Received message: \(message.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        immediateCommunicatorService = ImmediateCommunicatorService.shared

        ImmediateMessage.observations.store[.init(queue: .main)] = { [weak self] message in
            Current.Log.verbose("Received message: \(message.identifier)")
            self?.immediateCommunicatorService?.evaluateMessage(message)
            self?.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        GuaranteedMessage.observations.store[.init(queue: .main)] = { message in
            Current.Log.verbose("Received guaranteed message! \(message)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Blob.observations.store[.init(queue: .main)] = { blob in
            Current.Log.verbose("Received blob: \(blob.identifier)")

            self.endWatchConnectivityBackgroundTaskIfNecessary()
        }

        Context.observations.store[.init(queue: .main)] = { [weak self] context in
            Current.Log.verbose("Received context: \(context)")

            self?.updateContext(context.content)
        }

        ComplicationInfo.observations.store[.init(queue: .main)] = { complicationInfo in
            Current.Log.verbose("Received complication info: \(complicationInfo)")

            self.updateComplications()
        }

        _ = Communicator.shared
    }

    private func enqueueForCompletion(_ task: WKWatchConnectivityRefreshBackgroundTask) {
        DispatchQueue.main.async { [self] in
            guard Communicator.shared.hasPendingDataToBeReceived else {
                // nothing else to be received
                task.setTaskCompletedWithSnapshot(false)
                return
            }

            // wait for it to send the next set of data
            watchConnectivityBackgroundPromise.done {
                task.setTaskCompletedWithSnapshot(false)
            }

            if watchConnectivityWatchdogTimer == nil || watchConnectivityWatchdogTimer?.isValid == false {
                // 10s should be more than enough time, and the system timer's at 15s (last tested watchOS 7)
                let timer = Timer.scheduledTimer(
                    withTimeInterval: 10.0,
                    repeats: true
                ) { [weak self] _ in
                    // we endeavor to not need this timer, but apple's api is so difficult to micromanage
                    // that it's just safer to guess and check every few seconds
                    Current.Log.info("ending background task due to our own watchdog timer")
                    self?.endWatchConnectivityBackgroundTaskIfNecessary()
                }

                watchConnectivityBackgroundPromise.done {
                    timer.invalidate()
                }

                watchConnectivityWatchdogTimer = timer
            }
        }
    }

    private func endWatchConnectivityBackgroundTaskIfNecessary() {
        DispatchQueue.main.async { [self] in
            guard !Communicator.shared.hasPendingDataToBeReceived else { return }

            // complete the current one
            watchConnectivityBackgroundSeal(())
            // and set up a new one for the next chain of updates
            (watchConnectivityBackgroundPromise, watchConnectivityBackgroundSeal) = Guarantee<Void>.pending()
        }
    }

    private func updateContext(_ content: Content) {
        let realm = Current.realm()

        if let servers = content["servers"] as? Data {
            Current.servers.restoreState(servers)
        }

        if let actionsDictionary = content["actions"] as? [[String: Any]] {
            let actions = actionsDictionary.compactMap { try? Action(JSON: $0) }

            Current.Log.verbose("Updating actions from context \(actions)")

            realm.reentrantWrite {
                realm.delete(realm.objects(Action.self))
                realm.add(actions, update: .all)
            }
        }

        if let complicationsDictionary = content["complications"] as? [[String: Any]] {
            let complications = complicationsDictionary.compactMap { try? WatchComplication(JSON: $0) }

            Current.Log.verbose("Updating complications from context \(complications)")

            realm.reentrantWrite {
                realm.delete(realm.objects(WatchComplication.self))
                realm.add(complications, update: .all)
            }
        }

        updateComplications()
    }

    private var isUpdatingComplications = false
    private func updateComplications() {
        // avoid double-updating due to e.g. complication info update request
        guard !isUpdatingComplications else { return }

        isUpdatingComplications = true

        firstly {
            when(fulfilled: Current.apis.map { $0.updateComplications(passively: true) })
        }.ensure { [self] in
            isUpdatingComplications = false
        }.ensure { [self] in
            endWatchConnectivityBackgroundTaskIfNecessary()
        }.cauterize()
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let apnsToken = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Current.Log.verbose("Successfully registered for push notifications! APNS token: \(apnsToken)")
    }

    func didFailToRegisterForRemoteNotificationsWithError(_ error: Error) {
        Current.Log.error("Error when trying to register for push: \(error)")
    }
}

extension ExtensionDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let info = HomeAssistantAPI.PushActionInfo(response: response),
              let server = Current.servers.server(for: response.notification.request.content) else {
            completionHandler()
            return
        }

        firstly { () -> Promise<Void> in
            let (promise, seal) = Promise<Void>.pending()

            if Communicator.shared.currentReachability == .immediatelyReachable {
                Current.Log.info("sending via phone")
                Communicator.shared.send(.init(
                    identifier: InteractiveImmediateMessages.pushAction.rawValue,
                    content: ["PushActionInfo": info.toJSON(), "Server": server.identifier.rawValue],
                    reply: { message in
                        Current.Log.verbose("Received reply dictionary \(message)")
                        seal.fulfill(())
                    }
                ), errorHandler: { error in
                    Current.Log.error("Received error when sending immediate message \(error)")
                    seal.reject(error)
                })
            } else {
                Current.Log.info("sending via local")
                Current.api(for: server).handlePushAction(for: info)
                    .pipe(to: seal.resolve)
            }

            return promise
        }.ensure {
            completionHandler()
        }.cauterize()
    }
}
