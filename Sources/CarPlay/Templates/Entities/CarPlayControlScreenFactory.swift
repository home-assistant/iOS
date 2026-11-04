import CarPlay
import Foundation
import HAKit
import Shared

/// Builds the pushed control screen for an entity of a control-screen domain (see
/// `Domain.controlScreenDomains`). Returns nil for domains without one, so callers can fall back
/// to executing the tap instead.
enum CarPlayControlScreenFactory {
    static func template(entity: HAEntity, server: Server) -> (any CarPlayTemplateProvider)? {
        switch Domain(entityId: entity.entityId) {
        case .climate:
            return CarPlayClimateControlTemplate(viewModel: .init(server: server, entity: entity))
        case .vacuum:
            return CarPlayVacuumControlTemplate(viewModel: .init(server: server, entity: entity))
        default:
            return nil
        }
    }
}
