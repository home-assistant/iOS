import Foundation
@testable import Shared
import Testing

struct WatchComplicationConfigGaugeRangeTests {
    private func config(
        gaugeMin: Double? = nil,
        gaugeMax: Double? = nil,
        options: WatchComplicationConfig.FamilyOptions? = nil
    ) -> WatchComplicationConfig {
        WatchComplicationConfig(
            serverId: "server-1",
            gaugeMin: gaugeMin,
            gaugeMax: gaugeMax,
            families: options.map { [WatchComplicationConfig.Family.circular.rawValue: $0] }
        )
    }

    @Test func baseRangeAppliesWithoutOverrides() {
        let config = config(gaugeMin: 0, gaugeMax: 100)
        let range = config.gaugeRange(for: .circular)
        #expect(range?.min == 0)
        #expect(range?.max == 100)
    }

    @Test func fullPerFamilyOverrideWins() {
        let config = config(
            gaugeMin: 0,
            gaugeMax: 100,
            options: .init(gaugeMin: 10, gaugeMax: 40)
        )
        let range = config.gaugeRange(for: .circular)
        #expect(range?.min == 10)
        #expect(range?.max == 40)
    }

    /// Feedback regression: editing only Maximum stores just that bound per-family; the resolved
    /// range must combine it with the base Minimum instead of reverting to the base 0–100.
    @Test func maxOnlyOverrideCombinesWithBaseMin() {
        let config = config(
            gaugeMin: 0,
            gaugeMax: 100,
            options: .init(gaugeMax: 40)
        )
        let range = config.gaugeRange(for: .circular)
        #expect(range?.min == 0)
        #expect(range?.max == 40)
    }

    @Test func minOnlyOverrideCombinesWithBaseMax() {
        let config = config(
            gaugeMin: 0,
            gaugeMax: 100,
            options: .init(gaugeMin: 20)
        )
        let range = config.gaugeRange(for: .circular)
        #expect(range?.min == 20)
        #expect(range?.max == 100)
    }

    @Test func overridesOnlyAffectTheirFamily() {
        let config = config(
            gaugeMin: 0,
            gaugeMax: 100,
            options: .init(gaugeMax: 40)
        )
        let range = config.gaugeRange(for: .rectangular)
        #expect(range?.min == 0)
        #expect(range?.max == 100)
    }

    @Test func invalidResolvedRangeHidesGauge() {
        // Base 50–100 with a per-family max of 40 resolves to 50–40 — exactly what the editor's
        // fields show — so no gauge rather than silently gauging against the base range.
        var config = config(
            gaugeMin: 50,
            gaugeMax: 100,
            options: .init(gaugeMax: 40)
        )
        // Keep the gauge toggled on so the range validity alone decides.
        var options = config.options(for: .circular)
        options.showGauge = true
        config.setOptions(options, for: .circular)
        #expect(config.gaugeRange(for: .circular) == nil)
    }

    @Test func noRangeMeansNoGauge() {
        #expect(config().gaugeRange(for: .circular) == nil)
        #expect(config(gaugeMin: 0).gaugeRange(for: .circular) == nil)
    }
}
