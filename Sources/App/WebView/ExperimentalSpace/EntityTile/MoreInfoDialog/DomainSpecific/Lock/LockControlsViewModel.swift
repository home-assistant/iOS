import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class LockControlsViewModel {
    // MARK: - Published State

    var isLocked: Bool = false
    var isUpdating: Bool = false
    var currentState: String = ""

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

    var lockIcon: SFSymbol {
        switch currentState {
        case Domain.State.locked.rawValue:
            return .lockFill
        case Domain.State.unlocked.rawValue:
            return .lockOpen
        case Domain.State.jammed.rawValue:
            return .exclamationmarkTriangleFill
        default:
            return .lockFill
        }
    }

    // MARK: - State Management

    func updateStateFromEntity() {
        currentState = haEntity.state
        isLocked = currentState == Domain.State.locked.rawValue
    }

    // MARK: - Actions

    @MainActor
    func toggleLock() async {
        guard !isUpdating else { return }

        isUpdating = true
        defer { isUpdating = false }

        guard let api = Current.api(for: server) else {
            Current.Log.error("Failed to get API for server \(server.identifier.rawValue)")
            return
        }

        let service = isLocked ? Service.unlock.rawValue : Service.lock.rawValue

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                api.CallService(
                    domain: Domain.lock.rawValue,
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
            isLocked.toggle()
            currentState = isLocked ? Domain.State.locked.rawValue : Domain.State.unlocked.rawValue
            Current.Log.info("Successfully toggled lock \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to toggle lock \(haEntity.entityId): \(error)")
        }
    }
}
