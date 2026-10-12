import Foundation
@testable import HomeAssistant
import Testing

struct SendspinMessagesTests {
    private func decode(_ json: String) throws -> SendspinServerMessage? {
        try SendspinServerMessage.decode(Data(json.utf8))
    }

    @Test func decodesEveryServerMessage() throws {
        #expecttry (
            decode(#"{"type":"server/hello","payload":{"name":"MA","languages":["en"]}}"#)
                == .hello(SendspinServerHello(name: "MA", languages: ["en"]))
        )
        #expecttry (
            decode(#"{"type":"server/activate","payload":{"activities":["playback"],"active_roles":["player@v1"]}}"#)
                == .activate(SendspinServerActivate(activities: ["playback"], activeRoles: ["player@v1"], pairing: nil))
        )
        #expecttry (decode(
            #"{"type":"server/time","payload":{"client_transmitted":1,"server_received":2,"server_transmitted":3}}"#
        ) == .time(SendspinServerTime(clientTransmitted: 1, serverReceived: 2, serverTransmitted: 3)))
        #expecttry (
            decode(#"{"type":"server/command","payload":{"player":{"command":"volume","volume":30}}}"#)
                == .command(SendspinServerCommand(player: SendspinPlayerCommand(
                    command: "volume",
                    volume: 30,
                    mute: nil,
                    outputDelayMs: nil
                )))
        )
        #expecttry (decode(
            #"{"type":"stream/start","payload":{"server_transmitted":1,"player":{"codec":"pcm","sample_rate":48000,"channels":2,"bit_depth":16}}}"#
        ) == .streamStart(SendspinStreamStart(player: SendspinStreamFormat(
            codec: "pcm",
            sampleRate: 48000,
            channels: 2,
            bitDepth: 16,
            codecHeader: nil
        ))))
        #expecttry (
            decode(#"{"type":"stream/clear","payload":{"server_transmitted":1,"roles":["player"]}}"#)
                == .streamClear(SendspinStreamRoles(roles: ["player"]))
        )
        #expecttry (decode(#"{"type":"stream/end","payload":{}}"#) == .streamEnd(SendspinStreamRoles(roles: nil)))
        #expecttry (
            decode(
                #"{"type":"group/update","payload":{"playback_state":"playing","group_id":"g","group_name":"Kitchen"}}"#
            )
                == .groupUpdate(SendspinGroupUpdate(playbackState: "playing", groupID: "g", groupName: "Kitchen"))
        )
        #expecttry (decode(#"{"type":"server/unpair","payload":{}}"#) == .unpair)
        #expecttry (decode(#"{"type":"server/pair-finalize","payload":{}}"#) == .pairFinalize)
        #expecttry (
            decode(#"{"type":"pair/abort","payload":{"reason":"user_cancelled"}}"#)
                == .pairAbort(SendspinPairAbort(reason: "user_cancelled"))
        )
        #expecttry (
            decode(#"{"type":"noise/handshake","payload":{"data":"AA"}}"#)
                == .handshake(SendspinNoiseHandshakeMessage(data: "AA"))
        )
    }

    @Test func decodesServerState() throws {
        let message = try decode(#"""
        {"type":"server/state","payload":{
          "metadata":{"timestamp":10,"title":"Song","artist":"Artist","progress":{"track_progress":1000,"track_duration":5000,"playback_speed":1000}},
          "controller":{"supported_commands":["play","pause"],"volume":40,"muted":false,"repeat":"off","shuffle":true}
        }}
        """#)
        guard case let .state(state)? = message else {
            Issue.record("Expected server/state")
            return
        }
        #expect(state.metadata?.title == "Song")
        #expect(state.controller?.supportedCommands == ["play", "pause"])
        #expect(state.controller?.shuffle == true)
    }

    /// Unknown types are ignored, as the specification requires; broken messages are not.
    @Test func ignoresUnknownTypesButRejectsGarbage() throws {
        #expecttry (decode(#"{"type":"server/something-new","payload":{"x":1}}"#) == nil)
        #expect(throws: (any Error).self) { try decode("not json") }
        #expect(throws: (any Error).self) { try decode(#"{"type":"server/time","payload":{}}"#) }
    }

    @Test func encodesTheClientHelloWithVersionedKeys() throws {
        let hello = SendspinClientHello(
            name: "Kitchen",
            deviceInfo: SendspinDeviceInfo(productName: "iPhone", manufacturer: "Apple", softwareVersion: "1"),
            supportedRoles: SendspinSession.supportedRoles,
            playerSupport: SendspinPlayerSupport(
                supportedFormats: SendspinSession.supportedFormats,
                bufferCapacity: 100
            ),
            supportedPairMethods: SendspinSupportedPairMethods(
                pairingPsk: SendspinPairMethodDescriptor(locations: ["device"])
            ),
            unpairedAccess: SendspinUnpairedAccess(enabled: true)
        )
        let json = try #requiretry (
            JSONSerialization
                .jsonObject(with: SendspinClientMessage.hello(hello).encoded()) as? [String: Any]
        )
        #expect(json["type"] as? String == "client/hello")
        let payload = try #require(json["payload"] as? [String: Any])
        #expect(payload["player@v1_support"] != nil)
        #expect(payload["supported_pair_methods"] as? [String: Any] != nil)
        #expect(payload["unpaired_access"] as? [String: Bool] == ["enabled": true])
    }

    @Test func namesEveryClientMessage() throws {
        let messages: [(SendspinClientMessage, String)] = [
            (.time(SendspinClientTime(clientTransmitted: 1)), "client/time"),
            (.state(SendspinClientState(available: true, player: nil)), "client/state"),
            (.command(SendspinClientCommand(controller: SendspinControllerCommand(command: "play"))), "client/command"),
            (.goodbye(SendspinClientGoodbye(reason: .shutdown)), "client/goodbye"),
            (.pairInit(SendspinPairInit(pairingIndex: 1)), "client/pair-init"),
            (.pairFinalize(SendspinPairFinalize(longTermPsk: "AA")), "client/pair-finalize"),
            (.pairAbort(SendspinPairAbort(reason: "attempt_timeout")), "pair/abort"),
            (.handshake(SendspinNoiseHandshakeMessage(data: "AA")), "noise/handshake"),
        ]
        for (message, type) in messages {
            let header = try JSONDecoder().decode(SendspinMessageHeader.self, from: message.encoded())
            #expect(header.type == type)
        }
    }

    @Test func extrapolatesTheTrackPosition() {
        let metadata = SendspinMetadataState(
            timestamp: 1_000_000,
            title: nil,
            artist: nil,
            albumArtist: nil,
            album: nil,
            artworkURL: nil,
            year: nil,
            track: nil,
            progress: SendspinTrackProgress(trackProgress: 10000, trackDuration: 12000, playbackSpeed: 1000)
        )
        #expect(metadata.trackPosition(atServerTime: 2_000_000) == 11000)
        #expect(metadata.trackPosition(atServerTime: 9_000_000) == 12000)
        #expect(metadata.trackPosition(atServerTime: 0) == 9000)
    }
}
