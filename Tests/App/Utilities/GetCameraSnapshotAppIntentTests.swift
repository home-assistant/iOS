import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import Testing

/// Covers which server a camera snapshot is taken from.
///
/// The availability guard sits inside each test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the intent is iOS 17.
@Suite(.serialized)
struct GetCameraSnapshotAppIntentTests {
    private static let foreignIdentifier = "identifier-from-another-device"

    /// A 1×1 PNG, the smallest thing the snapshot can decode into an image.
    private static let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"

    private func withServers(count: Int, _ body: ([Server]) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }

        let manager = FakeServerManager(initial: count)
        Current.servers = manager
        Current.cachedApis = manager.all.reduce(into: [Identifier<Server>: HomeAssistantAPI]()) { apis, server in
            let api = HomeAssistantAPI(server: server)
            api.connection = HAMockConnection()
            apis[server.identifier] = api
        }

        try await body(manager.all)
    }

    /// A shortcut synced from another device names a server this installation never issued. With a
    /// single server set up the snapshot is taken from it instead of failing.
    ///
    /// Reaching the stubbed snapshot at all is the assertion: a server that does not resolve throws
    /// before any request is sent.
    @Test func snapshotsForAShortcutSyncedFromAnotherDevice() async throws {
        guard #available(iOS 17.0, *) else { return }
        let png = try #require(Data(base64Encoded: Self.onePixelPNGBase64))

        try await withServers(count: 1) { _ in
            let descriptor = stub(
                condition: { $0.url?.path.hasSuffix("/camera_proxy/camera.front_door") == true },
                response: { _ in .init(data: png, statusCode: 200, headers: ["Content-Type": "image/png"]) }
            )
            defer { HTTPStubs.removeStub(descriptor) }

            let intent = GetCameraSnapshotAppIntent()
            intent.server = IntentServerAppEntity(identifier: .init(rawValue: Self.foreignIdentifier))
            intent.camera = IntentCameraEntity(
                serverId: Self.foreignIdentifier,
                entityId: "camera.front_door",
                displayName: "Front door"
            )

            _ = try await intent.perform()
        }
    }

    /// With several servers set up an unknown identifier resolves to nothing, so a camera belonging
    /// to a different server than the one picked is refused rather than snapshotted from the wrong
    /// place.
    @Test func refusesACameraBelongingToAnotherServer() async throws {
        guard #available(iOS 17.0, *) else { return }
        try await withServers(count: 2) { servers in
            let intent = GetCameraSnapshotAppIntent()
            intent.server = IntentServerAppEntity(from: servers[0])
            intent.camera = IntentCameraEntity(
                serverId: servers[1].identifier.rawValue,
                entityId: "camera.front_door",
                displayName: "Front door"
            )

            await #expect(throws: ShortcutAppIntentError.self) {
                _ = try await intent.perform()
            }
        }
    }
}
