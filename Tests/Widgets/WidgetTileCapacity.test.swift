@testable import HomeAssistant

import HADesignSystem
import Shared
import Testing
import WidgetKit

/// Guards the requirement that the commonly-used widget is the only one that trades tiles for the
/// entity-tile look; every other widget still packs the family full.
struct WidgetTileCapacityTests {
    @Test func commonlyUsedEntitiesKeepsTheEntityTileLook() {
        #expect(WidgetsKind.commonlyUsedEntities.tileCapacity == .tile)
        #expect(WidgetTileLayout.size(for: .systemSmall, capacity: .tile) == 2)
        #expect(WidgetTileLayout.size(for: .systemMedium, capacity: .tile) == 4)
        #expect(WidgetTileLayout.size(for: .systemLarge, capacity: .tile) == 10)
    }

    @Test func everyOtherWidgetKeepsTheOriginalSizes() {
        for kind in WidgetsKind.allCases where kind != .commonlyUsedEntities {
            #expect(kind.tileCapacity == .packed, "\(kind) must keep the original sizes")
        }
        #expect(WidgetTileLayout.size(for: .systemSmall) == 3)
        #expect(WidgetTileLayout.size(for: .systemMedium) == 6)
        #expect(WidgetTileLayout.size(for: .systemLarge) == 12)
        #expect(WidgetTileLayout.size(for: .systemExtraLarge) == 20)
    }

    /// The point of the lower counts: filled to its maximum, a `.tile` widget must never cross the
    /// breakpoint that strips the padding and border off every card.
    @Test func tileCapacityNeverCompresses() {
        for family in [WidgetFamily.systemSmall, .systemMedium, .systemLarge] {
            let max = WidgetTileLayout.size(for: family, capacity: .tile)
            let rows = WidgetTileLayout.rows(for: family, models: Array(0 ..< max), capacity: .tile)
            #expect(
                WidgetTileLayout.sizeStyle(family: family, modelsCount: max, rowsCount: rows.count) != .compressed,
                "\(family) compresses at its maximum"
            )
        }
    }
}
