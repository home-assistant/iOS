import CallKit
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared
import UIKit
import UserNotifications

/// Rings `incoming_call` notifications through CallKit and reports what the user did back to Home Assistant.
///
/// The call only exists to ring: Home Assistant does not carry audio or video through CallKit. The conversation
/// itself happens in the page the call names (`url`), so answering opens that page and then hands the audio
/// session over to it by ending the CallKit call once the app is in front.
///
/// What happens to a call, and the `mobile_app_notification_action` event Home Assistant receives for it, with
/// the call's `action_data` (its tag included):
///
/// | The user…                       | Event          | CallKit call            |
/// |---------------------------------|----------------|-------------------------|
/// | answers                         | `CALL_ANSWER`  | ended once the app is in front, or after `handOffTimeout` |
/// | declines                        | `CALL_DECLINE` | ended                   |
/// | lets it ring for `timeout`      | `CALL_MISSED`  | ended as unanswered     |
/// | is already ringing for a call   | `CALL_BUSY`    | ended right away        |
/// | has Focus or blocks it (iOS)    | `CALL_MISSED`  | never shown             |
///
/// Home Assistant stops a ringing call with `clear_notification` and the call's tag (the caller hung up, or the
/// call was answered on another device); no event is sent for that. Only a request from the call's own server,
/// made after the call started ringing, stops it (`IncomingCallEndRequest`).
///
/// When CallKit cannot report a call for another reason, it is shown as a time-sensitive notification with the
/// same Answer and Decline actions, which send the same events.
///
/// Everything here runs on the main queue: CallKit's delegate queue, report completions and timers included.
final class IncomingCallController: NSObject {
    /// How long an answered call stays on the in-call screen while the user has not opened the app.
    static let handOffTimeout: TimeInterval = 60

    typealias Schedule = (_ delay: TimeInterval, _ work: DispatchWorkItem) -> Void

    private struct Call {
        enum State {
            /// Reported to CallKit, which has not answered yet. Ending it now ends it as soon as CallKit answers.
            case reporting
            case ringing
            case answered
        }

        let uuid: UUID
        let request: IncomingCallRequest
        let startedAt: Date
        var state: State
        var timer: DispatchWorkItem?
    }

    private let provider: IncomingCallProvider
    private let sendAction: (IncomingCallAction, IncomingCallRequest) -> Void
    private let openPage: (IncomingCallRequest) -> Void
    private let postFallback: (IncomingCallRequest) -> Void
    private let isAppActive: () -> Bool
    private let schedule: Schedule
    private let now: () -> Date
    private let drainEndRequests: () -> [IncomingCallEndRequest]

    private var calls = [UUID: Call]()
    private var observers = [NSObjectProtocol]()

