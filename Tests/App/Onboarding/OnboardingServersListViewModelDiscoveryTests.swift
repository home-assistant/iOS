@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// What the servers list's view model does with discovery: instances added once however often
/// they are reported, removed by name, discovery resumed without losing them, and the dismissal
/// that follows a completed onboarding.
@Suite(.sharedState)
@MainActor
struct OnboardingServersListViewModelDiscoveryTests {
    private func withViewModel(
        shouldDismissOnSuccess: Bool = false,
        _ body: (OnboardingServersListViewModel, MockBonjour) async throws -> Void
    ) async rethrows {
        let bonjour = MockBonjour()
        let previousBonjour = Current.bonjour
        Current.bonjour = { bonjour }
        defer { Current.bonjour = previousBonjour }
        let viewModel = OnboardingServersListViewModel(shouldDismissOnSuccess: shouldDismissOnSuccess)
        try await body(viewModel, bonjour)
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    private func instance(named name: String) throws -> DiscoveredHomeAssistant {
        var instance = try DiscoveredHomeAssistant(JSON: [
            "uuid": "uuid-\(name)",
            "internal_url": "http://192.0.2.\(name.count):8123",
            "location_name": name,
        ], context: nil)
        instance.bonjourName = name
        return instance
    }

    @Test func discoveredInstancesAreAddedOnceAndRemovedByName() async throws {
        try await withViewModel { viewModel, _ in
            let chalet = try instance(named: "Chalet")
            let home = try instance(named: "Home")

            viewModel.bonjour(Bonjour(), didAdd: chalet)
            viewModel.bonjour(Bonjour(), didAdd: chalet)
            viewModel.bonjour(Bonjour(), didAdd: home)
            let expectation1 = await waitUntil { viewModel.discoveredInstances.count == 2 }
            #expect(expectation1)

            viewModel.bonjour(Bonjour(), didRemoveInstanceWithName: "Chalet")
            let expectation2 = await waitUntil { viewModel.discoveredInstances.map(\.bonjourName) == ["Home"] }
            #expect(expectation2)
        }
    }

    @Test func resumingDiscoveryKeepsWhatWasFound() async throws {
        try await withViewModel { viewModel, bonjour in
            viewModel.discoveredInstances = try [instance(named: "Home")]

            viewModel.stopDiscovery()
            #expect(bonjour.stopCalled)
            viewModel.resumeDiscovery()

            #expect(bonjour.startCalled)
            #expect(viewModel.discoveredInstances.count == 1)
        }
    }

    @Test(arguments: [true, false])
    func completingOnboardingDismissesWhenAskedTo(shouldDismissOnSuccess: Bool) async {
        await withViewModel(shouldDismissOnSuccess: shouldDismissOnSuccess) { viewModel, _ in
            viewModel.onboardingStateDidChange(to: .needed(.logout))
            viewModel.onboardingStateDidChange(to: .complete)

            // The dismissal lands on the main queue; give it a few turns when nothing is expected.
            if shouldDismissOnSuccess {
                let expectation3 = await waitUntil { viewModel.shouldDismiss }
                #expect(expectation3)
            } else {
                for _ in 0 ..< 5 {
                    await Task.yield()
                }
                #expect(!viewModel.shouldDismiss)
            }
        }
    }
}
