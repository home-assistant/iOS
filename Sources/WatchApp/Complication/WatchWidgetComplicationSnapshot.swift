import Shared
import UIKit

/// The watch app's copy of the complication payload it writes into the app group for the widget
/// extension to render on the face. Built here — `make(config:)` performs the live REST fetch and
/// resolves every slot — then JSON-encoded under `WatchWidgetComplicationSnapshotStore.defaultsKey`.
///
/// Must stay field-compatible with the widget extension's copy in
/// `Sources/WatchWidgets/WatchWidgetComplicationSnapshot.swift`: the two targets never share the
/// type, only the JSON in the app group.
struct WatchWidgetComplicationSnapshot: Codable, Equatable {
    // Watch screens are @2x, so this rasterizes to 112px — safely under WidgetKit's ~122px
    // complication-image archiving limit. Anything larger makes the complication render empty.
    static let iconRenderSize = CGSize(width: 56, height: 56)

    /// Per-widget-family rendering values (varies with the config's per-size customization). Keyed by
    /// `WatchComplicationConfig.Family.rawValue`. Must stay field-compatible with the widget
    /// extension's copy in `Sources/WatchWidgets/WatchWidgetComplicationSnapshot.swift` — the two
    /// only meet through the JSON in the app group.
    struct PerFamily: Codable, Equatable {
        let fraction: Double?
        let tint: String?
        let showValue: Bool
        /// Whether to show the complication name (default true).
        var showName: Bool?
        /// Whether to show the icon (default true).
        var showIcon: Bool?
        /// Whether to show the gauge/progress-bar minimum / maximum labels (each default true).
        var showMin: Bool?
        var showMax: Bool?
        /// Raw `WatchComplicationConfig.GaugeStyle` (circular only); nil defaults to open.
        var gaugeStyle: String?
        /// Pre-formatted gauge min/max labels for the open circular gauge.
        var minLabel: String?
        var maxLabel: String?
        /// Hex color for the value text; nil uses the default.
        var textColor: String?
        /// Per-slot color override for the bottom text; nil falls back to `textColor`.
        var bottomTextColor: String? = nil
        /// Resolved slot texts (slot/formula model); optional so older widget builds ignore them.
        var title: String?
        var subtitle: String?
        var value: String?
        var bottomText: String?
        /// Visibility of the slots that have no legacy flag (both default hidden).
        var showSubtitle: Bool?
        var showBottomText: Bool?
        /// Corner only: whether the corner's own text rides the outer curve (default true, the modern
        /// layout) or sits flat in the corner tip, the way ClockKit drew a Graphic Corner's outer text.
        var curvesText: Bool? = nil
    }

    let id: String
    let family: String
    let title: String
    let subtitle: String
    let inlineText: String
    let fraction: Double?
    let tint: String?
    let iconData: Data?
    let perFamily: [String: PerFamily]?
    /// Name shown in the complication picker (the value goes in `title` for on-face rendering).
    let menuName: String?
    /// Whether the complication is shown while the display is dimmed (default true).
    var showWhenInactive: Bool?

    init(
        id: String,
        family: String,
        title: String,
        subtitle: String,
        inlineText: String,
        fraction: Double?,
        tint: String?,
        iconData: Data?,
        perFamily: [String: PerFamily]? = nil,
        menuName: String? = nil,
        showWhenInactive: Bool? = nil
    ) {
        self.id = id
        self.family = family
        self.title = title
        self.subtitle = subtitle
        self.inlineText = inlineText
        self.fraction = fraction
        self.tint = tint
        self.iconData = iconData
        self.perFamily = perFamily
        self.menuName = menuName
        self.showWhenInactive = showWhenInactive
    }

