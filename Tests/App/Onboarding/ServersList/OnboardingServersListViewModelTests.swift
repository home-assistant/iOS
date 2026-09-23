import Foundation
@testable import HomeAssistant
import ObjectMapper
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

    @Test @MainActor func testSelectInstanceUsesInstanceIDOfDiscoveredServerDirectly() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        let discovered = try Self.discoveredInstance()

        sut.selectInstance(discovered, presenter: OnboardingAuthPresenter())

        #expect(sut.currentlyInstanceLoading?.uuid == Self.discoveredInstanceID)
    }

    @Test @MainActor func testSelectInstanceAdoptsDiscoveredInstanceIDForManualURL() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        let discovered = try Self.discoveredInstance()
        sut.discoveredInstances = [discovered]

        sut.selectInstance(Self.manualInstance(), presenter: OnboardingAuthPresenter())

        try await waitUntil { sut.currentlyInstanceLoading?.uuid == Self.discoveredInstanceID }
    }

    /// An invitation starts discovery moments before it is accepted, so the answer for the server it
    /// points at can land after the user taps accept.
    @Test @MainActor func testSelectInstanceAdoptsAnInstanceDiscoveredAfterSelecting() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)

        sut.selectInstance(Self.manualInstance(), presenter: OnboardingAuthPresenter())

        #expect(sut.currentlyInstanceLoading?.hasHomeAssistantInstanceID == false)
        try await Task.sleep(nanoseconds: 150_000_000)
        let discovered = try Self.discoveredInstance()
        sut.discoveredInstances = [discovered]

        try await waitUntil { sut.currentlyInstanceLoading?.uuid == Self.discoveredInstanceID }
    }

    @Test @MainActor func testSelectInstanceKeepsGeneratedIDWhenDiscoveryDoesNotAnswer() async throws {
        let mockBonjour = MockBonjour()
        Current.bonjour = {
            mockBonjour
        }
        let sut = OnboardingServersListViewModel(shouldDismissOnSuccess: false)
        sut.discoveryAdoptionTimeout = 0.1
        let manual = Self.manualInstance()

        sut.selectInstance(manual, presenter: OnboardingAuthPresenter())

        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(sut.currentlyInstanceLoading?.uuid == manual.uuid)
        #expect(sut.currentlyInstanceLoading?.hasHomeAssistantInstanceID == false)
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

private extension OnboardingServersListViewModelTests {
    /// Port 1 so the authentication attempt selecting an instance kicks off is refused immediately
    /// instead of reaching anything; the identifier is decided before any of it runs.
    static let instanceURL = URL(string: "http://127.0.0.1:1")!
    static let discoveredInstanceID = "instance-id-from-mdns"

    static func discoveredInstance() throws -> DiscoveredHomeAssistant {
        try DiscoveredHomeAssistant(
            JSON: [
                "uuid": discoveredInstanceID,
                "internal_url": instanceURL.absoluteString,
                "location_name": "Home",
            ],
            context: nil
        )
    }

    static func manualInstance() -> DiscoveredHomeAssistant {
        DiscoveredHomeAssistant(manualURL: instanceURL)
    }

    @MainActor
    func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        #expect(condition())
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

    func update(server: Server, forceUpdate: Bool, showProgress _: Bool) {
        updates.append(Update(serverId: server.identifier.rawValue, forceUpdate: forceUpdate))
        onUpdate?(server, forceUpdate)
    }
}
