@testable import HomeAssistant
import Testing

struct AudioPlayerTests {
    /// AVPlayer streams the reply over its own connection, so the cookies used by native requests
    /// only reach the server if the player's asset carries them.
    @Test("Streaming a reply sends the mirrored cookies")
    func streamingSendsMirroredCookies() async throws {
        let player = AudioPlayer()
        defer { player.pause() }

        try await CookieRecordingServer.expectMirroredCookie(path: "api/tts_proxy/reply.mp3") { url in
            player.play(url: url, server: nil)
        }
    }
}
