@testable import Shared
import Testing

struct RemoteMediaSelectionTests {
    /// The identifier length-prefixes the server id, so a different split of the same characters
    /// cannot produce the same session.
    @Test func identifiersDoNotCollideAcrossServers() {
        let first = RemoteMediaSelection(serverId: "ab", entityId: "media_player.x")
        let second = RemoteMediaSelection(serverId: "a", entityId: "bmedia_player.x")
        #expect(first.id != second.id)
    }
}
