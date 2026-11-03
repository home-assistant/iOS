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

/// Renders the Jinja editor sheet through each result state (placeholder, plain text, color swatch,
/// invalid color, loading, server result and server error), with known entities turned into pills,
/// and commits or discards the draft from the toolbar.
///
/// `.sharedState`: the sheet's renderer looks its API up through `Current.api(for:)` from a timer on
/// the main run loop, and its entities come from `Current.database`, so both are swapped globally.
@Suite(.sharedState)
@MainActor
struct JinjaTemplateEditorSheetTests {
    private final class TextBox {
        var text: String
        init(_ text: String) { self.text = text }
        var binding: Binding<String> {
            Binding(get: { self.text }, set: { self.text = $0 })
        }
    }

    private func entity(_ serverId: String, _ entityId: String, _ name: String) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }

    private func withWorld(_ body: (Server, HAMockConnection) async throws -> Void) async throws {
        let previousServers = Current.servers
        let manager = FakeServerManager(initial: 1)
        let server = manager.all[0]
        let serverId = server.identifier.rawValue
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        Current.servers = manager
        defer {
            Current.resetAPICache(for: [server.identifier])
            Current.servers = previousServers
        }
        try await SettingsTestDatabase.with({ db in
            try entity(serverId, "light.kitchen", "Kitchen").insert(db)
            try entity(serverId, "light.kitchen_island", "Kitchen Island").insert(db)
            try entity(serverId, "sensor.solar", "Solar").insert(db)
        }) { _ in
            try await body(server, connection)
        }
    }

    private func show(
        _ server: Server,
        _ box: TextBox,
        expectsColor: Bool = false
    ) async -> SwiftUIScreenDriver {
        await SwiftUIScreenDriver.show(
            JinjaTemplateEditorSheet(
                server: server,
                title: "Template",
                text: box.binding,
                expectsColor: expectsColor
            ),
            size: CGSize(width: 390, height: 844),
            inNavigationStack: false
        )
    }

    private func close(_ driver: SwiftUIScreenDriver) {
        for textView in driver.views(of: UITextView.self) {
            textView.resignFirstResponder()
        }
        driver.close()
    }

    @Test(arguments: ["", "Just text"])
    func rendersLocalResults(_ text: String) async throws {
        try await withWorld { server, _ in
            let box = TextBox(text)
            let driver = await show(server, box)
            defer { close(driver) }
            await driver.settle()
            #expect(driver.views(of: UITextView.self).count == 1)
            #expect(box.text == text)
        }
    }

    @Test(arguments: ["#FF0000", "not a color"])
    func rendersColorResults(_ text: String) async throws {
        try await withWorld { server, _ in
            let box = TextBox(text)
            let driver = await show(server, box, expectsColor: true)
            defer { close(driver) }
            await driver.settle()
            #expect(driver.views(of: UITextView.self).count == 1)
        }
    }

    @Test func rendersTheServerResultAndErrors() async throws {
        try await withWorld { server, connection in
            let box = TextBox("{{ states('light.kitchen') }}")
            let driver = await show(server, box)
            defer { close(driver) }

            // The known entity id is shown as a pill.
            let textView = try #require(driver.views(of: UITextView.self).first)
            await #expect(driver.waitUntil { textView.attributedText.string.contains("\u{FFFC}") })

            try await #require(driver.waitUntil { !connection.pendingSubscriptions.isEmpty })
            let subscription = try #require(connection.pendingSubscriptions.last)
            subscription.handler(subscription.cancellable, HAData(value: ["result": "on"]))
            await driver.settle()
            subscription.handler(subscription.cancellable, HAData(value: ["result": ""]))
            await driver.settle()
            subscription.handler(subscription.cancellable, HAData(value: ["error": "Bad template"]))
            await driver.settle()
            #expect(box.text == "{{ states('light.kitchen') }}")
        }
    }

    @Test func colorTemplatesFromTheServerShowASwatch() async throws {
        try await withWorld { server, connection in
            let box = TextBox("{{ '#00FF00' }}")
            let driver = await show(server, box, expectsColor: true)
            defer { close(driver) }

            try await #require(driver.waitUntil { !connection.pendingSubscriptions.isEmpty })
            let subscription = try #require(connection.pendingSubscriptions.last)
            subscription.handler(subscription.cancellable, HAData(value: ["result": "#00FF00"]))
            await driver.settle()
            subscription.handler(subscription.cancellable, HAData(value: ["result": "green-ish"]))
            await driver.settle()
        }
    }

    @Test func typingAnEntityPrefixOffersSuggestions() async throws {
        try await withWorld { server, _ in
            let text = "{{ states('light.kit"
            let box = TextBox(text)
            let driver = await show(server, box)
            defer { close(driver) }
            let textView = try #require(driver.views(of: UITextView.self).first)
            let coordinator = try #require(textView.delegate as? JinjaTextEditor.Coordinator)

            // Move the cursor to the end of the typed prefix, as the user typing would.
            textView.selectedRange = NSRange(location: (text as NSString).length, length: 0)
            coordinator.textViewDidChangeSelection(textView)
            await driver.settle(5)

            // Completing the id turns it into a pill.
            textView.textStorage.append(NSAttributedString(string: "chen') }}"))
            coordinator.textViewDidChange(textView)
            await #expect(driver.waitUntil { textView.attributedText.string.contains("\u{FFFC}") })
        }
    }

    @Test func doneCommitsTheDraftAndCancelDiscardsIt() async throws {
        try await withWorld { server, _ in
            let box = TextBox("Original")
            let driver = await show(server, box)
            defer { close(driver) }
            let textView = try #require(driver.views(of: UITextView.self).first)
            let coordinator = try #require(textView.delegate as? JinjaTextEditor.Coordinator)

            textView.textStorage.append(NSAttributedString(string: " edited"))
            coordinator.textViewDidChange(textView)
            await driver.settle()

            await #expect(driver.tapBarButton(titled: L10n.cancelLabel))
            #expect(box.text == "Original")
            await #expect(driver.tapBarButton(titled: L10n.doneLabel))
            #expect(box.text == "Original edited")
        }
    }
}
