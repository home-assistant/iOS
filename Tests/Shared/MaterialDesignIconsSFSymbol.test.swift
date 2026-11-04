@testable import Shared
import Testing

struct MaterialDesignIconsSFSymbolTests {
    @Test func commonIconsMapToExpectedSymbols() {
        #expect(MaterialDesignIcons.lightbulbIcon.similarSFSymbol.rawValue == "lightbulb")
        #expect(MaterialDesignIcons.homeIcon.similarSFSymbol.rawValue == "house")
        #expect(MaterialDesignIcons.lockIcon.similarSFSymbol.rawValue == "lock")
        #expect(MaterialDesignIcons.playIcon.similarSFSymbol.rawValue == "play")
        #expect(MaterialDesignIcons.weatherSunnyIcon.similarSFSymbol.rawValue == "sun.max")
        #expect(MaterialDesignIcons.accountIcon.similarSFSymbol.rawValue == "person")
    }

    @Test func availabilityGatedIconsResolveOnEveryOS() {
        // These only have an exact match on newer OS versions and must
        // still resolve to a real mapping instead of the generic fallback.
        let gated: [MaterialDesignIcons] = [
            .fanIcon,
            .batteryIcon,
            .thermostatIcon,
            .garageIcon,
            .curtainsIcon,
            .dogIcon,
        ]
        for icon in gated {
            #expect(icon.similarSFSymbol.rawValue != "questionmark.circle", "\(icon.name) should have a mapping")
        }
    }

    @Test func unmappedIconFallsBackToQuestionmark() {
        #expect(MaterialDesignIcons.abjadArabicIcon.similarSFSymbol.rawValue == "questionmark.circle")
    }

    @Test func everyIconResolvesToSomeSymbol() {
        for icon in MaterialDesignIcons.allCases {
            #expect(!icon.similarSFSymbol.rawValue.isEmpty)
        }
    }
}
