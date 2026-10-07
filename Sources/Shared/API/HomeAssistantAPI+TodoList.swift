import Foundation
import HAKit
import PromiseKit

/// Async helpers for the `todo` domain services.
///
/// These must live in Shared, not in the app target: both the app binary and Shared.framework
/// link HAKit statically, so instantiating `HATypedRequest<TodoListRawResponse>` metadata from
/// app code mixes the two copies of HAKit's type descriptors and the runtime returns null
/// metadata (EXC_BAD_ACCESS). Inside Shared the descriptors are consistent.
public extension HomeAssistantAPI {
    func todoListItems(listId: String) async throws -> [TodoListItem] {
        let response = try await send(.getItemFromTodoList(listId: listId))
        return response.serviceResponse[listId]?.items ?? []
    }

    /// `dueDate` is `yyyy-MM-dd`, `dueDateTime` is an ISO8601 datetime; pass at most one.
    func addTodoItem(
        listId: String,
        summary: String,
        description: String?,
        dueDate: String?,
        dueDateTime: String?
    ) async throws {
        _ = try await send(.addTodoItem(
            listId: listId,
            summary: summary,
            description: description,
            dueDate: dueDate,
            dueDateTime: dueDateTime
        ))
    }

    func updateTodoItem(
        listId: String,
        itemId: String,
        rename: String,
        status: String,
        description: String?,
        dueDate: String?,
        dueDateTime: String?
    ) async throws {
        _ = try await send(.updateTodoItem(
            listId: listId,
            itemId: itemId,
            rename: rename,
            status: status,
            description: description,
            dueDate: dueDate,
            dueDateTime: dueDateTime
        ))
    }

    func removeTodoItem(listId: String, itemId: String) async throws {
        _ = try await send(.removeTodoItem(listId: listId, itemId: itemId))
    }

    func completeTodoItem(listId: String, itemId: String) async throws {
        _ = try await send(.completeTodoItem(listId: listId, itemId: itemId))
    }

    private func send<T: HADataDecodable>(_ request: HATypedRequest<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(request).promise.pipe { result in
                switch result {
                case let .fulfilled(value):
                    continuation.resume(returning: value)
                case let .rejected(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
