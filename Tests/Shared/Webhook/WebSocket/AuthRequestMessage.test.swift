import Foundation
@testable import Shared
import Testing

struct AuthRequestMessageTests {
    @Test func initializerSetsTheTokenAndType() {
        let message = AuthRequestMessage(accessToken: "secret-token")

        #expect(message.MessageType == "auth")
        #expect(message.AccessToken == "secret-token")
        #expect(message.ID == nil)
    }

    @Test func encodesTheTokenAlongsideTheType() throws {
        let data = try JSONEncoder().encode(AuthRequestMessage(accessToken: "secret-token"))
        let dictionary = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(dictionary["access_token"] as? String == "secret-token")
        #expect(dictionary["type"] as? String == "auth")
        #expect(dictionary["id"] == nil)
    }

    @Test func decodesTheTokenAndTheSuperclassFields() throws {
        let json = #"{"access_token": "decoded-token", "super": {"type": "auth", "id": 2}}"#

        let message = try JSONDecoder().decode(AuthRequestMessage.self, from: Data(json.utf8))

        #expect(message.AccessToken == "decoded-token")
        #expect(message.MessageType == "auth")
        #expect(message.ID == 2)
    }

    @Test func decodingWithoutATokenFails() {
        let json = #"{"super": {"type": "auth"}}"#

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AuthRequestMessage.self, from: Data(json.utf8))
        }
    }
}
