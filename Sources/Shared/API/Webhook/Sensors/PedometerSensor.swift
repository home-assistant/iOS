import CoreMotion
import Foundation
import PromiseKit
import Version

public class PedometerSensor: SensorProvider {
    public enum PedometerError: Error {
        case unauthorized
        case unavailable
        case noData
    }

    public let request: SensorProviderRequest
    public required init(request: SensorProviderRequest) {
        self.request = request
    }

    public func sensors() -> Promise<[WebhookSensor]> {
        firstly { () -> Promise<CMPedometerData> in
            latestPedometerData()
        }.then { [request] data in
            when(resolved: PedometerSensor.allCases.map { $0.asSensor(from: data, request: request) })
        }.map { sensors -> [WebhookSensor] in
            sensors.compactMap {
                if case let .fulfilled(value) = $0 {
                    return value
                } else {
                    return nil
                }
            }
        }
    }

    private func latestPedometerData() -> Promise<CMPedometerData> {
        guard Current.pedometer.isAuthorized() else {
            return .init(error: PedometerError.unauthorized)
        }

        guard Current.pedometer.isStepCountingAvailable() else {
            Current.Log.warning("Pedometer is not available")
            return .init(error: PedometerError.unavailable)
        }

        let (promise, seal) = Promise<CMPedometerData>.pending()

        let end = Current.date()
        let start = Current.calendar().startOfDay(for: end)
        Current.pedometer.queryStartEndHandler(start, end) { data, error in
            if let data = data {
                seal.fulfill(data)
            } else if let error = error {
                seal.reject(error)
            } else {
                seal.reject(PedometerError.noData)
            }
        }
        return promise
    }

    private enum KeyPathType {
        case normal(KeyPath<CMPedometerData, NSNumber>)
        case optional(KeyPath<CMPedometerData, NSNumber?>)

        func intValue(on data: CMPedometerData) -> Int? {
            switch self {
            case let .normal(keyPath): return data[keyPath: keyPath].intValue
            case let .optional(keyPath): return data[keyPath: keyPath]?.intValue
            }
        }
    }

    private enum PedometerSensor: String, CaseIterable {
        case distance = "pedometer_distance"
        case floorsAscended = "pedometer_floors_ascended"
        case floorsDescended = "pedometer_floors_descended"
        case steps = "pedometer_steps"
        case averageActivePace = "pedometer_avg_active_pace"
        case currentPace = "pedometer_current_pace"
        case currentCadence = "pedometer_current_cadence"

        private var name: String {
            switch self {
            case .distance: return "Distance"
            case .floorsAscended: return "Floors Ascended"
            case .floorsDescended: return "Floors Descended"
            case .steps: return "Steps"
            case .averageActivePace: return "Average Active Pace"
            case .currentPace: return "Current Pace"
            case .currentCadence: return "Current Cadence"
            }
        }

        private var keyPath: KeyPathType {
            switch self {
            case .distance: return .optional(\.distance)
            case .floorsAscended: return .optional(\.floorsAscended)
            case .floorsDescended: return .optional(\.floorsDescended)
            case .steps: return .normal(\.numberOfSteps)
            case .averageActivePace: return .optional(\.averageActivePace)
            case .currentPace: return .optional(\.currentPace)
            case .currentCadence: return .optional(\.currentCadence)
            }
        }

        private func icon(serverVersion: Version) -> String? {
            switch self {
            case .distance: return "mdi:hiking"
            case .floorsAscended:
                if serverVersion < .pedometerIconsAvailable {
                    return "mdi:slope-uphill"
                } else {
                    return "mdi:stairs-up"
                }
            case .floorsDescended:
                if serverVersion < .pedometerIconsAvailable {
                    return "mdi:slope-downhill"
                } else {
                    return "mdi:stairs-down"
                }
            case .steps: return "mdi:walk"
            case .averageActivePace: return "mdi:speedometer"
            case .currentPace: return "mdi:speedometer"
            case .currentCadence: return nil
            }
        }

        private var unit: String {
            switch self {
            case .distance: return "m"
            case .floorsAscended: return "floors"
            case .floorsDescended: return "floors"
            case .steps: return "steps"
            case .averageActivePace: return "m/s"
            case .currentPace: return "m/s"
            case .currentCadence: return "steps/s"
            }
        }

        func asSensor(from data: CMPedometerData, request: SensorProviderRequest) -> Promise<WebhookSensor> {
            guard let intVal = keyPath.intValue(on: data) else {
                return .init(error: PedometerError.noData)
            }

            return .value(WebhookSensor(
                name: name,
                uniqueID: rawValue,
                icon: icon(serverVersion: request.serverVersion),
                state: intVal,
                unit: unit
            ))
        }
    }
}
