@testable import HomeAssistant

import Shared
import SharedTesting

import SwiftUI
import Testing

/// A widget tile is tapped in two places now, so its customization screen offers two behaviors: what
/// a tap on the tile does, and what a tap on its icon does. Everywhere else a magic item is used
/// there is still only one thing to tap.
@MainActor
@Suite(.sharedState)
struct MagicItemCustomizationViewTests {
    @Test func widgetOffersTapAndIconTapBehaviors() {
        assertSnapshots(context: .widget, item: .init(id: "light.kitchen", serverId: "1", type: .entity))
    }

    /// The behavior that needs more than a name — a navigation path — brings its own row along, for
    /// either half of the tile.
    @Test func widgetShowsTheDetailsATapBehaviorNeeds() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .navigate("/lovelace/0")
        item.action = .moreInfoDialog
        assertSnapshots(context: .widget, item: item)
    }

    /// An app icon shortcut is a single action — there is no tile, so there is no second half.
    @Test func appIconShortcutKeepsASingleBehavior() {
        assertSnapshots(
            context: .appIconShortcut,
            item: .init(id: "script.morning", serverId: "1", type: .script)
        )
    }

    /// "Perform action" needs two things a name can't carry: which action to call, and the data to
    /// send with it. With no server reachable the picker reads the stored id as a name — never the
    /// raw `domain.service` pair — which is what the screen shows before the servers answer.
    @Test func widgetShowsThePerformActionRows() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .performAction("1", "light.turn_on", "{\"brightness_pct\": 60}")
        assertSnapshots(context: .widget, item: item)
    }

    /// An action chosen but not yet given any data leaves the payload field on its placeholder, with
    /// the footer explaining what belongs there.
    @Test func widgetShowsThePerformActionRowsWithoutData() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.action = .performAction("1", "light.toggle", "")
        assertSnapshots(context: .widget, item: item)
    }

    /// The one behavior that points outside Home Assistant brings a single field along.
    @Test func widgetShowsTheUrlRow() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .url("https://www.home-assistant.io/docs")
        assertSnapshots(context: .widget, item: item)
    }

    /// A shortcut has one behavior, so "perform action" fills the whole section on its own.
    @Test func appIconShortcutShowsThePerformActionRows() {
        var item = MagicItem(id: "script.morning", serverId: "1", type: .script)
        item.action = .performAction("1", "notify.persistent_notification", "{\"message\": \"Good morning\"}")
        assertSnapshots(context: .appIconShortcut, item: item)
    }

    /// A behavior that needs nothing else — the frontend's "toggle" — adds no rows, so the section
    /// stays as short as the default does.
    @Test func widgetShowsNoExtraRowsForToggle() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .toggle
        item.action = .toggle
        assertSnapshots(context: .widget, item: item)
    }

    /// An entity whose icon isn't a control on the frontend's tile card — a sensor — names "More
    /// info" as the default for both halves of the tile, since there is nothing for its icon to run.
    @Test func widgetNamesMoreInfoAsTheDefaultForAnEntityThatCannotToggle() {
        assertSnapshots(context: .widget, item: .init(id: "sensor.temperature", serverId: "1", type: .entity))
    }

    /// An automation's own behavior is "Trigger", and it reads that way on the row once chosen.
    @Test func widgetNamesAnAutomationsOwnBehaviorTrigger() {
        var item = MagicItem(id: "automation.night", serverId: "1", type: .entity)
        item.action = .mainAction
        assertSnapshots(context: .widget, item: item)
    }

    /// A lock's explicit behaviors are named in its own words, "Lock" and "Unlock", and the chosen
    /// one reads that way on the row.
    @Test func widgetNamesALocksOnOffBehaviorsAsLockAndUnlock() {
        var item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)
        item.action = .turnOff
        assertSnapshots(context: .widget, item: item)
    }

    /// With no color chosen the icon color reads "Default" — the entity keeps the color the frontend
    /// gives it for its state — and there is no color to pick.
    @Test func iconColorDefaultsToTheEntityColor() {
        assertSnapshots(context: .carPlay, item: .init(id: "light.kitchen", serverId: "1", type: .entity))
    }

    /// "Custom" fixes the icon to a color, which the row below it picks.
    @Test func iconColorCustomShowsTheColorToPick() {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(iconColor: "#FF9800", iconColorIsCustomized: true)
        )
        assertSnapshots(context: .carPlay, item: item)
    }

    /// The tint older versions wrote into an item just by opening this screen was never a choice, so
    /// the item reads "Default".
    @Test func iconColorSeededByTheAppReadsAsDefault() {
        let item = MagicItem(
            id: "light.kitchen",
            serverId: "1",
            type: .entity,
            customization: .init(iconColor: "00AEF8")
        )
        assertSnapshots(context: .carPlay, item: item)
    }

    // MARK: - Driving the editor

    /// Custom colors and the confirmation switch write into the item, the name field falls back to
    /// the entity's name when cleared, and the toolbar button hands the edited item back.
    @Test func editingAWidgetItemHandsItBack() async throws {
        let previousProvider = Current.magicItemProvider
        Current.magicItemProvider = { MagicItemCustomizationMagicItemProvider() }
        defer { Current.magicItemProvider = previousProvider }

        var saved: [MagicItem] = []
        let driver = await SwiftUIScreenDriver.show(MagicItemCustomizationView(
            mode: .add,
            context: .widget,
            // Without a customization, the screen gives the item one to edit.
            item: .init(id: "light.kitchen", serverId: "1", type: .entity, customization: nil)
        ) { saved.append($0) })
        defer { driver.close() }

        await driver.toggleSwitches()
        await driver.type("  ")
        await driver.type("Desk lamp")
        let pressed = await driver.tapBarButton(titled: L10n.MagicItem.add)
        #expect(pressed)
        let item = try #require(saved.last)
        #expect(item.displayText == "Desk lamp")
        #expect(item.customization?.backgroundColor != nil)
        #expect(item.customization?.requiresConfirmation == true)

        await driver.toggleSwitches()
        await driver.tapBarButton(titled: L10n.MagicItem.add)
        #expect(saved.last?.customization?.backgroundColor == nil)
    }

    /// An Assist pipeline shows the microphone instead of an icon picker, and on the watch it never
    /// asks for confirmation.
    @Test(arguments: [nil, "#FF9800"])
    func assistOnTheWatchSkipsConfirmation(iconColor: String?) async throws {
        let previousProvider = Current.magicItemProvider
        Current.magicItemProvider = { MagicItemCustomizationMagicItemProvider() }
        defer { Current.magicItemProvider = previousProvider }

        var saved: [MagicItem] = []
        let item = MagicItem(
            id: "pipeline",
            serverId: "1",
            type: .assistPipeline,
            customization: .init(iconColor: iconColor, requiresConfirmation: true)
        )
        let driver = await SwiftUIScreenDriver.show(
            MagicItemCustomizationView(mode: .edit, context: .watch, item: item) { saved.append($0) }
        )
        defer { driver.close() }

        await driver.tapBarButton(titled: L10n.MagicItem.edit)
        #expect(saved.last?.customization?.requiresConfirmation == false)
    }

    /// `Current` is a shared global, so the mocked provider is put back as soon as the snapshot is
    /// taken — left in place it would follow whichever suite runs next.
    private func assertSnapshots(
        context: MagicItemAddView.Context,
        item: MagicItem,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        let previousProvider = Current.magicItemProvider
        Current.magicItemProvider = { MagicItemCustomizationMagicItemProvider() }
        defer { Current.magicItemProvider = previousProvider }

        assertLightDarkSnapshots(
            of: NavigationView {
                MagicItemCustomizationView(mode: .edit, context: context, item: item) { _ in }
            },
            drawHierarchyInKeyWindow: true,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}

private final class MagicItemCustomizationMagicItemProvider: MagicItemProviderProtocol {
    func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
        completion([:])
    }

    func loadInformation() async -> [String: [HAAppEntity]] {
        [:]
    }

    func getInfo(for item: MagicItem) -> MagicItem.Info? {
        .init(id: item.serverUniqueId, name: "Kitchen light", iconName: "mdi:lightbulb")
    }

    func getAreaName(for item: MagicItem) -> String? {
        nil
    }
}
