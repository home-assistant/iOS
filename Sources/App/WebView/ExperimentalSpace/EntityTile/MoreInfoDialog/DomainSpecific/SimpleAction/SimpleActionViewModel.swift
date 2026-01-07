import HAKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
final class SimpleActionViewModel {
    // MARK: - Published State

    var isExecuting: Bool = false
    var lastExecuted: Date?

    // MARK: - Dependencies

    private let server: Server
    private var haEntity: HAEntity

    // MARK: - Initialization

    init(server: Server, haEntity: HAEntity) {
        self.server = server
        self.haEntity = haEntity
        self.lastExecuted = haEntity.lastChanged
    }

    // MARK: - Public Methods

    func updateEntity(_ haEntity: HAEntity) {
        self.haEntity = haEntity
        self.lastExecuted = haEntity.lastChanged
    }

    func initialize() {
        lastExecuted = haEntity.lastChanged
    }

    func stateDescription() -> String {
        if let domain = Domain(entityId: haEntity.entityId) {
            return domain.localizedState(for: haEntity.state)
        }
        return haEntity.state
    }

    var actionIcon: SFSymbol {
        guard let domain = Domain(entityId: haEntity.entityId) else {
            return .play
        }

        switch domain {
        case .button, .inputButton:
            return .handTap
        case .scene:
            return .paintpalette
        case .script:
            return .scriptText
        case .automation:
            return .gearshape2
        default:
            return .play
        }
    }

    var actionLabel: String {
        guard let domain = Domain(entityId: haEntity.entityId) else {
            return "Execute"
        }

        switch domain {
        case .button, .inputButton:
            return "Press"
        case .scene:
            return "Activate"
        case .script:
            return "Run"
        case .automation:
            return "Trigger"
        default:
            return "Execute"
        }
    }

    // MARK: - Actions

    @MainActor
    func executeAction() async {
        guard !isExecuting else { return }

        isExecuting = true
        defer { isExecuting = false }

        guard let api = Current.api(for: server),
              let domain = Domain(entityId: haEntity.entityId) else {
            Current.Log.error("Failed to get API or domain for entity \(haEntity.entityId)")
            return
        }

        let service: String
        switch domain {
        case .button, .inputButton:
            service = "press"
        case .scene:
            service = Service.turnOn.rawValue
        case .script:
            service = Service.turnOn.rawValue
        case .automation:
            service = Service.trigger.rawValue
        default:
            service = Service.turnOn.rawValue
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                api.CallService(
                    domain: domain.rawValue,
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

            lastExecuted = Date()
            Current.Log.info("Successfully executed \(domain.rawValue) \(haEntity.entityId)")
        } catch {
            Current.Log.error("Failed to execute \(domain.rawValue) \(haEntity.entityId): \(error)")
        }
    }
}
