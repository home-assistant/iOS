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
}
