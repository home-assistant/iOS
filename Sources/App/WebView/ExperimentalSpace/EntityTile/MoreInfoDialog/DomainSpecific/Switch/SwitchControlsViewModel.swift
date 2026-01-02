import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class SwitchControlsViewModel {
    // MARK: - Published State

    var isOn: Bool = false
    var isUpdating: Bool = false
    var deviceClass: String?

    // MARK: - Dependencies

    private let server: Server
    private let appEntity: HAAppEntity
    private var haEntity: HAEntity?

    // MARK: - Initialization

    init(server: Server, appEntity: HAAppEntity, haEntity: HAEntity?) {
        self.server = server
        self.appEntity = appEntity
        self.haEntity = haEntity
    }

    // MARK: - Public Methods

    func updateEntity(_ haEntity: HAEntity?) {
        self.haEntity = haEntity
        updateStateFromEntity()
    }

    func initialize() {
        updateStateFromEntity()
    }

    func stateDescription() -> String {
        guard let haEntity else { return CoreStrings.commonStateOff }
        return Domain(entityId: appEntity.entityId)?.contextualStateDescription(for: haEntity) ?? haEntity.state
    }

    var switchIcon: SFSymbol {
        // Map device classes to appropriate icons
        guard let deviceClass else {
            return .powerCircle // Default switch icon
        }

        switch deviceClass.lowercased() {
        case "outlet":
            return .powerCircle
        case "switch":
            return .powerCircle
        default:
            return .powerCircle
        }
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        guard let haEntity else {
            isOn = false
            deviceClass = nil
            return
        }

        isOn = haEntity.state == Domain.State.on.rawValue
        deviceClass = haEntity.attributes["device_class"] as? String
    }

    // MARK: - Actions

    @MainActor
    func toggleSwitch() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        await Current.connectivity.syncNetworkInformation()
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("Failed to get connection for switch \(appEntity.entityId)")
            return
        }

        let service = isOn ? Service.turnOff.rawValue : Service.turnOn.rawValue

        _ = await withCheckedContinuation { continuation in
            connection.send(.callService(
                domain: .init(stringLiteral: Domain.switch.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": appEntity.entityId,
                ]
            )).promise.pipe { _ in
                continuation.resume()
            }
        }

        // Optimistically update state
        isOn.toggle()
        Current.Log.info("Successfully toggled switch \(appEntity.entityId)")
    }
}
