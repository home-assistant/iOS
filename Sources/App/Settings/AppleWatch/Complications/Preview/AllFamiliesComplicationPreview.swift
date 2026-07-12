import Shared
import SwiftUI

/// Shows the complication in all four WidgetKit families at once, arranged like an Apple Watch face,
/// so the user sees every size simultaneously instead of flipping a size picker. Fetches the entity
/// state once and renders every family from that single fetch.
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
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 72, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.28), Color(white: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 244, height: 300)
                    .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

                RoundedRectangle(cornerRadius: 64, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    .frame(width: 230, height: 286)

                RoundedRectangle(cornerRadius: 58, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 214, height: 270)
                    .overlay {
                        ZStack {
                            familyButton(.circular)
                                .position(x: 58, y: 68)
                            familyButton(.corner)
                                .position(x: 156, y: 68)
                            familyButton(.rectangular)
                                .position(x: 107, y: 148)
                            familyButton(.inline)
                                .position(x: 107, y: 226)
                        }
                        .frame(width: 214, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 58, style: .continuous))
                    }
            }
            .frame(width: 260, height: 316)

            if isFetching {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .padding(DesignSystem.Spaces.two)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spaces.two)
        .environment(\.colorScheme, .dark)
        // Re-run the fetch/render whenever a fetch input changes (entity, server, kind, template) —
        // reliably, so the preview updates on entity change without needing to tap a family first.
        .task(id: fetchKey) { refresh() }
    }

    @ViewBuilder
    private func familyButton(_ family: WatchComplicationConfig.Family) -> some View {
        Button {
            selectedFamily = family
        } label: {
            preview(for: family)
                .padding(DesignSystem.Spaces.half)
                .overlay {
                    if selectedFamily == family {
                        switch family {
                        case .circular, .corner:
                            Circle()
                                .stroke(Color.accentColor, lineWidth: 2)
                                .padding(10)
                        case .rectangular:
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2)
                        case .inline:
                            Capsule()
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: family.title))
        .accessibilityAddTraits(selectedFamily == family ? .isSelected : [])
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
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            AllFamiliesComplicationPreview(
                config: WatchComplicationConfig(serverId: "preview"),
                server: ServerFixture.standard,
                selectedFamily: .constant(.circular)
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Solar",
                        iconName: "solar-power",
                        iconColor: "#FFD60AFF"
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(
                            showIcon: true,
                            showMin: false,
                            showMax: false,
                            tint: "#FFD60AFF",
                            gaugeStyle: WatchComplicationConfig.GaugeStyle.capacity.rawValue
                        ),
                        for: .circular
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(tint: "#FFD60AFF"),
                        for: .corner
                    )
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .constant(.corner)
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Humidity",
                        iconName: "water-percent",
                        iconColor: "#64D2FFFF"
                    )
                    for family in WatchComplicationConfig.Family.allCases {
                        config.setOptions(
                            WatchComplicationConfig.FamilyOptions(showGauge: false, tint: "#64D2FFFF"),
                            for: family
                        )
                    }
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .constant(.rectangular)
            )
        }
        .padding()
    }
}
#endif
