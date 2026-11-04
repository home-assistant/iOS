import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Running each "Add to" action from the frontend's menu: which screen it opens over the web view,
/// what the Mac toolbar action stores, and how a missing web view or unknown action fails.
@Suite(.sharedState)
@MainActor
struct EntityAddToHandlerExecuteTests {
    private struct UnknownAction: EntityAddToAction {
        var mdiIcon: String { "mdi:help" }
        var actionType: String { "teleport" }
        func text() -> String { "Teleport" }
    }

    private enum Outcome: Equatable {
        case fulfilled
        case rejected
    }

    private func settle(_ promise: Promise<Void>) async -> Outcome {
        await withCheckedContinuation { continuation in
            promise.pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume(returning: .fulfilled)
                case .rejected:
                    continuation.resume(returning: .rejected)
                }
            }
        }
    }

    private func withDatabase(_ body: (DatabaseQueue) async throws -> Void) async throws {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        Current.database = { database }
        defer { Current.database = previousDatabase }
        try await body(database)
    }

    @Test(arguments: [
        EntityAddToActionType.carPlayQuickAccess,
        .watchItem,
        .customWidget,
    ])
    func anActionWithAScreenPresentsItOverTheWebView(type: EntityAddToActionType) async throws {
        try await withDatabase { _ in
            let webView = MockWebViewController()
            let sut = EntityAddToHandler(webViewController: webView)
            let action: any EntityAddToAction = switch type {
            case .carPlayQuickAccess: CarPlayQuickAccessAction()
            case .watchItem: WatchItemAction()
            default: CustomWidgetAction()
            }

            let expectation1 = await settle(sut.execute(action: action, entityId: "light.kitchen")) == .fulfilled
            #expect(expectation1)

            #expect(webView.presentOverlayControllerCalled)
            let controller = try #require(webView.overlayedController)
            if type == .customWidget {
                #expect(controller.sheetPresentationController?.prefersGrabberVisible == true)
            }
            controller.loadViewIfNeeded()
        }
    }

    @Test func theMacToolbarActionStoresTheEntityOnce() async throws {
        try await withDatabase { _ in
            let webView = MockWebViewController()
            let sut = EntityAddToHandler(webViewController: webView)
            var notifications = 0
            let observer = NotificationCenter.default.addObserver(
                forName: .macToolbarConfigDidChange,
                object: nil,
                queue: nil
            ) { _ in notifications += 1 }
            defer { NotificationCenter.default.removeObserver(observer) }

            let expectation2 = await settle(sut.execute(action: MacToolbarItemAction(), entityId: "light.kitchen")) ==
                .fulfilled
            #expect(expectation2)
            let expectation3 = await settle(sut.execute(action: MacToolbarItemAction(), entityId: "light.kitchen")) ==
                .fulfilled
            #expect(expectation3)

            let configValue = try MacToolbarConfig.config()
            let config = try #require(configValue)
            #expect(config.items.map(\.id) == ["light.kitchen"])
            #expect(config.items.first?.serverId == webView.server.identifier.rawValue)
            #expect(config.items.first?.action == .moreInfoDialog)
            #expect(notifications == 2)
        }
    }

    @Test func anUnknownActionIsRejected() async {
        let webView = MockWebViewController()
        let sut = EntityAddToHandler(webViewController: webView)

        let expectation4 = await settle(sut.execute(action: UnknownAction(), entityId: "light.kitchen")) == .rejected
        #expect(expectation4)
        #expect(!webView.presentOverlayControllerCalled)
    }

    @Test func anActionWithoutAWebViewIsRejected() async {
        let sut = EntityAddToHandler(webViewController: nil)
        let expectation5 = await settle(sut.execute(action: CustomWidgetAction(), entityId: "light.kitchen")) ==
            .rejected
        #expect(expectation5)
    }

    @Test(arguments: ["light.kitchen", "camera.porch", "sensor.temperature", "not_an_entity"])
    func everyEntityCanBeAddedToAWidget(entityId: String) async throws {
        let sut = EntityAddToHandler()
        let actions = try await withCheckedThrowingContinuation { continuation in
            sut.actionsForEntity(entityId: entityId).done { continuation.resume(returning: $0) }
                .catch { continuation.resume(throwing: $0) }
        }
        #expect(actions.contains { $0 is CustomWidgetAction })
        #expect(actions.contains { $0 is DeeplinkAction } == (Domain(entityId: entityId) != nil))
    }
}
