@testable import Shared
import Testing

struct ClimateHvacModeTests {
    @Test func everyModeHasATitleAndItsFrontendIcon() {
        let icons: [ClimateHvacMode: MaterialDesignIcons] = [
            .off: .powerIcon,
            .heat: .fireIcon,
            .cool: .snowflakeIcon,
            .heatCool: .sunSnowflakeVariantIcon,
            .auto: .thermostatAutoIcon,
            .dry: .waterPercentIcon,
            .fanOnly: .fanIcon,
        ]
        for mode in ClimateHvacMode.allCases {
            #expect(!mode.title.isEmpty, "\(mode) has no title")
            #expect(mode.icon == icons[mode], "\(mode) icon")
        }
        #expect(Set(ClimateHvacMode.allCases.map(\.title)).count == ClimateHvacMode.allCases.count)
    }

    @Test func rawValuesMatchHomeAssistant() {
        #expect(ClimateHvacMode(rawValue: "heat_cool") == .heatCool)
        #expect(ClimateHvacMode(rawValue: "fan_only") == .fanOnly)
    }

    @Test func localizedTitleUsesTheKnownTitleOrHumanizesTheRawMode() {
        #expect(ClimateHvacMode.localizedTitle(forMode: "heat") == ClimateHvacMode.heat.title)
        #expect(ClimateHvacMode.localizedTitle(forMode: "fan_only") == ClimateHvacMode.fanOnly.title)
        #expect(
            ClimateHvacMode.localizedTitle(forMode: "eco_boost")
                == ClimateControlState.displayName(forMode: "eco_boost")
        )
    }
}
