import Foundation
import HAKit

public extension HATypedRequest {
    /// Executes the domain's main action (e.g., toggle for lights, turn_on for scenes).
    /// Returns nil if the domain doesn't have a main action.
    static func executeMainAction(
        domain: Domain,
        entityId: String
    ) -> HATypedRequest<HAResponseVoid>? {
        guard let action = domain.mainAction else { return nil }
        return HATypedRequest<HAResponseVoid>(request: .init(
            type: "call_service",
            data: [
                "domain": domain.rawValue,
                "service": action.rawValue,
                "target": [
                    "entity_id": entityId,
                ],
            ]
        ))
    }

    /// Performs a `call_service` over the websocket, optionally requesting the action's response.
    ///
    /// `returnResponse` must only be `true` for actions that support a response, otherwise Home
    /// Assistant rejects the call.
    static func callService(
        domain: String,
        service: String,
        serviceData: [String: Any],
        returnResponse: Bool
    ) -> HATypedRequest<CallServiceResponse> {
        HATypedRequest<CallServiceResponse>(request: .init(
            type: "call_service",
            data: [
                "domain": domain,
                "service": service,
                "service_data": serviceData,
                "return_response": returnResponse,
            ]
        ))
    }

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

    static func configFloorRegistry() -> HATypedRequest<[HAFloorRegistryResponse]> {
        HATypedRequest<[HAFloorRegistryResponse]>(request: .init(
            type: "config/floor_registry/list"
        ))
    }

    static func configDeviceRegistryList() -> HATypedRequest<[DeviceRegistryEntry]> {
        HATypedRequest<[DeviceRegistryEntry]>(request: .init(
            type: "config/device_registry/list"
        ))
    }

    static func fetchCurrentUser() -> HATypedRequest<HAResponseCurrentUser> {
        HATypedRequest<HAResponseCurrentUser>.currentUser()
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

    /// Adds an item to a todo list. `dueDate` is `yyyy-MM-dd`, `dueDateTime` is an ISO8601
    /// datetime; pass at most one of them.
    static func addTodoItem(
        listId: String,
        summary: String,
        description: String? = nil,
        dueDate: String? = nil,
        dueDateTime: String? = nil
    ) -> HATypedRequest<HAResponseVoid> {
        var data: [String: Any] = [
            "entity_id": listId,
            "item": summary,
        ]
        if let description {
            data["description"] = description
        }
        if let dueDate {
            data["due_date"] = dueDate
        } else if let dueDateTime {
            data["due_datetime"] = dueDateTime
        }
        return HATypedRequest<HAResponseVoid>(
            request: .init(
                type: .rest(.post, "services/todo/add_item"),
                data: data
            )
        )
    }

    /// Updates a todo item identified by its `uid`. Only the provided fields are sent; a nil due
    /// date is left untouched (the todo services offer no way to clear it).
    static func updateTodoItem(
        listId: String,
        itemId: String,
        rename: String,
        status: String,
        description: String? = nil,
        dueDate: String? = nil,
        dueDateTime: String? = nil
    ) -> HATypedRequest<HAResponseVoid> {
        var data: [String: Any] = [
            "entity_id": listId,
            "item": itemId,
            "rename": rename,
            "status": status,
        ]
        if let description {
            data["description"] = description
        }
        if let dueDate {
            data["due_date"] = dueDate
        } else if let dueDateTime {
            data["due_datetime"] = dueDateTime
        }
        return HATypedRequest<HAResponseVoid>(
            request: .init(
                type: .rest(.post, "services/todo/update_item"),
                data: data
            )
        )
    }

    static func removeTodoItem(listId: String, itemId: String) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(
            request: .init(
                type: .rest(.post, "services/todo/remove_item"),
                data: [
                    "entity_id": listId,
                    "item": itemId,
                ]
            )
        )
    }

    static func completeTodoItem(listId: String, itemId: String) -> HATypedRequest<HAResponseVoid> {
        HATypedRequest<HAResponseVoid>(
            request:
            .init(
                type: .rest(
                    .post, "services/todo/update_item"
                ), data: [
                    "entity_id": listId,
                    "item": itemId,
                    "status": "completed",
                ]
            )
        )
    }
}
