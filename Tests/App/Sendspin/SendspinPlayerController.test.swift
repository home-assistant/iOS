import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
@Suite(.serialized)
struct SendspinPlayerControllerTests {
    private func waitFor(
        _ controller: SendspinPlayerController,
        timeout: TimeInterval = 5,
        _ predicate: (SendspinPlayerStatus) -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(controller.status) {
                return true
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return false
    }

    /// Switched on, the player listens; sent to the background idle, it stops; back in front, it
    /// listens again; switched off, it stops for good.
    @Test func followsTheSettingAndTheAppLifecycle() async throws {
        let controller = SendspinPlayerController(
            credentials: SendspinMemoryCredentialStore(),
            configuration: SendspinPlayerConfiguration()
        )
        controller.applyConfiguration(SendspinPlayerConfiguration())
        #expect(controller.status == .stopped)

        controller.applyConfiguration(SendspinPlayerConfiguration(isEnabled: true, playerName: "Test"))
        #expectawait (waitFor(controller) { status in
            if case .listening = status { return true }
            if case .failed = status { return true }
            return false
        })

        controller.applicationDidEnterBackground()
        if !Current.isCatalyst {
            #expect(controller.status == .stopped)
        }
        controller.applicationWillEnterForeground()
        #expect(controller.status != .stopped)

        controller.send(SendspinControllerCommand(command: "play"))
        controller.applyConfiguration(SendspinPlayerConfiguration(isEnabled: false))
        #expect(controller.status == .stopped)
        #expect(controller.nowPlaying == nil)
    }

    @Test func pairingTokenCarriesTheIdentityAndPairingPsk() throws {
        let credentials = SendspinMemoryCredentialStore()
        let controller = SendspinPlayerController(
            credentials: credentials,
            configuration: SendspinPlayerConfiguration()
        )
        let token = try #require(SendspinPairingToken(string: controller.pairingToken.string))
        #expect(token.clientKey == credentials.identity().publicKeyBytes)
        #expect(token.pairingPsk == credentials.pairingPsk())
    }
}
