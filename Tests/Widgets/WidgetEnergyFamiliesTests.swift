@testable import HomeAssistant
import Testing
import WidgetKit

/// The energy widget's families on a device with a lock screen: the accessory families ride along with the
/// home screen ones, and the headline-figure families are the ones that resolve live power.
struct WidgetEnergyFamiliesTests {
    @available(iOS 17, *)
    @Test func offersTheAccessoryFamiliesNextToTheHomeScreenOnes() {
        let families = WidgetEnergySupportedFamilies.families
        #expect(families.contains(.systemSmall))
        #expect(families.contains(.systemLarge))
        #expect(families.contains(.accessoryCircular))
        #expect(families.contains(.accessoryRectangular))
        #expect(families.contains(.accessoryInline))
    }

    @available(iOS 17, *)
    @Test func livePowerFamiliesAreTheOnesLeadingWithOneFigure() {
        #expect(WidgetEnergySupportedFamilies.livePowerFamilies == [
            .systemSmall,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
        #expect(!WidgetEnergySupportedFamilies.livePowerFamilies.contains(.systemLarge))
    }
}
