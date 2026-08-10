import Foundation
@testable import Shared
import Testing

struct ComplicationRenderContextTests {
    private func templateConfig(template: String? = "{{ tpl }}") -> WatchComplicationConfig {
        WatchComplicationConfig(
            serverId: "server",
            kind: .customTemplate,
            name: "Solar",
            customTextTemplate: template
        )
    }

    // MARK: - Template value resolution

    @Test func valueSlotResolvesRenderedDisplayNameTemplate() {
        let context = ComplicationRenderContext(
            config: templateConfig(),
            value: "42 W",
            fraction: nil,
            iconImage: nil,
            renderedTemplates: ["{{ tpl }}": "42 W"]
        )
        #expect(context.valueText == "42 W")
    }

    @Test func valueSlotResolvesEmptyWithoutRenderedTemplates() {
        // The default value formula routes through the text template, so a caller that forgets the
        // rendered lookup would leave the face showing only the complication name.
        let context = ComplicationRenderContext(
            config: templateConfig(),
            value: "42 W",
            fraction: nil,
            iconImage: nil
        )
        #expect(context.valueText.isEmpty)
    }

    @Test func mockTemplateKindShowsSampleValueBeforeTemplateIsTyped() {
        let context = ComplicationRenderContext.mock(config: templateConfig(template: nil), family: .circular)
        #expect(context.valueText == "72%")
    }

    @Test func mockTemplateKindShowsSampleValueForTypedTemplate() {
        let context = ComplicationRenderContext.mock(config: templateConfig(), family: .rectangular)
        #expect(context.valueText == "72%")
    }

    @Test func templateKindTitleRendersNothingByDefault() {
        // The complication name only labels the config in lists — the face's title slot defaults to
        // empty for template complications instead of rendering it.
        let context = ComplicationRenderContext(
            config: templateConfig(),
            value: "42 W",
            fraction: nil,
            iconImage: nil,
            renderedTemplates: ["{{ tpl }}": "42 W"]
        )
        #expect(context.titleText.isEmpty)
    }

    @Test func nameTokenResolvesRenderedDisplayNameForTemplateKind() {
        var config = templateConfig()
        config.setSlotConfig(
            ComplicationSlotConfig(isVisible: true, formula: ComplicationFormula(parts: [.entityName])),
            slot: .title,
            for: .circular
        )
        let context = ComplicationRenderContext(
            config: config,
            value: "42 W",
            fraction: nil,
            iconImage: nil,
            renderedTemplates: ["{{ tpl }}": "42 W"]
        )
        #expect(context.titleText == "42 W")
    }

    // MARK: - Icon placeholder

    @Test func visibleIconSlotWithoutIconRendersPlaceholder() {
        var config = templateConfig()
        config.setSlotConfig(ComplicationSlotConfig(isVisible: true), slot: .icon, for: .circular)
        #expect(ComplicationRenderContext.icon(for: config, family: .circular) != nil)
    }

    @Test func hiddenIconSlotRendersNoIcon() {
        // Circular hides the icon by default; no placeholder may leak in while the slot is off.
        #expect(ComplicationRenderContext.icon(for: templateConfig(), family: .circular) == nil)
    }
}
