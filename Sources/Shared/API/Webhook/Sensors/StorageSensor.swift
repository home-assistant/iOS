import Foundation
import PromiseKit

public class StorageSensor: SensorProvider {
    public enum StorageError: Error, Equatable {
        case noData
        case invalidData
        case missingData(URLResourceKey)
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    #if os(watchOS)
    public func sensors() -> Promise<[WebhookSensor]> {
        .init(error: StorageError.noData)
    }
    #else
    public func sensors() -> Promise<[WebhookSensor]> {
        firstly {
            Promise<Void>.value(())
        }.map(on: .global(qos: .userInitiated)) {
            if let volumes = Current.device.volumes(), volumes.isEmpty == false {
                return volumes
            } else {
                throw StorageError.noData
            }
        }.map { (volumes: [URLResourceKey: Int64]) -> [WebhookSensor] in
            [try Self.sensor(for: volumes)]
        }
    }

    private static func sensor(for volumes: [URLResourceKey: Int64]) throws -> WebhookSensor {
        let sensor = WebhookSensor(
            name: "Storage",
            uniqueID: "storage",
            icon: .databaseIcon,
            state: "Unknown"
        )

        let values = try Values(volumes: volumes)
        sensor.State = values.availablePercent()
        sensor.UnitOfMeasurement = "% available"

        sensor.Attributes = [
            "Total": values.byteString(for: \.total),
            "Available": values.byteString(for: \.availableOverall),
            "Available (Important)": values.byteString(for: \.availableImportant),
            "Available (Opportunistic)": values.byteString(for: \.availableOpportunistic),
        ]

        return sensor
    }

    struct Values {
        let availableOverall: Int64
        let availableImportant: Int64
        let availableOpportunistic: Int64
        let total: Int64

        private let formatter = with(ByteCountFormatter()) {
            $0.allowedUnits = [.useGB, .useMB]
            $0.countStyle = .file
            $0.allowsNonnumericFormatting = false
            $0.formattingContext = .standalone
            $0.zeroPadsFractionDigits = true
        }

        init(volumes: [URLResourceKey: Int64]) throws {
            func value(of key: URLResourceKey) throws -> Int64 {
                if let value = volumes[key] {
                    return value
                } else {
                    throw StorageError.missingData(key)
                }
            }

            self.availableOverall = try value(of: .volumeAvailableCapacityKey)
            self.availableImportant = try value(of: .volumeAvailableCapacityForImportantUsageKey)
            self.availableOpportunistic = try value(of: .volumeAvailableCapacityForOpportunisticUsageKey)
            self.total = try value(of: .volumeTotalCapacityKey)

            guard total > 0 else {
                throw StorageError.invalidData
            }
        }

        func availablePercent() -> String {
            precondition(total > 0, "init should prevent this")
            let percent = Decimal(availableOpportunistic) / Decimal(total) * Decimal(100.0)
            return String(format: "%.02lf", Double(truncating: percent as NSNumber))
        }

        func byteString(for keyPath: KeyPath<Self, Int64>) -> String {
            formatter.string(fromByteCount: self[keyPath: keyPath])
        }
    }
    #endif
}
