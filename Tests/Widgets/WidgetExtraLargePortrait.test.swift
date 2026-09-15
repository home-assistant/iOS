@testable import HomeAssistant

import HADesignSystem
import Testing
import WidgetKit

/// The portrait extra-large family iOS 27 added: a widget that fits the landscape one also offers
/// it, and it is laid out as a tall large widget rather than as a wide extra-large one.
///
/// The availability sits on each test rather than on the suite: `@Test` cannot be applied to a
/// function whose availability it inherits from its type.
struct WidgetExtraLargePortraitTests {
    @available(iOS 27, *)
    @Test func bothOrientationsAreOffered() {
        #expect(WidgetFamily.extraLarges == [.systemExtraLarge, .systemExtraLargePortrait])
    }

    /// Every widget the home screen offers goes up to both extra-large families: one of them
    /// missing the size is the size missing from the gallery on iPad.
    @available(iOS 27, *)
    @Test func everyHomeScreenWidgetOffersTheExtraLargeFamilies() {
        let widgets: [(String, [WidgetFamily])] = [
            ("entities", WidgetEntitiesSupportedFamilies.families),
            ("open page", WidgetOpenPageSupportedFamilies.families),
            ("scripts", WidgetScriptsSupportedFamilies.families),
            ("sensors", WidgetDetailsTableSupportedFamilies.families),
            ("custom", WidgetCustomSupportedFamilies.families),
            ("commonly used entities", WidgetCommonlyUsedEntitiesSupportedFamilies.families),
            ("to-do list", WidgetTodoList().supportedFamilies),
            ("calendar", WidgetCalendar().supportedFamilies),
            ("energy", WidgetEnergySupportedFamilies.families),
        ]

        for (name, families) in widgets {
            #expect(families.contains(.systemExtraLarge), "\(name)")
            #expect(families.contains(.systemExtraLargePortrait), "\(name)")
        }
    }

    /// Twice the height of a large widget, so twice the events rather than the landscape family's
    /// count, which is a large widget's list stretched sideways.
    @available(iOS 27, *)
    @Test func listsMoreCalendarEventsThanTheLandscapeFamily() {
        #expect(
            WidgetTileLayout.calendarSize(for: .systemExtraLargePortrait) ==
                WidgetTileLayout.calendarSize(for: .systemLarge) * 2
        )
        #expect(
            WidgetTileLayout.calendarSize(for: .systemExtraLarge) ==
                WidgetTileLayout.calendarSize(for: .systemLarge)
        )
    }

    @available(iOS 27, *)
    @Test func holdsAsManyTilesAsTheLandscapeFamily() {
        for capacity in WidgetTileCapacity.allCases {
            #expect(
                WidgetTileLayout.size(for: .systemExtraLargePortrait, capacity: capacity) ==
                    WidgetTileLayout.size(for: .systemExtraLarge, capacity: capacity),
                "\(capacity)"
            )
        }
    }

    /// It is no wider than a large widget, so it takes the same columns and spends the extra space
    /// on rows instead.
    @available(iOS 27, *)
    @Test func takesTheSameColumnsAsALargeWidget() {
        for count in 1 ... WidgetTileLayout.size(for: .systemExtraLargePortrait) {
            #expect(
                WidgetTileLayout.columns(family: .systemExtraLargePortrait, modelCount: count) ==
                    WidgetTileLayout.columns(family: .systemLarge, modelCount: count),
                "\(count) tiles"
            )
        }
    }

    @available(iOS 27, *)
    @Test func fullOfTilesItStillDrawsCards() {
        let max = WidgetTileLayout.size(for: .systemExtraLargePortrait)
        let rows = WidgetTileLayout.rows(for: .systemExtraLargePortrait, models: Array(0 ..< max))

        #expect(rows.count == 10)
        #expect(WidgetTileLayout.sizeStyle(
            family: .systemExtraLargePortrait,
            modelsCount: max,
            rowsCount: rows.count
        ) != .compressed)
    }
}
