#if canImport(ActivityKit)
import ActivityKit
import Foundation
@testable import Shared

/// Test double for `LiveActivityRegistryProtocol`.
/// Records all calls so tests can assert on what was invoked.
@available(iOS 17.2, *)
final class MockLiveActivityRegistry: LiveActivityRegistryProtocol {
    // MARK: - Recorded Calls

    struct StartOrUpdateCall: Equatable {
        let tag: String
        let title: String
    }

    struct EndCall {
        let tag: String
        let policy: ActivityUIDismissalPolicy
    }

    private(set) var startOrUpdateCalls: [StartOrUpdateCall] = []
    private(set) var endCalls: [EndCall] = []
    private(set) var reattachCallCount = 0

    // MARK: - Configurable Errors

    /// Set to make the next `startOrUpdate` throw.
    var startOrUpdateError: Error?

    // MARK: - LiveActivityRegistryProtocol

    func startOrUpdate(
        tag: String,
        title: String,
        state: HALiveActivityAttributes.ContentState
    ) async throws {
        if let error = startOrUpdateError {
            startOrUpdateError = nil
            throw error
        }
        startOrUpdateCalls.append(StartOrUpdateCall(tag: tag, title: title))
    }

    func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy) async {
        endCalls.append(EndCall(tag: tag, policy: dismissalPolicy))
    }

    func reattach() async {
        reattachCallCount += 1
    }

    func startObservingPushToStartToken() async {
        // No-op in tests — token observation requires a real device/simulator push environment.
    }
}

// MARK: - EndCall helpers

@available(iOS 17.2, *)
extension MockLiveActivityRegistry.EndCall {
    var policyIsImmediate: Bool { policy == .immediate }
    var policyIsDefault: Bool { policy == .default }
    /// True when the policy is `.after(date)` for any date.
    var policyIsAfter: Bool { !policyIsImmediate && !policyIsDefault }
}
#endif
