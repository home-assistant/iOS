import Foundation
import HAKit

public extension HATypedRequest {
    static func toggleDomain(
        domain: Domain,
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": domain.rawValue,
                "service": Service.toggle.rawValue,
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
                "domain": Domain.script.rawValue,
                "service": Service.turnOn.rawValue,
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func applyScene(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": Domain.scene.rawValue,
                "service": Service.turnOn.rawValue,
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func trigger(
        entityId: String
    ) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": Domain.automation.rawValue,
                "service": Service.trigger.rawValue,
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
                "service": Service.press.rawValue,
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
                "domain": Domain.lock.rawValue,
                "service": Service.lock.rawValue,
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
                "domain": Domain.lock.rawValue,
                "service": Service.unlock.rawValue,
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    static func configAreasRegistry() -> HATypedRequest<[HAAreasRegistryResponse]> {
        HATypedRequest<[HAAreasRegistryResponse]>(request: .init(
            type: "config/area_registry/list"
        ))
    }

    static func configEntityRegistryList() -> HATypedRequest<[EntityRegistryEntry]> {
        HATypedRequest<[EntityRegistryEntry]>(request: .init(
            type: "config/entity_registry/list"
        ))
    }

    static func configDeviceRegistryList() -> HATypedRequest<[DeviceRegistryEntry]> {
        HATypedRequest<[DeviceRegistryEntry]>(request: .init(
            type: "config/device_registry/list"
        ))
    }

    static func fetchStates() -> HATypedRequest<[HAEntity]> {
        HATypedRequest<[HAEntity]>(request: .init(
            type: .rest(.get, "states")
        ))
    }

    static func configEntityRegistryListForDisplay() -> HATypedRequest<EntityRegistryListForDisplay> {
        HATypedRequest<EntityRegistryListForDisplay>(request: .init(
            type: .webSocket("config/entity_registry/list_for_display")
        ))
    }

    static func usagePredictionCommonControl() -> HATypedRequest<HAUsagePredictionCommonControl> {
        HATypedRequest<HAUsagePredictionCommonControl>(request: .init(
            type: .webSocket("usage_prediction/common_control")
        ))
    }

    static func getItemFromTodoList(listId: String) -> HATypedRequest<TodoListRawResponse> {
        HATypedRequest<TodoListRawResponse>(
            request:
            .init(
                type: .rest(
                    .post, "services/todo/get_items"
                ), data: [
                    "entity_id": listId,
                ],
                queryItems: [
                    .init(name: "return_response", value: "true"),
                ],
                shouldRetry: true
            )
        )
    }
}
