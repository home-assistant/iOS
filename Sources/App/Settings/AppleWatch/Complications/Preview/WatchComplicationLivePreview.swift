import Alamofire
import Foundation
import PromiseKit
import Shared
import SwiftUI

#if DEBUG
extension ComplicationRenderContext {
    /// Sample context used by the per-family preview SwiftUI previews.
    static func preview(_ family: WatchComplicationConfig.Family, gauge: Bool = true) -> ComplicationRenderContext {
        var config = WatchComplicationConfig(
            serverId: "preview",
            widgetFamily: family,
            name: "Battery",
            iconName: "battery-70",
            iconColor: "#34C759FF"
        )
        if gauge {
            config.gaugeMin = 0
            config.gaugeMax = 100
        }
        return ComplicationRenderContext(
            config: config,
            value: "68%",
            fraction: gauge ? 0.68 : nil,
            iconImage: Image(systemSymbol: .battery75)
        )
    }

    /// Corner-specific sample with individually toggleable value / name / icon / gauge, used to preview
    /// the corner layout's permutations.
    static func previewCorner(
        value: String = "68%",
        name: String = "Battery",
        showValue: Bool = true,
        showName: Bool = true,
        showIcon: Bool = true,
        gauge: Bool = true
    ) -> ComplicationRenderContext {
        var config = WatchComplicationConfig(serverId: "preview", widgetFamily: .corner, name: name)
        if gauge {
            config.gaugeMin = 0
            config.gaugeMax = 100
        }
        config.setOptions(
            WatchComplicationConfig.FamilyOptions(
                showName: showName,
                showValue: showValue,
                showIcon: showIcon,
                showGauge: gauge,
                tint: "#34C759FF"
            ),
            for: .corner
        )
        return ComplicationRenderContext(
            config: config,
            value: value,
            fraction: gauge ? 0.68 : nil,
            iconImage: showIcon ? Image(systemSymbol: .battery75) : nil
        )
    }
}
#endif

/// A live approximation of the watch complication, rendered on iPhone with current data so the user
/// sees the real result before saving. Entity complications fetch their value over the plain REST
/// states API (no admin-only templating); only the custom-template kind renders templates.
struct WatchComplicationLivePreview: View {
    let config: WatchComplicationConfig
    let server: Server
    /// Reports the entity's unit of measurement (nil when it has none) so the editor can decide whether
    /// to offer the "Show unit" toggle.
    var onUnit: (String?) -> Void = { _ in }
    /// Reports the entity's attribute names (sorted) so the editor can offer them as value sources.
    var onAttributes: ([String]) -> Void = { _ in }

    // Template rendering is used only for the custom-template kind.
    @StateObject private var valueRenderer: TemplateRenderer
    @StateObject private var gaugeRenderer: TemplateRenderer

    // Live entity state, fetched over REST for the entity kind.
    @State private var entityState: String = ""
    @State private var entityAttributes: [String: Any] = [:]
    @State private var isFetching = false
    /// The inputs a fetch actually depends on. Changing only the value source / unit / precision reuses
    /// the already-fetched attributes instead of triggering a fresh (slow) REST call, so the value and
    /// unit update together immediately.
    @State private var lastFetchKey: String?

    private var fetchKey: String {
        [
            config.kind.rawValue,
            config.serverId,
            config.entityId ?? "",
            config.customTextTemplate ?? "",
            config.customGaugeTemplate ?? "",
        ].joined(separator: "|")
    }

    init(
        config: WatchComplicationConfig,
        server: Server,
        onUnit: @escaping (String?) -> Void = { _ in },
        onAttributes: @escaping ([String]) -> Void = { _ in }
    ) {
        self.config = config
        self.server = server
        self.onUnit = onUnit
        self.onAttributes = onAttributes
        _valueRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
        _gaugeRenderer = StateObject(wrappedValue: TemplateRenderer(server: server))
    }

    // MARK: - Value / fraction / unit

    private var value: String {
        switch config.kind {
        case .entity:
            guard !entityState.isEmpty else { return "" }
            // The value can come from an entity attribute instead of the state.
            let raw = config.valueAttribute
                .flatMap { entityAttributes[$0] }
                .map { String(describing: $0) } ?? entityState
            return Self.formatValue(raw, unit: displayUnit, precision: entityPrecision)
        case .customTemplate:
            if case let .success(rendered) = valueRenderer.output { return rendered }
            return ""
        }
    }

    /// The unit for the current value source, derived synchronously from the already-fetched attributes
    /// so switching between the state / attributes updates the unit immediately (no stale re-fetch
    /// window). The state's `unit_of_measurement` only applies to the state; an attribute resolves its
    /// own unit (weather `*_unit`, known percentages, …) or none.
    private var resolvedUnit: String? {
        guard config.kind == .entity else { return nil }
        if let attribute = config.valueAttribute {
            return WatchComplicationConfig.attributeUnit(
                attribute: attribute,
                attributes: entityAttributes,
                domain: config.entityId?.components(separatedBy: ".").first
            )
        }
        return entityAttributes["unit_of_measurement"] as? String
    }

