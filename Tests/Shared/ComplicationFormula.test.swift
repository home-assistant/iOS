import Foundation
@testable import Shared
import Testing

struct ComplicationFormulaTests {
    // MARK: - Token string round trip

    @Test func tokenStringRoundTrip() {
        let formula = ComplicationFormula(parts: [
            .entityName,
            .text(": "),
            .state,
            .text(" ("),
            .attribute("battery_level"),
            .text(")"),
        ])
        #expect(formula.tokenString == "{name}: {value} ({attr:battery_level})")
        #expect(ComplicationFormula(tokenString: formula.tokenString) == formula)
    }

    @Test func unknownTokensStayLiteral() {
        let formula = ComplicationFormula(tokenString: "{nope} and {name")
        #expect(formula.parts == [.text("{nope} and {name")])
    }

    @Test func templateTokenAttachesSource() {
        let formula = ComplicationFormula(tokenString: "{template} kWh", templateSource: "{{ states('sensor.x') }}")
        #expect(formula.parts == [.template("{{ states('sensor.x') }}"), .text(" kWh")])
        #expect(formula.tokenString == "{template} kWh")
    }

    // MARK: - Resolver

    private func resolve(_ formula: ComplicationFormula, state: String = "21.5 °C") -> String {
        ComplicationFormulaResolver.resolve(formula, context: ComplicationFormulaContext(
            entityName: "Sala",
            formattedState: state,
            attributeValue: { $0 == "battery_level" ? "68" : nil },
            renderedTemplates: ["{{ tpl }}": "rendered"]
        ))
    }

    @Test func resolvesAllPartKinds() {
        let formula = ComplicationFormula(parts: [
            .entityName, .text(" "), .state, .text(" "), .attribute("battery_level"),
            .text(" "), .template("{{ tpl }}"),
        ])
        #expect(resolve(formula) == "Sala 21.5 °C 68 rendered")
    }

    @Test func dropsSeparatorNextToEmptyDynamicPart() {
        let formula = ComplicationFormula(parts: [.entityName, .text(" - "), .state])
        #expect(resolve(formula, state: "") == "Sala")
    }

    @Test func dropsAffixesAroundEmptyDynamicPart() {
        let formula = ComplicationFormula(parts: [.text("Battery: "), .state])
        #expect(resolve(formula, state: "") == "")
    }

    @Test func unknownAttributeResolvesEmpty() {
        let formula = ComplicationFormula(parts: [.attribute("missing"), .text("!"), .entityName])
        #expect(resolve(formula) == "Sala")
    }

    // MARK: - Slot defaults replicate the pre-slot rendering

    private var entityConfig: WatchComplicationConfig {
        WatchComplicationConfig(serverId: "server", kind: .entity, entityId: "sensor.sala")
    }

    @Test func defaultVisibilityMatchesLegacyFlags() {
        let config = entityConfig
        // Circular was value-only, rectangular led with icon + name, corner had name + value.
        #expect(config.isSlotVisible(.value, for: .circular))
        #expect(!config.isSlotVisible(.title, for: .circular))
        #expect(!config.isSlotVisible(.icon, for: .circular))
        #expect(config.isSlotVisible(.icon, for: .rectangular))
        #expect(config.isSlotVisible(.title, for: .rectangular))
        #expect(config.isSlotVisible(.value, for: .rectangular))
        #expect(!config.isSlotVisible(.subtitle, for: .rectangular))
        #expect(!config.isSlotVisible(.bottomText, for: .rectangular))
        #expect(config.isSlotVisible(.title, for: .inline))
        #expect(!config.isSlotVisible(.icon, for: .corner))
        #expect(config.isSlotVisible(.title, for: .corner))
        #expect(config.isSlotVisible(.value, for: .corner))
    }

    @Test func legacyFlagsStillDriveSlotVisibility() {
        var config = entityConfig
        config.setOptions(WatchComplicationConfig.FamilyOptions(showName: true, showIcon: true), for: .circular)
        #expect(config.isSlotVisible(.title, for: .circular))
        #expect(config.isSlotVisible(.icon, for: .circular))
    }

    @Test func explicitSlotConfigWinsOverLegacyFlags() {
        var config = entityConfig
        config.setOptions(WatchComplicationConfig.FamilyOptions(showName: true), for: .circular)
        config.setSlotConfig(ComplicationSlotConfig(isVisible: false), slot: .title, for: .circular)
        #expect(!config.isSlotVisible(.title, for: .circular))
    }

    @Test func defaultFormulasMirrorLegacyContent() {
        let config = entityConfig
        #expect(config.formula(for: .title, family: .rectangular).parts == [.entityName])
        #expect(config.formula(for: .value, family: .rectangular).parts == [.state])
        #expect(config.formula(for: .title, family: .inline).parts == [.entityName, .text(" - "), .state])
    }

    @Test func templateKindDefaultsRouteValueThroughTextTemplate() {
        var config = WatchComplicationConfig(serverId: "server", kind: .customTemplate)
        config.customTextTemplate = "{{ tpl }}"
        #expect(config.formula(for: .value, family: .circular).parts == [.template("{{ tpl }}")])
    }

    @Test func customFormulaSurvivesCodableRoundTrip() throws {
        var config = entityConfig
        config.setSlotConfig(
            ComplicationSlotConfig(
                isVisible: true,
                formula: ComplicationFormula(parts: [.entityName, .text(" • "), .attribute("battery_level")])
            ),
            slot: .subtitle,
            for: .rectangular
        )
        let decoded = try JSONDecoder().decode(
            WatchComplicationConfig.self,
            from: JSONEncoder().encode(config)
        )
        #expect(decoded.slotConfig(.subtitle, for: .rectangular) == config.slotConfig(.subtitle, for: .rectangular))
        #expect(decoded.isSlotVisible(.subtitle, for: .rectangular))
    }
}
