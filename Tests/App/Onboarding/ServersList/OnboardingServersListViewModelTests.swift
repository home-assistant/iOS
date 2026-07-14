import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
struct OnboardingServersListViewModelTests {
    @Test func testInitAddsSelfAsObserver() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        assert(sut.discoveredInstances.isEmpty)
        assert((mockBonjour.observer as? OnboardingServersListViewModel) != nil)
    }

    @Test func testStartDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.startDiscovery()
        assert(sut.discoveredInstances.isEmpty)
        assert(mockBonjour.startCalled)
    }

    @Test func testStopDiscovery() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.stopDiscovery()
        assert(mockBonjour.stopCalled)
    }

    @Test func testResetFlow() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.resetFlow()
        assert(sut.currentlyInstanceLoading == nil)
        assert(sut.manualInputLoading == false)
        assert(sut.invitationLoading == false)
    }

    @Test @MainActor func testOnboardingCompletionUpdatesDatabaseForServer() async {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let recorder = RecordingAppDatabaseUpdater()
        let previousUpdater = Current.appDatabaseUpdater
        Current.appDatabaseUpdater = recorder
        defer { Current.appDatabaseUpdater = previousUpdater }

        let server = Server.fake()
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        sut.onboardingServer = server

        await withCheckedContinuation { continuation in
            recorder.onUpdate = { _, _ in continuation.resume() }
            sut.onboardingStateDidChange(to: .complete)
        }

        let updatedServerIds = recorder.updates.map(\.serverId)
        let usedForceUpdate = recorder.updates.allSatisfy(\.forceUpdate)
        #expect(updatedServerIds == [server.identifier.rawValue])
        #expect(usedForceUpdate)
    }

    @Test @MainActor func testOnboardingCompletionWithoutServerDoesNotUpdateDatabase() async {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let recorder = RecordingAppDatabaseUpdater()
        let previousUpdater = Current.appDatabaseUpdater
        Current.appDatabaseUpdater = recorder
        defer { Current.appDatabaseUpdater = previousUpdater }

        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.onboardingStateDidChange(to: .complete)
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        #expect(recorder.updates.isEmpty)
    }
}

private final class RecordingAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    struct Update {
        let serverId: String
        let forceUpdate: Bool
    }

    private(set) var updates: [Update] = []
    var onUpdate: ((Server, Bool) -> Void)?

    func stop() {}

    func update(server: Server, forceUpdate: Bool) {
        updates.append(Update(serverId: server.identifier.rawValue, forceUpdate: forceUpdate))
        onUpdate?(server, forceUpdate)
    }
}
