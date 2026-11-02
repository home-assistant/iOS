import CallbackURLKit
import CoreLocation
import CoreSpotlight
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
import SafariServices
@testable import Shared
import SharedTesting
import Testing
import UIKit
import WebKit

/// Routing of every `homeassistant://` host, user activity and home screen shortcut the app accepts:
/// what each one asks the coordinator to show, which confirmation it raises first and what tapping
/// that confirmation sends to the server.
@Suite(.sharedState)
@MainActor
struct IncomingURLHandlerRoutingTests {
    // MARK: - Fakes

    /// Answers webhook sends in place, so the confirmation alerts can be followed through to their
    /// success and error results without a server.
    private final class RecordingWebhookManager: WebhookManager {
        var sendError: Error?
        var ephemeralError: Error?
        private(set) var sentTypes: [String] = []

        func reset() {
            sendError = nil
            ephemeralError = nil
            sentTypes = []
        }

        override func send(
            identifier: WebhookResponseIdentifier = .unhandled,
            server: Server,
            request: WebhookRequest
        ) -> Promise<Void> {
            sentTypes.append(request.type)
            if let sendError {
                return .init(error: sendError)
            }
            return .value(())
        }

        override func sendEphemeral(server: Server, request: WebhookRequest) -> Promise<Void> {
            sentTypes.append(request.type)
            if let ephemeralError {
                return .init(error: ephemeralError)
            }
            return .value(())
        }
    }

    private final class StubTagManager: TagManager {
        var result: TagManagerHandleResult = .unhandled
        private(set) var firedTags: [String] = []

        var isNFCAvailable: Bool { false }
        func readNFC() -> Promise<String> { .init(error: TagManagerError.nfcUnavailable) }
        func writeNFC(value: String) -> Promise<String> { .init(error: TagManagerError.nfcUnavailable) }
        func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
            .init(error: TagManagerError.nfcUnavailable)
        }

        func handle(userActivity: NSUserActivity) -> TagManagerHandleResult { result }

