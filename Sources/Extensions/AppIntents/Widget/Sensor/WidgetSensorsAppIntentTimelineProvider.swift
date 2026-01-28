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
            WidgetSensorsEntry.SensorData(id: String(index), serverId: "", entityId: "", key: "?", value: "?")
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
        let state: ControlEntityProvider.State = await ControlEntityProvider(domains: Domain.allCases).state(
            server: server,
            entityId: sensor.entityId
        ) ?? ControlEntityProvider.State(value: "", unitOfMeasurement: nil, domainState: nil)
        return WidgetSensorsEntry.SensorData(
            id: sensor.id,
            serverId: server.identifier.rawValue,
            entityId: sensor.entityId,
            key: sensor.displayString,
            value: state.value,
            unitOfMeasurement: state.unitOfMeasurement,
            icon: sensor.icon ?? Domain(entityId: sensor.entityId)?.icon().name
        )
    }

    private func capitalizeFirstLetter(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
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
        var serverId: String
        var entityId: String
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
