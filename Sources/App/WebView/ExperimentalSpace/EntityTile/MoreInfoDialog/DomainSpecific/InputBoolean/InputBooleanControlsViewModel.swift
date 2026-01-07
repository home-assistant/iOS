import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class InputBooleanControlsViewModel {
    // MARK: - Published State

    var isOn: Bool = false
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

    var inputBooleanIcon: SFSymbol {
        return isOn ? .toggleOn : .toggleOff
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        isOn = haEntity.state == Domain.State.on.rawValue
    }

    // MARK: - Actions

    @MainActor
    func toggleInputBoolean() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to get API for server \(server.identifier.rawValue)")
            return
        }

        let service = Service.toggle.rawValue

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                api.CallService(
                    domain: Domain.inputBoolean.rawValue,
                    service: service,
                    serviceData: ["entity_id": haEntity.entityId],
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
            isOn.toggle()
            Current.Log.info("Successfully toggled input_boolean \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to toggle input_boolean \(haEntity.entityId): \(error)")
        }
    }
}
