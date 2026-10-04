import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the complication builder out at each step of its flow — no source yet, the entity step before an
/// entity is picked, and a configured template complication with several servers (which reveals the
/// server picker, the template rows and the Customize row). Templates are plain text and no entity is
/// picked, so the live preview never fetches from a server.
@MainActor
@Suite(.serialized)
struct WatchComplicationBuilderEditViewRenderTests {
    @Test func rendersANewComplication() throws {
        try withWorld(serverCount: 1) { _ in
            #expect(render(NavigationView { WatchComplicationBuilderEditView(existing: nil) }))
        }
    }

    @Test func rendersTheEntityStepBeforeAnEntityIsPicked() throws {
        try withWorld(serverCount: 1) { serverId in
            let config = WatchComplicationConfig(serverId: serverId, widgetFamily: .corner, name: "Pending")
            #expect(render(NavigationView { WatchComplicationBuilderEditView(existing: config) }))
        }
    }

    @Test func rendersAConfiguredTemplateComplicationWithSeveralServers() throws {
        try withWorld(serverCount: 2) { serverId in
            let config = WatchComplicationConfig(
                serverId: serverId,
                widgetFamily: .rectangular,
                kind: .customTemplate,
                name: "Solar",
                iconName: "mdi:solar-power",
                iconColor: "#FFD60A",
                customTextTemplate: "Solar",
                customGaugeTemplate: "0.4",
                customTextColorTemplate: "#FF9500"
            )
            let viewModel = WatchComplicationBuilderEditViewModel(existing: config)
            #expect(viewModel.isSourceConfigured)
            #expect(viewModel.servers.count == 2)
            #expect(render(NavigationView { WatchComplicationBuilderEditView(existing: config) }))
        }
    }

    @Test func straightQuotedReplacesSmartPunctuation() {
        var stored = ""
        let binding = Binding(get: { stored }, set: { stored = $0 }).straightQuoted()

        binding.wrappedValue = "{{ states(\u{201C}sensor.x\u{201D}) }} \u{2018}a\u{2019}"

        #expect(stored == "{{ states(\"sensor.x\") }} 'a'")
        #expect(binding.wrappedValue == stored)
    }

    // MARK: - Helpers

    private func withWorld(serverCount: Int, _ work: (String) throws -> Void) throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        let servers = FakeServerManager(initial: serverCount)
        Current.database = { database }
        Current.servers = servers
        try work(servers.all.first?.identifier.rawValue ?? "")
    }

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 2400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
