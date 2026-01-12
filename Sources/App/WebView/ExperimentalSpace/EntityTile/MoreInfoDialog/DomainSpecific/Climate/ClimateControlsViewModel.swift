import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class ClimateControlsViewModel {
    // MARK: - Published State

    var currentTemperature: Double?
    var targetTemperature: Double = 20.0
    var minTemperature: Double = 7.0
    var maxTemperature: Double = 35.0
    var temperatureStep: Double = 0.5
    var hvacMode: String = "off"
    var availableHvacModes: [String] = []
    var isUpdating: Bool = false

    // MARK: - Dependencies

    private let server: Server
    private var haEntity: HAEntity

    // MARK: - Initialization

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
    }

    // MARK: - Public Methods

    func updateEntity(_ haEntity: HAEntity) {
        self.haEntity = haEntity
        updateStateFromEntity()
    }

    func initialize() {
        updateStateFromEntity()
    }

    func stateDescription() -> String {
        Domain(entityId: haEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    var climateIcon: SFSymbol {
        switch hvacMode {
        case "heat":
            return .flameFill
        case "cool":
            return .snowflake
        case "heat_cool", "auto":
            return .arrowLeftArrowRightCircle
        case "dry":
            return .drop
        case "fan_only":
            return .fanFill
        default:
            return .powerCircle
        }
    }

    var temperatureUnit: String {
        if let unit = haEntity.attributes["temperature_unit"] as? String {
            return unit
        }
        return "°C"
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        hvacMode = haEntity.state

        // Get current temperature
        if let current = haEntity.attributes["current_temperature"] as? Double {
            currentTemperature = current
        } else if let current = haEntity.attributes["current_temperature"] as? Int {
            currentTemperature = Double(current)
        }

        // Get target temperature
        if let target = haEntity.attributes["temperature"] as? Double {
            targetTemperature = target
        } else if let target = haEntity.attributes["temperature"] as? Int {
            targetTemperature = Double(target)
        }

        // Get temperature range
        if let min = haEntity.attributes["min_temp"] as? Double {
            minTemperature = min
        } else if let min = haEntity.attributes["min_temp"] as? Int {
            minTemperature = Double(min)
        }

        if let max = haEntity.attributes["max_temp"] as? Double {
            maxTemperature = max
        } else if let max = haEntity.attributes["max_temp"] as? Int {
            maxTemperature = Double(max)
        }

        // Get temperature step
        if let step = haEntity.attributes["target_temp_step"] as? Double {
            temperatureStep = step
        } else if let step = haEntity.attributes["target_temp_step"] as? Int {
            temperatureStep = Double(step)
        }

        // Get available HVAC modes
        if let modes = haEntity.attributes["hvac_modes"] as? [String] {
            availableHvacModes = modes
        }
    }

    // MARK: - Actions

    @MainActor
    func setTemperature(_ temperature: Double) async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to get API for server \(server.identifier.rawValue)")
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                api.CallService(
                    domain: Domain.climate.rawValue,
                    service: Service.setTemperature.rawValue,
                    serviceData: [
                        "entity_id": haEntity.entityId,
                        "temperature": temperature,
                    ],
                    triggerSource: .AppIntent
                )
                .pipe { result in
                    switch result {
                    case .fulfilled:
                        continuation.resume()
                    case let .rejected(error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Optimistically update state
            targetTemperature = temperature
            Current.Log.info("Successfully set temperature for \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to set temperature for \(haEntity.entityId): \(error)")
        }
    }

    @MainActor
    func setHvacMode(_ mode: String) async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to get API for server \(server.identifier.rawValue)")
            return
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                api.CallService(
                    domain: Domain.climate.rawValue,
                    service: Service.setHvacMode.rawValue,
                    serviceData: [
                        "entity_id": haEntity.entityId,
                        "hvac_mode": mode,
                    ],
                    triggerSource: .AppIntent
                )
                .pipe { result in
                    switch result {
                    case .fulfilled:
                        continuation.resume()
                    case let .rejected(error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            // Optimistically update state
            hvacMode = mode
            Current.Log.info("Successfully set HVAC mode for \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to set HVAC mode for \(haEntity.entityId): \(error)")
        }
    }

    func hvacModeDisplayName(_ mode: String) -> String {
        switch mode {
        case "off":
            return "Off"
        case "heat":
            return "Heat"
        case "cool":
            return "Cool"
        case "heat_cool":
            return "Auto"
        case "auto":
            return "Auto"
        case "dry":
            return "Dry"
        case "fan_only":
            return "Fan"
        default:
            return mode.capitalized
        }
    }
}