        func fireEvent(tag: String) -> Promise<Void> {
            firedTags.append(tag)
            return .value(())
        }
    }

    private enum TestError: Error {
        case failed
    }

    /// One background-session-backed manager for the whole suite: each `WebhookManager` creates its
    /// URL sessions on init, and the identifiers are better not churned per test.
    private static let webhooks = RecordingWebhookManager()

    @MainActor
    private final class Harness {
        let servers = FakeServerManager(initial: 0)
        let server: Server
        let coordinator = MockAppCoordinator()
        let handler: IncomingURLHandler
        let connection = HAMockConnection()
        let tags = StubTagManager()
        let urlOpener = MockURLOpener()
        let webhooks: RecordingWebhookManager

        init(webhooks: RecordingWebhookManager) {
            self.webhooks = webhooks
            self.server = servers.addFake()
            self.handler = IncomingURLHandler(coordinator: coordinator)
        }

        var serverId: String { server.identifier.rawValue }

        var alerts: [UIAlertController] {
            coordinator.presentedViewControllers.compactMap { $0 as? UIAlertController }
        }
    }

    private func withHarness(_ body: (Harness) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousWebhooks = Current.webhooks
        let previousCachedApis = Current.cachedApis
        let previousTags = Current.tags
        let previousDatabase = Current.database
        let previousOneShotLocation = Current.location.oneShotLocation
        let previousURLOpener = URLOpener.shared
        defer {
            Current.servers = previousServers
            Current.webhooks = previousWebhooks
            Current.cachedApis = previousCachedApis
            Current.tags = previousTags
            Current.database = previousDatabase
            Current.location.oneShotLocation = previousOneShotLocation
            URLOpener.shared = previousURLOpener
        }

        Self.webhooks.reset()
        let harness = Harness(webhooks: Self.webhooks)
        Current.servers = harness.servers
        Current.webhooks = Self.webhooks
        let api = HomeAssistantAPI(server: harness.server)
        api.connection = harness.connection
        Current.setCachedApi(api, for: harness.server.identifier)
        Current.tags = harness.tags
        URLOpener.shared = harness.urlOpener
        Current.location.oneShotLocation = { _, _ in .init(error: TestError.failed) }

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }

        // Prompts are presented once the scene's web view controller exists. The coordinator is what
        // presents them, so the controller only has to fulfil that promise: it is left unloaded, because
        // loading it starts observers, configuration requests and permission work that the scene manager
        // would keep running into later tests.
        if !Current.sceneManager.webViewControllerPromise.isFulfilled {
            // A server on a closed loopback port, so the controller never reaches a real instance.
            let unreachable = Server.fake { info in
                info.connection.set(address: URL(string: "http://127.0.0.1:9"), for: .external)
            }
            let placeholder = WebViewController(server: unreachable)
            // Never loaded, so it has no web view of its own; later code that reaches the scene's
            // controller (switching to kiosk mode refreshes it) needs one to find.
            placeholder.webView = WKWebView()
            Current.sceneManager.setWebViewController(placeholder)
        }

        try await body(harness)
    }

    // MARK: - Helpers

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func alert(_ harness: Harness, at index: Int) async throws -> UIAlertController {
        let expectation1 = await waitUntil { harness.alerts.count > index }
        #expect(expectation1)
        return try #require(harness.alerts.dropFirst(index).first)
    }

    private func tap(_ title: String, in alert: UIAlertController) throws {
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        let action = try #require(alert.actions.first { $0.title == title })
        // An action added without a handler (a plain "OK") has nothing to run.
        guard let block = action.value(forKey: "handler") else { return }
        unsafeBitCast(block as AnyObject, to: Handler.self)(action)
    }

    private func url(_ string: String) throws -> URL {
        try #require(URL(string: "\(AppConstants.deeplinkURL.absoluteString)\(string)"))
    }

    private enum Outcome: Equatable {
        case fulfilled
        case rejected
        /// Still unresolved at the deadline, which fails the comparison instead of hanging the test.
        case pending
    }

    /// How `promise` ended, once it has. A promise still pending after ten seconds reports `.pending`
    /// rather than being awaited: nothing may be left to resolve it, and the test holds the shared-state lock.
    private func settle(_ promise: Promise<Void>) async -> Outcome {
        let resolved = await waitUntil { !promise.isPending }
        guard resolved else { return .pending }
        return promise.isFulfilled ? .fulfilled : .rejected
    }

    // MARK: - X-Callback errors

    @Test func xCallbackErrorsCarryTheirCodeAndAMessage() {
        let errors: [(IncomingURLHandler.XCallbackError, Int)] = [
            (.generalError, 0),
            (.eventNameMissing, 1),
            (.serviceMissing, 2),
            (.templateMissing, 2),
        ]
        for (error, code) in errors {
            #expect(error.code == code)
            #expect(!error.message.isEmpty)
        }
    }

    // MARK: - URL routing

    @Test func aURLWithoutAHostIsAcceptedWithoutDoingAnything() async throws {
        try await withHarness { harness in
            let url = try #require(URL(string: "homeassistant:"))
            #expect(harness.handler.handle(url: url))
            #expect(harness.coordinator.presentedViewControllers.isEmpty)
            #expect(harness.coordinator.openedDeeplinks.isEmpty)
        }
    }

    @Test func aMyLinkOpensInSafariWithTheMobileFlag() async throws {
        try await withHarness { harness in
            let url = try #require(URL(string: "https://my.home-assistant.io/redirect/config/"))
            #expect(harness.handler.handle(url: url))
            let safari = try #require(harness.coordinator.presentedViewControllers.first as? SFSafariViewController)
            #expect(harness.coordinator.presentedViewControllers.count == 1)
            _ = safari
        }
    }

    @Test func anUnknownHostShowsAnError() async throws {
        try await withHarness { harness in
            let expectation2 = try harness.handler.handle(url: url("not_a_route"))
            #expect(expectation2)
            let alert = try await alert(harness, at: 0)
            #expect(alert.title == L10n.errorLabel)
            #expect(alert.message == L10n.UrlHandler.NoService.message("not_a_route"))
            try tap(L10n.okLabel, in: alert)
        }
    }

    @Test func aMyLinkInTheAppSchemeIsNotOpenedInSafari() async throws {
        try await withHarness { harness in
            let expectation3 = try harness.handler.handle(url: url("my.home-assistant.io/redirect/config/"))
            #expect(expectation3)
            let alert = try await alert(harness, at: 0)
            #expect(alert.title == L10n.errorLabel)
            #expect(!harness.coordinator.presentedViewControllers.contains { $0 is SFSafariViewController })
        }
    }

    @Test(arguments: ["call_service", "call_service/light", "call_service/.turn_on", "call_service/light."])
    func aCallServiceLinkWithoutADomainAndServiceIsIgnored(path: String) async throws {
        try await withHarness { harness in
            let link = try url(path)
            #expect(harness.handler.handle(url: link))
            #expect(harness.coordinator.presentedViewControllers.isEmpty)
            #expect(harness.webhooks.sentTypes.isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedCallServiceLinkCallsTheServiceAndReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            if fails {
                harness.webhooks.sendError = TestError.failed
            }
            let expectation4 = try harness.handler
                .handle(url: url("call_service/light.turn_on?entity_id=light.kitchen"))
            #expect(expectation4)

            let confirm = try await alert(harness, at: 0)
            #expect(confirm.title == L10n.UrlHandler.CallService.Confirm.title)
            #expect(confirm.message == L10n.UrlHandler.CallService.Confirm.message("light.turn_on"))
            try tap(L10n.yesLabel, in: confirm)

            let result = try await alert(harness, at: 1)
            #expect(harness.webhooks.sentTypes == ["call_service"])
            #expect(result.title == (fails ? L10n.errorLabel : L10n.UrlHandler.CallService.Success.title))
        }
    }

    @Test func aCallServiceLinkWithoutAServerReportsAnError() async throws {
        try await withHarness { harness in
            Current.servers = FakeServerManager(initial: 0)
            let expectation5 = try harness.handler.handle(url: url("call_service/light.turn_on"))
            #expect(expectation5)
            let shownAlert38 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert38)

            let result = try await alert(harness, at: 1)
            #expect(result.title == L10n.errorLabel)
            #expect(harness.webhooks.sentTypes.isEmpty)
        }
    }

    @Test func aCancelledCallServiceLinkSendsNothing() async throws {
        try await withHarness { harness in
            let expectation6 = try harness.handler.handle(url: url("call_service/light.turn_on"))
            #expect(expectation6)
            let shownAlert39 = try await alert(harness, at: 0)
            try tap(L10n.cancelLabel, in: shownAlert39)
            #expect(harness.webhooks.sentTypes.isEmpty)
            #expect(harness.alerts.count == 1)
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedFireEventLinkFiresTheEventAndReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            if fails {
                harness.webhooks.ephemeralError = TestError.failed
            }
            let expectation7 = try harness.handler.handle(url: url("fire_event/custom_event?entity_id=light.kitchen"))
            #expect(expectation7)

            let confirm = try await alert(harness, at: 0)
            #expect(confirm.title == L10n.UrlHandler.FireEvent.Confirm.title)
            try tap(L10n.yesLabel, in: confirm)

            let result = try await alert(harness, at: 1)
            #expect(harness.webhooks.sentTypes == ["fire_event"])
            #expect(result.title == (fails ? L10n.errorLabel : L10n.UrlHandler.FireEvent.Success.title))
        }
    }

    @Test func aFireEventLinkWithoutAServerReportsAnError() async throws {
        try await withHarness { harness in
            Current.servers = FakeServerManager(initial: 0)
            let expectation8 = try harness.handler.handle(url: url("fire_event/custom_event"))
            #expect(expectation8)
            let shownAlert40 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert40)
            let expectation9 = try await alert(harness, at: 1).title == L10n.errorLabel
            #expect(expectation9)
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedSendLocationLinkReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            // Without servers there is nothing to submit to, so a location alone completes the send.
            Current.servers = FakeServerManager(initial: 0)
            if !fails {
                Current.location.oneShotLocation = { _, _ in .value(CLLocation(latitude: 1, longitude: 2)) }
            }
            let expectation10 = try harness.handler.handle(url: url("send_location/"))
            #expect(expectation10)

            let confirm = try await alert(harness, at: 0)
            #expect(confirm.title == L10n.UrlHandler.SendLocation.Confirm.title)
            try tap(L10n.yesLabel, in: confirm)

            let result = try await alert(harness, at: 1)
            #expect(result.title == (fails ? L10n.errorLabel : L10n.UrlHandler.SendLocation.Success.title))
        }
    }

    @Test func aNavigateLinkForAKnownServerOpensThePathOnThatServer() async throws {
        try await withHarness { harness in
            let link = try url(
                "navigate/lovelace/kitchen?serverId=\(harness.serverId)"
                    + "&\(AppConstants.QueryItems.isComingFromAppIntent.rawValue)=true"
            )
            #expect(harness.handler.handle(url: link))

            let opened = try #require(harness.coordinator.openedDeeplinks.first)
            #expect(opened.server.identifier == harness.server.identifier)
            #expect(opened.urlString.hasPrefix("/lovelace/kitchen"))
            #expect(harness.coordinator.openedDeeplinksSelectingServer.isEmpty)
        }
    }

    @Test func aNavigateLinkNamingAWebhookOpensItsServerWithoutLeakingTheWebhook() async throws {
        try await withHarness { harness in
            let webhookID = harness.server.info.connection.webhookID
            let expectation11 = try harness.handler.handle(url: url("navigate/map?webhook_id=\(webhookID)"))
            #expect(expectation11)

            let opened = try #require(harness.coordinator.openedDeeplinks.first)
            #expect(opened.server.identifier == harness.server.identifier)
            #expect(!opened.urlString.contains("webhook_id"))
        }
    }

    @Test func aNavigateLinkWithAnExplicitURLOpensThatURL() async throws {
        try await withHarness { harness in
            let link = try url("navigate/?serverId=\(harness.serverId)&url=https%3A%2F%2Fexample.com%2Fpage")
            #expect(harness.handler.handle(url: link))

            let opened = try #require(harness.coordinator.openedDeeplinks.first)
            #expect(opened.urlString == "https://example.com/page")
        }
    }

    @Test func aNavigateLinkWithoutAServerAsksWhichServerToUse() async throws {
        try await withHarness { harness in
            let expectation12 = try harness.handler.handle(url: url("navigate/energy?serverId=unknown"))
            #expect(expectation12)

            #expect(harness.coordinator.openedDeeplinks.isEmpty)
            let opened = try #require(harness.coordinator.openedDeeplinksSelectingServer.first)
            #expect(opened.hasPrefix("/energy"))
        }
    }

    @Test func aNavigateLinkOverAMyLinkWaitsForSafariToBeDismissed() async throws {
        try await withHarness { harness in
            harness.coordinator.presentedViewController = try SFSafariViewController(
                url: #require(URL(string: "https://my.home-assistant.io"))
            )
            let expectation13 = try harness.handler.handle(url: url("navigate/energy?serverId=\(harness.serverId)"))
            #expect(expectation13)

            // Opening happens once Safari is gone, not straight away on the server the link names.
            #expect(harness.coordinator.openedDeeplinks.isEmpty)
        }
    }

    @Test(arguments: ["assist", "assist?serverId=unknown"])
    func anAssistLinkWithoutAServerToUseIsRejected(path: String) async throws {
        try await withHarness { harness in
            if path.contains("serverId") {
                Current.servers = FakeServerManager(initial: 0)
            }
            let link = try url(path)
            #expect(!harness.handler.handle(url: link))
            #expect(harness.coordinator.dismissPresentedContentCallCount == 0)
        }
    }

    @Test func anInvitationWithoutAFragmentIsRejected() async throws {
        try await withHarness { harness in
            let link = try url("invite")
            #expect(!harness.handler.handle(url: link))
        }
    }

    @Test func anInvitationWithAFragmentIsAccepted() async throws {
        try await withHarness { harness in
            let link = try url("invite#url=http%3A%2F%2Fhomeassistant.local%3A8123")
            #expect(harness.handler.handle(url: link))
        }
    }

    // MARK: - X-Callback-URL actions

    private struct CallbackResult {
        var successes: [[String: String]?] = []
        var failures: [Int] = []
        var cancels = 0
    }

    private final class CallbackRecorder {
        var result = CallbackResult()
    }

    private func perform(
        _ action: String,
        parameters: [String: String],
        recorder: CallbackRecorder
    ) throws {
        let actionHandler = try #require(Manager.shared[action])
        actionHandler(
            parameters,
            { recorder.result.successes.append($0) },
            { recorder.result.failures.append($0.code) },
            { recorder.result.cancels += 1 }
        )
    }

    @Test(arguments: [
        ("fire_event", 1),
        ("call_service", 2),
        ("render_template", 2),
    ])
    func anXCallbackActionMissingItsParameterFails(action: String, code: Int) async throws {
        try await withHarness { _ in
            let recorder = CallbackRecorder()
            try perform(action, parameters: [:], recorder: recorder)
            #expect(recorder.result.failures == [code])
        }
    }

    @Test(arguments: ["fire_event", "call_service", "send_location", "render_template"])
    func aCancelledXCallbackActionReportsTheCancellation(action: String) async throws {
        try await withHarness { harness in
            let recorder = CallbackRecorder()
            try perform(
                action,
                parameters: ["eventName": "event", "service": "light.turn_on", "template": "{{ 1 }}"],
                recorder: recorder
            )
            let shownAlert41 = try await alert(harness, at: 0)
            try tap(L10n.cancelLabel, in: shownAlert41)
            #expect(recorder.result.cancels == 1)
            #expect(harness.webhooks.sentTypes.isEmpty)
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedXCallbackFireEventReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            if fails {
                harness.webhooks.ephemeralError = TestError.failed
            }
            let recorder = CallbackRecorder()
            try perform("fire_event", parameters: ["eventName": "event", "key": "value"], recorder: recorder)
            let expectation14 = try await alert(harness, at: 0).title == L10n.UrlHandler.FireEvent.Confirm.title
            #expect(expectation14)
            let shownAlert42 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert42)

            let expectation15 = await waitUntil { recorder.result.successes.count + recorder.result.failures.count == 1
            }
            #expect(expectation15)
            #expect(recorder.result.failures == (fails ? [0] : []))
            #expect(harness.webhooks.sentTypes == ["fire_event"])
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedXCallbackCallServiceReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            if fails {
                harness.webhooks.sendError = TestError.failed
            }
            let recorder = CallbackRecorder()
            try perform("call_service", parameters: ["service": "light.turn_on", "key": "value"], recorder: recorder)
            let shownAlert43 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert43)

            let expectation16 = await waitUntil { recorder.result.successes.count + recorder.result.failures.count == 1
            }
            #expect(expectation16)
            #expect(recorder.result.failures == (fails ? [0] : []))
            #expect(harness.webhooks.sentTypes == ["call_service"])
        }
    }

    @Test(arguments: ["fire_event", "call_service", "render_template"])
    func aConfirmedXCallbackActionWithoutAServerFails(action: String) async throws {
        try await withHarness { harness in
            Current.servers = FakeServerManager(initial: 0)
            let recorder = CallbackRecorder()
            try perform(
                action,
                parameters: ["eventName": "event", "service": "light.turn_on", "template": "{{ 1 }}"],
                recorder: recorder
            )
            let shownAlert44 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert44)

            let expectation17 = await waitUntil { recorder.result.failures.count == 1 }
            #expect(expectation17)
            #expect(recorder.result.failures == [0])
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedXCallbackSendLocationReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            Current.servers = FakeServerManager(initial: 0)
            if !fails {
                Current.location.oneShotLocation = { _, _ in .value(CLLocation(latitude: 1, longitude: 2)) }
            }
            let recorder = CallbackRecorder()
            try perform("send_location", parameters: [:], recorder: recorder)
            let shownAlert45 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert45)

            let expectation18 = await waitUntil { recorder.result.successes.count + recorder.result.failures.count == 1
            }
            #expect(expectation18)
            #expect(recorder.result.failures == (fails ? [0] : []))
        }
    }

    @Test(arguments: [false, true])
    func aConfirmedXCallbackRenderTemplateReturnsTheRenderedValue(fails: Bool) async throws {
        try await withHarness { harness in
            let recorder = CallbackRecorder()
            try perform("render_template", parameters: ["template": "{{ 1 + 1 }}", "x": "1"], recorder: recorder)
            let shownAlert46 = try await alert(harness, at: 0)
            try tap(L10n.yesLabel, in: shownAlert46)

            let subscription = try #require(harness.connection.pendingSubscriptions.first)
            if fails {
                subscription.initiated(.failure(.internal(debugDescription: "failed")))
                #expect(recorder.result.failures == [0])
            } else {
                subscription.initiated(.success(.empty))
                subscription.handler(subscription.cancellable, .dictionary(["result": "2", "listeners": [:]]))
                #expect(recorder.result.successes.count == 1)
                #expect(subscription.cancellable.wasCancelled)
            }
        }
    }

    @Test func anXCallbackURLIsRoutedToTheCallbackManager() async throws {
        try await withHarness { harness in
            let scheme = try #require(Manager.shared.callbackURLScheme)
            let link = try #require(URL(string: "\(scheme)://x-callback-url/fire_event"))
            // The handler fails the missing event name straight away rather than asking to confirm.
            #expect(harness.handler.handle(url: link))
            #expect(harness.coordinator.presentedViewControllers.isEmpty)
        }
    }

    // MARK: - User activities

    @Test func aSpotlightResultForAnUnknownEntityIsNotHandled() async throws {
        try await withHarness { harness in
            let activity = NSUserActivity(activityType: CSSearchableItemActionType)
            activity.userInfo = [CSSearchableItemActivityIdentifier: "missing-entity"]
            #expect(!harness.handler.handle(userActivity: activity))
        }
    }

    @Test(arguments: [TagManagerHandleResult.HandledType.nfc, .generic])
    func aHandledTagShowsTheReadConfirmation(type: TagManagerHandleResult.HandledType) async throws {
        try await withHarness { harness in
            harness.tags.result = .handled(type)
            #expect(harness.handler.handle(userActivity: NSUserActivity(activityType: "tag")))

            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
            harness.coordinator.window = window
            #expect(harness.handler.handle(userActivity: NSUserActivity(activityType: "tag")))
            harness.coordinator.window = nil
        }
    }

    @Test func aTagThatNeedsApprovalAsksBeforeFiring() async throws {
        try await withHarness { harness in
            harness.tags.result = .requiresApproval(tag: "front-door", type: .nfc)
            #expect(harness.handler.handle(userActivity: NSUserActivity(activityType: "tag")))

            let expectation19 = await waitUntil { !harness.coordinator.presentedViewControllers.isEmpty }
            #expect(expectation19)
            let sheet = try #require(harness.coordinator.presentedViewControllers.first)
            #expect(sheet.modalPresentationStyle == .overFullScreen)
            #expect(harness.tags.firedTags.isEmpty)
        }
    }

    @Test func aTagHoldingALinkOpensTheLink() async throws {
        try await withHarness { harness in
            harness.tags.result = try .open(url("settings"))
            #expect(harness.handler.handle(userActivity: NSUserActivity(activityType: "tag")))
            #expect(harness.coordinator.showSettingsCalled)
        }
    }

    @Test func anUnhandledActivityOpensAMyLinkAndIgnoresAnythingElse() async throws {
        try await withHarness { harness in
            let other = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            other.webpageURL = URL(string: "https://example.com/page")
            #expect(!harness.handler.handle(userActivity: other))

            let myLink = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
            myLink.webpageURL = URL(string: "https://my.home-assistant.io/redirect/energy/")
            #expect(harness.handler.handle(userActivity: myLink))
            #expect(harness.coordinator.presentedViewControllers.first is SFSafariViewController)
        }
    }

    // MARK: - Home screen shortcuts

    @Test func anUnknownShortcutIsRejected() async throws {
        try await withHarness { harness in
            let item = UIApplicationShortcutItem(type: "unknown", localizedTitle: "Unknown")
            let expectation20 = await settle(harness.handler.handle(shortcutItem: item)) == .rejected
            #expect(expectation20)
        }
    }

    @Test(arguments: [false, true])
    func theSendLocationShortcutReportsTheResult(fails: Bool) async throws {
        try await withHarness { harness in
            Current.servers = FakeServerManager(initial: 0)
            if !fails {
                Current.location.oneShotLocation = { _, _ in .value(CLLocation(latitude: 1, longitude: 2)) }
            }
            let item = UIApplicationShortcutItem(
                type: HAApplicationShortcutItem.sendLocation.rawValue,
                localizedTitle: "Send location"
            )
            let expectation21 = await settle(harness.handler.handle(shortcutItem: item)) ==
                (fails ? .rejected : .fulfilled)
            #expect(expectation21)
        }
    }

    private func shortcutItem(for item: MagicItem) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: "appIconShortcut.\(item.serverId)|\(item.type.rawValue)|\(item.id)",
            localizedTitle: item.id
        )
    }

    private func store(_ items: [MagicItem]) throws {
        try Current.database().write { db in
            try AppIconShortcutConfig(items: items).save(db)
        }
    }

    @Test func anAppIconShortcutWithoutAConfigIsRejected() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "script.morning", serverId: harness.serverId, type: .script)
            let expectation22 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) == .rejected
            #expect(expectation22)
        }
    }

    @Test func anAppIconShortcutThatDoesNothingSucceedsQuietly() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "light.kitchen", serverId: harness.serverId, type: .entity, action: .nothing)
            try store([item])
            let expectation23 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) ==
                .fulfilled
            #expect(expectation23)
            #expect(harness.coordinator.openedDeeplinks.isEmpty)
        }
    }

    @Test func anAppIconShortcutForAMoreInfoDialogOpensTheEntity() async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .moreInfoDialog
            )
            try store([item])
            let expectation24 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) ==
                .fulfilled
            #expect(expectation24)
            let opened = try #require(harness.coordinator.openedDeeplinks.first)
            #expect(opened.urlString.contains("light.kitchen"))
        }
    }

    @Test func anAppIconShortcutForAnAppDeepLinkHandlesItInPlace() async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .url("homeassistant://settings")
            )
            try store([item])
            let expectation25 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) ==
                .fulfilled
            #expect(expectation25)
            #expect(harness.coordinator.showSettingsCalled)
            #expect(harness.urlOpener.openedURLs.isEmpty)
        }
    }

    @Test func anAppIconShortcutForAWebLinkOpensItOutsideTheApp() async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .url("example.com/page")
            )
            try store([item])
            let expectation26 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) ==
                .fulfilled
            #expect(expectation26)
            #expect(harness.urlOpener.openedURLs.map(\.url) == [URL(string: "https://example.com/page")])
        }
    }

    @Test func anAppIconShortcutWithAnEmptyLinkIsRejected() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "light.kitchen", serverId: harness.serverId, type: .entity, action: .url("  "))
            try store([item])
            let expectation27 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) == .rejected
            #expect(expectation27)
        }
    }

    @Test(arguments: [
        (serverKnown: false, actionId: "light.turn_on"),
        (serverKnown: true, actionId: "turn_on"),
    ])
    func anAppIconShortcutPerformingAnUnusableActionIsRejected(serverKnown: Bool, actionId: String) async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .performAction(serverKnown ? harness.serverId : "unknown", actionId, "{}")
            )
            try store([item])
            let expectation28 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) == .rejected
            #expect(expectation28)
            #expect(harness.connection.pendingRequests.isEmpty)
        }
    }

    @Test(arguments: ["{\"brightness\": 10}", "not json", ""])
    func anAppIconShortcutPerformingAnActionCallsIt(payload: String) async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .performAction(harness.serverId, "light.turn_on", payload)
            )
            try store([item])
            let promise = harness.handler.handle(shortcutItem: shortcutItem(for: item))

            let expectation29 = await waitUntil { !harness.connection.pendingRequests.isEmpty }
            #expect(expectation29)
            let request = try #require(harness.connection.pendingRequests.first)
            #expect(request.request.data["domain"] as? String == "light")
            #expect(request.request.data["service"] as? String == "turn_on")
            request.completion(.success(.empty))
            let expectation30 = await settle(promise) == .fulfilled
            #expect(expectation30)
        }
    }

    @Test(arguments: [
        (serverKnown: true, fails: false),
        (serverKnown: true, fails: true),
        (serverKnown: false, fails: false),
    ])
    func anAppIconShortcutRunningAScriptCallsIt(serverKnown: Bool, fails: Bool) async throws {
        try await withHarness { harness in
            if fails {
                harness.webhooks.sendError = TestError.failed
            }
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .runScript(serverKnown ? harness.serverId : "unknown", "script.morning")
            )
            try store([item])
            let outcome = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item)))
            #expect(outcome == (serverKnown && !fails ? .fulfilled : .rejected))
            #expect(harness.webhooks.sentTypes == (serverKnown ? ["call_service"] : []))
        }
    }

    @Test func anAppIconShortcutNavigatingOpensThePath() async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                action: .navigate("  //lovelace/1 ")
            )
            try store([item])
            let expectation31 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) ==
                .fulfilled
            #expect(expectation31)
            let opened = try #require(harness.coordinator.openedDeeplinksSelectingServer.first)
            #expect(URLComponents(string: opened)?.path == "/lovelace/1")
        }
    }

    @Test func aFolderAppIconShortcutIsRejected() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "folder", serverId: harness.serverId, type: .folder)
            try store([item])
            let expectation32 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) == .rejected
            #expect(expectation32)
        }
    }

    @Test func anAppIconShortcutForAServerThatIsGoneIsRejected() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "script.morning", serverId: "unknown", type: .script)
            try store([item])
            let expectation33 = await settle(harness.handler.handle(shortcutItem: shortcutItem(for: item))) == .rejected
            #expect(expectation33)
        }
    }

    @Test(arguments: [false, true])
    func aScriptAppIconShortcutRunsTheScriptOverTheConnection(fails: Bool) async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "script.morning", serverId: harness.serverId, type: .script)
            try store([item])
            let promise = harness.handler.handle(shortcutItem: shortcutItem(for: item))

            let expectation34 = await waitUntil { !harness.connection.pendingRequests.isEmpty }
            #expect(expectation34)
            let request = try #require(harness.connection.pendingRequests.first)
            request.completion(fails ? .failure(.internal(debugDescription: "failed")) : .success(.empty))
            let expectation35 = await settle(promise) == (fails ? .rejected : .fulfilled)
            #expect(expectation35)
        }
    }

    @Test func aLightAppIconShortcutTogglesTheLight() async throws {
        try await withHarness { harness in
            let item = MagicItem(id: "light.kitchen", serverId: harness.serverId, type: .entity, action: .toggle)
            try store([item])
            let promise = harness.handler.handle(shortcutItem: shortcutItem(for: item))

            // Answer whatever the toggle asks for (the entity's state, then the service call).
            var answered = 0
            let deadline = Date().addingTimeInterval(10)
            while promise.isPending, Date() < deadline {
                let pending = harness.connection.pendingRequests
                if pending.count > answered {
                    for request in pending[answered...] {
                        request.completion(.success(.dictionary(["state": "on"])))
                    }
                    answered = pending.count
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            let expectation36 = await settle(promise) == .fulfilled
            #expect(expectation36)
            #expect(answered >= 1)
        }
    }

    @Test(arguments: [false, true])
    func anAppIconShortcutThatRequiresConfirmationAsksFirst(confirms: Bool) async throws {
        try await withHarness { harness in
            let item = MagicItem(
                id: "light.kitchen",
                serverId: harness.serverId,
                type: .entity,
                customization: .init(requiresConfirmation: true),
                action: .nothing,
                displayText: "Kitchen"
            )
            try store([item])
            let promise = harness.handler.handle(shortcutItem: shortcutItem(for: item))

            let confirm = try await alert(harness, at: 0)
            try tap(confirms ? L10n.yesLabel : L10n.cancelLabel, in: confirm)
            let expectation37 = await settle(promise) == .fulfilled
            #expect(expectation37)
        }
    }
}
