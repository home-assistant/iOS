import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import Testing
import UIKit

/// Every scene kind round-trips through its activity identifier and configuration name, builds the
/// activity and scene configuration it is opened with, and the scene manager's URL-open copy and
/// full-screen confirmation work on their own.
@MainActor
struct SceneActivityTests {
    @Test(arguments: SceneActivity.allCases)
    func roundTripsThroughItsIdentifiers(_ activity: SceneActivity) {
        #expect(SceneActivity(activityIdentifier: activity.activityIdentifier) == activity)
        #expect(SceneActivity(configurationName: activity.configurationName) == activity)

        let userActivity = activity.activity
        #expect(userActivity.activityType == activity.activityIdentifier)
        #expect(userActivity.targetContentIdentifier == activity.activityIdentifier)

        let withInfo = activity.activity(with: ["key": "value"])
        #expect(withInfo.activityType == activity.activityIdentifier)
        #expect(withInfo.targetContentIdentifier == activity.activityIdentifier)
        #expect(withInfo.userInfo?["key"] as? String == "value")

        let configuration = activity.configuration
        if activity == .carPlay {
            #expect(configuration.role == .carTemplateApplication)
        } else {
            #expect(configuration.role == .windowApplication)
        }
        if activity == .assist {
            #expect(
                configuration.delegateClass
                    .map(ObjectIdentifier.init) == ObjectIdentifier(AssistWindowSceneDelegate.self)
            )
        }
        #expect((activity.defaultMacWindowSize != nil) == (activity == .assist))
    }

    @Test func unknownIdentifiersFallBackToTheWebView() {
        #expect(SceneActivity(activityIdentifier: "ha.unknown") == .webView)
        #expect(SceneActivity(configurationName: "Unknown") == .webView)
        #expect(SceneActivity.assist.defaultMacWindowSize == CGSize(width: 400, height: 600))
    }

    @Test func openSourcesDescribeTheURL() {
        let url = "https://example.com/path"
        #expect(OpenSource.notification.message(with: url) == L10n.Alerts.OpenUrlFromNotification.message(url))
        #expect(OpenSource.deeplink.message(with: url) == L10n.Alerts.OpenUrlFromDeepLink.message(url))

        let notificationPrompt = OpenSource.notification.serverSelectPrompt(with: url)
        #expect(notificationPrompt.message == L10n.Alerts.OpenUrlFromNotification.selectServer)
        #expect(notificationPrompt.link == url)
        let deeplinkPrompt = OpenSource.deeplink.serverSelectPrompt(with: url)
        #expect(deeplinkPrompt.message == L10n.Alerts.OpenUrlFromDeepLink.selectServer)
        #expect(deeplinkPrompt.link == url)
    }

    @Test func fullScreenConfirmationShowsAHUDOnTheWindow() async throws {
        let manager = SceneManager()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        defer { window.isHidden = true }

        manager.showFullScreenConfirm(icon: .checkIcon, text: "Done", onto: .value(window))

        let deadline = Date().addingTimeInterval(10)
        while window.subviews.isEmpty, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!window.subviews.isEmpty)
        _ = manager.supportsMultipleScenes
    }
}
