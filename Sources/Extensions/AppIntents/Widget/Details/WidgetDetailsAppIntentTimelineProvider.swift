import AppIntents
import HAKit
import RealmSwift
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetDetailsAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetDetailsEntry
    typealias Intent = WidgetDetailsAppIntent

    func snapshot(for configuration: WidgetDetailsAppIntent, in context: Context) async -> WidgetDetailsEntry {
        do {
            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.debug("Using placeholder for gauge widget snapshot")
            return placeholder(in: context)
        }
    }

    func timeline(for configuration: WidgetDetailsAppIntent, in context: Context) async -> Timeline<Entry> {
        do {
            let snapshot = try await entry(for: configuration, in: context)
            return .init(
                entries: [snapshot],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetDetailsDataSource.expiration.converted(to: .seconds).value)
                )
            )
        } catch {
            Current.Log.debug("Using placeholder for gauge widget")
            return .init(
                entries: [placeholder(in: context)],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetDetailsDataSource.expiration.converted(to: .seconds).value)
                )
            )
        }
    }

    func placeholder(in context: Context) -> WidgetDetailsEntry {
        .init(
            upperText: nil, lowerText: nil, detailsText: nil,
            runScript: false, script: nil, showConfirmationNotification: true
        )
    }

    private func entry(for configuration: WidgetDetailsAppIntent, in context: Context) async throws -> Entry {
        guard let server = configuration.server.getServer() ?? Current.servers.all.first,
              let connection = Current.api(for: server)?.connection else {
            Current.Log.error("Failed to fetch data for details widget: No servers exist")
            throw WidgetDetailsDataError.noServers
        }

        let upperTemplate = !configuration.upperTemplate.isEmpty ? configuration.upperTemplate : "?"
        let lowerTemplate = !configuration.lowerTemplate.isEmpty ? configuration.lowerTemplate : "?"
        let detailsTemplate = !configuration.detailsTemplate.isEmpty ? configuration.detailsTemplate : "?"
        let template = "\(upperTemplate)|\(lowerTemplate)|\(detailsTemplate)"

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
            Current.Log.error("Failed to render template for details widget: \(error)")
            throw WidgetDetailsDataError.apiError
        }
        guard let data else {
            throw WidgetDetailsDataError.apiError
        }
        var renderedTemplate: String?
        switch data {
        case let .primitive(response):
            renderedTemplate = response as? String
        default:
            Current.Log.error("Failed to render template for details widget: Bad response data")
            throw WidgetDetailsDataError.badResponse
        }

        let params = renderedTemplate?.split(separator: "|") ?? []
        guard params.count == 3 else {
            Current.Log.error("Failed to render template for details widget: Wrong length response")
            throw WidgetDetailsDataError.badResponse
        }

        let upperText = String(params[0])
        let lowerText = String(params[1])
        let detailsText = String(params[2])

        return .init(
            upperText: upperText != "?" ? upperText : nil,
            lowerText: lowerText != "?" ? lowerText : nil,
            detailsText: detailsText != "?" ? detailsText : nil,

            runScript: configuration.runScript,
            script: configuration.script,
            showConfirmationNotification: configuration.showConfirmationNotification
        )
    }
}

enum WidgetDetailsDataSource {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17, *)
struct WidgetDetailsEntry: TimelineEntry {
    var date = Date()

    var upperText: String?
    var lowerText: String?
    var detailsText: String?

    var runScript: Bool
    var script: IntentScriptEntity?
    var showConfirmationNotification: Bool
}

enum WidgetDetailsDataError: Error {
    case noServers
    case apiError
    case badResponse
}
