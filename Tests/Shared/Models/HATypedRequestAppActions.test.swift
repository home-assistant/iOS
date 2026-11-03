import Foundation
import HAKit
@testable import Shared
import Testing

/// The service calls the app's tiles, widgets and to-do lists send: each one's domain, service,
/// target and REST payload.
struct HATypedRequestAppActionsTests {
    @Test func eachEntityActionCallsItsDomainsService() {
        let requests: [(HATypedRequest<HAResponseVoid>, String, String)] = [
            (.toggleDomain(domain: .light, entityId: "light.a"), "light", "toggle"),
            (.runScript(entityId: "script.a"), "script", "turn_on"),
            (.applyScene(entityId: "scene.a"), "scene", "turn_on"),
            (.trigger(entityId: "automation.a"), "automation", "trigger"),
            (.pressButton(domain: .inputButton, entityId: "input_button.a"), "input_button", "press"),
            (.lockLock(entityId: "lock.a"), "lock", "lock"),
            (.unlockLock(entityId: "lock.a"), "lock", "unlock"),
        ]
        for (request, domain, service) in requests {
            #expect(request.request.type == .webSocket("call_service"))
            #expect(request.request.data["domain"] as? String == domain)
            #expect(request.request.data["service"] as? String == service)
            #expect((request.request.data["target"] as? [String: Any])?["entity_id"] as? String != nil)
        }
    }

    /// Domains whose main action is their toggle have no explicit one to run.
    @Test func onlyDomainsWithAnExplicitMainActionHaveOne() {
        #expect(HATypedRequest<HAResponseVoid>.mainAction(domain: .scene, entityId: "scene.a") != nil)
        #expect(HATypedRequest<HAResponseVoid>.mainAction(domain: .light, entityId: "light.a") == nil)
    }

    @Test func updatingATodoItemSendsOnlyWhatChanged() {
        let plain = HATypedRequest<HAResponseVoid>.updateTodoItem(
            listId: "todo.list",
            itemId: "1",
            rename: "Milk",
            status: "needs_action"
        ).request
        #expect(plain.type == .rest(.post, "services/todo/update_item"))
        #expect(plain.data["description"] == nil)
        #expect(plain.data["due_date"] == nil)
        #expect(plain.data["due_datetime"] == nil)

        let dated = HATypedRequest<HAResponseVoid>.updateTodoItem(
            listId: "todo.list",
            itemId: "1",
            rename: "Milk",
            status: "completed",
            description: "Semi-skimmed",
            dueDate: "2026-01-02",
            dueDateTime: "2026-01-02T10:00:00"
        ).request
        #expect(dated.data["description"] as? String == "Semi-skimmed")
        #expect(dated.data["due_date"] as? String == "2026-01-02")
        #expect(dated.data["due_datetime"] == nil)

        let timed = HATypedRequest<HAResponseVoid>.updateTodoItem(
            listId: "todo.list",
            itemId: "1",
            rename: "Milk",
            status: "completed",
            dueDateTime: "2026-01-02T10:00:00"
        ).request
        #expect(timed.data["due_datetime"] as? String == "2026-01-02T10:00:00")
    }

    @Test func completingAndRemovingTodoItemsTargetTheItem() {
        let complete = HATypedRequest<HAResponseVoid>.completeTodoItem(listId: "todo.list", itemId: "1").request
        #expect(complete.type == .rest(.post, "services/todo/update_item"))
        #expect(complete.data["status"] as? String == "completed")
        #expect(complete.data["item"] as? String == "1")

        let remove = HATypedRequest<HAResponseVoid>.removeTodoItem(listId: "todo.list", itemId: "1").request
        #expect(remove.type == .rest(.post, "services/todo/remove_item"))
        #expect(remove.data["entity_id"] as? String == "todo.list")
    }
}