    init(
        provider: IncomingCallProvider = CXProvider(configuration: IncomingCallController.configuration),
        sendAction: @escaping (IncomingCallAction, IncomingCallRequest) -> Void = IncomingCallController.defaultSend,
        open: @escaping (IncomingCallRequest) -> Void = IncomingCallController.defaultOpen,
        postFallback: @escaping (IncomingCallRequest) -> Void = IncomingCallController.defaultPostFallback,
        isAppActive: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
        schedule: @escaping Schedule = { DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1) },
        now: @escaping () -> Date = { Current.date() },
        drainEndRequests: @escaping () -> [IncomingCallEndRequest] = IncomingCallPendingEnd.drainAll
    ) {
        self.provider = provider
        self.sendAction = sendAction
        self.openPage = open
        self.postFallback = postFallback
        self.isAppActive = isAppActive
        self.schedule = schedule
        self.now = now
        self.drainEndRequests = drainEndRequests
        super.init()

        provider.setDelegate(self, queue: nil)

        observers.append(NotificationCenter.default.addObserver(
            forName: IncomingCallPendingEnd.didRequestEnd,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let endRequest = note.object as? IncomingCallEndRequest else { return }
            self?.end(endRequest)
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.didBecomeActive()
        })

        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // A C callback can't capture self; re-derive it (see LiveActivityPendingEndObserver).
            guard let observer else { return }
            let controller = Unmanaged<IncomingCallController>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async { controller.drainPendingEnds() }
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            IncomingCallPendingEnd.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    static var configuration: CXProviderConfiguration {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        // These are not phone calls: they have no number to call back, so keep them out of the Phone app.
        configuration.includesCallsInRecents = false
        configuration.iconTemplateImageData = UIImage(systemSymbol: .houseFill).pngData()
        return configuration
    }

    // MARK: - Ringing

    /// Rings a call. Call it on the main queue.
    ///
    /// - Parameter mustReport: set when the app was launched by `NEAppPushProvider.reportIncomingCall`. iOS
    ///   requires such a launch to report a call to CallKit, so even a call that cannot ring is reported and
    ///   ended at once instead of being skipped.
    func report(_ request: IncomingCallRequest, mustReport: Bool = false) {
        dispatchPrecondition(condition: .onQueue(.main))

        // A call still being reported counts: it is already on its way to the screen.
        let isAlreadyRinging = calls.values.contains { $0.request.tag == request.tag }
        let isBusy = !calls.isEmpty

        if !mustReport, isAlreadyRinging {
            Current.Log.info("incoming call \(request.tag) is already ringing")
            return
        }
        if !mustReport, isBusy {
            Current.Log.info("busy, not ringing incoming call \(request.tag)")
            sendAction(.busy, request)
            return
        }

        let uuid = UUID()
        if !isBusy {
            // Reserved before CallKit answers, so a second delivery, a clear or a reset in the meantime sees it.
            calls[uuid] = Call(uuid: uuid, request: request, startedAt: now(), state: .reporting)
        }

        provider.reportNewIncomingCall(with: uuid, update: Self.update(for: request)) { [weak self] error in
            DispatchQueue.main.async {
                self?.didReport(uuid: uuid, request: request, error: error, isBusy: isBusy)
            }
        }
    }

    /// Satisfies a launch by `NEAppPushProvider.reportIncomingCall` whose payload is not a valid call: iOS still
    /// requires a call to be reported, so one is, and ended immediately.
    func reportInvalidCall() {
        let uuid = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "Home Assistant")
        update.localizedCallerName = "Home Assistant"
        provider.reportNewIncomingCall(with: uuid, update: update) { [provider] error in
            guard error == nil else { return }
            provider.reportCall(with: uuid, endedAt: nil, reason: .failed)
        }
    }

    private func didReport(uuid: UUID, request: IncomingCallRequest, error: Error?, isBusy: Bool) {
        if let error {
            calls[uuid] = nil
            switch (error as? CXErrorCodeIncomingCallError)?.code {
            case .filteredByDoNotDisturb, .filteredByBlockList:
                // The user asked not to be disturbed: no ringing, and no notification around it either.
                Current.Log.info("incoming call \(request.tag) filtered by the system")
                sendAction(.missed, request)
            default:
                Current.Log.error("could not report incoming call \(request.tag): \(error)")
                postFallback(request)
            }
            return
        }

        if isBusy {
            provider.reportCall(with: uuid, endedAt: nil, reason: .unanswered)
            sendAction(.busy, request)
            return
        }

        guard var call = calls[uuid] else {
            // Ended (or reset) while CallKit was still reporting it.
            Current.Log.info("incoming call \(request.tag) ended before it rang")
            provider.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
            return
        }

        let timer = DispatchWorkItem { [weak self] in self?.didTimeOut(uuid: uuid) }
        call.state = .ringing
        call.timer = timer
        calls[uuid] = call
        schedule(request.timeout, timer)

        // A clear may have been queued while iOS was still launching the app, before anything listened for it.
        drainPendingEnds()
    }

    private func didTimeOut(uuid: UUID) {
        guard let call = calls[uuid] else { return }
        calls[uuid] = nil
        let isAnswered = call.state == .answered
        provider.reportCall(with: uuid, endedAt: nil, reason: isAnswered ? .remoteEnded : .unanswered)
        if !isAnswered {
            sendAction(.missed, call.request)
        }
    }

    // MARK: - Ending

    /// Stops the call this request is about, if it is ringing or waiting for the app. Sends no event.
    func end(_ endRequest: IncomingCallEndRequest) {
        for call in calls.values where endRequest.ends(
            tag: call.request.tag,
            webhookID: call.request.webhookID,
            startedAt: call.startedAt
        ) {
            if call.state == .reporting {
                // `didReport` ends it once CallKit has it.
                calls[call.uuid] = nil
            } else {
                finish(call, reason: .remoteEnded)
            }
        }
    }

    func drainPendingEnds() {
        drainEndRequests().forEach(end(_:))
    }

    private func didBecomeActive() {
        drainPendingEnds()
        // The page is in front now: hand the audio session over to it.
        for call in calls.values where call.state == .answered {
            finish(call, reason: .remoteEnded)
        }
    }

    private func finish(_ call: Call, reason: CXCallEndedReason) {
        call.timer?.cancel()
        calls[call.uuid] = nil
        provider.reportCall(with: call.uuid, endedAt: nil, reason: reason)
    }

    private static func update(for request: IncomingCallRequest) -> CXCallUpdate {
        let name = displayName(for: request)
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: name)
        update.localizedCallerName = name
        update.hasVideo = request.hasVideo
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        return update
    }
}

// MARK: - CXProviderDelegate

