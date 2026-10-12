import Foundation
@testable import HomeAssistant
import Testing

/// Drives a session end to end against a scripted server speaking the real protocol.
struct SendspinSessionTests {
    private struct Harness {
        let connection = SendspinFakeConnection()
        let host = SendspinFakeSessionHost()
        let audio = SendspinFakeAudio()
        let credentials = SendspinMemoryCredentialStore()
        let session: SendspinSession
        let run: Task<Void, Never>
        var server: SendspinTestServer

        init(settings: SendspinPlayerSettings = .init(
            name: "Kitchen",
            volume: 50,
            isMuted: false,
            outputDelayMs: 0,
            allowsUnpairedAccess: true
        ), handshakeTimeout: TimeInterval = 30) {
            let session = SendspinSession(
                connection: connection,
                host: host,
                credentials: credentials,
                audio: audio,
                settings: settings,
                deviceInfo: SendspinDeviceInfo(productName: "iPhone", manufacturer: "Apple", softwareVersion: "1"),
                handshakeTimeout: handshakeTimeout
            )
            self.session = session
            self.run = Task { await session.run() }
            self.server = SendspinTestServer(connection: connection)
        }

        /// Handshake and hellos, up to the client's hello.
        mutating func connect(reference: SendspinPskReference? = nil, psk: SendspinPsk = .sentinel) async throws
            -> SendspinClientHello {
            try await server.handshake(
                reference: reference ?? SendspinPskReference(pskID: psk.identifier, category: .sentinel),
                psk: psk
            )
            try server.send(type: "server/hello", payload: SendspinServerHello(name: "Music Assistant", languages: nil))
            return try await server.receive(SendspinClientHello.self, type: "client/hello")
        }

        mutating func activate(
            _ activities: [String],
            roles: [String]?,
            pairing: SendspinActivatePairing? = nil
        ) throws {
            try server.send(
                type: "server/activate",
                payload: SendspinServerActivate(activities: activities, activeRoles: roles, pairing: pairing)
            )
        }

        /// Answers client/time requests until the session reports itself available.
        mutating func synchronizeClock() async throws -> SendspinClientState {
            for _ in 0 ..< 2 {
                let request = try await server.receive(SendspinClientTime.self, type: "client/time")
                try server.send(type: "server/time", payload: SendspinServerTime(
                    clientTransmitted: request.clientTransmitted,
                    serverReceived: request.clientTransmitted + 5000,
                    serverTransmitted: request.clientTransmitted + 5100
                ))
            }
            return try await server.receive(SendspinClientState.self, type: "client/state")
        }
    }