    /// Formats a numeric state with the entity's display precision and unit, mirroring the app.
    private static func formatValue(_ state: String, unit: String?, precision: Int?) -> String {
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

    /// Renders every template the slot formulas reference (template kind only): the main text
    /// template reuses its already-rendered result, and any extra templates in customized slots
    /// render once each.
    private static func renderedSlotTemplates(
        config: WatchComplicationConfig,
        server: Server?,
        mainTemplateResult: String?
    ) async -> [String: String] {
        guard config.kind == .customTemplate, let server else { return [:] }
        var rendered: [String: String] = [:]
        if let mainTemplate = config.customTextTemplate, let mainTemplateResult {
            rendered[mainTemplate] = mainTemplateResult
        }
        let slotConfigs = (config.families ?? [:]).values.flatMap { ($0.slots ?? [:]).values }
        let customTemplates = Set(slotConfigs.flatMap { $0.formula?.templates ?? [] })
            .subtracting(rendered.keys)
        for template in customTemplates {
            if let result = await ComplicationStateFetcher.renderTemplate(template, server: server) {
                rendered[template] = result
            }
        }
        return rendered
    }

    /// Builds a snapshot for a modern config, fetching the live entity state / rendering the custom
    /// template on the watch. The value is shared across sizes; per-family gauge/tint/showValue are
    /// resolved from the config's per-size customization. Falls back to the name when unavailable.
    static func make(
        config: WatchComplicationConfig
    ) async -> (snapshot: WatchWidgetComplicationSnapshot, isLive: Bool, failureReason: String?) {
        typealias Family = WatchComplicationConfig.Family
        let server = Current.servers.all.first(where: { $0.identifier.rawValue == config.serverId })
        if server == nil {
            Current.Log.error("[Complication] no matching server for config \(config.id) (serverId \(config.serverId))")
        }

        var valueText = ""
        var rawState = ""
        var attributes: [String: Any] = [:]
        var customGaugeFraction: Double?
        // Rendered by the color templates (custom-template kind); each overrides its static color.
        var gaugeColorHex: String?
        var iconColorHex: String?
        var textColorHex: String?
        // Whether we obtained fresh live data this pass. When false the caller keeps the last-known
        // snapshot instead of overwriting it with a value-less one.
        var isLive = false
        var failureReason: String?

        switch config.kind {
        case .entity:
            guard let server else {
                failureReason = "no server configured"
                break
            }
            guard let entityId = config.entityId else {
                failureReason = "no entity configured"
                break
            }
            let fetched = await ComplicationStateFetcher.fetchState(entityId: entityId, server: server)
            if let result = fetched.state {
                rawState = result.state
                attributes = result.attributes
                // Unit comes from the live state; precision comes from the entity registry in GRDB (synced
                // to the watch) — neither is duplicated into the config. The unit is suppressed when the
                // user turned it off.
                // The user can override the decimal precision; otherwise follow Home Assistant's.
                let precision = config.valuePrecision ?? EntityRegistryListForDisplay.Entity.displayPrecision(
                    serverId: config.serverId,
                    entityId: entityId
                )
                // The value can come from an entity attribute instead of the state. The unit follows the
                // source: the state's unit_of_measurement for the state, or the attribute's resolved unit
                // (never the state unit) for an attribute — otherwise weather temperature would get the
                // wrong unit.
                let rawValue: String
                let resolvedUnit: String?
                if let attribute = config.valueAttribute {
                    rawValue = result.attributes[attribute].map { String(describing: $0) } ?? result.state
                    resolvedUnit = WatchComplicationConfig.attributeUnit(
                        attribute: attribute,
                        attributes: result.attributes,
                        domain: entityId.components(separatedBy: ".").first
                    )
                } else {
                    rawValue = result.state
                    resolvedUnit = result.attributes["unit_of_measurement"] as? String
                }
                // A user-provided unit override wins over the resolved unit.
                let effectiveUnit = config.unitOverride.flatMap { $0.isEmpty ? nil : $0 } ?? resolvedUnit
                let unit = config.showsUnit() ? effectiveUnit : nil
                valueText = formatValue(rawValue, unit: unit, precision: precision)
                isLive = true
            } else {
                failureReason = fetched.failure ?? "live state unavailable"
            }
        case .customTemplate:
            guard let server else {
                failureReason = "no server configured"
                break
            }
            if let template = config.customTextTemplate,
               let rendered = await ComplicationStateFetcher.renderTemplate(template, server: server) {
                valueText = rendered
                rawState = rendered
                isLive = true
            }
            if let template = config.customGaugeTemplate,
               let rendered = await ComplicationStateFetcher.renderTemplate(template, server: server),
               let raw = WatchComplication.percentileNumber(from: rendered) {
                customGaugeFraction = min(max(Double(raw), 0), 1)
                isLive = true
            }
            // Colors are cosmetic: they never count as live data, and an invalid render just keeps
            // the static color it would have overridden.
            func renderColor(_ template: String?) async -> String? {
                guard let template,
                      let rendered = await ComplicationStateFetcher.renderTemplate(template, server: server) else { return nil }
                return WatchComplicationConfig.normalizedHexColor(from: rendered)
            }
            gaugeColorHex = await renderColor(config.customGaugeColorTemplate)
            iconColorHex = await renderColor(config.customIconColorTemplate)
            textColorHex = await renderColor(config.customTextColorTemplate)
            if !isLive {
                failureReason = "template render failed"
            }
        }

        func fraction(for family: Family) -> Double? {
            switch config.kind {
            case .entity:
                guard let range = config.gaugeRange(for: family) else { return nil }
                let source: Any = config.gaugeAttribute(for: family).flatMap { attributes[$0] }
                    ?? config.valueAttribute.flatMap { attributes[$0] }
                    ?? rawState
                guard let raw = WatchComplication.percentileNumber(from: source), range.max > range.min else {
                    return nil
                }
                return min(max((Double(raw) - range.min) / (range.max - range.min), 0), 1)
            case .customTemplate:
                if config.families?[family.rawValue]?.showGauge == false { return nil }
                return customGaugeFraction
            }
        }

        func label(_ value: Double) -> String {
            String(Int(value.rounded()))
        }

        // The name rendered on the face — the entity's name, or the rendered display-name template
        // for the template kind. The complication's own `name` never renders: it only labels the
        // complication in the gallery menu (`menuName` below uses `displayName`).
        let name = config.kind == .customTemplate ? valueText : config.faceName

        // Slot resolution. Entity formulas resolve fully on-device from the fetched state (template
        // rendering is an admin-only server operation); template-kind formulas may reference extra
        // templates in customized slots, each rendered once here. The main text template reuses the
        // render above instead of rendering twice.
        let renderedTemplates = await renderedSlotTemplates(
            config: config,
            server: server,
            mainTemplateResult: isLive ? valueText : nil
        )
        let formulaContext = ComplicationFormulaContext(
            entityName: name,
            formattedState: valueText,
            attributeValue: { attributes[$0].map { String(describing: $0) } },
            renderedTemplates: renderedTemplates
        )
        func slotText(_ slot: ComplicationSlot, _ family: Family) -> String {
            ComplicationFormulaResolver.resolve(config.formula(for: slot, family: family), context: formulaContext)
        }

        var perFamily: [String: PerFamily] = [:]
        for family in Family.allCases {
            let range = config.gaugeRange(for: family)
            perFamily[family.rawValue] = PerFamily(
                fraction: fraction(for: family),
                tint: gaugeColorHex ?? config.tint(for: family),
                showValue: config.isSlotVisible(.value, for: family),
                showName: config.isSlotVisible(.title, for: family),
                showIcon: config.isSlotVisible(.icon, for: family),
                showMin: config.showsMin(for: family),
                showMax: config.showsMax(for: family),
                gaugeStyle: config.gaugeStyle(for: family).rawValue,
                minLabel: range.map { label($0.min) },
                maxLabel: range.map { label($0.max) },
                textColor: textColorHex ?? config.textColor(for: family),
                bottomTextColor: config.slotColor(.bottomText, for: family),
                title: slotText(.title, family),
                subtitle: slotText(.subtitle, family),
                value: slotText(.value, family),
                bottomText: slotText(.bottomText, family),
                showSubtitle: config.isSlotVisible(.subtitle, for: family),
                showBottomText: config.isSlotVisible(.bottomText, for: family)
            )
        }
        let iconData = Self.iconData(config: config, iconColorHex: iconColorHex)

        // Template kind resolves name and value to the same rendered text; joining both would
        // render it twice on the legacy inline line.
        let inlineParts = name == valueText ? [valueText] : [name, valueText]
        let snapshot = WatchWidgetComplicationSnapshot(
            id: config.id,
            family: "",
            title: valueText.isEmpty ? name : valueText,
            subtitle: name,
            inlineText: inlineParts.filter { !$0.isEmpty }.joined(separator: " "),
            fraction: fraction(for: config.widgetFamily),
            tint: config.tint(for: config.widgetFamily),
            iconData: iconData,
            perFamily: perFamily,
            menuName: config.displayName,
            showWhenInactive: config.showsWhenInactive()
        )
        return (snapshot, isLive, failureReason)
    }

    /// Adapts a legacy (ClockKit-era) complication into the modern snapshot shape.
    ///
    /// Legacy complications used to ship with no `perFamily` payload, which every on-face view reads
    /// as "this is a built-in" and renders as the Home Assistant logo alone (circular and corner) or a
    /// single unstyled line (rectangular) — silently dropping the user's text areas, gauge and ring.
    /// Populating `perFamily` sends them through the same content views the modern configs use, so
    /// they render their own content again.
    init(complication: WatchComplication) {
        let render = LegacyComplicationRender(complication: complication)
        let iconData = Self.iconData(name: render.iconName, colorHex: render.iconColor)

        let options = PerFamily(
            fraction: render.fraction,
            tint: render.tint,
            showValue: !render.value.isEmpty,
            showName: !render.title.isEmpty,
            showIcon: iconData != nil,
            gaugeStyle: render.gaugeStyle,
            minLabel: render.minLabel,
            maxLabel: render.maxLabel,
            textColor: render.textColor,
            bottomTextColor: render.bottomTextColor,
            title: render.title,
            value: render.value,
            bottomText: render.bottomText,
            showBottomText: !render.bottomText.isEmpty
        )
        // Inline is a single system-tinted line with no icon or gauge, and resolves that whole line
        // from the title slot — so it gets every area joined together rather than just one of them.
        var inlineOptions = options
        inlineOptions.title = render.inlineText
        inlineOptions.showName = !render.inlineText.isEmpty
        // The corner and circular families lead with the complication's content and caption it after,
        // rather than heading it with a label, so their two areas land the other way round (see
        // `LegacyComplicationRender.ContentLed`).
        let contentLedOptions = PerFamily(
            fraction: render.fraction,
            tint: render.tint,
            showValue: !render.contentLed.value.isEmpty,
            showName: !render.contentLed.title.isEmpty,
            showIcon: iconData != nil,
            gaugeStyle: render.gaugeStyle,
            minLabel: render.minLabel,
            maxLabel: render.maxLabel,
            textColor: render.contentLed.textColor,
            bottomTextColor: render.bottomTextColor,
            title: render.contentLed.title,
            value: render.contentLed.value,
            bottomText: render.bottomText,
            showBottomText: !render.bottomText.isEmpty
        )
        // The corner's own text sits flat in the corner tip unless the template curved it (see
        // `LegacyComplicationRender.curvesCornerText`); the modern layout curves it by default.
        var cornerOptions = contentLedOptions
        cornerOptions.curvesText = render.curvesCornerText

        self.init(
            id: complication.identifier,
            family: complication.Family.rawValue,
            title: render.value.isEmpty ? complication.displayName : render.value,
            // `subtitle` is this struct's pre-slot name field, so it carries the complication's name
            // rather than one of its text areas — the slots below hold the rendered content.
            subtitle: complication.displayName,
            inlineText: render.inlineText,
            fraction: render.fraction,
            tint: render.tint,
            iconData: iconData,
            // Spelled out rather than aliased to `Family`: `WatchComplication.Family` is the legacy
            // ClockKit family, and the two reading alike in one initializer invites a mix-up.
            perFamily: [
                WatchComplicationConfig.Family.circular.rawValue: contentLedOptions,
                WatchComplicationConfig.Family.rectangular.rawValue: options,
                WatchComplicationConfig.Family.corner.rawValue: cornerOptions,
                WatchComplicationConfig.Family.inline.rawValue: inlineOptions,
            ],
            menuName: complication.displayName
        )
    }

    static var placeholder: WatchWidgetComplicationSnapshot {
        .init(
            id: "placeholder",
            family: "",
            title: "Home Assistant",
            subtitle: "Complication",
            inlineText: "Home Assistant",
            fraction: nil,
            tint: nil,
            // No icon payload: the widget extension renders its bundled (correctly sized) Logo asset.
            iconData: nil
        )
    }

    static var assist: WatchWidgetComplicationSnapshot {
        .init(
            id: AssistDefaultComplication.defaultComplicationId,
            family: "",
            title: AssistDefaultComplication.title,
            subtitle: "Home Assistant",
            inlineText: AssistDefaultComplication.title,
            fraction: nil,
            tint: nil,
            // No icon payload: the widget extension renders its bundled Assist symbol via the fallback path.
            iconData: nil
        )
    }

    /// Rasterizes a modern config's icon for the snapshot payload. Icon names may be server-side
    /// values (e.g. "mdi:home"); normalized before lookup. A config without an icon of its own still
    /// gets the shared placeholder glyph, so turning "Show icon" on renders something before the user
    /// picks one. Skipped entirely when no size shows the icon — no point rasterizing a payload
    /// nothing renders.
    private static func iconData(config: WatchComplicationConfig, iconColorHex: String?) -> Data? {
        let familyShowsIcon = WatchComplicationConfig.Family.allCases
            .contains { config.isSlotVisible(.icon, for: $0) }
        guard familyShowsIcon else { return nil }
        let color = (iconColorHex ?? config.iconColor).map { UIColor(hex: $0) } ?? AppConstants.tintColor
        let icon = config.iconName.map { MaterialDesignIcons(serversideValueNamed: $0) }
            ?? ComplicationRenderContext.placeholderIcon
        return icon.image(ofSize: iconRenderSize, color: color).pngData()
    }

    /// Rasterizes a legacy complication's Material Design icon for the snapshot payload.
    private static func iconData(name: String?, colorHex: String?) -> Data? {
        guard let name else { return nil }

        let color = colorHex.map { UIColor($0) } ?? AppConstants.tintColor
        // The stored name may be a server-side value (e.g. "mdi:music"); normalize before lookup so
        // image-based legacy complications (e.g. "Ring Image") actually resolve an icon.
        return MaterialDesignIcons(serversideValueNamed: name)
            .image(ofSize: iconRenderSize, color: color)
            .pngData()
    }
}
