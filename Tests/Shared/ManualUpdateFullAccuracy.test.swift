import CoreLocation
import Foundation
import PromiseKit
@testable import Shared
import Testing
import UIKit

/// Serialized because every test swaps the global `Current.locationManager`.
@Suite("manuallyUpdate full accuracy", .serialized)
struct ManualUpdateFullAccuracyTests {
    /// Fails the wrapped work immediately, which stops `manuallyUpdate` after the accuracy step so
    /// these tests don't need a server, sensors or a real location fix.
    private final class ExpiringBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
        func callAsFunction<PromiseValue>(
            withName name: String,
            wrapping: (TimeInterval?) -> Promise<PromiseValue>
        ) -> Promise<PromiseValue> {
            _ = wrapping(nil)
            return Promise(error: BackgroundTaskError.outOfTime)
        }
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 500 {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func withLocationManager(
        accuracy: CLAccuracyAuthorization,
        error: Error? = nil,
        _ body: (MockLocationManager) async throws -> Void
    ) async rethrows {
        let manager = MockLocationManager()
        manager.mockAccuracyAuthorization = accuracy
        manager.mockTemporaryFullAccuracyError = error

        let previousManager = Current.locationManager
        let previousRunner = Current.backgroundTask
        Current.locationManager = manager
        Current.backgroundTask = ExpiringBackgroundTaskRunner()
        defer {
            Current.locationManager = previousManager
            Current.backgroundTask = previousRunner
        }

        try await body(manager)
    }

    @Test("A user-requested update asks for full accuracy while the user is on approximate location")
    func userRequestedUpdateAsksForFullAccuracy() async {
        await withLocationManager(accuracy: .reducedAccuracy) { manager in
            HomeAssistantAPI.manuallyUpdate(applicationState: .active, type: .userRequested).cauterize()

            #expectawait (waitUntil { manager.requestedTemporaryFullAccuracyPurposeKeys.isEmpty == false })
            #expect(
                manager.requestedTemporaryFullAccuracyPurposeKeys == ["TemporaryFullAccuracyReasonManualUpdate"]
            )
        }
    }

    @Test("A refused full-accuracy request still lets the update continue")
    func refusedRequestStillContinues() async {
        let refusal = NSError(domain: kCLErrorDomain, code: CLError.denied.rawValue)
        await withLocationManager(accuracy: .reducedAccuracy, error: refusal) { manager in
            HomeAssistantAPI.manuallyUpdate(applicationState: .active, type: .userRequested).cauterize()

            #expectawait (waitUntil { manager.requestedTemporaryFullAccuracyPurposeKeys.isEmpty == false })
        }
    }

    @Test("An already-precise user does not get asked")
    func fullAccuracyIsNotAskedAgain() async {
        await withLocationManager(accuracy: .fullAccuracy) { manager in
            HomeAssistantAPI.manuallyUpdate(applicationState: .active, type: .userRequested).cauterize()

            // Waits for the decision itself rather than for a timeout to lapse.
            #expectawait (waitUntil { manager.accuracyAuthorizationReadCount > 0 })
            #expect(manager.requestedTemporaryFullAccuracyPurposeKeys.isEmpty)
        }
    }

    @Test("An app-open update never shows the system prompt")
    func appOpenedUpdateNeverAsks() async {
        await withLocationManager(accuracy: .reducedAccuracy) { manager in
            HomeAssistantAPI.manuallyUpdate(applicationState: .active, type: .appOpened).cauterize()

            #expectawait (waitUntil { manager.accuracyAuthorizationReadCount > 0 })
            #expect(manager.requestedTemporaryFullAccuracyPurposeKeys.isEmpty)
        }
    }
}
