import Combine
import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
final class FanControlsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isOn: Bool = false
    @Published var isUpdating: Bool = false
    @Published var speed: Double = 0 // Percentage 0-100
    @Published var oscillating: Bool = false
    @Published var direction: String = "forward"
    @Published var supportsOscillation: Bool = false
    @Published var supportsDirection: Bool = false
    @Published var supportsSpeedPercentage: Bool = false

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

    var fanIcon: SFSymbol {
        isOn ? .fanFill : .fan
    }

    // MARK: - Helper Methods

    private func createIntentFanEntity() -> IntentFanEntity {
        IntentFanEntity(
            id: "\(server.identifier.rawValue)-\(haEntity.entityId)",
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? SFSymbol.fan.rawValue
        )
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        isOn = haEntity.state == Domain.State.on.rawValue

        // Get speed percentage
        if let percentageSpeed = haEntity.attributes["percentage"] as? Int {
            speed = Double(percentageSpeed)
            supportsSpeedPercentage = true
        } else if let percentageSpeed = haEntity.attributes["percentage"] as? Double {
            speed = percentageSpeed
            supportsSpeedPercentage = true
        } else {
            speed = isOn ? 100 : 0
            supportsSpeedPercentage = false
        }

        // Get oscillation state
        if let oscillatingValue = haEntity.attributes["oscillating"] as? Bool {
            oscillating = oscillatingValue
            supportsOscillation = true
        } else {
            oscillating = false
            supportsOscillation = false
        }

        // Get direction
        if let directionValue = haEntity.attributes["direction"] as? String {
            direction = directionValue
            supportsDirection = true
        } else {
            direction = "forward"
            supportsDirection = false
        }
    }

    // MARK: - Actions

    @MainActor
    func toggleFan() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        // Create and perform the toggle intent
        let toggleIntent = ToggleFanIntent()
        toggleIntent.fan = createIntentFanEntity()
        toggleIntent.turnOn = !isOn

        do {
            _ = try await toggleIntent.perform()

            // Optimistically update state
            isOn.toggle()
            Current.Log.info("Successfully toggled fan \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to toggle fan \(haEntity.entityId): \(error)")
        }
    }

    @MainActor
    func updateSpeed(_ newSpeed: Double) async {
        guard !isUpdating else { return }
        guard supportsSpeedPercentage else { return }

        isUpdating = true
        defer { isUpdating = false }

        // Create and perform the set speed intent
        let setSpeedIntent = SetFanSpeedIntent()
        setSpeedIntent.fan = createIntentFanEntity()
        setSpeedIntent.percentage = Int(newSpeed)

        do {
            _ = try await setSpeedIntent.perform()

            // Update local state
            speed = newSpeed
            // If setting speed, turn on the fan
            if !isOn, newSpeed > 0 {
                isOn = true
            }
            Current.Log.info("Successfully updated fan speed \(haEntity.entityId) to \(Int(newSpeed))%")
        } catch {
            Current.Log.error("Failed to update fan speed \(haEntity.entityId): \(error)")
        }
    }

    @MainActor
    func toggleOscillation() async {
        guard !isUpdating else { return }
        guard supportsOscillation else { return }

        isUpdating = true
        defer { isUpdating = false }

        let newOscillating = !oscillating

        // Create and perform the oscillation intent
        let oscillationIntent = ToggleFanOscillationIntent()
        oscillationIntent.fan = createIntentFanEntity()
        oscillationIntent.oscillating = newOscillating

        do {
            _ = try await oscillationIntent.perform()

            // Update local state
            oscillating = newOscillating
            Current.Log.info("Successfully toggled oscillation for \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to toggle oscillation for \(haEntity.entityId): \(error)")
        }
    }

    @MainActor
    func toggleDirection() async {
        guard !isUpdating else { return }
        guard supportsDirection else { return }

        isUpdating = true
        defer { isUpdating = false }

        let newDirection = direction == "forward" ? "reverse" : "forward"

        // Create and perform the set direction intent
        let directionIntent = SetFanDirectionIntent()
        directionIntent.fan = createIntentFanEntity()
        directionIntent.direction = newDirection

        do {
            _ = try await directionIntent.perform()

            // Update local state
            direction = newDirection
            Current.Log.info("Successfully changed direction for \(haEntity.entityId) to \(newDirection)")
        } catch {
            Current.Log.error("Failed to change direction for \(haEntity.entityId): \(error)")
        }
    }
}
