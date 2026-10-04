import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the legacy complication editor out for templates exercising each optional section: text areas
/// with the gauge (and a forced gauge type), the column-2 alignment picker, the ring with the icon
/// picker, and the server picker shown with several servers. Template text is plain, so the live
/// previews render locally instead of subscribing to a server.
@MainActor
@Suite(.serialized)
struct ComplicationEditViewRenderTests {
    @Test func rendersAGaugeTemplateWithTextAreas() throws {
        try withWorld(serverCount: 2) {
            let config = WatchComplication(
                family: .graphicCircular,
                template: .GraphicCircularOpenGaugeRangeText,
                data: [
                    "gauge": ["gauge": "0.5", "gauge_color": "#FF0000"],
                    "textAreas": ["Center": ["text": "Middle", "color": "#00FF00"]],
                ],
                name: "Gauge"
            )
            #expect(render(NavigationView { ComplicationEditView(config: config, isNew: false, onSaved: nil) }))
        }
    }

    @Test func rendersAColumnsTemplateWithAlignment() throws {
        try withWorld(serverCount: 1) {
            let config = WatchComplication(
                family: .modularLarge,
                template: .ModularLargeColumns,
                data: ["column2alignment": ["column2alignment": "trailing"]]
            )
            #expect(render(NavigationView { ComplicationEditView(config: config, isNew: true, onSaved: {}) }))
        }
    }

    @Test func rendersARingTemplateWithAnIcon() throws {
        try withWorld(serverCount: 1) {
            let config = WatchComplication(
                family: .circularSmall,
                template: .CircularSmallRingImage,
                data: [
                    "ring": ["ring_value": "0.3", "ring_type": "closed"],
                    "icon": ["icon": "home", "icon_color": "#FFFFFF"],
                ]
            )
            #expect(render(NavigationView { ComplicationEditView(config: config, isNew: false, onSaved: nil) }))
        }
    }

    @Test func rendersARectangularGaugeTemplate() throws {
        try withWorld(serverCount: 1) {
            let config = WatchComplication(family: .graphicRectangular, template: .GraphicRectangularTextGauge)
            #expect(render(NavigationView { ComplicationEditView(config: config, isNew: true, onSaved: nil) }))
        }
    }

    // MARK: - Helpers

    private func withWorld(serverCount: Int, _ work: () throws -> Void) throws {
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
        Current.database = { database }
        Current.servers = FakeServerManager(initial: serverCount)
        try work()
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