    /// The unit actually shown: the user's override when set, otherwise the resolved unit; nil when the
    /// "Show unit" toggle is off.
    private var displayUnit: String? {
        guard config.showsUnit() else { return nil }
        if let override = config.unitOverride, !override.isEmpty { return override }
        return resolvedUnit
    }

    private var fraction: Double? {
        switch config.kind {
        case .entity:
            guard let range = config.gaugeRange(for: config.widgetFamily) else { return nil }
            let source: Any = config.gaugeAttribute(for: config.widgetFamily)
                .flatMap { entityAttributes[$0] }
                ?? config.valueAttribute.flatMap { entityAttributes[$0] }
                ?? entityState
            guard let raw = WatchComplication.percentileNumber(from: source), range.max > range.min else {
                return nil
            }
            return min(max((Double(raw) - range.min) / (range.max - range.min), 0), 1)
        case .customTemplate:
            guard case let .success(rendered) = gaugeRenderer.output,
                  let raw = WatchComplication.percentileNumber(from: rendered) else {
                return nil
            }
            return min(max(Double(raw), 0), 1)
        }
    }

    /// Display precision: the user's override when set, otherwise Home Assistant's from the registry.
    private var entityPrecision: Int? {
        if let override = config.valuePrecision { return override }
        guard let entityId = config.entityId else { return nil }
        return EntityRegistryListForDisplay.Entity.displayPrecision(serverId: config.serverId, entityId: entityId)
    }

    private var iconColor: Color {
        config.iconColor.map { Color(uiColor: UIColor(hex: $0)) } ?? .white
    }

    private var iconImage: Image? {
        guard config.isSlotVisible(.icon, for: config.widgetFamily), let iconName = config.iconName else { return nil }
        let image = MaterialDesignIcons(serversideValueNamed: iconName)
            .image(ofSize: CGSize(width: 64, height: 64), color: UIColor(iconColor))
        return Image(uiImage: image)
    }

    private var isLoading: Bool {
        switch config.kind {
        case .entity: return isFetching
        case .customTemplate: return [valueRenderer.output, gaugeRenderer.output].contains(.loading)
        }
    }

    private var context: ComplicationRenderContext {
        switch config.kind {
        case .entity:
            return .entity(
                config: config,
                family: config.widgetFamily,
                state: entityState,
                attributes: entityAttributes
            )
        case .customTemplate:
            return ComplicationRenderContext(
                config: config,
                value: value,
                fraction: fraction,
                iconImage: iconImage,
                renderedTemplates: config.customTextTemplate.map { [$0: value] } ?? [:]
            )
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            // Spinner tucked in the corner so it doesn't cover the preview content.
            .overlay(alignment: .topTrailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(6)
                }
            }
            .onAppear(perform: refresh)
            // Re-fetch/re-render whenever the config changes (e.g. the user picks a different entity).
            .onChange(of: config) { _ in refresh() }
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

    // MARK: - Data loading

    private func refresh() {
        switch config.kind {
        case .entity:
            // Only hit the network when a fetch input changed; otherwise recompute the reported
            // unit/attributes from the cached data so switching value source updates instantly.
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

    /// Report the resolved unit and attribute names for the current config off the already-fetched data.
    private func reportDerived() {
        onUnit(resolvedUnit)
        onAttributes(entityAttributes.keys.sorted())
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
            let result = await Self.fetchState(entityId: entityId, server: server)
            await MainActor.run {
                isFetching = false
                guard let result else { return }
                entityState = result.state
                entityAttributes = result.attributes
                reportDerived()
            }
        }
    }

    // MARK: - REST helpers (plain states API — no admin-only templating)

    struct EntityState {
        let state: String
        let attributes: [String: Any]
    }

    static func fetchState(entityId: String, server: Server) async -> EntityState? {
        guard let baseURL = await server.activeURL() else { return nil }
        guard let token = await bearerToken(for: server) else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else {
            return nil
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            // The server rejected a token the client still considered valid; invalidate it so the
            // next fetch refreshes instead of re-sending it (which the server logs as invalid auth
            // and eventually answers with an IP ban).
            if http.statusCode == 401 {
                let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
                tokenManager.handleAccessTokenRejected(token)
            }
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return nil
        }
        return EntityState(state: state, attributes: json["attributes"] as? [String: Any] ?? [:])
    }

    static func bearerToken(for server: Server) async -> String? {
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        return try? await withCheckedThrowingContinuation { continuation in
            tokenManager.bearerToken.done { token, _ in
                continuation.resume(returning: token)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

    static func formatValue(_ state: String, unit: String?, precision: Int?) -> String {
        ComplicationRenderContext.formatValue(state, unit: unit, precision: precision)
    }
}
