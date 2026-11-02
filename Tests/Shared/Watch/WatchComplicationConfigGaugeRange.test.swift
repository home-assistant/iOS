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

    @Test func cornerGaugeDisplayDefaultsToGauge() {
        #expect(config().cornerGaugeDisplay(for: .corner) == .gauge)
    }

    @Test func cornerGaugeDisplayReadsCornerOverride() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            families: [
                WatchComplicationConfig.Family.corner.rawValue: .init(
                    cornerGaugeDisplay: WatchComplicationConfig.CornerGaugeDisplay.progress.rawValue
                ),
            ]
        )

        #expect(config.cornerGaugeDisplay(for: .corner) == .progress)
    }

    @Test func cornerGaugeDisplayIgnoresOtherFamilies() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            families: [
                WatchComplicationConfig.Family.circular.rawValue: .init(
                    cornerGaugeDisplay: WatchComplicationConfig.CornerGaugeDisplay.progress.rawValue
                ),
            ]
        )

        #expect(config.cornerGaugeDisplay(for: .circular) == .gauge)
        #expect(config.cornerGaugeDisplay(for: .corner) == .gauge)
    }

    @Test func templateEndpointLabelsRenderIndependently() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            kind: .customTemplate,
            families: ["circular": .init(minLabelTemplate: "{{ low }}", maxLabelTemplate: "{{ high }}")]
        )
        let labels = config.gaugeLabels(for: .circular, renderedTemplates: ["{{ low }}": "12.5°"])
        #expect(labels.min == "12.5°")
        #expect(labels.max == nil)
        #expect(config.gaugeRange(for: .circular) == nil)
    }

    @Test func endpointLabelsRespectFamilyAndVisibility() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            kind: .customTemplate,
            families: ["corner": .init(showMin: false, minLabelTemplate: "low", maxLabelTemplate: "high")]
        )
        let rendered = ["low": "-4", "high": "18"]
        let labels = config.gaugeLabels(for: .corner, renderedTemplates: rendered)
        #expect(labels.min == nil)
        #expect(labels.max == "18")
        #expect(config.gaugeLabels(for: .circular, renderedTemplates: rendered).max == nil)
    }

    @Test func entityLabelsKeepRoundedNumericBounds() {
        let config = config(gaugeMin: -5.5, gaugeMax: 25.5)
        let labels = config.gaugeLabels(for: .circular)
        #expect(labels.min == "-6")
        #expect(labels.max == "26")
    }

    @Test func blankOrFailedEndpointRenderDoesNotShowTemplateSource() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            kind: .customTemplate,
            families: ["circular": .init(minLabelTemplate: "{{ low }}", maxLabelTemplate: "{{ high }}")]
        )
        let labels = config.gaugeLabels(for: .circular, renderedTemplates: ["{{ low }}": ""])
        #expect(labels.min == nil)
        #expect(labels.max == nil)
    }

    @Test func endpointTemplatesAreDeduplicatedAndIgnoreEmptySources() {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            kind: .customTemplate,
            families: [
                "circular": .init(minLabelTemplate: "{{ low }}", maxLabelTemplate: " "),
                "corner": .init(minLabelTemplate: "{{ low }}", maxLabelTemplate: "{{ high }}"),
            ]
        )
        #expect(config.gaugeLabelTemplates == ["{{ low }}", "{{ high }}"])
        var entity = config
        entity.kind = .entity
        #expect(entity.gaugeLabelTemplates.isEmpty)
    }

    @Test func endpointTemplatesSurviveConfigSync() throws {
        let config = WatchComplicationConfig(
            serverId: "server-1",
            kind: .customTemplate,
            families: ["corner": .init(minLabelTemplate: "{{ low }}", maxLabelTemplate: "{{ high }}")]
        )
        let decoded = try JSONDecoder().decode(WatchComplicationConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
        #expect(decoded.options(for: .corner).minLabelTemplate == "{{ low }}")
    }

    @Test func oldFamilyOptionsDecodeWithoutLabelTemplates() throws {
        let options = try JSONDecoder().decode(
            WatchComplicationConfig.FamilyOptions.self,
            from: Data(#"{"gaugeMin":0,"gaugeMax":100}"#.utf8)
        )
        #expect(options.minLabelTemplate == nil)
        #expect(options.maxLabelTemplate == nil)
        #expect(options.gaugeMax == 100)
    }
}
