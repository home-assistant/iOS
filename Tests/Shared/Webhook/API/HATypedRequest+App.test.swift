import Foundation
import HAKit
@testable import Shared
import Testing

struct HATypedRequestAppTests {
    private typealias VoidRequest = HATypedRequest<HAResponseVoid>

    private func target(of request: HARequest) -> [String: String]? {
        request.data["target"] as? [String: String]
    }

    private func serviceData(of request: HARequest) -> [String: Any]? {
        request.data["service_data"] as? [String: Any]
    }

    // MARK: - Service calls

    @Test func executeMainActionTogglesALight() throws {
        let request = try #require(VoidRequest.executeMainAction(domain: .light, entityId: "light.kitchen")).request

        #expect(request.type == .webSocket("call_service"))
        #expect(request.data["domain"] as? String == "light")
        #expect(request.data["service"] as? String == "toggle")
        #expect(target(of: request) == ["entity_id": "light.kitchen"])
    }

    @Test func executeMainActionUsesHomeAssistantDomainForGroups() throws {
        let request = try #require(VoidRequest.executeMainAction(domain: .group, entityId: "group.all")).request

        #expect(request.data["domain"] as? String == "homeassistant")
        #expect(request.data["service"] as? String == "toggle")
    }

    @Test func executeMainActionIsNilForDomainsWithoutOne() {
        #expect(VoidRequest.executeMainAction(domain: .sensor, entityId: "sensor.temp") == nil)
        #expect(VoidRequest.executeMainAction(domain: .lock, entityId: "lock.door") == nil)
    }

    @Test func mainActionPressesAButton() throws {
        let request = try #require(VoidRequest.mainAction(domain: .button, entityId: "button.ring")).request

        #expect(request.data["domain"] as? String == "button")
        #expect(request.data["service"] as? String == "press")
        #expect(target(of: request) == ["entity_id": "button.ring"])
    }

    @Test func mainActionIsNilForToggleDomains() {
        #expect(VoidRequest.mainAction(domain: .light, entityId: "light.kitchen") == nil)
        #expect(VoidRequest.mainAction(domain: .sensor, entityId: "sensor.temp") == nil)
    }

    @Test func callServiceCarriesServiceDataAndResponseFlag() {
        let request = HATypedRequest<CallServiceResponse>.callService(
            domain: "weather",
            service: "get_forecasts",
            serviceData: ["type": "daily"],
            returnResponse: true
        ).request

        #expect(request.type == .webSocket("call_service"))
        #expect(request.data["domain"] as? String == "weather")
        #expect(request.data["service"] as? String == "get_forecasts")
        #expect(serviceData(of: request)?["type"] as? String == "daily")
        #expect(request.data["return_response"] as? Bool == true)
    }

    @Test func callEntityServiceAddsEntityIdToServiceData() {
        let request = VoidRequest.callEntityService(
            domain: .climate,
            .setTemperature,
            entityId: "climate.living_room",
            data: ["temperature": 21]
        ).request

        #expect(request.data["domain"] as? String == "climate")
        #expect(request.data["service"] as? String == "set_temperature")
        let data = serviceData(of: request)
        #expect(data?["entity_id"] as? String == "climate.living_room")
        #expect(data?["temperature"] as? Int == 21)
    }

    @Test func callEntityServiceDefaultsToOnlyTheEntity() {
        let request = VoidRequest.callEntityService(domain: .vacuum, .start, entityId: "vacuum.robot").request

        #expect(request.data["service"] as? String == "start")
        #expect(serviceData(of: request)?.count == 1)
        #expect(serviceData(of: request)?["entity_id"] as? String == "vacuum.robot")
    }

    @Test func toggleDomainTargetsTheEntity() {
        let request = VoidRequest.toggleDomain(domain: .switch, entityId: "switch.fan").request

        #expect(request.data["domain"] as? String == "switch")
        #expect(request.data["service"] as? String == "toggle")
        #expect(target(of: request) == ["entity_id": "switch.fan"])
    }

