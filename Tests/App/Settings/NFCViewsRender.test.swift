import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the NFC and allowed-tag screens out, so SwiftUI evaluates each section they show with NFC
/// available or not, and with or without allowed tags stored.
@MainActor
@Suite(.serialized)
struct NFCViewsRenderTests {
    @Test func listOffersReadingAndWritingWhenNFCIsAvailable() {
        withTags(isNFCAvailable: true) { tags in
            render(NFCListView())
            #expect(tags.writtenValues.isEmpty)
        }
    }

    @Test func listExplainsWhenNFCIsUnavailable() {
        withTags(isNFCAvailable: false) { tags in
            render(NFCListView())
            #expect(tags.writtenValues.isEmpty)
        }
    }

    @Test func tagDetailShowsTheIdentifierActionsAndExampleTrigger() {
        withTags(isNFCAvailable: true) { tags in
            render(NFCTagView(identifier: "abc123-def456"))
            #expect(tags.writtenValues.isEmpty)
        }
    }

    @Test func yamlSheetRendersTheTrigger() {
        render(YamlCodeView(yaml: "- platform: tag\n  tag_id: abc123"))
    }

    @Test func tagsMenuRendersBothEntries() {
        render(TagsView())
        #expect(TagsView.settingsSearchEntries.map(\.title) == [L10n.Nfc.List.title, L10n.Tags.Allowed.title])
    }

    @Test func allowedTagsListsStoredTagsInOrder() throws {
        try withAllowedTags(["kitchen", "front-door"]) {
            #expect(AllowedTag.all().map(\.tag) == ["front-door", "kitchen"])
            render(AllowedTagsView())
        }
    }

    @Test func allowedTagsShowsItsEmptyState() throws {
        try withAllowedTags([]) {
            #expect(AllowedTag.all().isEmpty)
            render(AllowedTagsView())
        }
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withTags(isNFCAvailable: Bool, _ body: (MockTagManager) -> Void) {
        let previousTags = Current.tags
        defer { Current.tags = previousTags }
        let tags = MockTagManager()
        tags.isNFCAvailable = isNFCAvailable
        Current.tags = tags
        body(tags)
    }

    private func withAllowedTags(_ tags: [String], _ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        defer { Current.database = previousDatabase }

        let database = try DatabaseQueue()
        try AllowedTagTable().createIfNeeded(database: database)
        Current.database = { database }
        for tag in tags {
            AllowedTag.add(tag)
        }

        try body()
    }
}