    @Test func playsAStreamAndFollowsTheServer() async throws {
        var harness = Harness()
        let hello = try await harness.connect()
        #expect(hello.name == "Kitchen")
        #expect(hello.supportedRoles == SendspinSession.supportedRoles)
        #expect(hello.playerSupport.supportedFormats == SendspinSession.supportedFormats)
        #expect(hello.unpairedAccess.enabled)

        try harness.activate(["playback"], roles: SendspinSession.supportedRoles)
        let initial = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        // Not available until the clock can place audio on the server's timeline.
        #expect(initial.available == false)
        #expect(initial.player?.volume == 50)
        #expect(initial.player?.supportedCommands == SendspinPlayerStateReport.supportedCommands)

        let ready = try await harness.synchronizeClock()
        #expect(ready.available)
        #expect(harness.audio.mapping != nil)

        try harness.server.send(type: "server/state", payload: SendspinServerState(
            metadata: SendspinMetadataState(
                timestamp: 0,
                title: "Song",
                artist: "Artist",
                albumArtist: nil,
                album: nil,
                artworkURL: nil,
                year: nil,
                track: nil,
                progress: nil
            ),
            controller: SendspinControllerState(
                supportedCommands: ["play", "pause"],
                volume: 50,
                muted: false,
                repeat: "off",
                shuffle: false,
                seekMaxMs: nil
            )
        ))
        try harness.server.send(type: "group/update", payload: SendspinGroupUpdate(
            playbackState: "playing",
            groupID: "group",
            groupName: "Downstairs"
        ))
        let format = SendspinStreamFormat(codec: "pcm", sampleRate: 48000, channels: 2, bitDepth: 16, codecHeader: nil)
        try harness.server.send(type: "stream/start", payload: SendspinStreamStart(player: format))
        var chunk = Data([4, 0, 0, 0, 0, 0, 0x0F, 0x42, 0x40, 0, 0, 0, 0])
        chunk.append(contentsOf: [0, 0, 0, 0])
        try harness.server.sendPlaintext(chunk)
        try harness.server.send(type: "stream/clear", payload: SendspinStreamRoles(roles: ["player"]))

        // A volume command is answered with the new state, which also proves everything sent
        // before it was handled.
        try harness.server.send(type: "server/command", payload: SendspinServerCommand(player: SendspinPlayerCommand(
            command: "volume",
            volume: 20,
            mute: nil,
            outputDelayMs: nil
        )))
        let afterVolume = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(afterVolume.player?.volume == 20)
        #expect(harness.audio.started == [format])
        #expect(harness.audio.enqueued.map(\.timestamp) == [1_000_000])
        #expect(harness.audio.clearCount == 1)
        #expect(harness.audio.volume?.0 == 20)
        #expectawait (harness.session.isStreaming)
        #expectawait (harness.session.supportedControllerCommands == ["play", "pause"])

        await harness.session.sendControllerCommand(SendspinControllerCommand(command: "pause"))
        let command = try await harness.server.receive(SendspinClientCommand.self, type: "client/command")
        #expect(command.controller.command == "pause")
        // Commands the group does not accept are never sent.
        await harness.session.sendControllerCommand(SendspinControllerCommand(command: "next"))

        try harness.server.send(type: "server/command", payload: SendspinServerCommand(player: SendspinPlayerCommand(
            command: "set_output_delay",
            volume: nil,
            mute: nil,
            outputDelayMs: 9000
        )))
        let afterDelay = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(afterDelay.player?.outputDelayMs == 5000)
        #expect(harness.audio.outputDelay == 5000)

        try harness.server.send(type: "stream/end", payload: SendspinStreamRoles(roles: nil))
        try harness.server.send(type: "server/command", payload: SendspinServerCommand(player: SendspinPlayerCommand(
            command: "mute",
            volume: nil,
            mute: true,
            outputDelayMs: nil
        )))
        let afterMute = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(afterMute.player?.muted == true)
        #expect(harness.audio.stopCount == 1)
        #expectawait (harness.session.isStreaming == false)

        await harness.session.setAvailable(false)
        let unavailable = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(unavailable.available == false)

        await harness.session.update(settings: .init(
            name: "Kitchen",
            volume: 70,
            isMuted: false,
            outputDelayMs: 5000,
            allowsUnpairedAccess: true
        ))
        let updated = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(updated.player?.volume == 70)

        await harness.session.disconnect(reason: .shutdown)
        let goodbye = try await harness.server.receive(SendspinClientGoodbye.self, type: "client/goodbye")
        #expect(goodbye.reason == .shutdown)
        await harness.run.value

        let events = await harness.host.events
        #expect(events.contains(.connected(serverName: "Music Assistant")))
        #expect(events.contains(.streamStarted))
        #expect(events.contains(.streamEnded))
        #expect(events.contains(.volumeChanged(volume: 20, muted: false)))
        #expect(events.contains(.outputDelayChanged(milliseconds: 5000)))
        #expect(events.contains(.groupUpdated(SendspinGroupUpdate(
            playbackState: "playing",
            groupID: "group",
            groupName: "Downstairs"
        ))))
        #expect(events.contains { event in
            if case let .metadata(metadata, _) = event { return metadata?.title == "Song" }
            return false
        })
        #expectawait (harness.host.candidates.first?.activity == .playback)
        #expectawait (harness.host.closeCount == 1)
        #expect(harness.credentials.lastPlaybackServerID == harness.server.serverID)
    }

    /// The Pairing PSK flow, then the re-handshake onto the new record, then the server dropping it.
    @Test func pairsAndRehandshakesOntoTheNewRecord() async throws {
        var harness = Harness(settings: .init(
            name: "Kitchen",
            volume: 100,
            isMuted: false,
            outputDelayMs: 0,
            allowsUnpairedAccess: false
        ))
        let pairingPsk = harness.credentials.pairingPsk()
        let hello = try await harness.connect(
            reference: SendspinPskReference(pskID: pairingPsk.identifier, category: .pairing),
            psk: pairingPsk
        )
        #expect(hello.supportedPairMethods.pairingPsk.locations == ["device"])
        #expect(hello.unpairedAccess.enabled == false)

        try harness.activate(
            ["pairing"],
            roles: [],
            pairing: SendspinActivatePairing(method: "pairing_psk", format: nil)
        )
        let pairInit = try await harness.server.receive(SendspinPairInit.self, type: "client/pair-init")
        #expect(pairInit.pairingIndex == 1)
        let finalize = try await harness.server.receive(SendspinPairFinalize.self, type: "client/pair-finalize")
        let longTermPsk = try #require(
            SendspinBase64URL.decode(finalize.longTermPsk)
                .flatMap { SendspinPsk(bytes: $0) }
        )

        try harness.server.send(type: "server/pair-finalize", payload: SendspinEmptyPayload())
        try await harness.server.rehandshake(
            reference: SendspinPskReference(pskID: longTermPsk.identifier, category: .longTerm),
            psk: longTermPsk
        )
        try harness.activate(["playback"], roles: [SendspinSession.playerRole])
        let state = try await harness.server.receive(SendspinClientState.self, type: "client/state")
        #expect(state.player != nil)
        #expectawait (harness.session.isPaired)
        #expect(harness.credentials.pairingRecords().map(\.serverID) == [harness.server.serverID])
        #expectawait (harness.host.events.contains(.paired(serverName: "Music Assistant")))

        try harness.server.send(type: "server/unpair", payload: SendspinEmptyPayload())
        let goodbye = try await harness.server.receive(SendspinClientGoodbye.self, type: "client/goodbye")
        #expect(goodbye.reason == .unpaired)
        #expect(harness.credentials.pairingRecords().isEmpty)
        await harness.run.value
    }

    @Test func refusesPlaybackWithoutUnpairedAccess() async throws {
        var harness = Harness(settings: .init(
            name: "Kitchen",
            volume: 100,
            isMuted: false,
            outputDelayMs: 0,
            allowsUnpairedAccess: false
        ))
        _ = try await harness.connect()
        try harness.activate(["playback"], roles: [SendspinSession.playerRole])
        let goodbye = try await harness.server.receive(SendspinClientGoodbye.self, type: "client/goodbye")
        #expect(goodbye.reason == .pairingRequired)
        await harness.run.value
        #expectawait (harness.host.candidates.isEmpty)
    }

    @Test func stepsAsideWhenTheHostRefusesTheConnection() async throws {
        var harness = Harness()
        await harness.host.setAdmits(false)
        _ = try await harness.connect()
        try harness.activate(["playback"], roles: [SendspinSession.playerRole])
        let goodbye = try await harness.server.receive(SendspinClientGoodbye.self, type: "client/goodbye")
        #expect(goodbye.reason == .concurrentAttempt)
        await harness.run.value
        #expect(harness.audio.stopCount == 0)
    }

    @Test func refusesAPairingMethodItDoesNotOffer() async throws {
        var harness = Harness()
        _ = try await harness.connect()
        try harness.activate(
            ["pairing"],
            roles: [],
            pairing: SendspinActivatePairing(method: "static_pairing_code", format: nil)
        )
        let abort = try await harness.server.receive(SendspinPairAbort.self, type: "pair/abort")
        #expect(abort.reason == "method_not_supported")
        await harness.session.displace()
        let goodbye = try await harness.server.receive(SendspinClientGoodbye.self, type: "client/goodbye")
        #expect(goodbye.reason == .anotherServer)
        await harness.run.value
    }

    /// A server referencing a record this device lost is answered under the Sentinel PSK, so the
    /// connection survives to carry a re-pairing.
    @Test func fallsBackToTheSentinelForAnUnknownCredential() async throws {
        var harness = Harness()
        _ = try await harness.connect(
            reference: SendspinPskReference(pskID: SendspinPsk.generate().identifier, category: .longTerm),
            psk: .sentinel
        )
        #expectawait (harness.session.isPaired == false)
        await harness.session.disconnect(reason: .userRequest)
        await harness.run.value
    }

    @Test func endsWhenTheServerRejectsTheInit() async throws {
        let harness = Harness()
        _ = try await harness.connection.nextSent()
        harness.connection.deliver(
            .text,
            Data(#"{"type":"server/error","payload":{"reason":"unsupported_version"}}"#.utf8)
        )
        await harness.run.value
        #expect(harness.connection.isClosed)
        #expectawait (harness.host.closeCount == 1)
    }

    @Test func dropsAServerThatNeverActivates() async throws {
        var harness = Harness(handshakeTimeout: 0.5)
        _ = try await harness.connect()
        await harness.run.value
        #expect(harness.connection.isClosed)
    }
}
