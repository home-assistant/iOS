import AppIntents
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit
import WebKit

@MainActor
@Suite(.serialized)
struct WebViewControllerOnscreenPageTests {
    @Test("The activity is named after the panel the frontend is showing")
    func namesTheActivityAfterThePage() throws {
        try withExposureDatabase {
            let activity = NSUserActivity(activityType: "test")

            WebViewController.publishOnscreenPage(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == "Overview")
            if #available(iOS 18.2, *) {
                #expect(activity.appEntityIdentifier != nil)
            }
        }
    }

    /// A page that has not set a title yet still names the activity, after the server, exactly as it
    /// names the window.
    @Test("A page with no title of its own falls back to the server's name")
    func fallsBackToTheServerName() throws {
        try withExposureDatabase {
            let activity = NSUserActivity(activityType: "test")

            WebViewController.publishOnscreenPage(
                onto: activity,
                url: URL(string: "https://example.com/history"),
                pageTitle: nil,
                serverName: "Kitchen",
                serverId: "1",
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == "Kitchen")
        }
    }

    /// The root URL is whichever panel the server made default, which the URL alone does not say, so
    /// the activity is left carrying nothing rather than a guess.
    @Test("A URL that names no panel publishes nothing")
    func publishesNothingWithoutAPanel() throws {
        try withExposureDatabase {
            let activity = NSUserActivity(activityType: "test")

            WebViewController.publishOnscreenPage(
                onto: activity,
                url: URL(string: "https://example.com/"),
                pageTitle: "Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == nil)
            if #available(iOS 18.2, *) {
                #expect(activity.appEntityIdentifier == nil)
            }
        }
    }

    @Test("A web view with no URL yet publishes nothing")
    func publishesNothingWithoutAURL() throws {
        try withExposureDatabase {
            let activity = NSUserActivity(activityType: "test")

            WebViewController.publishOnscreenPage(
                onto: activity,
                url: nil,
                pageTitle: nil,
                serverName: "Kitchen",
                serverId: "1",
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == nil)
        }
    }

    @Test("A server hidden from Siri publishes a name but no identifier")
    func hiddenServerPublishesNoIdentifier() throws {
        try withExposureDatabase {
            SiriServerExposure.setExposed(false, serverId: "1")
            let activity = NSUserActivity(activityType: "test")

            WebViewController.publishOnscreenPage(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == "Overview")
            if #available(iOS 18.2, *) {
                #expect(activity.appEntityIdentifier == nil)
            }
        }
    }

    /// Drives the controller's own hook, which reads the URL and title off the web view it owns. A web
    /// view that has loaded nothing has no URL, so this is the "nothing to publish yet" path.
    @Test("The controller publishes from the web view it owns")
    func controllerPublishesFromItsWebView() throws {
        try withExposureDatabase {
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)

            sut.updateOnscreenPage()

            #expect(sut.userActivity?.title == nil)
        }
    }

    @Test("The panels a page can be on are the ones this server has")
    func knownPanelPathsComeFromTheServersPanels() throws {
        try withExposureDatabase {
            try Current.database().write { db in
                try AppPanel(
                    id: "1-lovelace",
                    serverId: "1",
                    icon: nil,
                    title: "Overview",
                    path: "lovelace",
                    component: "lovelace",
                    showInSidebar: true
                ).insert(db, onConflict: .replace)
            }

            #expect(WebViewController.knownPanelPaths(serverId: "1") == ["lovelace"])
            #expect(WebViewController.knownPanelPaths(serverId: "2").isEmpty)
        }
    }

    private func withExposureDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        try SiriServerExposureTable().createIfNeeded(database: database)
        try AppPanelTable().createIfNeeded(database: database)
        Current.database = { database }

        defer { Current.database = previousDatabase }

        try work()
    }
}
