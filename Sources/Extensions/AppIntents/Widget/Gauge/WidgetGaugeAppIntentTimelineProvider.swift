import AppIntents
import HAKit
import RealmSwift
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetGaugeAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetGaugeEntry
    typealias Intent = WidgetGaugeAppIntent

    func snapshot(for configuration: WidgetGaugeAppIntent, in context: Context) async -> WidgetGaugeEntry {
        // `context.isPreview` is WidgetKit's hook for the widget gallery, which renders with a
        // default (unconfigured) configuration. Unlike the other widgets (whose templates default
        // to "?"), the gauge's value template defaults to 0.0 — a numeric fill that renders as an
        // empty arc. Return a representative sample for the gallery; live widgets are unaffected.
        if context.isPreview {
            return Self.previewSample(for: configuration)
        }
        do {
            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.debug("Using placeholder for gauge widget snapshot")
            return placeholder(in: context)
        }
    }

    static func previewSample(for configuration: WidgetGaugeAppIntent) -> WidgetGaugeEntry {
        .init(
            gaugeType: configuration.gaugeType,
            value: 0.67,
            valueLabel: "67%",
            label: nil,
            min: "0",
            max: "100",
            runScript: false,
            script: nil,
            showConfirmationNotification: configuration.showConfirmationNotification
        )
    }

    func timeline(for configuration: WidgetGaugeAppIntent, in context: Context) async -> Timeline<Entry> {
        do {
            let snapshot = try await entry(for: configuration, in: context)
            return .init(
                entries: [snapshot],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetGaugeDataSource.expiration.converted(to: .seconds).value)
                )
            )
        } catch {
            Current.Log.debug("Using placeholder for gauge widget")
            return .init(
                entries: [placeholder(in: context)],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetGaugeDataSource.expiration.converted(to: .seconds).value)
                )
            )
        }
    }

    func placeholder(in context: Context) -> WidgetGaugeEntry {
        .init(
            gaugeType: .normal,
            value: 0.5,
            valueLabel: "?", min: "?", max: "?",
            runScript: false, script: nil, showConfirmationNotification: true
        )
    }

    private func entry(for configuration: WidgetGaugeAppIntent, in context: Context) async throws -> Entry {
        switch configuration.source {
        case .entity:
            return try await entityEntry(for: configuration)
        case .template:
            return try await templateEntry(for: configuration)
        }
    }

    /// Builds the gauge from a single picked entity's live state, fetched over the REST `/states`
    /// endpoint (no admin required). The 0…1 fill maps the numeric state across the configured
    /// `minValue`…`maxValue` range; labels are generated from the state, unit and range.
    private func entityEntry(for configuration: WidgetGaugeAppIntent) async throws -> Entry {
        guard let entity = configuration.entity else {
            Current.Log.error("Failed to fetch data for gauge widget: No entity selected")
            throw WidgetGaugeDataError.noServers
        }
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId })
            ?? configuration.server.getServer() ?? Current.servers.all.first else {
            Current.Log.error("Failed to fetch data for gauge widget: No servers exist")
            throw WidgetGaugeDataError.noServers
        }
        guard let resolved = await WidgetEntityAttributes.resolvedValue(
            entityId: entity.entityId,
            attribute: configuration.attribute?.id,
            server: server
        ) else {
            Current.Log.error("Failed to fetch value for gauge widget entity \(entity.entityId)")
            throw WidgetGaugeDataError.apiError
        }

        let numericValue = Double(resolved.value.replacingOccurrences(of: ",", with: ".")) ?? 0
        let range = configuration.maxValue - configuration.minValue
        let fraction = range != 0 ? Swift.min(Swift.max((numericValue - configuration.minValue) / range, 0), 1) : 0

        let valueLabel = resolved.unit.map { "\(resolved.value) \($0)" } ?? resolved.value

        return .init(
            gaugeType: configuration.gaugeType,

            value: fraction,

            valueLabel: valueLabel,
            label: configuration.gaugeType == .singleLabel ? entity.displayString : nil,
            min: configuration.gaugeType == .normal ? Self.formatBound(configuration.minValue) : nil,
            max: configuration.gaugeType == .normal ? Self.formatBound(configuration.maxValue) : nil,

            runScript: configuration.runScript,
            script: configuration.script,
            showConfirmationNotification: configuration.showConfirmationNotification
        )
    }

    /// Trims a trailing `.0` so whole-number bounds read as "100" rather than "100.0".
    private static func formatBound(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15 ? String(Int(value)) : String(value)
    }

    private func templateEntry(for configuration: WidgetGaugeAppIntent) async throws -> Entry {
        guard let server = configuration.server.getServer() ?? Current.servers.all.first,
              let connection = Current.api(for: server)?.connection else {
            Current.Log.error("Failed to fetch data for gauge widget: No servers exist")
            throw WidgetGaugeDataError.noServers
        }

        let valueTemplate = !configuration.valueTemplate.isEmpty ? configuration.valueTemplate : "0.0"
        let valueLabelTemplate = !configuration.valueLabelTemplate.isEmpty ? configuration.valueLabelTemplate : "?"
        let labelTemplate = !configuration.labelTemplate.isEmpty ? configuration.labelTemplate : "?"
        let maxTemplate = configuration.gaugeType == .normal && !configuration.maxTemplate.isEmpty ? configuration
            .maxTemplate : "?"
        let minTemplate = configuration.gaugeType == .normal && !configuration.minTemplate.isEmpty ? configuration
            .minTemplate : "?"
        let template = "\(valueTemplate)|\(valueLabelTemplate)|\(maxTemplate)|\(minTemplate)|\(labelTemplate)"

        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
                type: .rest(.post, "template"),
                data: ["template": template],
                shouldRetry: true
            )) { result in
                continuation.resume(returning: result)
            }
        }

        var data: HAData?
        switch result {
        case let .success(resultData):
            data = resultData
        case let .failure(error):
            Current.Log.error("Failed to render template for gauge widget: \(error)")
            throw WidgetGaugeDataError.apiError
        }

        guard let data else {
            throw WidgetGaugeDataError.apiError
        }

        var renderedTemplate: String?
        switch data {
        case let .primitive(response):
            renderedTemplate = response as? String
        default:
            Current.Log.error("Failed to render template for gauge widget: Bad response data")
            throw WidgetGaugeDataError.badResponse
        }

        let params = renderedTemplate?.split(separator: "|") ?? []
        guard params.count == 5 else {
            Current.Log.error("Failed to render template for gauge widget: Wrong length response")
            throw WidgetGaugeDataError.badResponse
        }

        let valueText = String(params[1])
        let maxText = String(params[2])
        let minText = String(params[3])
        let labelText = String(params[4])

        return .init(
            gaugeType: configuration.gaugeType,

            value: Double(params[0]) ?? 0.0,

            valueLabel: valueText != "?" ? valueText : nil,
            label: labelText != "?" ? labelText : nil,
            min: minText != "?" ? minText : nil,
            max: maxText != "?" ? maxText : nil,

            runScript: configuration.runScript,
            script: configuration.script,
            showConfirmationNotification: configuration.showConfirmationNotification
        )
    }
}

enum WidgetGaugeDataSource {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17, *)
struct WidgetGaugeEntry: TimelineEntry {
    var date = Date()

    var gaugeType: GaugeTypeAppEnum

    var value: Double

    var valueLabel: String?
    var label: String?
    var min: String?
    var max: String?

    var runScript: Bool
    var script: IntentScriptEntity?
    var showConfirmationNotification: Bool
}

enum WidgetGaugeDataError: Error {
    case noServers
    case apiError
    case badResponse
}