    @Test func runScriptTurnsOnTheScript() {
        let request = VoidRequest.runScript(entityId: "script.morning").request

        #expect(request.data["domain"] as? String == "script")
        #expect(request.data["service"] as? String == "turn_on")
        #expect(target(of: request) == ["entity_id": "script.morning"])
    }

    @Test func applySceneTurnsOnTheScene() {
        let request = VoidRequest.applyScene(entityId: "scene.movie").request

        #expect(request.data["domain"] as? String == "scene")
        #expect(request.data["service"] as? String == "turn_on")
        #expect(target(of: request) == ["entity_id": "scene.movie"])
    }

    @Test func triggerTriggersTheAutomation() {
        let request = VoidRequest.trigger(entityId: "automation.lights").request

        #expect(request.data["domain"] as? String == "automation")
        #expect(request.data["service"] as? String == "trigger")
        #expect(target(of: request) == ["entity_id": "automation.lights"])
    }

    @Test func pressButtonUsesTheGivenDomain() {
        let request = VoidRequest.pressButton(domain: .inputButton, entityId: "input_button.bell").request

        #expect(request.data["domain"] as? String == "input_button")
        #expect(request.data["service"] as? String == "press")
        #expect(target(of: request) == ["entity_id": "input_button.bell"])
    }

    @Test func lockAndUnlock() {
        let lock = VoidRequest.lockLock(entityId: "lock.front").request
        let unlock = VoidRequest.unlockLock(entityId: "lock.front").request

        #expect(lock.data["domain"] as? String == "lock")
        #expect(lock.data["service"] as? String == "lock")
        #expect(target(of: lock) == ["entity_id": "lock.front"])
        #expect(unlock.data["domain"] as? String == "lock")
        #expect(unlock.data["service"] as? String == "unlock")
        #expect(target(of: unlock) == ["entity_id": "lock.front"])
    }

    // MARK: - Registries and lookups

