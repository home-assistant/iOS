import AppIntents
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing
import UIKit
import WebKit

@MainActor
@Suite(.serialized)
struct WebViewControllerOnscreenContentTests {
    @Test("The activity is named after the panel the frontend is showing")
    func namesTheActivityAfterThePage() async throws {
        try await withExposureDatabase { _ in
            let activity = NSUserActivity(activityType: "test")

            await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                onscreenEntityId: nil,
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
    func fallsBackToTheServerName() async throws {
        try await withExposureDatabase { _ in
            let activity = NSUserActivity(activityType: "test")

            await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/history"),
                pageTitle: nil,
                serverName: "Kitchen",
                serverId: "1",
                onscreenEntityId: nil,
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == "Kitchen")
        }
    }

    /// The root URL is whichever panel the server made default, which the URL alone does not say, so
    /// the activity is left carrying nothing rather than a guess.
    @Test("A URL that names no panel publishes nothing")
    func publishesNothingWithoutAPanel() async throws {
        try await withExposureDatabase { _ in
            let activity = NSUserActivity(activityType: "test")

            await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/"),
                pageTitle: "Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                onscreenEntityId: nil,
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == nil)
            if #available(iOS 18.2, *) {
                #expect(activity.appEntityIdentifier == nil)
            }
        }
    }

    @Test("A web view with no URL yet publishes nothing")
    func publishesNothingWithoutAURL() async throws {
        try await withExposureDatabase { _ in
            let activity = NSUserActivity(activityType: "test")

            await WebViewController.publishOnscreenContent(
                onto: activity,
                url: nil,
                pageTitle: nil,
                serverName: "Kitchen",
                serverId: "1",
                onscreenEntityId: nil,
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == nil)
        }
    }

    @Test("A server hidden from Siri publishes a name but no identifier")
    func hiddenServerPublishesNoIdentifier() async throws {
        try await withExposureDatabase { _ in
            SiriServerExposure.setExposed(false, serverId: "1")
            let activity = NSUserActivity(activityType: "test")

            await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: "1",
                onscreenEntityId: nil,
                knownPanelPaths: ["lovelace", "history"]
            )

            #expect(activity.title == "Overview")
            if #available(iOS 18.2, *) {
                #expect(activity.appEntityIdentifier == nil)
            }
        }
    }

    /// The dialog is what the user is looking at, so a command saying "this" has to mean the entity
    /// it is showing rather than the dashboard behind it.
    @Test("An open more-info dialog takes the identifier over the page")
    func theDialogEntityWinsOverThePage() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withExposureDatabase { serverId in
            try seedEntity(entityId: "light.kitchen", serverId: serverId)
            let activity = NSUserActivity(activityType: "test")

            let identifiers = await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: serverId,
                onscreenEntityId: "light.kitchen",
                knownPanelPaths: ["lovelace", "history"]
            )

            // The page still names the activity: the dialog is drawn over it, not instead of it.
            #expect(activity.title == "Overview")
            let identifier = activity.appEntityIdentifier
            // "Turn this off" is the common ask for a light, so that command's type leads.
            #expect(identifier?.entityType == ControllableEntityAppEntity.self)
            #expect(identifier?.identifier == ServerEntity.uniqueId(serverId: serverId, entityId: "light.kitchen"))
            // The same identifiers go to the web view's elements, which is where a command whose
            // parameter takes another type — "dim this", for a light — finds the one it needs.
            #expect(identifiers.first == identifier)
            #expect(identifiers.map(\.entityType).contains { $0 == DimmableLightAppEntity.self })
        }
    }

    /// An entity Siri's own entity lists leave out has no identifier to publish, and the page it is
    /// shown over is a perfectly good answer to "this" in the meantime.
    @Test("An entity Siri cannot resolve falls back to the page")
    func anUnresolvableEntityFallsBackToThePage() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withExposureDatabase { serverId in
            let activity = NSUserActivity(activityType: "test")

            let identifiers = await WebViewController.publishOnscreenContent(
                onto: activity,
                url: URL(string: "https://example.com/lovelace/0"),
                pageTitle: "Overview – Home Assistant",
                serverName: "Kitchen",
                serverId: serverId,
                onscreenEntityId: "light.not_in_the_database",
                knownPanelPaths: ["lovelace", "history"]
            )

            let identifier = activity.appEntityIdentifier
            #expect(identifier?.entityType == PageAppEntity.self)
            #expect(identifiers.isEmpty)
        }
    }

    /// Drives the controller's own hook, which reads the URL and title off the web view it owns. A web
    /// view that has loaded nothing has no URL, so this is the "nothing to publish yet" path.
    @Test("The controller publishes from the web view it owns")
    func controllerPublishesFromItsWebView() async throws {
        try await withExposureDatabase { _ in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)

            sut.updateOnscreenContent()
            await sut.onscreenContentTask?.value

            #expect(sut.userActivity?.title == nil)
        }
    }

    /// The identifiers the activity cannot carry reach the system as elements of the web view, which
    /// is the only place more than one type fits.
    @Test("The identifiers become elements of the web view, and go away with them")
    func theIdentifiersBecomeWebViewElements() async throws {
        guard #available(iOS 18.4, *) else { return }
        try await withExposureDatabase { serverId in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))

            let identifiers = [
                EntityIdentifier(
                    for: HAAppEntityAppIntentEntity.self,
                    identifier: ServerEntity.uniqueId(serverId: serverId, entityId: "light.kitchen")
                ),
                EntityIdentifier(
                    for: OpenableEntityAppEntity.self,
                    identifier: ServerEntity.uniqueId(serverId: serverId, entityId: "cover.garage")
                ),
            ]

            sut.publishOnscreenEntityElements(identifiers)
            #expect(sut.webView.appEntityUIElementProvider != nil)

            // The web view is one opaque view, so every element takes its whole area.
            let elements = WebViewController.onscreenEntityElements(identifiers, bounds: sut.webView.bounds)
            #expect(elements.map(\.identifier) == identifiers)
            #expect(elements.allSatisfy { $0.bounds == sut.webView.bounds })

            // Nothing on screen leaves nothing to report, rather than the last thing that was.
            sut.publishOnscreenEntityElements([])
            #expect(sut.webView.appEntityUIElementProvider == nil)
        }
    }

    /// A close carries the entity it closed with so a late one cannot take down the entity that
    /// replaced it, which is what switching straight from one entity to another looks like.
    @Test("A close for another entity leaves the one on screen alone")
    func aStaleCloseLeavesTheCurrentEntityAlone() async throws {
        try await withExposureDatabase { _ in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)

            sut.setOnscreenEntity(entityId: "light.kitchen")
            sut.clearOnscreenEntity(entityId: "light.hallway")
            #expect(sut.onscreenEntityId == "light.kitchen")

            sut.clearOnscreenEntity(entityId: "light.kitchen")
            #expect(sut.onscreenEntityId == nil)
            await sut.onscreenContentTask?.value
        }
    }

    /// The frontend closes the dialog when it navigates and says so, but a missed message would leave
    /// Siri resolving "this" to something no longer on screen.
    @Test("Moving to another route forgets the entity, message or no message")
    func anotherRouteForgetsTheEntity() async throws {
        try await withExposureDatabase { _ in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)

            sut.setOnscreenEntity(entityId: "light.kitchen")
            #expect(sut.onscreenEntityId == "light.kitchen")

            // The web view has loaded nothing, so it is on no path; standing the dialog on one is what
            // makes the next publish see the frontend as having moved off it.
            sut.onscreenEntityPath = "/lovelace"
            sut.updateOnscreenContent()
            await sut.onscreenContentTask?.value

            #expect(sut.onscreenEntityId == nil)
            #expect(sut.onscreenEntityPath == nil)
        }
    }

    /// A new document means the dialog is gone, and the page that would have said so is the one being
    /// replaced. This is the reload case — pull to refresh — where the path never changes.
    @Test("Loading a new document forgets the entity that was on screen")
    func aNewDocumentForgetsTheEntity() async throws {
        try await withExposureDatabase { _ in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)

            sut.setOnscreenEntity(entityId: "light.kitchen")
            sut.forgetOnscreenEntity()

            #expect(sut.onscreenEntityId == nil)
            await sut.onscreenContentTask?.value
        }
    }

    /// Hiding a server from Siri has to take what is on screen off the activity now, rather than at
    /// the next navigation, which is what the observer is for.
    @Test("Changing the Siri exposure setting republishes what is on screen")
    func theSiriExposureSettingRepublishes() async throws {
        try await withExposureDatabase { _ in
            let sut = WebViewController(server: .fake())
            sut.setValue(UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 640)), forKey: "view")
            sut.webView = WKWebView(frame: .zero)
            sut.userActivity = NSUserActivity(activityType: "test")

            sut.observeSiriExposureForOnscreenContent()
            #expect(sut.siriExposureObserver != nil)

            NotificationCenter.default.post(name: .siriEntityExposureDidChange, object: nil)

            // The observer hands the work to a task of its own, so the publish it starts is what says
            // it fired.
            var waited = 0
            while sut.onscreenContentTask == nil, waited < 200 {
                try await Task.sleep(nanoseconds: 5_000_000)
                waited += 1
            }
            #expect(sut.onscreenContentTask != nil)
            await sut.onscreenContentTask?.value
        }
    }

    @Test("The panels a page can be on are the ones this server has")
    func knownPanelPathsComeFromTheServersPanels() async throws {
        try await withExposureDatabase { _ in
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

    /// The entity has to be somewhere Siri's own lists would find it, which means a row of its own and
    /// an area to sit in.
    private func seedEntity(entityId: String, serverId: String) throws {
        try Current.database().write { db in
            try HAAppEntity(
                id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
                entityId: entityId,
                serverId: serverId,
                domain: entityId.components(separatedBy: ".").first ?? "",
                name: "Kitchen",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db, onConflict: .replace)
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: [entityId],
                floorId: nil,
                floorName: nil
            ).insert(db, onConflict: .replace)
        }
    }

    /// Hands the closure the fake server's own identifier, which is what an entity has to be seeded
    /// under for the queries behind Siri's entity lists to find it.
    private func withExposureDatabase(perform work: (String) async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let database = try DatabaseQueue(path: ":memory:")

        try SiriServerExposureTable().createIfNeeded(database: database)
        try AppPanelTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }

        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        try await work(server.identifier.rawValue)
    }
}
