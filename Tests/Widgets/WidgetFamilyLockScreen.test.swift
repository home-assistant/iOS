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

    @Test(arguments: [WidgetFamily.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    func homeScreenFamiliesAreNot(family: WidgetFamily) {
        #expect(!family.isLockScreenAccessory)
    }

    /// Tested on its own rather than in the arguments above: naming the case as a value needs
    /// iOS 27, and an argument list cannot carry the availability check that allows it.
    @available(iOS 27, *)
    @Test func extraLargePortraitIsNotAnAccessory() {
        #expect(!WidgetFamily.systemExtraLargePortrait.isLockScreenAccessory)
    }
}
