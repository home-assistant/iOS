import Alamofire
import Foundation
import PromiseKit
import Shared
import SwiftUI

/// The resolved rendering inputs a per-family preview needs. Bundled so the family views stay small and
/// don't each re-derive the same styling from the config.
struct ComplicationPreviewContext {
    let config: WatchComplicationConfig
    /// The value text (already unit-appended when applicable).
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
    @State private var entityUnit: String?
    @State private var isFetching = false

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
            let unit = config.showsUnit() ? entityUnit : nil
            // The value can come from an entity attribute instead of the state.
            let raw = config.valueAttribute
                .flatMap { entityAttributes[$0] }
                .map { String(describing: $0) } ?? entityState
            return Self.formatValue(raw, unit: unit, precision: entityPrecision)
        case .customTemplate:
            if case let .success(rendered) = valueRenderer.output { return rendered }
            return ""
        }
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

    /// Display precision comes from the entity registry (never duplicated into the config).
    private var entityPrecision: Int? {
        guard let entityId = config.entityId else { return nil }
        return EntityRegistryListForDisplay.Entity.displayPrecision(serverId: config.serverId, entityId: entityId)
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

    private var isLoading: Bool {
        switch config.kind {
        case .entity: return isFetching
        case .customTemplate: return [valueRenderer.output, gaugeRenderer.output].contains(.loading)
        }
    }

    private var context: ComplicationPreviewContext {
        ComplicationPreviewContext(config: config, value: value, fraction: fraction, iconImage: iconImage)
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
            fetchEntityState()
        case .customTemplate:
            valueRenderer.updateTemplate(config.customTextTemplate ?? "")
            gaugeRenderer.updateTemplate(config.customGaugeTemplate ?? "")
        }
    }

    private func fetchEntityState() {
        guard let entityId = config.entityId else {
            entityState = ""
            entityAttributes = [:]
            entityUnit = nil
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
                entityUnit = result.attributes["unit_of_measurement"] as? String
                onUnit(entityUnit)
                onAttributes(result.attributes.keys.sorted())
            }
        }
    }

    // MARK: - REST helpers (plain states API — no admin-only templating)

    private struct EntityState {
        let state: String
        let attributes: [String: Any]
    }

    private static func fetchState(entityId: String, server: Server) async -> EntityState? {
        guard let baseURL = await server.activeURL() else { return nil }
        guard let token = await bearerToken(for: server) else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return nil
        }
        return EntityState(state: state, attributes: json["attributes"] as? [String: Any] ?? [:])
    }

    private static func bearerToken(for server: Server) async -> String? {
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        return try? await withCheckedThrowingContinuation { continuation in
            tokenManager.bearerToken.done { token, _ in
                continuation.resume(returning: token)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

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
}
