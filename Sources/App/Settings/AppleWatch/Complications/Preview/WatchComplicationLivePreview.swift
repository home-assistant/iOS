import Shared
import SwiftUI

/// The resolved rendering inputs a per-family preview needs. Bundled so the family views stay small and
/// don't each re-derive the same styling from the config.
struct ComplicationPreviewContext {
    let config: WatchComplicationConfig
    /// The value text (already unit-appended when applicable), from the live template render.
    let value: String
    /// The gauge fraction (0...1), or nil when there's no gauge value.
    let fraction: Double?
    /// The icon image, already gated by the "show icon" toggle (nil when hidden or none).
    let iconImage: Image?

    private var family: WatchComplicationConfig.Family { config.widgetFamily }

    var name: String { config.name ?? config.entityDisplayName ?? config.entityId ?? "" }
    var showsValue: Bool { config.showsValue(for: family) }
    var showsName: Bool { config.showsName(for: family) }
    var showsMin: Bool { config.showsMin(for: family) }
    var showsMax: Bool { config.showsMax(for: family) }
    /// Whether a gauge is drawn — needs both the toggle on and an actual value.
    var showsGauge: Bool { config.showsGauge(for: family) && fraction != nil }
    var range: (min: Double, max: Double)? { config.gaugeRange(for: family) }
    var gaugeStyle: WatchComplicationConfig.GaugeStyle { config.gaugeStyle(for: family) }

    /// Gauge/ring tint; defaults to the accent color.
    var tint: Color { config.tint(for: family).map { Color(uiColor: UIColor($0)) } ?? .accentColor }
    /// Value/text color; defaults to white for contrast on the dark preview face.
    var textColor: Color { config.textColor(for: family).map { Color(uiColor: UIColor(hex: $0)) } ?? .white }

    /// Min/max are whole numbers.
    func label(_ value: Double) -> String { String(Int(value.rounded())) }
}

/// A live approximation of the watch complication, mirroring `WatchWidgetsEntryView` but rendered on
/// iPhone with current data (via Home Assistant template rendering) so the user sees the real result
/// before saving. Owns the template renderers and dispatches to the per-family preview views.
struct WatchComplicationLivePreview: View {
    let config: WatchComplicationConfig
    /// Reports the entity's rendered unit of measurement (nil when it has none) so the editor can
    /// decide whether to offer the "Show unit" toggle.
    var onUnit: (String?) -> Void = { _ in }
    @StateObject private var valueRenderer: TemplateRenderer
    @StateObject private var gaugeRenderer: TemplateRenderer
    @StateObject private var unitRenderer: TemplateRenderer

    init(config: WatchComplicationConfig, server: Server, onUnit: @escaping (String?) -> Void = { _ in }) {
        self.config = config
        self.onUnit = onUnit
        _valueRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _gaugeRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _unitRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
    }

    private var renderedValue: String {
        if case let .success(rendered) = valueRenderer.output { return rendered }
        return ""
    }

    private var renderedUnit: String? {
        if case let .success(unit) = unitRenderer.output, !unit.isEmpty { return unit }
        return nil
    }

    /// The value as displayed: appends the unit when present and enabled (entity source only).
    private var value: String {
        let base = renderedValue
        guard !base.isEmpty else { return "" }
        if config.kind == .entity, config.showsUnit(), let unit = renderedUnit {
            return "\(base) \(unit)"
        }
        return base
    }

    private var fraction: Double? {
        guard case let .success(rendered) = gaugeRenderer.output,
              let raw = WatchComplication.percentileNumber(from: rendered) else {
            return nil
        }
        return min(max(Double(raw), 0), 1)
    }

    private var iconColor: Color {
        config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? .white
    }

    private var iconImage: Image? {
        guard config.showsIcon(for: config.widgetFamily), let iconName = config.iconName else { return nil }
        let image = MaterialDesignIcons(serversideValueNamed: iconName)
            .image(ofSize: CGSize(width: 64, height: 64), color: UIColor(iconColor))
        return Image(uiImage: image)
    }

    /// True while any of the template renderers is still evaluating.
    private var isLoading: Bool {
        [valueRenderer.output, gaugeRenderer.output, unitRenderer.output].contains(.loading)
    }

    private var context: ComplicationPreviewContext {
        ComplicationPreviewContext(config: config, value: value, fraction: fraction, iconImage: iconImage)
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .onAppear(perform: applyTemplates)
            .onChange(of: config) { _ in applyTemplates() }
            .onChange(of: unitRenderer.output) { _ in onUnit(renderedUnit) }
    }

    @ViewBuilder
    private var content: some View {
        switch config.widgetFamily {
        case .circular:
            CircularComplicationPreview(context: context)
        case .corner:
            CornerComplicationPreview(context: context)
        case .rectangular:
            RectangularComplicationPreview(context: context)
        case .inline:
            InlineComplicationPreview(context: context)
        }
    }

    private func applyTemplates() {
        switch config.kind {
        case .entity:
            guard let entityId = config.entityId else {
                valueRenderer.updateTemplate("")
                gaugeRenderer.updateTemplate("")
                unitRenderer.updateTemplate("")
                return
            }
            valueRenderer.updateTemplate("{{ states('\(entityId)') }}")
            unitRenderer.updateTemplate("{{ state_attr('\(entityId)', 'unit_of_measurement') or '' }}")
            if let range = config.gaugeRange(for: config.widgetFamily) {
                let source = config.gaugeAttribute(for: config.widgetFamily)
                    .map { "state_attr('\(entityId)', '\($0)')" } ?? "states('\(entityId)')"
                gaugeRenderer.updateTemplate(
                    "{{ ((\(source) | float(0)) - \(range.min)) / \(range.max - range.min) }}"
                )
            } else {
                gaugeRenderer.updateTemplate("")
            }
        case .customTemplate:
            valueRenderer.updateTemplate(config.customTextTemplate ?? "")
            gaugeRenderer.updateTemplate(config.customGaugeTemplate ?? "")
            unitRenderer.updateTemplate("")
        }
    }
}
