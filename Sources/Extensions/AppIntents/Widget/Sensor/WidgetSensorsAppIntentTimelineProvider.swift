import AppIntents
import GRDB
import HAKit
import PromiseKit
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
        // `context.isPreview` is WidgetKit's hook for the widget gallery, which renders with a
        // default (unconfigured) configuration. The suggestion pass below reads the entity database
        // and then fetches a state per sensor — none of which the picker needs, so mock it.
        if context.isPreview {
            return Self.previewSample(in: context)
        }
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

    static func previewSample(in context: Context) -> WidgetSensorsEntry {
        let readings = WidgetPreviewSample.sensorReadings
        let sensors = (0 ..< WidgetFamilySizes.sizeForPreview(for: context.family))
            .map { index -> WidgetSensorsEntry.SensorData in
                let reading = readings[index % readings.count]
                return .init(
                    id: String(index),
                    key: reading.name,
                    value: reading.value,
                    unitOfMeasurement: reading.unit,
                    icon: reading.icon.name
                )
            }
        return WidgetSensorsEntry(sensorData: sensors)
    }

    func timeline(for configuration: WidgetSensorsAppIntent, in context: Context) async -> Timeline<Entry> {
        if context.isPreview {
            return .init(entries: [Self.previewSample(in: context)], policy: .never)
        }
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

    /// The gallery renders this, redacted, until the snapshot arrives — so it is the same mock, and
    /// the card never flips from a column of "?" to readings as it loads.
    func placeholder(in context: Context) -> WidgetSensorsEntry {
        Self.previewSample(in: context)
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
            key: sensor.displayString,
            value: state.value,
            unitOfMeasurement: state.unitOfMeasurement,
            icon: sensor.icon ?? Domain(entityId: sensor.entityId)?.icon().name,
            entityId: sensor.entityId,
            serverId: sensor.serverId
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
        var key: String
        var value: String
        var unitOfMeasurement: String?
        var icon: String?
        /// Placeholder and gallery samples have no real entity behind them, so they carry no
        /// identifiers and the tile falls back to a non-navigating interaction.
        var entityId: String?
        var serverId: String?
    }
}

enum WidgetSensorsDataError: Error {
    case noServers
    case apiError
    case badResponse
}
