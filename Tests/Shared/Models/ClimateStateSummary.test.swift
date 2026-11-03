import Foundation
@testable import Shared
import Testing

/// The climate row summary and the formatting helpers behind it.
struct ClimateStateSummaryTests {
    @Test func summaryCombinesModeAndTemperature() {
        let heating = ClimateControlState(state: "heat", attributes: ["current_temperature": "21.5"])
        #expect(heating.currentTemperature == 21.5)
        #expect(heating.stateSummary.contains(ClimateControlState.formatTemperature(21.5)))
        #expect(heating.stateSummary.contains(" · "))

        let off = ClimateControlState(state: "off", attributes: [:])
        #expect(!off.stateSummary.contains("·"))
    }

    @Test func unavailableStatesUseTheirOwnWording() {
        for state in ["unavailable", "unknown"] {
            let summary = ClimateControlState(state: state, attributes: ["current_temperature": 20]).stateSummary
            #expect(!summary.isEmpty)
            #expect(!summary.contains("20"))
        }
    }

    @Test func helpersFormatAndHumanize() {
        #expect(ClimateControlState.formatTemperature(20) == "20°")
        #expect(ClimateControlState.formatHumidity(45.25).hasSuffix("%"))
        #expect(ClimateControlState.displayName(forMode: "eco_boost") == "Eco boost")
        #expect(
            ClimateControlState(state: "heat", attributes: ["current_temperature": "warm"])
                .currentTemperature == nil
        )
    }
}
