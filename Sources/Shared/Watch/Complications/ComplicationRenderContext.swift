import Foundation
import SwiftUI
import UIKit

/// The resolved rendering inputs a complication face needs, derived once from a
/// `WatchComplicationConfig` plus the live entity state (or rendered templates).
///
/// Lives in `Shared` because three surfaces render the very same complication: the watch itself, the
/// in-app editor preview, and the iPhone lock-screen widgets that can mirror a complication. Each of
/// them maps this context into the `HAWatchComplications` render models, so the value / unit /
/// precision / fraction / slot resolution is decided in exactly one place.
public struct ComplicationRenderContext {
    public let config: WatchComplicationConfig
    /// The value text (already unit-appended when applicable).
    public let value: String
    /// The gauge fraction (0...1), or nil when there's no gauge value.
    public let fraction: Double?
    /// The icon image, already gated by the "show icon" toggle (nil when hidden).
    public let iconImage: Image?
    /// Raw entity attributes (entity kind), so slot formulas referencing `{attr:…}` resolve
    /// exactly like on the watch.
    public var attributes: [String: Any] = [:]
    /// Pre-rendered templates for formula resolution. A caller that only renders the main text
    /// template leaves extra templates in customized slot formulas resolving empty here.
    public var renderedTemplates: [String: String] = [:]

    public init(
        config: WatchComplicationConfig,
        value: String,
        fraction: Double?,
        iconImage: Image?,
        attributes: [String: Any] = [:],
        renderedTemplates: [String: String] = [:]
    ) {
        self.config = config
        self.value = value
        self.fraction = fraction
        self.iconImage = iconImage
        self.attributes = attributes
        self.renderedTemplates = renderedTemplates
    }

    private var family: WatchComplicationConfig.Family { config.widgetFamily }

    /// The `{name}` token's value: the entity's name, or — template kind — the rendered
    /// display-name template (`value` carries its render). The complication's own name is
    /// list-only and never renders on the face.
    public var name: String { config.kind == .customTemplate ? value : config.faceName }
    public var showsValue: Bool { config.isSlotVisible(.value, for: family) }
    public var showsName: Bool { config.isSlotVisible(.title, for: family) }
    public var showsSubtitle: Bool { config.isSlotVisible(.subtitle, for: family) }
    public var showsBottomText: Bool { config.isSlotVisible(.bottomText, for: family) }
    public var showsMin: Bool { config.showsMin(for: family) }
    public var showsMax: Bool { config.showsMax(for: family) }
    /// Whether a gauge is drawn — needs both the toggle on and an actual value.
    public var showsGauge: Bool { config.showsGauge(for: family) && fraction != nil }
    public var range: (min: Double, max: Double)? { config.gaugeRange(for: family) }
    public var gaugeStyle: WatchComplicationConfig.GaugeStyle { config.gaugeStyle(for: family) }

    /// Gauge/ring tint; defaults to the accent color.
    public var tint: Color { config.tint(for: family).map { Color(uiColor: UIColor(hex: $0)) } ?? .accentColor }
    /// The configured value/text color, or nil when the complication sets none — so a surface that
    /// isn't drawing on the black watch face can fall back to its own primary color.
    public var configuredTextColor: Color? {
        config.textColor(for: family).map { Color(uiColor: UIColor(hex: $0)) }
    }

    /// Value/text color; defaults to white for contrast on the dark complication face.
    public var textColor: Color { configuredTextColor ?? .white }
    /// Per-slot bottom text color override; nil falls back to `textColor` in the rendered view.
    public var bottomTextColor: Color? {
        config.slotColor(.bottomText, for: family).map { Color(uiColor: UIColor(hex: $0)) }
    }

    /// Min/max are whole numbers.
    public func label(_ value: Double) -> String { String(Int(value.rounded())) }

    // MARK: - Slot texts (same resolution as the watch's snapshot builder)

    private func slotText(_ slot: ComplicationSlot) -> String {
        ComplicationFormulaResolver.resolve(
            config.formula(for: slot, family: family),
            context: ComplicationFormulaContext(
                entityName: name,
                formattedState: value,
                attributeValue: { attributes[$0].map { String(describing: $0) } },
                renderedTemplates: renderedTemplates
            )
        )
    }

    public var titleText: String { slotText(.title) }
    public var valueText: String { slotText(.value) }
    public var subtitleText: String { slotText(.subtitle) }
    public var bottomText: String { slotText(.bottomText) }
}

