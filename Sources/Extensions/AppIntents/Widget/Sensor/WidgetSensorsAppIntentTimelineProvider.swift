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
                        displayString: sensor.name,
                        icon: sensor.icon
                    )
                }
            }.prefix(WidgetFamilySizes.sizeForPreview(for: context.family)))
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
        let count = WidgetFamilySizes.size(for: context.family)
        let sensors = stride(from: 0, to: count, by: 1).map { index in
            WidgetSensorsEntry.SensorData(id: String(index), key: "?", value: "?")
        }

        return WidgetSensorsEntry(
            sensorData: sensors
        )
    }

    private func entry(for configuration: WidgetSensorsAppIntent, in context: Context) async throws -> Entry {
        var sensorValues: [WidgetSensorsEntry.SensorData] = []

        for sensor in configuration.sensors ?? [] {
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == sensor.serverId }) else {
                throw WidgetSensorsDataError.noServers
            }

            let sensorData = try await fetchSensorData(for: sensor, server: server)
            sensorValues.append(sensorData)
        }

        return WidgetSensorsEntry(sensorData: sensorValues)
    }

    private func fetchSensorData(
        for sensor: IntentSensorsAppEntity,
        server: Server
    ) async throws -> WidgetSensorsEntry.SensorData {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch sensor data")
            throw HomeAssistantAPI.APIError.noAPIAvailable
        }

        let result = await withCheckedContinuation { continuation in
            connection.send(.init(
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

        var stateValue = (state?["state"] as? String) ?? "N/A"
        stateValue = adjustPrecision(
            serverId: server.identifier.rawValue,
            entityId: sensor.entityId,
            stateValue: stateValue
        )
        let unitOfMeasurement = (state?["attributes"] as? [String: Any])?["unit_of_measurement"] as? String
        stateValue = capitalizeFirstLetter(stateValue)
        return WidgetSensorsEntry.SensorData(
            id: sensor.id,
            key: sensor.displayString,
            value: stateValue,
            unitOfMeasurement: unitOfMeasurement,
            icon: sensor.icon
        )
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }

    private func adjustPrecision(serverId: String, entityId: String, stateValue: String) -> String {
        guard let stateValueFloat = Float(stateValue) else {
            return stateValue
        }
        if let decimalPlacesForEntityId: Int = {
            do {
                return try Current.database.read { db in
                    try AppEntityRegistryListForDisplay
                        .filter(
                            Column(DatabaseTables.AppEntityRegistryListForDisplay.id.rawValue) == ServerEntity
                                .uniqueId(
                                    serverId: serverId,
                                    entityId: entityId
                                )
                        )
                        .fetchOne(db)?.registry.decimalPlaces
                }
            } catch {
                Current.Log.error("Failed to fetch decimal places for entity ID: \(entityId)")
                return nil
            }
        }() {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.locale = Locale.current
            numberFormatter.maximumFractionDigits = decimalPlacesForEntityId
            numberFormatter.minimumFractionDigits = decimalPlacesForEntityId
            return numberFormatter.string(from: NSNumber(value: stateValueFloat)) ?? stateValue
        } else {
            return stateValue
        }
    }

    private func suggestions() async -> [(Server, [HAAppEntity])] {
        ControlEntityProvider(domains: WidgetSensorsConfig.domains).getEntities()
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
        var id: String
        var key: String
        var value: String
        var unitOfMeasurement: String?
        var icon: String?
    }
}

enum WidgetSensorsDataError: Error {
    case noServers
    case apiError
    case badResponse
}
