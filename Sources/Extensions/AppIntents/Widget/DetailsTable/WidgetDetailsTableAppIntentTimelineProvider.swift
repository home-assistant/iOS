import AppIntents
import HAKit
import RealmSwift
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetDetailsTableAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetDetailsTableEntry
    typealias Intent = WidgetDetailsTableAppIntent

    func snapshot(for configuration: WidgetDetailsTableAppIntent, in context: Context) async -> WidgetDetailsTableEntry {
        do {
            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.error("Using placeholder for detail table widget snapshot")
            return placeholder(in: context)
        }
    }

    func timeline(for configuration: WidgetDetailsTableAppIntent, in context: Context) async -> Timeline<Entry> {
        do {
            let snapshot = try await entry(for: configuration, in: context)
            return .init(
                entries: [snapshot],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetDetailsTableDataSource.expiration.converted(to: .seconds).value)
                )
            )
        } catch {
            Current.Log.debug("Using placeholder for detail table widget")
            return .init(
                entries: [placeholder(in: context)],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetDetailsTableDataSource.expiration.converted(to: .seconds).value)
                )
            )
        }
    }

    func placeholder(in context: Context) -> WidgetDetailsTableEntry {
        .init(
            sensorData: [
                WidgetDetailsTableEntry.SensorData(entityId: "1", key: "Solar Generation", value: "3404 Watt"),
                WidgetDetailsTableEntry.SensorData(entityId: "2", key: "Temperature", value: "22.4 C"),
                WidgetDetailsTableEntry.SensorData(entityId: "3", key: "Humidity", value: "56.4 %")
            ]
        )
    }

    private func entry(for configuration: WidgetDetailsTableAppIntent, in context: Context) async throws -> Entry {
        let sensorsGroupedByServer = Dictionary(grouping: configuration.sensors ?? [], by: { $0.serverId })

        var sensorValues: [WidgetDetailsTableEntry.SensorData] = []

        for (serverId, sensors) in sensorsGroupedByServer {
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
                throw WidgetDetailsTableDataError.noServers
            }
            
            for sensor in sensors {
                let sensorData = try await fetchSensorData(for: sensor, server: server)
                sensorValues.append(sensorData)
            }
        }

        return WidgetDetailsTableEntry(sensorData: sensorValues)
    }

    private func fetchSensorData(for sensor: IntentDetailsTableAppEntity, server: Server) async throws -> WidgetDetailsTableEntry.SensorData {
        let result = await withCheckedContinuation { continuation in
            Current.api(for: server).connection.send(.init(
                type: .rest(.get, "states/\(sensor.entityId)"),
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
                throw WidgetDetailsTableDataError.apiError
            }
        
        guard let data else {
            throw WidgetDetailsTableDataError.apiError
        }

        var state: [String: Any]?
        switch data {
        case let .dictionary(response):
            state = response
        default:
            Current.Log.error("Failed to render template for detail table widget: Bad response data")
            throw WidgetDetailsTableDataError.badResponse
        }

        let stateValue = (state?["state"] as? String) ?? "N/A"
        let unitOfMeasurement = (state?["attributes"] as? [String: Any])?["unit_of_measurement"] as? String

        return WidgetDetailsTableEntry.SensorData(
            entityId: sensor.entityId,
            key: sensor.displayString,
            value: stateValue,
            unitOfMeasurement: unitOfMeasurement
        )
    }
}

enum WidgetDetailsTableDataSource {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17, *)
struct WidgetDetailsTableEntry: TimelineEntry {
    var date = Date()

    var sensorData: [SensorData] = []
    
    struct SensorData {
        var entityId: String
        var key: String
        var value: String
        var unitOfMeasurement: String?
    }
}

enum WidgetDetailsTableDataError: Error {
    case noServers
    case apiError
    case badResponse
}
