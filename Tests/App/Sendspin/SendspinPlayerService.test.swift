import Foundation
@testable import HomeAssistant
import Testing

/// Runs the service's real listener on loopback, with a real WebSocket client playing the server.
@Suite(.serialized)
struct SendspinPlayerServiceTests {
    private static let settings = SendspinPlayerSettings(
        name: "Kitchen",
        volume: 50,
        isMuted: false,
        outputDelayMs: 0,
        allowsUnpairedAccess: true
    )

    private func makeService(_ recorder: SendspinServiceRecorder) -> SendspinPlayerService {
        SendspinPlayerService(
            credentials: SendspinMemoryCredentialStore(),
            audio: SendspinFakeAudio(),
            settings: Self.settings,
            deviceInfo: nil,
            advertises: false,
            onStatus: { recorder.record($0) },
            onEvent: { recorder.record($0) }
        )
    }

    /// Connects a server over the socket and takes it up to an activated playback connection.
    private func connectServer(port: UInt16, name: String = "Music Assistant") async throws
        -> (SendspinURLSessionLink, SendspinTestServer) {
        let link = try SendspinURLSessionLink(port: port)
        var server = SendspinTestServer(connection: link)
        try await server.handshake(
            reference: SendspinPskReference(pskID: SendspinPsk.sentinel.identifier, category: .sentinel),
            psk: .sentinel
        )
        try server.send(type: "server/hello", payload: SendspinServerHello(name: name, languages: nil))
        _ = try await server.receive(SendspinClientHello.self, type: "client/hello")
        try server.send(type: "server/activate", payload: SendspinServerActivate(
            activities: ["playback"],
            activeRoles: [SendspinSession.playerRole],
            pairing: nil
        ))
        _ = try await server.receive(SendspinClientState.self, type: "client/state")
        return (link, server)
    }

    @Test func servesAServerOverARealSocket() async throws {
        let recorder = SendspinServiceRecorder()
        let service = makeService(recorder)
        await service.start(port: 0)
        let port = try await recorder.listeningPort()

        let (link, connected) = try await connectServer(port: port)
        var server = connected
        defer { link.close() }
        _ = try await recorder.wait { $0 == .connected(serverName: "Music Assistant") }

        var louder = Self.settings
        louder.volume = 30
        await service.update(settings: louder)
        #expecttry await (server.receive(SendspinClientState.self, type: "client/state").player?.volume == 30)

        await service.setAvailable(false)
        #expecttry await (server.receive(SendspinClientState.self, type: "client/state").available == false)
        #expectawait (service.isStreaming == false)

        await service.stop(reason: .shutdown)
        #expecttry await (server.receive(SendspinClientGoodbye.self, type: "client/goodbye").reason == .shutdown)
        _ = try await recorder.wait { $0 == .stopped }
    }

    /// A second server of equal priority takes the player over; the first is told why.
    @Test func aSecondServerDisplacesTheFirst() async throws {
        let recorder = SendspinServiceRecorder()
        let service = makeService(recorder)
        await service.start(port: 0)
        let port = try await recorder.listeningPort()

        let (firstLink, connectedFirst) = try await connectServer(port: port, name: "First")
        var first = connectedFirst
        defer { firstLink.close() }
        let (secondLink, _) = try await connectServer(port: port, name: "Second")
        defer { secondLink.close() }

        #expecttry await (first.receive(SendspinClientGoodbye.self, type: "client/goodbye").reason == .anotherServer)
        _ = try await recorder.wait { $0 == .connected(serverName: "Second") }

        // Renaming the player reconnects every server, since the name only travels in the hello.
        var renamed = Self.settings
        renamed.name = "Den"
        await service.update(settings: renamed)
        _ = try await recorder.listeningPort()
        await service.stop(reason: .userRequest)
    }
}
