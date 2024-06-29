import AppIntents
import RealmSwift
import Shared
import WidgetKit
import HAKit

@available(iOS 17, *)
struct WidgetGaugeAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetGaugeEntry
    typealias Intent = WidgetGaugeAppIntent

    func snapshot(for configuration: WidgetGaugeAppIntent, in context: Context) async -> WidgetGaugeEntry {
        do {
            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.debug("Using placeholder for gauge widget snapshot")
            return placeholder(in: context)
        }
    }

    func timeline(for configuration: WidgetGaugeAppIntent, in context: Context) async -> Timeline<Entry> {
        do {
            let snapshot = try await entry(for: configuration, in: context)
            Current.Log.debug("Reloading gauge widget")
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
                        .addingTimeInterval(WidgetGaugeDataSource.fastExpiration.converted(to: .seconds).value)
                )
            )
        }
    }

    func placeholder(in context: Context) -> WidgetGaugeEntry {
        .init(
            gaugeType: .normal,
            value: 0.5,
            valueLabel: "?", max: "?", min: "?",
            runAction: false, action: nil
        )
    }

    private func entry(for configuration: WidgetGaugeAppIntent, in context: Context) async throws -> Entry {
        guard Current.servers.all.count > 0 else {
            Current.Log.error("Failed to fetch data for gauge widget: No servers exist")
            throw WidgetGaugeDataError.noServers
        }
        
        let server = configuration.server.getServer() ?? Current.servers.all.first!
        let api = Current.api(for: server)
        
        let valueTemplate = !configuration.valueTemplate.isEmpty ? configuration.valueTemplate : "0"
        let valueLabelTemplate = !configuration.valueLabelTemplate.isEmpty ? configuration.valueLabelTemplate : "0"
        let maxTemplate = configuration.gaugeType == .normal && !configuration.maxTemplate.isEmpty ? configuration.maxTemplate : "0"
        let minTemplate = configuration.gaugeType == .normal && !configuration.minTemplate.isEmpty ? configuration.minTemplate : "0"
        let template = "\(valueTemplate)|\(valueLabelTemplate)|\(maxTemplate)|\(minTemplate)"
        
        let result = await withCheckedContinuation { continuation in
            api.connection.send(.init(type: .rest(.post, "template"), data: ["template": template], shouldRetry: true)) { result in
                continuation.resume(returning: result)
            }
        }
        
        var data: HAData?
        switch (result) {
        case let .success(resultData):
            data = resultData
        case let .failure(error):
            Current.Log.error("Failed to render template for gauge widget: \(error)")
            throw WidgetGaugeDataError.apiError
        }
        
        var renderedTemplate: String?
        switch (data!) {
        case let .primitive(response):
            renderedTemplate = response as? String
        default:
            Current.Log.error("Failed to render template for gauge widget: Bad response data")
            throw WidgetGaugeDataError.badResponse
        }
        
        let params = renderedTemplate!.split(separator: "|")
        guard params.count == 4 else {
            Current.Log.error("Failed to render template for gauge widget: Wrong length response")
            throw WidgetGaugeDataError.badResponse
        }
        
        return .init(
            gaugeType: configuration.gaugeType,
            
            value: Double(params[0]) ?? 0.0,
            
            valueLabel: String(params[1]),
            max: String(params[2]),
            min: String(params[3]),
            
            runAction: configuration.runAction,
            action: configuration.action?.asAction()
        )
    }
}

enum WidgetGaugeDataSource {
    static var expiration: Measurement<UnitDuration> {
//        .init(value: 2, unit: .hours)
        .init(value: 2, unit: .minutes)
    }
    
    static var fastExpiration: Measurement<UnitDuration> {
        .init(value: 1, unit: .hours)
    }
}

@available(iOS 17, *)
struct WidgetGaugeEntry: TimelineEntry {
    var date = Date()
    
    var gaugeType: GaugeTypeAppEnum
    
    var value: Double
    
    var valueLabel: String
    var max: String
    var min: String
    
    var runAction: Bool
    var action: Action?
}

enum WidgetGaugeDataError: Error {
    case noServers
    case apiError
    case badResponse
}
