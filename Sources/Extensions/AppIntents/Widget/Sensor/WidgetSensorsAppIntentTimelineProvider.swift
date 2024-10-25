import AppIntents
import GRDB
import HAKit
import PromiseKit
import RealmSwift
import Shared
import WidgetKit

@available(iOS 17, *)
struct WidgetSensorsAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetSensorsEntry
    typealias Intent = WidgetSensorsAppIntent

    func snapshot(
        for configuration: WidgetSensorsAppIntent,
        in context: Context
    ) async -> WidgetSensorsEntry {
        do {
            let suggestions = await suggestions()
            configuration.sensors = Array(suggestions.flatMap { key, value in
                value.map { sensor in
                    IntentSensorsAppEntity(
                        id: sensor.id,
                        entityId: sensor.entityId,
                        serverId: key.identifier.rawValue,
                        displayString: sensor.name
                    )
                }
            }.prefix(upTo: 3))
            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.error("Using placeholder for sensor widget snapshot")
            return placeholder(in: context)
        }
    }

    func timeline(for configuration: WidgetSensorsAppIntent, in context: Context) async -> Timeline<Entry> {
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
            Current.Log.debug("Using placeholder for sensor widget")
            return .init(
                entries: [placeholder(in: context)],
                policy: .after(
                    Current.date()
                        .addingTimeInterval(WidgetDetailsTableDataSource.expiration.converted(to: .seconds).value)
                )
            )
        }
    }

    func placeholder(in context: Context) -> WidgetSensorsEntry {
        .init(
            sensorData: [
                WidgetSensorsEntry.SensorData(entityId: "1", key: "Solar Generation", value: "3404 Watt"),
                WidgetSensorsEntry.SensorData(entityId: "2", key: "Temperature", value: "22.4 C"),
                WidgetSensorsEntry.SensorData(entityId: "3", key: "Humidity", value: "56.4 %"),
            ]
        )
    }

    private func entry(for configuration: WidgetSensorsAppIntent, in context: Context) async throws -> Entry {
        let sensorsGroupedByServer = Dictionary(grouping: configuration.sensors ?? [], by: { $0.serverId })

        var sensorValues: [WidgetSensorsEntry.SensorData] = []

        for (serverId, sensors) in sensorsGroupedByServer {
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
                throw WidgetSensorsDataError.noServers
            }

            for sensor in sensors {
                let sensorData = try await fetchSensorData(for: sensor, server: server)
                sensorValues.append(sensorData)
            }
        }

        return WidgetSensorsEntry(sensorData: sensorValues)
    }

    private func fetchSensorData(
        for sensor: IntentSensorsAppEntity,
        server: Server
    ) async throws -> WidgetSensorsEntry.SensorData {
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
            throw WidgetSensorsDataError.apiError
        }

        guard let data else {
            throw WidgetSensorsDataError.apiError
        }

        var state: [String: Any]?
        switch data {
        case let .dictionary(response):
            state = response
        default:
            Current.Log.error("Failed to render template for sensor widget: Bad response data")
            throw WidgetSensorsDataError.badResponse
        }

        let stateValue = (state?["state"] as? String) ?? "N/A"
        let unitOfMeasurement = (state?["attributes"] as? [String: Any])?["unit_of_measurement"] as? String

        return WidgetSensorsEntry.SensorData(
            entityId: sensor.entityId,
            key: sensor.displayString,
            value: stateValue,
            unitOfMeasurement: unitOfMeasurement
        )
    }

    private func suggestions() async -> [Server: [HAAppEntity]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [HAAppEntity]] = [:]
            var serverCheckedCount = 0
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                do {
                    let scripts: [HAAppEntity] = try Current.database().read { db in
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.sensor.rawValue)
                            .fetchAll(db)
                    }
                    entities[server] = scripts
                } catch {
                    Current.Log.error("Failed to load sensors from database: \(error.localizedDescription)")
                }
                serverCheckedCount += 1
                if serverCheckedCount == Current.servers.all.count {
                    continuation.resume(returning: entities)
                }
            }
        }
    }
}

enum WidgetDetailsTableDataSource {
    static var expiration: Measurement<UnitDuration> {
        .init(value: 15, unit: .minutes)
    }
}

@available(iOS 17, *)
struct WidgetSensorsEntry: TimelineEntry {
    var date = Date()

    var sensorData: [SensorData] = []

    struct SensorData {
        var entityId: String
        var key: String
        var value: String
        var unitOfMeasurement: String?
    }
}

enum WidgetSensorsDataError: Error {
    case noServers
    case apiError
    case badResponse
}
