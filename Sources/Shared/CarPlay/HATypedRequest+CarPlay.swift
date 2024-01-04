import Foundation
import HAKit

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
                "service_data": [
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
                "service": "scene.apply",
                "service_data": [
                    "entities": [
                        entityId,
                    ],
                ],
            ]
        ))
    }

    static func pressButton(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": "button",
                "service": "button.press",
                "service_data": [
                    "entityId": entityId,
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
                "service": "lock.lock",
                "service_data": [
                    "entityId": entityId,
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
                "service": "lock.unlock",
                "service_data": [
                    "entityId": entityId,
                ],
            ]
        ))
    }
}