extension IncomingCallController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        calls.values.forEach { $0.timer?.cancel() }
        calls.removeAll()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        let uuid = action.callUUID
        guard var call = calls[uuid], call.state == .ringing else {
            action.fail()
            return
        }

        call.timer?.cancel()
        call.state = .answered
        // Captures the id only: the call is a value, and the work item is stored back into it.
        let handOff = DispatchWorkItem { [weak self] in self?.didTimeOut(uuid: uuid) }
        call.timer = handOff
        calls[uuid] = call
        action.fulfill()

        sendAction(.answer, call.request)
        openPage(call.request)

        if isAppActive() {
            finish(call, reason: .remoteEnded)
        } else {
            schedule(Self.handOffTimeout, handOff)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        guard let call = calls[action.callUUID] else {
            action.fulfill()
            return
        }

        call.timer?.cancel()
        calls[call.uuid] = nil
        action.fulfill()

        // Hanging up after answering only leaves the in-call screen; the page keeps the conversation.
        if call.state != .answered {
            sendAction(.decline, call.request)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        // There is no CallKit audio to mute; accept it so the in-call screen does not show an error.
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        action.fail()
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        action.fail()
    }
}

// MARK: - Default dependencies

extension IncomingCallController {
    static func server(for request: IncomingCallRequest) -> Server? {
        request.webhookID.flatMap { Current.servers.server(forWebhookID: $0) }
    }

    static func displayName(for request: IncomingCallRequest) -> String {
        request.caller ?? server(for: request)?.info.name ?? "Home Assistant"
    }

    /// The event for an action, as `defaultSend` sends it.
    static func actionInfo(
        _ action: IncomingCallAction,
        for request: IncomingCallRequest
    ) -> HomeAssistantAPI.PushActionInfo {
        HomeAssistantAPI.PushActionInfo(identifier: action.rawValue, actionData: request.actionData)
    }

    static func defaultSend(_ action: IncomingCallAction, for request: IncomingCallRequest) {
        guard let server = server(for: request), let api = Current.api(for: server) else {
            Current.Log.error("no server to send \(action.rawValue) for incoming call \(request.tag)")
            return
        }
        let info = actionInfo(action, for: request)
        Current.backgroundTask(withName: BackgroundTask.handlePushAction.rawValue) { _ in
            api.handlePushAction(for: info)
        }.catch { error in
            Current.Log.error("failed to send \(action.rawValue) for incoming call \(request.tag): \(error)")
        }
    }

    /// Opens the call's page in the app. Answering from the lock screen leaves the user on the in-call screen
    /// until they unlock and open the app, as for any CallKit app; the page is waiting for them then.
    static func defaultOpen(_ request: IncomingCallRequest) {
        guard let server = server(for: request) else { return }
        Current.sceneManager.appCoordinator.done { coordinator in
            if let url = request.url {
                // A path on this server, checked by `IncomingCallRequest`.
                coordinator.open(from: .notification, server: server, urlString: url, isComingFromAppIntent: false)
            } else {
                coordinator.open(server: server)
            }
        }
    }

    /// The notification shown when CallKit cannot report a call: the same Answer and Decline actions, marked as
    /// an incoming call so the app validates its page before opening it, and identified by the tag so
    /// `clear_notification` removes it.
    static func fallbackRequest(for request: IncomingCallRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = displayName(for: request)
        content.body = request.hasVideo ? L10n.IncomingCall.video : L10n.IncomingCall.audio
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        // Shows the actions below through the notification content extension, like any notification's own.
        content.categoryIdentifier = "DYNAMIC"

        var homeassistant = request.actionData
        homeassistant[IncomingCallRequest.notificationMarker] = true
        if let url = request.url {
            homeassistant["url"] = url
        }

        var userInfo: [AnyHashable: Any] = [
            "homeassistant": homeassistant,
            "actions": [
                [
                    "action": IncomingCallAction.answer.rawValue,
                    "title": L10n.IncomingCall.Action.answer,
                    "activationMode": "foreground",
                    "icon": "sfsymbols:phone.fill",
                ],
                [
                    "action": IncomingCallAction.decline.rawValue,
                    "title": L10n.IncomingCall.Action.decline,
                    "destructive": true,
                    "icon": "sfsymbols:phone.down.fill",
                ],
            ],
        ]
        if let webhookID = request.webhookID {
            userInfo["webhook_id"] = webhookID
        }
        content.userInfo = userInfo

        return UNNotificationRequest(identifier: request.tag, content: content, trigger: nil)
    }

    static func defaultPostFallback(_ request: IncomingCallRequest) {
        UNUserNotificationCenter.current().add(fallbackRequest(for: request)) { error in
            if let error {
                Current.Log.error("failed to show incoming call \(request.tag) as a notification: \(error)")
            }
        }
    }
}
