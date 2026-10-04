import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the Jinja editor screens out in each of the result states they show, so every branch of their
/// bodies is evaluated. Only plain-text and hex values are used: those render without a server.
@MainActor
final class JinjaTemplateViewsRenderTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var server: Server!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        previousServers = Current.servers

        let servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let serverId = server.identifier.rawValue
        try database.write { db in
            try HAAppEntity(
                id: "\(serverId)-light.kitchen",
                entityId: "light.kitchen",
                serverId: serverId,
                domain: "light",
                name: "Kitchen",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
            try HAAppEntity(
                id: "\(serverId)-light.office",
                entityId: "light.office",
                serverId: serverId,
                domain: "light",
                name: "Office",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db)
        }
        Current.database = { database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.servers = previousServers
        super.tearDown()
    }

    func testEditorSheetWithAnEmptyTemplate() {
        let text = TextBox("")
        let height = render(JinjaTemplateEditorSheet(server: server, title: "Name", text: text.binding))
        XCTAssertGreaterThan(height, 0)
        XCTAssertEqual(text.value, "", "nothing is committed without Done")
    }

    func testEditorSheetWithPlainText() {
        let text = TextBox("Kitchen is 'light.kitchen'")
        XCTAssertGreaterThan(render(JinjaTemplateEditorSheet(server: server, title: "Name", text: text.binding)), 0)
    }

    func testEditorSheetWithAValidColor() {
        let text = TextBox("#ff8800")
        let sheet = JinjaTemplateEditorSheet(server: server, title: "Color", text: text.binding, expectsColor: true)
        XCTAssertGreaterThan(render(sheet), 0)
    }

    func testEditorSheetWithAnInvalidColor() {
        let text = TextBox("orange")
        let sheet = JinjaTemplateEditorSheet(
            server: server,
            title: "Color",
            text: text.binding,
            placeholder: "#RRGGBB",
            expectsColor: true
        )
        XCTAssertGreaterThan(render(sheet), 0)
    }

    func testTemplateButtonStates() {
        XCTAssertGreaterThan(render(Form {
            JinjaTemplateButton(server: server, title: "Empty", text: .constant(""), placeholder: "{{ x }}")
            JinjaTemplateButton(server: server, title: "Plain", text: .constant("Hello"))
            JinjaTemplateButton(server: server, title: "Color", text: .constant("#00FF00"), expectsColor: true)
            JinjaTemplateButton(server: server, title: "Bad color", text: .constant("green"), expectsColor: true)
        }), 0)
    }

    func testSuggestionsView() {
        var selected: [String] = []
        var moreTapped = false
        let view = JinjaEntitySuggestionsView(
            items: [
                .init(
                    suggestion: .init(label: "light.kitchen", insertion: "light.kitchen"),
                    name: "Kitchen",
                    subtitle: "Ground floor"
                ),
                .init(
                    suggestion: .init(label: "light.office", insertion: "light.office"),
                    name: "Office",
                    subtitle: nil
                ),
            ],
            onSelect: { selected.append($0.label) },
            onMore: { moreTapped = true }
        )

        XCTAssertGreaterThan(render(view), 0)
        XCTAssertEqual(view.items.map(\.id), ["light.kitchenlight.kitchen", "light.officelight.office"])

        view.onSelect(view.items[0].suggestion)
        view.onMore()
        XCTAssertEqual(selected, ["light.kitchen"])
        XCTAssertTrue(moreTapped)
    }

    /// Lays the view out in a visible window (never the key one, so snapshot tests elsewhere are
    /// unaffected), lets `onAppear` work settle, and returns the height it fits in.
    private func render(_ view: some View) -> CGFloat {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.layoutIfNeeded()
        let height = controller.sizeThatFits(in: CGSize(width: 390, height: 844)).height

        window.isHidden = true
        window.rootViewController = nil
        return height
    }

    private final class TextBox {
        var value: String

        init(_ value: String) {
            self.value = value
        }

        var binding: Binding<String> {
            Binding(get: { self.value }, set: { self.value = $0 })
        }
    }
}
