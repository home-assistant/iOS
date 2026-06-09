import HAKit
@testable import Shared
import Testing

struct CallServiceResponseTests {
    @Test func decodesResponseDictionary() throws {
        let data = HAData(value: [
            "context": ["id": "abc"],
            "response": ["forecast": ["temperature": 21]],
        ])
        let response = try CallServiceResponse(data: data)

        #expect(response.hasResponse == true)
        let dictionary = try #require(response.response as? [String: Any])
        #expect(dictionary["forecast"] != nil)
    }

    @Test func noResponseKeyHasNoResponse() throws {
        let data = HAData(value: ["context": ["id": "abc"]])
        let response = try CallServiceResponse(data: data)

        #expect(response.hasResponse == false)
        #expect(response.jsonString() == nil)
    }

    @Test func emptyResponseDictionaryHasNoResponse() throws {
        let data = HAData(value: ["context": [:], "response": [String: Any]()])
        let response = try CallServiceResponse(data: data)

        #expect(response.hasResponse == false)
        #expect(response.jsonString() == nil)
    }

    @Test func nullResponseHasNoResponse() throws {
        let data = HAData(value: ["response": NSNull()])
        let response = try CallServiceResponse(data: data)

        #expect(response.hasResponse == false)
        #expect(response.jsonString() == nil)
    }

    @Test func nonDictionaryDataHasNoResponse() throws {
        let response = try CallServiceResponse(data: HAData(value: "ok"))

        #expect(response.hasResponse == false)
        #expect(response.jsonString() == nil)
    }

    @Test func serializesDictionaryResponseToJSON() throws {
        let data = HAData(value: ["response": ["count": 2, "name": "kitchen"]])
        let response = try CallServiceResponse(data: data)

        let json = try #require(response.jsonString())
        // sortedKeys makes the output deterministic.
        #expect(json == "{\"count\":2,\"name\":\"kitchen\"}")
    }

    @Test func serializesArrayResponseToJSON() throws {
        let data = HAData(value: ["response": [1, 2, 3]])
        let response = try CallServiceResponse(data: data)

        #expect(response.jsonString() == "[1,2,3]")
    }

    @Test func wrapsPrimitiveResponseForSerialization() throws {
        let data = HAData(value: ["response": "hello"])
        let response = try CallServiceResponse(data: data)

        #expect(response.hasResponse == true)
        #expect(response.jsonString() == "{\"response\":\"hello\"}")
    }
}
