import Foundation
@testable import Shared
import Testing

/// The REST transport App Intents fall back to on watchOS, where no WebSocket is available.
struct AppIntentServerAPIRESTTests {
    private func json(_ string: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(string.utf8), options: [.fragmentsAllowed])
    }

    // MARK: - call_service

    @Test func callServiceResponseCarriesServiceResponse() throws {
        let payload = try json("""
        {
            "changed_states": [],
            "service_response": {"events": [{"summary": "Standup"}]}
        }
        """)

        let response = try AppIntentServerAPI.callServiceResponse(from: payload)

        #expect(response.hasResponse)
        #expect(response.jsonString() == #"{"events":[{"summary":"Standup"}]}"#)
    }

    @Test func callServiceResponseWithoutReturnResponseHasNoResponse() throws {
        // Without `?return_response` the endpoint answers with a bare array of changed states.
        let payload = try json(#"[{"entity_id": "light.kitchen"}]"#)

        let response = try AppIntentServerAPI.callServiceResponse(from: payload)

        #expect(response.hasResponse == false)
        #expect(response.jsonString() == nil)
    }

    // MARK: - services

    @Test func actionDefinitionsAreFlattenedAndSorted() throws {
        let payload = try json("""
        [
            {
                "domain": "light",
                "services": {
                    "turn_on": {"name": "Turn on", "description": "Turns a light on"},
                    "turn_off": {"name": "Turn off", "description": "Turns a light off"}
                }
            },
            {
                "domain": "calendar",
                "services": {
                    "get_events": {
                        "name": "Get events",
                        "description": "Reads events",
                        "response": {"optional": true}
                    }
                }
            }
        ]
        """)

        let definitions = AppIntentServerAPI.actionDefinitions(fromRESTServices: payload)

        #expect(definitions.map(\.actionId) == ["calendar.get_events", "light.turn_off", "light.turn_on"])
        #expect(definitions[0].supportsResponse)
        #expect(definitions[1].supportsResponse == false)
        #expect(definitions[0].displayName == "Get events")
        #expect(definitions[0].displayDescription == "Reads events")
    }

    @Test func actionDefinitionsFallBackToServiceNameWhenOnlyATranslationKeyIsShipped() throws {
        let payload = try json("""
        [{"domain": "light", "services": {"turn_on": {"name": "component.light.services.turn_on.name"}}}]
        """)

        let definitions = AppIntentServerAPI.actionDefinitions(fromRESTServices: payload)

        #expect(definitions.count == 1)
        // REST carries no translations, and a raw key is useless as display text.
        #expect(definitions[0].displayName == "turn_on")
        #expect(definitions[0].displayDescription == nil)
    }

    @Test func actionDefinitionsIgnoreUnexpectedPayloads() throws {
        let payload = try json("{}")

        #expect(AppIntentServerAPI.actionDefinitions(fromRESTServices: payload).isEmpty)
    }

    // MARK: - states

    @Test func entitiesKeepOnlyTheRequestedDomainSortedByFriendlyName() throws {
        let payload = try json("""
        [
            {
                "entity_id": "camera.porch",
                "state": "idle",
                "attributes": {"friendly_name": "Porch"},
                "last_changed": "2026-07-28T10:00:00.000000+00:00",
                "last_updated": "2026-07-28T10:00:00.000000+00:00",
                "context": {"id": "context", "parent_id": null, "user_id": null}
            },
            {
                "entity_id": "camera.driveway",
                "state": "idle",
                "attributes": {"friendly_name": "Driveway"},
                "last_changed": "2026-07-28T10:00:00.000000+00:00",
                "last_updated": "2026-07-28T10:00:00.000000+00:00",
                "context": {"id": "context", "parent_id": null, "user_id": null}
            },
            {
                "entity_id": "light.kitchen",
                "state": "on",
                "attributes": {},
                "last_changed": "2026-07-28T10:00:00.000000+00:00",
                "last_updated": "2026-07-28T10:00:00.000000+00:00",
                "context": {"id": "context", "parent_id": null, "user_id": null}
            }
        ]
        """)

        let entities = AppIntentServerAPI.entities(fromRESTStates: payload, domain: .camera)

        #expect(entities.map(\.entityId) == ["camera.driveway", "camera.porch"])
    }

    // MARK: - conversation

    @Test func assistAnswerReadsPlainSpeech() throws {
        let payload = try json("""
        {
            "response": {
                "speech": {"plain": {"speech": "Turned on the kitchen light", "extra_data": null}},
                "response_type": "action_done"
            },
            "conversation_id": "01JD"
        }
        """)

        #expect(try AppIntentServerAPI.assistAnswer(from: payload) == "Turned on the kitchen light")
    }

    @Test func assistAnswerSurfacesAgentErrorsAsUserFacingText() throws {
        let payload = try json("""
        {
            "response": {
                "speech": {"plain": {"speech": "Sorry, I am not aware of any device called kitchen"}},
                "response_type": "error"
            }
        }
        """)

        #expect(throws: ShortcutAppIntentError.self) {
            try AppIntentServerAPI.assistAnswer(from: payload)
        }
    }

    @Test func assistAnswerRejectsUnexpectedPayloads() throws {
        let payload = try json(#"{"conversation_id": "01JD"}"#)

        #expect(throws: HomeAssistantRESTError.invalidResponse) {
            try AppIntentServerAPI.assistAnswer(from: payload)
        }
    }
}
