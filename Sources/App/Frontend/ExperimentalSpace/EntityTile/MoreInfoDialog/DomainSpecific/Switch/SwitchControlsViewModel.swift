import Combine
import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
final class SwitchControlsViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isOn: Bool = false
    @Published var isUpdating: Bool = false
    @Published var deviceClass: String?

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

    var switchIcon: SFSymbol {
        // Map device classes to appropriate icons
        guard let deviceClass,
              let deviceClassEnum = DeviceClass(rawValue: deviceClass.lowercased()) else {
            return .powerCircle // Default switch icon
        }

        switch deviceClassEnum {
        case .outlet:
            return .powerCircle
        case .switch:
            return .powerCircle
        default:
            return .powerCircle
        }
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        isOn = haEntity.state == Domain.State.on.rawValue
        deviceClass = DeviceClassProvider.deviceClass(for: haEntity.entityId, serverId: server.identifier.rawValue)
            .rawValue
    }

    // MARK: - Actions

    @MainActor
    func toggleSwitch() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        // Create IntentSwitchEntity from appEntity
        let intentSwitch = IntentSwitchEntity(
            id: "\(server.identifier.rawValue)-\(haEntity.entityId)",
            entityId: haEntity.entityId,
            serverId: server.identifier.rawValue,
            displayString: haEntity.attributes.friendlyName ?? haEntity.entityId,
            iconName: haEntity.attributes.icon ?? ""
        )

        // Create and perform the toggle intent
        let toggleIntent = ToggleSwitchIntent()
        toggleIntent.switchEntity = intentSwitch

        do {
            _ = try await toggleIntent.perform()

            // Optimistically update state
            isOn.toggle()
            Current.Log.info("Successfully toggled switch \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to toggle switch \(haEntity.entityId): \(error)")
        }
    }
}
