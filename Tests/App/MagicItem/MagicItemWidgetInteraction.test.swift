@testable import Shared
import Testing

/// A widget tile is two controls, the way the frontend's tile card is: the icon acts on the entity
/// and the rest of the tile opens it. These cover which of the two a given item resolves to, and
/// when the two collapse back into one.
struct MagicItemWidgetInteractionTests {
    @Test func controllableEntityIconTogglesAndTapOpensMoreInfo() {
        let item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)

        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "light.kitchen"))
        // The two halves differ, so the tile is split.
        #expect(item.widgetInteractionType != item.widgetTapInteractionType)
    }

    @Test func readOnlyEntityIsNotSplitAndKeepsItsIconPlain() {
        let item = MagicItem(id: "sensor.temperature", serverId: "1", type: .entity)

        #expect(Self.opensMoreInfo(item.widgetInteractionType, entityId: "sensor.temperature"))
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
        #expect(!item.controlsEntityFromWidget)
    }

    /// A lock has no single main action, so both halves open it — which is exactly a tile that isn't
    /// split, and an icon drawn without its background.
    @Test func lockOpensMoreInfoFromBothHalves() {
        let item = MagicItem(id: "lock.front_door", serverId: "1", type: .entity)

        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
        #expect(!item.controlsEntityFromWidget)
    }

    @Test func scriptIsControllableAndOpensMoreInfoOnTap() {
        let item = MagicItem(id: "script.morning", serverId: "1", type: .script)

        #expect(item.widgetInteractionType == .appIntent(.activate(
            entityId: "script.morning",
            domain: "script",
            serverId: "1"
        )))
        #expect(item.controlsEntityFromWidget)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "script.morning"))
    }

    @Test func chosenTapBehaviorWinsOverTheDefaultMoreInfoDialog() {
        var item = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        item.tapAction = .navigate("/lovelace/0")

        guard case let .widgetURL(url) = item.widgetTapInteractionType else {
            Issue.record("Expected a deep link, got \(item.widgetTapInteractionType)")
            return
        }
        #expect(url.absoluteString.contains("lovelace/0"))
        // The icon keeps controlling the entity.
        #expect(item.controlsEntityFromWidget)
    }

    /// An icon that only opens the app is not a control, so it loses its background — whichever way
    /// it was told to open it.
    @Test func iconThatOnlyOpensTheAppIsNotAControl() {
        var navigating = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        navigating.action = .navigate("/lovelace/0")
        #expect(!navigating.controlsEntityFromWidget)

        var moreInfo = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        moreInfo.action = .moreInfoDialog
        #expect(!moreInfo.controlsEntityFromWidget)

        var nothing = MagicItem(id: "light.kitchen", serverId: "1", type: .entity)
        nothing.action = .nothing
        #expect(!nothing.controlsEntityFromWidget)
    }

    /// An Assist pipeline has no entity behind it, so there is no dialog for the rest of the tile to
    /// open and the whole tile keeps starting Assist.
    @Test func assistPipelineKeepsOneBehaviorForTheWholeTile() {
        let item = MagicItem(id: "pipeline-1", serverId: "1", type: .assistPipeline)

        #expect(!item.hasMoreInfoDialog)
        #expect(item.widgetInteractionType == item.widgetTapInteractionType)
    }

    /// Items saved before the tile was split have no `tapAction` at all; they must read back as the
    /// default, not as a tile that does nothing.
    @Test func itemStoredBeforeTapBehaviorExistedFallsBackToTheDefault() throws {
        let stored = Data("""
        {"id":"light.kitchen","serverId":"1","type":"entity"}
        """.utf8)

        let item = try JSONDecoder().decode(MagicItem.self, from: stored)

        #expect(item.tapAction == nil)
        #expect(Self.opensMoreInfo(item.widgetTapInteractionType, entityId: "light.kitchen"))
        #expect(item.widgetInteractionType == .appIntent(.toggle(
            entityId: "light.kitchen",
            domain: "light",
            serverId: "1"
        )))
    }

    private static func opensMoreInfo(_ interactionType: WidgetInteractionType, entityId: String) -> Bool {
        guard case let .widgetURL(url) = interactionType else { return false }
        return url.absoluteString.contains("\(AppConstants.QueryItems.openMoreInfoDialog.rawValue)=\(entityId)")
    }
}
