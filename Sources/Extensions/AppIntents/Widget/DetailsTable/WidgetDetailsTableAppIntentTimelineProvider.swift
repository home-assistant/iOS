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
            return WidgetDetailsTableEntry.init(
                sensorData: [WidgetDetailsTableEntry.SensorData(entityId: "lol", key: "123", value: "123")]
            )
//            return try await entry(for: configuration, in: context)
        } catch {
            Current.Log.error("Using placeholder for detailtable widget snapshot")
            return placeholder(in: context)
        }
    }

    func timeline(for configuration: WidgetDetailsTableAppIntent, in context: Context) async -> Timeline<Entry> {
        print("IK WORD AANGEROEPEN")
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
            Current.Log.debug("Using placeholder for detailtable widget")
            print("")
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
            sensorData: [WidgetDetailsTableEntry.SensorData(entityId: "1", key: "2", value: "3")]
        )
    }

    private func entry(for configuration: WidgetDetailsTableAppIntent, in context: Context) async throws -> Entry {
        Current.Log.error("AAAAAAAAAAAAAAAA")

        let sensorsGroupedByServer = Dictionary(grouping: configuration.sensors ?? [], by: { $0.serverId })

        // Use async operations to gather results
        var sensorValues: [WidgetDetailsTableEntry.SensorData] = []

        // Iterate over each group of sensors asynchronously
        for (serverId, sensors) in sensorsGroupedByServer {
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
                throw WidgetDetailsTableDataError.noServers
            }
            
            // Fetch sensor data for each sensor asynchronously
            for sensor in sensors {
                let sensorData = try await fetchSensorData(for: sensor, server: server)
                sensorValues.append(sensorData)
            }
        }

        return WidgetDetailsTableEntry(sensorData: sensorValues)
    }

    private func fetchSensorData(for sensor: IntentDetailsTableAppEntity, server: Server) async throws -> WidgetDetailsTableEntry.SensorData {
        // Define the task to fetch sensor data
        let result = await withCheckedContinuation { continuation in
            Current.api(for: server).connection.send(.init(
                type: .rest(.post, "states/\(sensor.serverId)"),
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

        // Return the processed SensorData (replace "123" with actual value from `data`)
        return WidgetDetailsTableEntry.SensorData(
            entityId: sensor.entityId,
            key: sensor.displayString,
            value: "123" // Replace with actual sensor data
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
    }
}

enum WidgetDetailsTableDataError: Error {
    case noServers
    case apiError
    case badResponse
}
