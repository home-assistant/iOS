@testable import HomeAssistant

import HADesignSystem
import Testing
import WidgetKit

/// Which families the lock screen draws. The circular accessory is the one that routes around the
/// tile grid, so its control's label is the glyph alone — see `WidgetCircularAccessoryView`.
struct WidgetFamilyLockScreenTests {
    @Test(arguments: [WidgetFamily.accessoryCircular, .accessoryRectangular, .accessoryInline])
    func lockScreenFamiliesAreAccessories(family: WidgetFamily) {
        #expect(family.isLockScreenAccessory)
    }

    @Test(arguments: [
        WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge, .systemExtraLargePortrait,
    ])
    func homeScreenFamiliesAreNot(family: WidgetFamily) {
        #expect(!family.isLockScreenAccessory)
    }
}