    @Test func registryRequestsUseTheirWebSocketCommands() {
        #expect(VoidRequest.configAreasRegistry().request.type == .webSocket("config/area_registry/list"))
        #expect(VoidRequest.configFloorRegistry().request.type == .webSocket("config/floor_registry/list"))
        #expect(VoidRequest.configDeviceRegistryList().request.type == .webSocket("config/device_registry/list"))
        #expect(
            VoidRequest.configEntityRegistryListForDisplay().request.type ==
                .webSocket("config/entity_registry/list_for_display")
        )
    }

    @Test func fetchCurrentUserAndStates() {
        #expect(VoidRequest.fetchCurrentUser().request.type == .webSocket("auth/current_user"))
        #expect(VoidRequest.fetchStates().request.type == .rest(.get, "states"))
    }

    @Test func vacuumAreaMappingReadsTheEntityRegistryEntry() {
        let request = VoidRequest.vacuumAreaMapping(entityId: "vacuum.robot").request

        #expect(request.type == .webSocket("config/entity_registry/get"))
        #expect(request.data["entity_id"] as? String == "vacuum.robot")
    }

    @Test func usagePredictionOnlySendsALimitWhenGiven() {
        let withoutLimit = VoidRequest.usagePredictionCommonControl().request
        let withLimit = VoidRequest.usagePredictionCommonControl(limit: 20).request

        #expect(withoutLimit.type == .webSocket("usage_prediction/common_control"))
        #expect(withoutLimit.data.isEmpty)
        #expect(withLimit.data["limit"] as? Int == 20)
    }

    @Test func frontendGetIconsSendsTheCategory() {
        let request = VoidRequest.frontendGetIcons(category: "entity_component").request

        #expect(request.type == .webSocket("frontend/get_icons"))
        #expect(request.data["category"] as? String == "entity_component")
    }

    // MARK: - Todo

    @Test func getItemFromTodoListAsksForTheResponse() {
        let request = VoidRequest.getItemFromTodoList(listId: "todo.shopping").request

        #expect(request.type == .rest(.post, "services/todo/get_items"))
        #expect(request.data["entity_id"] as? String == "todo.shopping")
        #expect(request.queryItems == [URLQueryItem(name: "return_response", value: "true")])
        #expect(request.shouldRetry)
    }

    @Test func addTodoItemWithOnlyASummary() {
        let request = VoidRequest.addTodoItem(listId: "todo.shopping", summary: "Milk").request

        #expect(request.type == .rest(.post, "services/todo/add_item"))
        #expect(request.data["entity_id"] as? String == "todo.shopping")
        #expect(request.data["item"] as? String == "Milk")
        #expect(request.data["description"] == nil)
        #expect(request.data["due_date"] == nil)
        #expect(request.data["due_datetime"] == nil)
    }

    @Test func addTodoItemPrefersDueDateOverDueDateTime() {
        let request = VoidRequest.addTodoItem(
            listId: "todo.shopping",
            summary: "Milk",
            description: "Semi-skimmed",
            dueDate: "2026-01-02",
            dueDateTime: "2026-01-02T10:00:00Z"
        ).request

        #expect(request.data["description"] as? String == "Semi-skimmed")
        #expect(request.data["due_date"] as? String == "2026-01-02")
        #expect(request.data["due_datetime"] == nil)
    }

    @Test func addTodoItemWithDueDateTime() {
        let request = VoidRequest.addTodoItem(
            listId: "todo.shopping",
            summary: "Milk",
            dueDateTime: "2026-01-02T10:00:00Z"
        ).request

        #expect(request.data["due_date"] == nil)
        #expect(request.data["due_datetime"] as? String == "2026-01-02T10:00:00Z")
    }

    @Test func updateTodoItemSendsOnlyProvidedFields() {
        let request = VoidRequest.updateTodoItem(
            listId: "todo.shopping",
            itemId: "uid-1",
            rename: "Oat milk",
            status: "needs_action"
        ).request

        #expect(request.type == .rest(.post, "services/todo/update_item"))
        #expect(request.data["entity_id"] as? String == "todo.shopping")
        #expect(request.data["item"] as? String == "uid-1")
        #expect(request.data["rename"] as? String == "Oat milk")
        #expect(request.data["status"] as? String == "needs_action")
        #expect(request.data["description"] == nil)
        #expect(request.data["due_date"] == nil)
        #expect(request.data["due_datetime"] == nil)
    }

    @Test func updateTodoItemWithDescriptionAndDueDate() {
        let request = VoidRequest.updateTodoItem(
            listId: "todo.shopping",
            itemId: "uid-1",
            rename: "Oat milk",
            status: "completed",
            description: "Two cartons",
            dueDate: "2026-03-04"
        ).request

        #expect(request.data["description"] as? String == "Two cartons")
        #expect(request.data["due_date"] as? String == "2026-03-04")
        #expect(request.data["due_datetime"] == nil)
    }

    @Test func updateTodoItemWithDueDateTime() {
        let request = VoidRequest.updateTodoItem(
            listId: "todo.shopping",
            itemId: "uid-1",
            rename: "Oat milk",
            status: "completed",
            dueDateTime: "2026-03-04T08:00:00Z"
        ).request

        #expect(request.data["due_date"] == nil)
        #expect(request.data["due_datetime"] as? String == "2026-03-04T08:00:00Z")
    }

    @Test func removeTodoItem() {
        let request = VoidRequest.removeTodoItem(listId: "todo.shopping", itemId: "uid-1").request

        #expect(request.type == .rest(.post, "services/todo/remove_item"))
        #expect(request.data["entity_id"] as? String == "todo.shopping")
        #expect(request.data["item"] as? String == "uid-1")
    }

    @Test func completeTodoItemMarksItCompleted() {
        let request = VoidRequest.completeTodoItem(listId: "todo.shopping", itemId: "uid-1").request

        #expect(request.type == .rest(.post, "services/todo/update_item"))
        #expect(request.data["item"] as? String == "uid-1")
        #expect(request.data["status"] as? String == "completed")
    }
}
