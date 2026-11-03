import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Shared state: the editor reads `Current.servers` and `Current.database`, and its template
/// previews look their API up through `Current.api(for:)` from the main run loop.
@Suite(.sharedState)
@MainActor
struct ComplicationEditViewRenderTests {
    private static let filledData: [String: Any] = [
        "column2alignment": ["column2alignment": "trailing"],
        "gauge": ["gauge": "{{ 0.5 }}", "gauge_color": "#ff0000", "gauge_type": "open", "gauge_style": "fill"],
        "ring": ["ring_value": "0.25", "ring_color": "#00ff00", "ring_type": "closed"],
        "icon": ["icon": "lightbulb", "icon_color": "#0000ff"],
        "textAreas": Dictionary(uniqueKeysWithValues: ComplicationTextAreas.allCases.map {
            ($0.slug, ["text": "Text \($0.slug)", "color": "#ffffff"])
        }),
    ]

    /// Every family and template, so each optional section (text areas, column alignment, gauge, ring,
    /// icon) is laid out at least once.
    @Test func rendersEveryTemplate() async throws {
        try await withWorld { servers, _ in
            for family in ComplicationGroupMember.allCases {
                for template in family.templates {
                    let config = WatchComplication(
                        serverIdentifier: servers[0].identifier.rawValue,
                        family: family,
                        template: template,
                        data: Self.filledData,
                        name: "\(template.rawValue)"
                    )
                    try await showing(ComplicationEditView(config: config, isNew: false, onSaved: nil)) { driver in
                        #expect(driver.sectionCount > 1, "\(template.rawValue) rendered no sections")
                    }
                }
            }
        }
    }

    @Test func newComplicationRendersEmptyAndPicksATemplate() async throws {
        try await withWorld { _, _ in
            let config = WatchComplication(family: .graphicCircular, template: .GraphicCircularOpenGaugeImage)
            var saved = 0
            try await showing(ComplicationEditView(config: config, isNew: true, onSaved: { saved += 1 })) { driver in
                // Name, server picker, template link, public toggle.
                #expect(driver.rowCount(inSection: 0) == 4)
                await #expect(driver.push(IndexPath(item: 2, section: 0)))
                #expect(driver.rowCount(inSection: 0) == ComplicationGroupMember.graphicCircular.templates.count)
                await driver.tapRow(IndexPath(item: 1, section: 0))
                await driver.popToRoot()

                await driver.toggleSwitches()
                await driver.type("{{ 0.75 }}")
                await driver.selectSegment(1)
                #expect(saved == 0)
            }
        }
    }

    /// The template previews show what the server renders, checked as a percentile or as text; Save
    /// stores the complication and reports back (or closes the editor), and Delete only asks.
    @Test func previewsRenderThenSaveAndDelete() async throws {
        try await withWorld { servers, database in
            let config = WatchComplication(
                serverIdentifier: servers[0].identifier.rawValue,
                family: .graphicCircular,
                template: .GraphicCircularOpenGaugeImage,
                data: Self.filledData,
                name: "Gauge"
            )
            var saved = 0
            try await showing(ComplicationEditView(config: config, isNew: false, onSaved: { saved += 1 })) { driver in
                let connection = try #require(Current.api(for: servers[0])?.connection as? HAMockConnection)
                await #expect(driver.waitUntil { !connection.pendingSubscriptions.isEmpty })
                for result in ["0.5", "not a number", "Text"] {
                    for subscription in connection.pendingSubscriptions {
                        subscription.handler(subscription.cancellable, HAData(value: ["result": result]))
                    }
                    await driver.settle()
                }

                let pressed = await driver.tapBarButton(titled: L10n.saveLabel)
                #expect(pressed)
                #expect(saved == 1)
                let stored = try await database.read { db in try WatchComplication.fetchCount(db) }
                #expect(stored == 1)

                let last = driver.sectionCount - 1
                await driver.tapRow(IndexPath(item: 0, section: last))
                await driver.dismissPresented()
                connection.pendingSubscriptions.removeAll()
                connection.pendingRequests.removeAll()
            }
        }
    }

    /// Without an `onSaved` handler, Save closes the editor itself.
    @Test func savingWithoutAHandlerCloses() async throws {
        try await withWorld { servers, database in
            let config = WatchComplication(
                serverIdentifier: servers[0].identifier.rawValue,
                family: .modularSmall,
                template: .ModularSmallSimpleText,
                data: Self.filledData,
                name: "Small"
            )
            try await showing(ComplicationEditView(config: config, isNew: true, onSaved: nil)) { driver in
                await driver.tapBarButton(titled: L10n.saveLabel)
            }
            let stored = try await database.read { db in try WatchComplication.fetchCount(db) }
            #expect(stored == 1)
        }
    }

    /// The editors a test has shown, so its world can outlive them (see `showing`).
    @MainActor
    private final class ShownEditors {
        private var objects: [() -> AnyObject?] = []

        /// The hosting controller and its view, which owns the SwiftUI graph that evaluates bodies.
        func add(_ host: UIViewController) {
            objects.append { [weak host] in host }
            if let view = host.viewIfLoaded {
                objects.append { [weak view] in view }
            }
        }

        var allReleased: Bool {
            objects.allSatisfy { $0() == nil }
        }
    }

    private let shown = ShownEditors()

    /// Shows `view` for `body`, then closes it; `withWorld` waits until SwiftUI has let go of it
    /// before putting the app's own world back.
    ///
    /// Closing the window queues a SwiftUI transaction that evaluates the editor's body again on a
    /// later run-loop turn, and the editor's sections force-unwrap `Current.servers.all.first`:
    /// evaluated after `withWorld` had put the app's empty server list back, that crashed the host.
    private func showing(
        _ view: ComplicationEditView,
        _ body: (SwiftUIScreenDriver) async throws -> Void
    ) async throws {
        let driver = await SwiftUIScreenDriver.show(view)
        shown.add(driver.host)
        defer { driver.close() }
        try await body(driver)
    }

    private func withWorld(_ body: ([Server], DatabaseQueue) async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let servers = FakeServerManager(initial: 2)
        for server in servers.all {
            let api = HomeAssistantAPI(server: server)
            api.connection = HAMockConnection()
            Current.setCachedApi(api, for: server.identifier)
        }
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.resetAPICache(for: servers.all.map(\.identifier))
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        var failure: Error?
        do {
            try await body(servers.all, database)
        } catch {
            failure = error
        }
        let released = await LoadTolerantDeadline.waitUntil { shown.allReleased }
        #expect(released, "SwiftUI still holds an editor")
        if let failure {
            throw failure
        }
    }
}
