import Foundation
@testable import HomeAssistant
import Testing

struct SendspinMessageCodingTests {
    private func object(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func encodesClientInitWithTheWireKeys() throws {
        let data = try SendspinOutgoingMessage.clientInit(clientId: "abc", suite: "25519_ChaChaPoly_SHA256").encoded()
        let envelope = try object(data)
        #expect(envelope["type"] as? String == "client/init")
        let payload = try #require(envelope["payload"] as? [String: Any])
        #expect(payload["client_id"] as? String == "abc")
        #expect(payload["version"] as? Int == 1)
        #expect(payload["suite"] as? String == "25519_ChaChaPoly_SHA256")
    }

    @Test func encodesTheClientStatePlayerObject() throws {
        let player = SendspinPlayerState(
            volume: 42,
            muted: true,
            outputDelayMs: 120,
            requiredLeadTimeMs: 300,
            minBufferMs: 700,
            supportedCommands: ["volume", "mute", "set_output_delay"],
            format: nil
        )
        let data = try SendspinOutgoingMessage.clientState(available: true, player: player).encoded()
        let payload = try #require(try object(data)["payload"] as? [String: Any])
        #expect(payload["available"] as? Bool == true)
        let encoded = try #require(payload["player"] as? [String: Any])
        #expect(encoded["output_delay_ms"] as? Int == 120)
        #expect(encoded["required_lead_time_ms"] as? Int == 300)
        #expect(encoded["min_buffer_ms"] as? Int == 700)
        #expect(encoded["supported_commands"] as? [String] == ["volume", "mute", "set_output_delay"])
        // An absent preference means the server picks by supported_formats priority.
        #expect(encoded["format"] == nil)
    }

    @Test func decodesStreamStartWithACodecHeader() throws {
        let json = """
        {"type":"stream/start","payload":{"server_transmitted":99,"player":
        {"codec":"flac","sample_rate":44100,"channels":2,"bit_depth":16,"codec_header":"ZkxhQw=="}}}
        """
        guard case let .streamStart(start) = try SendspinIncomingMessage.decode(Data(json.utf8)) else {
            Issue.record("expected stream/start")
            return
        }
        #expect(start.serverTransmitted == 99)
        #expect(start.player?.format.codec == .flac)
        #expect(start.player?.format.sampleRate == 44_100)
        #expect(start.player?.codecHeader == Data("fLaC".utf8))
    }

    /// A role object is tri-state: absent leaves it alone, null clears it, an object replaces it.
    @Test func distinguishesAbsentFromClearedRoleState() throws {
        let cleared = """
        {"type":"server/state","payload":{"metadata":null}}
        """
        guard case let .serverState(state) = try SendspinIncomingMessage.decode(Data(cleared.utf8)) else {
            Issue.record("expected server/state")
            return
        }
        #expect(state.metadata == .cleared)
        #expect(state.controller == .unchanged)

        let updated = """
        {"type":"server/state","payload":{"metadata":{"timestamp":10,"title":"Track","progress":
        {"track_progress":1000,"track_duration":180000,"playback_speed":1000}}}}
        """
        guard case let .serverState(next) = try SendspinIncomingMessage.decode(Data(updated.utf8)) else {
            Issue.record("expected server/state")
            return
        }
        guard case let .updated(metadata) = next.metadata else {
            Issue.record("expected updated metadata")
            return
        }
        #expect(metadata.title == "Track")
        #expect(metadata.progress?.trackDuration == 180_000)
    }

    @Test func extrapolatesTrackPositionFromTheServerClock() throws {
        let json = """
        {"type":"server/state","payload":{"metadata":{"timestamp":1000000,"progress":
        {"track_progress":5000,"track_duration":180000,"playback_speed":1000}}}}
        """
        guard
            case let .serverState(state) = try SendspinIncomingMessage.decode(Data(json.utf8)),
            case let .updated(metadata) = state.metadata
        else {
            Issue.record("expected metadata")
            return
        }
        // Two seconds later on the server clock, the position has moved two seconds.
        #expect(metadata.positionMilliseconds(atServerTime: 3_000_000) == 7_000)
        // A paused track holds its position however much time passes.
        #expect(metadata.positionMilliseconds(atServerTime: 60_000_000) == 180_000)
    }

    @Test func decodesActivationAndItsActivities() throws {
        let json = """
        {"type":"server/activate","payload":{"activities":["playback"],"active_roles":
        ["player@v1","metadata@v1"]}}
        """
        guard case let .activate(activation) = try SendspinIncomingMessage.decode(Data(json.utf8)) else {
            Issue.record("expected server/activate")
            return
        }
        #expect(activation.isPlayback)
        #expect(activation.isPairing == false)
        #expect(activation.activeRoles == ["player@v1", "metadata@v1"])
    }

    @Test func reportsUnknownMessagesRatherThanFailing() throws {
        let json = #"{"type":"server/something-new","payload":{}}"#
        guard case let .unrecognized(type) = try SendspinIncomingMessage.decode(Data(json.utf8)) else {
            Issue.record("expected an unrecognized message")
            return
        }
        #expect(type == "server/something-new")
    }
}
