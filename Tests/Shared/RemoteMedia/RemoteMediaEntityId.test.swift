import Foundation
import Shared
import Testing

/// The accepted grammar is Home Assistant Core's `valid_entity_id`, restricted to ASCII. The cases
/// below that Core rejects are the ones its own `test_valid_entity_id` rejects.
struct RemoteMediaEntityIdTests {
    @Test(arguments: [
        "media_player.speaker",
        "media_player.living_room_2",
        "media_player.2",
        "media_player.a",
        "media_player." + String(repeating: "a", count: 242),
    ])
    func wellFormedMediaPlayerIdsAreAccepted(_ rawValue: String) throws {
        let entityId = try #require(RemoteMediaEntityId(rawValue))
        #expect(entityId.rawValue == rawValue)
    }

    @Test(arguments: [
        // Not a media player.
        "", "media_player", "light.kitchen", "media_playerx.speaker", "Media_player.speaker",
        // An empty object id.
        "media_player.",
        // Characters Core's slugs never contain.
        "media_player.Speaker", "media_player.bad-name", "media_player.a.b", "media_player.a b",
        "media_player.speaker ", " media_player.speaker", "media_player.speaker\0",
        // Underscores Core rejects: leading, trailing, and doubled anywhere in the id — its `(?!.+__)`
        // lookahead covers the object id as well as the domain (`light.kitchen__ceiling` in Core).
        "media_player._leading", "media_player.trailing_", "media_player.living__room", "media_player.a___b",
        "media_player._legacy__name_",
        // Would end the quoted literal the id sits in inside a server-side template.
        "media_player.speaker' }} {{ 7 * 7 }} {{ '", "media_player.speaker\"", "media_player.{{x}}",
        // Core's regex accepts these through Python's `$` and Unicode `\d`. Rejecting them is a
        // deliberate departure: no slugified entity id contains either.
        "media_player.speaker\n", "media_player.speaker\u{0663}",
        // Non-ASCII lookalikes.
        "media_player.café", "media_player.\u{FF53}peaker",
        // Longer than any entity id Home Assistant stores.
        "media_player." + String(repeating: "a", count: 243),
    ])
    func malformedIdsAreRejected(_ rawValue: String) {
        #expect(RemoteMediaEntityId(rawValue) == nil)
    }
}
