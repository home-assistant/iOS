import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SnapshotTesting
import SwiftUI
import XCTest

/// The camera player's own chrome: the close button, the camera name (and picker), the clock large
/// screens get, and the player it mounts once `camera/capabilities` answers.
@MainActor
final class CameraPlayerViewSnapshotTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousDate: (() -> Date)!
    private var server: Server!
    private var connection: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousDate = Current.date

        let servers = FakeServerManager(initial: 0)
        server = servers.addFake()
        Current.servers = servers
        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        api.connection = connection
        Current.cachedApis[server.identifier] = api

        let database = try DatabaseQueue(path: ":memory:")
        // Every table, since listing the cameras for the picker reads the entity registry too.
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
        // 9:41 in UTC, which the snapshots below render in.
        Current.date = { Date(timeIntervalSince1970: 1_793_094_060) }
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.date = previousDate
        connection = nil
        server = nil
        super.tearDown()
    }

    /// Kiosks are mostly iPads: the clock sits in the trailing corner and, with another camera to
    /// switch to, the name opens the picker.
    func testIPadShowsTheClockAndThePicker() throws {
        try addCameras(["camera.front_door": "Front Door", "camera.garden": "Garden"])

        assertLightDarkSnapshots(
            of: player(sizeClass: .regular),
            drawHierarchyInKeyWindow: true,
            layout: .device(config: .iPadPro12_9(.landscape))
        )
    }

    /// A phone has no room for the clock, and a single camera leaves nothing to pick.
    func testIPhoneShowsTheNameWithoutClockOrPicker() throws {
        try addCameras(["camera.front_door": "Front Door"])

        assertLightDarkSnapshots(
            of: player(sizeClass: .compact),
            drawHierarchyInKeyWindow: true,
            layout: .device(config: .iPhone13(.portrait))
        )
    }

    func testACameraStreamingOverWebRTCMountsTheWebRTCPlayer() throws {
        let window = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.windows.first }.first
        )
        let previousRoot = window.rootViewController
        defer { window.rootViewController = previousRoot }
        window.rootViewController = UIHostingController(rootView: player(sizeClass: .regular))
        window.makeKeyAndVisible()

        let capabilities = try waitForRequest("camera/capabilities")
        capabilities.completion(.success(.init(value: [
            "frontend_stream_types": ["web_rtc"],
            "two_way_audio": true,
        ])))

        _ = try waitForRequest("camera/webrtc/get_client_config")
    }

    // MARK: - Helpers

    private func player(sizeClass: UserInterfaceSizeClass) -> some View {
        CameraPlayerView(server: server, cameraEntityId: "camera.front_door")
            .environment(\.horizontalSizeClass, sizeClass)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .gmt)
    }

    private func addCameras(_ cameras: [String: String]) throws {
        try Current.database().write { db in
            for (entityId, name) in cameras {
                try HAAppEntity(
                    id: ServerEntity.uniqueId(serverId: server.identifier.rawValue, entityId: entityId),
                    entityId: entityId,
                    serverId: server.identifier.rawValue,
                    domain: Domain.camera.rawValue,
                    name: name,
                    icon: nil,
                    rawDeviceClass: nil
                ).insert(db)
            }
        }
    }

    /// Spins the main run loop until the player sends `command`, so the view's tasks get to run.
    private func waitForRequest(_ command: String) throws -> HAMockConnection.PendingRequest {
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            if let request = connection.pendingRequests.first(where: { $0.request.type.command == command }) {
                return request
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        throw RequestTimeout(command: command)
    }

    private struct RequestTimeout: Error {
        let command: String
    }
}
