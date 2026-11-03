import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Walks the NFC screens with a scripted tag manager: reading and writing a tag leads to its detail
/// screen, whose rows copy, share, duplicate and fire it.
/// Shared state: swaps `Current.tags` and `Current.database`, read from the main run loop.
@Suite(.sharedState)
@MainActor
struct NFCViewsRenderTests {
    @Test func readingATagOpensItsDetail() async throws {
        try await withTags(ScriptedTagManager(read: .value("front-door"))) { tags in
            let driver = await SwiftUIScreenDriver.show(NFCListView())
            defer { driver.close() }
            // Description, then read / write.
            #expect(driver.rowCount(inSection: 1) == 2)
            await driver.tapRow(IndexPath(item: 0, section: 1))
            let reached1 = await driver.waitUntil { driver.depth == 2 }
            #expect(reached1)

            // Every row of the detail: copy, YAML, share, duplicate, fire, example trigger.
            for indexPath in driver.rows {
                await driver.tapRow(indexPath)
                if await driver.waitUntil(timeout: 1, { driver.presented != nil }) {
                    await driver.dismissPresented()
                }
            }
            #expect(tags.written.contains("front-door"))
            #expect(tags.fired.contains("front-door"))
        }
    }

    @Test func writingARandomOrManualTagOpensItsDetail() async throws {
        try await withTags(ScriptedTagManager(read: .value("unused"))) { tags in
            let driver = await SwiftUIScreenDriver.show(NFCListView())
            defer { driver.close() }

            await driver.tapRow(IndexPath(item: 1, section: 1))
            let reached2 = await driver.waitUntil { driver.alert != nil }
            #expect(reached2)
            await driver.tapAlertButton(L10n.Nfc.Write.IdentifierChoice.random)
            let reached3 = await driver.waitUntil { driver.depth == 2 }
            #expect(reached3)
            #expect(tags.written.count == 1)
            await driver.popToRoot()

            await driver.tapRow(IndexPath(item: 1, section: 1))
            let reached4 = await driver.waitUntil { driver.alert != nil }
            #expect(reached4)
            await driver.tapAlertButton(L10n.Nfc.Write.IdentifierChoice.manual)
            let reached5 = await driver.waitUntil { driver.alert?.textFields?.isEmpty == false }
            #expect(reached5)
            driver.alert?.textFields?.first?.text = "manual-tag"
            driver.alert?.textFields?.first?.sendActions(for: .editingChanged)
            await driver.settle()
            await driver.tapAlertButton(L10n.doneLabel)
            let reached6 = await driver.waitUntil { tags.written.contains("manual-tag") }
            #expect(reached6)
        }
    }

    @Test func aFailedReadShowsTheError() async throws {
        try await withTags(ScriptedTagManager(read: .init(error: TagManagerError.notHomeAssistantTag))) { _ in
            let driver = await SwiftUIScreenDriver.show(NFCListView())
            defer { driver.close() }
            await driver.tapRow(IndexPath(item: 0, section: 1))
            let reached7 = await driver.waitUntil { driver.alert != nil }
            #expect(reached7)
            await driver.tapAlertButton()
            #expect(driver.depth == 1)
        }
    }

    @Test func withoutNFCTheListSaysSo() async throws {
        try await withTags(ScriptedTagManager(read: .value("x"), isNFCAvailable: false)) { _ in
            let driver = await SwiftUIScreenDriver.show(NFCListView())
            defer { driver.close() }
            #expect(driver.rowCount(inSection: 1) == 1)
        }
    }

    @Test func tagsLeadToTheListAndTheAllowedTags() async throws {
        try await withTags(ScriptedTagManager(read: .value("x"))) { _ in
            AllowedTag.add("front-door")
            AllowedTag.add("garage")
            let driver = await SwiftUIScreenDriver.show(TagsView())
            defer { driver.close() }
            let reached8 = await driver.push(IndexPath(item: 0, section: 0))
            #expect(reached8)
            await driver.pop()
            let reached9 = await driver.push(IndexPath(item: 1, section: 0))
            #expect(reached9)
            let reached10 = await driver.waitUntil { driver.rowCount(inSection: 0) == 2 }
            #expect(reached10)

            // "Delete all" only asks, through a confirmation dialog: SwiftUI presents it through UIKit,
            // which an off-screen window doesn't reliably do, so the test doesn't wait for it.
            await driver.tapRow(IndexPath(item: 0, section: 1))
            #expect(AllowedTag.all().count == 2)
        }
    }

    /// "Delete all" in the toolbar only asks for confirmation; nothing is deleted yet.
    @Test func deleteAllInTheToolbarOnlyAsks() async throws {
        try await withTags(ScriptedTagManager(read: .value("x"))) { _ in
            AllowedTag.add("front-door")
            let driver = await SwiftUIScreenDriver.show(AllowedTagsView())
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 1 })

            let pressed = await driver.tapBarButton(titled: L10n.Tags.Allowed.deleteAll)
            #expect(pressed)
            #expect(AllowedTag.all().count == 1)
        }
    }

    /// The YAML sheet's toolbar copies the YAML and closes.
    @Test func theYAMLViewCopiesItsYAML() async throws {
        let pasteboard = UIPasteboard.general
        let previous = pasteboard.string
        defer { pasteboard.string = previous ?? "" }

        let yaml = "tag_id: front-door"
        let driver = await SwiftUIScreenDriver.show(YamlCodeView(yaml: yaml), inNavigationStack: false)
        defer { driver.close() }

        for index in driver.barButtons.indices {
            await driver.tapBarButton(index)
        }
        #expect(pasteboard.string == yaml)
    }

    private func withTags(
        _ tags: ScriptedTagManager,
        _ body: (ScriptedTagManager) async throws -> Void
    ) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousTags = Current.tags
        let previousDatabase = Current.database
        Current.tags = tags
        Current.database = { database }
        defer {
            Current.tags = previousTags
            Current.database = previousDatabase
        }
        try await body(tags)
    }
}

private final class ScriptedTagManager: TagManager {
    let isNFCAvailable: Bool
    private let read: Promise<String>
    private(set) var written: [String] = []
    private(set) var fired: [String] = []

    init(read: Promise<String>, isNFCAvailable: Bool = true) {
        self.read = read
        self.isNFCAvailable = isNFCAvailable
    }

    func readNFC() -> Promise<String> {
        read
    }

    func writeNFC(value: String) -> Promise<String> {
        written.append(value)
        return .value(value)
    }

    func writeNFC(deeplink: URL, alertMessage: String) -> Promise<Void> {
        .value(())
    }

    func handle(userActivity: NSUserActivity) -> TagManagerHandleResult {
        .unhandled
    }

    func fireEvent(tag: String) -> Promise<Void> {
        fired.append(tag)
        return .value(())
    }
}