public extension ComplicationRenderContext {
    /// Build a context for `family` from already-fetched entity data. Centralizes the value / unit /
    /// fraction / icon resolution so every surface renders identically off one fetch.
    static func entity(
        config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family,
        state: String,
        attributes: [String: Any]
    ) -> ComplicationRenderContext {
        var familyConfig = config
        familyConfig.widgetFamily = family

        // Value is shared across families: the chosen attribute (or the state), formatted with the
        // resolved unit + precision.
        let raw = config.valueAttribute.flatMap { attributes[$0] }.map { String(describing: $0) } ?? state
        let resolvedUnit: String? = {
            if let attribute = config.valueAttribute {
                return WatchComplicationConfig.attributeUnit(
                    attribute: attribute,
                    attributes: attributes,
                    domain: config.entityId?.components(separatedBy: ".").first
                )
            }
            return attributes["unit_of_measurement"] as? String
        }()
        let unit: String? = {
            guard config.showsUnit() else { return nil }
            if let override = config.unitOverride, !override.isEmpty { return override }
            return resolvedUnit
        }()
        let precision = config.valuePrecision ?? config.entityId.flatMap {
            EntityRegistryListForDisplay.Entity.displayPrecision(serverId: config.serverId, entityId: $0)
        }
        // Gated on the resolved value, not the state: an entity whose state is empty can still have a
        // value attribute selected, and blanking that would drop a value the face does have.
        let value = raw.isEmpty ? "" : formatValue(raw, unit: unit, precision: precision)

        // Fraction depends on the family's gauge range.
        var fraction: Double?
        if let range = familyConfig.gaugeRange(for: family) {
            let source: Any = familyConfig.gaugeAttribute(for: family).flatMap { attributes[$0] }
                ?? config.valueAttribute.flatMap { attributes[$0] }
                ?? state
            if let rawNumber = WatchComplication.percentileNumber(from: source), range.max > range.min {
                fraction = min(max((Double(rawNumber) - range.min) / (range.max - range.min), 0), 1)
            }
        }

        return ComplicationRenderContext(
            config: familyConfig,
            value: value,
            fraction: fraction,
            iconImage: icon(for: familyConfig, family: family),
            attributes: attributes
        )
    }

    /// A representative placeholder shown before the user picks an entity/template, so every size renders
    /// meaningful sample content instead of an empty face. Honors the config's toggles, colors, chosen
    /// icon, and any typed name.
    static func mock(
        config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family
    ) -> ComplicationRenderContext {
        var familyConfig = config
        familyConfig.widgetFamily = family
        familyConfig.gaugeMin = familyConfig.gaugeMin ?? 0
        familyConfig.gaugeMax = familyConfig.gaugeMax ?? 100
        if familyConfig.name == nil, familyConfig.entityDisplayName == nil, familyConfig.entityId == nil {
            familyConfig.name = "Battery"
        }
        // The face's name token ignores the complication name for the entity kind, so the pre-entity
        // mock needs a stand-in entity name for the title to render.
        if familyConfig.entityDisplayName == nil, familyConfig.entityId == nil {
            familyConfig.entityDisplayName = familyConfig.name
        }
        return ComplicationRenderContext(
            config: familyConfig,
            value: "72%",
            fraction: 0.72,
            iconImage: icon(for: familyConfig, family: family),
            // The template kind's slots resolve through the text template, so the sample value has to
            // be keyed under it (or the empty source, pre-template) for the mock face to show it.
            renderedTemplates: familyConfig.kind == .customTemplate
                ? [familyConfig.customTextTemplate ?? "": "72%"]
                : [:]
        )
    }

    /// The stand-in glyph rendered when the icon slot is visible but no icon has been chosen yet —
    /// the same neutral gauge glyph the complications list uses for icon-less configs.
    static let placeholderIcon: MaterialDesignIcons = .gaugeIcon

    /// The complication's icon, gated by the icon slot's visibility (the same resolution the watch
    /// uses). `placeholderIcon` stands in when the config has no icon of its own, so turning "Show
    /// icon" on always renders a glyph.
    static func icon(
        for config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family
    ) -> Image? {
        guard config.isSlotVisible(.icon, for: family) else { return nil }
        let icon = config.iconName.map { MaterialDesignIcons(serversideValueNamed: $0) } ?? placeholderIcon
        let color = config.iconColor.map { UIColor(hex: $0) } ?? .white
        return Image(uiImage: icon.image(ofSize: CGSize(width: 64, height: 64), color: color))
    }

    /// Formats a raw value for display: Home Assistant's (or the user's) decimal precision, then the
    /// unit appended when there is one.
    static func formatValue(_ state: String, unit: String?, precision: Int?) -> String {
        var text = state
        if let precision, let number = Double(state) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = precision
            formatter.maximumFractionDigits = precision
            text = formatter.string(from: NSNumber(value: number)) ?? state
        }
        if let unit, !unit.isEmpty {
            text += " \(unit)"
        }
        return text
    }
}
