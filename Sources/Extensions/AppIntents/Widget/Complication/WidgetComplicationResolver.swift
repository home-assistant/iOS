import Foundation
import HAKit
import Shared

/// Loads a watch complication the user already built and resolves it into the shared
/// `ComplicationRenderContext`, so a lock-screen widget can render it through the very same content
/// views the watch and the complication editor use.
@available(iOS 17.0, *)
enum WidgetComplicationResolver {
    enum ResolveError: Error {
        case noComplication
        case noServer
        case unavailable
    }

    /// The user's complications for a family, in the order they appear in the app.
    static func configs(family: WatchComplicationConfig.Family) -> [WatchComplicationConfig] {
        do {
            return try WatchComplicationConfig.all().filter { $0.widgetFamily == family }
        } catch {
            Current.Log.error("Failed to load complication configs for widget: \(error)")
            return []
        }
    }

    /// Resolves the complication with `id` against live data. Entity complications read the plain
    /// `/states` API; template complications render their templates server-side (admin only, same as
    /// the widgets' template source).
    static func context(
        id: String,
        family: WatchComplicationConfig.Family
    ) async throws -> ComplicationRenderContext {
        guard let config = configs(family: family).first(where: { $0.id == id }) else {
            Current.Log.error("Failed to render complication widget: complication \(id) no longer exists")
            throw ResolveError.noComplication
        }
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == config.serverId }) else {
            Current.Log.error("Failed to render complication widget: server \(config.serverId) no longer exists")
            throw ResolveError.noServer
        }

        switch config.kind {
        case .entity:
            return try await entityContext(config: config, family: family, server: server)
        case .customTemplate:
            return await templateContext(config: config, family: family, server: server)
        }
    }

    private static func entityContext(
        config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family,
        server: Server
    ) async throws -> ComplicationRenderContext {
        guard let entityId = config.entityId else {
            throw ResolveError.noComplication
        }
        guard let fetched = await ControlEntityProvider(domains: []).rawState(server: server, entityId: entityId) else {
            Current.Log.error("Failed to fetch state for complication widget entity \(entityId)")
            throw ResolveError.unavailable
        }
        return .entity(
            config: config,
            family: family,
            state: fetched.state,
            attributes: fetched.attributes
        )
    }

    /// Template complications render their text, gauge and color templates server-side. A template
    /// that fails to render keeps the statically configured value rather than blanking the face, which
    /// is what the watch does too.
    private static func templateContext(
        config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family,
        server: Server
    ) async -> ComplicationRenderContext {
        var familyConfig = config
        familyConfig.widgetFamily = family

        let value = await render(config.customTextTemplate, server: server) ?? ""
        let renderedGauge = await render(config.customGaugeTemplate, server: server)
        let fraction = renderedGauge
            .flatMap { WatchComplication.percentileNumber(from: $0) }
            .map { Swift.min(Swift.max(Double($0), 0), 1) }

        // Color templates override the static pickers on every size, exactly as on the watch.
        if let iconColor = await renderColor(config.customIconColorTemplate, server: server) {
            familyConfig.iconColor = iconColor
        }
        let gaugeColor = await renderColor(config.customGaugeColorTemplate, server: server)
        let textColor = await renderColor(config.customTextColorTemplate, server: server)
        var options = familyConfig.options(for: family)
        options.tint = gaugeColor ?? options.tint
        options.textColor = textColor ?? options.textColor
        // A template complication gauges off its gauge template, not a numeric range: the watch draws
        // one whenever that template rendered, unless the size explicitly turned the gauge off.
        if options.showGauge != false {
            options.showGauge = fraction != nil
        }
        familyConfig.setOptions(options, for: family)

        // Slot formulas may reference further templates; each is rendered once, the main one reused.
        var renderedTemplates: [String: String] = [:]
        if let mainTemplate = config.customTextTemplate {
            renderedTemplates[mainTemplate] = value
        }
        let slotTemplates = Set((familyConfig.families ?? [:]).values
            .flatMap { ($0.slots ?? [:]).values }
            .flatMap { $0.formula?.templates ?? [] })
            .subtracting(renderedTemplates.keys)
        for template in slotTemplates {
            if let rendered = await render(template, server: server) {
                renderedTemplates[template] = rendered
            }
        }

        return ComplicationRenderContext(
            config: familyConfig,
            value: value,
            fraction: fraction,
            iconImage: ComplicationRenderContext.icon(for: familyConfig, family: family),
            renderedTemplates: renderedTemplates
        )
    }

    private static func renderColor(_ template: String?, server: Server) async -> String? {
        guard let rendered = await render(template, server: server) else { return nil }
        return WatchComplicationConfig.normalizedHexColor(from: rendered)
    }

    private static func render(_ template: String?, server: Server) async -> String? {
        guard let template, !template.isEmpty, let connection = Current.api(for: server)?.connection else {
            return nil
        }
        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.post, "template"),
                data: ["template": template],
                shouldRetry: true
            )) { result in
                continuation.resume(returning: result)
            }
        }
        switch result {
        case let .success(data):
            guard case let .primitive(response) = data, let rendered = response as? String else {
                Current.Log.error("Failed to render complication widget template: bad response data")
                return nil
            }
            return rendered
        case let .failure(error):
            Current.Log.error("Failed to render complication widget template: \(error)")
            return nil
        }
    }
}
