import Shared
import SwiftUI

/// Shows the complication in all four WidgetKit families at once, arranged like an Apple Watch face,
/// so the user sees every size simultaneously instead of flipping a size picker. Tapping a family
/// selects it as the one being customized below (bound to `selectedFamily`), with the selection
/// highlighted. Fetches the entity state once and renders every family from that single fetch.
struct AllFamiliesComplicationPreview: View {
    let config: WatchComplicationConfig
    let server: Server
    @Binding var selectedFamily: WatchComplicationConfig.Family
    /// Reports the entity's unit (nil when none), so the editor can offer the "Show unit" toggle.
    var onUnit: (String?) -> Void = { _ in }
    /// Reports the entity's attribute names (sorted), offered as value sources.
    var onAttributes: ([String]) -> Void = { _ in }
    /// Reports whether the current value (state or chosen attribute) is numeric, so the editor can hide
    /// the decimals picker for non-numeric values.
    var onValueIsNumeric: (Bool) -> Void = { _ in }

    @State private var entityState = ""
    @State private var entityAttributes: [String: Any] = [:]
    @State private var isFetching = false
    @State private var lastFetchKey: String?

    // Template rendering, used only for the custom-template kind.
    @StateObject private var valueRenderer: TemplateRenderer
    @StateObject private var gaugeRenderer: TemplateRenderer

    init(
        config: WatchComplicationConfig,
        server: Server,
        selectedFamily: Binding<WatchComplicationConfig.Family>,
        onUnit: @escaping (String?) -> Void = { _ in },
        onAttributes: @escaping ([String]) -> Void = { _ in },
        onValueIsNumeric: @escaping (Bool) -> Void = { _ in }
    ) {
        self.config = config
        self.server = server
        self._selectedFamily = selectedFamily
        self.onUnit = onUnit
        self.onAttributes = onAttributes
        self.onValueIsNumeric = onValueIsNumeric
        _valueRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _gaugeRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
    }

    private var fetchKey: String {
        [
            config.kind.rawValue, config.serverId, config.entityId ?? "",
            config.customTextTemplate ?? "", config.customGaugeTemplate ?? "",
        ].joined(separator: "|")
    }

    /// True before the user has chosen a data source — the preview then shows sample (mock) content.
    private var isUnconfigured: Bool {
        switch config.kind {
        case .entity: return config.entityId == nil
        case .customTemplate:
            return (config.customTextTemplate ?? "").isEmpty && (config.customGaugeTemplate ?? "").isEmpty
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spaces.two) {
            HStack(alignment: .top, spacing: DesignSystem.Spaces.three) {
                familyTile(.circular)
                familyTile(.corner)
            }
            familyTile(.rectangular)
            familyTile(.inline)
        }
        .padding(DesignSystem.Spaces.two)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
        )
        .overlay(alignment: .topTrailing) {
            if isFetching {
                ProgressView().controlSize(.small).tint(.white).padding(10)
            }
        }
        .environment(\.colorScheme, .dark)
        // Re-run the fetch/render whenever a fetch input changes (entity, server, kind, template) —
        // reliably, so the preview updates on entity change without needing to tap a family first.
        .task(id: fetchKey) { refresh() }
    }

    /// One tappable family render + label; the selected family is highlighted.
    @ViewBuilder
    private func familyTile(_ family: WatchComplicationConfig.Family) -> some View {
        let isSelected = selectedFamily == family
        Button {
            selectedFamily = family
        } label: {
            VStack(spacing: DesignSystem.Spaces.half) {
                preview(for: family)
                    .padding(DesignSystem.Spaces.one)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor, lineWidth: isSelected ? 2 : 0)
                    )
                Text(verbatim: family.title)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func preview(for family: WatchComplicationConfig.Family) -> some View {
        let context = context(for: family)
        switch family {
        case .circular: CircularComplicationPreview(context: context)
        case .corner: CornerComplicationPreview(context: context)
        case .rectangular: RectangularComplicationPreview(context: context)
        case .inline: InlineComplicationPreview(context: context)
        }
    }

    private func context(for family: WatchComplicationConfig.Family) -> ComplicationPreviewContext {
        if isUnconfigured {
            return .mock(config: config, family: family)
        }
        switch config.kind {
        case .entity:
            return .entity(config: config, family: family, state: entityState, attributes: entityAttributes)
        case .customTemplate:
            var familyConfig = config
            familyConfig.widgetFamily = family
            let value: String = {
                if case let .success(rendered) = valueRenderer.output { return rendered }
                return ""
            }()
            let fraction: Double? = {
                guard case let .success(rendered) = gaugeRenderer.output,
                      let raw = WatchComplication.percentileNumber(from: rendered) else { return nil }
                return min(max(Double(raw), 0), 1)
            }()
            var iconImage: Image?
            if familyConfig.showsIcon(for: family), let iconName = config.iconName {
                let color = config.iconColor.map { UIColor(hex: $0) } ?? .white
                iconImage = Image(
                    uiImage: MaterialDesignIcons(serversideValueNamed: iconName)
                        .image(ofSize: CGSize(width: 64, height: 64), color: color)
                )
            }
            return ComplicationPreviewContext(
                config: familyConfig, value: value, fraction: fraction, iconImage: iconImage
            )
        }
    }

    // MARK: - Data loading

    private func refresh() {
        switch config.kind {
        case .entity:
            if fetchKey != lastFetchKey {
                fetchEntityState()
            } else {
                reportDerived()
            }
        case .customTemplate:
            valueRenderer.updateTemplate(config.customTextTemplate ?? "")
            gaugeRenderer.updateTemplate(config.customGaugeTemplate ?? "")
        }
    }

    private func reportDerived() {
        let resolvedUnit: String? = config.valueAttribute.flatMap {
            WatchComplicationConfig.attributeUnit(
                attribute: $0,
                attributes: entityAttributes,
                domain: config.entityId?.components(separatedBy: ".").first
            )
        } ?? entityAttributes["unit_of_measurement"] as? String
        onUnit(resolvedUnit)
        onAttributes(entityAttributes.keys.sorted())
        // The value the decimals picker applies to: the chosen attribute, else the state.
        let raw = config.valueAttribute.flatMap { entityAttributes[$0] }.map { String(describing: $0) } ?? entityState
        onValueIsNumeric(Double(raw) != nil)
    }

    private func fetchEntityState() {
        lastFetchKey = fetchKey
        guard let entityId = config.entityId else {
            entityState = ""
            entityAttributes = [:]
            onUnit(nil)
            onAttributes([])
            return
        }
        isFetching = true
        Task {
            let result = await WatchComplicationLivePreview.fetchState(entityId: entityId, server: server)
            await MainActor.run {
                isFetching = false
                guard let result else { return }
                entityState = result.state
                entityAttributes = result.attributes
                reportDerived()
            }
        }
    }
}

#if DEBUG
#Preview {
    // No entity selected → the panel renders the mock (sample) complications.
    AllFamiliesComplicationPreview(
        config: WatchComplicationConfig(serverId: "preview"),
        server: ServerFixture.standard,
        selectedFamily: .constant(.circular)
    )
    .padding()
}
#endif
