import Foundation
import HAKit
import Shared

extension HATypedRequest {
    static func toggleDomain(
        domain: Domain,
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": domain.rawValue,
                "service": "toggle",
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func runScript(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": "script",
                "service": entityId.replacingOccurrences(of: "script.", with: ""),
            ]
        ))
    }

    static func applyScene(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": "scene",
                "service": "turn_on",
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func pressButton(
        domain: Domain,
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": domain.rawValue,
                "service": "press",
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func lockLock(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": "lock",
                "service": "lock",
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func unlockLock(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": "lock",
                "service": "unlock",
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func fetchAreas() -> HATypedRequest<[HAAreaResponse]> {
        HATypedRequest<[HAAreaResponse]>(request: .init(
            type: "config/area_registry/list"
        ))
    }

    static func fetchEntitiesWithAreas() -> HATypedRequest<[HAEntityAreaResponse]> {
        HATypedRequest<[HAEntityAreaResponse]>(request: .init(
            type: "config/entity_registry/list"
        ))
    }

    static func fetchDevicesWithAreas() -> HATypedRequest<[HADeviceAreaResponse]> {
        HATypedRequest<[HADeviceAreaResponse]>(request: .init(
            type: "config/device_registry/list"
        ))
    }
}
